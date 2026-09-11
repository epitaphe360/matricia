begin;
set local search_path = public, extensions;
select plan(13);

insert into auth.users (id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('40000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','finance@example.invalid','',now(),'{}','{}',now(),now()),
('50000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','outsider@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations (id,legal_name,display_name,status,created_by)
values ('d0000000-0000-0000-0000-000000000004','Finance SARL','Finance','ACTIVE','40000000-0000-0000-0000-000000000004');
insert into public.organization_memberships (id,organization_id,user_id,status,activated_at)
values ('d1000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000004','40000000-0000-0000-0000-000000000004','ACTIVE',now());
insert into public.organization_member_roles (membership_id,role_code)
values ('d1000000-0000-0000-0000-000000000001','CLIENT_ACCOUNTING');
insert into public.financial_accounts (id,organization_id,code,name,account_type) values
('d2000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000004','CASH','Cash','ASSET'),
('d3000000-0000-0000-0000-000000000003','d0000000-0000-0000-0000-000000000004','REVENUE','Revenue','REVENUE');
insert into public.credit_wallets (id,organization_id,wallet_type)
values ('d4000000-0000-0000-0000-000000000004','d0000000-0000-0000-0000-000000000004','CLIENT');

set local role authenticated;
select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-000000000004',true);
select public.post_financial_journal(
  'd0000000-0000-0000-0000-000000000004','journal-key-0001',null,'SALE','MAD',now(),'RPC test',
  jsonb_build_array(
    jsonb_build_object('account_id','d2000000-0000-0000-0000-000000000002','direction','DEBIT','amount_minor',12500),
    jsonb_build_object('account_id','d3000000-0000-0000-0000-000000000003','direction','CREDIT','amount_minor',12500)
  ),'d5000000-0000-0000-0000-000000000005'
);
select public.post_financial_journal(
  'd0000000-0000-0000-0000-000000000004','journal-key-0001',null,'SALE','MAD',now(),'RPC test',
  jsonb_build_array(
    jsonb_build_object('account_id','d2000000-0000-0000-0000-000000000002','direction','DEBIT','amount_minor',12500),
    jsonb_build_object('account_id','d3000000-0000-0000-0000-000000000003','direction','CREDIT','amount_minor',12500)
  ),'d5000000-0000-0000-0000-000000000005'
);
select public.append_credit_entry('d0000000-0000-0000-0000-000000000004','d4000000-0000-0000-0000-000000000004','GRANT',25,'TEST','credit-1','credit-key-0001',null,'d6000000-0000-0000-0000-000000000006');
select public.append_credit_entry('d0000000-0000-0000-0000-000000000004','d4000000-0000-0000-0000-000000000004','GRANT',25,'TEST','credit-1','credit-key-0001',null,'d6000000-0000-0000-0000-000000000006');
reset role;
select throws_ok(
  $$select public.post_financial_journal(
    'd0000000-0000-0000-0000-000000000004','journal-key-0001',null,'SALE','MAD',now(),'RPC test',
    jsonb_build_array(
      jsonb_build_object('account_id','d2000000-0000-0000-0000-000000000002','direction','DEBIT','amount_minor',15000),
      jsonb_build_object('account_id','d3000000-0000-0000-0000-000000000003','direction','CREDIT','amount_minor',15000)
    ),'d5000000-0000-0000-0000-000000000005'
  )$$,
  '22000','IDEMPOTENCY_PAYLOAD_MISMATCH','same journal key with a different server-canonical payload is rejected'
);
select throws_ok(
  $$select public.append_credit_entry('d0000000-0000-0000-0000-000000000004','d4000000-0000-0000-0000-000000000004','GRANT',30,'TEST','credit-1','credit-key-0001',null,'d6000000-0000-0000-0000-000000000006')$$,
  '22000','IDEMPOTENCY_PAYLOAD_MISMATCH','same credit key with a different server-canonical payload is rejected'
);
select throws_ok(
  $$select public.append_credit_entry('d0000000-0000-0000-0000-000000000004','d4000000-0000-0000-0000-000000000004','GRANT',1,'TEST','client-hash','credit-key-0003',repeat('f',64),'d8000000-0000-0000-0000-000000000008')$$,
  '22000','CLIENT_REQUEST_HASH_MISMATCH','an untrusted client hash cannot override the server-canonical request hash'
);
select set_config('request.jwt.claim.sub','50000000-0000-0000-0000-000000000005',true);
select throws_ok(
  $$select public.append_credit_entry('d0000000-0000-0000-0000-000000000004','d4000000-0000-0000-0000-000000000004','GRANT',1,'TEST','forbidden','credit-key-0002',repeat('c',64),'d7000000-0000-0000-0000-000000000007')$$,
  '42501','FORBIDDEN','an outsider cannot invoke a tenant financial command'
);
select ok(not has_table_privilege('authenticated','public.credit_ledger_entries','INSERT'),'authenticated users cannot write a ledger directly');

select is((select count(*) from public.financial_journals where organization_id='d0000000-0000-0000-0000-000000000004'),1::bigint,'journal command is idempotent');
select is((select count(*) from public.financial_entries where organization_id='d0000000-0000-0000-0000-000000000004'),2::bigint,'journal writes exactly two entries');
select is((select count(*) from public.credit_ledger_entries where organization_id='d0000000-0000-0000-0000-000000000004'),1::bigint,'credit command is idempotent');
select is((select balance from public.credit_wallet_balances where wallet_id='d4000000-0000-0000-0000-000000000004'),25::bigint,'credit balance is exact');
select is((select count(*) from public.audit_events where organization_id='d0000000-0000-0000-0000-000000000004'),2::bigint,'each unique command emits one audit event');
select is((select count(*) from public.event_outbox where organization_id='d0000000-0000-0000-0000-000000000004'),2::bigint,'each unique command emits one outbox event');
select ok((select bool_and(event_hash ~ '^[0-9a-f]{64}$') from public.audit_events where organization_id='d0000000-0000-0000-0000-000000000004'),'audit hashes are SHA-256 hex');
select is((select previous_hash from public.audit_events where organization_id='d0000000-0000-0000-0000-000000000004' order by id desc limit 1),(select event_hash from public.audit_events where organization_id='d0000000-0000-0000-0000-000000000004' order by id asc limit 1),'audit chain links consecutive events');

select * from finish();
rollback;
