begin;
set local search_path = public, extensions;
select plan(31);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
('b2000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','documents-owner-a@example.invalid','',now(),'{}','{}',now(),now()),
('b2000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','documents-owner-b@example.invalid','',now(),'{}','{}',now(),now()),
('b2000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','documents-reviewer@example.invalid','',now(),'{}','{}',now(),now());

insert into public.organizations (id,legal_name,display_name,status,created_by) values
('b2010000-0000-0000-0000-000000000001','Documents Client A SARL','Documents A','PENDING','b2000000-0000-0000-0000-000000000001'),
('b2010000-0000-0000-0000-000000000002','Documents Client B SARL','Documents B','PENDING','b2000000-0000-0000-0000-000000000002');
insert into public.organization_memberships (id,organization_id,user_id,status,activated_at) values
('b2020000-0000-0000-0000-000000000001','b2010000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','ACTIVE',now()),
('b2020000-0000-0000-0000-000000000002','b2010000-0000-0000-0000-000000000002','b2000000-0000-0000-0000-000000000002','ACTIVE',now());
insert into public.organization_member_roles (membership_id,role_code) values
('b2020000-0000-0000-0000-000000000001','CLIENT_OWNER'),
('b2020000-0000-0000-0000-000000000002','CLIENT_OWNER');
insert into public.platform_user_roles (user_id,role_code) values
('b2000000-0000-0000-0000-000000000003','COMPLIANCE_MANAGER');

insert into public.client_compliance_cases (id,organization_id,created_by) values
('b2030000-0000-0000-0000-000000000001','b2010000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001'),
('b2030000-0000-0000-0000-000000000002','b2010000-0000-0000-0000-000000000002','b2000000-0000-0000-0000-000000000002');
insert into public.client_profile_versions (
  compliance_case_id,organization_id,version,profile_data,organization_snapshot,
  source_organization_row_version,created_by
) values
('b2030000-0000-0000-0000-000000000001','b2010000-0000-0000-0000-000000000001',1,'{}','{}',1,'b2000000-0000-0000-0000-000000000001'),
('b2030000-0000-0000-0000-000000000002','b2010000-0000-0000-0000-000000000002',1,'{}','{}',1,'b2000000-0000-0000-0000-000000000002');
update public.client_compliance_cases set current_profile_version=1;

create temporary table p05_documents_observed (key text primary key, value jsonb not null);
grant select,insert on p05_documents_observed to authenticated;
grant select,insert on p05_documents_observed to service_role;

set local role authenticated;
select set_config('request.jwt.claim.sub','b2000000-0000-0000-0000-000000000001',true);
insert into p05_documents_observed values ('begin',public.begin_client_compliance_document_upload(
  'b2030000-0000-0000-0000-000000000001','REGISTRATION_DOCUMENT','RC-12345',
  'Tribunal de commerce',date '2025-01-10',date '2030-01-10','registre.pdf',
  'application/pdf',128,repeat('a',64),'p05-document-begin-0001'
));
insert into p05_documents_observed values ('begin-retry',public.begin_client_compliance_document_upload(
  'b2030000-0000-0000-0000-000000000001','REGISTRATION_DOCUMENT','RC-12345',
  'Tribunal de commerce',date '2025-01-10',date '2030-01-10','registre.pdf',
  'application/pdf',128,repeat('a',64),'p05-document-begin-0001'
));
reset role;

select is((select value->>'outcome' from p05_documents_observed where key='begin'),
  'DOCUMENT_UPLOAD_RESERVED','an owner reserves a private upload through the guarded RPC');
select is((select value from p05_documents_observed where key='begin-retry'),
  (select value from p05_documents_observed where key='begin'),'upload reservation is idempotent');
select is((select count(*) from public.client_compliance_documents
  where compliance_case_id='b2030000-0000-0000-0000-000000000001'),1::bigint,
  'an idempotent retry creates no duplicate document version');
select ok((select value->>'object_path' from p05_documents_observed where key='begin')
  like 'b2010000-0000-0000-0000-000000000001/%','the generated object path is tenant-prefixed');
select is((select status from public.client_compliance_cases where id='b2030000-0000-0000-0000-000000000001'),
  'DOCUMENTS_REQUIRED','reserving a required document advances the explicit onboarding state');

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','b2000000-0000-0000-0000-000000000002',true);
    select public.begin_client_compliance_document_upload(
      'b2030000-0000-0000-0000-000000000001','TAX_DOCUMENT','IF-999','Tax authority',
      date '2025-01-01',null,'tax.pdf','application/pdf',100,repeat('b',64),'cross-tenant-doc-key'
    )$$,'P0002','COMPLIANCE_CASE_NOT_FOUND','cross-tenant reservation is non-enumerating');
reset role;
select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','b2000000-0000-0000-0000-000000000001',true);
    select public.begin_client_compliance_document_upload(
      'b2030000-0000-0000-0000-000000000001','TAX_DOCUMENT','IF-123','Tax authority',
      date '2025-01-01',null,'payload.exe','application/octet-stream',100,repeat('b',64),'invalid-mime-doc-key'
    )$$,'22023','DOCUMENT_FILE_TYPE_OR_SIZE_NOT_ALLOWED','the policy rejects unsafe MIME and extension pairs');
reset role;
select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','b2000000-0000-0000-0000-000000000001',true);
    select public.begin_client_compliance_document_upload(
      'b2030000-0000-0000-0000-000000000001','TAX_DOCUMENT','IF-123','Tax authority',
      date '2025-01-01',null,'tax.pdf','application/pdf',10485761,repeat('b',64),'oversize-document-key'
  )$$,'22023','DOCUMENT_FILE_TYPE_OR_SIZE_NOT_ALLOWED','the versioned policy enforces maximum size');
reset role;

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','b2000000-0000-0000-0000-000000000002',true);
    select public.submit_client_compliance(
      'b2030000-0000-0000-0000-000000000002','missing-required-documents-key'
    )$$,'55000','REQUIRED_CLIENT_DOCUMENTS_MISSING','submission cannot bypass required documents');
reset role;

insert into storage.objects (bucket_id,name,metadata)
select 'client-compliance',value->>'object_path',jsonb_build_object('mimetype','application/pdf','size',128)
from p05_documents_observed where key='begin';

set local role authenticated;
select set_config('request.jwt.claim.sub','b2000000-0000-0000-0000-000000000001',true);
insert into p05_documents_observed values ('finalize',public.finalize_client_compliance_document_upload(
  (select (value->>'document_id')::uuid from p05_documents_observed where key='begin'),
  'p05-document-finalize-0001'
));
insert into p05_documents_observed values ('finalize-retry',public.finalize_client_compliance_document_upload(
  (select (value->>'document_id')::uuid from p05_documents_observed where key='begin'),
  'p05-document-finalize-0001'
));
reset role;
select is((select value->>'status' from p05_documents_observed where key='finalize'),
  'PENDING_REVIEW','finalization checks the real Storage object before review');
select is((select value from p05_documents_observed where key='finalize-retry'),
  (select value from p05_documents_observed where key='finalize'),'finalization retry is idempotent');
select is((select detected_size_bytes from public.client_compliance_documents
  where id=(select (value->>'document_id')::uuid from p05_documents_observed where key='begin')),128::bigint,
  'trusted Storage size is retained as metadata');

set local role authenticated;
select set_config('request.jwt.claim.sub','b2000000-0000-0000-0000-000000000002',true);
insert into p05_documents_observed values ('tenant-b-count',jsonb_build_object('count',(
  select count(*) from public.client_compliance_documents
  where organization_id='b2010000-0000-0000-0000-000000000001'
)));
reset role;
select is((select (value->>'count')::bigint from p05_documents_observed where key='tenant-b-count'),
  0::bigint,'document metadata RLS prevents tenant escape');
select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','b2000000-0000-0000-0000-000000000001',true);
    update public.client_compliance_documents set status='VERIFIED'$$,
  '42501',null,'authenticated owners cannot bypass document RPC transitions');
reset role;

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','b2000000-0000-0000-0000-000000000001',true);
    select public.review_client_compliance_document(
      (select (value->>'document_id')::uuid from p05_documents_observed where key='begin'),
      'VERIFIED',repeat('a',64),null,null,'owner-review-document-key'
    )$$,'42501','CENTRAL_COMPLIANCE_APPROVAL_REQUIRED','a tenant owner cannot self-verify a document');
reset role;
select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','b2000000-0000-0000-0000-000000000003',true);
    select set_config('request.jwt.claims','{"sub":"b2000000-0000-0000-0000-000000000003","role":"authenticated","aal":"aal1"}',true);
    select public.review_client_compliance_document(
      (select (value->>'document_id')::uuid from p05_documents_observed where key='begin'),
      'VERIFIED',repeat('a',64),null,null,'aal1-review-document-key'
    )$$,'42501','CENTRAL_COMPLIANCE_APPROVAL_REQUIRED','central review fails closed without required MFA');
reset role;
select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','b2000000-0000-0000-0000-000000000003',true);
    select set_config('request.jwt.claims','{"sub":"b2000000-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2"}',true);
    select public.review_client_compliance_document(
      (select (value->>'document_id')::uuid from p05_documents_observed where key='begin'),
      'VERIFIED',repeat('f',64),null,'Scanner clean','wrong-hash-review-key'
    )$$,'22000','DOCUMENT_HASH_MISMATCH','review cannot attest a different content hash');
reset role;

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into p05_documents_observed values ('scan',public.record_client_document_scan_result(
  (select (value->>'document_id')::uuid from p05_documents_observed where key='begin'),
  'CLEAN','DEMO_SCANNER','1.0',repeat('a',64),'application/pdf',128,'{}'::jsonb,
  'p05-document-scan-0001'
));
insert into p05_documents_observed values ('scan-retry',public.record_client_document_scan_result(
  (select (value->>'document_id')::uuid from p05_documents_observed where key='begin'),
  'CLEAN','DEMO_SCANNER','1.0',repeat('a',64),'application/pdf',128,'{}'::jsonb,
  'p05-document-scan-0001'
));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b2000000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"b2000000-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2"}',true);
insert into p05_documents_observed values ('review',public.review_client_compliance_document(
  (select (value->>'document_id')::uuid from p05_documents_observed where key='begin'),
  'VERIFIED',repeat('a',64),null,'Scanner antivirus propre','p05-document-review-0001'
));
insert into p05_documents_observed values ('review-retry',public.review_client_compliance_document(
  (select (value->>'document_id')::uuid from p05_documents_observed where key='begin'),
  'VERIFIED',repeat('a',64),null,'Scanner antivirus propre','p05-document-review-0001'
));
reset role;
select is((select value->>'result' from p05_documents_observed where key='scan'),'CLEAN',
  'a structured CLEAN scan result is recorded before review');
select is((select value from p05_documents_observed where key='scan-retry'),
  (select value from p05_documents_observed where key='scan'),'scan recording retry is idempotent');
select is((select count(*) from private.client_document_scan_results
  where document_id=(select (value->>'document_id')::uuid from p05_documents_observed where key='begin')),1::bigint,
  'scan evidence is append-only and not duplicated');
select is((select count(*) from public.event_outbox where event_type='ClientDocumentScanCleanV1'
  and aggregate_id=(select value->>'document_id' from p05_documents_observed where key='begin')),
  1::bigint,'the CLEAN scan emits one durable event');
select is((select value->>'status' from p05_documents_observed where key='review'),
  'VERIFIED','an MFA-authenticated compliance reviewer verifies matching content');
select is((select value from p05_documents_observed where key='review-retry'),
  (select value from p05_documents_observed where key='review'),'review retry is idempotent');
select is((select count(*) from private.client_compliance_document_reviews
  where document_id=(select (value->>'document_id')::uuid from p05_documents_observed where key='begin')),1::bigint,
  'a successful review creates one append-only private decision');
select is((select count(*) from public.client_compliance_evidence
  where compliance_case_id='b2030000-0000-0000-0000-000000000001'
    and evidence_type='REGISTRATION_DOCUMENT' and review_status='VERIFIED'),
  1::bigint,'verified document feeds the existing compliance verification gate');
select is((select count(*) from public.audit_events where action='client.document.upload.finalized'
  and resource_id=(select value->>'document_id' from p05_documents_observed where key='begin')),
  1::bigint,'finalization is audited exactly once');
select is((select count(*) from public.event_outbox where event_type='DocumentUploadedV1'
  and aggregate_id=(select value->>'document_id' from p05_documents_observed where key='begin')),
  1::bigint,'finalization emits one durable DocumentUploaded event');
select is((select count(*) from public.event_outbox where event_type='ClientDocumentVerifiedV1'
  and aggregate_id=(select value->>'document_id' from p05_documents_observed where key='begin')),
  1::bigint,'review emits one durable outcome event');
select ok(not exists (
  select 1 from information_schema.columns
  where table_schema in ('public','private')
    and table_name in ('client_compliance_documents','client_compliance_document_reviews')
    and data_type='bytea'
),'no compliance table stores binary payloads');
select ok(not has_function_privilege('anon',
  'public.begin_client_compliance_document_upload(uuid,text,text,text,date,date,text,text,bigint,text,text,uuid)','EXECUTE'),
  'anonymous actors have no upload reservation RPC access');
select ok(has_function_privilege('authenticated',
  'public.finalize_client_compliance_document_upload(uuid,text,uuid)','EXECUTE'),
  'authenticated users receive only the guarded finalization RPC surface');

select * from finish();
rollback;
