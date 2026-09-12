begin;
set local search_path=public,extensions;
select plan(46);

select has_table('public','questionnaire_session_snapshots','immutable session snapshots exist');
select has_table('public','questionnaire_session_evaluations','final deterministic evaluations exist');
select has_table('public','questionnaire_session_state_events','session lifecycle evidence exists');
select has_column('public','questionnaire_sessions','last_resumed_at','resume timestamp is persisted');
select has_column('public','questionnaire_sessions','abandoned_at','abandon timestamp is persisted');
select has_column('public','questionnaire_sessions','expired_at','expiry timestamp is persisted');
select has_function('public','resume_questionnaire_session',array['uuid','text','uuid'],'resume RPC exists');
select has_function('public','terminate_questionnaire_session',array['uuid','text','text','integer','text','uuid'],'terminal transition RPC exists');
select ok((select bool_and(c.relrowsecurity)from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'and c.relname in('questionnaire_session_snapshots','questionnaire_session_evaluations','questionnaire_session_state_events')),'RLS is enabled on every new session table');
select ok(not has_table_privilege('authenticated','public.questionnaire_session_snapshots','INSERT')and not has_table_privilege('authenticated','public.questionnaire_session_evaluations','INSERT')and not has_table_privilege('authenticated','public.questionnaire_session_state_events','INSERT'),'authenticated cannot forge snapshots evaluations or state evidence');
select ok(not has_function_privilege('anon','public.resume_questionnaire_session(uuid,text,uuid)','EXECUTE')and not has_function_privilege('service_role','public.resume_questionnaire_session(uuid,text,uuid)','EXECUTE'),'resume excludes anonymous and service-role impersonation');
select ok(has_function_privilege('authenticated','public.resume_questionnaire_session(uuid,text,uuid)','EXECUTE')and has_function_privilege('authenticated','public.terminate_questionnaire_session(uuid,text,text,integer,text,uuid)','EXECUTE'),'authenticated receives only guarded session commands');
select ok((select count(*)=4 and bool_and(p.prosecdef and p.proconfig::text like'%search_path=pg_catalog%')from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname in('start_questionnaire_session','resume_questionnaire_session','terminate_questionnaire_session','submit_questionnaire_session')),'all session RPCs are SECURITY DEFINER with fixed search paths');
select has_index('public','questionnaire_session_snapshots','questionnaire_session_snapshots_session_id_key','one immutable snapshot exists per session');
select has_index('public','questionnaire_session_evaluations','questionnaire_session_evaluations_session_id_key','one final evaluation exists per session');
select has_index('public','questionnaire_sessions','questionnaire_sessions_due_idx','open due sessions are indexed');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values
('d0600000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-session-owner@example.invalid','',now(),'{}','{}',now(),now()),
('d0600000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-session-outsider@example.invalid','',now(),'{}','{}',now(),now()),
('d0600000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-session-admin@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)values
('d0610000-0000-0000-0000-000000000001','P06 Session Tenant A','P06 Session A','ACTIVE','d0600000-0000-0000-0000-000000000001'),
('d0610000-0000-0000-0000-000000000002','P06 Session Tenant B','P06 Session B','ACTIVE','d0600000-0000-0000-0000-000000000002');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at)values
('d0620000-0000-0000-0000-000000000001','d0610000-0000-0000-0000-000000000001','d0600000-0000-0000-0000-000000000001','ACTIVE',now()),
('d0620000-0000-0000-0000-000000000002','d0610000-0000-0000-0000-000000000002','d0600000-0000-0000-0000-000000000002','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code)values
('d0620000-0000-0000-0000-000000000001','CLIENT_MEMBER'),
('d0620000-0000-0000-0000-000000000002','CLIENT_MEMBER');
insert into public.platform_user_roles(user_id,role_code)values('d0600000-0000-0000-0000-000000000003','MATRICIA_ADMIN');
insert into public.catalog_libraries(id,code,slug,steward_organization_id,status,created_by)values('d0630000-0000-0000-0000-000000000001','P06_SESSIONS','p06-sessions','d0610000-0000-0000-0000-000000000001','PUBLISHED','d0600000-0000-0000-0000-000000000003');
insert into public.catalog_releases(id,library_id,release_key,status,source_bundle_hash,snapshot_hash,created_by,audience,effective_from,published_at)values('d0640000-0000-0000-0000-000000000001','d0630000-0000-0000-0000-000000000001','P06.SESSIONS.V1','PUBLISHED',repeat('a',64),repeat('b',64),'d0600000-0000-0000-0000-000000000003','{"kind":"PUBLIC"}',now()-interval'1 day',now()-interval'1 day');
update public.catalog_libraries set current_release_id='d0640000-0000-0000-0000-000000000001'where id='d0630000-0000-0000-0000-000000000001';
insert into public.questionnaires(id,library_id,code,status,created_by)values('d0650000-0000-0000-0000-000000000001','d0630000-0000-0000-0000-000000000001','SESSION_ENGINE','DRAFT','d0600000-0000-0000-0000-000000000003');
insert into public.questionnaire_versions(id,questionnaire_id,library_id,catalog_release_id,version,status,title_fr,title_ar,description_fr,description_ar,audience,engine_version,policy_version,snapshot_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,change_reason,created_by)values('d0660000-0000-0000-0000-000000000001','d0650000-0000-0000-0000-000000000001','d0630000-0000-0000-0000-000000000001','d0640000-0000-0000-0000-000000000001',1,'DRAFT','Session reproductible','جلسة قابلة للتكرار','Validation finale versionnée','تحقق نهائي بإصدار','CLIENT','2.0.0','P06-SESSIONS-1',repeat('0',64),'APPROVED','d0600000-0000-0000-0000-000000000003',now(),repeat('c',64),1,'Sessions versionnées','d0600000-0000-0000-0000-000000000003');
insert into public.questionnaire_sections(id,questionnaire_version_id,section_key,label_fr,label_ar,sort_order,content_hash)values('d0670000-0000-0000-0000-000000000001','d0660000-0000-0000-0000-000000000001','GENERAL','Général','عام',1,repeat('d',64));
insert into public.question_bank_questions(id,library_id,question_key,scope,status,created_by)values
('d0680000-0000-0000-0000-000000000001','d0630000-0000-0000-0000-000000000001','HAS_POLICY','LIBRARY','DRAFT','d0600000-0000-0000-0000-000000000003'),
('d0680000-0000-0000-0000-000000000002','d0630000-0000-0000-0000-000000000001','POLICY_DETAIL','LIBRARY','DRAFT','d0600000-0000-0000-0000-000000000003');
insert into public.question_versions(id,question_id,library_id,version,status,label_fr,label_ar,answer_type,data_key,required_by_default,sensitivity,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,weight,maximum_score,content_hash,change_reason,created_by,published_at)values
('d0690000-0000-0000-0000-000000000001','d0680000-0000-0000-0000-000000000001','d0630000-0000-0000-0000-000000000001',1,'PUBLISHED','Avez-vous une politique ?','هل لديكم سياسة؟','YES_NO','session.has_policy',true,'BUSINESS','APPROVED','d0600000-0000-0000-0000-000000000003',now(),repeat('e',64),1,1,1,repeat('1',64),'Question session','d0600000-0000-0000-0000-000000000003',now()),
('d0690000-0000-0000-0000-000000000002','d0680000-0000-0000-0000-000000000002','d0630000-0000-0000-0000-000000000001',1,'PUBLISHED','Décrivez la politique','صف السياسة','SHORT_TEXT','session.policy_detail',true,'CONFIDENTIAL','APPROVED','d0600000-0000-0000-0000-000000000003',now(),repeat('f',64),1,1,1,repeat('2',64),'Question session','d0600000-0000-0000-0000-000000000003',now());
update public.question_bank_questions set status='PUBLISHED',current_published_version_id=case when question_key='HAS_POLICY'then'd0690000-0000-0000-0000-000000000001'::uuid else'd0690000-0000-0000-0000-000000000002'::uuid end where library_id='d0630000-0000-0000-0000-000000000001';
insert into public.questionnaire_version_questions(questionnaire_version_id,library_id,section_id,question_version_id,sort_order)values
('d0660000-0000-0000-0000-000000000001','d0630000-0000-0000-0000-000000000001','d0670000-0000-0000-0000-000000000001','d0690000-0000-0000-0000-000000000001',1),
('d0660000-0000-0000-0000-000000000001','d0630000-0000-0000-0000-000000000001','d0670000-0000-0000-0000-000000000001','d0690000-0000-0000-0000-000000000002',2);
insert into public.question_rules(id,library_id,rule_key,status,created_by)values
('d06a0000-0000-0000-0000-000000000001','d0630000-0000-0000-0000-000000000001','HIDE_DETAIL','DRAFT','d0600000-0000-0000-0000-000000000003'),
('d06a0000-0000-0000-0000-000000000002','d0630000-0000-0000-0000-000000000001','POLICY_SCORE','DRAFT','d0600000-0000-0000-0000-000000000003');
insert into public.question_rule_versions(id,rule_id,library_id,version,status,condition_ast,actions,dependency_graph,priority,compiled_hash,change_reason,created_by,published_at)values
('d06b0000-0000-0000-0000-000000000001','d06a0000-0000-0000-0000-000000000001','d0630000-0000-0000-0000-000000000001',1,'PUBLISHED','{"operator":"EQ","question_version_id":"d0690000-0000-0000-0000-000000000001","value":false}','[{"type":"HIDE","target":"d0690000-0000-0000-0000-000000000002"}]','{"d0690000-0000-0000-0000-000000000001":[]}',10,repeat('3',64),'Masquage conditionnel','d0600000-0000-0000-0000-000000000003',now()),
('d06b0000-0000-0000-0000-000000000002','d06a0000-0000-0000-0000-000000000002','d0630000-0000-0000-0000-000000000001',1,'PUBLISHED','{"operator":"EQ","question_version_id":"d0690000-0000-0000-0000-000000000001","value":true}','[{"type":"SCORE","dimension":"GLOBAL","delta_basis_points":8000}]','{"d0690000-0000-0000-0000-000000000001":[]}',20,repeat('4',64),'Scoring versionné','d0600000-0000-0000-0000-000000000003',now());
update public.question_rules set status='PUBLISHED',current_published_version_id=case when rule_key='HIDE_DETAIL'then'd06b0000-0000-0000-0000-000000000001'::uuid else'd06b0000-0000-0000-0000-000000000002'::uuid end where library_id='d0630000-0000-0000-0000-000000000001';
insert into public.questionnaire_version_rules(questionnaire_version_id,library_id,rule_version_id,evaluation_order)values
('d0660000-0000-0000-0000-000000000001','d0630000-0000-0000-0000-000000000001','d06b0000-0000-0000-0000-000000000001',10),
('d0660000-0000-0000-0000-000000000001','d0630000-0000-0000-0000-000000000001','d06b0000-0000-0000-0000-000000000002',20);
update public.questionnaire_versions set snapshot_hash=private.compute_questionnaire_snapshot_hash(id,jsonb_build_object('questionnaire_id',questionnaire_id,'library_id',library_id,'release_id',catalog_release_id,'version',version,'title_fr',title_fr,'title_ar',title_ar,'description_fr',description_fr,'description_ar',description_ar,'audience',audience,'engine_version',engine_version,'policy_version',policy_version)),status='PUBLISHED',published_at=now(),row_version=row_version+1 where id='d0660000-0000-0000-0000-000000000001';
update public.questionnaires set status='PUBLISHED',current_published_version_id='d0660000-0000-0000-0000-000000000001',row_version=row_version+1 where id='d0650000-0000-0000-0000-000000000001';
set constraints all immediate;set constraints all deferred;

create temporary table p06_session_observed(k text primary key,v jsonb);grant select,insert on p06_session_observed to authenticated;
create temporary table p06_session_errors(k text primary key,s text,m text);grant select,insert on p06_session_errors to authenticated;
set local role authenticated;select set_config('request.jwt.claims','{"sub":"d0600000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal1"}',true);
insert into p06_session_observed values('start',public.start_questionnaire_session('d0610000-0000-0000-0000-000000000001','d0660000-0000-0000-0000-000000000001','fr-MA','2099-01-01T00:00:00Z','p06-session-start-0001','d06c0000-0000-0000-0000-000000000001'));
insert into p06_session_observed values('start-retry',public.start_questionnaire_session('d0610000-0000-0000-0000-000000000001','d0660000-0000-0000-0000-000000000001','fr-MA','2099-01-01T00:00:00Z','p06-session-start-0001','d06c0000-0000-0000-0000-000000000001'));
insert into p06_session_observed values('save',public.autosave_questionnaire_answers((select(v->>'session_id')::uuid from p06_session_observed where k='start'),1,'[{"question_version_id":"d0690000-0000-0000-0000-000000000001","value":false,"expected_answer_row_version":0}]','p06-session-save-0001','d06c0000-0000-0000-0000-000000000002'));
insert into p06_session_observed values('resume',public.resume_questionnaire_session((select(v->>'session_id')::uuid from p06_session_observed where k='start'),'p06-session-resume-0001','d06c0000-0000-0000-0000-000000000003'));
insert into p06_session_observed values('resume-retry',public.resume_questionnaire_session((select(v->>'session_id')::uuid from p06_session_observed where k='start'),'p06-session-resume-0001','d06c0000-0000-0000-0000-000000000003'));
insert into p06_session_observed values('submit',public.submit_questionnaire_session((select(v->>'session_id')::uuid from p06_session_observed where k='start'),2,'p06-session-submit-0001','d06c0000-0000-0000-0000-000000000004'));
insert into p06_session_observed values('submit-retry',public.submit_questionnaire_session((select(v->>'session_id')::uuid from p06_session_observed where k='start'),2,'p06-session-submit-0001','d06c0000-0000-0000-0000-000000000004'));
insert into p06_session_observed values('abandon-start',public.start_questionnaire_session('d0610000-0000-0000-0000-000000000001','d0660000-0000-0000-0000-000000000001','ar-MA','2099-01-01T00:00:00Z','p06-session-start-0002','d06c0000-0000-0000-0000-000000000005'));
insert into p06_session_observed values('abandon',public.terminate_questionnaire_session((select(v->>'session_id')::uuid from p06_session_observed where k='abandon-start'),'ABANDON','USER_CANCELLED',1,'p06-session-abandon-01','d06c0000-0000-0000-0000-000000000006'));
insert into p06_session_observed values('abandon-retry',public.terminate_questionnaire_session((select(v->>'session_id')::uuid from p06_session_observed where k='abandon-start'),'ABANDON','USER_CANCELLED',1,'p06-session-abandon-01','d06c0000-0000-0000-0000-000000000006'));
do $x$begin perform public.resume_questionnaire_session((select(v->>'session_id')::uuid from p06_session_observed where k='abandon-start'),'p06-session-resume-dead','d06c0000-0000-0000-0000-000000000007');exception when others then insert into p06_session_errors values('resume-terminal',sqlstate,sqlerrm);end$x$;
reset role;

insert into public.questionnaire_sessions(id,organization_id,actor_user_id,library_id,catalog_release_id,questionnaire_version_id,audience,locale,status,started_at,due_at)values('d06d0000-0000-0000-0000-000000000001','d0610000-0000-0000-0000-000000000001','d0600000-0000-0000-0000-000000000001','d0630000-0000-0000-0000-000000000001','d0640000-0000-0000-0000-000000000001','d0660000-0000-0000-0000-000000000001','CLIENT','fr-MA','DRAFT',now()-interval'2 days',now()-interval'1 day');
select private.create_questionnaire_session_snapshot('d06d0000-0000-0000-0000-000000000001');
set local role authenticated;select set_config('request.jwt.claims','{"sub":"d0600000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal1"}',true);
insert into p06_session_observed values('expire',public.terminate_questionnaire_session('d06d0000-0000-0000-0000-000000000001','EXPIRE','DEADLINE_REACHED',1,'p06-session-expire-01','d06c0000-0000-0000-0000-000000000008'));
reset role;

select is((select v from p06_session_observed where k='start'),(select v from p06_session_observed where k='start-retry'),'start replay is idempotent');
select matches((select v->>'session_snapshot_hash'from p06_session_observed where k='start'),'^[0-9a-f]{64}$','start returns immutable snapshot hash');
select is((select count(*)from public.questionnaire_session_snapshots where session_id=(select(v->>'session_id')::uuid from p06_session_observed where k='start')),1::bigint,'exactly one snapshot is materialized');
select ok((select jsonb_array_length(questions_manifest)=2 and jsonb_array_length(rules_manifest)=2 from public.questionnaire_session_snapshots where session_id=(select(v->>'session_id')::uuid from p06_session_observed where k='start')),'snapshot pins exact questions and rules');
select is((select v->'progress'->>'progress_basis_points'from p06_session_observed where k='resume'),'5000','resume reports progressive completion');
select is((select v->'answers'->'d0690000-0000-0000-0000-000000000001'from p06_session_observed where k='resume'),'false'::jsonb,'resume restores current canonical answers');
select is((select v from p06_session_observed where k='resume'),(select v from p06_session_observed where k='resume-retry'),'resume replay is idempotent');
select ok(not exists(select 1 from public.event_outbox where event_type='QuestionnaireSessionResumedV1'and payload?'answers'),'resume Outbox never contains answer values');
select is((select v->>'outcome'from p06_session_observed where k='submit'),'QUESTIONNAIRE_SESSION_SUBMITTED','hidden required question does not block valid conditional submission');
select is((select v from p06_session_observed where k='submit'),(select v from p06_session_observed where k='submit-retry'),'final validation and evaluation replay idempotently');
select matches((select v->>'reproducibility_hash'from p06_session_observed where k='submit'),'^[0-9a-f]{64}$','final evaluation has reproducibility hash');
select is((select count(*)from public.questionnaire_session_evaluations where session_id=(select(v->>'session_id')::uuid from p06_session_observed where k='start')),1::bigint,'submission writes one immutable evaluation');
select is((select score_basis_points from public.questionnaire_session_evaluations where session_id=(select(v->>'session_id')::uuid from p06_session_observed where k='start')),0,'advanced condition evaluation persists bounded basis points');
select ok((select result_payload->>'mode'='FINAL'and engine_version='2.0.0'and policy_version='P06-SESSIONS-1'from public.questionnaire_session_evaluations where session_id=(select(v->>'session_id')::uuid from p06_session_observed where k='start')),'final result pins engine and policy versions');
select is((select v from p06_session_observed where k='abandon'),(select v from p06_session_observed where k='abandon-retry'),'abandon replay is idempotent');
select is((select status from public.questionnaire_sessions where id=(select(v->>'session_id')::uuid from p06_session_observed where k='abandon-start')),'ABANDONED','abandon reaches explicit terminal state');
select is((select s||':'||m from p06_session_errors where k='resume-terminal'),'55000:SESSION_NOT_RESUMABLE','abandoned session cannot resume');
select is((select status from public.questionnaire_sessions where id='d06d0000-0000-0000-0000-000000000001'),'EXPIRED','due session reaches explicit expired state');
select ok((select abandoned_at is not null and expired_at is null from public.questionnaire_sessions where id=(select(v->>'session_id')::uuid from p06_session_observed where k='abandon-start'))and(select expired_at is not null and abandoned_at is null from public.questionnaire_sessions where id='d06d0000-0000-0000-0000-000000000001'),'terminal timestamps are mutually exclusive');
select is((select count(*)from public.questionnaire_session_state_events where session_id=(select(v->>'session_id')::uuid from p06_session_observed where k='start')and to_status='SUBMITTED'),1::bigint,'submission state transition is recorded once');
select ok((select count(*)from public.audit_events where action in('questionnaire.session.started','questionnaire.session.resumed','questionnaire.session.submitted','questionnaire.session.abandoned','questionnaire.session.expired')and organization_id='d0610000-0000-0000-0000-000000000001')>=5,'all lifecycle mutations emit tenant audit evidence');
select ok((select count(*)from public.event_outbox where aggregate_type='questionnaire_session'and organization_id='d0610000-0000-0000-0000-000000000001'and event_type in('QuestionnaireSessionStartedV1','QuestionnaireSessionResumedV1','QuestionnaireSessionSubmittedV1','QuestionnaireSessionAbandonedV1','QuestionnaireSessionExpiredV1'))>=5,'all lifecycle mutations emit Outbox events');
select throws_ok(format('update public.questionnaire_session_snapshots set engine_version=%L where session_id=%L','9.9.9',(select v->>'session_id'from p06_session_observed where k='start')),'55000','IMMUTABLE_QUESTIONNAIRE_HISTORY','session snapshots are immutable');
select throws_ok(format('update public.questionnaire_session_evaluations set score_basis_points=1 where session_id=%L',(select v->>'session_id'from p06_session_observed where k='start')),'55000','IMMUTABLE_QUESTIONNAIRE_HISTORY','final evaluations are immutable');
select throws_ok(format('update public.questionnaire_session_state_events set reason_code=%L where session_id=%L','ALTERED',(select v->>'session_id'from p06_session_observed where k='start')),'55000','IMMUTABLE_QUESTIONNAIRE_HISTORY','lifecycle evidence is immutable');
select throws_ok(format('update public.questionnaire_sessions set locale=%L where id=%L','fr-MA',(select v->>'session_id'from p06_session_observed where k='abandon-start')),'55000','IMMUTABLE_TERMINAL_QUESTIONNAIRE','abandoned sessions are immutable');

set local role authenticated;select set_config('request.jwt.claims','{"sub":"d0600000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal1"}',true);
insert into p06_session_observed values('outsider-snapshots',to_jsonb((select count(*)from public.questionnaire_session_snapshots)));
insert into p06_session_observed values('outsider-evaluations',to_jsonb((select count(*)from public.questionnaire_session_evaluations)));
insert into p06_session_observed values('outsider-events',to_jsonb((select count(*)from public.questionnaire_session_state_events)));
do $x$begin perform public.resume_questionnaire_session((select(v->>'session_id')::uuid from p06_session_observed where k='start'),'p06-session-outsider','d06c0000-0000-0000-0000-000000000009');exception when others then insert into p06_session_errors values('outsider-resume',sqlstate,sqlerrm);end$x$;
reset role;
select is((select v::text::bigint from p06_session_observed where k='outsider-snapshots'),0::bigint,'RLS hides another tenant snapshot');
select is((select v::text::bigint from p06_session_observed where k='outsider-evaluations'),0::bigint,'RLS hides another tenant evaluation');
select is((select v::text::bigint from p06_session_observed where k='outsider-events'),0::bigint,'RLS hides another tenant lifecycle');
select is((select s||':'||m from p06_session_errors where k='outsider-resume'),'42501:SESSION_SCOPE_DENIED','cross-tenant resume fails closed');

select * from finish();
rollback;
