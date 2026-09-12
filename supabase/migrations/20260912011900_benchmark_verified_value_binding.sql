-- P1 benchmark poisoning hardening: a verified source proof binds one exact,
-- canonical value to one registry version and its applied source policy.
alter table private.benchmark_verified_sources
  add column registry_version_id uuid references public.benchmark_registry_versions(id) on delete restrict,
  add column verified_value_exact numeric(30,6),
  add column value_canonical text,
  add column source_policy_snapshot jsonb,
  add column source_policy_hash text,
  add column binding_hash text,
  add constraint benchmark_verified_source_binding_complete_ck check (
    (registry_version_id is null and verified_value_exact is null and value_canonical is null
      and source_policy_snapshot is null and source_policy_hash is null and binding_hash is null)
    or
    (registry_version_id is not null and verified_value_exact is not null
      and value_canonical is not null and source_policy_snapshot is not null
      and jsonb_typeof(source_policy_snapshot)='object'
      and source_policy_hash~'^[0-9a-f]{64}$' and binding_hash~'^[0-9a-f]{64}$')
  );

alter table private.benchmark_contributions
  add column registry_version_id uuid references public.benchmark_registry_versions(id) on delete restrict,
  add column source_verification_id uuid references private.benchmark_verified_sources(id) on delete restrict;

create unique index benchmark_source_proof_single_use_uidx
  on private.benchmark_contributions(source_verification_id)
  where source_verification_id is not null;

create index benchmark_verified_binding_lookup_idx
  on private.benchmark_verified_sources(
    organization_id,registry_version_id,metric_code,segment_key,period_start,period_end,
    input_version,source_hash,verified_value_exact
  );

create function private.benchmark_source_policy_allows(p_policy jsonb,p_method text)
returns boolean language sql immutable set search_path=pg_catalog
as $$
  select jsonb_typeof(p_policy)='object'
    and jsonb_typeof(p_policy->'allowed_verification_methods')='array'
    and jsonb_array_length(p_policy->'allowed_verification_methods')>0
    and p_method in ('SIGNED_IMPORT','AUDITED_CONNECTOR','ADMIN_ATTESTATION')
    and exists(
      select 1 from jsonb_array_elements_text(p_policy->'allowed_verification_methods') allowed(method)
      where allowed.method=p_method
    )
    and not exists(
      select 1 from jsonb_array_elements_text(p_policy->'allowed_verification_methods') allowed(method)
      where allowed.method not in ('SIGNED_IMPORT','AUDITED_CONNECTOR','ADMIN_ATTESTATION')
    )
$$;

create or replace function public.verify_benchmark_source(
  p_organization_id uuid,p_metric_code text,p_segment_key text,p_period_start date,p_period_end date,
  p_input_version text,p_source_hash text,p_evidence_hash text,p_verification_method text,
  p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$
begin
  raise exception 'BENCHMARK_VERIFIED_VALUE_REQUIRED' using errcode='22023';
end
$$;

create function public.verify_benchmark_source(
  p_organization_id uuid,p_metric_code text,p_segment_key text,p_period_start date,p_period_end date,
  p_value_exact numeric,p_input_version text,p_source_hash text,p_evidence_hash text,
  p_verification_method text,p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare
  actor_id uuid:=auth.uid();
  request_hash text;
  result jsonb;
  cached jsonb;
  source_id uuid;
  registry public.benchmark_registry_versions%rowtype;
  canonical_value numeric(30,6);
  canonical_text text;
  policy_hash text;
  proof_binding_hash text;
begin
  if actor_id is null or auth.jwt()->>'aal'<>'aal2'
     or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],actor_id) then
    raise exception 'BENCHMARK_SOURCE_VERIFY_DENIED' using errcode='42501';
  end if;
  if not exists(select 1 from public.organizations o where o.id=p_organization_id)
     or p_period_start is null or p_period_end<p_period_start
     or p_source_hash!~'^[0-9a-f]{64}$' or p_evidence_hash!~'^[0-9a-f]{64}$' then
    raise exception 'INVALID_BENCHMARK_SOURCE_PROOF' using errcode='22023';
  end if;
  canonical_value:=p_value_exact::numeric(30,6);
  if p_value_exact is null or p_value_exact<>canonical_value then
    raise exception 'BENCHMARK_VALUE_NOT_CANONICAL' using errcode='22023';
  end if;
  canonical_text:=canonical_value::text;
  perform pg_advisory_xact_lock(hashtextextended(
    'benchmark-cell:'||p_metric_code||':'||p_segment_key||':'||p_period_start::text||':'||p_period_end::text,0
  ));
  select registry_row.* into registry
    from public.benchmark_registry_versions registry_row
   where registry_row.metric_code=p_metric_code and registry_row.segment_key=p_segment_key
     and registry_row.status='ACTIVE' and registry_row.effective_from<=clock_timestamp()
     and (registry_row.effective_to is null or registry_row.effective_to>clock_timestamp());
  if not found then
    raise exception 'BENCHMARK_METRIC_SEGMENT_NOT_REGISTERED' using errcode='22023';
  end if;
  if canonical_value<registry.minimum_value or canonical_value>registry.maximum_value
     or p_input_version!~registry.input_version_pattern then
    raise exception 'INVALID_BENCHMARK_SOURCE_PROOF' using errcode='22023';
  end if;
  if not private.benchmark_source_policy_allows(registry.source_policy,p_verification_method) then
    raise exception 'BENCHMARK_SOURCE_POLICY_DENIED' using errcode='42501';
  end if;
  policy_hash:=private.canonical_request_hash(registry.source_policy);
  proof_binding_hash:=private.canonical_request_hash(jsonb_build_object(
    'organization',p_organization_id,'registry_version_id',registry.id,
    'metric',p_metric_code,'segment',p_segment_key,'period_start',p_period_start,
    'period_end',p_period_end,'value_canonical',canonical_text,'input_version',p_input_version,
    'source_hash',p_source_hash,'evidence_hash',p_evidence_hash,
    'verification_method',p_verification_method,'source_policy_hash',policy_hash
  ));
  request_hash:=proof_binding_hash;
  cached:=private.begin_contract_command(
    p_organization_id,'benchmark.source.verify.value',p_idempotency_key,request_hash,actor_id
  );
  if cached is not null then return cached;end if;
  insert into private.benchmark_verified_sources(
    organization_id,metric_code,segment_key,period_start,period_end,input_version,source_hash,
    evidence_hash,verification_method,verified_by,correlation_id,registry_version_id,
    verified_value_exact,value_canonical,source_policy_snapshot,source_policy_hash,binding_hash
  ) values(
    p_organization_id,p_metric_code,p_segment_key,p_period_start,p_period_end,p_input_version,p_source_hash,
    p_evidence_hash,p_verification_method,actor_id,p_correlation_id,registry.id,
    canonical_value,canonical_text,registry.source_policy,policy_hash,proof_binding_hash
  ) returning id into source_id;
  result:=jsonb_build_object(
    'outcome','BENCHMARK_SOURCE_VALUE_VERIFIED','source_verification_id',source_id,
    'registry_version_id',registry.id,'value_canonical',canonical_text,'binding_hash',proof_binding_hash
  );
  insert into public.audit_events(
    organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash
  ) values(
    p_organization_id,actor_id,'USER','benchmark.source.value_verified','benchmark_source',
    source_id::text,p_correlation_id,
    jsonb_build_object('registry_version_id',registry.id,'binding_hash',proof_binding_hash,
      'source_policy_hash',policy_hash,'value_canonical',canonical_text),repeat('0',64)
  );
  insert into public.event_outbox(
    organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key
  ) values(
    p_organization_id,'benchmark_source',source_id::text,'BenchmarkSourceValueVerifiedV1',
    p_correlation_id,result,p_idempotency_key
  );
  perform private.finish_contract_command(
    p_organization_id,'benchmark.source.verify.value',p_idempotency_key,result
  );
  return result;
end
$$;

create or replace function public.submit_benchmark_contribution(
  p_organization_id uuid,p_metric_code text,p_segment_key text,p_period_start date,p_period_end date,
  p_value_exact numeric,p_input_version text,p_source_hash text,p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare
  actor_id uuid:=auth.uid();
  request_hash text;
  result jsonb;
  cached jsonb;
  contribution_id uuid;
  source_id uuid;
  registry public.benchmark_registry_versions%rowtype;
  canonical_value numeric(30,6);
  canonical_text text;
  policy_hash text;
begin
  if actor_id is null or not private.has_org_role(
    p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],actor_id
  ) then raise exception 'BENCHMARK_CONTRIBUTION_DENIED' using errcode='42501';end if;
  if p_metric_code!~'^[A-Z][A-Z0-9_.-]{1,119}$'
     or p_segment_key!~'^[A-Z][A-Z0-9_.-]{1,119}$'
     or p_period_start is null or p_period_end<p_period_start
     or length(btrim(coalesce(p_input_version,'')))not between 1 and 120
     or p_source_hash!~'^[0-9a-f]{64}$' then
    raise exception 'INVALID_BENCHMARK_CONTRIBUTION' using errcode='22023';
  end if;
  canonical_value:=p_value_exact::numeric(30,6);
  if p_value_exact is null or p_value_exact<>canonical_value then
    raise exception 'BENCHMARK_VALUE_NOT_CANONICAL' using errcode='22023';
  end if;
  canonical_text:=canonical_value::text;
  request_hash:=private.canonical_request_hash(jsonb_build_object(
    'organization',p_organization_id,'metric',p_metric_code,'segment',p_segment_key,
    'period_start',p_period_start,'period_end',p_period_end,'value_canonical',canonical_text,
    'input_version',p_input_version,'source_hash',p_source_hash
  ));
  cached:=private.begin_contract_command(
    p_organization_id,'benchmark.contribution.submit',p_idempotency_key,request_hash,actor_id
  );
  if cached is not null then return cached;end if;
  perform pg_advisory_xact_lock(hashtextextended(
    'benchmark-cell:'||p_metric_code||':'||p_segment_key||':'||p_period_start::text||':'||p_period_end::text,0
  ));
  if exists(
    select 1 from public.benchmark_publications publication_row
     where publication_row.metric_code=p_metric_code and publication_row.segment_key=p_segment_key
       and publication_row.period_start=p_period_start and publication_row.period_end=p_period_end
  ) then raise exception 'BENCHMARK_CELL_SEALED' using errcode='55000';end if;
  select registry_row.* into registry
    from public.benchmark_registry_versions registry_row
   where registry_row.metric_code=p_metric_code and registry_row.segment_key=p_segment_key
     and registry_row.status='ACTIVE' and registry_row.effective_from<=clock_timestamp()
     and (registry_row.effective_to is null or registry_row.effective_to>clock_timestamp());
  if not found then
    raise exception 'BENCHMARK_METRIC_SEGMENT_NOT_REGISTERED' using errcode='22023';
  end if;
  if canonical_value<registry.minimum_value or canonical_value>registry.maximum_value then
    raise exception 'BENCHMARK_VALUE_OUT_OF_BOUNDS' using errcode='22003';
  end if;
  policy_hash:=private.canonical_request_hash(registry.source_policy);
  select source_row.id into source_id
    from private.benchmark_verified_sources source_row
   where source_row.organization_id=p_organization_id
     and source_row.registry_version_id=registry.id
     and source_row.metric_code=p_metric_code and source_row.segment_key=p_segment_key
     and source_row.period_start=p_period_start and source_row.period_end=p_period_end
     and source_row.input_version=p_input_version and source_row.source_hash=p_source_hash
     and source_row.verified_value_exact=canonical_value
     and source_row.value_canonical=canonical_text
     and source_row.source_policy_snapshot=registry.source_policy
     and source_row.source_policy_hash=policy_hash
     and source_row.binding_hash=private.canonical_request_hash(jsonb_build_object(
       'organization',p_organization_id,'registry_version_id',registry.id,
       'metric',p_metric_code,'segment',p_segment_key,'period_start',p_period_start,
       'period_end',p_period_end,'value_canonical',canonical_text,'input_version',p_input_version,
       'source_hash',p_source_hash,'evidence_hash',source_row.evidence_hash,
       'verification_method',source_row.verification_method,'source_policy_hash',policy_hash
     ))
     and not exists(
       select 1 from private.benchmark_contributions used
        where used.source_verification_id=source_row.id
     );
  if source_id is null then
    raise exception 'BENCHMARK_SOURCE_VALUE_NOT_VERIFIED' using errcode='22023';
  end if;
  insert into private.benchmark_contributions(
    organization_id,metric_code,segment_key,period_start,period_end,value_exact,input_version,
    source_hash,submitted_by,correlation_id,registry_version_id,source_verification_id
  ) values(
    p_organization_id,p_metric_code,p_segment_key,p_period_start,p_period_end,canonical_value,
    p_input_version,p_source_hash,actor_id,p_correlation_id,registry.id,source_id
  ) returning id into contribution_id;
  result:=jsonb_build_object(
    'outcome','BENCHMARK_CONTRIBUTION_ACCEPTED','contribution_id',contribution_id,
    'registry_version_id',registry.id,'source_verification_id',source_id,
    'metric_code',p_metric_code,'period_end',p_period_end
  );
  insert into public.audit_events(
    organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash
  ) values(
    p_organization_id,actor_id,'USER','benchmark.contribution.submitted','benchmark_contribution',
    contribution_id::text,p_correlation_id,
    jsonb_build_object('registry_version_id',registry.id,'source_verification_id',source_id,
      'metric_code',p_metric_code,'segment_key',p_segment_key,'source_hash',p_source_hash,
      'value_canonical',canonical_text),repeat('0',64)
  );
  insert into public.event_outbox(
    organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key
  ) values(
    p_organization_id,'benchmark_contribution',contribution_id::text,
    'BenchmarkContributionAcceptedV3',p_correlation_id,result,p_idempotency_key
  );
  perform private.finish_contract_command(
    p_organization_id,'benchmark.contribution.submit',p_idempotency_key,result
  );
  return result;
end
$$;

revoke all on function private.benchmark_source_policy_allows(jsonb,text) from public,anon,authenticated,service_role;
revoke all on function public.verify_benchmark_source(uuid,text,text,date,date,text,text,text,text,text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.verify_benchmark_source(uuid,text,text,date,date,numeric,text,text,text,text,text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.submit_benchmark_contribution(uuid,text,text,date,date,numeric,text,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.verify_benchmark_source(uuid,text,text,date,date,numeric,text,text,text,text,text,uuid) to authenticated;
grant execute on function public.submit_benchmark_contribution(uuid,text,text,date,date,numeric,text,text,text,uuid) to authenticated;
notify pgrst,'reload schema';
