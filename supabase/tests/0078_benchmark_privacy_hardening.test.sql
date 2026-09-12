begin;
set local search_path=public,extensions;
select plan(24);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values
('a7800000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p1-bench-1@example.invalid','',now(),'{}','{}',now(),now()),
('a7800000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p1-bench-2@example.invalid','',now(),'{}','{}',now(),now()),
('a7800000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p1-bench-3@example.invalid','',now(),'{}','{}',now(),now()),
('a7800000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p1-bench-4@example.invalid','',now(),'{}','{}',now(),now()),
('a7800000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p1-bench-5@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)select ('b7800000-0000-0000-0000-00000000000'||n)::uuid,'Benchmark Tenant '||n,'Bench '||n,'ACTIVE',('a7800000-0000-0000-0000-00000000000'||n)::uuid from generate_series(1,5)n;
insert into public.organization_memberships(organization_id,user_id,status,activated_at)select ('b7800000-0000-0000-0000-00000000000'||n)::uuid,('a7800000-0000-0000-0000-00000000000'||n)::uuid,'ACTIVE',now()from generate_series(1,5)n;
insert into public.organization_member_roles(membership_id,role_code)select id,'CLIENT_ADMIN'from public.organization_memberships where user_id::text like'a7800000-%';
insert into public.benchmark_privacy_policies(id,steward_organization_id,version,status,minimum_group_size,rounding_increment,minimum_period_days,release_delay_days,policy_snapshot,content_hash,effective_from,created_by,correlation_id)values('c7800000-0000-0000-0000-000000000001','b7800000-0000-0000-0000-000000000001',(select coalesce(max(version),0)+1 from public.benchmark_privacy_policies),'RETIRED',5,10,7,1,'{"version":"P1"}',repeat('a',64),'2026-01-01','a7800000-0000-0000-0000-000000000001','d7800000-0000-0000-0000-000000000001');
insert into private.benchmark_contributions(organization_id,metric_code,segment_key,period_start,period_end,value_exact,input_version,source_hash,submitted_by,correlation_id)
select ('b7800000-0000-0000-0000-00000000000'||n)::uuid,'MARGIN_BPS','IT_SERVICES','2026-01-01','2026-01-31',n*10,'v1',repeat(n::text,64),('a7800000-0000-0000-0000-00000000000'||n)::uuid,('d7800000-0000-0000-0000-00000000000'||n)::uuid from generate_series(1,5)n;

create temporary table p1_benchmark_observed(key text primary key,value text);
grant insert,select on p1_benchmark_observed to service_role,authenticated;
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into p1_benchmark_observed values('first',public.compute_anonymized_benchmark('c7800000-0000-0000-0000-000000000001','MARGIN_BPS','IT_SERVICES','2026-01-01','2026-01-31')->>'outcome');
reset role;

select is((select value from p1_benchmark_observed where key='first'),'BENCHMARK_PUBLISHED','five-tenant cohort publishes once');
select throws_ok($$set local role service_role;select set_config('request.jwt.claims','{"role":"service_role"}',true);select public.compute_anonymized_benchmark('c7800000-0000-0000-0000-000000000001','MARGIN_BPS','IT_SERVICES','2026-01-01','2026-01-31')$$,'55000','BENCHMARK_CELL_SEALED','recompute is denied and cannot expose a delta');
select is((select count(*)from public.benchmark_publications where privacy_policy_id='c7800000-0000-0000-0000-000000000001'),1::bigint,'only one publication exists for the cell');
select is((select rounded_mean from public.benchmark_publications where privacy_policy_id='c7800000-0000-0000-0000-000000000001'),30.000000::numeric,'mean is protectively rounded');
select is((select group_size_band from public.benchmark_publications where privacy_policy_id='c7800000-0000-0000-0000-000000000001'),'5-9','exact cohort size is not published');
select is((select status from private.benchmark_cohort_privacy_budgets where privacy_policy_id='c7800000-0000-0000-0000-000000000001'),'SEALED','cohort privacy budget is sealed');
select is((select privacy_budget_total from private.benchmark_cohort_privacy_budgets where privacy_policy_id='c7800000-0000-0000-0000-000000000001'),1,'privacy budget permits one publication');
select is((select privacy_budget_used from private.benchmark_cohort_privacy_budgets where privacy_policy_id='c7800000-0000-0000-0000-000000000001'),1,'single privacy budget unit is consumed');
select is((select cohort_version from private.benchmark_cohort_privacy_budgets where privacy_policy_id='c7800000-0000-0000-0000-000000000001'),1,'cohort version is explicit');
select throws_ok($$update public.benchmark_publications set rounded_mean=40 where privacy_policy_id='c7800000-0000-0000-0000-000000000001'$$,'55000','SOLUTION_BENCHMARK_HISTORY_IMMUTABLE','published aggregate cannot be changed');
select throws_ok($$update private.benchmark_cohort_privacy_budgets set privacy_budget_used=0 where privacy_policy_id='c7800000-0000-0000-0000-000000000001'$$,'55000','BENCHMARK_PRIVACY_BUDGET_IMMUTABLE','sealed privacy budget cannot be reopened');
select throws_ok($$delete from public.benchmark_publications where privacy_policy_id='c7800000-0000-0000-0000-000000000001'$$,'55000','SOLUTION_BENCHMARK_HISTORY_IMMUTABLE','published aggregate cannot be deleted');
select ok(exists(select 1 from pg_indexes where schemaname='public'and indexname='benchmark_one_publication_per_cell_uidx'and indexdef like'%metric_code, segment_key, period_start, period_end%'and indexdef not like'%privacy_policy_id, metric_code%'),'database uniqueness seals one publication per cell across policy versions');
select ok(not has_table_privilege('authenticated','private.benchmark_cohort_privacy_budgets','SELECT')and not has_table_privilege('service_role','private.benchmark_cohort_privacy_budgets','SELECT'),'privacy budget internals have no direct API grant');
select ok((select relrowsecurity from pg_class where oid='private.benchmark_cohort_privacy_budgets'::regclass),'privacy budgets have restrictive RLS');
select ok((select p.prosrc like'%pg_advisory_xact_lock%'and p.prosrc like'%status=''SEALED''%'and p.prosrc like'%BENCHMARK_CELL_SEALED%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='compute_anonymized_benchmark'),'compute serializes and denies sealed cells');
select ok((select p.prosrc like'%privacy_budget_total%'and p.prosrc like'%privacy_budget_used%'and p.prosrc like'%cohort_version%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='compute_anonymized_benchmark'),'publication records budget and cohort version');
select ok((select p.prosrc like'%distinct on(organization_id)%'and p.prosrc like'%round(exact_mean/pol.rounding_increment)%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='compute_anonymized_benchmark'),'one latest value per tenant and policy rounding are enforced');
select ok(not exists(select 1 from information_schema.columns where table_schema='public'and table_name='benchmark_publications'and column_name in('organization_id','contributor_count','exact_mean','input_manifest_hash','privacy_budget_used')),'public result exposes neither members, exact cohort, exact mean, manifest nor budget internals');
select ok((select methodology->>'republication'='SEALED'and methodology->>'group_size_disclosure'='FIVE_MEMBER_BAND'from public.benchmark_publications where privacy_policy_id='c7800000-0000-0000-0000-000000000001'),'published methodology explains sealing and size protection');

set local role authenticated;
select set_config('request.jwt.claim.sub','a7800000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"a7800000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into p1_benchmark_observed values('other_tenant_count',(select count(*)::text from public.organizations where id='b7800000-0000-0000-0000-000000000002')),('aggregate_count',(select count(*)::text from public.benchmark_publications where privacy_policy_id='c7800000-0000-0000-0000-000000000001'));
reset role;
select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','a7800000-0000-0000-0000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a7800000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true);select public.submit_benchmark_contribution('b7800000-0000-0000-0000-000000000001','MARGIN_BPS','IT_SERVICES','2026-01-01','2026-01-31',99,'v2',repeat('f',64),'sealed-cell-new-version')$$,'55000','BENCHMARK_CELL_SEALED','new contribution version cannot reopen a published cell');
select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','a7800000-0000-0000-0000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a7800000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true);select public.submit_benchmark_contribution('b7800000-0000-0000-0000-000000000002','OTHER_METRIC','IT_SERVICES','2026-01-01','2026-01-31',99,'v1',repeat('e',64),'cross-tenant-attempt')$$,'42501','BENCHMARK_CONTRIBUTION_DENIED','tenant cannot submit for another tenant');
select is((select value::bigint from p1_benchmark_observed where key='other_tenant_count'),0::bigint,'RLS hides another contributing tenant');
select is((select value::bigint from p1_benchmark_observed where key='aggregate_count'),1::bigint,'authenticated reader sees only the sealed aggregate');

select*from finish();rollback;
