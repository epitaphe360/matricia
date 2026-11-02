-- Synthetic local SQL identities; real governed posting/preparation/capture RPCs.
-- This fixture certifies SQL accounting/authorization, not PSP network signatures.
begin;
update private.admin_execution_environment_v1 set environment='DEVELOPMENT',configuration_reference='transactional-payment-fixture-0262',configured_at=clock_timestamp()where singleton;
set local search_path=public,extensions;
select no_plan();
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values
('a2620000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner-262@example.invalid','',now(),'{}','{}',now(),now()),
('a2620000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','intruder-262@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)values
('b2620000-0000-4000-8000-000000000001','Payment 262 SARL','Payment 262','ACTIVE','a2620000-0000-4000-8000-000000000001'),
('b2620000-0000-4000-8000-000000000002','Other 262 SARL','Other 262','ACTIVE','a2620000-0000-4000-8000-000000000002');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at)values
('c2620000-0000-4000-8000-000000000001','b2620000-0000-4000-8000-000000000001','a2620000-0000-4000-8000-000000000001','ACTIVE',now()),
('c2620000-0000-4000-8000-000000000002','b2620000-0000-4000-8000-000000000002','a2620000-0000-4000-8000-000000000002','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code)values
('c2620000-0000-4000-8000-000000000001','CLIENT_OWNER'),('c2620000-0000-4000-8000-000000000002','CLIENT_OWNER');
-- Other clone harnesses can keep a reference plan. Choose an unused enum code;
-- never rewrite their commercial offer or an existing active plan version.
insert into public.subscription_plans(id,code,status,created_by)
select'd2620000-0000-4000-8000-000000000001'::uuid,candidate.code,'ACTIVE','a2620000-0000-4000-8000-000000000001'::uuid
from(values('GOLD'),('PLATINUM'),('PREMIUM'))candidate(code)where not exists(select 1 from public.subscription_plans existing where existing.code=candidate.code)order by candidate.code limit 1;
insert into public.subscription_plan_versions(id,plan_id,version,status,currency,monthly_price_minor,annual_price_minor,monthly_credit_grant,core_allocation_basis_points,benefit_pool_allocation_basis_points,limits_snapshot,valid_from,content_hash,created_by)
values('d2620000-0000-4000-8000-000000000002','d2620000-0000-4000-8000-000000000001',1,'ACTIVE','EUR',12345,123450,10,5000,5000,'{}',current_date-1,repeat('a',64),'a2620000-0000-4000-8000-000000000001');
insert into public.subscriptions(id,organization_id,status)values('e2620000-0000-4000-8000-000000000001','b2620000-0000-4000-8000-000000000001','TRIAL_EXPIRED');


insert into public.platform_user_roles(user_id,role_code)values('a2620000-0000-4000-8000-000000000001','FINANCE_MANAGER'),('a2620000-0000-4000-8000-000000000002','FINANCE_MANAGER');
-- Governance prerequisites are real public commands: two independent financial reviewers,
-- an explicit synthetic POSTING policy, and a frozen cash/suspense context before PSP creation.
create function pg_temp.approve_posting262(target_environment text)returns void language plpgsql as $$declare proposal jsonb;begin
 perform set_config('request.jwt.claim.sub','a2620000-0000-4000-8000-000000000001',true);perform set_config('request.jwt.claims','{"sub":"a2620000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
 proposal:=public.create_credit_revenue_policy_v1('POSTING','SUBSCRIPTION','d2620000-0000-4000-8000-000000000002',null,'EUR',target_environment,1,current_date-1,null,jsonb_build_object('cash_account_code','FUNDING262_CASH_EUR','cash_name_fr','Trésorerie synthétique de recette','cash_name_ar','خزينة الاختبار','suspense_account_code','FUNDING262_PENDING_EUR','suspense_name_fr','Encaissement synthétique en attente','suspense_name_ar','تحصيل قيد المراجعة'),'Configuration uniquement pour la recette SQL 0262','funding262-posting-'||lower(target_environment));
 perform set_config('request.jwt.claim.sub','a2620000-0000-4000-8000-000000000002',true);perform set_config('request.jwt.claims','{"sub":"a2620000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);
 perform public.decide_credit_revenue_policy_v1((proposal->>'request_id')::uuid,true,proposal->>'request_hash','Approbation indépendante uniquement pour recette SQL 0262');
end$$;
select pg_temp.approve_posting262('DEVELOPMENT');
create temporary table p262(kind text primary key,value jsonb);
select set_config('request.jwt.claim.sub','a2620000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"a2620000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into p262 values('preparation',public.prepare_subscription_payment_intent_v2('b2620000-0000-4000-8000-000000000001','d2620000-0000-4000-8000-000000000002','MONTHLY','PAYPAL','SANDBOX','f2620000-0000-4000-8000-000000000001'));
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into p262 values('intent',public.register_subscription_payment_intent_v2((select(value->>'preparation_id')::uuid from p262 where kind='preparation'),'SANDBOX','ORDER-26200001',12345,'EUR'));
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into p262 values('paid',public.process_verified_subscription_payment_v2('PAYPAL','SANDBOX','EVENT-26200001','ORDER-26200001','PAYMENT_SUCCEEDED',12345,'EUR',clock_timestamp(),'CAPTURE-26200001',repeat('b',64),repeat('c',64)));
insert into p262 select'payment_id',jsonb_build_object('id',id)from public.subscription_payment_events where provider_event_id='EVENT-26200001';
select is((select fa.code from private.subscription_adjustment_posting_accounts_v1((select(value->>'id')::bigint from p262 where kind='payment_id'))accounts join public.financial_accounts fa on fa.id=accounts.cash_account_id),'FUNDING262_CASH_EUR','refund account resolver follows the approved custom cash mapping');
select is((select fa.code from private.subscription_adjustment_posting_accounts_v1((select(value->>'id')::bigint from p262 where kind='payment_id'))accounts join public.financial_accounts fa on fa.id=accounts.suspense_account_id),'FUNDING262_PENDING_EUR','refund counterparty remains the original pending liability');
select ok(not has_function_privilege('authenticated','private.subscription_adjustment_posting_accounts_v1(bigint)','EXECUTE'),'browser cannot invoke the private posting resolver');
insert into p262 values('refund-at',to_jsonb(clock_timestamp()));
insert into p262 values('refund',public.process_verified_subscription_adjustment_v2('SANDBOX','REFUND-EVENT-262001','CAPTURE-26200001','REFUND-26200001','REFUND_SUCCEEDED',1000,'EUR',(select(value#>>'{}')::timestamptz from p262 where kind='refund-at'),repeat('d',64),repeat('e',64)));
select is((select count(*)from public.subscription_payment_adjustments where provider_event_id='REFUND-EVENT-262001'),1::bigint,'verified native refund survives the governed custom posting codes');
select is((select sum(fe.amount_minor)from public.financial_entries fe join public.subscription_payment_adjustments a on a.financial_journal_id=fe.journal_id join public.financial_accounts fa on fa.id=fe.account_id where a.provider_event_id='REFUND-EVENT-262001'and fe.direction='CREDIT'and fa.code='FUNDING262_CASH_EUR'),1000::numeric,'native refund credits the exact cash account pinned before payment');
select is((select sum(fe.amount_minor)from public.financial_entries fe join public.subscription_payment_adjustments a on a.financial_journal_id=fe.journal_id join public.financial_accounts fa on fa.id=fe.account_id where a.provider_event_id='REFUND-EVENT-262001'and fe.direction='DEBIT'and fa.code='FUNDING262_PENDING_EUR'),1000::numeric,'refund debits suspense pending a true fiscal reversal');
select is((select count(*)from public.financial_entries fe join public.subscription_payment_adjustments a on a.financial_journal_id=fe.journal_id join public.financial_accounts fa on fa.id=fe.account_id where a.provider_event_id='REFUND-EVENT-262001'and fa.account_type in('REVENUE','EXPENSE')),0::bigint,'refund creates neither an invented expense nor an inferred tax/revenue reversal');
select is((select count(*)from public.financial_accounts where organization_id='b2620000-0000-4000-8000-000000000001'and code in('PAYMENT_CASH_EUR','SUBSCRIPTION_ADJUSTMENT_EUR')),0::bigint,'legacy sentinel accounts are never created to disguise a missing mapping');
select is(public.process_verified_subscription_adjustment_v2('SANDBOX','REFUND-EVENT-262001','CAPTURE-26200001','REFUND-26200001','REFUND_SUCCEEDED',1000,'EUR',(select(value#>>'{}')::timestamptz from p262 where kind='refund-at'),repeat('d',64),repeat('f',64))->>'replayed','true','native refund replay preserves its first journal despite a changed transmission fingerprint');
select is((select count(*)from public.subscription_payment_adjustments where provider_event_id='REFUND-EVENT-262001'),1::bigint,'retry never posts a second refund');
select throws_ok($$select public.process_verified_subscription_adjustment_v2('SANDBOX','REFUND-EVENT-262001','CAPTURE-26200001','REFUND-26200001','REFUND_SUCCEEDED',1000,'EUR',clock_timestamp(),repeat('f',64),repeat('f',64))$$,'22000','PAYMENT_EVENT_REPLAY_MISMATCH','changed native refund facts are refused atomically');
select is((select count(*)from private.subscription_adjustment_posting_accounts_v1(-262)),0::bigint,'an unknown or unconfigured capture receives no guessed posting account');
select is((select amount_minor from public.subscription_payment_events where provider_event_id='EVENT-26200001'),12345::bigint,'the original financial capture remains unchanged');
select is((select status from public.credit_economic_processing_events_v1 where funding_source_id=(select id from public.credit_economic_funding_sources_v1 where source_kind='SUBSCRIPTION'and source_id='PAYPAL:SANDBOX:CAPTURE-26200001')order by id desc limit 1),'SOURCE_REVIEW_REQUIRED','refund remains explicitly pending fiscal and economic reversal');
select*from finish();
rollback;
