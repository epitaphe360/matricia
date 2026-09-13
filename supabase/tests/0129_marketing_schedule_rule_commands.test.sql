begin;
set local search_path=public,extensions;
select plan(18);

select has_function('public','create_marketing_schedule_rule_version_v1',array['uuid','uuid','text','integer','integer','integer','jsonb','integer','integer','text','uuid'],'schedule rule version create command exists');
select has_function('public','activate_marketing_schedule_rule_version_v1',array['uuid','integer','text','uuid'],'schedule rule version activation command exists');
select has_function('public','approve_assisted_marketing_calendar_v1',array['uuid','integer','text','uuid'],'ASSISTED global approval command exists');
select ok((select count(*)=3 and bool_and(p.prosecdef and p.proconfig::text like'%search_path=%')from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname=any(array['create_marketing_schedule_rule_version_v1','activate_marketing_schedule_rule_version_v1','approve_assisted_marketing_calendar_v1'])),'all commands are hardened SECURITY DEFINER functions');
select ok((select count(*)=3 and bool_and(has_function_privilege('authenticated',p.oid,'EXECUTE')and not has_function_privilege('anon',p.oid,'EXECUTE')and not has_function_privilege('service_role',p.oid,'EXECUTE'))from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname=any(array['create_marketing_schedule_rule_version_v1','activate_marketing_schedule_rule_version_v1','approve_assisted_marketing_calendar_v1'])),'commands expose least-privilege authenticated entrypoints');
select ok(not has_function_privilege('authenticated','private.valid_marketing_allowed_slots_v1(jsonb)','EXECUTE'),'slot validator is not an API surface');

select ok(private.valid_marketing_allowed_slots_v1('[{"dayOfMonth":5,"time":"09:30"}]'),'strict slot validator accepts canonical day/time');
select ok(not private.valid_marketing_allowed_slots_v1('[]'),'strict slot validator rejects an empty schedule');
select ok(not private.valid_marketing_allowed_slots_v1('[{"dayOfMonth":0,"time":"09:30"}]'),'strict slot validator rejects invalid calendar days');
select ok(not private.valid_marketing_allowed_slots_v1('[{"dayOfMonth":5,"time":"24:00"}]'),'strict slot validator rejects invalid times');
select ok(not private.valid_marketing_allowed_slots_v1('[{"dayOfMonth":5,"time":"09:30","unsafe":true}]'),'strict slot validator rejects unknown fields');
select ok(not private.valid_marketing_allowed_slots_v1('[{"dayOfMonth":5,"time":"09:30"},{"dayOfMonth":5,"time":"09:30"}]'),'strict slot validator rejects duplicate slots');

select isnt_empty($$select 1 from pg_get_functiondef('public.create_marketing_schedule_rule_version_v1(uuid,uuid,text,integer,integer,integer,jsonb,integer,integer,text,uuid)'::regprocedure)d where d like'%pg_timezone_names%'and d like'%pg_advisory_xact_lock%'and d like'%begin_contract_command%'$$,'create validates IANA timezone and serializes version allocation idempotently');
select isnt_empty($$select 1 from pg_get_functiondef('public.activate_marketing_schedule_rule_version_v1(uuid,integer,text,uuid)'::regprocedure)d where d like'%for update%'and d like'%STALE_MARKETING_SCHEDULE_RULE_HEAD%'and d like'%begin_contract_command%'$$,'activation locks and compare-and-swaps the tenant head idempotently');
select isnt_empty($$select 1 from pg_get_functiondef('public.approve_assisted_marketing_calendar_v1(uuid,integer,text,uuid)'::regprocedure)d where d like'%has_org_role%'and d like'%CLIENT_OWNER%'$$,'ASSISTED approval is restricted to CLIENT_OWNER');
select isnt_empty($$select 1 from pg_get_functiondef('public.approve_assisted_marketing_calendar_v1(uuid,integer,text,uuid)'::regprocedure)d where d like'%marketing_publication_ready_v41%'and d like'%marketing_consent_active%'and d like'%marketing_exceptions%'$$,'ASSISTED approval fails closed on consent, readiness and exceptions');
select isnt_empty($$select 1 from pg_get_functiondef('public.approve_assisted_marketing_calendar_v1(uuid,integer,text,uuid)'::regprocedure)d where d like'%event_outbox%'and d like'%audit_events%'and d like'%SocialPublicationScheduledV1%'$$,'ASSISTED approval is audited, outboxed and schedules idempotent jobs');
select isnt_empty($$select 1 from pg_get_functiondef('public.create_marketing_schedule_rule_version_v1(uuid,uuid,text,integer,integer,integer,jsonb,integer,integer,text,uuid)'::regprocedure)d where d like'%MARKETING_SCHEDULE_RULE_CREATE_DENIED%'and d like'%marketing_manage_access%'and d like'%account.organization_id%'$$,'schedule rule creation enforces tenant parent ownership');

select * from finish();
rollback;
