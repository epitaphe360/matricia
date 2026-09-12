-- Additive four-eyes enforcement for Client compliance decisions.
-- Existing RPC state machines, locks, idempotency, audit and Outbox remain authoritative.

create or replace function private.enforce_client_compliance_decision_four_eyes()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
begin
  if new.decided_by is not distinct from old.decided_by
     and new.decided_at is not distinct from old.decided_at then
    return new;
  end if;
  if new.status not in ('VERIFIED', 'REJECTED', 'QUESTION_REQUIRED') then
    return new;
  end if;
  -- A rejected answer also returns the case to QUESTION_REQUIRED. Its own
  -- separation is enforced on the question row below. The compliance RPC
  -- has already opened its idempotency command in the current transaction.
  if new.status = 'QUESTION_REQUIRED' and not exists (
    select 1 from public.idempotency_keys command
    where command.organization_id = new.organization_id
      and command.operation_scope = 'client.compliance.decide'
      and command.created_by = v_actor
      and command.status = 'PROCESSING'
      and command.created_at >= transaction_timestamp()
  ) then
    return new;
  end if;
  if v_actor is null or new.decided_by is distinct from v_actor then
    raise exception 'CLIENT_COMPLIANCE_DECISION_ACTOR_REQUIRED' using errcode = '42501';
  end if;
  if v_actor = new.created_by
     or exists (
       select 1
       from public.client_profile_versions profile
       where profile.compliance_case_id = new.id
         and profile.version = new.current_profile_version
         and profile.created_by = v_actor
     )
     or exists (
       select 1
       from public.idempotency_keys command
       where command.organization_id = new.organization_id
         and command.operation_scope = 'client.compliance.submit'
         and command.created_by = v_actor
     )
     or exists (
       select 1
       from public.client_compliance_documents document
       where document.compliance_case_id = new.id
         and (document.created_by = v_actor or document.reviewed_by = v_actor)
     ) then
    raise exception 'CLIENT_COMPLIANCE_DUAL_CONTROL_REQUIRED' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_client_compliance_decision_four_eyes()
  from public, anon, authenticated, service_role;

drop trigger if exists client_compliance_decision_four_eyes on public.client_compliance_cases;
create trigger client_compliance_decision_four_eyes
before update on public.client_compliance_cases
for each row execute function private.enforce_client_compliance_decision_four_eyes();

create or replace function private.enforce_client_document_review_four_eyes()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
begin
  if new.status not in ('VERIFIED', 'REJECTED', 'QUARANTINED')
     or new.reviewed_by is not distinct from old.reviewed_by then
    return new;
  end if;
  if v_actor is null or new.reviewed_by is distinct from v_actor then
    raise exception 'CLIENT_DOCUMENT_REVIEW_ACTOR_REQUIRED' using errcode = '42501';
  end if;
  if v_actor = old.created_by then
    raise exception 'CLIENT_DOCUMENT_DUAL_CONTROL_REQUIRED' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_client_document_review_four_eyes()
  from public, anon, authenticated, service_role;

drop trigger if exists client_document_review_four_eyes on public.client_compliance_documents;
create trigger client_document_review_four_eyes
before update on public.client_compliance_documents
for each row execute function private.enforce_client_document_review_four_eyes();

create or replace function private.enforce_client_response_review_four_eyes()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
  v_submitter uuid;
begin
  if old.status <> 'ANSWERED' or new.status not in ('ACCEPTED', 'OPEN') then
    return new;
  end if;
  if v_actor is null then
    raise exception 'CLIENT_RESPONSE_REVIEW_ACTOR_REQUIRED' using errcode = '42501';
  end if;
  select response.submitted_by into v_submitter
  from public.client_compliance_response_versions response
  where response.question_id = old.id
  order by response.version desc
  limit 1;
  if v_actor = old.created_by or v_actor = v_submitter then
    raise exception 'CLIENT_RESPONSE_DUAL_CONTROL_REQUIRED' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_client_response_review_four_eyes()
  from public, anon, authenticated, service_role;

drop trigger if exists client_response_review_four_eyes on public.client_compliance_questions;
create trigger client_response_review_four_eyes
before update on public.client_compliance_questions
for each row execute function private.enforce_client_response_review_four_eyes();

create or replace function public.explain_client_compliance_four_eyes(p_compliance_case_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
  v_case public.client_compliance_cases%rowtype;
  v_can_act boolean;
  v_case_can_decide boolean;
begin
  if v_actor is null or not private.has_platform_role(
    array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'COMPLIANCE_MANAGER', 'READ_ONLY_AUDITOR'], v_actor
  ) then
    raise exception 'CLIENT_COMPLIANCE_ADMIN_SCOPE_REQUIRED' using errcode = '42501';
  end if;
  select * into v_case from public.client_compliance_cases where id = p_compliance_case_id;
  if not found then
    raise exception 'COMPLIANCE_CASE_NOT_FOUND' using errcode = 'P0002';
  end if;
  v_can_act := private.has_platform_role(
    array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'COMPLIANCE_MANAGER'], v_actor
  );
  v_case_can_decide := v_can_act
    and v_actor <> v_case.created_by
    and not exists (
      select 1 from public.client_profile_versions profile
      where profile.compliance_case_id = v_case.id
        and profile.version = v_case.current_profile_version
        and profile.created_by = v_actor
    )
    and not exists (
      select 1 from public.idempotency_keys command
      where command.organization_id = v_case.organization_id
        and command.operation_scope = 'client.compliance.submit'
        and command.created_by = v_actor
    )
    and not exists (
      select 1 from public.client_compliance_documents document
      where document.compliance_case_id = v_case.id
        and (document.created_by = v_actor or document.reviewed_by = v_actor)
    );
  return jsonb_build_object(
    'case_can_decide', v_case_can_decide,
    'documents', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', document.id,
        'can_review', v_can_act and document.created_by <> v_actor
      ) order by document.created_at desc)
      from public.client_compliance_documents document
      where document.compliance_case_id = v_case.id
        and document.status = 'PENDING_REVIEW'
    ), '[]'::jsonb),
    'responses', coalesce((
      select jsonb_agg(jsonb_build_object(
        'question_id', question.id,
        'can_review', v_can_act and question.created_by <> v_actor
          and response.submitted_by <> v_actor
      ) order by question.updated_at desc)
      from public.client_compliance_questions question
      join lateral (
        select submitted.submitted_by
        from public.client_compliance_response_versions submitted
        where submitted.question_id = question.id
        order by submitted.version desc
        limit 1
      ) response on true
      where question.compliance_case_id = v_case.id
        and question.status = 'ANSWERED'
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.explain_client_compliance_four_eyes(uuid)
  from public, anon, service_role;
grant execute on function public.explain_client_compliance_four_eyes(uuid) to authenticated;

notify pgrst, 'reload schema';
