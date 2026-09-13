begin;
set local search_path=public,extensions;
select plan(29);

select has_table('public','client_project_contracts','project-contract relation exists');
select ok((select relrowsecurity from pg_class where oid='public.client_project_contracts'::regclass),'project-contract relation has RLS');
select ok((select count(*)=1 from pg_policies where schemaname='public' and tablename='client_project_contracts' and policyname='client_project_contracts_read'),'relation has one tenant read policy');
select ok(has_table_privilege('authenticated','public.client_project_contracts','SELECT') and not has_table_privilege('anon','public.client_project_contracts','SELECT'),'relation ACL is least privilege');
select ok(exists(select 1 from pg_trigger where tgname='client_project_contracts_immutable' and not tgisinternal),'relation is immutable');
select ok((select p.prosecdef and p.proconfig::text like '%search_path=%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='link_contract_to_client_project'),'link command is security-definer with fixed search path');
select ok(has_function_privilege('authenticated','public.link_contract_to_client_project(uuid,uuid,text,uuid)','EXECUTE') and not has_function_privilege('anon','public.link_contract_to_client_project(uuid,uuid,text,uuid)','EXECUTE'),'link command ACL is restricted');
select has_view('public','client_central_calendar','central calendar view exists');
select ok(has_table_privilege('authenticated','public.client_central_calendar','SELECT') and not has_table_privilege('anon','public.client_central_calendar','SELECT'),'central calendar view denies anon');
select has_table('public','client_invoice_calendar_items','minimal client invoice projection exists');
select ok((select relrowsecurity from pg_class where oid='public.client_invoice_calendar_items'::regclass),'minimal invoice projection has RLS');
select ok(not has_column_privilege('authenticated','public.client_invoice_calendar_items','source_invoice_id','SELECT'),'provider invoice identifier is never exposed to Client');
select ok((select p.prosecdef and p.proconfig::text like '%search_path=%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='client_central_calendar_items'),'calendar projection enforces tenant scope in a fixed-path function');
select ok((select pg_get_functiondef(p.oid) like '%RFQ_DEADLINE%' and pg_get_functiondef(p.oid) like '%QUOTE_VALIDITY%' and pg_get_functiondef(p.oid) like '%INVOICE_DUE%' and pg_get_functiondef(p.oid) like '%DOCUMENT_EXPIRY%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='client_central_calendar_items'),'calendar projects quote, invoice and document deadlines');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('fe100000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','mf011-a@example.invalid','',now(),'{}','{}',now(),now()),
('fe100000-0000-4000-8000-000000000002','00000000-0000-0000-8000-000000000000','authenticated','authenticated','mf011-b@example.invalid','',now(),'{}','{}',now(),now()),
('fe100000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','mf011-viewer@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by) values
('fe110000-0000-4000-8000-000000000001','MF011 A','MF011 A','ACTIVE','fe100000-0000-4000-8000-000000000001'),
('fe110000-0000-4000-8000-000000000002','MF011 B','MF011 B','ACTIVE','fe100000-0000-4000-8000-000000000002');
insert into public.organization_memberships(id,organization_id,user_id,status) values
('fe120000-0000-4000-8000-000000000001','fe110000-0000-4000-8000-000000000001','fe100000-0000-4000-8000-000000000001','ACTIVE'),
('fe120000-0000-4000-8000-000000000002','fe110000-0000-4000-8000-000000000002','fe100000-0000-4000-8000-000000000002','ACTIVE'),
('fe120000-0000-4000-8000-000000000003','fe110000-0000-4000-8000-000000000001','fe100000-0000-4000-8000-000000000003','ACTIVE');
insert into public.organization_member_roles(membership_id,role_code) values
('fe120000-0000-4000-8000-000000000001','CLIENT_OWNER'),('fe120000-0000-4000-8000-000000000002','CLIENT_OWNER'),('fe120000-0000-4000-8000-000000000003','CLIENT_VIEWER');
insert into public.client_projects(id,organization_id,project_code,status,created_by) values
('fe130000-0000-4000-8000-000000000001','fe110000-0000-4000-8000-000000000001','PROJECT_A','DRAFT','fe100000-0000-4000-8000-000000000001'),
('fe130000-0000-4000-8000-000000000002','fe110000-0000-4000-8000-000000000002','PROJECT_B','DRAFT','fe100000-0000-4000-8000-000000000002');
insert into public.contracts(id,client_organization_id,provider_organization_id,status,created_by) values
('fe140000-0000-4000-8000-000000000001','fe110000-0000-4000-8000-000000000001','fe110000-0000-4000-8000-000000000002','ACTIVE','fe100000-0000-4000-8000-000000000001'),
('fe140000-0000-4000-8000-000000000002','fe110000-0000-4000-8000-000000000002','fe110000-0000-4000-8000-000000000001','ACTIVE','fe100000-0000-4000-8000-000000000002');

set local session_replication_role=replica;
insert into public.service_requests(id,client_organization_id,library_id,service_id,status,created_by)
values('fe150000-0000-4000-8000-000000000001','fe110000-0000-4000-8000-000000000001','fe160000-0000-4000-8000-000000000001','fe170000-0000-4000-8000-000000000001','RFQ_OPEN','fe100000-0000-4000-8000-000000000001');
insert into public.rfqs(id,request_id,request_version_id,matching_run_id,deadline,status,invited_count,opened_by)
values('fe180000-0000-4000-8000-000000000001','fe150000-0000-4000-8000-000000000001','fe190000-0000-4000-8000-000000000001','fe200000-0000-4000-8000-000000000001','2026-12-15 14:30:00+00','OPEN',0,'fe100000-0000-4000-8000-000000000001');
insert into public.client_compliance_documents(id,compliance_case_id,organization_id,document_type,version,policy_version_id,document_number,issuer,issued_on,expires_on,original_file_name,file_extension,declared_mime_type,declared_size_bytes,declared_sha256,storage_object_path,status,created_by)
values('fe210000-0000-4000-8000-000000000001','fe220000-0000-4000-8000-000000000001','fe110000-0000-4000-8000-000000000001','TAX_DOCUMENT',1,'fe230000-0000-4000-8000-000000000001','TAX-1','DGI','2026-01-01','2026-12-31','tax-proof.pdf','pdf','application/pdf',100,repeat('a',64),'fe110000-0000-4000-8000-000000000001/tax-proof.pdf','UPLOAD_PENDING','fe100000-0000-4000-8000-000000000001');
insert into public.missions(id,contract_id,contract_version_id,client_organization_id,provider_organization_id,status,created_by)
values('fe250000-0000-4000-8000-000000000001','fe140000-0000-4000-8000-000000000001','fe260000-0000-4000-8000-000000000001','fe110000-0000-4000-8000-000000000001','fe110000-0000-4000-8000-000000000002','PLANNED','fe100000-0000-4000-8000-000000000001');
insert into public.provider_payable_events(id,provider_organization_id,client_organization_id,mission_id,contract_version_id,event_type,occurred_on,currency,gross_amount_minor,commission_basis_points,commission_amount_minor,tax_rule_version_id,tax_rate_basis_points,tax_amount_minor,commission_rule_snapshot,client_receipt_reference,proof_hash,correlation_id,created_by)
values('fe270000-0000-4000-8000-000000000001','fe110000-0000-4000-8000-000000000002','fe110000-0000-4000-8000-000000000001','fe250000-0000-4000-8000-000000000001','fe260000-0000-4000-8000-000000000001','CLIENT_RECEIPT_CONFIRMED','2026-11-01','MAD',10000,1000,1000,'fe280000-0000-4000-8000-000000000001',2000,200,'{}','MF011-RECEIPT',repeat('b',64),'fe290000-0000-4000-8000-000000000001','fe100000-0000-4000-8000-000000000002');
insert into public.provider_statement_lines(provider_organization_id,statement_id,payable_event_id,subtotal_minor,tax_minor,total_minor)
values('fe110000-0000-4000-8000-000000000002','fe300000-0000-4000-8000-000000000001','fe270000-0000-4000-8000-000000000001',1000,200,1200);
insert into public.provider_invoices(id,provider_organization_id,statement_id,invoice_number,currency,subtotal_minor,tax_minor,total_minor,issued_on,due_on,tax_rule_snapshot,document_hash,journal_id,correlation_id,created_by)
values('fe310000-0000-4000-8000-000000000001','fe110000-0000-4000-8000-000000000002','fe300000-0000-4000-8000-000000000001','PROVIDER-PRIVATE-1','MAD',1000,200,1200,'2026-12-01','2027-01-15','[]',repeat('c',64),'fe320000-0000-4000-8000-000000000001','fe330000-0000-4000-8000-000000000001','fe100000-0000-4000-8000-000000000002');
set local session_replication_role=origin;

create temporary table mf011_observed(key text primary key,value text);
grant insert,select on table mf011_observed to authenticated;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"fe100000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into mf011_observed values('link',(public.link_contract_to_client_project('fe130000-0000-4000-8000-000000000001','fe140000-0000-4000-8000-000000000001','mf011-link-contract','fe240000-0000-4000-8000-000000000001')->>'outcome'));
insert into mf011_observed values
('links',(select count(*)::text from public.client_project_contracts)),
('rfq',(select count(*)::text from public.client_central_calendar where source_kind='RFQ_DEADLINE' and starts_at='2026-12-15 14:30:00+00')),
('document',(select count(*)::text from public.client_central_calendar where source_kind='DOCUMENT_EXPIRY' and occurs_on='2026-12-31' and all_day)),
('invoice',(select count(*)::text from public.client_central_calendar where source_kind='INVOICE_DUE' and occurs_on='2027-01-15' and all_day)),
('provider-invoices',(select count(*)::text from public.provider_invoices));
select public.link_contract_to_client_project('fe130000-0000-4000-8000-000000000001','fe140000-0000-4000-8000-000000000001','mf011-link-contract','fe240000-0000-4000-8000-000000000001');
insert into mf011_observed values('replay-links',(select count(*)::text from public.client_project_contracts));
select set_config('request.jwt.claims','{"sub":"fe100000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);
insert into mf011_observed values('tenant-b-links',(select count(*)::text from public.client_project_contracts)),('tenant-b-rfq',(select count(*)::text from public.client_central_calendar where source_kind='RFQ_DEADLINE')),('tenant-b-document',(select count(*)::text from public.client_central_calendar where source_kind='DOCUMENT_EXPIRY')),('tenant-b-invoice',(select count(*)::text from public.client_central_calendar where source_kind='INVOICE_DUE'));
reset role;

select is((select value from mf011_observed where key='link'),'CLIENT_PROJECT_CONTRACT_LINKED','client links its contract to its project');
select is((select value from mf011_observed where key='links'),'1','client sees its linked contract');
select is((select value from mf011_observed where key='replay-links'),'1','idempotent replay creates no duplicate');
select is((select value from mf011_observed where key='rfq'),'1','RFQ deadline is projected at the exact timestamp');
select is((select value from mf011_observed where key='document'),'1','document expiration preserves the exact all-day date');
select is((select value from mf011_observed where key='invoice'),'1','automatic Client projection exposes only the exact invoice due date');
select is((select value from mf011_observed where key='provider-invoices'),'0','Client cannot read the underlying Provider invoice');
select is((select value from mf011_observed where key='tenant-b-links'),'0','other tenant cannot read project-contract link');
select is((select value from mf011_observed where key='tenant-b-rfq'),'0','other tenant cannot read RFQ projection');
select is((select value from mf011_observed where key='tenant-b-document'),'0','other tenant cannot read document projection');
select is((select value from mf011_observed where key='tenant-b-invoice'),'0','other tenant cannot read invoice projection');
select ok((select count(*)=1 from public.audit_events where action='client.project_contract.linked'),'link emits audit evidence');
select ok((select count(*)=1 from public.event_outbox where event_type='ClientProjectContractLinkedV1'),'link emits one Outbox event');
select set_config('request.jwt.claims','{"sub":"fe100000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
select throws_ok($$select public.link_contract_to_client_project('fe130000-0000-4000-8000-000000000001','fe140000-0000-4000-8000-000000000002','mf011-foreign-contract','fe240000-0000-4000-8000-000000000002')$$,'22023','INVALID_CLIENT_PROJECT_CONTRACT','cross-tenant contract spoof is denied');
select set_config('request.jwt.claims','{"sub":"fe100000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal2"}',true);
select throws_ok($$select public.link_contract_to_client_project('fe130000-0000-4000-8000-000000000001','fe140000-0000-4000-8000-000000000001','mf011-viewer-denied','fe240000-0000-4000-8000-000000000003')$$,'42501','CLIENT_PROJECT_CONTRACT_LINK_DENIED','read-only Client viewer cannot link a contract');

select * from finish();
rollback;
