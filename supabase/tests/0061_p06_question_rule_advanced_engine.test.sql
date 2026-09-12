begin;
set local search_path=public,extensions;
select plan(28);

select has_function('public','validate_questionnaire_rule_engine',array['uuid'],'version validation RPC exists');
select has_function('public','simulate_questionnaire_rule_engine',array['uuid','jsonb','jsonb'],'pure simulation RPC exists');
select ok((select count(*)=2 and bool_and(p.prosecdef and p.proconfig::text like'%search_path=pg_catalog%')from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname in('validate_questionnaire_rule_engine','simulate_questionnaire_rule_engine')),'engine RPCs are security definer with fixed paths');
select ok(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname in('validate_questionnaire_rule_engine','simulate_questionnaire_rule_engine')and(has_function_privilege('anon',p.oid,'EXECUTE')or has_function_privilege('service_role',p.oid,'EXECUTE'))),'anon and service_role cannot execute engine RPCs');
select ok((select count(*)=2 and bool_and(has_function_privilege('authenticated',p.oid,'EXECUTE'))from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname in('validate_questionnaire_rule_engine','simulate_questionnaire_rule_engine')),'authenticated receives explicit engine execution');

select throws_ok($$select private.assert_advanced_condition_node('{}','{}',0)$$,'22023'::char(5),'RULE_PREDICATE_MALFORMED','malformed predicates fail closed');
select throws_ok($$select private.assert_advanced_condition_node('{"operator":"EQ","question_version_id":"missing","value":true}',array['known'],0)$$,'22023'::char(5),'RULE_REFERENCE_OR_OPERATOR_INVALID','absent references are rejected');
select throws_ok($$select private.assert_advanced_rule_contract('{"operator":"EQ","question_version_id":"a","value":true}','[{"type":"ANOMALY","target":"A"}]','{"a":["b"],"b":["a"]}',array['a','b'])$$,'23514'::char(5),'RULE_DEPENDENCY_CYCLE','dependency cycles are rejected');
select throws_ok($$select private.assert_advanced_condition_node('{"operator":"REGEX","question_version_id":"a","value":"(?=unsafe)"}',array['a'],0)$$,'22023'::char(5),'RULE_REGEX_UNSAFE','unsafe regular expressions are rejected');
select throws_ok($$select private.assert_advanced_rule_contract('{"operator":"EQ","question_version_id":"a","value":true}','[{"type":"SCORE","dimension":"GLOBAL","delta_basis_points":10001}]','{"a":[]}',array['a'])$$,'22023'::char(5),'RULE_SCORE_ACTION_INVALID','individual score changes are bounded');
select throws_ok($$select private.assert_advanced_condition_node('{"group":"AND","conditions":[{"operator":"EQ","question_version_id":"a","value":true},{"operator":"EQ","question_version_id":"a","value":false}]}',array['a'],0)$$,'23514'::char(5),'RULE_DEAD_BRANCH','obviously contradictory AND branches are rejected');

select ok(private.evaluate_advanced_condition('{"group":"AND","conditions":[{"operator":"GT","question_version_id":"age","value":17},{"group":"NOT","conditions":[{"operator":"EMPTY","question_version_id":"country"}]}]}','{"age":18,"country":"MA"}','{}'),'nested AND and NOT groups evaluate deterministically');
select ok(private.evaluate_advanced_condition('{"operator":"IN","question_version_id":"country","value":["MA","CA"]}','{"country":"MA"}','{}'),'IN evaluates standardized values');
select ok(private.evaluate_advanced_condition('{"operator":"CONTAINS","question_version_id":"tags","value":"AUDIT"}','{"tags":["AUDIT","RISK"]}','{}'),'CONTAINS evaluates arrays');
select ok(private.evaluate_advanced_condition('{"operator":"REGEX","question_version_id":"email","value":"^[a-z]+@example\\.ma$"}','{"email":"client@example.ma"}','{}'),'controlled regex evaluates strings');
select ok(private.evaluate_advanced_condition('{"operator":"DATE_AFTER","question_version_id":"date","value":"2026-01-01"}','{"date":"2026-09-12"}','{}'),'dated comparisons use ISO dates');
select ok(private.evaluate_advanced_condition('{"operator":"CHANGED","question_version_id":"status"}','{"status":"NEW"}','{"status":"OLD"}'),'CHANGED compares explicit previous answers');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values
('ac100000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-engine-admin@example.invalid','',now(),'{}','{}',now(),now()),
('ac100000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-engine-outsider@example.invalid','',now(),'{}','{}',now(),now());
insert into public.platform_user_roles(user_id,role_code)values('ac100000-0000-0000-0000-000000000001','MATRICIA_ADMIN');
insert into public.organizations(id,legal_name,display_name,status,created_by)values('ac110000-0000-0000-0000-000000000001','P06 Engine Steward','P06 Engine Steward','ACTIVE','ac100000-0000-0000-0000-000000000001');
insert into public.catalog_libraries(id,code,slug,steward_organization_id,status,created_by)values('ac120000-0000-0000-0000-000000000001','P06_ENGINE','p06-engine','ac110000-0000-0000-0000-000000000001','DRAFT','ac100000-0000-0000-0000-000000000001');
insert into public.catalog_releases(id,library_id,release_key,status,source_bundle_hash,created_by)values('ac130000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000001','P06.ENGINE.V1','DRAFT',repeat('a',64),'ac100000-0000-0000-0000-000000000001');
insert into public.questionnaires(id,library_id,code,status,created_by)values('ac140000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000001','ADVANCED_ENGINE','DRAFT','ac100000-0000-0000-0000-000000000001');
insert into public.questionnaire_versions(id,questionnaire_id,library_id,catalog_release_id,version,status,title_fr,title_ar,description_fr,description_ar,audience,engine_version,policy_version,snapshot_hash,translation_review_status,change_reason,created_by)values('ac141000-0000-0000-0000-000000000001','ac140000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000001','ac130000-0000-0000-0000-000000000001',1,'DRAFT','Moteur avancé','محرك متقدم','Simulation déterministe','محاكاة حتمية','CLIENT','2.0.0','P06-ADV-2026-09-12',repeat('0',64),'PENDING','Validation moteur avancé','ac100000-0000-0000-0000-000000000001');
insert into public.questionnaire_sections(id,questionnaire_version_id,section_key,label_fr,label_ar,sort_order,content_hash)values('ac142000-0000-0000-0000-000000000001','ac141000-0000-0000-0000-000000000001','GENERAL','Général','عام',1,repeat('b',64));
insert into public.question_bank_questions(id,library_id,question_key,scope,created_by)values
('ac150000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000001','AGE','LIBRARY','ac100000-0000-0000-0000-000000000001'),
('ac150000-0000-0000-0000-000000000002','ac120000-0000-0000-0000-000000000001','COUNTRY','LIBRARY','ac100000-0000-0000-0000-000000000001');
insert into public.question_versions(id,question_id,library_id,version,status,label_fr,label_ar,answer_type,data_key,content_hash,change_reason,created_by)values
('ac151000-0000-0000-0000-000000000001','ac150000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000001',1,'APPROVED','Âge','العمر','INTEGER','profile.age',repeat('c',64),'Version de test','ac100000-0000-0000-0000-000000000001'),
('ac151000-0000-0000-0000-000000000002','ac150000-0000-0000-0000-000000000002','ac120000-0000-0000-0000-000000000001',1,'APPROVED','Pays','البلد','SHORT_TEXT','profile.country',repeat('d',64),'Version de test','ac100000-0000-0000-0000-000000000001');
insert into public.questionnaire_version_questions(questionnaire_version_id,library_id,section_id,question_version_id,sort_order)values
('ac141000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000001','ac142000-0000-0000-0000-000000000001','ac151000-0000-0000-0000-000000000001',1),
('ac141000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000001','ac142000-0000-0000-0000-000000000001','ac151000-0000-0000-0000-000000000002',2);
insert into public.question_rules(id,library_id,rule_key,created_by)values
('ac160000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000001','ELIGIBLE_SCORE','ac100000-0000-0000-0000-000000000001'),
('ac160000-0000-0000-0000-000000000002','ac120000-0000-0000-0000-000000000001','COUNTRY_SCORE','ac100000-0000-0000-0000-000000000001');
insert into public.question_rule_versions(id,rule_id,library_id,version,status,condition_ast,actions,dependency_graph,priority,compiled_hash,change_reason,created_by)values
('ac161000-0000-0000-0000-000000000001','ac160000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000001',1,'APPROVED','{"group":"AND","conditions":[{"operator":"GTE","question_version_id":"ac151000-0000-0000-0000-000000000001","value":18},{"operator":"IN","question_version_id":"ac151000-0000-0000-0000-000000000002","value":["MA","CA"]}]}','[{"type":"SCORE","dimension":"GLOBAL","delta_basis_points":7000},{"type":"RECOMMENDATION","target":"ELIGIBLE"}]','{"ac151000-0000-0000-0000-000000000001":["ac151000-0000-0000-0000-000000000002"],"ac151000-0000-0000-0000-000000000002":[]}',10,repeat('e',64),'Règle éligibilité','ac100000-0000-0000-0000-000000000001'),
('ac161000-0000-0000-0000-000000000002','ac160000-0000-0000-0000-000000000002','ac120000-0000-0000-0000-000000000001',1,'APPROVED','{"operator":"NOT_EMPTY","question_version_id":"ac151000-0000-0000-0000-000000000002"}','[{"type":"SCORE","dimension":"GLOBAL","delta_basis_points":7000}]','{"ac151000-0000-0000-0000-000000000002":[]}',20,repeat('f',64),'Règle pays','ac100000-0000-0000-0000-000000000001');
insert into public.questionnaire_version_rules(questionnaire_version_id,library_id,rule_version_id,evaluation_order)values
('ac141000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000001','ac161000-0000-0000-0000-000000000001',10),
('ac141000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000001','ac161000-0000-0000-0000-000000000002',20);

create temporary table p06_advanced_observed(key text primary key,value jsonb);grant select,insert on p06_advanced_observed to authenticated;grant usage on schema extensions to authenticated;
set local role authenticated;select set_config('request.jwt.claims','{"sub":"ac100000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into p06_advanced_observed values('validation',public.validate_questionnaire_rule_engine('ac141000-0000-0000-0000-000000000001'));
insert into p06_advanced_observed values('first',public.simulate_questionnaire_rule_engine('ac141000-0000-0000-0000-000000000001','{"ac151000-0000-0000-0000-000000000001":18,"ac151000-0000-0000-0000-000000000002":"MA"}','{}'));
insert into p06_advanced_observed values('second',public.simulate_questionnaire_rule_engine('ac141000-0000-0000-0000-000000000001','{"ac151000-0000-0000-0000-000000000001":18,"ac151000-0000-0000-0000-000000000002":"MA"}','{}'));
insert into p06_advanced_observed values('canonical',public.simulate_questionnaire_rule_engine('ac141000-0000-0000-0000-000000000001','{"ac151000-0000-0000-0000-000000000001":{"kind":"INTEGER","value":"18"},"ac151000-0000-0000-0000-000000000002":"MA"}','{}'));
reset role;
select ok((select(value->>'valid')::boolean and(value->>'question_count')::integer=2 and(value->>'rule_count')::integer=2 from p06_advanced_observed where key='validation'),'version validation covers its targeted questions and rules');
select is((select value->>'engine_version'from p06_advanced_observed where key='validation'),'2.0.0','validation reports the pinned versioned engine contract');
select is((select(value->>'score_basis_points')::integer from p06_advanced_observed where key='first'),10000,'aggregate score is clamped to 10000 basis points');
select is((select value->'triggered_actions'->0->>'type'from p06_advanced_observed where key='first'),'SCORE','actions preserve deterministic evaluation order');
select matches((select value->>'reproducibility_hash'from p06_advanced_observed where key='first'),'^[0-9a-f]{64}$','simulation returns a reproducibility hash');
select is((select value from p06_advanced_observed where key='first'),(select value from p06_advanced_observed where key='second'),'identical version and inputs reproduce the complete result');
select is((select value from p06_advanced_observed where key='first'),(select value from p06_advanced_observed where key='canonical'),'numeric shorthand and canonical input produce identical score and hash');
select ok((select(value->>'simulation')::boolean from p06_advanced_observed where key='first')and not exists(select 1 from public.questionnaire_sessions where questionnaire_version_id='ac141000-0000-0000-0000-000000000001'),'simulation has no session or statistics side effect');

set local role authenticated;select set_config('request.jwt.claims','{"sub":"ac100000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true);
select throws_ok($$select public.simulate_questionnaire_rule_engine('ac141000-0000-0000-0000-000000000001','{"ffffffff-ffff-ffff-ffff-ffffffffffff":true}','{}')$$,'22023'::char(5),'SIMULATION_UNKNOWN_QUESTION','unknown answer references fail closed');
select throws_ok($$select public.simulate_questionnaire_rule_engine('ac141000-0000-0000-0000-000000000001','[]','{}')$$,'22023'::char(5),'SIMULATION_INPUT_INVALID','malformed simulation input fails closed');
select set_config('request.jwt.claims','{"sub":"ac100000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}',true);
select throws_ok($$select public.validate_questionnaire_rule_engine('ac141000-0000-0000-0000-000000000001')$$,'42501'::char(5),'QUESTIONNAIRE_SCOPE_DENIED','outsider cannot inspect draft rule logic');
reset role;

select * from finish();
rollback;
