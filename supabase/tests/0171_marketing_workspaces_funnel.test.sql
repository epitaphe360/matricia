begin;
set local search_path=public,extensions;
select plan(14);

select isnt_empty($$select 1 from pg_get_functiondef('public.approve_assisted_marketing_calendar_v1(uuid,integer,text,uuid)'::regprocedure)d where d like'%CLIENT_OWNER%'and d like'%PROVIDER_OWNER%'and d like'%FRANCHISE_OWNER%'$$,'ASSISTED global approval is open to Client, Provider and Franchise owners');
select isnt_empty($$select 1 from pg_get_functiondef('public.approve_assisted_marketing_calendar_v1(uuid,integer,text,uuid)'::regprocedure)d where d like'%marketing_consent_active%'and d like'%audit_events%'and d like'%event_outbox%'$$,'ASSISTED approval keeps consent, audit and outbox controls');
select ok(has_function_privilege('authenticated','public.approve_assisted_marketing_calendar_v1(uuid,integer,text,uuid)','EXECUTE')and not has_function_privilege('anon','public.approve_assisted_marketing_calendar_v1(uuid,integer,text,uuid)','EXECUTE'),'ASSISTED approval stays an authenticated-only entrypoint');

select has_table('public','marketing_frequency_adjustments','weekly frequency decisions are recorded');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.marketing_frequency_adjustments'::regclass),'frequency decisions use forced RLS');
select ok(not has_table_privilege('authenticated','public.marketing_frequency_adjustments','INSERT')and not has_table_privilege('authenticated','public.marketing_frequency_adjustments','UPDATE')and not has_table_privilege('anon','public.marketing_frequency_adjustments','SELECT'),'frequency decisions cannot be written by users nor read anonymously');
select isnt_empty($$select 1 from pg_trigger where tgrelid='public.marketing_frequency_adjustments'::regclass and tgname='marketing_frequency_adjustments_immutable'$$,'frequency decisions are immutable');
select isnt_empty($$select 1 from pg_constraint where conrelid='public.marketing_frequency_adjustments'::regclass and pg_get_constraintdef(oid) like'%abs((new_frequency - previous_frequency)) <= 1%'$$,'a weekly adjustment moves the frequency by one step at most');

select has_function('public','apply_marketing_weekly_frequency_v1',array['date','text','uuid'],'weekly frequency command exists');
select ok((select prosecdef and proconfig::text like'%search_path=%' from pg_proc where oid='public.apply_marketing_weekly_frequency_v1(date,text,uuid)'::regprocedure),'weekly frequency command is a hardened SECURITY DEFINER function');
select ok(has_function_privilege('service_role','public.apply_marketing_weekly_frequency_v1(date,text,uuid)','EXECUTE')and not has_function_privilege('authenticated','public.apply_marketing_weekly_frequency_v1(date,text,uuid)','EXECUTE')and not has_function_privilege('anon','public.apply_marketing_weekly_frequency_v1(date,text,uuid)','EXECUTE'),'weekly frequency command is reserved to the worker');
select isnt_empty($$select 1 from pg_get_functiondef('public.apply_marketing_weekly_frequency_v1(date,text,uuid)'::regprocedure)d where d like'%AUTOPILOT%'and d like'%HUMAN_REVIEW_REQUIRED%'and d like'%begin_marketing_worker_command%'$$,'only AUTOPILOT campaigns are adjusted, idempotently; other recommendations wait for a human');
select isnt_empty($$select 1 from pg_get_functiondef('public.apply_marketing_weekly_frequency_v1(date,text,uuid)'::regprocedure)d where d like'%audit_events%'and d like'%MarketingWeeklyFrequencyReviewedV1%'$$,'weekly frequency decisions are audited and outboxed');

set local role authenticated;
set local request.jwt.claims='{"role":"authenticated","sub":"00000000-0000-4000-8000-000000000171"}';
select throws_ok($$select public.apply_marketing_weekly_frequency_v1(date '2026-09-21','marketing-frequency:test')$$,'42501',null,'an authenticated user cannot run the weekly frequency worker');

select * from finish();
rollback;
