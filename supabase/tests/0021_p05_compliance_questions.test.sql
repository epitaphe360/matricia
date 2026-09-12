begin;
set local search_path=public,extensions;
select plan(24);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('b2100000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p05-question-owner@example.invalid','',now(),'{}','{}',now(),now()),
('b2100000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p05-question-central@example.invalid','',now(),'{}','{}',now(),now()),
('b2100000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p05-question-outsider@example.invalid','',now(),'{}','{}',now(),now()),
('b2100000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p05-question-questioner@example.invalid','',now(),'{}','{}',now(),now()),
('b2100000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p05-question-reviewer@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by) values
('b2110000-0000-0000-0000-000000000001','P05 Questions SARL','P05 Questions','PENDING','b2100000-0000-0000-0000-000000000001'),
('b2110000-0000-0000-0000-000000000002','P05 Other SARL','P05 Other','ACTIVE','b2100000-0000-0000-0000-000000000003');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at) values
('b2120000-0000-0000-0000-000000000001','b2110000-0000-0000-0000-000000000001','b2100000-0000-0000-0000-000000000001','ACTIVE',now()),
('b2120000-0000-0000-0000-000000000002','b2110000-0000-0000-0000-000000000002','b2100000-0000-0000-0000-000000000003','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code) values
('b2120000-0000-0000-0000-000000000001','CLIENT_OWNER'),
('b2120000-0000-0000-0000-000000000002','CLIENT_OWNER');
insert into public.platform_user_roles(user_id,role_code) values
('b2100000-0000-0000-0000-000000000002','COMPLIANCE_MANAGER'),
('b2100000-0000-0000-0000-000000000004','COMPLIANCE_MANAGER'),
('b2100000-0000-0000-0000-000000000005','COMPLIANCE_MANAGER');
insert into public.organization_identifiers(organization_id,identifier_type,normalized_value,verification_status,is_active) values
('b2110000-0000-0000-0000-000000000001','ICE','P05QICE001','UNVERIFIED',true),
('b2110000-0000-0000-0000-000000000001','IF','P05QIF001','UNVERIFIED',true),
('b2110000-0000-0000-0000-000000000001','RC','P05QRC001','UNVERIFIED',true);
insert into public.client_compliance_cases(id,organization_id,status,created_by,submitted_by) values('b2130000-0000-0000-0000-000000000001','b2110000-0000-0000-0000-000000000001','PROFILE_IN_PROGRESS','b2100000-0000-0000-0000-000000000001','b2100000-0000-0000-0000-000000000001');
insert into public.client_profile_versions(compliance_case_id,organization_id,version,profile_data,organization_snapshot,source_organization_row_version,created_by) values
('b2130000-0000-0000-0000-000000000001','b2110000-0000-0000-0000-000000000001',1,'{}','{}',1,'b2100000-0000-0000-0000-000000000001');
update public.client_compliance_cases set current_profile_version=1 where id='b2130000-0000-0000-0000-000000000001';

create temporary table p05_question_observed(key text primary key,value text not null);
grant select,insert on p05_question_observed to authenticated;
select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','b2100000-0000-0000-0000-000000000002',true); select set_config('request.jwt.claims','{"sub":"b2100000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal1"}',true); select public.evaluate_client_compliance('b2130000-0000-0000-0000-000000000001','p05-question-aal1-deny')$$,
  '42501','CENTRAL_COMPLIANCE_REVIEW_REQUIRED','AAL1 cannot run central compliance evaluation'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b2100000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"b2100000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}',true);
insert into p05_question_observed values('evaluation',public.evaluate_client_compliance('b2130000-0000-0000-0000-000000000001','p05-question-evaluate-1')::text);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b2100000-0000-0000-0000-000000000004',true);
select set_config('request.jwt.claims','{"sub":"b2100000-0000-0000-0000-000000000004","role":"authenticated","aal":"aal2"}',true);
insert into p05_question_observed values('question_id',public.create_client_compliance_question(
  (select id from public.client_administrative_anomalies where compliance_case_id='b2130000-0000-0000-0000-000000000001' and anomaly_code='ICE_NOT_VERIFIED'),
  'Veuillez fournir un justificatif ICE lisible.','يرجى تقديم وثيقة واضحة لمعرف ICE.','REGISTRATION_DOCUMENT',transaction_timestamp()+interval '5 days','p05-question-create-1'
)::text);
insert into p05_question_observed values('question_retry',public.create_client_compliance_question(
  (select id from public.client_administrative_anomalies where compliance_case_id='b2130000-0000-0000-0000-000000000001' and anomaly_code='ICE_NOT_VERIFIED'),
  'Veuillez fournir un justificatif ICE lisible.','يرجى تقديم وثيقة واضحة لمعرف ICE.','REGISTRATION_DOCUMENT',transaction_timestamp()+interval '5 days','p05-question-create-1'
)::text);
reset role;

select is(((select value::jsonb from p05_question_observed where key='evaluation')->>'blocking_anomalies')::integer,5,'evaluation detects three identifiers and two required documents');
select is((select value from p05_question_observed where key='question_retry'),(select value from p05_question_observed where key='question_id'),'question creation retry is idempotent');
select is((select status from public.client_compliance_cases where id='b2130000-0000-0000-0000-000000000001'),'QUESTION_REQUIRED','a compliance question moves the case to QUESTION_REQUIRED');
select is((select status from public.client_administrative_anomalies where anomaly_code='ICE_NOT_VERIFIED' and compliance_case_id='b2130000-0000-0000-0000-000000000001'),'QUESTIONED','the question is linked to the blocking anomaly');

set local role authenticated;
select set_config('request.jwt.claim.sub','b2100000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"b2100000-0000-0000-0000-000000000003","role":"authenticated","aal":"aal1"}',true);
insert into p05_question_observed values('outsider_anomalies',(select count(*)::text from public.client_administrative_anomalies));
insert into p05_question_observed values('outsider_questions',(select count(*)::text from public.client_compliance_questions));
reset role;
select is((select value::bigint from p05_question_observed where key='outsider_anomalies'),0::bigint,'RLS hides anomalies from another tenant');
select is((select value::bigint from p05_question_observed where key='outsider_questions'),0::bigint,'RLS hides questions from another tenant');

set local role authenticated;
select set_config('request.jwt.claim.sub','b2100000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"b2100000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal1"}',true);
insert into p05_question_observed values('response',public.respond_client_compliance_question((select value::uuid from p05_question_observed where key='question_id'),'Le justificatif corrigé a été transmis.','p05-question-response-1')::text);
insert into p05_question_observed values('response_retry',public.respond_client_compliance_question((select value::uuid from p05_question_observed where key='question_id'),'Le justificatif corrigé a été transmis.','p05-question-response-1')::text);
reset role;
select is((select value from p05_question_observed where key='response_retry'),(select value from p05_question_observed where key='response'),'response submission is idempotent');
select is((select status from public.client_compliance_questions where id=(select value::uuid from p05_question_observed where key='question_id')),'ANSWERED','the client response is awaiting review');
select is((select status from public.client_compliance_cases where id='b2130000-0000-0000-0000-000000000001'),'RESPONSE_RECEIVED','the case records response receipt');

set local role authenticated;
select set_config('request.jwt.claim.sub','b2100000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"b2100000-0000-0000-0000-000000000003","role":"authenticated","aal":"aal1"}',true);
insert into p05_question_observed values('outsider_responses',(select count(*)::text from public.client_compliance_response_versions));
reset role;
select is((select value::bigint from p05_question_observed where key='outsider_responses'),0::bigint,'RLS hides response history from another tenant');

set local role authenticated;
select set_config('request.jwt.claim.sub','b2100000-0000-0000-0000-000000000005',true);
select set_config('request.jwt.claims','{"sub":"b2100000-0000-0000-0000-000000000005","role":"authenticated","aal":"aal2"}',true);
reset role;
select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','b2100000-0000-0000-0000-000000000005',true); select set_config('request.jwt.claims','{"sub":"b2100000-0000-0000-0000-000000000005","role":"authenticated","aal":"aal2"}',true); select public.accept_client_compliance_response((select value::uuid from p05_question_observed where key='question_id'),null,'p05-question-null-decision')$$,
  '22023','INVALID_COMPLIANCE_DECISION','a null review decision has no side effect'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b2100000-0000-0000-0000-000000000005',true);
select set_config('request.jwt.claims','{"sub":"b2100000-0000-0000-0000-000000000005","role":"authenticated","aal":"aal2"}',true);
insert into p05_question_observed values('accept',public.accept_client_compliance_response((select value::uuid from p05_question_observed where key='question_id'),true,'p05-question-accept-1')::text);
insert into p05_question_observed values('accept_retry',public.accept_client_compliance_response((select value::uuid from p05_question_observed where key='question_id'),true,'p05-question-accept-1')::text);
reset role;
select is((select value from p05_question_observed where key='accept_retry'),(select value from p05_question_observed where key='accept'),'response decision retry is idempotent');
select is((select status from public.client_compliance_questions where id=(select value::uuid from p05_question_observed where key='question_id')),'ACCEPTED','central review accepts the response');
select is((select status from public.client_administrative_anomalies where anomaly_code='ICE_NOT_VERIFIED' and compliance_case_id='b2130000-0000-0000-0000-000000000001'),'RESOLVED','an accepted response closes its anomaly');
select is((select status from public.client_compliance_cases where id='b2130000-0000-0000-0000-000000000001'),'DOCUMENTS_REQUIRED','the case remains in remediation while other blocking anomalies exist');
select throws_ok(
  $$update public.client_compliance_cases set status='VERIFIED',verified_at=clock_timestamp(),activated_at=clock_timestamp() where id='b2130000-0000-0000-0000-000000000001'$$,
  '55000','BLOCKING_COMPLIANCE_ANOMALY','remaining blocking anomalies prevent verification');
reset role;
select throws_ok($$update public.client_compliance_response_versions set response_text='rewritten' where question_id=(select value::uuid from p05_question_observed where key='question_id')$$,'55000','IMMUTABLE_RECORD','response history is immutable');
select is((select count(*) from public.audit_events where resource_id in ('b2130000-0000-0000-0000-000000000001',(select value from p05_question_observed where key='question_id')) and action in ('client.compliance.evaluated','client.compliance.question.created','client.compliance.response.received','client.compliance.response.decided')),4::bigint,'every compliance transition is audited once');
select is((select count(*) from public.event_outbox where aggregate_id in ('b2130000-0000-0000-0000-000000000001',(select value from p05_question_observed where key='question_id')) and event_type in ('ClientComplianceEvaluatedV1','ClientComplianceQuestionCreatedV1','ClientComplianceResponseReceivedV1','ClientComplianceResponseAcceptedV1')),4::bigint,'every compliance transition emits one durable event');
select ok(not has_table_privilege('authenticated','public.client_compliance_response_versions','INSERT'),'clients cannot bypass the versioned response RPC');
select ok(not has_function_privilege('anon','public.respond_client_compliance_question(uuid,text,text,uuid)','EXECUTE'),'anonymous actors cannot answer compliance questions');
select is((select count(*) from public.client_compliance_response_versions where question_id=(select value::uuid from p05_question_observed where key='question_id')),1::bigint,'idempotent retry creates one response version');
select ok((select count(*)=5 from public.client_administrative_anomalies where compliance_case_id='b2130000-0000-0000-0000-000000000001'),'evaluation uses a bounded deterministic rule set');

select * from finish();
rollback;
