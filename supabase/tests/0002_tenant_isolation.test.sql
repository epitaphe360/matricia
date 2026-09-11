begin;
set local search_path = public, extensions;
select plan(5);

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
insert into public.organization_member_roles (membership_id,role_code)
select id,'CLIENT_ACCOUNTING' from public.organization_memberships;
insert into public.financial_accounts (id,organization_id,code,name,account_type) values
('a1000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','CASH','Cash','ASSET'),
('a2000000-0000-0000-0000-000000000002','a0000000-0000-0000-0000-000000000001','REVENUE','Revenue','REVENUE'),
('b1000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000002','CASH','Cash','ASSET'),
('b2000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000002','REVENUE','Revenue','REVENUE');
insert into public.financial_journals (id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,correlation_id,effective_at,description,created_by) values
('a3000000-0000-0000-0000-000000000003','a0000000-0000-0000-0000-000000000001','TEST','MAD','tenant.test','tenant-a-key','a4000000-0000-0000-0000-000000000004',now(),'Tenant A journal','10000000-0000-0000-0000-000000000001'),
('b3000000-0000-0000-0000-000000000003','b0000000-0000-0000-0000-000000000002','TEST','MAD','tenant.test','tenant-b-key','b4000000-0000-0000-0000-000000000004',now(),'Tenant B journal','20000000-0000-0000-0000-000000000002');
insert into public.financial_entries (organization_id,journal_id,account_id,direction,amount_minor,currency) values
('a0000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000001','DEBIT',100,'MAD'),
('a0000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000003','a2000000-0000-0000-0000-000000000002','CREDIT',100,'MAD'),
('b0000000-0000-0000-0000-000000000002','b3000000-0000-0000-0000-000000000003','b1000000-0000-0000-0000-000000000001','DEBIT',100,'MAD'),
('b0000000-0000-0000-0000-000000000002','b3000000-0000-0000-0000-000000000003','b2000000-0000-0000-0000-000000000002','CREDIT',100,'MAD');

create temporary table observed (key text primary key,value text);
grant insert,select on table observed to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
insert into observed values
('organization_count',(select count(*)::text from public.organizations)),
('organization_id',(select id::text from public.organizations)),
('membership_count',(select count(*)::text from public.organization_memberships)),
('tenant_a_finance_count',(select count(*)::text from public.financial_journals where organization_id='a0000000-0000-0000-0000-000000000001')),
('tenant_b_finance_count',(select count(*)::text from public.financial_journals where organization_id='b0000000-0000-0000-0000-000000000002'));
reset role;

select is((select value::bigint from observed where key='organization_count'),1::bigint,'tenant A sees one organization');
select is((select value::uuid from observed where key='organization_id'),'a0000000-0000-0000-0000-000000000001'::uuid,'tenant A sees only itself');
select is((select value::bigint from observed where key='membership_count'),1::bigint,'tenant A cannot enumerate tenant B memberships');
select is((select value::bigint from observed where key='tenant_a_finance_count'),1::bigint,'tenant A accounting can read its own finance');
select is((select value::bigint from observed where key='tenant_b_finance_count'),0::bigint,'tenant A cannot see tenant B finance');

select * from finish();
rollback;
