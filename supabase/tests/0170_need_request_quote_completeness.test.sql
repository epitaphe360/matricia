begin;
select plan(14);
select has_function('private','parse_need_intake_answers',array['text'],'need answer parser exists');
select has_function('private','service_request_missing_quote_keys',array['uuid','jsonb'],'missing quote keys helper exists');
select has_function('public','get_service_request_quote_questions',array['uuid'],'quote questions reader exists');
select has_function('public','complete_service_request_information',array['uuid','integer','jsonb','text','text','uuid'],'information completion command exists');
select ok(
  not has_function_privilege('authenticated','private.parse_need_intake_answers(text)','EXECUTE')
  and not has_function_privilege('authenticated','private.service_quote_questions(uuid)','EXECUTE')
  and not has_function_privilege('authenticated','private.service_request_missing_quote_keys(uuid,jsonb)','EXECUTE'),
  'private helpers are not callable by clients'
);
select ok(
  not has_function_privilege('anon','public.get_service_request_quote_questions(uuid)','EXECUTE')
  and not has_function_privilege('anon','public.complete_service_request_information(uuid,integer,jsonb,text,text,uuid)','EXECUTE')
  and has_function_privilege('authenticated','public.complete_service_request_information(uuid,integer,jsonb,text,text,uuid)','EXECUTE'),
  'completion is reserved to authenticated users'
);
select is(
  private.parse_need_intake_answers(E'users_count: 12\nhosting: Cloud\nligne libre sans clé\nempty: \n1bad: x'),
  '{"users_count":"12","hosting":"Cloud"}'::jsonb,
  'parser keeps only well-formed business answers'
);
select is(private.parse_need_intake_answers(null), '{}'::jsonb, 'parser tolerates an empty intake');
select ok(
  pg_get_functiondef('public.create_service_request_from_need_intake(uuid,text,jsonb,text,uuid)'::regprocedure) like '%service_request_missing_quote_keys%'
  and pg_get_functiondef('public.create_service_request_from_need_intake(uuid,text,jsonb,text,uuid)'::regprocedure) not like '%''required_fields_complete'', true%',
  'need conversion computes completeness instead of hardcoding it'
);
select ok(
  pg_get_functiondef('public.create_service_request_from_need_intake(uuid,text,jsonb,text,uuid)'::regprocedure) like '%create_service_request(%',
  'need conversion still goes through the entitlement-gated create command'
);
select ok(
  pg_get_functiondef('public.complete_service_request_information(uuid,integer,jsonb,text,text,uuid)'::regprocedure) like '%can_manage_client_request%'
  and pg_get_functiondef('public.complete_service_request_information(uuid,integer,jsonb,text,text,uuid)'::regprocedure) like '%begin_rfq_command%'
  and pg_get_functiondef('public.complete_service_request_information(uuid,integer,jsonb,text,text,uuid)'::regprocedure) like '%row_version%',
  'completion is authorised server-side, idempotent and optimistic-locked'
);
select ok(
  pg_get_functiondef('public.complete_service_request_information(uuid,integer,jsonb,text,text,uuid)'::regprocedure) like '%insert into public.service_request_versions%'
  and pg_get_functiondef('public.complete_service_request_information(uuid,integer,jsonb,text,text,uuid)'::regprocedure) like '%INFORMATION_REQUIRED%'
  and pg_get_functiondef('public.complete_service_request_information(uuid,integer,jsonb,text,text,uuid)'::regprocedure) like '%ServiceRequestInformationCompletedV1%',
  'completion appends a new frozen version before matching and emits an outbox event'
);
select ok(
  pg_get_functiondef('private.client_may_open_new_service_request(uuid)'::regprocedure) like '%trial_ends_at%'
  and pg_get_functiondef('private.client_may_open_new_service_request(uuid)'::regprocedure) like '%TRIAL_EXPIRED%',
  'new-request gate blocks once the 30-day trial end date has passed'
);
select ok(
  not has_function_privilege('authenticated','private.client_may_open_new_service_request(uuid)','EXECUTE'),
  'entitlement helper stays private'
);
select * from finish();
rollback;
