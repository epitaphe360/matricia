begin;
update private.admin_execution_environment_v1 set environment='DEVELOPMENT',configuration_reference='transactional-payment-fixture-0097',configured_at=clock_timestamp()where singleton;
set local search_path=public,extensions;
select plan(20);

select ok(has_function_privilege('service_role','public.register_subscription_payment_intent_v2(uuid,text,text,bigint,character,uuid)','EXECUTE')
  and not has_function_privilege('authenticated','public.register_subscription_payment_intent_v2(uuid,text,text,bigint,character,uuid)','EXECUTE'),'provider-verified intent registration is service-only');
select ok(has_function_privilege('authenticated','public.prepare_subscription_payment_capture_v2(uuid,text)','EXECUTE')
  and not has_function_privilege('service_role','public.prepare_subscription_payment_capture_v2(uuid,text)','EXECUTE'),'PayPal capture preparation is authenticated-only');
select ok(has_function_privilege('service_role','public.process_verified_subscription_payment_v2(text,text,text,text,text,bigint,character,timestamptz,text,text,text,uuid)','EXECUTE')
  and not has_function_privilege('authenticated','public.process_verified_subscription_payment_v2(text,text,text,text,text,bigint,character,timestamptz,text,text,text,uuid)','EXECUTE'),'verified webhook processing is service-role-only');
select ok((select prosecdef and proconfig::text like'%search_path=pg_catalog%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='process_verified_subscription_payment_v2'),'webhook RPC is hardened security definer');
select ok((select pg_get_functiondef(p.oid)like'%pg_advisory_xact_lock%'and pg_get_functiondef(p.oid)like'%PAYMENT_EVENT_REPLAY_MISMATCH%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='process_subscription_payment_context_core_v1'),'private verified webhook core has concurrency lock and altered replay rejection');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values
('a9700000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner-97@example.invalid','',now(),'{}','{}',now(),now()),
('a9700000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','intruder-97@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)values
('b9700000-0000-4000-8000-000000000001','Payment 97 SARL','Payment 97','ACTIVE','a9700000-0000-4000-8000-000000000001'),
('b9700000-0000-4000-8000-000000000002','Other 97 SARL','Other 97','ACTIVE','a9700000-0000-4000-8000-000000000002');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at)values
('c9700000-0000-4000-8000-000000000001','b9700000-0000-4000-8000-000000000001','a9700000-0000-4000-8000-000000000001','ACTIVE',now()),
('c9700000-0000-4000-8000-000000000002','b9700000-0000-4000-8000-000000000002','a9700000-0000-4000-8000-000000000002','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code)values
('c9700000-0000-4000-8000-000000000001','CLIENT_OWNER'),('c9700000-0000-4000-8000-000000000002','CLIENT_OWNER');
insert into public.subscription_plans(id,code,status,created_by)values('d9700000-0000-4000-8000-000000000001','PREMIUM','ACTIVE','a9700000-0000-4000-8000-000000000001');
insert into public.subscription_plan_versions(id,plan_id,version,status,currency,monthly_price_minor,annual_price_minor,monthly_credit_grant,core_allocation_basis_points,benefit_pool_allocation_basis_points,limits_snapshot,valid_from,content_hash,created_by)
values('d9700000-0000-4000-8000-000000000002','d9700000-0000-4000-8000-000000000001',1,'ACTIVE','EUR',12345,123450,10,5000,5000,'{}',current_date-1,repeat('a',64),'a9700000-0000-4000-8000-000000000001');
insert into public.subscriptions(id,organization_id,status)values('e9700000-0000-4000-8000-000000000001','b9700000-0000-4000-8000-000000000001','TRIAL_EXPIRED');

insert into public.platform_user_roles(user_id,role_code)values('a9700000-0000-4000-8000-000000000001','FINANCE_MANAGER'),('a9700000-0000-4000-8000-000000000002','FINANCE_MANAGER');
-- Governance prerequisites are real public commands: two independent financial reviewers,
-- an explicit synthetic POSTING policy, and a frozen cash/suspense context before PSP creation.
create function pg_temp.approve_posting970(target_environment text)returns void language plpgsql as $$declare proposal jsonb;begin
 perform set_config('request.jwt.claim.sub','a9700000-0000-4000-8000-000000000001',true);perform set_config('request.jwt.claims','{"sub":"a9700000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
 proposal:=public.create_credit_revenue_policy_v1('POSTING','SUBSCRIPTION','d9700000-0000-4000-8000-000000000002',null,'EUR',target_environment,1,current_date-1,null,jsonb_build_object('cash_account_code','FUNDING970_CASH_EUR','cash_name_fr','Trésorerie synthétique de recette','cash_name_ar','خزينة الاختبار','suspense_account_code','FUNDING970_PENDING_EUR','suspense_name_fr','Encaissement synthétique en attente','suspense_name_ar','تحصيل قيد المراجعة'),'Configuration uniquement pour la recette SQL 0970','funding970-posting-'||lower(target_environment));
 perform set_config('request.jwt.claim.sub','a9700000-0000-4000-8000-000000000002',true);perform set_config('request.jwt.claims','{"sub":"a9700000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);
 perform public.decide_credit_revenue_policy_v1((proposal->>'request_id')::uuid,true,proposal->>'request_hash','Approbation indépendante uniquement pour recette SQL 0970');
end$$;
select pg_temp.approve_posting970('DEVELOPMENT');
create temporary table p97_results(kind text primary key,value jsonb);
grant select,insert on p97_results to authenticated,service_role;
set local role authenticated;
select set_config('request.jwt.claim.sub','a9700000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"a9700000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into p97_results values('preparation',public.prepare_subscription_payment_intent_v2('b9700000-0000-4000-8000-000000000001','d9700000-0000-4000-8000-000000000002','MONTHLY','PAYPAL','SANDBOX','f9700000-0000-4000-8000-000000000001'));
reset role;set local role service_role;select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into p97_results values('intent',public.register_subscription_payment_intent_v2((select(value->>'preparation_id')::uuid from p97_results where kind='preparation'),'SANDBOX','ORDER-97000001',12345,'EUR','f9700000-0000-4000-8000-000000000002'));
reset role;set local role authenticated;select set_config('request.jwt.claim.sub','a9700000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a9700000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into p97_results values('capture',public.prepare_subscription_payment_capture_v2((select (value->>'payment_intent_id')::uuid from p97_results where kind='intent'),'SANDBOX'));
reset role;
select ok((select value->>'provider_intent_id'='ORDER-97000001' from p97_results where kind='capture'),'authorized owner resolves only the stored PayPal order');
select is((select status from public.subscriptions where id='e9700000-0000-4000-8000-000000000001'),'TRIAL_EXPIRED','intent and capture preparation never activate before verified webhook');
select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','a9700000-0000-4000-8000-000000000002',true);select public.prepare_subscription_payment_capture_v2((select (value->>'payment_intent_id')::uuid from p97_results where kind='intent'),'SANDBOX')$$,'42501','PAYMENT_CAPTURE_DENIED','cross-tenant capture preparation is denied');
reset role;

set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into p97_results values('payment',public.process_verified_subscription_payment_v2('PAYPAL','SANDBOX','EVENT-97000001','ORDER-97000001','PAYMENT_SUCCEEDED',12345,'EUR',clock_timestamp(),'CAPTURE-97000001',repeat('b',64),repeat('c',64),'f9700000-0000-4000-8000-000000000003'));
reset role;
select is((select status from public.subscriptions where id='e9700000-0000-4000-8000-000000000001'),'ACTIVE','verified webhook activates the subscription');
select is((select count(*) from public.subscription_payment_events where provider_event_id='EVENT-97000001'),1::bigint,'one immutable payment event is recorded');
select is((select count(*) from public.financial_journals where id=(select (value->>'financial_journal_id')::uuid from p97_results where kind='payment')),1::bigint,'one reconstructible financial journal is posted');
select is((select count(*) from public.financial_entries where journal_id=(select (value->>'financial_journal_id')::uuid from p97_results where kind='payment')),2::bigint,'journal has exactly two entries');
select ok((select sum(amount_minor)filter(where direction='DEBIT')=sum(amount_minor)filter(where direction='CREDIT')and min(currency)=max(currency)and min(currency)='EUR' from public.financial_entries where journal_id=(select (value->>'financial_journal_id')::uuid from p97_results where kind='payment')),'journal is balanced in the payment currency');
select is((select count(*) from public.audit_events where action='financial.journal.posted'and resource_id=(select value->>'financial_journal_id' from p97_results where kind='payment')),1::bigint,'journal posting is audited once');
select is((select count(*) from public.event_outbox where event_type='FinancialJournalPostedV1'and aggregate_id=(select value->>'financial_journal_id' from p97_results where kind='payment')),1::bigint,'journal posting emits one durable event');

set local role service_role;select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into p97_results values('replay',public.process_verified_subscription_payment_v2('PAYPAL','SANDBOX','EVENT-97000001','ORDER-97000001','PAYMENT_SUCCEEDED',12345,'EUR',(select paid_at from public.subscription_payment_events where provider_event_id='EVENT-97000001'),'CAPTURE-97000001',repeat('b',64),repeat('c',64),'f9700000-0000-4000-8000-000000000004'));
reset role;
select ok((select (value->>'replayed')::boolean from p97_results where kind='replay'),'identical webhook replay is acknowledged');
select is((select count(*) from public.subscription_payment_events where provider_event_id='EVENT-97000001'),1::bigint,'identical double webhook does not duplicate payment');
select is((select count(*) from public.financial_journals where idempotency_scope='verified.payment.capture'and idempotency_key='SUBSCRIPTION:PAYPAL:SANDBOX:CAPTURE-97000001'),1::bigint,'identical double webhook does not duplicate journal');
select throws_ok($$set local role service_role;select set_config('request.jwt.claims','{"role":"service_role"}',true);select public.process_verified_subscription_payment_v2('PAYPAL','SANDBOX','EVENT-97000001','ORDER-97000001','PAYMENT_SUCCEEDED',12345,'EUR',(select paid_at from public.subscription_payment_events where provider_event_id='EVENT-97000001'),'CAPTURE-97000001',repeat('d',64),repeat('c',64),'f9700000-0000-4000-8000-000000000005')$$,'22000','PAYMENT_EVENT_REPLAY_MISMATCH','altered replay is rejected atomically');
reset role;
select is((select count(*) from public.subscription_cycles where organization_id='b9700000-0000-4000-8000-000000000001'),1::bigint,'replay and rejection leave one paid cycle');

select * from finish();
rollback;
