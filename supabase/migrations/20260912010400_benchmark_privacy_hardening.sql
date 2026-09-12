-- P1 privacy hardening: a benchmark cell has one sealed publication and one
-- privacy-budget unit. Later contributions cannot create a differencing oracle.

create table private.benchmark_cohort_privacy_budgets(
 id uuid primary key default extensions.gen_random_uuid(),
 privacy_policy_id uuid not null references public.benchmark_privacy_policies(id)on delete restrict,
 metric_code text not null check(metric_code~'^[A-Z][A-Z0-9_.-]{1,119}$'),
 segment_key text not null check(segment_key~'^[A-Z][A-Z0-9_.-]{1,119}$'),
 period_start date not null,
 period_end date not null,
 cohort_version integer not null default 1 check(cohort_version>0),
 privacy_budget_total integer not null default 1 check(privacy_budget_total=1),
 privacy_budget_used integer not null default 0 check(privacy_budget_used between 0 and privacy_budget_total),
 status text not null default'OPEN'check(status in('OPEN','SEALED')),
 sealed_publication_id uuid references public.benchmark_publications(id)on delete restrict,
 sealed_input_manifest_hash text check(sealed_input_manifest_hash is null or sealed_input_manifest_hash~'^[0-9a-f]{64}$'),
 created_at timestamptz not null default clock_timestamp(),
 sealed_at timestamptz,
 correlation_id uuid not null,
 unique(privacy_policy_id,metric_code,segment_key,period_start,period_end),
 check(period_end>=period_start),
 check((status='SEALED')=(privacy_budget_used=1 and sealed_publication_id is not null and sealed_input_manifest_hash is not null and sealed_at is not null))
);

create unique index benchmark_one_publication_per_cell_uidx
on public.benchmark_publications(metric_code,segment_key,period_start,period_end);

create function private.protect_benchmark_privacy_budget()returns trigger language plpgsql set search_path=pg_catalog as $$
begin
 if tg_op='DELETE' or old.status<>'OPEN' or new.status<>'SEALED'
  or new.privacy_budget_used<>1 or new.sealed_publication_id is null
  or new.sealed_input_manifest_hash is null or new.sealed_at is null
  or(to_jsonb(new)-array['status','privacy_budget_used','sealed_publication_id','sealed_input_manifest_hash','sealed_at'])
    is distinct from(to_jsonb(old)-array['status','privacy_budget_used','sealed_publication_id','sealed_input_manifest_hash','sealed_at'])
 then raise exception'BENCHMARK_PRIVACY_BUDGET_IMMUTABLE'using errcode='55000';end if;
 return new;
end$$;
create trigger benchmark_privacy_budget_seal_only before update or delete on private.benchmark_cohort_privacy_budgets for each row execute function private.protect_benchmark_privacy_budget();

create or replace function public.submit_benchmark_contribution(p_organization_id uuid,p_metric_code text,p_segment_key text,p_period_start date,p_period_end date,p_value_exact numeric,p_input_version text,p_source_hash text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();h text;r jsonb;cached jsonb;cid uuid;
begin
 if a is null or not private.has_org_role(p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a)then raise exception'BENCHMARK_CONTRIBUTION_DENIED'using errcode='42501';end if;
 if p_metric_code!~'^[A-Z][A-Z0-9_.-]{1,119}$'or p_segment_key!~'^[A-Z][A-Z0-9_.-]{1,119}$'or p_period_start is null or p_period_end<p_period_start or length(btrim(coalesce(p_input_version,'')))not between 1 and 120 or p_source_hash!~'^[0-9a-f]{64}$'then raise exception'INVALID_BENCHMARK_CONTRIBUTION'using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('organization',p_organization_id,'metric',p_metric_code,'segment',p_segment_key,'period_start',p_period_start,'period_end',p_period_end,'value',p_value_exact,'input_version',p_input_version,'source_hash',p_source_hash));cached:=private.begin_contract_command(p_organization_id,'benchmark.contribution.'||p_metric_code||'.'||p_segment_key,p_idempotency_key,h,a);if cached is not null then return cached;end if;
 if exists(select 1 from public.benchmark_publications where metric_code=p_metric_code and segment_key=p_segment_key and period_start=p_period_start and period_end=p_period_end)then raise exception'BENCHMARK_CELL_SEALED'using errcode='55000';end if;
 insert into private.benchmark_contributions(organization_id,metric_code,segment_key,period_start,period_end,value_exact,input_version,source_hash,submitted_by,correlation_id)values(p_organization_id,p_metric_code,p_segment_key,p_period_start,p_period_end,p_value_exact,p_input_version,p_source_hash,a,p_correlation_id)returning id into cid;
 r:=jsonb_build_object('outcome','BENCHMARK_CONTRIBUTION_ACCEPTED','contribution_id',cid,'metric_code',p_metric_code,'period_end',p_period_end);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,a,'USER','benchmark.contribution.submitted','benchmark_contribution',cid::text,p_correlation_id,jsonb_build_object('metric_code',p_metric_code,'segment_key',p_segment_key,'period_start',p_period_start,'period_end',p_period_end,'input_version',p_input_version,'source_hash',p_source_hash),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_organization_id,'benchmark_contribution',cid::text,'BenchmarkContributionAcceptedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(p_organization_id,'benchmark.contribution.'||p_metric_code||'.'||p_segment_key,p_idempotency_key,r);return r;
end$$;

create or replace function public.compute_anonymized_benchmark(p_privacy_policy_id uuid,p_metric_code text,p_segment_key text,p_period_start date,p_period_end date,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare pol public.benchmark_privacy_policies%rowtype;n integer;exact_mean numeric(30,6);manifest text;comp uuid;pub uuid;rounded numeric(30,6);band text;budget private.benchmark_cohort_privacy_budgets%rowtype;r jsonb;
begin
 if auth.role()<>'service_role'then raise exception'BENCHMARK_WORKER_ONLY'using errcode='42501';end if;
 select*into pol from public.benchmark_privacy_policies where id=p_privacy_policy_id;if not found then raise exception'BENCHMARK_POLICY_NOT_FOUND'using errcode='P0002';end if;
 if pol.status not in('ACTIVE','RETIRED')or p_metric_code!~'^[A-Z][A-Z0-9_.-]{1,119}$'or p_segment_key!~'^[A-Z][A-Z0-9_.-]{1,119}$'or p_period_end<p_period_start or(p_period_end-p_period_start+1)<pol.minimum_period_days or clock_timestamp()<p_period_end::timestamptz+make_interval(days=>pol.release_delay_days)then raise exception'BENCHMARK_PRIVACY_WINDOW_INVALID'using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('benchmark-cell:'||p_metric_code||':'||p_segment_key||':'||p_period_start::text||':'||p_period_end::text,0));
 select id into pub from public.benchmark_publications where metric_code=p_metric_code and segment_key=p_segment_key and period_start=p_period_start and period_end=p_period_end;
 if found then raise exception'BENCHMARK_CELL_SEALED'using errcode='55000';end if;
 select b.* into budget from private.benchmark_cohort_privacy_budgets b where b.privacy_policy_id=pol.id and b.metric_code=p_metric_code and b.segment_key=p_segment_key and b.period_start=p_period_start and b.period_end=p_period_end for update;
 if found and budget.status='SEALED'then raise exception'BENCHMARK_CELL_SEALED'using errcode='55000';end if;
 if not found then insert into private.benchmark_cohort_privacy_budgets(privacy_policy_id,metric_code,segment_key,period_start,period_end,cohort_version,privacy_budget_total,privacy_budget_used,status,correlation_id)values(pol.id,p_metric_code,p_segment_key,p_period_start,p_period_end,1,1,0,'OPEN',p_correlation_id)returning*into budget;end if;
 with latest as(select distinct on(organization_id)organization_id,value_exact,source_hash from private.benchmark_contributions where metric_code=p_metric_code and segment_key=p_segment_key and period_start=p_period_start and period_end=p_period_end order by organization_id,submitted_at desc,id desc)
 select count(*),avg(value_exact),encode(extensions.digest(convert_to(coalesce(string_agg(organization_id::text||':'||source_hash,','order by organization_id),'EMPTY'),'UTF8'),'sha256'),'hex')into n,exact_mean,manifest from latest;
 if n<pol.minimum_group_size then insert into private.benchmark_computations(privacy_policy_id,metric_code,segment_key,period_start,period_end,contributor_count,exact_mean,input_manifest_hash,outcome,correlation_id)values(pol.id,p_metric_code,p_segment_key,p_period_start,p_period_end,n,null,manifest,'SUPPRESSED_SMALL_GROUP',p_correlation_id)on conflict do nothing;r:=jsonb_build_object('outcome','BENCHMARK_SUPPRESSED','reason','MINIMUM_GROUP_NOT_REACHED','policy_version',pol.version,'cohort_version',budget.cohort_version);return r;end if;
 insert into private.benchmark_computations(privacy_policy_id,metric_code,segment_key,period_start,period_end,contributor_count,exact_mean,input_manifest_hash,outcome,correlation_id)values(pol.id,p_metric_code,p_segment_key,p_period_start,p_period_end,n,exact_mean,manifest,'PUBLISHED',p_correlation_id)on conflict(privacy_policy_id,metric_code,segment_key,period_start,period_end,input_manifest_hash)do nothing returning id into comp;
 if comp is null then select id into comp from private.benchmark_computations where privacy_policy_id=pol.id and metric_code=p_metric_code and segment_key=p_segment_key and period_start=p_period_start and period_end=p_period_end and input_manifest_hash=manifest;end if;
 rounded:=round(exact_mean/pol.rounding_increment)*pol.rounding_increment;band:=(floor(n::numeric/5)*5)::integer::text||'-'||((floor(n::numeric/5)*5+4)::integer)::text;
 insert into public.benchmark_publications(computation_id,privacy_policy_id,metric_code,segment_key,period_start,period_end,group_size_band,rounded_mean,methodology,cohort_fingerprint,correlation_id)values(comp,pol.id,p_metric_code,p_segment_key,p_period_start,p_period_end,band,rounded,jsonb_build_object('policy_version',pol.version,'cohort_version',budget.cohort_version,'privacy_budget_total',1,'privacy_budget_used',1,'minimum_group_size',pol.minimum_group_size,'rounding_increment',pol.rounding_increment,'minimum_period_days',pol.minimum_period_days,'release_delay_days',pol.release_delay_days,'suppression','SMALL_GROUP','group_size_disclosure','FIVE_MEMBER_BAND','republication','SEALED'),private.canonical_request_hash(jsonb_build_object('policy',pol.content_hash,'metric',p_metric_code,'segment',p_segment_key,'period_start',p_period_start,'period_end',p_period_end,'cohort_version',budget.cohort_version,'manifest',manifest)),p_correlation_id)returning id into pub;
 update private.benchmark_cohort_privacy_budgets set status='SEALED',privacy_budget_used=1,sealed_publication_id=pub,sealed_input_manifest_hash=manifest,sealed_at=clock_timestamp()where id=budget.id and status='OPEN'and privacy_budget_used=0;
 r:=jsonb_build_object('outcome','BENCHMARK_PUBLISHED','publication_id',pub,'policy_version',pol.version,'cohort_version',budget.cohort_version,'metric_code',p_metric_code,'segment_key',p_segment_key,'period_start',p_period_start,'period_end',p_period_end,'group_size_band',band,'rounded_mean',rounded);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(pol.steward_organization_id,null,'SYSTEM','benchmark.published','benchmark_publication',pub::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(pol.steward_organization_id,'benchmark_publication',pub::text,'BenchmarkPublishedV1',p_correlation_id,r);return r;
end$$;

alter table private.benchmark_cohort_privacy_budgets enable row level security;
revoke all on private.benchmark_cohort_privacy_budgets from public,anon,authenticated,service_role;
revoke all on function private.protect_benchmark_privacy_budget(),public.submit_benchmark_contribution(uuid,text,text,date,date,numeric,text,text,text,uuid),public.compute_anonymized_benchmark(uuid,text,text,date,date,uuid)from public,anon,authenticated,service_role;
grant execute on function public.submit_benchmark_contribution(uuid,text,text,date,date,numeric,text,text,text,uuid)to authenticated;
grant execute on function public.compute_anonymized_benchmark(uuid,text,text,date,date,uuid)to service_role;
create index benchmark_privacy_budget_status_idx on private.benchmark_cohort_privacy_budgets(status,period_end,metric_code,segment_key);
notify pgrst,'reload schema';
