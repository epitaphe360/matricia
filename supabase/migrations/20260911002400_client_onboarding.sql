-- P05 client onboarding and compliance foundation.
-- External Moroccan registries are deliberately not claimed or emulated here:
-- identifiers remain unverified until a permitted adapter or manual review acts.

create table public.client_compliance_cases (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null unique references public.organizations(id) on delete restrict,
  status text not null default 'PROFILE_IN_PROGRESS' check (status in (
    'PROFILE_IN_PROGRESS', 'DOCUMENTS_REQUIRED', 'UNDER_REVIEW',
    'QUESTION_REQUIRED', 'RESPONSE_RECEIVED', 'VERIFIED', 'REJECTED', 'SUSPENDED'
  )),
  current_profile_version integer check (current_profile_version is null or current_profile_version > 0),
  submitted_at timestamptz,
  decided_by uuid references auth.users(id),
  decided_at timestamptz,
  decision_reason_public text check (
    decision_reason_public is null or length(btrim(decision_reason_public)) between 3 and 1000
  ),
  verified_at timestamptz,
  activated_at timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check (row_version > 0),
  unique (id, organization_id),
  check (activated_at is null or (verified_at is not null and activated_at >= verified_at)),
  check ((status in ('VERIFIED', 'SUSPENDED')) = (verified_at is not null)),
  check ((status in ('VERIFIED', 'SUSPENDED')) = (activated_at is not null))
);

create table public.client_profile_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  compliance_case_id uuid not null,
  organization_id uuid not null,
  version integer not null check (version > 0),
  profile_data jsonb not null check (jsonb_typeof(profile_data) = 'object'),
  organization_snapshot jsonb not null check (jsonb_typeof(organization_snapshot) = 'object'),
  source_organization_row_version integer not null check (source_organization_row_version > 0),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (compliance_case_id, version),
  unique (compliance_case_id, organization_id, version),
  foreign key (compliance_case_id, organization_id)
    references public.client_compliance_cases(id, organization_id) on delete restrict
);

alter table public.client_compliance_cases
  add constraint client_compliance_current_profile_fk
  foreign key (id, organization_id, current_profile_version)
  references public.client_profile_versions(compliance_case_id, organization_id, version)
  deferrable initially deferred;

create table public.client_trials (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null unique references public.organizations(id) on delete restrict,
  compliance_case_id uuid not null unique,
  verified_profile_version integer not null check (verified_profile_version > 0),
  status text not null default 'TRIAL_ACTIVE' check (status in ('TRIAL_ACTIVE', 'TRIAL_EXPIRED')),
  trial_started_at timestamptz not null,
  trial_ends_at timestamptz not null,
  activated_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check (row_version > 0),
  foreign key (compliance_case_id, organization_id, verified_profile_version)
    references public.client_profile_versions(compliance_case_id, organization_id, version) on delete restrict,
  check (trial_ends_at = trial_started_at + interval '30 days')
);

create or replace function private.validate_client_profile_payload(p_profile jsonb)
returns void
language plpgsql
stable
security invoker
set search_path = pg_catalog
as $$
declare
  v_required text[] := array[
    'legal_form', 'incorporation_date', 'activity', 'sector', 'employee_count',
    'registered_city', 'registered_address', 'contact', 'representative',
    'declarations', 'if_number', 'rc_number'
  ];
  v_incorporation_date date;
  v_employee_count numeric;
begin
  if p_profile is null
     or jsonb_typeof(p_profile) <> 'object'
     or not (p_profile ?& v_required) then
    raise exception 'CLIENT_PROFILE_REQUIRED_FIELDS_MISSING' using errcode = '22023';
  end if;

  if length(btrim(coalesce(p_profile ->> 'legal_form', ''))) not between 2 and 120
     or length(btrim(coalesce(p_profile ->> 'activity', ''))) not between 2 and 500
     or length(btrim(coalesce(p_profile ->> 'sector', ''))) not between 2 and 120
     or length(btrim(coalesce(p_profile ->> 'registered_city', ''))) not between 2 and 120 then
    raise exception 'CLIENT_PROFILE_INVALID_TEXT' using errcode = '22023';
  end if;

  if (p_profile ->> 'incorporation_date') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception 'CLIENT_PROFILE_INVALID_DATE' using errcode = '22023';
  end if;
  v_incorporation_date := (p_profile ->> 'incorporation_date')::date;
  if v_incorporation_date < date '1800-01-01' or v_incorporation_date > current_date then
    raise exception 'CLIENT_PROFILE_INVALID_DATE' using errcode = '22023';
  end if;

  if jsonb_typeof(p_profile -> 'employee_count') <> 'number' then
    raise exception 'CLIENT_PROFILE_INVALID_EMPLOYEE_COUNT' using errcode = '22023';
  end if;
  v_employee_count := (p_profile ->> 'employee_count')::numeric;
  if v_employee_count < 0 or v_employee_count > 100000000
     or trunc(v_employee_count) <> v_employee_count then
    raise exception 'CLIENT_PROFILE_INVALID_EMPLOYEE_COUNT' using errcode = '22023';
  end if;

  if jsonb_typeof(p_profile -> 'registered_address') <> 'object'
     or length(btrim(coalesce(p_profile #>> '{registered_address,line1}', ''))) not between 3 and 300
     or jsonb_typeof(p_profile -> 'contact') <> 'object'
     or length(btrim(coalesce(p_profile #>> '{contact,phone}', ''))) not between 6 and 40
     or coalesce(p_profile #>> '{contact,email}', '') !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then
    raise exception 'CLIENT_PROFILE_INVALID_CONTACT' using errcode = '22023';
  end if;

  if jsonb_typeof(p_profile -> 'representative') <> 'object'
     or length(btrim(coalesce(p_profile #>> '{representative,first_name}', ''))) not between 2 and 120
     or length(btrim(coalesce(p_profile #>> '{representative,last_name}', ''))) not between 2 and 120
     or length(btrim(coalesce(p_profile #>> '{representative,title}', ''))) not between 2 and 160
     or length(btrim(coalesce(p_profile #>> '{representative,phone}', ''))) not between 6 and 40
     or coalesce(p_profile #>> '{representative,email}', '') !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
     or length(btrim(coalesce(p_profile #>> '{representative,power}', ''))) not between 2 and 500 then
    raise exception 'CLIENT_PROFILE_INVALID_REPRESENTATIVE' using errcode = '22023';
  end if;

  if jsonb_typeof(p_profile -> 'declarations') <> 'object'
     or coalesce((p_profile #>> '{declarations,accuracy_confirmed}')::boolean, false) is not true
     or coalesce((p_profile #>> '{declarations,representation_authorized}')::boolean, false) is not true then
    raise exception 'CLIENT_PROFILE_DECLARATIONS_REQUIRED' using errcode = '22023';
  end if;
end;
$$;

revoke all on function private.validate_client_profile_payload(jsonb)
  from public, anon, authenticated, service_role;

create or replace function public.save_client_profile_draft(
  p_organization_id uuid,
  p_profile jsonb,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_hash text;
  v_existing public.idempotency_keys%rowtype;
  v_case public.client_compliance_cases%rowtype;
  v_organization public.organizations%rowtype;
  v_profile jsonb;
  v_snapshot jsonb;
  v_if text;
  v_rc text;
  v_version integer;
  v_response jsonb;
begin
  if v_actor is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;
  if coalesce(private.has_org_role(
    p_organization_id, array['CLIENT_OWNER', 'CLIENT_ADMIN'], v_actor
  ), false) is not true then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if length(coalesce(p_idempotency_key, '')) not between 8 and 200 then
    raise exception 'INVALID_IDEMPOTENCY_KEY' using errcode = '22023';
  end if;
  perform private.validate_client_profile_payload(p_profile);

  v_if := upper(regexp_replace(btrim(coalesce(p_profile ->> 'if_number', '')), '[^[:alnum:]]', '', 'g'));
  v_rc := upper(regexp_replace(btrim(coalesce(p_profile ->> 'rc_number', '')), '[^[:alnum:]]', '', 'g'));
  if length(v_if) not between 3 and 32 or length(v_rc) not between 3 and 32 then
    raise exception 'CLIENT_PROFILE_INVALID_IDENTIFIER' using errcode = '22023';
  end if;
  v_profile := p_profile || jsonb_build_object('if_number', v_if, 'rc_number', v_rc);
  v_hash := private.canonical_request_hash(jsonb_build_object(
    'operation', 'client.profile.save.v1',
    'organization_id', p_organization_id,
    'profile', v_profile
  ));

  perform pg_advisory_xact_lock(hashtextextended(
    p_organization_id::text || ':client.profile.save:' || p_idempotency_key, 0
  ));
  select * into v_existing
  from public.idempotency_keys
  where organization_id = p_organization_id
    and operation_scope = 'client.profile.save'
    and key = p_idempotency_key;
  if found then
    if v_existing.request_hash <> v_hash then
      raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode = '22000';
    end if;
    if v_existing.status = 'COMPLETED' then return v_existing.response_body; end if;
    raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode = '55000';
  end if;
  insert into public.idempotency_keys (
    organization_id, operation_scope, key, request_hash, created_by, expires_at
  ) values (
    p_organization_id, 'client.profile.save', p_idempotency_key, v_hash,
    v_actor, clock_timestamp() + interval '7 days'
  );

  select * into v_organization
  from public.organizations
  where id = p_organization_id
    and status not in ('SUSPENDED', 'ARCHIVED')
  for update;
  if not found then
    raise exception 'ORGANIZATION_NOT_ELIGIBLE' using errcode = '55000';
  end if;
  if not exists (
    select 1 from public.organization_identifiers identifier
    where identifier.organization_id = p_organization_id
      and identifier.identifier_type = 'ICE' and identifier.is_active
  ) then
    raise exception 'ACTIVE_ICE_REQUIRED' using errcode = '22023';
  end if;

  insert into public.client_compliance_cases (organization_id, created_by)
  values (p_organization_id, v_actor)
  on conflict (organization_id) do nothing;
  select * into v_case
  from public.client_compliance_cases
  where organization_id = p_organization_id
  for update;

  if v_case.status in ('UNDER_REVIEW', 'RESPONSE_RECEIVED', 'VERIFIED', 'SUSPENDED') then
    raise exception 'CLIENT_PROFILE_NOT_EDITABLE' using errcode = '55000';
  end if;

  if exists (
    select 1 from public.organization_identifiers identifier
    where identifier.organization_id = p_organization_id
      and identifier.identifier_type = 'IF' and identifier.is_active
      and identifier.normalized_value::text <> v_if
  ) or exists (
    select 1 from public.organization_identifiers identifier
    where identifier.organization_id = p_organization_id
      and identifier.identifier_type = 'RC' and identifier.is_active
      and identifier.normalized_value::text <> v_rc
  ) then
    raise exception 'IDENTIFIER_CHANGE_REQUIRES_REVIEW' using errcode = '55000';
  end if;

  insert into public.organization_identifiers (
    organization_id, identifier_type, normalized_value, verification_status, is_active
  ) values
    (p_organization_id, 'IF', v_if, 'UNVERIFIED', true),
    (p_organization_id, 'RC', v_rc, 'UNVERIFIED', true)
  on conflict (organization_id, identifier_type, normalized_value) do update
    set is_active = true;

  select jsonb_build_object(
    'legal_name', v_organization.legal_name,
    'display_name', v_organization.display_name,
    'country_code', v_organization.country_code,
    'row_version', v_organization.row_version,
    'identifiers', coalesce((
      select jsonb_object_agg(identifier.identifier_type, identifier.normalized_value::text)
      from public.organization_identifiers identifier
      where identifier.organization_id = p_organization_id and identifier.is_active
    ), '{}'::jsonb)
  ) into v_snapshot;

  v_version := coalesce(v_case.current_profile_version, 0) + 1;
  insert into public.client_profile_versions (
    compliance_case_id, organization_id, version, profile_data,
    organization_snapshot, source_organization_row_version, created_by
  ) values (
    v_case.id, p_organization_id, v_version, v_profile,
    v_snapshot, v_organization.row_version, v_actor
  );

  update public.client_compliance_cases
  set current_profile_version = v_version,
      status = 'PROFILE_IN_PROGRESS',
      submitted_at = null,
      decided_by = null,
      decided_at = null,
      decision_reason_public = null
  where id = v_case.id;

  v_response := jsonb_build_object(
    'outcome', 'CLIENT_PROFILE_VERSION_CREATED',
    'compliance_case_id', v_case.id,
    'organization_id', p_organization_id,
    'profile_version', v_version,
    'status', 'PROFILE_IN_PROGRESS'
  );
  insert into public.audit_events (
    organization_id, actor_user_id, actor_type, action, resource_type,
    resource_id, correlation_id, metadata, previous_hash, event_hash
  ) values (
    p_organization_id, v_actor, 'USER', 'client.profile.version.created',
    'client_compliance_case', v_case.id::text, p_correlation_id,
    jsonb_build_object('profile_version', v_version), null, repeat('0', 64)
  );
  insert into public.event_outbox (
    organization_id, aggregate_type, aggregate_id, event_type,
    correlation_id, payload
  ) values (
    p_organization_id, 'client_compliance_case', v_case.id::text,
    'ClientProfileVersionCreatedV1', p_correlation_id,
    jsonb_build_object(
      'compliance_case_id', v_case.id,
      'organization_id', p_organization_id,
      'profile_version', v_version
    )
  );
  update public.idempotency_keys
  set status = 'COMPLETED', response_code = 201, response_body = v_response,
      completed_at = clock_timestamp()
  where organization_id = p_organization_id
    and operation_scope = 'client.profile.save' and key = p_idempotency_key;
  return v_response;
end;
$$;

create or replace function public.submit_client_compliance(
  p_compliance_case_id uuid,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_case public.client_compliance_cases%rowtype;
  v_hash text;
  v_existing public.idempotency_keys%rowtype;
  v_response jsonb;
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode = '42501'; end if;
  select * into v_case from public.client_compliance_cases
  where id = p_compliance_case_id for update;
  if not found then raise exception 'COMPLIANCE_CASE_NOT_FOUND' using errcode = 'P0002'; end if;
  if coalesce(private.has_org_role(v_case.organization_id, array['CLIENT_OWNER', 'CLIENT_ADMIN'], v_actor), false) is not true then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if length(coalesce(p_idempotency_key, '')) not between 8 and 200 then
    raise exception 'INVALID_IDEMPOTENCY_KEY' using errcode = '22023';
  end if;
  v_hash := private.canonical_request_hash(jsonb_build_object(
    'operation', 'client.compliance.submit.v1', 'case_id', p_compliance_case_id,
    'profile_version', v_case.current_profile_version
  ));
  perform pg_advisory_xact_lock(hashtextextended(
    v_case.organization_id::text || ':client.compliance.submit:' || p_idempotency_key, 0
  ));
  select * into v_existing from public.idempotency_keys
  where organization_id = v_case.organization_id
    and operation_scope = 'client.compliance.submit' and key = p_idempotency_key;
  if found then
    if v_existing.request_hash <> v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode = '22000'; end if;
    if v_existing.status = 'COMPLETED' then return v_existing.response_body; end if;
    raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode = '55000';
  end if;
  if v_case.current_profile_version is null
     or v_case.status not in ('PROFILE_IN_PROGRESS', 'DOCUMENTS_REQUIRED') then
    raise exception 'INVALID_COMPLIANCE_TRANSITION' using errcode = '55000';
  end if;
  insert into public.idempotency_keys (
    organization_id, operation_scope, key, request_hash, created_by, expires_at
  ) values (
    v_case.organization_id, 'client.compliance.submit', p_idempotency_key,
    v_hash, v_actor, clock_timestamp() + interval '7 days'
  );
  update public.client_compliance_cases
  set status = 'UNDER_REVIEW', submitted_at = clock_timestamp(),
      decided_by = null, decided_at = null, decision_reason_public = null
  where id = p_compliance_case_id;
  v_response := jsonb_build_object(
    'outcome', 'CLIENT_COMPLIANCE_SUBMITTED',
    'compliance_case_id', p_compliance_case_id,
    'organization_id', v_case.organization_id,
    'profile_version', v_case.current_profile_version,
    'status', 'UNDER_REVIEW'
  );
  insert into public.audit_events (
    organization_id, actor_user_id, actor_type, action, resource_type,
    resource_id, correlation_id, metadata, previous_hash, event_hash
  ) values (
    v_case.organization_id, v_actor, 'USER', 'client.compliance.submitted',
    'client_compliance_case', p_compliance_case_id::text, p_correlation_id,
    jsonb_build_object('profile_version', v_case.current_profile_version), null, repeat('0', 64)
  );
  insert into public.event_outbox (
    organization_id, aggregate_type, aggregate_id, event_type,
    correlation_id, payload
  ) values (
    v_case.organization_id, 'client_compliance_case', p_compliance_case_id::text,
    'ClientComplianceSubmittedV1', p_correlation_id,
    jsonb_build_object(
      'compliance_case_id', p_compliance_case_id,
      'organization_id', v_case.organization_id,
      'profile_version', v_case.current_profile_version
    )
  );
  update public.idempotency_keys
  set status = 'COMPLETED', response_code = 202, response_body = v_response,
      completed_at = clock_timestamp()
  where organization_id = v_case.organization_id
    and operation_scope = 'client.compliance.submit' and key = p_idempotency_key;
  return v_response;
end;
$$;

create or replace function public.decide_client_compliance(
  p_compliance_case_id uuid,
  p_decision text,
  p_reason_public text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_case public.client_compliance_cases%rowtype;
  v_hash text;
  v_existing public.idempotency_keys%rowtype;
  v_response jsonb;
  v_now timestamptz := clock_timestamp();
  v_trial_id uuid;
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode = '42501'; end if;
  if not private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'COMPLIANCE_MANAGER'], v_actor) then
    raise exception 'CENTRAL_COMPLIANCE_APPROVAL_REQUIRED' using errcode = '42501';
  end if;
  if p_decision is null
     or p_decision not in ('VERIFIED', 'QUESTION_REQUIRED', 'REJECTED')
     or length(coalesce(p_idempotency_key, '')) not between 8 and 200
     or (p_reason_public is not null and btrim(p_reason_public) <> ''
         and length(btrim(p_reason_public)) not between 3 and 1000)
     or (p_decision in ('QUESTION_REQUIRED', 'REJECTED')
         and length(btrim(coalesce(p_reason_public, ''))) not between 3 and 1000) then
    raise exception 'INVALID_COMPLIANCE_DECISION' using errcode = '22023';
  end if;
  select * into v_case from public.client_compliance_cases
  where id = p_compliance_case_id for update;
  if not found then raise exception 'COMPLIANCE_CASE_NOT_FOUND' using errcode = 'P0002'; end if;

  v_hash := private.canonical_request_hash(jsonb_build_object(
    'operation', 'client.compliance.decide.v1',
    'case_id', p_compliance_case_id,
    'decision', p_decision,
    'reason_public', nullif(btrim(p_reason_public), '')
  ));
  perform pg_advisory_xact_lock(hashtextextended(
    v_case.organization_id::text || ':client.compliance.decide:' || p_idempotency_key, 0
  ));
  select * into v_existing from public.idempotency_keys
  where organization_id = v_case.organization_id
    and operation_scope = 'client.compliance.decide' and key = p_idempotency_key;
  if found then
    if v_existing.request_hash <> v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode = '22000'; end if;
    if v_existing.status = 'COMPLETED' then return v_existing.response_body; end if;
    raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode = '55000';
  end if;
  if v_case.status not in ('UNDER_REVIEW', 'RESPONSE_RECEIVED') then
    raise exception 'INVALID_COMPLIANCE_TRANSITION' using errcode = '55000';
  end if;
  insert into public.idempotency_keys (
    organization_id, operation_scope, key, request_hash, created_by, expires_at
  ) values (
    v_case.organization_id, 'client.compliance.decide', p_idempotency_key,
    v_hash, v_actor, v_now + interval '7 days'
  );

  if p_decision = 'VERIFIED' then
    if v_case.current_profile_version is null then
      raise exception 'CLIENT_PROFILE_REQUIRED' using errcode = '55000';
    end if;
    update public.organizations
    set status = 'ACTIVE'
    where id = v_case.organization_id and status = 'PENDING';
    if not exists (
      select 1 from public.organizations organization
      where organization.id = v_case.organization_id and organization.status = 'ACTIVE'
    ) then
      raise exception 'ORGANIZATION_ACTIVATION_FORBIDDEN' using errcode = '55000';
    end if;
    update public.client_compliance_cases
    set status = 'VERIFIED', decided_by = v_actor, decided_at = v_now,
        decision_reason_public = nullif(btrim(p_reason_public), ''),
        verified_at = v_now, activated_at = v_now
    where id = p_compliance_case_id;
    insert into public.client_trials (
      organization_id, compliance_case_id, verified_profile_version,
      status, trial_started_at, trial_ends_at, activated_by
    ) values (
      v_case.organization_id, p_compliance_case_id, v_case.current_profile_version,
      'TRIAL_ACTIVE', v_now, v_now + interval '30 days', v_actor
    ) returning id into v_trial_id;
  else
    update public.client_compliance_cases
    set status = p_decision, decided_by = v_actor, decided_at = v_now,
        decision_reason_public = btrim(p_reason_public)
    where id = p_compliance_case_id;
  end if;

  v_response := jsonb_build_object(
    'outcome', 'CLIENT_COMPLIANCE_' || p_decision,
    'compliance_case_id', p_compliance_case_id,
    'organization_id', v_case.organization_id,
    'status', p_decision,
    'trial_id', v_trial_id
  );
  insert into public.audit_events (
    organization_id, actor_user_id, actor_type, action, resource_type,
    resource_id, correlation_id, metadata, previous_hash, event_hash
  ) values (
    v_case.organization_id, v_actor, 'USER', 'client.compliance.decided',
    'client_compliance_case', p_compliance_case_id::text, p_correlation_id,
    jsonb_build_object(
      'decision', p_decision,
      'profile_version', v_case.current_profile_version,
      'public_reason_provided', nullif(btrim(p_reason_public), '') is not null
    ), null, repeat('0', 64)
  );
  insert into public.event_outbox (
    organization_id, aggregate_type, aggregate_id, event_type,
    correlation_id, payload
  ) values (
    v_case.organization_id, 'client_compliance_case', p_compliance_case_id::text,
    case p_decision
      when 'VERIFIED' then 'OrganizationVerifiedV1'
      when 'QUESTION_REQUIRED' then 'ClientComplianceQuestionRequiredV1'
      else 'ClientComplianceRejectedV1'
    end,
    p_correlation_id,
    jsonb_build_object(
      'compliance_case_id', p_compliance_case_id,
      'organization_id', v_case.organization_id,
      'status', p_decision,
      'profile_version', v_case.current_profile_version
    )
  );
  if p_decision = 'VERIFIED' then
    insert into public.audit_events (
      organization_id, actor_user_id, actor_type, action, resource_type,
      resource_id, correlation_id, metadata, previous_hash, event_hash
    ) values (
      v_case.organization_id, v_actor, 'USER', 'client.trial.started',
      'client_trial', v_trial_id::text, p_correlation_id,
      jsonb_build_object('duration_days', 30), null, repeat('0', 64)
    );
    insert into public.event_outbox (
      organization_id, aggregate_type, aggregate_id, event_type,
      correlation_id, payload
    ) values (
      v_case.organization_id, 'client_trial', v_trial_id::text,
      'TrialStartedV1', p_correlation_id,
      jsonb_build_object(
        'trial_id', v_trial_id,
        'organization_id', v_case.organization_id,
        'trial_started_at', v_now,
        'trial_ends_at', v_now + interval '30 days'
      )
    );
  end if;
  update public.idempotency_keys
  set status = 'COMPLETED', response_code = 200, response_body = v_response,
      completed_at = clock_timestamp()
  where organization_id = v_case.organization_id
    and operation_scope = 'client.compliance.decide' and key = p_idempotency_key;
  return v_response;
end;
$$;

alter table public.client_compliance_cases enable row level security;
alter table public.client_profile_versions enable row level security;
alter table public.client_trials enable row level security;

revoke all on public.client_compliance_cases, public.client_profile_versions, public.client_trials
  from public, anon, authenticated, service_role;
grant select on public.client_compliance_cases, public.client_profile_versions, public.client_trials
  to authenticated;

create policy client_compliance_cases_read
on public.client_compliance_cases for select to authenticated
using (
  private.has_org_role(organization_id, array[
    'CLIENT_OWNER', 'CLIENT_ADMIN', 'CLIENT_BUYER', 'CLIENT_ACCOUNTING',
    'CLIENT_MEMBER', 'CLIENT_VIEWER'
  ])
  or private.has_platform_role(array[
    'SUPER_ADMIN', 'MATRICIA_ADMIN', 'COMPLIANCE_MANAGER', 'READ_ONLY_AUDITOR'
  ])
);

create policy client_profile_versions_read
on public.client_profile_versions for select to authenticated
using (
  private.has_org_role(organization_id, array['CLIENT_OWNER', 'CLIENT_ADMIN'])
  or private.has_platform_role(array[
    'SUPER_ADMIN', 'MATRICIA_ADMIN', 'COMPLIANCE_MANAGER'
  ])
);

create policy client_trials_read
on public.client_trials for select to authenticated
using (
  private.has_org_role(organization_id, array[
    'CLIENT_OWNER', 'CLIENT_ADMIN', 'CLIENT_BUYER', 'CLIENT_ACCOUNTING',
    'CLIENT_MEMBER', 'CLIENT_VIEWER'
  ])
  or private.has_platform_role(array[
    'SUPER_ADMIN', 'MATRICIA_ADMIN', 'COMPLIANCE_MANAGER', 'READ_ONLY_AUDITOR'
  ])
);

create trigger client_profile_versions_immutable
before update or delete on public.client_profile_versions
for each row execute function private.prevent_update_delete();
create trigger client_compliance_cases_updated_at
before update on public.client_compliance_cases
for each row execute function private.set_updated_at();
create trigger client_trials_updated_at
before update on public.client_trials
for each row execute function private.set_updated_at();

create index client_compliance_cases_review_queue_idx
  on public.client_compliance_cases (status, submitted_at, id)
  where status in ('UNDER_REVIEW', 'RESPONSE_RECEIVED');
create index client_profile_versions_org_created_idx
  on public.client_profile_versions (organization_id, created_at desc, version desc);
create index client_trials_status_end_idx
  on public.client_trials (status, trial_ends_at, id);

revoke all on function public.save_client_profile_draft(uuid, jsonb, text, uuid),
  public.submit_client_compliance(uuid, text, uuid),
  public.decide_client_compliance(uuid, text, text, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.save_client_profile_draft(uuid, jsonb, text, uuid),
  public.submit_client_compliance(uuid, text, uuid),
  public.decide_client_compliance(uuid, text, text, text, uuid)
  to authenticated;

notify pgrst, 'reload schema';
