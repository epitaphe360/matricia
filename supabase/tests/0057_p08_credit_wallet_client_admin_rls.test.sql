begin;
set local search_path=public,extensions;
select plan(14);

select ok((select qual like'%CLIENT_ADMIN%'and qual like'%has_org_role%'and qual not like'%is_active_org_member%'from pg_policies where schemaname='public'and tablename='credit_wallets'and policyname='credit_wallets_tenant_read'),'wallet policy grants role-scoped Client Admin reads');
select ok((select qual like'%CLIENT_ADMIN%'and qual like'%has_org_role%'and qual not like'%is_active_org_member%'from pg_policies where schemaname='public'and tablename='credit_ledger_entries'and policyname='credit_entries_tenant_read'),'ledger policy grants role-scoped Client Admin reads');
select ok(not has_table_privilege('authenticated','public.credit_wallets','INSERT')and not has_table_privilege('authenticated','public.credit_wallets','UPDATE')and not has_table_privilege('authenticated','public.credit_ledger_entries','INSERT'),'hotfix adds no wallet or ledger mutation privilege');
select ok(has_table_privilege('authenticated','public.credit_wallet_balances','SELECT'),'authenticated users retain access to the security-invoker balance view');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values
('f5700000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p08-admin-a@example.invalid','',now(),'{}','{}',now(),now()),
('f5700000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p08-admin-b@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)values
('f5710000-0000-4000-8000-000000000001','P08 Tenant A SARL','P08 Tenant A','ACTIVE','f5700000-0000-4000-8000-000000000001'),
('f5710000-0000-4000-8000-000000000002','P08 Tenant B SARL','P08 Tenant B','ACTIVE','f5700000-0000-4000-8000-000000000002');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at)values
('f5720000-0000-4000-8000-000000000001','f5710000-0000-4000-8000-000000000001','f5700000-0000-4000-8000-000000000001','ACTIVE',now()),
('f5720000-0000-4000-8000-000000000002','f5710000-0000-4000-8000-000000000002','f5700000-0000-4000-8000-000000000002','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code)values
('f5720000-0000-4000-8000-000000000001','CLIENT_ADMIN'),
('f5720000-0000-4000-8000-000000000002','CLIENT_ADMIN');
insert into public.credit_wallets(id,organization_id,wallet_type)values
('f5730000-0000-4000-8000-000000000001','f5710000-0000-4000-8000-000000000001','CLIENT'),
('f5730000-0000-4000-8000-000000000002','f5710000-0000-4000-8000-000000000002','CLIENT');
insert into public.credit_ledger_entries(organization_id,wallet_id,entry_type,quantity,idempotency_scope,idempotency_key,correlation_id,reference_type,reference_id,created_by)values
('f5710000-0000-4000-8000-000000000001','f5730000-0000-4000-8000-000000000001','GRANT',17,'p08.rls.fixture','tenant-a','f5740000-0000-4000-8000-000000000001','TEST','A','f5700000-0000-4000-8000-000000000001'),
('f5710000-0000-4000-8000-000000000002','f5730000-0000-4000-8000-000000000002','GRANT',29,'p08.rls.fixture','tenant-b','f5740000-0000-4000-8000-000000000002','TEST','B','f5700000-0000-4000-8000-000000000002');

create temporary table p08_admin_rls_observed(key text primary key,value text);grant select,insert on p08_admin_rls_observed to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','f5700000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"f5700000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
insert into p08_admin_rls_observed values
('wallet_total',(select count(*)::text from public.credit_wallets)),
('wallet_own',(select count(*)::text from public.credit_wallets where organization_id='f5710000-0000-4000-8000-000000000001')),
('wallet_other',(select count(*)::text from public.credit_wallets where organization_id='f5710000-0000-4000-8000-000000000002')),
('entry_total',(select count(*)::text from public.credit_ledger_entries)),
('entry_own',(select count(*)::text from public.credit_ledger_entries where organization_id='f5710000-0000-4000-8000-000000000001')),
('entry_other',(select count(*)::text from public.credit_ledger_entries where organization_id='f5710000-0000-4000-8000-000000000002')),
('balance_total',(select count(*)::text from public.credit_wallet_balances)),
('balance_own',(select balance::text from public.credit_wallet_balances where organization_id='f5710000-0000-4000-8000-000000000001')),
('balance_other',(select count(*)::text from public.credit_wallet_balances where organization_id='f5710000-0000-4000-8000-000000000002'));
reset role;

select is((select value::bigint from p08_admin_rls_observed where key='wallet_total'),1::bigint,'Client Admin sees exactly one tenant wallet');
select is((select value::bigint from p08_admin_rls_observed where key='wallet_own'),1::bigint,'Client Admin can read its wallet');
select is((select value::bigint from p08_admin_rls_observed where key='wallet_other'),0::bigint,'Client Admin cannot read another tenant wallet');
select is((select value::bigint from p08_admin_rls_observed where key='entry_total'),1::bigint,'Client Admin sees exactly one tenant ledger');
select is((select value::bigint from p08_admin_rls_observed where key='entry_own'),1::bigint,'Client Admin can read its ledger entries');
select is((select value::bigint from p08_admin_rls_observed where key='entry_other'),0::bigint,'Client Admin cannot read another tenant ledger');
select is((select value::bigint from p08_admin_rls_observed where key='balance_total'),1::bigint,'security-invoker balance view preserves wallet and ledger isolation');
select is((select value::bigint from p08_admin_rls_observed where key='balance_own'),17::bigint,'Client Admin reads its exact derived balance');
select is((select value::bigint from p08_admin_rls_observed where key='balance_other'),0::bigint,'Client Admin cannot read another tenant balance');
select ok((select count(*)=2 from pg_policies where schemaname='public'and tablename=any(array['credit_wallets','credit_ledger_entries'])and roles='{authenticated}'),'only the two authenticated read policies cover wallet and ledger');

select*from finish();rollback;
