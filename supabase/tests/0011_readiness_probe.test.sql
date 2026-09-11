begin;
set local search_path=public,extensions;
select plan(4);

select ok(not has_function_privilege('anon','public.readiness_status()','EXECUTE'),'anon cannot invoke readiness');
select ok(not has_function_privilege('authenticated','public.readiness_status()','EXECUTE'),'authenticated cannot invoke readiness');
select ok(has_function_privilege('service_role','public.readiness_status()','EXECUTE'),'service role may invoke readiness');

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
create temporary table readiness_observed(ok boolean);
grant select,insert on readiness_observed to service_role;
insert into readiness_observed select database_ok and pending_events>=0 and oldest_pending_seconds>=0 from public.readiness_status();
reset role;
select ok((select ok from readiness_observed),'readiness returns bounded non-sensitive health data');

select * from finish();
rollback;
