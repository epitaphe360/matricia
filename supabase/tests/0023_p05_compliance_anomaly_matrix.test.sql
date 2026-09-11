begin;
set local search_path=public,extensions;
select plan(20);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('b2300000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p05-matrix-owner@example.invalid','',now(),'{}','{}',now(),now()),
('b2300000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p05-matrix-central@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)
values('b2310000-0000-0000-0000-000000000001','Matrice Client SARL','Matrice Client','PENDING','b2300000-0000-0000-0000-000000000001');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at)
values('b2320000-0000-0000-0000-000000000001','b2310000-0000-0000-0000-000000000001','b2300000-0000-0000-0000-000000000001','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code)
values('b2320000-0000-0000-0000-000000000001','CLIENT_OWNER');
insert into public.platform_user_roles(user_id,role_code)
values('b2300000-0000-0000-0000-000000000002','COMPLIANCE_MANAGER');
insert into public.organization_identifiers(organization_id,identifier_type,normalized_value,verification_status,is_active) values
('b2310000-0000-0000-0000-000000000001','ICE','MATRIXICE001','VERIFIED',true),
('b2310000-0000-0000-0000-000000000001','IF','MATRIXIF001','VERIFIED',true),
('b2310000-0000-0000-0000-000000000001','RC','MATRIXRC001','VERIFIED',true);
insert into public.client_compliance_cases(id,organization_id,status,created_by)
values('b2330000-0000-0000-0000-000000000001','b2310000-0000-0000-0000-000000000001','PROFILE_IN_PROGRESS','b2300000-0000-0000-0000-000000000001');
insert into public.client_profile_versions(compliance_case_id,organization_id,version,profile_data,organization_snapshot,source_organization_row_version,created_by)
values('b2330000-0000-0000-0000-000000000001','b2310000-0000-0000-0000-000000000001',1,
  '{"legal_form":"SARL","library_codes":["IT"],"registered_address":{"line1":"10 rue A"},"representative":{"first_name":"Amal","last_name":"Alami"}}',
  '{}',1,'b2300000-0000-0000-0000-000000000001');
update public.client_compliance_cases set current_profile_version=1 where id='b2330000-0000-0000-0000-000000000001';

insert into public.client_compliance_documents(
  id,compliance_case_id,organization_id,document_type,version,policy_version_id,
  document_number,issuer,issued_on,expires_on,original_file_name,file_extension,
  declared_mime_type,declared_size_bytes,declared_sha256,storage_object_path,
  detected_mime_type,detected_size_bytes,status,uploaded_at,reviewed_by,reviewed_at,
  created_by
) values
('b2340000-0000-0000-0000-000000000001','b2330000-0000-0000-0000-000000000001','b2310000-0000-0000-0000-000000000001','REGISTRATION_DOCUMENT',1,
 (select id from public.client_document_policy_versions where document_type='REGISTRATION_DOCUMENT' and status='ACTIVE'),
 'RC-MATRIX','Tribunal',current_date-30,current_date+365,'matrix.pdf','pdf','application/pdf',128,repeat('a',64),
 'b2310000-0000-0000-0000-000000000001/b2330000-0000-0000-0000-000000000001/b2340000-0000-0000-0000-000000000001.pdf',
 'application/pdf',128,'VERIFIED',clock_timestamp(),'b2300000-0000-0000-0000-000000000002',clock_timestamp(),
 'b2300000-0000-0000-0000-000000000001'),
('b2340000-0000-0000-0000-000000000002','b2330000-0000-0000-0000-000000000001','b2310000-0000-0000-0000-000000000001','TAX_DOCUMENT',1,
 (select id from public.client_document_policy_versions where document_type='TAX_DOCUMENT' and status='ACTIVE'),
 'IF-OLD','Tax',current_date-365,current_date-1,'old.pdf','pdf','application/pdf',64,repeat('b',64),
 'b2310000-0000-0000-0000-000000000001/b2330000-0000-0000-0000-000000000001/b2340000-0000-0000-0000-000000000002.pdf',
 'application/pdf',64,'PENDING_REVIEW',clock_timestamp(),null,null,
 'b2300000-0000-0000-0000-000000000001'),
('b2340000-0000-0000-0000-000000000003','b2330000-0000-0000-0000-000000000001','b2310000-0000-0000-0000-000000000001','REPRESENTATIVE_AUTHORITY',1,
 (select id from public.client_document_policy_versions where document_type='REPRESENTATIVE_AUTHORITY' and status='ACTIVE'),
 'AUTH-OLD','Notary',current_date-365,current_date-1,'authority-old.pdf','pdf','application/pdf',64,repeat('c',64),
 'b2310000-0000-0000-0000-000000000001/b2330000-0000-0000-0000-000000000001/b2340000-0000-0000-0000-000000000003.pdf',
 'application/pdf',64,'PENDING_REVIEW',clock_timestamp(),null,null,
 'b2300000-0000-0000-0000-000000000001'),
('b2340000-0000-0000-0000-000000000004','b2330000-0000-0000-0000-000000000001','b2310000-0000-0000-0000-000000000001','TAX_DOCUMENT',2,
 (select id from public.client_document_policy_versions where document_type='TAX_DOCUMENT' and status='ACTIVE'),
 'IF-CURRENT','Tax',current_date-30,current_date+365,'tax-current.pdf','pdf','application/pdf',64,repeat('d',64),
 'b2310000-0000-0000-0000-000000000001/b2330000-0000-0000-0000-000000000001/b2340000-0000-0000-0000-000000000004.pdf',
 'application/pdf',64,'PENDING_REVIEW',clock_timestamp(),null,null,
 'b2300000-0000-0000-0000-000000000001');
insert into private.client_document_scan_results(
  id,document_id,organization_id,sequence,result,engine_code,engine_version,computed_sha256,
  detected_mime_type,detected_size_bytes,observed_claims,recorded_by,scanner_principal,correlation_id
) values
('b2350000-0000-0000-0000-000000000010','b2340000-0000-0000-0000-000000000001','b2310000-0000-0000-0000-000000000001',1,'CLEAN','DEMO_SCANNER','1.0',repeat('a',64),'application/pdf',128,
 '{"legal_name":"Autre Société SA","legal_form":"SA","registered_address":{"line1":"99 rue B"},"representative":{"first_name":"Nadia","last_name":"Bennani"}}',
 null,'SUPABASE_SERVICE_ROLE','b2350000-0000-0000-0000-000000000001'),
('b2350000-0000-0000-0000-000000000011','b2340000-0000-0000-0000-000000000002','b2310000-0000-0000-0000-000000000001',1,'ERROR','DEMO_SCANNER','1.0',repeat('b',64),'application/pdf',64,
 '{}',null,'SUPABASE_SERVICE_ROLE','b2350000-0000-0000-0000-000000000002'),
('b2350000-0000-0000-0000-000000000012','b2340000-0000-0000-0000-000000000003','b2310000-0000-0000-0000-000000000001',1,'ERROR','DEMO_SCANNER','1.0',repeat('c',64),'application/pdf',64,
 '{}',null,'SUPABASE_SERVICE_ROLE','b2350000-0000-0000-0000-000000000003'),
('b2350000-0000-0000-0000-000000000013','b2340000-0000-0000-0000-000000000004','b2310000-0000-0000-0000-000000000001',1,'CLEAN','DEMO_SCANNER','1.0',repeat('d',64),'application/pdf',64,
 '{}',null,'SUPABASE_SERVICE_ROLE','b2350000-0000-0000-0000-000000000004');
update public.client_compliance_documents
set current_scan_result_id='b2350000-0000-0000-0000-000000000010',scan_status='CLEAN',scanned_at=clock_timestamp()
where id='b2340000-0000-0000-0000-000000000001';
update public.client_compliance_documents
set current_scan_result_id='b2350000-0000-0000-0000-000000000011',scan_status='ERROR',scanned_at=clock_timestamp()
where id='b2340000-0000-0000-0000-000000000002';
update public.client_compliance_documents
set current_scan_result_id='b2350000-0000-0000-0000-000000000012',scan_status='ERROR',scanned_at=clock_timestamp()
where id='b2340000-0000-0000-0000-000000000003';
update public.client_compliance_documents
set current_scan_result_id='b2350000-0000-0000-0000-000000000013',scan_status='CLEAN',scanned_at=clock_timestamp()
where id='b2340000-0000-0000-0000-000000000004';
insert into public.client_compliance_evidence(
  compliance_case_id,organization_id,evidence_type,object_path,file_sha256,review_status,
  reviewed_by,reviewed_at,created_by,source_document_id,valid_until,validation_state
) values
('b2330000-0000-0000-0000-000000000001','b2310000-0000-0000-0000-000000000001','REGISTRATION_DOCUMENT','matrix/registration.pdf',repeat('a',64),'VERIFIED','b2300000-0000-0000-0000-000000000002',clock_timestamp(),'b2300000-0000-0000-0000-000000000001','b2340000-0000-0000-0000-000000000001',current_date+365,'SCANNED_CLEAN');

create temporary table p05_matrix_observed(key text primary key,value jsonb not null);
grant select,insert on p05_matrix_observed to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','b2300000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"b2300000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}',true);
insert into p05_matrix_observed values('evaluate',public.evaluate_client_compliance(
  'b2330000-0000-0000-0000-000000000001','p05-matrix-evaluate-1'));
insert into p05_matrix_observed values('retry',public.evaluate_client_compliance(
  'b2330000-0000-0000-0000-000000000001','p05-matrix-evaluate-1'));
reset role;

select is((select value from p05_matrix_observed where key='retry'),(select value from p05_matrix_observed where key='evaluate'),'matrix evaluation retry is idempotent');
select is((select value->>'blocking_anomalies' from p05_matrix_observed where key='evaluate'),'7','required evidence and six targeted Gold Master anomalies are detected');
select is((select status from public.client_administrative_anomalies where anomaly_code='LEGAL_NAME_MISMATCH'),'OPEN','legal-name mismatch is detected');
select is((select status from public.client_administrative_anomalies where anomaly_code='LEGAL_FORM_MISMATCH'),'OPEN','legal-form mismatch is detected');
select is((select status from public.client_administrative_anomalies where anomaly_code='ADDRESS_MISMATCH'),'OPEN','address mismatch is detected');
select is((select status from public.client_administrative_anomalies where anomaly_code='REPRESENTATIVE_MISMATCH'),'OPEN','representative mismatch is detected');
select is((select status from public.client_administrative_anomalies where anomaly_code='DOCUMENT_EXPIRED'),'OPEN','expired document is detected');
select is((select status from public.client_administrative_anomalies where anomaly_code='DOCUMENT_UNREADABLE'),'OPEN','unreadable document is detected');
select is((select status from public.client_administrative_anomalies where anomaly_code='REPRESENTATIVE_AUTHORITY_MISSING'),'OPEN','legacy or unreadable evidence cannot satisfy a required document');
select is((select count(*) from public.client_administrative_anomalies where anomaly_code='TAX_DOCUMENT_MISSING'),0::bigint,'optional TAX documents do not create a missing-document anomaly');
select ok((select bool_and(entered_value_digest is null or entered_value_digest~'^[0-9a-f]{64}$') from public.client_administrative_anomalies),'entered values are represented only by digests');
select ok((select bool_and(observed_value_digest is null or observed_value_digest~'^[0-9a-f]{64}$') from public.client_administrative_anomalies),'observed values are represented only by digests');
select ok(not exists(select 1 from public.audit_events where metadata::text like '%Autre Société%'),'audit metadata contains no extracted legal identity');
select ok(not exists(select 1 from public.event_outbox where payload::text like '%99 rue B%'),'Outbox contains no extracted address');
select is((select count(*) from public.audit_events where action='client.compliance.evaluated' and resource_id='b2330000-0000-0000-0000-000000000001'),1::bigint,'evaluation is audited once');
select is((select count(*) from public.event_outbox where event_type='ClientComplianceEvaluatedV1' and aggregate_id='b2330000-0000-0000-0000-000000000001'),1::bigint,'evaluation emits one durable event');
select ok((select jsonb_array_length(metadata->'requirement_versions')=2
    and not exists(select 1 from jsonb_array_elements(metadata->'requirement_versions') item
      where not (item ? 'id' and item ? 'version'))
  from public.audit_events where action='client.compliance.evaluated'
    and resource_id='b2330000-0000-0000-0000-000000000001'),
  'audit captures the ordered requirement IDs and versions without document contents');
select is(
  (select payload->'requirement_versions' from public.event_outbox
    where event_type='ClientComplianceEvaluatedV1' and aggregate_id='b2330000-0000-0000-0000-000000000001'),
  (select metadata->'requirement_versions' from public.audit_events
    where action='client.compliance.evaluated' and resource_id='b2330000-0000-0000-0000-000000000001'),
  'Outbox carries the same deterministic requirement-version snapshot as audit');
insert into public.client_document_requirement_versions(
  organization_kind,library_code,document_type,version,required,status,effective_from
) values('CLIENT','IT','TAX_DOCUMENT',1,true,'ACTIVE',clock_timestamp());
select throws_ok(
  $$set local role authenticated;select set_config('request.jwt.claim.sub','b2300000-0000-0000-0000-000000000002',true);select set_config('request.jwt.claims','{"sub":"b2300000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}',true);select public.evaluate_client_compliance('b2330000-0000-0000-0000-000000000001','p05-matrix-evaluate-1')$$,
  '22000','IDEMPOTENCY_PAYLOAD_MISMATCH','a changed applicable requirement matrix invalidates reuse of an old idempotency key');
update public.client_document_requirement_versions
set status='RETIRED',effective_to=clock_timestamp()
where organization_kind='CLIENT' and library_code='IT'
  and document_type='TAX_DOCUMENT' and version=1;

insert into public.client_compliance_questions(
  id,compliance_case_id,organization_id,anomaly_id,question_text_fr,question_text_ar,
  due_at,status,created_by
) values('b2360000-0000-0000-0000-000000000001','b2330000-0000-0000-0000-000000000001',
  'b2310000-0000-0000-0000-000000000001',
  (select id from public.client_administrative_anomalies where anomaly_code='LEGAL_NAME_MISMATCH'),
  'Veuillez clarifier la raison sociale.','يرجى توضيح الاسم القانوني.',clock_timestamp()+interval '1 day','OPEN',
  'b2300000-0000-0000-0000-000000000002');
update public.client_administrative_anomalies set status='QUESTIONED'
where anomaly_code='LEGAL_NAME_MISMATCH';
insert into private.client_document_scan_results(
  id,document_id,organization_id,sequence,result,engine_code,engine_version,computed_sha256,
  detected_mime_type,detected_size_bytes,observed_claims,recorded_by,scanner_principal,correlation_id
) values('b2350000-0000-0000-0000-000000000014','b2340000-0000-0000-0000-000000000001',
  'b2310000-0000-0000-0000-000000000001',2,'CLEAN','DEMO_SCANNER','1.1',repeat('a',64),
  'application/pdf',128,
  '{"legal_name":"Matrice Client SARL","legal_form":"SA","registered_address":{"line1":"99 rue B"},"representative":{"first_name":"Nadia","last_name":"Bennani"}}',
  null,'SUPABASE_SERVICE_ROLE','b2350000-0000-0000-0000-000000000005');
update public.client_compliance_documents
set current_scan_result_id='b2350000-0000-0000-0000-000000000014',row_version=row_version+1
where id='b2340000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','b2300000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"b2300000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}',true);
select public.evaluate_client_compliance('b2330000-0000-0000-0000-000000000001','p05-matrix-evaluate-2');
reset role;
select is((select status from public.client_administrative_anomalies where anomaly_code='LEGAL_NAME_MISMATCH'),'QUESTIONED','reevaluation preserves an active question instead of silently resolving its anomaly');

select * from finish();
rollback;
