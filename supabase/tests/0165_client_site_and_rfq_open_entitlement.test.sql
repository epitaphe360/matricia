begin;
select plan(11);
select ok(
  pg_get_functiondef('public.open_service_request_rfq(uuid,uuid,timestamptz,text,uuid)'::regprocedure) like '%client_may_open_new_service_request%'
  and pg_get_functiondef('public.open_service_request_rfq(uuid,uuid,timestamptz,text,uuid)'::regprocedure) like '%CLIENT_REQUEST_NOT_ENTITLED%',
  'opening an RFQ on an existing request uses the new-request entitlement helper'
);
select ok(
  pg_get_functiondef('public.open_service_request_rfq(uuid,uuid,timestamptz,text,uuid)'::regprocedure) like '%FAIR-ROTATION-90D-V2%'
  and pg_get_functiondef('public.open_service_request_rfq(uuid,uuid,timestamptz,text,uuid)'::regprocedure) like '%provider_service_eligibility_snapshot%',
  'RFQ opening still applies fair rotation and current eligibility'
);
select has_function('public','start_questionnaire_session',array['uuid','uuid','text','timestamptz','text','uuid','uuid'],'start_questionnaire_session accepts an optional site');
select ok(
  pg_get_functiondef('public.start_questionnaire_session(uuid,uuid,text,timestamptz,text,uuid,uuid)'::regprocedure) like '%SITE_SCOPE_DENIED%'
  and pg_get_functiondef('public.start_questionnaire_session(uuid,uuid,text,timestamptz,text,uuid,uuid)'::regprocedure) like '%site_id%',
  'session start stores and scopes a Client site'
);
select ok(not has_function_privilege('anon','public.start_questionnaire_session(uuid,uuid,text,timestamptz,text,uuid,uuid)','EXECUTE')
  and has_function_privilege('authenticated','public.start_questionnaire_session(uuid,uuid,text,timestamptz,text,uuid,uuid)','EXECUTE'),
  'authenticated keeps start execute; anon cannot start');
select has_column('public','missions','site_id','missions inherit a company site');
select ok(
  pg_get_functiondef('public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid)'::regprocedure) like '%site_id%'
  and pg_get_functiondef('public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid)'::regprocedure) like '%service_requests%',
  'create_mission copies site_id from the contracted service request'
);
select ok(
  pg_get_functiondef('public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid)'::regprocedure) like '%create_mission_legacy_0191%'
  and pg_get_functiondef('public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid)'::regprocedure) like '%MISSION_EXECUTABLE_PUBLISHED_CHECKLIST_REQUIRED%',
  'mission creation still requires the published checklist snapshot'
);
select ok(has_function_privilege('authenticated','public.open_service_request_rfq(uuid,uuid,timestamptz,text,uuid)','EXECUTE'),'authenticated clients keep RFQ open execute');
select ok(has_function_privilege('authenticated','public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid)','EXECUTE'),'authenticated clients keep create_mission execute');
select ok(
  not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'start_questionnaire_session'
      and pg_get_function_identity_arguments(p.oid) = 'uuid, uuid, text, timestamp with time zone, text, uuid'
  ),
  'PostgREST keeps a single start_questionnaire_session signature'
);
select * from finish();
rollback;
