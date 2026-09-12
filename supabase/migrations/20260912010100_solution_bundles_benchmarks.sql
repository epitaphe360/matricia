-- MAT-FUNC-009/010/045: explainable solution tiers, versioned cross-library bundles,
-- and privacy-preserving anonymized benchmarks. No catalogue question corpus is loaded.

create table public.diagnostic_solution_sets (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  anomaly_id uuid not null,
  diagnostic_run_id uuid not null references public.diagnostic_runs(id) on delete restrict,
  version integer not null check (version > 0),
  source_policy_snapshot jsonb not null check (jsonb_typeof(source_policy_snapshot) = 'object'),
  input_hash text not null check (input_hash ~ '^[0-9a-f]{64}$'),
  rationale_fr text not null check (length(btrim(rationale_fr)) between 3 and 4000),
  rationale_ar text not null check (length(btrim(rationale_ar)) between 3 and 4000),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  correlation_id uuid not null,
  foreign key (anomaly_id,organization_id) references public.diagnostic_anomalies(id,organization_id) on delete restrict,
  unique (anomaly_id,version), unique (id,organization_id)
);

create table public.diagnostic_solution_options (
  id uuid primary key default extensions.gen_random_uuid(),
  solution_set_id uuid not null references public.diagnostic_solution_sets(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  level text not null check (level in ('ESSENTIAL','STANDARD','ADVANCED')),
  service_id uuid not null references public.catalog_services(id) on delete restrict,
  service_version_id uuid not null references public.catalog_service_versions(id) on delete restrict,
  expected_score_bps integer not null check (expected_score_bps between 0 and 10000),
  estimated_amount_minor bigint check (estimated_amount_minor is null or estimated_amount_minor >= 0),
  currency char(3) check (currency is null or currency ~ '^[A-Z]{3}$'),
  benefits jsonb not null check (jsonb_typeof(benefits) = 'array'),
  tradeoffs jsonb not null check (jsonb_typeof(tradeoffs) = 'array'),
  explanation jsonb not null check (jsonb_typeof(explanation) = 'object'),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default clock_timestamp(),
  unique (solution_set_id,level),
  foreign key (solution_set_id,organization_id) references public.diagnostic_solution_sets(id,organization_id) on delete restrict,
  foreign key (service_id,service_version_id) references public.catalog_service_versions(service_id,id) on delete restrict,
  check ((estimated_amount_minor is null) = (currency is null))
);

create table public.diagnostic_solution_decisions (
  id uuid primary key default extensions.gen_random_uuid(),
  solution_set_id uuid not null references public.diagnostic_solution_sets(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  level text not null check (level in ('ESSENTIAL','STANDARD','ADVANCED')),
  decision text not null check (decision in ('ACCEPTED','REJECTED','DEFERRED')),
  reason text not null check (length(btrim(reason)) between 3 and 2000),
  deferred_until timestamptz,
  decided_by uuid not null references auth.users(id),
  decided_at timestamptz not null default clock_timestamp(),
  correlation_id uuid not null,
  foreign key (solution_set_id,organization_id) references public.diagnostic_solution_sets(id,organization_id) on delete restrict,
  foreign key (solution_set_id,level) references public.diagnostic_solution_options(solution_set_id,level) on delete restrict,
  check ((decision = 'DEFERRED') = (deferred_until is not null))
);
create unique index diagnostic_solution_one_accept_uidx on public.diagnostic_solution_decisions(solution_set_id) where decision='ACCEPTED';

create table public.solution_bundle_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  bundle_key text not null check (bundle_key ~ '^[A-Z][A-Z0-9_.-]{1,119}$'),
  version integer not null check (version > 0),
  title_fr text not null check (length(btrim(title_fr)) between 3 and 240),
  title_ar text not null check (length(btrim(title_ar)) between 3 and 240),
  description_fr text not null check (length(btrim(description_fr)) between 3 and 4000),
  description_ar text not null check (length(btrim(description_ar)) between 3 and 4000),
  source_manifest_hash text not null check (source_manifest_hash ~ '^[0-9a-f]{64}$'),
  fusion_policy_snapshot jsonb not null check (jsonb_typeof(fusion_policy_snapshot)='object'),
  library_codes jsonb not null check (jsonb_typeof(library_codes)='array' and jsonb_array_length(library_codes)>=2),
  total_amount_minor bigint not null check (total_amount_minor >= 0),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  correlation_id uuid not null,
  unique (organization_id,bundle_key,version), unique (id,organization_id)
);

create table public.solution_bundle_items (
  id uuid primary key default extensions.gen_random_uuid(),
  bundle_version_id uuid not null references public.solution_bundle_versions(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  dedupe_key text not null check (dedupe_key ~ '^[A-Z][A-Z0-9_.-]{1,159}$'),
  service_id uuid not null references public.catalog_services(id) on delete restrict,
  service_version_id uuid not null references public.catalog_service_versions(id) on delete restrict,
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  fusion_strategy text not null check (fusion_strategy in ('KEEP_PRIMARY','MERGE_SCOPE','SEQUENCE')),
  source_count integer not null check (source_count > 0),
  provenance jsonb not null check (jsonb_typeof(provenance)='array' and jsonb_array_length(provenance)>0),
  amount_minor bigint not null check (amount_minor >= 0),
  sort_order integer not null check (sort_order > 0),
  foreign key (bundle_version_id,organization_id) references public.solution_bundle_versions(id,organization_id) on delete restrict,
  foreign key (service_id,service_version_id) references public.catalog_service_versions(service_id,id) on delete restrict,
  foreign key (service_id,library_id) references public.catalog_services(id,library_id) on delete restrict,
  unique (bundle_version_id,dedupe_key), unique (bundle_version_id,sort_order)
);

create table public.benchmark_privacy_policies (
  id uuid primary key default extensions.gen_random_uuid(),
  steward_organization_id uuid not null references public.organizations(id) on delete restrict,
  version integer not null unique check (version > 0),
  status text not null check (status in ('ACTIVE','RETIRED')),
  minimum_group_size integer not null check (minimum_group_size >= 5),
  rounding_increment numeric(30,6) not null check (rounding_increment > 0),
  minimum_period_days integer not null check (minimum_period_days >= 7),
  release_delay_days integer not null check (release_delay_days >= 1),
  policy_snapshot jsonb not null check (jsonb_typeof(policy_snapshot)='object'),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  effective_from timestamptz not null,
  effective_to timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  correlation_id uuid not null,
  check (effective_to is null or effective_to > effective_from)
);
create unique index benchmark_one_active_policy_uidx on public.benchmark_privacy_policies((status)) where status='ACTIVE';

create table private.benchmark_contributions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  metric_code text not null check (metric_code ~ '^[A-Z][A-Z0-9_.-]{1,119}$'),
  segment_key text not null check (segment_key ~ '^[A-Z][A-Z0-9_.-]{1,119}$'),
  period_start date not null,
  period_end date not null,
  value_exact numeric(30,6) not null,
  input_version text not null check (length(btrim(input_version)) between 1 and 120),
  source_hash text not null check (source_hash ~ '^[0-9a-f]{64}$'),
  submitted_by uuid not null references auth.users(id),
  submitted_at timestamptz not null default clock_timestamp(),
  correlation_id uuid not null,
  unique (organization_id,metric_code,segment_key,period_start,period_end,input_version),
  check (period_end >= period_start)
);

create table private.benchmark_computations (
  id uuid primary key default extensions.gen_random_uuid(),
  privacy_policy_id uuid not null references public.benchmark_privacy_policies(id) on delete restrict,
  metric_code text not null,
  segment_key text not null,
  period_start date not null,
  period_end date not null,
  contributor_count integer not null check (contributor_count >= 0),
  exact_mean numeric(30,6),
  input_manifest_hash text not null check (input_manifest_hash ~ '^[0-9a-f]{64}$'),
  outcome text not null check (outcome in ('PUBLISHED','SUPPRESSED_SMALL_GROUP')),
  computed_at timestamptz not null default clock_timestamp(),
  correlation_id uuid not null,
  unique (privacy_policy_id,metric_code,segment_key,period_start,period_end,input_manifest_hash)
);

create table public.benchmark_publications (
  id uuid primary key default extensions.gen_random_uuid(),
  computation_id uuid not null unique references private.benchmark_computations(id) on delete restrict,
  privacy_policy_id uuid not null references public.benchmark_privacy_policies(id) on delete restrict,
  metric_code text not null check (metric_code ~ '^[A-Z][A-Z0-9_.-]{1,119}$'),
  segment_key text not null check (segment_key ~ '^[A-Z][A-Z0-9_.-]{1,119}$'),
  period_start date not null,
  period_end date not null,
  group_size_band text not null check (group_size_band ~ '^[0-9]+-[0-9]+$'),
  rounded_mean numeric(30,6) not null,
  methodology jsonb not null check (jsonb_typeof(methodology)='object'),
  cohort_fingerprint text not null check (cohort_fingerprint ~ '^[0-9a-f]{64}$'),
  published_at timestamptz not null default clock_timestamp(),
  correlation_id uuid not null,
  unique (privacy_policy_id,metric_code,segment_key,period_start,period_end,cohort_fingerprint)
);

create function private.prevent_solution_benchmark_history_change() returns trigger language plpgsql set search_path=pg_catalog as $$
begin raise exception 'SOLUTION_BENCHMARK_HISTORY_IMMUTABLE' using errcode='55000'; end $$;
create function private.protect_benchmark_privacy_policy_history() returns trigger language plpgsql set search_path=pg_catalog as $$
begin
 if tg_op='DELETE' or old.status<>'ACTIVE' or new.status<>'RETIRED' or new.effective_to is null
    or (to_jsonb(new)-array['status','effective_to']) is distinct from (to_jsonb(old)-array['status','effective_to'])
 then raise exception 'BENCHMARK_POLICY_HISTORY_IMMUTABLE' using errcode='55000';end if;
 return new;
end $$;
create trigger diagnostic_solution_sets_immutable before update or delete on public.diagnostic_solution_sets for each row execute function private.prevent_solution_benchmark_history_change();
create trigger diagnostic_solution_options_immutable before update or delete on public.diagnostic_solution_options for each row execute function private.prevent_solution_benchmark_history_change();
create trigger diagnostic_solution_decisions_immutable before update or delete on public.diagnostic_solution_decisions for each row execute function private.prevent_solution_benchmark_history_change();
create trigger solution_bundle_versions_immutable before update or delete on public.solution_bundle_versions for each row execute function private.prevent_solution_benchmark_history_change();
create trigger solution_bundle_items_immutable before update or delete on public.solution_bundle_items for each row execute function private.prevent_solution_benchmark_history_change();
create trigger benchmark_privacy_policies_immutable before update or delete on public.benchmark_privacy_policies for each row execute function private.protect_benchmark_privacy_policy_history();
create trigger benchmark_contributions_immutable before update or delete on private.benchmark_contributions for each row execute function private.prevent_solution_benchmark_history_change();
create trigger benchmark_computations_immutable before update or delete on private.benchmark_computations for each row execute function private.prevent_solution_benchmark_history_change();
create trigger benchmark_publications_immutable before update or delete on public.benchmark_publications for each row execute function private.prevent_solution_benchmark_history_change();

create function public.create_anomaly_solution_set(p_anomaly_id uuid,p_policy_snapshot jsonb,p_rationale_fr text,p_rationale_ar text,p_options jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();an public.diagnostic_anomalies%rowtype;h text;r jsonb;cached jsonb;sid uuid;ver integer;x jsonb;level_count integer;begin
 select * into an from public.diagnostic_anomalies where id=p_anomaly_id;
 if a is null or not found or not private.has_org_role(an.organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a) then raise exception 'SOLUTION_SET_CREATE_DENIED' using errcode='42501';end if;
 if jsonb_typeof(p_policy_snapshot)<>'object' or not(p_policy_snapshot?&array['version','content_hash']) or p_policy_snapshot->>'content_hash'!~'^[0-9a-f]{64}$' or jsonb_typeof(p_options)<>'array' or jsonb_array_length(p_options)<>3 or length(btrim(coalesce(p_rationale_fr,'')))not between 3 and 4000 or length(btrim(coalesce(p_rationale_ar,'')))not between 3 and 4000 then raise exception 'INVALID_SOLUTION_SET' using errcode='22023';end if;
 select count(distinct value->>'level') into level_count from jsonb_array_elements(p_options) where value->>'level' in('ESSENTIAL','STANDARD','ADVANCED');if level_count<>3 then raise exception 'THREE_SOLUTION_LEVELS_REQUIRED' using errcode='22023';end if;
 if exists(select 1 from jsonb_array_elements(p_options)x left join public.catalog_services s on s.id=nullif(x.value->>'service_id','')::uuid left join public.catalog_service_versions sv on sv.id=nullif(x.value->>'service_version_id','')::uuid and sv.service_id=s.id where s.id is null or sv.id is null or s.status<>'PUBLISHED' or s.current_published_version_id<>sv.id or (x.value->>'expected_score_bps')::integer not between 0 and 10000 or coalesce(jsonb_typeof(x.value->'benefits'),'null')<>'array' or coalesce(jsonb_typeof(x.value->'tradeoffs'),'null')<>'array' or coalesce(jsonb_typeof(x.value->'explanation'),'null')<>'object') then raise exception 'INVALID_SOLUTION_OPTION' using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('anomaly',an.id,'policy',p_policy_snapshot,'rationale_fr',p_rationale_fr,'rationale_ar',p_rationale_ar,'options',p_options));cached:=private.begin_contract_command(an.organization_id,'diagnostic.solution_set.'||an.id::text,p_idempotency_key,h,a);if cached is not null then return cached;end if;
 select coalesce(max(version),0)+1 into ver from public.diagnostic_solution_sets where anomaly_id=an.id;insert into public.diagnostic_solution_sets(organization_id,anomaly_id,diagnostic_run_id,version,source_policy_snapshot,input_hash,rationale_fr,rationale_ar,created_by,correlation_id)values(an.organization_id,an.id,an.diagnostic_run_id,ver,p_policy_snapshot,h,p_rationale_fr,p_rationale_ar,a,p_correlation_id)returning id into sid;
 for x in select value from jsonb_array_elements(p_options) loop insert into public.diagnostic_solution_options(solution_set_id,organization_id,level,service_id,service_version_id,expected_score_bps,estimated_amount_minor,currency,benefits,tradeoffs,explanation,content_hash)values(sid,an.organization_id,x->>'level',(x->>'service_id')::uuid,(x->>'service_version_id')::uuid,(x->>'expected_score_bps')::integer,nullif(x->>'estimated_amount_minor','')::bigint,nullif(x->>'currency',''),x->'benefits',x->'tradeoffs',x->'explanation',private.canonical_request_hash(x));end loop;
 r:=jsonb_build_object('outcome','SOLUTION_SET_CREATED','solution_set_id',sid,'anomaly_id',an.id,'version',ver,'levels',jsonb_build_array('ESSENTIAL','STANDARD','ADVANCED'),'input_hash',h);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(an.organization_id,a,'USER','diagnostic.solution_set.created','diagnostic_solution_set',sid::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(an.organization_id,'diagnostic_solution_set',sid::text,'DiagnosticSolutionSetCreatedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(an.organization_id,'diagnostic.solution_set.'||an.id::text,p_idempotency_key,r);return r;
exception when invalid_text_representation or invalid_parameter_value or numeric_value_out_of_range then raise exception 'INVALID_SOLUTION_OPTION' using errcode='22023';end $$;

create function public.record_solution_decision(p_solution_set_id uuid,p_level text,p_decision text,p_reason text,p_deferred_until timestamptz,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();s public.diagnostic_solution_sets%rowtype;h text;r jsonb;cached jsonb;did uuid;begin select * into s from public.diagnostic_solution_sets where id=p_solution_set_id;if a is null or not found or not private.has_org_role(s.organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],a)then raise exception'SOLUTION_DECISION_DENIED'using errcode='42501';end if;if p_level not in('ESSENTIAL','STANDARD','ADVANCED')or p_decision not in('ACCEPTED','REJECTED','DEFERRED')or length(btrim(coalesce(p_reason,'')))not between 3 and 2000 or(p_decision='DEFERRED'and(p_deferred_until is null or p_deferred_until<=clock_timestamp()))or(p_decision<>'DEFERRED'and p_deferred_until is not null)or not exists(select 1 from public.diagnostic_solution_options where solution_set_id=s.id and level=p_level)then raise exception'INVALID_SOLUTION_DECISION'using errcode='22023';end if;h:=private.canonical_request_hash(jsonb_build_object('set',s.id,'level',p_level,'decision',p_decision,'reason',p_reason,'deferred_until',p_deferred_until));cached:=private.begin_contract_command(s.organization_id,'diagnostic.solution_decision.'||s.id::text,p_idempotency_key,h,a);if cached is not null then return cached;end if;insert into public.diagnostic_solution_decisions(solution_set_id,organization_id,level,decision,reason,deferred_until,decided_by,correlation_id)values(s.id,s.organization_id,p_level,p_decision,p_reason,p_deferred_until,a,p_correlation_id)returning id into did;r:=jsonb_build_object('outcome','SOLUTION_'||p_decision,'decision_id',did,'solution_set_id',s.id,'level',p_level);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(s.organization_id,a,'USER','diagnostic.solution_decided','diagnostic_solution_set',s.id::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(s.organization_id,'diagnostic_solution_set',s.id::text,'DiagnosticSolutionDecidedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(s.organization_id,'diagnostic.solution_decision.'||s.id::text,p_idempotency_key,r);return r;end $$;

create function public.publish_solution_bundle(p_organization_id uuid,p_bundle_key text,p_version integer,p_title_fr text,p_title_ar text,p_description_fr text,p_description_ar text,p_currency text,p_fusion_policy_snapshot jsonb,p_items jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();h text;r jsonb;cached jsonb;bid uuid;library_count integer;total bigint;libraries jsonb;begin
 if a is null or not private.has_org_role(p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a)then raise exception'BUNDLE_PUBLISH_DENIED'using errcode='42501';end if;
 if p_bundle_key!~'^[A-Z][A-Z0-9_.-]{1,119}$'or p_version<1 or p_currency!~'^[A-Z]{3}$'or jsonb_typeof(p_fusion_policy_snapshot)<>'object'or not(p_fusion_policy_snapshot?&array['version','content_hash','default_strategy'])or p_fusion_policy_snapshot->>'content_hash'!~'^[0-9a-f]{64}$'or jsonb_typeof(p_items)<>'array'or jsonb_array_length(p_items)<2 or length(btrim(coalesce(p_title_fr,'')))not between 3 and 240 or length(btrim(coalesce(p_title_ar,'')))not between 3 and 240 or length(btrim(coalesce(p_description_fr,'')))not between 3 and 4000 or length(btrim(coalesce(p_description_ar,'')))not between 3 and 4000 then raise exception'INVALID_SOLUTION_BUNDLE'using errcode='22023';end if;
 if exists(select 1 from jsonb_array_elements(p_items)x left join public.catalog_services s on s.id=nullif(x.value->>'service_id','')::uuid left join public.catalog_service_versions sv on sv.id=nullif(x.value->>'service_version_id','')::uuid and sv.service_id=s.id where s.id is null or sv.id is null or s.status<>'PUBLISHED'or s.current_published_version_id<>sv.id or x.value->>'dedupe_key'!~'^[A-Z][A-Z0-9_.-]{1,159}$'or x.value->>'fusion_strategy'not in('KEEP_PRIMARY','MERGE_SCOPE','SEQUENCE')or(x.value->>'amount_minor')::bigint<0)then raise exception'INVALID_BUNDLE_ITEM'using errcode='22023';end if;
 if exists(select 1 from jsonb_array_elements(p_items)x group by x.value->>'dedupe_key' having count(distinct x.value->>'fusion_strategy')<>1)then raise exception'AMBIGUOUS_BUNDLE_FUSION'using errcode='22023';end if;
 select count(distinct s.library_id),jsonb_agg(distinct l.code order by l.code) into library_count,libraries from jsonb_array_elements(p_items)x join public.catalog_services s on s.id=(x.value->>'service_id')::uuid join public.catalog_libraries l on l.id=s.library_id;if library_count<2 then raise exception'MULTI_LIBRARY_BUNDLE_REQUIRED'using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('organization',p_organization_id,'key',p_bundle_key,'version',p_version,'titles',jsonb_build_array(p_title_fr,p_title_ar),'descriptions',jsonb_build_array(p_description_fr,p_description_ar),'currency',p_currency,'fusion_policy',p_fusion_policy_snapshot,'items',p_items));cached:=private.begin_contract_command(p_organization_id,'solution.bundle.publish.'||p_bundle_key,p_idempotency_key,h,a);if cached is not null then return cached;end if;
 with raw as(select x.value->>'dedupe_key' dedupe_key,(x.value->>'amount_minor')::bigint amount_minor from jsonb_array_elements(p_items)x),dedup as(select dedupe_key,max(amount_minor)amount_minor from raw group by dedupe_key)select coalesce(sum(amount_minor),0)into total from dedup;
 insert into public.solution_bundle_versions(organization_id,bundle_key,version,title_fr,title_ar,description_fr,description_ar,source_manifest_hash,fusion_policy_snapshot,library_codes,total_amount_minor,currency,created_by,correlation_id)values(p_organization_id,p_bundle_key,p_version,p_title_fr,p_title_ar,p_description_fr,p_description_ar,h,p_fusion_policy_snapshot,libraries,total,p_currency,a,p_correlation_id)returning id into bid;
 insert into public.solution_bundle_items(bundle_version_id,organization_id,dedupe_key,service_id,service_version_id,library_id,fusion_strategy,source_count,provenance,amount_minor,sort_order)
 with raw as(select x.value->>'dedupe_key'dedupe_key,(x.value->>'service_id')::uuid service_id,(x.value->>'service_version_id')::uuid service_version_id,s.library_id,x.value->>'fusion_strategy'fusion_strategy,(x.value->>'amount_minor')::bigint amount_minor,x.value provenance,x.ordinality from jsonb_array_elements(p_items)with ordinality x(value,ordinality)join public.catalog_services s on s.id=(x.value->>'service_id')::uuid),g as(select dedupe_key,(array_agg(service_id order by ordinality))[1]service_id,(array_agg(service_version_id order by ordinality))[1]service_version_id,(array_agg(library_id order by ordinality))[1]library_id,(array_agg(fusion_strategy order by ordinality))[1]fusion_strategy,count(*)::integer source_count,jsonb_agg(jsonb_build_object('service_id',service_id,'service_version_id',service_version_id,'library_id',library_id,'source',coalesce(provenance->'provenance','{}'::jsonb))order by ordinality)provenance,max(amount_minor)amount_minor,min(ordinality)first_order from raw group by dedupe_key)
 select bid,p_organization_id,g.dedupe_key,g.service_id,g.service_version_id,g.library_id,g.fusion_strategy,g.source_count,g.provenance,g.amount_minor,row_number()over(order by g.first_order,g.dedupe_key)::integer from g;
 r:=jsonb_build_object('outcome','SOLUTION_BUNDLE_PUBLISHED','bundle_version_id',bid,'bundle_key',p_bundle_key,'version',p_version,'source_count',jsonb_array_length(p_items),'deduplicated_count',(select count(*)from public.solution_bundle_items where bundle_version_id=bid),'library_count',library_count,'total_amount_minor',total,'currency',p_currency,'source_manifest_hash',h);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,a,'USER','solution.bundle.published','solution_bundle_version',bid::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_organization_id,'solution_bundle',bid::text,'SolutionBundlePublishedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(p_organization_id,'solution.bundle.publish.'||p_bundle_key,p_idempotency_key,r);return r;
exception when invalid_text_representation or invalid_parameter_value or numeric_value_out_of_range then raise exception'INVALID_BUNDLE_ITEM'using errcode='22023';end $$;

create function public.publish_benchmark_privacy_policy(p_steward_organization_id uuid,p_minimum_group_size integer,p_rounding_increment numeric,p_minimum_period_days integer,p_release_delay_days integer,p_policy_snapshot jsonb,p_effective_from timestamptz,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();h text;r jsonb;cached jsonb;pid uuid;ver integer;begin if a is null or auth.jwt()->>'aal'<>'aal2'or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],a)then raise exception'BENCHMARK_POLICY_MFA_REQUIRED'using errcode='42501';end if;if not exists(select 1 from public.organizations where id=p_steward_organization_id)then raise exception'PLATFORM_ORGANIZATION_REQUIRED'using errcode='55000';end if;if p_minimum_group_size<5 or p_rounding_increment<=0 or p_minimum_period_days<7 or p_release_delay_days<1 or jsonb_typeof(p_policy_snapshot)<>'object'or p_effective_from is null then raise exception'INVALID_BENCHMARK_POLICY'using errcode='22023';end if;h:=private.canonical_request_hash(jsonb_build_object('steward_organization_id',p_steward_organization_id,'minimum_group_size',p_minimum_group_size,'rounding_increment',p_rounding_increment,'minimum_period_days',p_minimum_period_days,'release_delay_days',p_release_delay_days,'policy',p_policy_snapshot,'effective_from',p_effective_from));cached:=private.begin_contract_command(p_steward_organization_id,'benchmark.policy.publish',p_idempotency_key,h,a);if cached is not null then return cached;end if;select coalesce(max(version),0)+1 into ver from public.benchmark_privacy_policies;update public.benchmark_privacy_policies set status='RETIRED',effective_to=p_effective_from where status='ACTIVE'and effective_from<p_effective_from;insert into public.benchmark_privacy_policies(steward_organization_id,version,status,minimum_group_size,rounding_increment,minimum_period_days,release_delay_days,policy_snapshot,content_hash,effective_from,created_by,correlation_id)values(p_steward_organization_id,ver,'ACTIVE',p_minimum_group_size,p_rounding_increment,p_minimum_period_days,p_release_delay_days,p_policy_snapshot,h,p_effective_from,a,p_correlation_id)returning id into pid;r:=jsonb_build_object('outcome','BENCHMARK_PRIVACY_POLICY_PUBLISHED','policy_id',pid,'version',ver,'content_hash',h);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_steward_organization_id,a,'USER','benchmark.privacy_policy.published','benchmark_privacy_policy',pid::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_steward_organization_id,'benchmark_privacy_policy',pid::text,'BenchmarkPrivacyPolicyPublishedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(p_steward_organization_id,'benchmark.policy.publish',p_idempotency_key,r);return r;end $$;

create function public.submit_benchmark_contribution(p_organization_id uuid,p_metric_code text,p_segment_key text,p_period_start date,p_period_end date,p_value_exact numeric,p_input_version text,p_source_hash text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();h text;r jsonb;cached jsonb;cid uuid;begin if a is null or not private.has_org_role(p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a)then raise exception'BENCHMARK_CONTRIBUTION_DENIED'using errcode='42501';end if;if p_metric_code!~'^[A-Z][A-Z0-9_.-]{1,119}$'or p_segment_key!~'^[A-Z][A-Z0-9_.-]{1,119}$'or p_period_start is null or p_period_end<p_period_start or length(btrim(coalesce(p_input_version,'')))not between 1 and 120 or p_source_hash!~'^[0-9a-f]{64}$'then raise exception'INVALID_BENCHMARK_CONTRIBUTION'using errcode='22023';end if;h:=private.canonical_request_hash(jsonb_build_object('organization',p_organization_id,'metric',p_metric_code,'segment',p_segment_key,'period_start',p_period_start,'period_end',p_period_end,'value',p_value_exact,'input_version',p_input_version,'source_hash',p_source_hash));cached:=private.begin_contract_command(p_organization_id,'benchmark.contribution.'||p_metric_code||'.'||p_segment_key,p_idempotency_key,h,a);if cached is not null then return cached;end if;insert into private.benchmark_contributions(organization_id,metric_code,segment_key,period_start,period_end,value_exact,input_version,source_hash,submitted_by,correlation_id)values(p_organization_id,p_metric_code,p_segment_key,p_period_start,p_period_end,p_value_exact,p_input_version,p_source_hash,a,p_correlation_id)returning id into cid;r:=jsonb_build_object('outcome','BENCHMARK_CONTRIBUTION_ACCEPTED','contribution_id',cid,'metric_code',p_metric_code,'period_end',p_period_end);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,a,'USER','benchmark.contribution.submitted','benchmark_contribution',cid::text,p_correlation_id,jsonb_build_object('metric_code',p_metric_code,'segment_key',p_segment_key,'period_start',p_period_start,'period_end',p_period_end,'input_version',p_input_version,'source_hash',p_source_hash),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_organization_id,'benchmark_contribution',cid::text,'BenchmarkContributionAcceptedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(p_organization_id,'benchmark.contribution.'||p_metric_code||'.'||p_segment_key,p_idempotency_key,r);return r;end $$;

create function public.compute_anonymized_benchmark(p_privacy_policy_id uuid,p_metric_code text,p_segment_key text,p_period_start date,p_period_end date,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare pol public.benchmark_privacy_policies%rowtype;n integer;exact_mean numeric(30,6);manifest text;comp uuid;pub uuid;rounded numeric(30,6);band text;new_comp boolean;new_pub boolean;r jsonb;
begin
 if auth.role()<>'service_role'then raise exception'BENCHMARK_WORKER_ONLY'using errcode='42501';end if;
 select * into pol from public.benchmark_privacy_policies where id=p_privacy_policy_id;if not found then raise exception'BENCHMARK_POLICY_NOT_FOUND'using errcode='P0002';end if;
 if pol.status not in('ACTIVE','RETIRED')or p_metric_code!~'^[A-Z][A-Z0-9_.-]{1,119}$'or p_segment_key!~'^[A-Z][A-Z0-9_.-]{1,119}$'or p_period_end<p_period_start or(p_period_end-p_period_start+1)<pol.minimum_period_days or clock_timestamp()<p_period_end::timestamptz+make_interval(days=>pol.release_delay_days)then raise exception'BENCHMARK_PRIVACY_WINDOW_INVALID'using errcode='22023';end if;
 with latest as(select distinct on(organization_id)organization_id,value_exact,source_hash from private.benchmark_contributions where metric_code=p_metric_code and segment_key=p_segment_key and period_start=p_period_start and period_end=p_period_end order by organization_id,submitted_at desc,id desc)
 select count(*),avg(value_exact),encode(extensions.digest(convert_to(coalesce(string_agg(organization_id::text||':'||source_hash,','order by organization_id),'EMPTY'),'UTF8'),'sha256'),'hex')into n,exact_mean,manifest from latest;
 insert into private.benchmark_computations(privacy_policy_id,metric_code,segment_key,period_start,period_end,contributor_count,exact_mean,input_manifest_hash,outcome,correlation_id)values(pol.id,p_metric_code,p_segment_key,p_period_start,p_period_end,n,case when n>=pol.minimum_group_size then exact_mean end,manifest,case when n>=pol.minimum_group_size then'PUBLISHED'else'SUPPRESSED_SMALL_GROUP'end,p_correlation_id)on conflict(privacy_policy_id,metric_code,segment_key,period_start,period_end,input_manifest_hash)do nothing returning id into comp;
 new_comp:=comp is not null;if comp is null then select id into comp from private.benchmark_computations where privacy_policy_id=pol.id and metric_code=p_metric_code and segment_key=p_segment_key and period_start=p_period_start and period_end=p_period_end and input_manifest_hash=manifest;end if;
 if n<pol.minimum_group_size then r:=jsonb_build_object('outcome','BENCHMARK_SUPPRESSED','reason','MINIMUM_GROUP_NOT_REACHED','policy_version',pol.version);if new_comp then insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(pol.steward_organization_id,null,'SYSTEM','benchmark.suppressed','benchmark_computation',comp::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(pol.steward_organization_id,'benchmark_computation',comp::text,'BenchmarkSuppressedV1',p_correlation_id,r);end if;return r;end if;
 rounded:=round(exact_mean/pol.rounding_increment)*pol.rounding_increment;band:=(floor(n::numeric/5)*5)::integer::text||'-'||((floor(n::numeric/5)*5+4)::integer)::text;
 insert into public.benchmark_publications(computation_id,privacy_policy_id,metric_code,segment_key,period_start,period_end,group_size_band,rounded_mean,methodology,cohort_fingerprint,correlation_id)values(comp,pol.id,p_metric_code,p_segment_key,p_period_start,p_period_end,band,rounded,jsonb_build_object('policy_version',pol.version,'minimum_group_size',pol.minimum_group_size,'rounding_increment',pol.rounding_increment,'minimum_period_days',pol.minimum_period_days,'release_delay_days',pol.release_delay_days,'suppression','SMALL_GROUP','group_size_disclosure','FIVE_MEMBER_BAND'),private.canonical_request_hash(jsonb_build_object('policy',pol.content_hash,'metric',p_metric_code,'segment',p_segment_key,'period_start',p_period_start,'period_end',p_period_end,'manifest',manifest)),p_correlation_id)on conflict(computation_id)do nothing returning id into pub;
 new_pub:=pub is not null;if pub is null then select id into pub from public.benchmark_publications where computation_id=comp;end if;
 r:=jsonb_build_object('outcome','BENCHMARK_PUBLISHED','publication_id',pub,'policy_version',pol.version,'metric_code',p_metric_code,'segment_key',p_segment_key,'period_start',p_period_start,'period_end',p_period_end,'group_size_band',band,'rounded_mean',rounded);
 if new_pub then insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(pol.steward_organization_id,null,'SYSTEM','benchmark.published','benchmark_publication',pub::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(pol.steward_organization_id,'benchmark_publication',pub::text,'BenchmarkPublishedV1',p_correlation_id,r);end if;return r;
end $$;

alter table public.diagnostic_solution_sets enable row level security;alter table public.diagnostic_solution_options enable row level security;alter table public.diagnostic_solution_decisions enable row level security;alter table public.solution_bundle_versions enable row level security;alter table public.solution_bundle_items enable row level security;alter table public.benchmark_privacy_policies enable row level security;alter table public.benchmark_publications enable row level security;alter table private.benchmark_contributions enable row level security;alter table private.benchmark_computations enable row level security;
create policy diagnostic_solution_sets_tenant_read on public.diagnostic_solution_sets for select to authenticated using(private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER','CLIENT_VIEWER'])or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy diagnostic_solution_options_tenant_read on public.diagnostic_solution_options for select to authenticated using(private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER','CLIENT_VIEWER'])or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy diagnostic_solution_decisions_tenant_read on public.diagnostic_solution_decisions for select to authenticated using(private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER','CLIENT_VIEWER'])or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy solution_bundle_versions_tenant_read on public.solution_bundle_versions for select to authenticated using(private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER','CLIENT_VIEWER'])or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy solution_bundle_items_tenant_read on public.solution_bundle_items for select to authenticated using(private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER','CLIENT_VIEWER'])or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy benchmark_privacy_policies_read on public.benchmark_privacy_policies for select to authenticated using(true);
create policy benchmark_publications_read on public.benchmark_publications for select to authenticated using(true);

revoke all on public.diagnostic_solution_sets,public.diagnostic_solution_options,public.diagnostic_solution_decisions,public.solution_bundle_versions,public.solution_bundle_items,public.benchmark_privacy_policies,public.benchmark_publications from public,anon,authenticated,service_role;
grant select on public.diagnostic_solution_sets,public.diagnostic_solution_options,public.diagnostic_solution_decisions,public.solution_bundle_versions,public.solution_bundle_items,public.benchmark_privacy_policies,public.benchmark_publications to authenticated;
revoke all on private.benchmark_contributions,private.benchmark_computations from public,anon,authenticated,service_role;
revoke all on function private.prevent_solution_benchmark_history_change(),private.protect_benchmark_privacy_policy_history(),public.create_anomaly_solution_set(uuid,jsonb,text,text,jsonb,text,uuid),public.record_solution_decision(uuid,text,text,text,timestamptz,text,uuid),public.publish_solution_bundle(uuid,text,integer,text,text,text,text,text,jsonb,jsonb,text,uuid),public.publish_benchmark_privacy_policy(uuid,integer,numeric,integer,integer,jsonb,timestamptz,text,uuid),public.submit_benchmark_contribution(uuid,text,text,date,date,numeric,text,text,text,uuid),public.compute_anonymized_benchmark(uuid,text,text,date,date,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_anomaly_solution_set(uuid,jsonb,text,text,jsonb,text,uuid),public.record_solution_decision(uuid,text,text,text,timestamptz,text,uuid),public.publish_solution_bundle(uuid,text,integer,text,text,text,text,text,jsonb,jsonb,text,uuid),public.publish_benchmark_privacy_policy(uuid,integer,numeric,integer,integer,jsonb,timestamptz,text,uuid),public.submit_benchmark_contribution(uuid,text,text,date,date,numeric,text,text,text,uuid) to authenticated;
grant execute on function public.compute_anonymized_benchmark(uuid,text,text,date,date,uuid) to service_role;
create index diagnostic_solution_sets_org_anomaly_idx on public.diagnostic_solution_sets(organization_id,anomaly_id,version desc);
create index diagnostic_solution_options_set_level_idx on public.diagnostic_solution_options(solution_set_id,level);
create index diagnostic_solution_decisions_org_time_idx on public.diagnostic_solution_decisions(organization_id,decided_at desc);
create index solution_bundle_versions_org_key_idx on public.solution_bundle_versions(organization_id,bundle_key,version desc);
create index solution_bundle_items_service_idx on public.solution_bundle_items(service_id,service_version_id);
create index benchmark_contributions_cohort_idx on private.benchmark_contributions(metric_code,segment_key,period_start,period_end,organization_id);
create index benchmark_publications_lookup_idx on public.benchmark_publications(metric_code,segment_key,period_end desc);
notify pgrst,'reload schema';
