begin;
set local search_path=public,extensions;
select plan(25);

select has_table('public','ai_provider_configs','AI provider configs exist');
select has_table('public','ai_price_versions','versioned AI prices exist');
select has_table('public','ai_budgets','AI budgets exist');
select has_table('public','ai_usage_events','immutable AI usage ledger exists');
select has_table('public','ai_cost_allocations','AI cost allocations exist');
select has_table('public','cost_allocation_rules','versioned cost allocation rules exist');
select has_table('public','benefit_actual_costs','actual benefit costs exist');
select has_table('public','benefit_margin_snapshots','forecast/actual margin snapshots exist');
select has_table('public','treasury_budget_versions','versioned Matricia treasury budgets exist');
select has_table('public','treasury_cashflow_snapshots','30/60/90 cash-flow snapshots exist');

select ok(has_function_privilege('service_role','public.record_ai_usage(uuid,uuid,uuid,text,text,text,bigint,text,text,text,uuid)','EXECUTE')
  and not has_function_privilege('authenticated','public.record_ai_usage(uuid,uuid,uuid,text,text,text,bigint,text,text,text,uuid)','EXECUTE'),
  'AI usage mutation is service-role-only');
select ok(has_function_privilege('service_role','public.record_benefit_actual_cost(uuid,uuid,text,bigint,character,text,text,uuid)','EXECUTE')
  and not has_function_privilege('authenticated','public.record_benefit_actual_cost(uuid,uuid,text,bigint,character,text,text,uuid)','EXECUTE'),
  'actual-cost mutation is service-role-only');

select ok((select prosecdef and proconfig::text like '%search_path=pg_catalog%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_ai_usage'),'AI usage RPC has fixed search path');
select ok((select pg_get_functiondef(p.oid) like '%AI_BUDGET_EXHAUSTED%' and pg_get_functiondef(p.oid) like '%AI_USAGE_REPLAY_MISMATCH%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_ai_usage'),'AI usage RPC enforces circuit breaker and anti-replay');
select ok((select data_type='bigint' from information_schema.columns where table_schema='public' and table_name='ai_usage_events' and column_name='cost_minor'),'AI ledger stores exact minor units');
select ok((select data_type='bigint' from information_schema.columns where table_schema='public' and table_name='benefit_actual_costs' and column_name='amount_minor'),'benefit actual costs store exact minor units');
select ok((select check_clause like '%forecast_horizon_days%' from information_schema.check_constraints where constraint_name='treasury_cashflow_snapshots_forecast_horizon_days_check'),'cash-flow horizon is constrained');

select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='ai_usage_events'),'AI usage has RLS');
select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='benefit_actual_costs'),'actual costs have RLS');
select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='treasury_cashflow_snapshots'),'treasury snapshots have RLS');

select is((select count(*) from pg_trigger where tgrelid='public.ai_usage_events'::regclass and not tgisinternal and tgname='ai_usage_events_immutable'),1::bigint,'AI usage ledger is immutable');
select is((select count(*) from pg_trigger where tgrelid='public.benefit_actual_costs'::regclass and not tgisinternal and tgname='benefit_actual_costs_immutable'),1::bigint,'actual cost ledger is immutable');
select is((select count(*) from pg_trigger where tgrelid='public.benefit_margin_snapshots'::regclass and not tgisinternal and tgname='benefit_margin_snapshots_immutable'),1::bigint,'margin snapshots are immutable');
select is((select count(*) from pg_trigger where tgrelid='public.treasury_budget_versions'::regclass and not tgisinternal and tgname='treasury_budget_versions_immutable'),1::bigint,'treasury budgets are immutable');
select is((select count(*) from pg_indexes where schemaname='public' and indexname in('ai_usage_events_scope_time_idx','ai_budgets_scope_period_idx','benefit_actual_costs_redemption_idx','treasury_cashflow_horizon_idx')),4::bigint,'operational reconciliation indexes exist');

select * from finish();
rollback;
