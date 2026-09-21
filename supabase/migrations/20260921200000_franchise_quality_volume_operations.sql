-- FR-009/010/011 versioned anomaly/risk/recommendation definitions.
-- FR-016 franchisee service qualification (company/document/restriction stay platform).
-- FR-022 first-level incident instruction (client still opens; platform still decides).
-- FR-035 franchise volume proposal (admin still creates framework drafts).
-- Additive; no production secrets; authenticated tables remain SELECT-only.

create table public.anomaly_definitions (
  id uuid primary key default extensions.gen_random_uuid(),
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  definition_key text not null check (definition_key ~ '^[A-Z][A-Z0-9_.-]{1,119}$'),
  status text not null default 'PUBLISHED' check (status in ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
  current_version_id uuid,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check (row_version > 0),
  unique (library_id, definition_key)
);

create table public.anomaly_definition_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  definition_id uuid not null references public.anomaly_definitions(id) on delete restrict,
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  version integer not null check (version > 0),
  severity text not null check (severity in ('INFO', 'MINOR', 'IMPORTANT', 'CRITICAL')),
  title_fr text not null check (length(btrim(title_fr)) between 2 and 240),
  title_ar text not null check (length(btrim(title_ar)) between 2 and 240),
  description_fr text not null check (length(btrim(description_fr)) between 3 and 4000),
  description_ar text not null check (length(btrim(description_ar)) between 3 and 4000),
  blocking boolean not null,
  evidence_required boolean not null,
  detected_by_rule_key text check (detected_by_rule_key is null or detected_by_rule_key ~ '^[A-Z][A-Z0-9_.-]{1,119}$'),
  change_reason text not null check (length(btrim(change_reason)) between 3 and 500),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (definition_id, version)
);

create table public.risk_definitions (
  id uuid primary key default extensions.gen_random_uuid(),
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  definition_key text not null check (definition_key ~ '^[A-Z][A-Z0-9_.-]{1,119}$'),
  status text not null default 'PUBLISHED' check (status in ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
  current_version_id uuid,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check (row_version > 0),
  unique (library_id, definition_key)
);

create table public.risk_definition_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  definition_id uuid not null references public.risk_definitions(id) on delete restrict,
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  version integer not null check (version > 0),
  impact text not null check (impact in ('LOW', 'MEDIUM', 'HIGH')),
  probability text not null check (probability in ('LOW', 'MEDIUM', 'HIGH')),
  criticality text not null check (criticality in ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
  title_fr text not null check (length(btrim(title_fr)) between 2 and 240),
  title_ar text not null check (length(btrim(title_ar)) between 2 and 240),
  description_fr text not null check (length(btrim(description_fr)) between 3 and 4000),
  description_ar text not null check (length(btrim(description_ar)) between 3 and 4000),
  change_reason text not null check (length(btrim(change_reason)) between 3 and 500),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (definition_id, version)
);

create table public.recommendation_definitions (
  id uuid primary key default extensions.gen_random_uuid(),
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  definition_key text not null check (definition_key ~ '^[A-Z][A-Z0-9_.-]{1,119}$'),
  status text not null default 'PUBLISHED' check (status in ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
  current_version_id uuid,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check (row_version > 0),
  unique (library_id, definition_key)
);

create table public.recommendation_definition_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  definition_id uuid not null references public.recommendation_definitions(id) on delete restrict,
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  version integer not null check (version > 0),
  service_id uuid not null references public.catalog_services(id) on delete restrict,
  anomaly_definition_id uuid references public.anomaly_definitions(id) on delete restrict,
  solution_level text not null check (solution_level in ('ESSENTIAL', 'STANDARD', 'ADVANCED')),
  priority integer not null check (priority between 1 and 100),
  title_fr text not null check (length(btrim(title_fr)) between 2 and 240),
  title_ar text not null check (length(btrim(title_ar)) between 2 and 240),
  client_text_fr text not null check (length(btrim(client_text_fr)) between 3 and 4000),
  client_text_ar text not null check (length(btrim(client_text_ar)) between 3 and 4000),
  technical_text_fr text not null check (length(btrim(technical_text_fr)) between 3 and 4000),
  technical_text_ar text not null check (length(btrim(technical_text_ar)) between 3 and 4000),
  change_reason text not null check (length(btrim(change_reason)) between 3 and 500),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (definition_id, version)
);

create table public.franchise_volume_proposals (
  id uuid primary key default extensions.gen_random_uuid(),
  franchise_id uuid not null references public.franchises(id) on delete restrict,
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  sku_id uuid not null references public.service_skus(id) on delete restrict,
  service_id uuid not null references public.catalog_services(id) on delete restrict,
  status text not null default 'PROPOSED' check (status in ('PROPOSED', 'UNDER_REVIEW', 'ACCEPTED', 'REJECTED', 'WITHDRAWN')),
  forecast_units numeric(20, 6) not null check (forecast_units > 0),
  minimum_commitment_units numeric(20, 6) not null check (minimum_commitment_units >= 0),
  maximum_units numeric(20, 6) not null check (maximum_units > 0),
  payment_model text not null check (payment_model in ('PAY_PER_USE', 'PREPAID', 'HYBRID')),
  period_start date not null,
  period_end date not null,
  rationale text not null check (length(btrim(rationale)) between 10 and 4000),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check (row_version > 0),
  check (period_end >= period_start),
  check (minimum_commitment_units <= maximum_units),
  check (forecast_units <= maximum_units)
);

create index anomaly_definitions_library_idx on public.anomaly_definitions (library_id, definition_key);
create index risk_definitions_library_idx on public.risk_definitions (library_id, definition_key);
create index recommendation_definitions_library_idx on public.recommendation_definitions (library_id, definition_key);
create index franchise_volume_proposals_library_idx on public.franchise_volume_proposals (library_id, created_at desc);

alter table public.anomaly_definitions
  add constraint anomaly_definitions_current_version_fk
  foreign key (current_version_id) references public.anomaly_definition_versions(id) on delete restrict;
alter table public.risk_definitions
  add constraint risk_definitions_current_version_fk
  foreign key (current_version_id) references public.risk_definition_versions(id) on delete restrict;
alter table public.recommendation_definitions
  add constraint recommendation_definitions_current_version_fk
  foreign key (current_version_id) references public.recommendation_definition_versions(id) on delete restrict;

create or replace function private.can_maintain_franchise_definitions(p_library_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select p_library_id is not null
     and p_actor is not null
     and exists (
       select 1
       from public.franchises f
       where f.library_id = p_library_id
         and f.status = 'ACTIVE'
         and private.franchise_access(f.id, p_actor)
         and private.has_org_role(
           f.operator_organization_id,
           array['FRANCHISE_OWNER', 'FRANCHISE_MANAGER', 'FRANCHISE_EXPERT'],
           p_actor
         )
     );
$$;

create or replace function private.can_decide_franchise_service_qualification(p_service_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select p_service_id is not null
     and p_actor is not null
     and exists (
       select 1
       from public.catalog_services s
       join public.franchises f on f.library_id = s.library_id and f.status = 'ACTIVE'
       where s.id = p_service_id
         and private.franchise_access(f.id, p_actor)
         and private.has_org_role(
           f.operator_organization_id,
           array['FRANCHISE_OWNER', 'FRANCHISE_MANAGER', 'FRANCHISE_EXPERT', 'FRANCHISE_PROVIDER_MANAGER'],
           p_actor
         )
     );
$$;

create or replace function private.franchise_supervises_dispute(p_case_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.dispute_cases d
    join public.missions m on m.id = d.mission_id
    where d.id = p_case_id
      and private.franchise_supervises_contract(m.contract_id, p_actor)
  );
$$;

create or replace function private.dispute_case_access(p_case_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.dispute_cases d
    where d.id = p_case_id
      and (
        private.is_active_org_member(d.client_organization_id, p_actor)
        or private.is_active_org_member(d.provider_organization_id, p_actor)
      )
  )
  or private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'DISPUTE_MANAGER', 'READ_ONLY_AUDITOR'], p_actor)
  or private.franchise_supervises_dispute(p_case_id, p_actor);
$$;

create or replace function private.dispute_evidence_access(p_evidence_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.dispute_evidence e
    join public.dispute_cases d on d.id = e.dispute_case_id
    where e.id = p_evidence_id
      and (
        private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'DISPUTE_MANAGER', 'READ_ONLY_AUDITOR'], p_actor)
        or (e.visibility = 'BOTH_PARTIES' and (
          private.is_active_org_member(d.client_organization_id, p_actor)
          or private.is_active_org_member(d.provider_organization_id, p_actor)
          or private.franchise_supervises_dispute(d.id, p_actor)
        ))
        or (e.visibility = 'CLIENT_ONLY' and private.is_active_org_member(d.client_organization_id, p_actor))
        or (e.visibility = 'PROVIDER_ONLY' and private.is_active_org_member(d.provider_organization_id, p_actor))
        or (e.visibility = 'MEDIATOR_ONLY' and (
          private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'DISPUTE_MANAGER'], p_actor)
          or private.franchise_supervises_dispute(d.id, p_actor)
        ))
      )
  );
$$;

create or replace function public.upsert_franchise_anomaly_definition(
  p_library_id uuid,
  p_definition_key text,
  p_severity text,
  p_title_fr text,
  p_title_ar text,
  p_description_fr text,
  p_description_ar text,
  p_blocking boolean,
  p_evidence_required boolean,
  p_detected_by_rule_key text,
  p_change_reason text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, extensions, private, public
as $$
declare
  v_actor uuid := auth.uid();
  v_org uuid;
  v_hash text;
  v_command uuid;
  v_replay jsonb;
  v_definition uuid;
  v_version integer;
  v_version_id uuid;
  v_response jsonb;
  v_rule text := nullif(btrim(coalesce(p_detected_by_rule_key, '')), '');
begin
  if v_actor is null or not private.can_maintain_franchise_definitions(p_library_id, v_actor) then
    raise exception 'FRANCHISE_DEFINITION_DENIED' using errcode = '42501';
  end if;
  if btrim(coalesce(p_definition_key, '')) !~ '^[A-Z][A-Z0-9_.-]{1,119}$'
     or p_severity not in ('INFO', 'MINOR', 'IMPORTANT', 'CRITICAL')
     or length(btrim(coalesce(p_title_fr, ''))) not between 2 and 240
     or length(btrim(coalesce(p_title_ar, ''))) not between 2 and 240
     or length(btrim(coalesce(p_description_fr, ''))) not between 3 and 4000
     or length(btrim(coalesce(p_description_ar, ''))) not between 3 and 4000
     or length(btrim(coalesce(p_change_reason, ''))) not between 3 and 500
     or (v_rule is not null and v_rule !~ '^[A-Z][A-Z0-9_.-]{1,119}$')
  then
    raise exception 'INVALID_ANOMALY_DEFINITION' using errcode = '22023';
  end if;
  select steward_organization_id into v_org from public.catalog_libraries where id = p_library_id;
  if not found then raise exception 'CATALOG_LIBRARY_NOT_FOUND' using errcode = 'P0002'; end if;
  v_hash := private.canonical_request_hash(jsonb_build_object(
    'operation', 'franchise.anomaly.definition.upsert.v1',
    'library_id', p_library_id, 'key', btrim(p_definition_key), 'severity', p_severity,
    'title_fr', btrim(p_title_fr), 'title_ar', btrim(p_title_ar),
    'description_fr', btrim(p_description_fr), 'description_ar', btrim(p_description_ar),
    'blocking', p_blocking, 'evidence_required', p_evidence_required,
    'rule_key', v_rule, 'reason', btrim(p_change_reason)
  ));
  select b.command_id, b.response_body into v_command, v_replay
    from private.begin_catalog_command(v_actor, 'franchise.anomaly.definition.upsert', p_idempotency_key, v_hash) b;
  if v_replay is not null then return v_replay; end if;
  perform pg_advisory_xact_lock(hashtextextended('franchise-anomaly-def:' || p_library_id::text || ':' || btrim(p_definition_key), 0));
  insert into public.anomaly_definitions (library_id, definition_key, created_by)
  values (p_library_id, btrim(p_definition_key), v_actor)
  on conflict (library_id, definition_key) do update set row_version = public.anomaly_definitions.row_version
  returning id into v_definition;
  select coalesce(max(version), 0) + 1 into v_version from public.anomaly_definition_versions where definition_id = v_definition;
  insert into public.anomaly_definition_versions (
    definition_id, library_id, version, severity, title_fr, title_ar, description_fr, description_ar,
    blocking, evidence_required, detected_by_rule_key, change_reason, content_hash, created_by
  ) values (
    v_definition, p_library_id, v_version, p_severity, btrim(p_title_fr), btrim(p_title_ar),
    btrim(p_description_fr), btrim(p_description_ar), p_blocking, p_evidence_required, v_rule,
    btrim(p_change_reason), v_hash, v_actor
  ) returning id into v_version_id;
  update public.anomaly_definitions
     set current_version_id = v_version_id, status = 'PUBLISHED', row_version = row_version + 1
   where id = v_definition;
  v_response := jsonb_build_object(
    'outcome', 'ANOMALY_DEFINITION_UPSERTED', 'definition_id', v_definition,
    'version_id', v_version_id, 'version', v_version, 'command_id', v_command
  );
  insert into public.audit_events (organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (v_org, v_actor, 'USER', 'franchise.anomaly.definition.upserted', 'anomaly_definition', v_definition::text, p_correlation_id, v_response, repeat('0', 64));
  insert into public.event_outbox (organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key, causation_id)
  values (v_org, 'anomaly_definition', v_definition::text, 'AnomalyDefinitionUpsertedV1', p_correlation_id, v_response, p_idempotency_key, v_command);
  perform private.finish_catalog_command(v_actor, 'franchise.anomaly.definition.upsert', p_idempotency_key, v_response);
  return v_response;
end
$$;

create or replace function public.upsert_franchise_risk_definition(
  p_library_id uuid,
  p_definition_key text,
  p_impact text,
  p_probability text,
  p_title_fr text,
  p_title_ar text,
  p_description_fr text,
  p_description_ar text,
  p_change_reason text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, extensions, private, public
as $$
declare
  v_actor uuid := auth.uid();
  v_org uuid;
  v_hash text;
  v_command uuid;
  v_replay jsonb;
  v_definition uuid;
  v_version integer;
  v_version_id uuid;
  v_criticality text;
  v_response jsonb;
begin
  if v_actor is null or not private.can_maintain_franchise_definitions(p_library_id, v_actor) then
    raise exception 'FRANCHISE_DEFINITION_DENIED' using errcode = '42501';
  end if;
  if btrim(coalesce(p_definition_key, '')) !~ '^[A-Z][A-Z0-9_.-]{1,119}$'
     or p_impact not in ('LOW', 'MEDIUM', 'HIGH')
     or p_probability not in ('LOW', 'MEDIUM', 'HIGH')
     or length(btrim(coalesce(p_title_fr, ''))) not between 2 and 240
     or length(btrim(coalesce(p_title_ar, ''))) not between 2 and 240
     or length(btrim(coalesce(p_description_fr, ''))) not between 3 and 4000
     or length(btrim(coalesce(p_description_ar, ''))) not between 3 and 4000
     or length(btrim(coalesce(p_change_reason, ''))) not between 3 and 500
  then
    raise exception 'INVALID_RISK_DEFINITION' using errcode = '22023';
  end if;
  v_criticality := case
    when p_impact = 'HIGH' and p_probability = 'HIGH' then 'CRITICAL'
    when p_impact = 'HIGH' or p_probability = 'HIGH' then 'HIGH'
    when p_impact = 'MEDIUM' or p_probability = 'MEDIUM' then 'MEDIUM'
    else 'LOW'
  end;
  select steward_organization_id into v_org from public.catalog_libraries where id = p_library_id;
  if not found then raise exception 'CATALOG_LIBRARY_NOT_FOUND' using errcode = 'P0002'; end if;
  v_hash := private.canonical_request_hash(jsonb_build_object(
    'operation', 'franchise.risk.definition.upsert.v1',
    'library_id', p_library_id, 'key', btrim(p_definition_key),
    'impact', p_impact, 'probability', p_probability, 'criticality', v_criticality,
    'title_fr', btrim(p_title_fr), 'title_ar', btrim(p_title_ar),
    'description_fr', btrim(p_description_fr), 'description_ar', btrim(p_description_ar),
    'reason', btrim(p_change_reason)
  ));
  select b.command_id, b.response_body into v_command, v_replay
    from private.begin_catalog_command(v_actor, 'franchise.risk.definition.upsert', p_idempotency_key, v_hash) b;
  if v_replay is not null then return v_replay; end if;
  perform pg_advisory_xact_lock(hashtextextended('franchise-risk-def:' || p_library_id::text || ':' || btrim(p_definition_key), 0));
  insert into public.risk_definitions (library_id, definition_key, created_by)
  values (p_library_id, btrim(p_definition_key), v_actor)
  on conflict (library_id, definition_key) do update set row_version = public.risk_definitions.row_version
  returning id into v_definition;
  select coalesce(max(version), 0) + 1 into v_version from public.risk_definition_versions where definition_id = v_definition;
  insert into public.risk_definition_versions (
    definition_id, library_id, version, impact, probability, criticality, title_fr, title_ar,
    description_fr, description_ar, change_reason, content_hash, created_by
  ) values (
    v_definition, p_library_id, v_version, p_impact, p_probability, v_criticality,
    btrim(p_title_fr), btrim(p_title_ar), btrim(p_description_fr), btrim(p_description_ar),
    btrim(p_change_reason), v_hash, v_actor
  ) returning id into v_version_id;
  update public.risk_definitions
     set current_version_id = v_version_id, status = 'PUBLISHED', row_version = row_version + 1
   where id = v_definition;
  v_response := jsonb_build_object(
    'outcome', 'RISK_DEFINITION_UPSERTED', 'definition_id', v_definition,
    'version_id', v_version_id, 'version', v_version, 'criticality', v_criticality, 'command_id', v_command
  );
  insert into public.audit_events (organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (v_org, v_actor, 'USER', 'franchise.risk.definition.upserted', 'risk_definition', v_definition::text, p_correlation_id, v_response, repeat('0', 64));
  insert into public.event_outbox (organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key, causation_id)
  values (v_org, 'risk_definition', v_definition::text, 'RiskDefinitionUpsertedV1', p_correlation_id, v_response, p_idempotency_key, v_command);
  perform private.finish_catalog_command(v_actor, 'franchise.risk.definition.upsert', p_idempotency_key, v_response);
  return v_response;
end
$$;

create or replace function public.upsert_franchise_recommendation_definition(
  p_library_id uuid,
  p_definition_key text,
  p_service_id uuid,
  p_anomaly_definition_id uuid,
  p_solution_level text,
  p_priority integer,
  p_title_fr text,
  p_title_ar text,
  p_client_text_fr text,
  p_client_text_ar text,
  p_technical_text_fr text,
  p_technical_text_ar text,
  p_change_reason text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, extensions, private, public
as $$
declare
  v_actor uuid := auth.uid();
  v_org uuid;
  v_hash text;
  v_command uuid;
  v_replay jsonb;
  v_definition uuid;
  v_version integer;
  v_version_id uuid;
  v_response jsonb;
begin
  if v_actor is null or not private.can_maintain_franchise_definitions(p_library_id, v_actor) then
    raise exception 'FRANCHISE_DEFINITION_DENIED' using errcode = '42501';
  end if;
  if btrim(coalesce(p_definition_key, '')) !~ '^[A-Z][A-Z0-9_.-]{1,119}$'
     or p_solution_level not in ('ESSENTIAL', 'STANDARD', 'ADVANCED')
     or p_priority not between 1 and 100
     or length(btrim(coalesce(p_title_fr, ''))) not between 2 and 240
     or length(btrim(coalesce(p_title_ar, ''))) not between 2 and 240
     or length(btrim(coalesce(p_client_text_fr, ''))) not between 3 and 4000
     or length(btrim(coalesce(p_client_text_ar, ''))) not between 3 and 4000
     or length(btrim(coalesce(p_technical_text_fr, ''))) not between 3 and 4000
     or length(btrim(coalesce(p_technical_text_ar, ''))) not between 3 and 4000
     or length(btrim(coalesce(p_change_reason, ''))) not between 3 and 500
     or not exists (select 1 from public.catalog_services s where s.id = p_service_id and s.library_id = p_library_id and s.status <> 'ARCHIVED')
     or (p_anomaly_definition_id is not null and not exists (
       select 1 from public.anomaly_definitions a where a.id = p_anomaly_definition_id and a.library_id = p_library_id
     ))
  then
    raise exception 'INVALID_RECOMMENDATION_DEFINITION' using errcode = '22023';
  end if;
  select steward_organization_id into v_org from public.catalog_libraries where id = p_library_id;
  if not found then raise exception 'CATALOG_LIBRARY_NOT_FOUND' using errcode = 'P0002'; end if;
  v_hash := private.canonical_request_hash(jsonb_build_object(
    'operation', 'franchise.recommendation.definition.upsert.v1',
    'library_id', p_library_id, 'key', btrim(p_definition_key), 'service_id', p_service_id,
    'anomaly_definition_id', p_anomaly_definition_id, 'solution_level', p_solution_level, 'priority', p_priority,
    'title_fr', btrim(p_title_fr), 'title_ar', btrim(p_title_ar),
    'client_text_fr', btrim(p_client_text_fr), 'client_text_ar', btrim(p_client_text_ar),
    'technical_text_fr', btrim(p_technical_text_fr), 'technical_text_ar', btrim(p_technical_text_ar),
    'reason', btrim(p_change_reason)
  ));
  select b.command_id, b.response_body into v_command, v_replay
    from private.begin_catalog_command(v_actor, 'franchise.recommendation.definition.upsert', p_idempotency_key, v_hash) b;
  if v_replay is not null then return v_replay; end if;
  perform pg_advisory_xact_lock(hashtextextended('franchise-reco-def:' || p_library_id::text || ':' || btrim(p_definition_key), 0));
  insert into public.recommendation_definitions (library_id, definition_key, created_by)
  values (p_library_id, btrim(p_definition_key), v_actor)
  on conflict (library_id, definition_key) do update set row_version = public.recommendation_definitions.row_version
  returning id into v_definition;
  select coalesce(max(version), 0) + 1 into v_version from public.recommendation_definition_versions where definition_id = v_definition;
  insert into public.recommendation_definition_versions (
    definition_id, library_id, version, service_id, anomaly_definition_id, solution_level, priority,
    title_fr, title_ar, client_text_fr, client_text_ar, technical_text_fr, technical_text_ar,
    change_reason, content_hash, created_by
  ) values (
    v_definition, p_library_id, v_version, p_service_id, p_anomaly_definition_id, p_solution_level, p_priority,
    btrim(p_title_fr), btrim(p_title_ar), btrim(p_client_text_fr), btrim(p_client_text_ar),
    btrim(p_technical_text_fr), btrim(p_technical_text_ar), btrim(p_change_reason), v_hash, v_actor
  ) returning id into v_version_id;
  update public.recommendation_definitions
     set current_version_id = v_version_id, status = 'PUBLISHED', row_version = row_version + 1
   where id = v_definition;
  v_response := jsonb_build_object(
    'outcome', 'RECOMMENDATION_DEFINITION_UPSERTED', 'definition_id', v_definition,
    'version_id', v_version_id, 'version', v_version, 'service_id', p_service_id, 'command_id', v_command
  );
  insert into public.audit_events (organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (v_org, v_actor, 'USER', 'franchise.recommendation.definition.upserted', 'recommendation_definition', v_definition::text, p_correlation_id, v_response, repeat('0', 64));
  insert into public.event_outbox (organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key, causation_id)
  values (v_org, 'recommendation_definition', v_definition::text, 'RecommendationDefinitionUpsertedV1', p_correlation_id, v_response, p_idempotency_key, v_command);
  perform private.finish_catalog_command(v_actor, 'franchise.recommendation.definition.upsert', p_idempotency_key, v_response);
  return v_response;
end
$$;

create or replace function public.instruct_franchise_dispute(
  p_dispute_case_id uuid,
  p_statement text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  d public.dispute_cases%rowtype;
  m public.missions%rowtype;
  v_org uuid;
  h text;
  r jsonb;
  v_hash text;
  v_evidence jsonb;
begin
  select * into d from public.dispute_cases where id = p_dispute_case_id;
  if not found then raise exception 'DISPUTE_NOT_FOUND' using errcode = 'P0002'; end if;
  select * into m from public.missions where id = d.mission_id;
  if a is null or not found or not private.franchise_supervises_contract(m.contract_id, a) then
    raise exception 'FRANCHISE_DISPUTE_INSTRUCTION_DENIED' using errcode = '42501';
  end if;
  select f.operator_organization_id into v_org
    from public.contract_versions cv
    join public.quote_versions qv on qv.id = cv.selected_quote_version_id
    join public.quotes qt on qt.id = qv.quote_id
    join public.rfqs q on q.id = qt.rfq_id
    join public.service_requests sr on sr.id = q.request_id
    join public.franchises f on f.library_id = sr.library_id and f.status = 'ACTIVE'
   where cv.contract_id = m.contract_id
     and private.has_org_role(f.operator_organization_id, array['FRANCHISE_OWNER', 'FRANCHISE_MANAGER', 'FRANCHISE_EXPERT'], a)
   limit 1;
  if v_org is null then
    raise exception 'FRANCHISE_DISPUTE_INSTRUCTION_DENIED' using errcode = '42501';
  end if;
  if d.status in ('DECIDED', 'CLOSED') or length(btrim(coalesce(p_statement, ''))) not between 10 and 4000 then
    raise exception 'INVALID_FRANCHISE_DISPUTE_INSTRUCTION' using errcode = '22023';
  end if;
  v_hash := encode(extensions.digest(convert_to(btrim(p_statement), 'UTF8'), 'sha256'), 'hex');
  v_evidence := jsonb_build_array(jsonb_build_object(
    'type', 'MESSAGE', 'statement', btrim(p_statement), 'hash', v_hash, 'visibility', 'BOTH_PARTIES'
  ));
  h := private.canonical_request_hash(jsonb_build_object('case', d.id, 'statement', btrim(p_statement)));
  r := private.begin_contract_command(v_org, 'dispute.franchise.instruct.' || d.id::text, p_idempotency_key, h, a);
  if r is not null then return r; end if;
  select * into d from public.dispute_cases where id = d.id for update;
  if d.status in ('DECIDED', 'CLOSED') then raise exception 'STALE_DISPUTE_STATE' using errcode = '40001'; end if;
  perform private.append_dispute_evidence(d.id, v_evidence, a, v_org);
  insert into public.dispute_case_events (dispute_case_id, event_type, from_status, to_status, actor_user_id, correlation_id, metadata)
  values (d.id, 'FRANCHISE_INSTRUCTION', d.status, d.status, a, p_correlation_id, jsonb_build_object('visibility', 'BOTH_PARTIES'));
  r := jsonb_build_object('outcome', 'FRANCHISE_DISPUTE_INSTRUCTED', 'dispute_case_id', d.id, 'status', d.status);
  insert into public.audit_events (organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (v_org, a, 'USER', 'franchise.dispute.instructed', 'dispute_case', d.id::text, p_correlation_id, r, repeat('0', 64));
  insert into public.event_outbox (organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (v_org, 'dispute_case', d.id::text, 'FranchiseDisputeInstructedV1', p_correlation_id, r, p_idempotency_key);
  perform private.finish_contract_command(v_org, 'dispute.franchise.instruct.' || d.id::text, p_idempotency_key, r);
  return r;
end
$$;

create or replace function public.propose_franchise_volume_purchase(
  p_library_id uuid,
  p_sku_id uuid,
  p_forecast_units numeric,
  p_minimum_commitment_units numeric,
  p_maximum_units numeric,
  p_payment_model text,
  p_period_start date,
  p_period_end date,
  p_rationale text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  f public.franchises%rowtype;
  s public.service_skus%rowtype;
  v_hash text;
  r jsonb;
  pid uuid;
begin
  select * into f from public.franchises where library_id = p_library_id and status = 'ACTIVE' order by created_at desc limit 1;
  if a is null or not found or not private.franchise_access(f.id, a)
     or not private.has_org_role(f.operator_organization_id, array['FRANCHISE_OWNER', 'FRANCHISE_MANAGER'], a) then
    raise exception 'FRANCHISE_VOLUME_PROPOSAL_DENIED' using errcode = '42501';
  end if;
  select * into s from public.service_skus where id = p_sku_id and status = 'ACTIVE';
  if not found or not exists (select 1 from public.catalog_services cs where cs.id = s.service_id and cs.library_id = p_library_id) then
    raise exception 'VOLUME_SKU_NOT_IN_MANDATE' using errcode = '22023';
  end if;
  if p_forecast_units is null or p_forecast_units <= 0
     or p_minimum_commitment_units is null or p_minimum_commitment_units < 0
     or p_maximum_units is null or p_maximum_units <= 0
     or p_minimum_commitment_units > p_maximum_units
     or p_forecast_units > p_maximum_units
     or p_payment_model not in ('PAY_PER_USE', 'PREPAID', 'HYBRID')
     or p_period_end < p_period_start
     or length(btrim(coalesce(p_rationale, ''))) not between 10 and 4000
  then
    raise exception 'INVALID_VOLUME_PROPOSAL' using errcode = '22023';
  end if;
  v_hash := private.canonical_request_hash(jsonb_build_object(
    'library', p_library_id, 'sku', p_sku_id, 'forecast', p_forecast_units,
    'min', p_minimum_commitment_units, 'max', p_maximum_units, 'model', p_payment_model,
    'start', p_period_start, 'end', p_period_end, 'rationale', btrim(p_rationale)
  ));
  r := private.begin_contract_command(f.operator_organization_id, 'franchise.volume.propose', p_idempotency_key, v_hash, a);
  if r is not null then return r; end if;
  insert into public.franchise_volume_proposals (
    franchise_id, library_id, sku_id, service_id, forecast_units, minimum_commitment_units,
    maximum_units, payment_model, period_start, period_end, rationale, content_hash, created_by
  ) values (
    f.id, p_library_id, p_sku_id, s.service_id, p_forecast_units, p_minimum_commitment_units,
    p_maximum_units, p_payment_model, p_period_start, p_period_end, btrim(p_rationale), v_hash, a
  ) returning id into pid;
  r := jsonb_build_object('outcome', 'FRANCHISE_VOLUME_PROPOSED', 'proposal_id', pid, 'status', 'PROPOSED', 'sku_id', p_sku_id);
  insert into public.audit_events (organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (f.operator_organization_id, a, 'USER', 'franchise.volume.proposed', 'franchise_volume_proposal', pid::text, p_correlation_id, r, repeat('0', 64));
  insert into public.event_outbox (organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (f.operator_organization_id, 'franchise_volume_proposal', pid::text, 'FranchiseVolumeProposedV1', p_correlation_id, r, p_idempotency_key);
  perform private.finish_contract_command(f.operator_organization_id, 'franchise.volume.propose', p_idempotency_key, r);
  return r;
end
$$;

create or replace function public.decide_provider_qualification(
  p_qualification_id uuid,
  p_status text,
  p_questionnaire_session_id uuid,
  p_score_basis_points integer,
  p_mandatory_checks jsonb,
  p_blocking_conditions jsonb,
  p_rationale text,
  p_rule_version text,
  p_expires_at timestamptz,
  p_expected_row_version integer,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
  v_q public.provider_qualifications%rowtype;
  v_hash text;
  v_command uuid;
  v_replay jsonb;
  v_version integer;
  v_decision uuid;
  v_response jsonb;
  v_approved integer;
  v_previous_status text;
  v_questionnaire_version uuid;
begin
  select * into v_q from public.provider_qualifications where id = p_qualification_id;
  if not found then raise exception 'QUALIFICATION_NOT_FOUND' using errcode = 'P0002'; end if;
  if not (
    private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'COMPLIANCE_MANAGER'], v_actor)
    or private.can_decide_franchise_service_qualification(v_q.service_id, v_actor)
  ) then
    raise exception 'HUMAN_QUALIFICATION_DECISION_REQUIRED' using errcode = '42501';
  end if;
  if p_status not in ('PENDING', 'INFORMATION_REQUIRED', 'APPROVED', 'CONDITIONAL', 'SUSPENDED', 'EXPIRED', 'REJECTED')
     or jsonb_typeof(p_mandatory_checks) <> 'array'
     or jsonb_typeof(p_blocking_conditions) <> 'array'
     or length(btrim(coalesce(p_rationale, ''))) < 3
     or p_rule_version !~ '^[A-Z0-9][A-Z0-9._-]{2,79}$'
     or (p_status = 'CONDITIONAL' and jsonb_array_length(p_blocking_conditions) = 0)
     or (
       p_status in ('APPROVED', 'CONDITIONAL')
       and (
         p_questionnaire_session_id is null
         or p_score_basis_points is null
         or jsonb_array_length(p_mandatory_checks) = 0
         or exists (
           select 1 from jsonb_array_elements(p_mandatory_checks) c
           where jsonb_typeof(c) <> 'object' or coalesce((c->>'passed')::boolean, false) = false
         )
       )
     )
  then
    raise exception 'INVALID_QUALIFICATION_DECISION' using errcode = '22023';
  end if;
  if p_questionnaire_session_id is not null then
    select s.questionnaire_version_id into v_questionnaire_version
      from public.questionnaire_sessions s
     where s.id = p_questionnaire_session_id
       and s.organization_id = v_q.provider_organization_id
       and s.audience = 'PROVIDER'
       and s.status = 'SUBMITTED'
       and not s.is_simulation;
    if v_questionnaire_version is null then
      raise exception 'SUBMITTED_PROVIDER_QUESTIONNAIRE_REQUIRED' using errcode = '23514';
    end if;
  end if;
  select d.status into v_previous_status from public.provider_qualification_decisions d where d.id = v_q.current_decision_id;
  if not (
    (v_previous_status is null and p_status in ('PENDING', 'INFORMATION_REQUIRED', 'APPROVED', 'CONDITIONAL', 'REJECTED'))
    or (v_previous_status = 'PENDING' and p_status in ('INFORMATION_REQUIRED', 'APPROVED', 'CONDITIONAL', 'REJECTED'))
    or (v_previous_status = 'INFORMATION_REQUIRED' and p_status = 'PENDING')
    or (v_previous_status in ('APPROVED', 'CONDITIONAL') and p_status in ('PENDING', 'SUSPENDED', 'EXPIRED'))
    or (v_previous_status in ('SUSPENDED', 'EXPIRED', 'REJECTED') and p_status = 'PENDING')
  ) then
    raise exception 'INVALID_QUALIFICATION_TRANSITION' using errcode = '55000';
  end if;
  v_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'operation', 'provider.qualification.decide.v1', 'qualification_id', p_qualification_id, 'status', p_status,
    'questionnaire_session_id', p_questionnaire_session_id, 'score', p_score_basis_points,
    'mandatory_checks', p_mandatory_checks, 'blocking_conditions', p_blocking_conditions,
    'rationale', btrim(p_rationale), 'rule_version', p_rule_version, 'expires_at', p_expires_at, 'expected', p_expected_row_version
  )::text, 'UTF8'), 'sha256'), 'hex');
  select b.command_id, b.response_body into v_command, v_replay
    from private.begin_provider_qualification_command(v_actor, 'provider.qualification.decide', p_idempotency_key, v_hash) b;
  perform pg_advisory_xact_lock(hashtextextended('provider-qualification:' || p_qualification_id::text, 0));
  select * into v_q from public.provider_qualifications where id = p_qualification_id for update;
  if v_replay is not null then return v_replay; end if;
  if v_q.row_version <> p_expected_row_version then raise exception 'STALE_PROVIDER_QUALIFICATION' using errcode = '40001'; end if;
  select coalesce(max(decision_version), 0) + 1 into v_version from public.provider_qualification_decisions where qualification_id = p_qualification_id;
  insert into public.provider_qualification_decisions (
    qualification_id, provider_organization_id, service_id, decision_version, status, questionnaire_version_id,
    questionnaire_session_id, score_basis_points, mandatory_checks, blocking_conditions, rationale, rule_version,
    expires_at, decided_by, correlation_id
  ) values (
    p_qualification_id, v_q.provider_organization_id, v_q.service_id, v_version, p_status, v_questionnaire_version,
    p_questionnaire_session_id, p_score_basis_points, p_mandatory_checks, p_blocking_conditions, btrim(p_rationale),
    p_rule_version, p_expires_at, v_actor, p_correlation_id
  ) returning id into v_decision;
  update public.provider_qualifications set current_decision_id = v_decision, row_version = row_version + 1 where id = p_qualification_id;
  update public.provider_services
     set request_status = case
           when p_status = 'INFORMATION_REQUIRED' then 'INFORMATION_REQUIRED'
           when p_status = 'PENDING' then 'UNDER_REVIEW'
           else 'DECIDED'
         end,
         updated_at = clock_timestamp(),
         row_version = row_version + 1
   where id = v_q.provider_service_id;
  update public.provider_service_match_profiles
     set qualification_status = case
           when p_status = 'APPROVED' then 'APPROVED'
           when p_status in ('SUSPENDED', 'EXPIRED') then 'SUSPENDED'
           when p_status = 'REJECTED' then 'REJECTED'
           else 'PENDING'
         end,
         required_certifications_valid = not exists (
           select 1
           from public.provider_document_families fam
           join lateral (
             select doc.* from public.provider_document_versions doc
             where doc.family_id = fam.id
             order by doc.version_number desc
             limit 1
           ) doc on true
           join public.provider_document_service_links l on l.document_version_id = doc.id
           where l.provider_service_id = v_q.provider_service_id
             and l.is_mandatory
             and (doc.status <> 'VERIFIED' or (doc.expires_on is not null and doc.expires_on <= current_date))
         ),
         updated_at = clock_timestamp(),
         row_version = row_version + 1
   where provider_organization_id = v_q.provider_organization_id and service_id = v_q.service_id;
  select count(*) into v_approved
    from public.provider_qualifications q
    join public.provider_qualification_decisions dec on dec.id = q.current_decision_id
   where q.provider_organization_id = v_q.provider_organization_id
     and dec.status = 'APPROVED'
     and (dec.expires_at is null or dec.expires_at > statement_timestamp());
  update public.provider_profiles
     set overall_status = case
           when v_approved > 0 and partner_contract_status = 'SIGNED' then 'ACTIVE'
           when v_approved > 0 then 'PARTIALLY_QUALIFIED'
           else 'QUALIFICATION_IN_PROGRESS'
         end,
         updated_at = clock_timestamp(),
         row_version = row_version + 1
   where provider_organization_id = v_q.provider_organization_id
     and overall_status not in ('FINANCIAL_RESTRICTED', 'QUALITY_RESTRICTED', 'COMPLIANCE_RESTRICTED', 'SUSPENDED', 'TERMINATED');
  v_response := jsonb_build_object(
    'outcome', 'PROVIDER_QUALIFICATION_DECIDED', 'qualification_id', p_qualification_id,
    'decision_id', v_decision, 'decision_version', v_version, 'status', p_status, 'command_id', v_command
  );
  insert into public.audit_events (organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (
    v_q.provider_organization_id, v_actor, 'USER', 'provider.qualification.decided', 'provider_qualification_decision',
    v_decision::text, p_correlation_id,
    jsonb_build_object('qualification_id', p_qualification_id, 'service_id', v_q.service_id, 'status', p_status, 'rule_version', p_rule_version, 'reason_recorded', true, 'command_id', v_command),
    repeat('0', 64)
  );
  insert into public.event_outbox (organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key, causation_id)
  values (
    v_q.provider_organization_id, 'provider_qualification', p_qualification_id::text, 'ProviderQualificationDecidedV1',
    p_correlation_id,
    jsonb_build_object('qualification_id', p_qualification_id, 'decision_id', v_decision, 'service_id', v_q.service_id, 'status', p_status, 'rule_version', p_rule_version),
    p_idempotency_key, v_command
  );
  perform private.finish_provider_qualification_command(v_actor, 'provider.qualification.decide', p_idempotency_key, v_response);
  return v_response;
end
$$;

alter table public.anomaly_definitions enable row level security;
alter table public.anomaly_definition_versions enable row level security;
alter table public.risk_definitions enable row level security;
alter table public.risk_definition_versions enable row level security;
alter table public.recommendation_definitions enable row level security;
alter table public.recommendation_definition_versions enable row level security;
alter table public.franchise_volume_proposals enable row level security;

revoke all on public.anomaly_definitions, public.anomaly_definition_versions, public.risk_definitions, public.risk_definition_versions, public.recommendation_definitions, public.recommendation_definition_versions, public.franchise_volume_proposals from anon, authenticated, service_role;
grant select on public.anomaly_definitions, public.anomaly_definition_versions, public.risk_definitions, public.risk_definition_versions, public.recommendation_definitions, public.recommendation_definition_versions, public.franchise_volume_proposals to authenticated;

drop policy if exists anomaly_definitions_franchise_library_read on public.anomaly_definitions;
create policy anomaly_definitions_franchise_library_read on public.anomaly_definitions
  for select to authenticated using (private.franchise_mandated_library(library_id) or private.has_library_permission(library_id, 'CATALOG_VIEW_DRAFT', auth.uid()));
drop policy if exists anomaly_definition_versions_franchise_library_read on public.anomaly_definition_versions;
create policy anomaly_definition_versions_franchise_library_read on public.anomaly_definition_versions
  for select to authenticated using (private.franchise_mandated_library(library_id) or private.has_library_permission(library_id, 'CATALOG_VIEW_DRAFT', auth.uid()));
drop policy if exists risk_definitions_franchise_library_read on public.risk_definitions;
create policy risk_definitions_franchise_library_read on public.risk_definitions
  for select to authenticated using (private.franchise_mandated_library(library_id) or private.has_library_permission(library_id, 'CATALOG_VIEW_DRAFT', auth.uid()));
drop policy if exists risk_definition_versions_franchise_library_read on public.risk_definition_versions;
create policy risk_definition_versions_franchise_library_read on public.risk_definition_versions
  for select to authenticated using (private.franchise_mandated_library(library_id) or private.has_library_permission(library_id, 'CATALOG_VIEW_DRAFT', auth.uid()));
drop policy if exists recommendation_definitions_franchise_library_read on public.recommendation_definitions;
create policy recommendation_definitions_franchise_library_read on public.recommendation_definitions
  for select to authenticated using (private.franchise_mandated_library(library_id) or private.has_library_permission(library_id, 'CATALOG_VIEW_DRAFT', auth.uid()));
drop policy if exists recommendation_definition_versions_franchise_library_read on public.recommendation_definition_versions;
create policy recommendation_definition_versions_franchise_library_read on public.recommendation_definition_versions
  for select to authenticated using (private.franchise_mandated_library(library_id) or private.has_library_permission(library_id, 'CATALOG_VIEW_DRAFT', auth.uid()));
drop policy if exists franchise_volume_proposals_scoped_read on public.franchise_volume_proposals;
create policy franchise_volume_proposals_scoped_read on public.franchise_volume_proposals
  for select to authenticated using (private.franchise_access(franchise_id) or private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'FINANCE_MANAGER', 'READ_ONLY_AUDITOR'], auth.uid()));
drop policy if exists provider_qualification_decisions_franchise_library_read on public.provider_qualification_decisions;
create policy provider_qualification_decisions_franchise_library_read on public.provider_qualification_decisions
  for select to authenticated using (
    provider_qualification_decisions.service_id is not null
    and private.franchise_supervises_catalog_service(provider_qualification_decisions.service_id)
  );

revoke all on function private.can_maintain_franchise_definitions(uuid, uuid), private.can_decide_franchise_service_qualification(uuid, uuid), private.franchise_supervises_dispute(uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function private.can_maintain_franchise_definitions(uuid, uuid), private.can_decide_franchise_service_qualification(uuid, uuid), private.franchise_supervises_dispute(uuid, uuid) to authenticated;

revoke all on function public.upsert_franchise_anomaly_definition(uuid, text, text, text, text, text, text, boolean, boolean, text, text, text, uuid), public.upsert_franchise_risk_definition(uuid, text, text, text, text, text, text, text, text, text, uuid), public.upsert_franchise_recommendation_definition(uuid, text, uuid, uuid, text, integer, text, text, text, text, text, text, text, text, uuid), public.instruct_franchise_dispute(uuid, text, text, uuid), public.propose_franchise_volume_purchase(uuid, uuid, numeric, numeric, numeric, text, date, date, text, text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.upsert_franchise_anomaly_definition(uuid, text, text, text, text, text, text, boolean, boolean, text, text, text, uuid), public.upsert_franchise_risk_definition(uuid, text, text, text, text, text, text, text, text, text, uuid), public.upsert_franchise_recommendation_definition(uuid, text, uuid, uuid, text, integer, text, text, text, text, text, text, text, text, uuid), public.instruct_franchise_dispute(uuid, text, text, uuid), public.propose_franchise_volume_purchase(uuid, uuid, numeric, numeric, numeric, text, date, date, text, text, uuid) to authenticated;
grant execute on function public.decide_provider_qualification(uuid, text, uuid, integer, jsonb, jsonb, text, text, timestamptz, integer, text, uuid) to authenticated;

notify pgrst, 'reload schema';
