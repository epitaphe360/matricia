begin;
set local search_path=public,extensions;
select plan(11);

select has_function('public','schedule_marketing_campaign',array['uuid','jsonb','integer','text','uuid'],'schedule command remains available');
select isnt_empty($$select 1 from pg_get_functiondef('public.schedule_marketing_campaign(uuid,jsonb,integer,text,uuid)'::regprocedure)d where d like'%calendar_id%'and d like'%MARKETING_ACTIVE_SCHEDULE_RULE_REQUIRED%'$$,'manual scheduling always resolves a governed calendar');
select isnt_empty($$select 1 from pg_get_functiondef('public.schedule_marketing_campaign(uuid,jsonb,integer,text,uuid)'::regprocedure)d where d like'%pg_advisory_xact_lock%'and d like'%date_trunc(''week''%'$$,'weekly frequency is serialized and calendar-week bounded');
select isnt_empty($$select 1 from pg_get_functiondef('public.schedule_marketing_campaign(uuid,jsonb,integer,text,uuid)'::regprocedure)d where d like'%marketing_publication_ready_v41%'and d like'%marketing_exceptions%'$$,'manual scheduling fails closed on policy and blocking exceptions');
select ok(has_function_privilege('authenticated','public.schedule_marketing_campaign(uuid,jsonb,integer,text,uuid)','EXECUTE'),'authenticated users may invoke the guarded schedule command');
select ok(not has_function_privilege('anon','public.schedule_marketing_campaign(uuid,jsonb,integer,text,uuid)','EXECUTE'),'anonymous users cannot schedule campaigns');

select isnt_empty($$select 1 from pg_constraint where conrelid='public.social_publication_results'::regclass and contype='c'and pg_get_constraintdef(oid)like'%SANDBOXED%'$$,'publication results explicitly model sandbox execution');
select isnt_empty($$select 1 from pg_get_functiondef('public.record_social_publication_worker_result_v41(uuid,text,text,text,text,uuid)'::regprocedure)d where d like'%SocialPublicationSandboxedV1%'and d like'%p_outcome=''SANDBOXED''%'$$,'worker records sandbox without a publication proof');
select ok(not has_function_privilege('authenticated','private.marketing_publication_ready_v41(uuid,text,uuid,uuid)','EXECUTE'),'private publication readiness is not exposed to authenticated callers');
select ok(has_function_privilege('service_role','public.record_social_publication_worker_result_v41(uuid,text,text,text,text,uuid)','EXECUTE'),'service worker can record its result');
select ok(not has_function_privilege('authenticated','public.record_social_publication_worker_result_v41(uuid,text,text,text,text,uuid)','EXECUTE'),'users cannot forge worker results');

select * from finish();
rollback;
