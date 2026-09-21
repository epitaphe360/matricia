-- Convert a confirmed public need intake into one versioned service request.
-- Intakes stay immutable; provenance lives in public_need_intake_conversions.
-- Does not mark ready, match, or open an RFQ.
-- Rollback: revoke the RPC and drop the conversion table; created requests remain.

create table public.public_need_intake_conversions (
  intake_id uuid primary key references public.public_need_intakes(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  service_request_id uuid not null unique references public.service_requests(id) on delete restrict,
  service_id uuid not null references public.catalog_services(id) on delete restrict,
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  service_code text not null check (service_code ~ '^[A-Z][A-Z0-9_-]{1,79}$'),
  catalog_snapshot_hash text not null check (catalog_snapshot_hash ~ '^[0-9a-f]{64}$'),
  questionnaire_version_id uuid not null references public.questionnaire_versions(id) on delete restrict,
  questionnaire_snapshot_hash text not null check (questionnaire_snapshot_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp()
);

create function private.prevent_public_need_intake_conversion_mutation() returns trigger
language plpgsql set search_path=pg_catalog,public,private as $$begin
  raise exception 'PUBLIC_NEED_INTAKE_CONVERSION_IMMUTABLE' using errcode='55000';
end$$;

create trigger public_need_intake_conversions_immutable
  before update or delete on public.public_need_intake_conversions
  for each row execute function private.prevent_public_need_intake_conversion_mutation();

revoke all on function private.prevent_public_need_intake_conversion_mutation() from public,anon,authenticated,service_role;

alter table public.public_need_intake_conversions enable row level security;
create policy public_need_intake_conversions_client_read on public.public_need_intake_conversions
  for select to authenticated
  using (private.has_org_role(organization_id, array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER','CLIENT_VIEWER']));
revoke all on public.public_need_intake_conversions from public,anon,authenticated,service_role;
grant select on public.public_need_intake_conversions to authenticated;

create function public.create_service_request_from_need_intake(
  p_intake_id uuid,
  p_service_code text,
  p_payload jsonb,
  p_change_reason text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  intake public.public_need_intakes%rowtype;
  conversion public.public_need_intake_conversions%rowtype;
  service public.catalog_services%rowtype;
  service_version public.catalog_service_versions%rowtype;
  questionnaire_version public.questionnaire_versions%rowtype;
  snapshot_code text;
  controlled_payload jsonb;
  response jsonb;
  request_id uuid;
begin
  if auth.uid() is null
     or p_service_code is null
     or p_service_code !~ '^[A-Z][A-Z0-9_-]{1,79}$'
     or jsonb_typeof(p_payload) <> 'object'
     or length(btrim(coalesce(p_change_reason, ''))) not between 3 and 500 then
    raise exception 'INVALID_NEED_REQUEST' using errcode='22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('need-intake-request:' || p_intake_id::text, 0));
  select * into intake from public.public_need_intakes where id = p_intake_id for update;
  if not found or not private.can_manage_client_request(intake.organization_id, auth.uid()) then
    raise exception 'NEED_REQUEST_SCOPE_DENIED' using errcode='42501';
  end if;

  select * into conversion from public.public_need_intake_conversions where intake_id = p_intake_id;
  if found then
    if conversion.service_code <> p_service_code then
      raise exception 'NEED_INTAKE_ALREADY_CONVERTED' using errcode='55000';
    end if;
    if not exists (
      select 1 from public.service_requests request
      where request.id = conversion.service_request_id
        and request.client_organization_id = conversion.organization_id
    ) then
      raise exception 'NEED_REQUEST_LINK_INVALID' using errcode='23514';
    end if;
    return jsonb_build_object(
      'outcome', 'SERVICE_REQUEST_CREATED',
      'request_id', conversion.service_request_id,
      'status', 'DRAFT',
      'replayed', true
    );
  end if;

  snapshot_code := (
    select match[1]
    from regexp_matches(intake.constraints_text, '\(([A-Z][A-Z0-9_-]*-[A-Z0-9_-]+)\)', 'g') as match
    limit 1
  );
  if snapshot_code is not null and snapshot_code <> p_service_code then
    raise exception 'NEED_SERVICE_MISMATCH' using errcode='22023';
  end if;

  select * into service
  from public.catalog_services
  where code = p_service_code and status = 'PUBLISHED';
  select * into service_version
  from public.catalog_service_versions
  where id = service.current_published_version_id
    and service_id = service.id
    and library_id = service.library_id
    and status = 'PUBLISHED';
  if service.id is null or service_version.id is null then
    raise exception 'NEED_SERVICE_UNAVAILABLE' using errcode='55000';
  end if;

  select qv.* into questionnaire_version
  from public.questionnaires questionnaire
  join public.questionnaire_versions qv
    on qv.id = questionnaire.current_published_version_id
   and qv.questionnaire_id = questionnaire.id
   and qv.library_id = questionnaire.library_id
   and qv.status = 'PUBLISHED'
   and qv.audience = 'CLIENT'
  where questionnaire.library_id = service.library_id
    and questionnaire.status = 'PUBLISHED'
    and exists (
      select 1
      from public.questionnaire_version_questions link
      join public.question_versions question on question.id = link.question_version_id
      where link.questionnaire_version_id = qv.id
        and question.source_service_id = service.id
    )
  order by qv.id
  limit 1;

  if questionnaire_version.id is null then
    select qv.* into questionnaire_version
    from public.questionnaires questionnaire
    join public.questionnaire_versions qv
      on qv.id = questionnaire.current_published_version_id
     and qv.questionnaire_id = questionnaire.id
     and qv.library_id = questionnaire.library_id
     and qv.status = 'PUBLISHED'
     and qv.audience = 'CLIENT'
    where questionnaire.library_id = service.library_id
      and questionnaire.status = 'PUBLISHED'
    order by qv.id
    limit 1;
  end if;

  if questionnaire_version.id is null then
    raise exception 'NEED_QUESTIONNAIRE_UNAVAILABLE' using errcode='55000';
  end if;

  controlled_payload := jsonb_build_object(
    'description', btrim(coalesce(p_payload->>'description', '')),
    'urgency', p_payload->>'urgency',
    'desired_date', coalesce(p_payload->>'desired_date', ''),
    'budget_minor', coalesce(p_payload->>'budget_minor', ''),
    'currency_code', coalesce(nullif(p_payload->>'currency_code', ''), 'MAD'),
    'required_quote_data', jsonb_build_object('region_code', p_payload->>'region_code'),
    'required_fields_complete', true,
    'catalog_snapshot_hash', service_version.content_hash,
    'questionnaire_snapshot_hash', questionnaire_version.snapshot_hash
  );

  response := public.create_service_request(
    intake.organization_id,
    service.library_id,
    service.id,
    questionnaire_version.id,
    controlled_payload,
    p_change_reason,
    p_intake_id::text,
    p_correlation_id
  );
  request_id := (response->>'request_id')::uuid;

  insert into public.public_need_intake_conversions (
    intake_id, organization_id, service_request_id, service_id, library_id, service_code,
    catalog_snapshot_hash, questionnaire_version_id, questionnaire_snapshot_hash, created_by
  ) values (
    intake.id, intake.organization_id, request_id, service.id, service.library_id, p_service_code,
    service_version.content_hash, questionnaire_version.id, questionnaire_version.snapshot_hash, auth.uid()
  );

  insert into public.audit_events (
    organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash
  ) values (
    intake.organization_id, auth.uid(), 'USER', 'public_need.intake.converted', 'public_need_intake', intake.id::text,
    p_correlation_id, jsonb_build_object('service_request_id', request_id, 'service_code', p_service_code), repeat('0', 64)
  );
  insert into public.event_outbox (
    organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key
  ) values (
    intake.organization_id, 'public_need_intake', intake.id::text, 'PublicNeedIntakeConvertedV1', p_correlation_id,
    jsonb_build_object('intake_id', intake.id, 'service_request_id', request_id, 'service_code', p_service_code),
    'need-intake-converted:' || intake.id::text
  ) on conflict do nothing;

  return response || jsonb_build_object('intake_id', intake.id, 'replayed', false);
end$$;

revoke all on function public.create_service_request_from_need_intake(uuid, text, jsonb, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.create_service_request_from_need_intake(uuid, text, jsonb, text, uuid) to authenticated;
