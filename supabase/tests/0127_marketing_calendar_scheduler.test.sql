begin;
set local search_path=public,extensions;
select plan(10);

select has_function('public','generate_due_marketing_calendars_v1',array['date','uuid'],'monthly marketing calendar scheduler exists');
select ok((select p.prosecdef from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='generate_due_marketing_calendars_v1'),'scheduler is SECURITY DEFINER');
select ok((select p.proconfig::text like'%search_path=%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='generate_due_marketing_calendars_v1'),'scheduler fixes its search path');
select ok(has_function_privilege('service_role','public.generate_due_marketing_calendars_v1(date,uuid)','EXECUTE'),'service role can execute scheduler');
select ok(not has_function_privilege('authenticated','public.generate_due_marketing_calendars_v1(date,uuid)','EXECUTE'),'authenticated callers cannot execute scheduler');
select ok(not has_function_privilege('anon','public.generate_due_marketing_calendars_v1(date,uuid)','EXECUTE'),'anonymous callers cannot execute scheduler');

select function_privs_are('public','generate_due_marketing_calendars_v1',array['date','uuid'],'service_role',array['EXECUTE'],'scheduler ACL is exactly service-role execute');
select isnt_empty($$select 1 from pg_get_functiondef('public.generate_due_marketing_calendars_v1(date,uuid)'::regprocedure)d where d like'%MARKETING_CALENDAR_SCHEDULER_DENIED%'and d like'%auth.role() is distinct from ''service_role''%'$$,'scheduler enforces service identity inside the definer boundary');
select isnt_empty($$select 1 from pg_get_functiondef('public.generate_due_marketing_calendars_v1(date,uuid)'::regprocedure)d where d like'%INVALID_MARKETING_CALENDAR_MONTH%'$$,'scheduler bounds the requested month');
select isnt_empty($$select 1 from pg_get_functiondef('public.generate_due_marketing_calendars_v1(date,uuid)'::regprocedure)d where d like'%marketing_consent_active%'and d like'%marketing_exceptions%'and d like'%event_outbox%'and d like'%audit_events%'$$,'autopilot scheduling is consent gated, exception aware, audited and outboxed');

select * from finish();
rollback;
