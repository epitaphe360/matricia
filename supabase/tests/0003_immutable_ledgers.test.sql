begin;
set local search_path = public, extensions;
select plan(5);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('30000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','ledger@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations (id, legal_name, display_name, status, created_by)
values ('c0000000-0000-0000-0000-000000000003','Ledger SARL','Ledger','ACTIVE','30000000-0000-0000-0000-000000000003');
insert into public.financial_accounts (id,organization_id,code,name,account_type) values
('c1000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000003','CASH','Cash','ASSET'),
('c2000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000003','REVENUE','Revenue','REVENUE');
insert into public.financial_journals (id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,correlation_id,effective_at,description,created_by)
values ('c3000000-0000-0000-0000-000000000003','c0000000-0000-0000-0000-000000000003','TEST','MAD','test.journal','test-key-0001','c4000000-0000-0000-0000-000000000004',now(),'Balanced test','30000000-0000-0000-0000-000000000003');
insert into public.financial_entries (organization_id,journal_id,account_id,direction,amount_minor,currency) values
('c0000000-0000-0000-0000-000000000003','c3000000-0000-0000-0000-000000000003','c1000000-0000-0000-0000-000000000001','DEBIT',10000,'MAD'),
('c0000000-0000-0000-0000-000000000003','c3000000-0000-0000-0000-000000000003','c2000000-0000-0000-0000-000000000002','CREDIT',10000,'MAD');
set constraints financial_journal_balanced immediate;

select is((select sum(case direction when 'DEBIT' then amount_minor else -amount_minor end)::bigint from public.financial_entries where journal_id='c3000000-0000-0000-0000-000000000003'),0::bigint,'journal balances exactly');
select throws_ok($$update public.financial_entries set amount_minor=1 where journal_id='c3000000-0000-0000-0000-000000000003'$$,'55000','IMMUTABLE_RECORD','financial entries are immutable');
select throws_ok($$delete from public.financial_journals where id='c3000000-0000-0000-0000-000000000003'$$,'55000','IMMUTABLE_RECORD','financial journals are immutable');

insert into public.credit_wallets (id,organization_id,wallet_type) values ('c5000000-0000-0000-0000-000000000005','c0000000-0000-0000-0000-000000000003','CLIENT');
insert into public.credit_ledger_entries (organization_id,wallet_id,entry_type,quantity,idempotency_scope,idempotency_key,correlation_id,reference_type,reference_id,created_by)
values ('c0000000-0000-0000-0000-000000000003','c5000000-0000-0000-0000-000000000005','GRANT',10,'test.credit','test-key-0002','c6000000-0000-0000-0000-000000000006','TEST','1','30000000-0000-0000-0000-000000000003');
select is((select balance from public.credit_wallet_balances where wallet_id='c5000000-0000-0000-0000-000000000005'),10::bigint,'credit balance derives from ledger');
select throws_ok($$update public.credit_ledger_entries set quantity=20 where wallet_id='c5000000-0000-0000-0000-000000000005'$$,'55000','IMMUTABLE_RECORD','credit entries are immutable');

select * from finish();
rollback;
