begin;
set local search_path=public,extensions;
select plan(22);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values
('a7900000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner-79@example.invalid','',now(),'{}','{}',now(),now()),
('a7900000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','other-79@example.invalid','',now(),'{}','{}',now(),now()),
('a7900000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','viewer-79@example.invalid','',now(),'{}','{}',now(),now()),
('a7900000-0000-4000-8000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','admin-79@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)values
('b7900000-0000-4000-8000-000000000001','Runtime Assistance One','Assistance One','ACTIVE','a7900000-0000-4000-8000-000000000001'),
('b7900000-0000-4000-8000-000000000002','Runtime Assistance Two','Assistance Two','ACTIVE','a7900000-0000-4000-8000-000000000002');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at)values
('c7900000-0000-4000-8000-000000000001','b7900000-0000-4000-8000-000000000001','a7900000-0000-4000-8000-000000000001','ACTIVE',now()),
('c7900000-0000-4000-8000-000000000002','b7900000-0000-4000-8000-000000000002','a7900000-0000-4000-8000-000000000002','ACTIVE',now()),
('c7900000-0000-4000-8000-000000000003','b7900000-0000-4000-8000-000000000001','a7900000-0000-4000-8000-000000000003','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code,granted_by)values
('c7900000-0000-4000-8000-000000000001','CLIENT_OWNER','a7900000-0000-4000-8000-000000000001'),
('c7900000-0000-4000-8000-000000000002','CLIENT_OWNER','a7900000-0000-4000-8000-000000000002'),
('c7900000-0000-4000-8000-000000000003','CLIENT_VIEWER','a7900000-0000-4000-8000-000000000001');
insert into public.platform_user_roles(user_id,role_code,granted_by)values('a7900000-0000-4000-8000-000000000004','MATRICIA_ADMIN','a7900000-0000-4000-8000-000000000004');

insert into public.client_compliance_cases(id,organization_id,created_by)values('d7900000-0000-4000-8000-000000000001','b7900000-0000-4000-8000-000000000001','a7900000-0000-4000-8000-000000000001');
insert into public.client_profile_versions(id,compliance_case_id,organization_id,version,profile_data,organization_snapshot,source_organization_row_version,created_by)values
('e7900000-0000-4000-8000-000000000001','d7900000-0000-4000-8000-000000000001','b7900000-0000-4000-8000-000000000001',1,'{"sector":"IT","employees":2}','{}',1,'a7900000-0000-4000-8000-000000000001'),
('e7900000-0000-4000-8000-000000000002','d7900000-0000-4000-8000-000000000001','b7900000-0000-4000-8000-000000000001',2,'{"sector":"IT","employees":5,"city":"Rabat"}','{}',1,'a7900000-0000-4000-8000-000000000001');

select is((select count(*)from public.assistance_profile_reassessments where organization_id='b7900000-0000-4000-8000-000000000001'),2::bigint,'profile inserts enqueue reassessments at runtime');
select is((select changed_keys from public.assistance_profile_reassessments where profile_version_id='e7900000-0000-4000-8000-000000000002'),array['city','employees'],'profile trigger records only changed keys');

create temporary table assistance_runtime_observed(key text primary key,value jsonb);
grant select,insert on assistance_runtime_observed to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','a7900000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a7900000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into assistance_runtime_observed values('analysis_first',public.run_assisted_analysis('b7900000-0000-4000-8000-000000000001','PROFILE_CHANGE',null,'{}','{}','{}','a1000000-0000-4000-8000-000000000001',(select id from public.assistance_profile_reassessments where profile_version_id='e7900000-0000-4000-8000-000000000002'),'runtime-analysis-0001','f7900000-0000-4000-8000-000000000001'));
insert into assistance_runtime_observed values('analysis_replay',public.run_assisted_analysis('b7900000-0000-4000-8000-000000000001','PROFILE_CHANGE',null,'{}','{}','{}','a1000000-0000-4000-8000-000000000001',(select id from public.assistance_profile_reassessments where profile_version_id='e7900000-0000-4000-8000-000000000002'),'runtime-analysis-0001','f7900000-0000-4000-8000-000000000099'));
reset role;
select is((select value->>'request_id'from assistance_runtime_observed where key='analysis_first'),(select value->>'request_id'from assistance_runtime_observed where key='analysis_replay'),'analysis replay returns cached result after reassessment became completed');
select is((select count(*)from public.assistance_requests where id=((select value->>'request_id'from assistance_runtime_observed where key='analysis_first')::uuid)),1::bigint,'analysis replay creates one request');
select is((select status from public.assistance_profile_reassessments where profile_version_id='e7900000-0000-4000-8000-000000000002'),'COMPLETED','profile reassessment completes exactly once');

select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','a7900000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a7900000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);select public.run_assisted_analysis('b7900000-0000-4000-8000-000000000002','CONTEXTUAL_ASSISTANT',null,'{}','{}','{}','a1000000-0000-4000-8000-000000000001',null,'runtime-cross-tenant','f7900000-0000-4000-8000-000000000002')$$,'42501'::char(5),'ASSISTANCE_ACCESS_DENIED','analysis denies a foreign tenant');

insert into public.assistance_suggestions(id,organization_id,request_id,suggestion_kind,target_type,score_basis_points,explanation_code,explanation)values('f7910000-0000-4000-8000-000000000001','b7900000-0000-4000-8000-000000000001',((select value->>'request_id'from assistance_runtime_observed where key='analysis_first')::uuid),'CONTEXTUAL_GUIDANCE','PROFILE',5000,'HUMAN_GUIDANCE','{"model_version":1,"evidence":{},"human_review_required":true}');
set local role authenticated;
select set_config('request.jwt.claim.sub','a7900000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a7900000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into assistance_runtime_observed values('decision_first',public.decide_assisted_suggestion('f7910000-0000-4000-8000-000000000001','ACCEPTED','Validation humaine explicite','runtime-decision-0001','f7900000-0000-4000-8000-000000000003'));
insert into assistance_runtime_observed values('decision_replay',public.decide_assisted_suggestion('f7910000-0000-4000-8000-000000000001','ACCEPTED','Validation humaine explicite','runtime-decision-0001','f7900000-0000-4000-8000-000000000004'));
reset role;
select is((select value->>'decision_id'from assistance_runtime_observed where key='decision_first'),(select value->>'decision_id'from assistance_runtime_observed where key='decision_replay'),'decision replay returns cached result after suggestion became accepted');
select is((select count(*)from public.assistance_suggestion_decisions where suggestion_id='f7910000-0000-4000-8000-000000000001'),1::bigint,'decision replay creates one human decision');
select is((select status from public.assistance_suggestions where id='f7910000-0000-4000-8000-000000000001'),'ACCEPTED','human decision updates only suggestion status');
select is((select value->>'business_action_executed'from assistance_runtime_observed where key='decision_first'),'false','accepted suggestion performs no autonomous business action');
select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','a7900000-0000-4000-8000-000000000002',true);select set_config('request.jwt.claims','{"sub":"a7900000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);select public.decide_assisted_suggestion('f7910000-0000-4000-8000-000000000001','ACCEPTED','Tentative autre tenant','runtime-decision-cross','f7900000-0000-4000-8000-000000000005')$$,'42501'::char(5),'ASSISTANCE_DECISION_DENIED','decision denies a foreign tenant');

set local role authenticated;select set_config('request.jwt.claim.sub','a7900000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a7900000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into assistance_runtime_observed values('need_text',public.run_assisted_analysis('b7900000-0000-4000-8000-000000000001','NEED_TEXT','Contact test.person@example.com au +212 612 345 678 pour un audit','{}','{}','{}','a1000000-0000-4000-8000-000000000001',null,'runtime-need-text','f7900000-0000-4000-8000-000000000006'));
reset role;
select ok((select input_text like'%[EMAIL]%'and input_text like'%[PHONE]%'and input_text not like'%test.person@example.com%'and input_text not like'%612 345 678%'and length(input_text)<=1000 from public.assistance_requests where id=((select value->>'request_id'from assistance_runtime_observed where key='need_text')::uuid)),'stored free text is bounded and category-redacted');
select ok((select input_text_expires_at<=created_at+interval'30 days'from public.assistance_requests where id=((select value->>'request_id'from assistance_runtime_observed where key='need_text')::uuid)),'free text retention is capped at thirty days');
select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','a7900000-0000-4000-8000-000000000003',true);select set_config('request.jwt.claims','{"sub":"a7900000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal2"}',true);select public.get_assistance_request_input(((select value->>'request_id'from assistance_runtime_observed where key='need_text')::uuid))$$,'42501'::char(5),'ASSISTANCE_INPUT_ACCESS_DENIED','ordinary tenant viewer cannot retrieve retained input');
select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','a7900000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a7900000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);select input_text from public.assistance_requests limit 1$$,'42501'::char(5),'permission denied for table assistance_requests','input column has no direct API read privilege');
set local role authenticated;select set_config('request.jwt.claim.sub','a7900000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a7900000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);insert into assistance_runtime_observed values('input_owner',public.get_assistance_request_input(((select value->>'request_id'from assistance_runtime_observed where key='need_text')::uuid)));reset role;
select is((select value->>'available'from assistance_runtime_observed where key='input_owner'),'true','need-to-know owner can retrieve retained minimized input');
select ok(not exists(select 1 from public.event_outbox where event_type like'Assistance%'and(payload::text like'%test.person@example.com%'or payload::text like'%612 345 678%')),'Outbox contains no submitted PII');

insert into public.assistance_requests(id,organization_id,model_version_id,context_type,input_text,input_hash,created_by,created_at,input_text_expires_at)values('f7920000-0000-4000-8000-000000000001','b7900000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','NEED_TEXT','Donnée expirée',repeat('9',64),'a7900000-0000-4000-8000-000000000001',now()-interval'31 days',now()-interval'1 day');
set local role authenticated;select set_config('request.jwt.claim.sub','a7900000-0000-4000-8000-000000000004',true);select set_config('request.jwt.claims','{"sub":"a7900000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal2"}',true);insert into assistance_runtime_observed values('redacted',to_jsonb(public.redact_expired_assistance_inputs(10)));reset role;
select ok((select input_text is null and input_text_redacted_at is not null from public.assistance_requests where id='f7920000-0000-4000-8000-000000000001'),'expired input is physically redacted at runtime');
select ok((select p.prosrc like'%ANOMALY_PAIR%'and p.prosrc like'%title_fr%title_ar%'and p.prosrc like'%begin_contract_command%'and p.prosrc like'%cardinality(coalesce(p_candidate_anomaly_ids%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='run_assisted_anomaly_similarity_runtime_v2'),'anomaly similarity core is bilingual bounded and replay-safe');
select ok((select p.prosrc like'%begin_contract_command%'and strpos(p.prosrc,'begin_contract_command')<strpos(p.prosrc,'run_assisted_analysis_core_v1')from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='run_assisted_analysis_runtime_v2'),'analysis consults idempotency before mutable core state');
select ok((select p.prosrc like'%begin_contract_command%'and strpos(p.prosrc,'begin_contract_command')<strpos(p.prosrc,'decide_assisted_suggestion_core_v1')from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='decide_assisted_suggestion_runtime_v2'),'decision consults idempotency before mutable suggestion status');
select ok((select count(*)=2 from public.audit_events where organization_id='b7900000-0000-4000-8000-000000000001'and action='assistance.analysis.completed')and(select count(*)=1 from public.audit_events where organization_id='b7900000-0000-4000-8000-000000000001'and action='assistance.suggestion.accepted'),'replays do not duplicate core audit events');

select * from finish();rollback;
