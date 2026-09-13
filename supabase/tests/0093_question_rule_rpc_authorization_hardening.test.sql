begin;
set local search_path=public,extensions;
select plan(24);

select ok(
  (
    select count(*)=2
      and bool_and(proc.prosecdef)
      and bool_and(proc.proconfig::text like '%search_path=pg_catalog%')
    from pg_proc proc
    join pg_namespace namespace on namespace.oid=proc.pronamespace
    where namespace.nspname='public'
      and proc.proname in (
        'validate_questionnaire_rule_engine',
        'simulate_questionnaire_rule_engine'
      )
  ),
  'rule engine RPCs remain SECURITY DEFINER with fixed search paths'
);
select ok(
  (
    select count(*)=3
      and bool_and(proc.prosecdef)
      and bool_and(proc.proconfig::text like '%search_path=pg_catalog%')
    from pg_proc proc
    join pg_namespace namespace on namespace.oid=proc.pronamespace
    where namespace.nspname='private'
      and proc.proname in(
        'can_execute_questionnaire_rule_engine',
        'validate_questionnaire_rule_engine_core',
        'simulate_questionnaire_rule_engine_core'
      )
  ),
  'private authorization and engine cores are SECURITY DEFINER with fixed paths'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'private.can_execute_questionnaire_rule_engine(uuid,uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'private.can_execute_questionnaire_rule_engine(uuid,uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'private.can_execute_questionnaire_rule_engine(uuid,uuid)',
    'EXECUTE'
  ) and not has_function_privilege(
    'authenticated',
    'private.validate_questionnaire_rule_engine_core(uuid)',
    'EXECUTE'
  ) and not has_function_privilege(
    'authenticated',
    'private.simulate_questionnaire_rule_engine_core(uuid,jsonb,jsonb)',
    'EXECUTE'
  ),
  'private authorization and engine cores are not executable by API roles'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.validate_questionnaire_rule_engine(uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'public.validate_questionnaire_rule_engine(uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.simulate_questionnaire_rule_engine(uuid,jsonb,jsonb)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'public.simulate_questionnaire_rule_engine(uuid,jsonb,jsonb)',
    'EXECUTE'
  ),
  'anonymous and service-role impersonation cannot execute rule engine RPCs'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.validate_questionnaire_rule_engine(uuid)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.simulate_questionnaire_rule_engine(uuid,jsonb,jsonb)',
    'EXECUTE'
  ),
  'authenticated receives only the explicitly guarded RPC entry points'
);
select ok(
  position(
    'can_execute_questionnaire_rule_engine'
    in pg_get_functiondef(
      'public.validate_questionnaire_rule_engine(uuid)'::regprocedure
    )
  )>0
  and position(
    'can_execute_questionnaire_rule_engine'
    in pg_get_functiondef(
      'public.simulate_questionnaire_rule_engine(uuid,jsonb,jsonb)'::regprocedure
    )
  )>0
  and position(
    'can_read_questionnaire_version'
    in pg_get_functiondef(
      'public.validate_questionnaire_rule_engine(uuid)'::regprocedure
    )
  )=0,
  'published questionnaire readability is not an engine execution capability'
);
select ok(
  position(
    'private.simulate_questionnaire_rule_engine_core'
    in pg_get_functiondef(
      'public.submit_questionnaire_session(uuid,integer,text,uuid)'::regprocedure
    )
  )>0
  and position(
    'public.simulate_questionnaire_rule_engine'
    in pg_get_functiondef(
      'public.submit_questionnaire_session(uuid,integer,text,uuid)'::regprocedure
    )
  )=0,
  'session submission uses only the unexposed engine core after its own guards'
);

insert into auth.users(
  id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
('a9300000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-rpc-admin@example.invalid','',now(),'{}','{}',now(),now()),
('a9300000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-rpc-client-a@example.invalid','',now(),'{}','{}',now(),now()),
('a9300000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-rpc-client-b@example.invalid','',now(),'{}','{}',now(),now()),
('a9300000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-rpc-revoked@example.invalid','',now(),'{}','{}',now(),now());

insert into public.organizations(id,legal_name,display_name,status,created_by) values
('b9300000-0000-0000-0000-000000000001','P06 RPC Tenant A','P06 RPC A','ACTIVE','a9300000-0000-0000-0000-000000000001'),
('b9300000-0000-0000-0000-000000000002','P06 RPC Tenant B','P06 RPC B','ACTIVE','a9300000-0000-0000-0000-000000000003');
insert into public.organization_memberships(
  id,organization_id,user_id,status,activated_at
) values
('c9300000-0000-0000-0000-000000000001','b9300000-0000-0000-0000-000000000001','a9300000-0000-0000-0000-000000000002','ACTIVE',now()),
('c9300000-0000-0000-0000-000000000002','b9300000-0000-0000-0000-000000000002','a9300000-0000-0000-0000-000000000003','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code) values
('c9300000-0000-0000-0000-000000000001','CLIENT_MEMBER'),
('c9300000-0000-0000-0000-000000000002','CLIENT_MEMBER');
insert into public.platform_user_roles(user_id,role_code,revoked_at) values
('a9300000-0000-0000-0000-000000000001','MATRICIA_ADMIN',null),
('a9300000-0000-0000-0000-000000000004','MATRICIA_ADMIN',now());

insert into public.catalog_libraries(
  id,code,slug,steward_organization_id,status,created_by
) values(
  'd9300000-0000-0000-0000-000000000001',
  'P06_RPC_AUTH',
  'p06-rpc-auth',
  'b9300000-0000-0000-0000-000000000001',
  'PUBLISHED',
  'a9300000-0000-0000-0000-000000000001'
);
insert into public.catalog_releases(
  id,library_id,release_key,status,source_bundle_hash,snapshot_hash,created_by,
  audience,effective_from,published_at
) values(
  'e9300000-0000-0000-0000-000000000001',
  'd9300000-0000-0000-0000-000000000001',
  'P06.RPC.AUTH.V1',
  'PUBLISHED',
  repeat('a',64),
  repeat('b',64),
  'a9300000-0000-0000-0000-000000000001',
  '{"kind":"PUBLIC"}',
  now()-interval '1 day',
  now()-interval '1 day'
);
update public.catalog_libraries
set current_release_id='e9300000-0000-0000-0000-000000000001'
where id='d9300000-0000-0000-0000-000000000001';

insert into public.questionnaires(id,library_id,code,status,created_by) values(
  'f9300000-0000-0000-0000-000000000001',
  'd9300000-0000-0000-0000-000000000001',
  'RPC_AUTH_ENGINE',
  'DRAFT',
  'a9300000-0000-0000-0000-000000000001'
);
insert into public.questionnaire_versions(
  id,questionnaire_id,library_id,catalog_release_id,version,status,
  title_fr,title_ar,description_fr,description_ar,audience,engine_version,
  policy_version,snapshot_hash,translation_review_status,
  translation_reviewer_user_id,translation_reviewed_at,
  translation_review_proof_hash,translation_review_version,change_reason,created_by
) values
(
  '09310000-0000-0000-0000-000000000001',
  'f9300000-0000-0000-0000-000000000001',
  'd9300000-0000-0000-0000-000000000001',
  'e9300000-0000-0000-0000-000000000001',
  1,'DRAFT','Moteur publié','محرك منشور','Accès client lisible','وصول عميل للقراءة',
  'CLIENT','2.0.0','P06-RPC-AUTH-1',repeat('0',64),'APPROVED',
  'a9300000-0000-0000-0000-000000000001',now(),repeat('c',64),1,
  'Durcissement RPC','a9300000-0000-0000-0000-000000000001'
),
(
  '09310000-0000-0000-0000-000000000002',
  'f9300000-0000-0000-0000-000000000001',
  'd9300000-0000-0000-0000-000000000001',
  'e9300000-0000-0000-0000-000000000001',
  2,'DRAFT','Moteur invalide','محرك غير صالح','Erreur contrôlée','خطأ مضبوط',
  'INTERNAL','2.0.0','P06-RPC-AUTH-2',repeat('0',64),'PENDING',
  null,null,null,1,'Test allowlist','a9300000-0000-0000-0000-000000000001'
);
insert into public.questionnaire_sections(
  id,questionnaire_version_id,section_key,label_fr,label_ar,sort_order,content_hash
) values(
  '09360000-0000-0000-0000-000000000001',
  '09310000-0000-0000-0000-000000000001',
  'GENERAL','Général','عام',1,repeat('e',64)
);
insert into public.question_bank_questions(
  id,library_id,question_key,scope,status,created_by
) values(
  '09370000-0000-0000-0000-000000000001',
  'd9300000-0000-0000-0000-000000000001',
  'RPC_AUTH_CONFIRMATION','LIBRARY','DRAFT',
  'a9300000-0000-0000-0000-000000000001'
);
insert into public.question_versions(
  id,question_id,library_id,version,status,label_fr,label_ar,answer_type,
  data_key,required_by_default,sensitivity,translation_review_status,
  translation_reviewer_user_id,translation_reviewed_at,
  translation_review_proof_hash,translation_review_version,weight,
  maximum_score,content_hash,change_reason,created_by,published_at
) values(
  '09380000-0000-0000-0000-000000000001',
  '09370000-0000-0000-0000-000000000001',
  'd9300000-0000-0000-0000-000000000001',
  1,'PUBLISHED','Confirmez-vous ?','هل تؤكد؟','YES_NO',
  'rpc.confirmation',false,'BUSINESS','APPROVED',
  'a9300000-0000-0000-0000-000000000001',now(),repeat('f',64),1,1,1,
  repeat('1',64),'Question minimale publiée',
  'a9300000-0000-0000-0000-000000000001',now()
);
update public.question_bank_questions
set status='PUBLISHED',
    current_published_version_id='09380000-0000-0000-0000-000000000001'
where id='09370000-0000-0000-0000-000000000001';
insert into public.questionnaire_version_questions(
  questionnaire_version_id,library_id,section_id,question_version_id,sort_order
) values(
  '09310000-0000-0000-0000-000000000001',
  'd9300000-0000-0000-0000-000000000001',
  '09360000-0000-0000-0000-000000000001',
  '09380000-0000-0000-0000-000000000001',1
);
update public.questionnaire_versions
set snapshot_hash=private.compute_questionnaire_snapshot_hash(
      id,
      jsonb_build_object(
        'questionnaire_id',questionnaire_id,
        'library_id',library_id,
        'release_id',catalog_release_id,
        'version',version,
        'title_fr',title_fr,
        'title_ar',title_ar,
        'description_fr',description_fr,
        'description_ar',description_ar,
        'audience',audience,
        'engine_version',engine_version,
        'policy_version',policy_version
      )
    ),
    status='PUBLISHED',
    published_at=now(),
    row_version=row_version+1
where id='09310000-0000-0000-0000-000000000001';
update public.questionnaires
set status='PUBLISHED',
    current_published_version_id='09310000-0000-0000-0000-000000000001',
    row_version=row_version+1
where id='f9300000-0000-0000-0000-000000000001';

insert into public.question_rules(id,library_id,rule_key,status,created_by) values(
  '09320000-0000-0000-0000-000000000001',
  'd9300000-0000-0000-0000-000000000001',
  'MALFORMED_FOR_ALLOWLIST',
  'DRAFT',
  'a9300000-0000-0000-0000-000000000001'
);
insert into public.question_rule_versions(
  id,rule_id,library_id,version,status,condition_ast,actions,dependency_graph,
  priority,compiled_hash,change_reason,created_by
) values(
  '09330000-0000-0000-0000-000000000001',
  '09320000-0000-0000-0000-000000000001',
  'd9300000-0000-0000-0000-000000000001',
  1,'APPROVED','{}','[{"type":"SCORE","dimension":"GLOBAL","delta_basis_points":1}]',
  '{}',10,repeat('d',64),'Test erreur contrôlée',
  'a9300000-0000-0000-0000-000000000001'
);
insert into public.questionnaire_version_rules(
  questionnaire_version_id,library_id,rule_version_id,evaluation_order
) values(
  '09310000-0000-0000-0000-000000000002',
  'd9300000-0000-0000-0000-000000000001',
  '09330000-0000-0000-0000-000000000001',
  10
);
set constraints all immediate;
set constraints all deferred;

insert into public.questionnaire_sessions(
  id,organization_id,actor_user_id,library_id,catalog_release_id,
  questionnaire_version_id,audience,locale,status,due_at
) values(
  '09340000-0000-0000-0000-000000000001',
  'b9300000-0000-0000-0000-000000000001',
  'a9300000-0000-0000-0000-000000000002',
  'd9300000-0000-0000-0000-000000000001',
  'e9300000-0000-0000-0000-000000000001',
  '09310000-0000-0000-0000-000000000001',
  'CLIENT','fr-MA','IN_PROGRESS',now()+interval '1 day'
);
select private.create_questionnaire_session_snapshot(
  '09340000-0000-0000-0000-000000000001'
);
create temporary table p06_client_submit_observed(
  key text primary key,
  value jsonb
);
grant select,insert on p06_client_submit_observed to authenticated;
grant usage on schema extensions to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"a9300000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}',
  true
);
select ok(
  exists(
    select 1 from public.questionnaire_versions
    where id='09310000-0000-0000-0000-000000000001'
  ),
  'same-tenant client can read the published questionnaire'
);
select throws_ok(
  $$select public.validate_questionnaire_rule_engine('09310000-0000-0000-0000-000000000001')$$,
  '42501'::char(5),'QUESTIONNAIRE_SCOPE_DENIED',
  'same-tenant client cannot inspect published rule internals'
);
select throws_ok(
  $$select public.simulate_questionnaire_rule_engine('09310000-0000-0000-0000-000000000001','{}','{}')$$,
  '42501'::char(5),'QUESTIONNAIRE_SCOPE_DENIED',
  'same-tenant client cannot execute published rule simulation'
);
insert into p06_client_submit_observed values(
  'submit',
  public.submit_questionnaire_session(
    '09340000-0000-0000-0000-000000000001',
    1,
    'p06-rpc-submit-0001',
    '09350000-0000-0000-0000-000000000001'
  )
);
select is(
  (select value->>'outcome' from p06_client_submit_observed where key='submit'),
  'QUESTIONNAIRE_SESSION_SUBMITTED',
  'Client submission can execute engine 2.x through the guarded internal path'
);
select is(
  (select status from public.questionnaire_sessions where id='09340000-0000-0000-0000-000000000001'),
  'SUBMITTED',
  'internal engine evaluation preserves the submitted session transition'
);
reset role;
select ok(
  exists(
    select 1 from public.questionnaire_session_evaluations
    where session_id='09340000-0000-0000-0000-000000000001'
  ) and exists(
    select 1 from public.audit_events
    where action='questionnaire.session.submitted'
      and resource_id='09340000-0000-0000-0000-000000000001'
  ) and exists(
    select 1 from public.event_outbox
    where event_type='QuestionnaireSessionSubmittedV1'
      and aggregate_id='09340000-0000-0000-0000-000000000001'
  ),
  'Client internal evaluation still writes immutable result, audit and Outbox proof'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"a9300000-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2"}',
  true
);
select ok(
  exists(
    select 1 from public.questionnaire_versions
    where id='09310000-0000-0000-0000-000000000001'
  ),
  'cross-tenant client can read an explicitly public questionnaire'
);
select throws_ok(
  $$select public.validate_questionnaire_rule_engine('09310000-0000-0000-0000-000000000001')$$,
  '42501'::char(5),'QUESTIONNAIRE_SCOPE_DENIED',
  'cross-tenant client cannot inspect rule internals'
);
select throws_ok(
  $$select public.simulate_questionnaire_rule_engine('09310000-0000-0000-0000-000000000001','{}','{}')$$,
  '42501'::char(5),'QUESTIONNAIRE_SCOPE_DENIED',
  'cross-tenant client cannot execute rule simulation'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"a9300000-0000-0000-0000-000000000004","role":"authenticated","aal":"aal2"}',
  true
);
select throws_ok(
  $$select public.validate_questionnaire_rule_engine('09310000-0000-0000-0000-000000000001')$$,
  '42501'::char(5),'QUESTIONNAIRE_SCOPE_DENIED',
  'revoked platform role cannot validate rules'
);
select throws_ok(
  $$select public.simulate_questionnaire_rule_engine('09310000-0000-0000-0000-000000000001','{}','{}')$$,
  '42501'::char(5),'QUESTIONNAIRE_SCOPE_DENIED',
  'revoked platform role cannot simulate rules'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"a9300000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal1"}',
  true
);
select throws_ok(
  $$select public.validate_questionnaire_rule_engine('09310000-0000-0000-0000-000000000001')$$,
  '42501'::char(5),'QUESTIONNAIRE_SCOPE_DENIED',
  'catalogue platform role still requires the existing aal2 control'
);

create temporary table p06_rpc_observed(key text primary key,value jsonb);
grant select,insert on p06_rpc_observed to authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"a9300000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',
  true
);
insert into p06_rpc_observed values(
  'validation',
  public.validate_questionnaire_rule_engine(
    '09310000-0000-0000-0000-000000000001'
  )
),(
  'simulation',
  public.simulate_questionnaire_rule_engine(
    '09310000-0000-0000-0000-000000000001','{}','{}'
  )
),(
  'invalid',
  public.validate_questionnaire_rule_engine(
    '09310000-0000-0000-0000-000000000002'
  )
);
select ok(
  (select (value->>'valid')::boolean from p06_rpc_observed where key='validation'),
  'active catalogue-authorized platform role can validate rules'
);
select ok(
  (
    select (value->>'simulation')::boolean
      and (value->>'score_basis_points')::integer=0
      and value->>'reproducibility_hash' ~ '^[0-9a-f]{64}$'
    from p06_rpc_observed
    where key='simulation'
  ),
  'active catalogue-authorized platform role can run deterministic simulation'
);
select is(
  (select value->'errors'->0->>'code' from p06_rpc_observed where key='invalid'),
  'RULE_PREDICATE_MALFORMED',
  'known validation failures expose only their stable error code'
);
select ok(
  (
    select bool_and(error_entry->>'code' ~ '^[A-Z][A-Z0-9_]{2,63}$')
    from p06_rpc_observed observed
    cross join lateral jsonb_array_elements(observed.value->'errors') error_entry
    where observed.key='invalid'
  ),
  'validation response error details are restricted to the public allowlist format'
);
select throws_ok(
  $$select public.simulate_questionnaire_rule_engine('09310000-0000-0000-0000-000000000002','{}','{}')$$,
  '23514'::char(5),'QUESTIONNAIRE_RULES_INVALID',
  'simulation reports invalid rule sets with a stable allowlisted error'
);
reset role;

select * from finish();
rollback;
