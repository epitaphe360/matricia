begin;
select plan(9);
select has_function('private','client_may_open_new_service_request',array['uuid'],'new-request entitlement helper exists');
select ok(not has_function_privilege('anon','private.client_may_open_new_service_request(uuid)','EXECUTE')
  and not has_function_privilege('authenticated','private.client_may_open_new_service_request(uuid)','EXECUTE'),
  'clients cannot invoke the helper directly');
select ok(
  pg_get_functiondef('private.client_may_open_new_service_request(uuid)'::regprocedure) like '%TRIAL_EXPIRED%'
  and pg_get_functiondef('private.client_may_open_new_service_request(uuid)'::regprocedure) like '%TRIAL_ACTIVE%'
  and pg_get_functiondef('private.client_may_open_new_service_request(uuid)'::regprocedure) like '%ACTIVE%'
  and pg_get_functiondef('private.client_may_open_new_service_request(uuid)'::regprocedure) like '%DOCUMENT_EXPIRED%'
  and pg_get_functiondef('private.client_may_open_new_service_request(uuid)'::regprocedure) like '%QUESTIONED%',
  'helper blocks expired trial, unpaid subscription and unresolved expired-document anomalies'
);
select ok(
  pg_get_functiondef('public.create_service_request(uuid,uuid,uuid,uuid,jsonb,text,text,uuid)'::regprocedure) like '%client_may_open_new_service_request%'
  and pg_get_functiondef('public.create_service_request(uuid,uuid,uuid,uuid,jsonb,text,text,uuid)'::regprocedure) like '%CLIENT_REQUEST_NOT_ENTITLED%',
  'create_service_request enforces the entitlement helper'
);
select ok(
  pg_get_functiondef('private.clone_request_core(uuid,date,uuid,text,boolean)'::regprocedure) like '%client_may_open_new_service_request%'
  and pg_get_functiondef('private.clone_request_core(uuid,date,uuid,text,boolean)'::regprocedure) like '%CLIENT_REQUEST_NOT_ENTITLED%',
  'clone and recurring generation enforce the same helper'
);
select ok(
  pg_get_functiondef('public.create_service_request(uuid,uuid,uuid,uuid,jsonb,text,text,uuid)'::regprocedure) like '%begin_rfq_command%'
  and pg_get_functiondef('public.create_service_request(uuid,uuid,uuid,uuid,jsonb,text,text,uuid)'::regprocedure) like '%ServiceRequestCreatedV1%',
  'create remains idempotent and audited'
);
select ok(
  pg_get_functiondef('private.clone_request_core(uuid,date,uuid,text,boolean)'::regprocedure) like '%PUBLISHED%'
  and pg_get_functiondef('private.clone_request_core(uuid,date,uuid,text,boolean)'::regprocedure) like '%APPROVED%',
  'clone still revalidates published catalogue and questionnaire'
);
select ok(
  pg_get_functiondef('public.create_service_request_from_need_intake(uuid,text,jsonb,text,uuid)'::regprocedure) like '%create_service_request(%'
  and pg_get_functiondef('public.create_service_request_from_opportunity(uuid,jsonb,text,uuid)'::regprocedure) like '%create_service_request(%',
  'need and opportunity conversion inherit the create entitlement gate'
);
select ok(has_function_privilege('authenticated','public.create_service_request(uuid,uuid,uuid,uuid,jsonb,text,text,uuid)','EXECUTE'),'authenticated clients keep create execute');
select * from finish();
rollback;
