begin;
set local search_path = public, extensions;
select plan(25);

insert into auth.users (
  id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
('70000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p03-a@example.invalid','',now(),'{}','{}',now(),now()),
('70000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p03-b@example.invalid','',now(),'{}','{}',now(),now()),
('70000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p03-platform@example.invalid','',now(),'{}','{}',now(),now());

insert into public.organizations (id,legal_name,display_name,status,created_by) values
('71000000-0000-0000-0000-000000000001','P03 Tenant A SARL','P03 Tenant A','ACTIVE','70000000-0000-0000-0000-000000000001'),
('71000000-0000-0000-0000-000000000002','P03 Tenant B SARL','P03 Tenant B','ACTIVE','70000000-0000-0000-0000-000000000002');
insert into public.organization_identifiers (id,organization_id,identifier_type,normalized_value,verification_status) values
('72000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001','RC','P03-RC-A','VERIFIED'),
('72000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000002','RC','P03-RC-B','VERIFIED');
insert into public.organization_memberships (id,organization_id,user_id,status,activated_at) values
('73000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001','ACTIVE',now()),
('73000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000002','70000000-0000-0000-0000-000000000002','ACTIVE',now());
insert into public.organization_member_roles (membership_id,role_code) values
('73000000-0000-0000-0000-000000000001','CLIENT_ACCOUNTING'),
('73000000-0000-0000-0000-000000000002','CLIENT_ACCOUNTING');
insert into public.platform_user_roles (user_id,role_code) values
('70000000-0000-0000-0000-000000000003','READ_ONLY_AUDITOR');

insert into public.financial_accounts (id,organization_id,code,name,account_type) values
('74000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001','P03-CASH-A','Cash A','ASSET'),
('74000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000001','P03-REV-A','Revenue A','REVENUE'),
('74000000-0000-0000-0000-000000000003','71000000-0000-0000-0000-000000000002','P03-CASH-B','Cash B','ASSET'),
('74000000-0000-0000-0000-000000000004','71000000-0000-0000-0000-000000000002','P03-REV-B','Revenue B','REVENUE');
insert into public.financial_journals (
  id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,
  correlation_id,effective_at,description,created_by
) values
('75000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001','TEST','MAD','p03.rls','journal-key-a','75100000-0000-0000-0000-000000000001',now(),'Tenant A','70000000-0000-0000-0000-000000000001'),
('75000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000002','TEST','MAD','p03.rls','journal-key-b','75100000-0000-0000-0000-000000000002',now(),'Tenant B','70000000-0000-0000-0000-000000000002');
insert into public.financial_entries (organization_id,journal_id,account_id,direction,amount_minor,currency) values
('71000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','DEBIT',100,'MAD'),
('71000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000002','CREDIT',100,'MAD'),
('71000000-0000-0000-0000-000000000002','75000000-0000-0000-0000-000000000002','74000000-0000-0000-0000-000000000003','DEBIT',200,'MAD'),
('71000000-0000-0000-0000-000000000002','75000000-0000-0000-0000-000000000002','74000000-0000-0000-0000-000000000004','CREDIT',200,'MAD');
set constraints financial_journal_balanced, financial_journal_not_empty immediate;
set constraints all deferred;

insert into public.credit_wallets (id,organization_id,wallet_type) values
('76000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001','CLIENT'),
('76000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000002','CLIENT');
insert into public.credit_ledger_entries (
  organization_id,wallet_id,entry_type,quantity,idempotency_scope,idempotency_key,
  correlation_id,reference_type,reference_id,created_by
) values
('71000000-0000-0000-0000-000000000001','76000000-0000-0000-0000-000000000001','GRANT',11,'p03.rls','credit-key-a','76100000-0000-0000-0000-000000000001','TEST','A','70000000-0000-0000-0000-000000000001'),
('71000000-0000-0000-0000-000000000002','76000000-0000-0000-0000-000000000002','GRANT',22,'p03.rls','credit-key-b','76100000-0000-0000-0000-000000000002','TEST','B','70000000-0000-0000-0000-000000000002');
set constraints credit_wallet_nonnegative immediate;
set constraints all deferred;

insert into public.audit_events (
  organization_id,actor_user_id,actor_type,action,resource_type,resource_id,
  correlation_id,metadata,previous_hash,event_hash
) values
('71000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001','USER','p03.rls.a','organization','71000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001','{}',null,repeat('0',64)),
('71000000-0000-0000-0000-000000000002','70000000-0000-0000-0000-000000000002','USER','p03.rls.b','organization','71000000-0000-0000-0000-000000000002','77000000-0000-0000-0000-000000000002','{}',null,repeat('0',64));

create temporary table observed (actor text,key text,value bigint,primary key(actor,key));
grant insert,select on table observed to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000001',true);
insert into observed values
('tenant','identifiers_own',(select count(*) from public.organization_identifiers where organization_id='71000000-0000-0000-0000-000000000001')),
('tenant','identifiers_other',(select count(*) from public.organization_identifiers where organization_id='71000000-0000-0000-0000-000000000002')),
('tenant','roles_own',(select count(*) from public.organization_member_roles where membership_id='73000000-0000-0000-0000-000000000001')),
('tenant','roles_other',(select count(*) from public.organization_member_roles where membership_id='73000000-0000-0000-0000-000000000002')),
('tenant','accounts_own',(select count(*) from public.financial_accounts where organization_id='71000000-0000-0000-0000-000000000001')),
('tenant','accounts_other',(select count(*) from public.financial_accounts where organization_id='71000000-0000-0000-0000-000000000002')),
('tenant','entries_own',(select count(*) from public.financial_entries where organization_id='71000000-0000-0000-0000-000000000001')),
('tenant','entries_other',(select count(*) from public.financial_entries where organization_id='71000000-0000-0000-0000-000000000002')),
('tenant','wallets_own',(select count(*) from public.credit_wallets where organization_id='71000000-0000-0000-0000-000000000001')),
('tenant','wallets_other',(select count(*) from public.credit_wallets where organization_id='71000000-0000-0000-0000-000000000002')),
('tenant','credit_entries_own',(select count(*) from public.credit_ledger_entries where organization_id='71000000-0000-0000-0000-000000000001')),
('tenant','credit_entries_other',(select count(*) from public.credit_ledger_entries where organization_id='71000000-0000-0000-0000-000000000002')),
('tenant','balances_own',(select count(*) from public.credit_wallet_balances where organization_id='71000000-0000-0000-0000-000000000001')),
('tenant','balances_other',(select count(*) from public.credit_wallet_balances where organization_id='71000000-0000-0000-0000-000000000002')),
('tenant','audit_activity_own',(select count(*) from public.organization_audit_activity where organization_id='71000000-0000-0000-0000-000000000001')),
('tenant','audit_activity_other',(select count(*) from public.organization_audit_activity where organization_id='71000000-0000-0000-0000-000000000002')),
('tenant','raw_audit',(select count(*) from public.audit_events));

select set_config('request.jwt.claim.sub','70000000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"70000000-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2"}',true);
insert into observed values
('platform','member_roles',(select count(*) from public.organization_member_roles)),
('platform','accounts',(select count(*) from public.financial_accounts where organization_id in ('71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002'))),
('platform','entries',(select count(*) from public.financial_entries where organization_id in ('71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002'))),
('platform','wallets',(select count(*) from public.credit_wallets where organization_id in ('71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002'))),
('platform','credit_entries',(select count(*) from public.credit_ledger_entries where organization_id in ('71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002'))),
('platform','raw_audit',(select count(*) from public.audit_events where organization_id in ('71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002'))),
('platform','identifiers',(select count(*) from public.organization_identifiers));
reset role;

select is((select value from observed where actor='tenant' and key='identifiers_own'),1::bigint,'tenant reads its own organization identifier');
select is((select value from observed where actor='tenant' and key='identifiers_other'),0::bigint,'tenant cannot read another organization identifier');
select is((select value from observed where actor='tenant' and key='roles_own'),1::bigint,'tenant reads its own member role');
select is((select value from observed where actor='tenant' and key='roles_other'),0::bigint,'tenant cannot read another organization member role');
select is((select value from observed where actor='tenant' and key='accounts_own'),2::bigint,'tenant accounting reads its own accounts');
select is((select value from observed where actor='tenant' and key='accounts_other'),0::bigint,'tenant accounting cannot read another organization accounts');
select is((select value from observed where actor='tenant' and key='entries_own'),2::bigint,'tenant accounting reads its own financial entries');
select is((select value from observed where actor='tenant' and key='entries_other'),0::bigint,'tenant accounting cannot read another organization entries');
select is((select value from observed where actor='tenant' and key='wallets_own'),1::bigint,'tenant accounting reads its own credit wallet');
select is((select value from observed where actor='tenant' and key='wallets_other'),0::bigint,'tenant accounting cannot read another organization wallet');
select is((select value from observed where actor='tenant' and key='credit_entries_own'),1::bigint,'tenant accounting reads its own credit entry');
select is((select value from observed where actor='tenant' and key='credit_entries_other'),0::bigint,'tenant accounting cannot read another organization credit entry');
select is((select value from observed where actor='tenant' and key='balances_own'),1::bigint,'tenant accounting reads its own derived credit balance');
select is((select value from observed where actor='tenant' and key='balances_other'),0::bigint,'tenant accounting cannot read another organization derived balance');
select is((select value from observed where actor='tenant' and key='audit_activity_own'),1::bigint,'tenant reads its own expurgated audit activity');
select is((select value from observed where actor='tenant' and key='audit_activity_other'),0::bigint,'tenant cannot read another organization audit activity');
select is((select value from observed where actor='tenant' and key='raw_audit'),0::bigint,'tenant cannot read raw audit events');
select is((select value from observed where actor='platform' and key='member_roles'),2::bigint,'platform auditor reads member roles across tenants');
select is((select value from observed where actor='platform' and key='accounts'),4::bigint,'platform auditor reads accounts across tenants');
select is((select value from observed where actor='platform' and key='entries'),4::bigint,'platform auditor reads entries across tenants');
select is((select value from observed where actor='platform' and key='wallets'),2::bigint,'platform auditor reads wallets across tenants');
select is((select value from observed where actor='platform' and key='credit_entries'),2::bigint,'platform auditor reads credit entries across tenants');
select is((select value from observed where actor='platform' and key='raw_audit'),2::bigint,'platform auditor reads raw audit events across tenants');
select is((select value from observed where actor='platform' and key='identifiers'),0::bigint,'platform role does not implicitly bypass identifier tenant policy');
select ok(not has_table_privilege('authenticated','public.event_outbox','SELECT'),'authenticated actors have no direct Outbox read path');

select * from finish();
rollback;
