-- Additive remediation for central Client compliance administration.
-- Migration 137 remains immutable; 138 is intentionally not used.

alter table public.client_compliance_cases
  add column if not exists submitted_by uuid references auth.users(id);

alter table public.client_compliance_questions
  add column if not exists reviewed_by uuid references auth.users(id);

-- Only immutable audit evidence is trusted for historical attribution. Rows for
-- which no unambiguous evidence exists remain NULL and are denied by the guards.
update public.client_compliance_cases compliance_case
set submitted_by = evidence.actor_user_id
from (
  select distinct on (audit.resource_id) audit.resource_id, audit.actor_user_id
  from public.audit_events audit
  where audit.action = 'client.compliance.submitted'
    and audit.resource_type = 'client_compliance_case'
    and audit.actor_type = 'USER'
    and audit.actor_user_id is not null
  order by audit.resource_id, audit.occurred_at desc, audit.id desc
) evidence
where compliance_case.id::text = evidence.resource_id
  and compliance_case.submitted_by is null;

update public.client_compliance_questions question
set reviewed_by = evidence.actor_user_id
from (
  select distinct on (audit.resource_id) audit.resource_id, audit.actor_user_id
  from public.audit_events audit
  where audit.action = 'client.compliance.response.decided'
    and audit.resource_type = 'client_compliance_question'
    and audit.actor_type = 'USER'
    and audit.actor_user_id is not null
  order by audit.resource_id, audit.occurred_at desc, audit.id desc
) evidence
where question.id::text = evidence.resource_id
  and question.reviewed_by is null;

create or replace function private.capture_client_compliance_submitter()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if old.submitted_by is distinct from new.submitted_by
     and not (new.status = 'UNDER_REVIEW'
       and old.status in ('PROFILE_IN_PROGRESS', 'DOCUMENTS_REQUIRED')) then
    raise exception 'CLIENT_COMPLIANCE_SUBMITTER_IMMUTABLE' using errcode = '55000';
  end if;
  if new.status = 'UNDER_REVIEW'
     and old.status in ('PROFILE_IN_PROGRESS', 'DOCUMENTS_REQUIRED') then
    if auth.uid() is null then
      raise exception 'CLIENT_COMPLIANCE_SUBMITTER_REQUIRED' using errcode = '42501';
    end if;
    new.submitted_by := auth.uid();
  end if;
  return new;
end;
$$;

revoke all on function private.capture_client_compliance_submitter()
  from public, anon, authenticated, service_role;

drop trigger if exists client_compliance_submitter_capture on public.client_compliance_cases;
create trigger client_compliance_submitter_capture
before update of status on public.client_compliance_cases
for each row execute function private.capture_client_compliance_submitter();

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
  if coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then
    raise exception 'CLIENT_COMPLIANCE_AAL2_REQUIRED' using errcode = '42501';
  end if;
  -- Response rejection first stamps the question through its own durable guard.
  if new.status = 'QUESTION_REQUIRED' and exists (
    select 1 from public.client_compliance_questions question
    where question.compliance_case_id = new.id
      and question.status = 'OPEN'
      and question.reviewed_by = v_actor
      and question.updated_at >= transaction_timestamp()
  ) then
    return new;
  end if;
  if v_actor is null or new.decided_by is distinct from v_actor then
    raise exception 'CLIENT_COMPLIANCE_DECISION_ACTOR_REQUIRED' using errcode = '42501';
  end if;
  if new.submitted_by is null then
    raise exception 'CLIENT_COMPLIANCE_SUBMITTER_EVIDENCE_REQUIRED' using errcode = '42501';
  end if;
  if v_actor = new.created_by
     or v_actor = new.submitted_by
     or exists (
       select 1 from public.client_profile_versions profile
       where profile.compliance_case_id = new.id
         and profile.version = new.current_profile_version
         and profile.created_by = v_actor
     )
     or exists (
       select 1 from public.audit_events audit
       where audit.organization_id = new.organization_id
         and audit.actor_user_id = v_actor
         and audit.action in ('client.compliance.evaluated', 'client.document.reviewed', 'client.compliance.response.decided')
     ) then
    raise exception 'CLIENT_COMPLIANCE_DUAL_CONTROL_REQUIRED' using errcode = '42501';
  end if;
  return new;
end;
$$;

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
  if coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then
    raise exception 'CLIENT_DOCUMENT_REVIEW_AAL2_REQUIRED' using errcode = '42501';
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
  if old.reviewed_by is distinct from new.reviewed_by
     and not (old.status = 'ANSWERED' and new.status in ('ACCEPTED', 'OPEN')) then
    raise exception 'CLIENT_RESPONSE_REVIEWER_IMMUTABLE' using errcode = '55000';
  end if;
  if old.status <> 'ANSWERED' or new.status not in ('ACCEPTED', 'OPEN') then
    return new;
  end if;
  if coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then
    raise exception 'CLIENT_RESPONSE_REVIEW_AAL2_REQUIRED' using errcode = '42501';
  end if;
  if v_actor is null then
    raise exception 'CLIENT_RESPONSE_REVIEW_ACTOR_REQUIRED' using errcode = '42501';
  end if;
  select response.submitted_by into v_submitter
  from public.client_compliance_response_versions response
  where response.question_id = old.id
  order by response.version desc
  limit 1;
  if v_submitter is null then
    raise exception 'CLIENT_RESPONSE_SUBMITTER_EVIDENCE_REQUIRED' using errcode = '42501';
  end if;
  if v_actor = old.created_by or v_actor = v_submitter then
    raise exception 'CLIENT_RESPONSE_DUAL_CONTROL_REQUIRED' using errcode = '42501';
  end if;
  new.reviewed_by := v_actor;
  return new;
end;
$$;

revoke all on function private.enforce_client_compliance_decision_four_eyes(),
  private.enforce_client_document_review_four_eyes(),
  private.enforce_client_response_review_four_eyes()
  from public, anon, authenticated, service_role;

create or replace function public.get_admin_client_compliance_projection(
  p_locale text default 'fr',
  p_limit integer default 100
) returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
  v_can_act boolean;
  v_cases jsonb;
begin
  if v_actor is null or not private.has_platform_role(
    array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'COMPLIANCE_MANAGER', 'READ_ONLY_AUDITOR'], v_actor
  ) then
    raise exception 'CLIENT_COMPLIANCE_ADMIN_SCOPE_REQUIRED' using errcode = '42501';
  end if;
  if p_locale not in ('fr', 'ar') or p_limit is null or p_limit not between 1 and 100 then
    raise exception 'INVALID_ADMIN_CLIENT_PROJECTION_LIMIT' using errcode = '22023';
  end if;
  v_can_act := private.has_platform_role(
    array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'COMPLIANCE_MANAGER'], v_actor
  );

  with bounded_cases as materialized (
    select compliance_case.*, organization.display_name as organization_name
    from public.client_compliance_cases compliance_case
    join public.organizations organization on organization.id = compliance_case.organization_id
    order by compliance_case.updated_at desc, compliance_case.id
    limit p_limit
  ), bounded_documents as materialized (
    select document.*
    from public.client_compliance_documents document
    join bounded_cases compliance_case on compliance_case.id = document.compliance_case_id
    order by document.updated_at desc, document.id
    limit 300
  ), latest_responses as materialized (
    select distinct on (response.question_id)
      response.question_id, response.version, response.submitted_by, response.submitted_at
    from public.client_compliance_response_versions response
    order by response.question_id, response.version desc
  ), bounded_questions as materialized (
    select question.*, response.version as response_version,
      response.submitted_by as response_submitted_by,
      response.submitted_at as response_submitted_at
    from public.client_compliance_questions question
    join bounded_cases compliance_case on compliance_case.id = question.compliance_case_id
    left join latest_responses response on response.question_id = question.id
    order by question.updated_at desc, question.id
    limit 300
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', compliance_case.id,
    'organization_name', left(compliance_case.organization_name, 200),
    'status', compliance_case.status,
    'profile_version', compliance_case.current_profile_version,
    'submitted_at', compliance_case.submitted_at,
    'updated_at', compliance_case.updated_at,
    'public_reason', compliance_case.decision_reason_public,
    'can_decide', v_can_act
      and compliance_case.submitted_by is not null
      and v_actor <> compliance_case.created_by
      and v_actor <> compliance_case.submitted_by
      and not exists (
        select 1 from public.client_profile_versions profile
        where profile.compliance_case_id = compliance_case.id
          and profile.version = compliance_case.current_profile_version
          and profile.created_by = v_actor
      )
      and not exists (
        select 1 from public.audit_events audit
        where audit.organization_id = compliance_case.organization_id
          and audit.actor_user_id = v_actor
          and audit.action in ('client.compliance.evaluated', 'client.document.reviewed', 'client.compliance.response.decided')
      ),
    'documents', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', document.id, 'type', document.document_type,
        'version', document.version, 'status', document.status,
        'scan_status', document.scan_status, 'expires_on', document.expires_on,
        'can_review', v_can_act and document.created_by <> v_actor
      ) order by document.updated_at desc, document.id)
      from bounded_documents document
      where document.compliance_case_id = compliance_case.id
    ), '[]'::jsonb),
    'questions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', question.id,
        'text', case when p_locale = 'ar' then question.question_text_ar else question.question_text_fr end,
        'due_at', question.due_at, 'status', question.status,
        'response_version', question.response_version,
        'response_submitted_at', question.response_submitted_at,
        'can_review', v_can_act and question.response_submitted_by is not null
          and question.created_by <> v_actor and question.response_submitted_by <> v_actor
      ) order by question.updated_at desc, question.id)
      from bounded_questions question
      where question.compliance_case_id = compliance_case.id
    ), '[]'::jsonb)
  ) order by compliance_case.updated_at desc, compliance_case.id), '[]'::jsonb)
  into v_cases
  from bounded_cases compliance_case;

  return jsonb_build_object(
    'capabilities', jsonb_build_object('can_act', v_can_act, 'read_only', not v_can_act),
    'cases', v_cases,
    'limits_reached', jsonb_build_array()
  );
end;
$$;

revoke all on function public.get_admin_client_compliance_projection(text, integer)
  from public, anon, service_role;
grant execute on function public.get_admin_client_compliance_projection(text, integer)
  to authenticated;

notify pgrst, 'reload schema';
