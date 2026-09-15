begin;
select plan(4);
select has_function('public','get_public_subscription_plans',array[]::text[],'public plan projection exists');
select ok(has_function_privilege('anon','public.get_public_subscription_plans()','EXECUTE'),'anonymous visitors can read the projection');
select ok(not has_table_privilege('anon','public.subscription_plan_versions','SELECT'),'anonymous visitors cannot read billing tables');
select ok(pg_get_functiondef('public.get_public_subscription_plans()'::regprocedure) like '%plan.code in (%','projection restricts publishable plan codes');
select * from finish();
rollback;
