begin;
set local search_path=public,extensions;
select plan(8);

select ok((select p.prosecdef and p.proconfig::text like '%search_path=%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='client_central_calendar_items'),'calendar function retains fixed-path security');
select ok((select pg_get_functiondef(p.oid) like '%left join public.client_project_contracts%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='client_central_calendar_items'),'mission projection preserves unlinked missions with a left join');
select ok(has_function_privilege('authenticated','public.client_central_calendar_items()','EXECUTE') and not has_function_privilege('anon','public.client_central_calendar_items()','EXECUTE'),'calendar function ACL remains restricted');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('ff100000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','mf021-client@example.invalid','',now(),'{}','{}',now(),now()),
('ff100000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','mf021-other@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by) values
('ff110000-0000-4000-8000-000000000001','MF021 Client','MF021 Client','ACTIVE','ff100000-0000-4000-8000-000000000001'),
('ff110000-0000-4000-8000-000000000002','MF021 Other','MF021 Other','ACTIVE','ff100000-0000-4000-8000-000000000002');
insert into public.organization_memberships(id,organization_id,user_id,status) values
('ff120000-0000-4000-8000-000000000001','ff110000-0000-4000-8000-000000000001','ff100000-0000-4000-8000-000000000001','ACTIVE'),
('ff120000-0000-4000-8000-000000000002','ff110000-0000-4000-8000-000000000002','ff100000-0000-4000-8000-000000000002','ACTIVE');
insert into public.organization_member_roles(membership_id,role_code) values
('ff120000-0000-4000-8000-000000000001','CLIENT_OWNER'),('ff120000-0000-4000-8000-000000000002','CLIENT_OWNER');
insert into public.client_projects(id,organization_id,project_code,status,created_by)
values('ff130000-0000-4000-8000-000000000001','ff110000-0000-4000-8000-000000000001','MISSION_PROJECT','ACTIVE','ff100000-0000-4000-8000-000000000001');
insert into public.contracts(id,client_organization_id,provider_organization_id,status,created_by) values
('ff140000-0000-4000-8000-000000000001','ff110000-0000-4000-8000-000000000001','ff110000-0000-4000-8000-000000000002','ACTIVE','ff100000-0000-4000-8000-000000000001'),
('ff140000-0000-4000-8000-000000000002','ff110000-0000-4000-8000-000000000001','ff110000-0000-4000-8000-000000000002','ACTIVE','ff100000-0000-4000-8000-000000000001');
insert into public.client_project_contracts(organization_id,project_id,contract_id,idempotency_key,correlation_id,linked_by)
values('ff110000-0000-4000-8000-000000000001','ff130000-0000-4000-8000-000000000001','ff140000-0000-4000-8000-000000000001','mf021-linked-contract','ff150000-0000-4000-8000-000000000001','ff100000-0000-4000-8000-000000000001');
set local session_replication_role=replica;
insert into public.missions(id,contract_id,contract_version_id,client_organization_id,provider_organization_id,status,created_by) values
('ff160000-0000-4000-8000-000000000001','ff140000-0000-4000-8000-000000000001','ff170000-0000-4000-8000-000000000001','ff110000-0000-4000-8000-000000000001','ff110000-0000-4000-8000-000000000002','PLANNED','ff100000-0000-4000-8000-000000000001'),
('ff160000-0000-4000-8000-000000000002','ff140000-0000-4000-8000-000000000002','ff170000-0000-4000-8000-000000000002','ff110000-0000-4000-8000-000000000001','ff110000-0000-4000-8000-000000000002','PLANNED','ff100000-0000-4000-8000-000000000001');
insert into public.mission_milestones(id,mission_id,milestone_key,title_fr,title_ar,sort_order,due_at,owner_organization_id,status) values
('ff180000-0000-4000-8000-000000000001','ff160000-0000-4000-8000-000000000001','LINKED','Jalon lié','مرحلة مرتبطة',1,'2027-02-01 10:00:00+00','ff110000-0000-4000-8000-000000000001','PENDING'),
('ff180000-0000-4000-8000-000000000002','ff160000-0000-4000-8000-000000000002','UNLINKED','Jalon sans projet','مرحلة دون مشروع',1,'2027-02-02 10:00:00+00','ff110000-0000-4000-8000-000000000001','PENDING');
set local session_replication_role=origin;

create temporary table mf021_observed(key text primary key,value text);
grant insert,select on table mf021_observed to authenticated;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"ff100000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into mf021_observed values
('all',(select count(*)::text from public.client_central_calendar where source_kind='MISSION_MILESTONE')),
('linked',(select count(*)::text from public.client_central_calendar where item_id='ff180000-0000-4000-8000-000000000001' and project_id='ff130000-0000-4000-8000-000000000001')),
('unlinked',(select count(*)::text from public.client_central_calendar where item_id='ff180000-0000-4000-8000-000000000002' and project_id is null));
select set_config('request.jwt.claims','{"sub":"ff100000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);
insert into mf021_observed values('other',(select count(*)::text from public.client_central_calendar where source_kind='MISSION_MILESTONE'));
reset role;

select is((select value from mf021_observed where key='all'),'2','client sees linked and historical unlinked mission milestones');
select is((select value from mf021_observed where key='linked'),'1','linked mission milestone carries the exact project');
select is((select value from mf021_observed where key='unlinked'),'1','unlinked mission milestone remains organization-level');
select is((select value from mf021_observed where key='other'),'0','other tenant cannot read either mission milestone');
select ok(has_table_privilege('authenticated','public.client_central_calendar','SELECT') and not has_table_privilege('anon','public.client_central_calendar','SELECT'),'calendar view remains unavailable to anon');

select * from finish();
rollback;
