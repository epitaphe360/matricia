begin;
set local search_path=public,extensions;
select plan(9);

select has_function('public','list_provider_quote_version_amounts',array['uuid','uuid[]'],'exact Provider quote projection exists');
select ok((select not p.prosecdef and p.provolatile='s' and p.proconfig::text like '%search_path=pg_catalog%'
  and pg_get_function_result(p.oid) like '%subtotal_minor text%tax_minor text%total_minor text%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='list_provider_quote_version_amounts'),'projection is stable SECURITY INVOKER with fixed path and text amounts');
select ok(has_function_privilege('authenticated','public.list_provider_quote_version_amounts(uuid,uuid[])','EXECUTE')
  and not has_function_privilege('anon','public.list_provider_quote_version_amounts(uuid,uuid[])','EXECUTE')
  and not has_function_privilege('service_role','public.list_provider_quote_version_amounts(uuid,uuid[])','EXECUTE'),'projection ACL is least privilege');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
 ('fb010000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p23-provider-a@example.invalid','',now(),'{}','{}',now(),now()),
 ('fb010000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p23-provider-b@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by) values
 ('fb011000-0000-4000-8000-000000000001','Provider exact A','Provider exact A','ACTIVE','fb010000-0000-4000-8000-000000000001'),
 ('fb011000-0000-4000-8000-000000000002','Provider exact B','Provider exact B','ACTIVE','fb010000-0000-4000-8000-000000000002');
insert into public.organization_memberships(id,organization_id,user_id,status) values
 ('fb012000-0000-4000-8000-000000000001','fb011000-0000-4000-8000-000000000001','fb010000-0000-4000-8000-000000000001','ACTIVE'),
 ('fb012000-0000-4000-8000-000000000002','fb011000-0000-4000-8000-000000000002','fb010000-0000-4000-8000-000000000002','ACTIVE');
insert into public.organization_member_roles(membership_id,role_code) values
 ('fb012000-0000-4000-8000-000000000001','PROVIDER_SALES'),
 ('fb012000-0000-4000-8000-000000000002','PROVIDER_SALES');

set local session_replication_role=replica;
insert into public.service_requests(id,client_organization_id,library_id,service_id,status,created_by) values
 ('fb017000-0000-4000-8000-000000000001','fb011000-0000-4000-8000-000000000001','fb018000-0000-4000-8000-000000000001','fb019000-0000-4000-8000-000000000001','DRAFT','fb010000-0000-4000-8000-000000000001'),
 ('fb017000-0000-4000-8000-000000000002','fb011000-0000-4000-8000-000000000002','fb018000-0000-4000-8000-000000000002','fb019000-0000-4000-8000-000000000002','DRAFT','fb010000-0000-4000-8000-000000000002');
insert into public.rfqs(id,request_id,request_version_id,matching_run_id,deadline,status,invited_count,opened_by) values
 ('fb014000-0000-4000-8000-000000000001','fb017000-0000-4000-8000-000000000001','fb021000-0000-4000-8000-000000000001','fb020000-0000-4000-8000-000000000001',now()+interval'7 days','OPEN',1,'fb010000-0000-4000-8000-000000000001'),
 ('fb014000-0000-4000-8000-000000000002','fb017000-0000-4000-8000-000000000002','fb021000-0000-4000-8000-000000000002','fb020000-0000-4000-8000-000000000002',now()+interval'7 days','OPEN',1,'fb010000-0000-4000-8000-000000000002');
insert into public.quotes(id,rfq_id,rfq_provider_id,provider_organization_id,status,created_by) values
 ('fb013000-0000-4000-8000-000000000001','fb014000-0000-4000-8000-000000000001','fb015000-0000-4000-8000-000000000001','fb011000-0000-4000-8000-000000000001','DRAFT','fb010000-0000-4000-8000-000000000001'),
 ('fb013000-0000-4000-8000-000000000002','fb014000-0000-4000-8000-000000000002','fb015000-0000-4000-8000-000000000002','fb011000-0000-4000-8000-000000000002','DRAFT','fb010000-0000-4000-8000-000000000002');
insert into public.quote_versions(id,quote_id,rfq_id,provider_organization_id,version_number,lifecycle_status,change_reason,currency,solution_fr,deliverables,inclusions,exclusions,prerequisites,warranty_fr,correction_terms_fr,sla,proposed_start_date,duration_days,valid_until,subtotal_minor,tax_minor,total_minor,recurring_subtotal_minor,calculation_basis,content_hash,created_by) values
 ('fb016000-0000-4000-8000-000000000001','fb013000-0000-4000-8000-000000000001','fb014000-0000-4000-8000-000000000001','fb011000-0000-4000-8000-000000000001',1,'DRAFT','Projection exacte','MAD','Solution exacte','["Livrable"]','[]','[]','[]','Garantie','Corrections','{}','2026-10-15',10,now()+interval'30 days',900719925474099300,180143985094819860,1080863910568919160,0,'{"money":"MINOR_UNITS"}',repeat('1',64),'fb010000-0000-4000-8000-000000000001'),
 ('fb016000-0000-4000-8000-000000000002','fb013000-0000-4000-8000-000000000002','fb014000-0000-4000-8000-000000000002','fb011000-0000-4000-8000-000000000002',1,'DRAFT','Projection étrangère','MAD','Solution étrangère','["Livrable"]','[]','[]','[]','Garantie','Corrections','{}','2026-10-15',10,now()+interval'30 days',10000,2000,12000,0,'{"money":"MINOR_UNITS"}',repeat('2',64),'fb010000-0000-4000-8000-000000000002');
set local session_replication_role=origin;

create temporary table projected(scope text,id uuid,version_number integer,currency text,subtotal_minor text,tax_minor text,total_minor text);
grant select,insert on projected to authenticated;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"fb010000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
insert into projected select 'OWN',value.* from public.list_provider_quote_version_amounts('fb011000-0000-4000-8000-000000000001',array['fb016000-0000-4000-8000-000000000001']::uuid[]) value;
insert into projected select 'FOREIGN_ORG',value.* from public.list_provider_quote_version_amounts('fb011000-0000-4000-8000-000000000002',array['fb016000-0000-4000-8000-000000000002']::uuid[]) value;
insert into projected select 'FOREIGN_ID',value.* from public.list_provider_quote_version_amounts('fb011000-0000-4000-8000-000000000001',array['fb016000-0000-4000-8000-000000000002']::uuid[]) value;
insert into projected select 'OVERSIZED',value.* from public.list_provider_quote_version_amounts('fb011000-0000-4000-8000-000000000001',array_fill('fb016000-0000-4000-8000-000000000001'::uuid,array[101])) value;
reset role;

select is((select count(*)::integer from projected where scope='OWN'),1,'own Provider projection is allowed');
select is((select subtotal_minor from projected where scope='OWN'),'900719925474099300','subtotal beyond Number.MAX_SAFE_INTEGER remains exact text');
select is((select tax_minor from projected where scope='OWN'),'180143985094819860','tax remains exact text');
select is((select total_minor from projected where scope='OWN'),'1080863910568919160','total remains exact text');
select is((select count(*)::integer from projected where scope in('FOREIGN_ORG','FOREIGN_ID')),0,'cross-organization projection is denied');
select is((select count(*)::integer from projected where scope='OVERSIZED'),0,'oversized identifier input fails closed');

select * from finish();
rollback;
