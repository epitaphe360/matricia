begin;
set local search_path=public,extensions;
select plan(7);

select ok(has_function_privilege('authenticated','private.assistance_role_access(uuid,text,uuid)','EXECUTE'),'authenticated may evaluate the RLS role predicate');
select ok(not has_function_privilege('anon','private.assistance_role_access(uuid,text,uuid)','EXECUTE'),'anonymous role cannot execute the role predicate');
select ok(not has_function_privilege('service_role','private.assistance_role_access(uuid,text,uuid)','EXECUTE'),'service role receives no unnecessary helper grant');
select ok(not has_schema_privilege('authenticated','private','USAGE'),'authenticated receives no direct usage on private schema');
select ok((select prosecdef and proconfig::text like'%search_path=pg_catalog%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='assistance_role_access'),'role predicate remains security definer with fixed search path');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values
('a8600000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','manager-86@example.invalid','',now(),'{}','{}',now(),now()),
('a8600000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','viewer-86@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)values('b8600000-0000-4000-8000-000000000001','Assistance ACL Runtime','ACL Runtime','ACTIVE','a8600000-0000-4000-8000-000000000001');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at)values
('c8600000-0000-4000-8000-000000000001','b8600000-0000-4000-8000-000000000001','a8600000-0000-4000-8000-000000000001','ACTIVE',now()),
('c8600000-0000-4000-8000-000000000002','b8600000-0000-4000-8000-000000000001','a8600000-0000-4000-8000-000000000002','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code,granted_by)values
('c8600000-0000-4000-8000-000000000001','CLIENT_ADMIN','a8600000-0000-4000-8000-000000000001'),
('c8600000-0000-4000-8000-000000000002','CLIENT_VIEWER','a8600000-0000-4000-8000-000000000001');
insert into public.assistance_requests(id,organization_id,model_version_id,context_type,input_hash,created_by)values('d8600000-0000-4000-8000-000000000001','b8600000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','CONTEXTUAL_ASSISTANT',repeat('8',64),'a8600000-0000-4000-8000-000000000001');

create temporary table assistance_acl_observed(key text primary key,value boolean);grant select,insert on assistance_acl_observed to authenticated;
set local role authenticated;select set_config('request.jwt.claim.sub','a8600000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a8600000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into assistance_acl_observed values('manager_rls',exists(select 1 from public.assistance_requests where id='d8600000-0000-4000-8000-000000000001'));reset role;
select is((select value from assistance_acl_observed where key='manager_rls'),true,'manager RLS evaluation succeeds and reveals scoped row');
set local role authenticated;select set_config('request.jwt.claim.sub','a8600000-0000-4000-8000-000000000002',true);select set_config('request.jwt.claims','{"sub":"a8600000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);
insert into assistance_acl_observed values('viewer_rls',exists(select 1 from public.assistance_requests where id='d8600000-0000-4000-8000-000000000001'));reset role;
select is((select value from assistance_acl_observed where key='viewer_rls'),false,'viewer RLS evaluation returns no row without an ACL error');

select * from finish();rollback;
