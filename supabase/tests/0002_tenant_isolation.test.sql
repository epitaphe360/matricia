begin;
set local search_path = public, extensions;
select plan(4);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','tenant-a@example.invalid','',now(),'{}','{}',now(),now()),
('20000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','tenant-b@example.invalid','',now(),'{}','{}',now(),now());

insert into public.organizations (id, legal_name, display_name, status, created_by) values
('a0000000-0000-0000-0000-000000000001','Tenant A SARL','Tenant A','ACTIVE','10000000-0000-0000-0000-000000000001'),
('b0000000-0000-0000-0000-000000000002','Tenant B SARL','Tenant B','ACTIVE','20000000-0000-0000-0000-000000000002');
insert into public.organization_memberships (organization_id,user_id,status,activated_at) values
('a0000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','ACTIVE',now()),
('b0000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','ACTIVE',now());

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select is((select count(*) from public.organizations),1::bigint,'tenant A sees one organization');
select is((select id from public.organizations),'a0000000-0000-0000-0000-000000000001'::uuid,'tenant A sees only itself');
select is((select count(*) from public.organization_memberships),1::bigint,'tenant A cannot enumerate tenant B memberships');
select is((select count(*) from public.financial_journals where organization_id='b0000000-0000-0000-0000-000000000002'),0::bigint,'tenant A cannot see tenant B finance');
reset role;

select * from finish();
rollback;
