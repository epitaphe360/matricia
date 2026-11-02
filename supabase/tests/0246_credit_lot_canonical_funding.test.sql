begin;
update private.admin_execution_environment_v1 set environment='DEVELOPMENT',configuration_reference='transactional-payment-fixture-0246',configured_at=clock_timestamp()where singleton;
set local search_path=public,extensions;
select no_plan();
grant usage on schema extensions to authenticated;

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values
('a2460000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner-246@example.invalid','',now(),'{}','{}',now(),now()),
('a2460000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','intruder-246@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)values
('b2460000-0000-4000-8000-000000000001','Payment 246 SARL','Payment 246','ACTIVE','a2460000-0000-4000-8000-000000000001'),
('b2460000-0000-4000-8000-000000000002','Other 246 SARL','Other 246','ACTIVE','a2460000-0000-4000-8000-000000000002');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at)values
('c2460000-0000-4000-8000-000000000001','b2460000-0000-4000-8000-000000000001','a2460000-0000-4000-8000-000000000001','ACTIVE',now()),
('c2460000-0000-4000-8000-000000000002','b2460000-0000-4000-8000-000000000002','a2460000-0000-4000-8000-000000000002','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code)values
('c2460000-0000-4000-8000-000000000001','CLIENT_OWNER'),('c2460000-0000-4000-8000-000000000002','CLIENT_OWNER');
insert into public.subscription_plans(id,code,status,created_by)values('d2460000-0000-4000-8000-000000000001','PREMIUM','ACTIVE','a2460000-0000-4000-8000-000000000001');
insert into public.subscription_plan_versions(id,plan_id,version,status,currency,monthly_price_minor,annual_price_minor,monthly_credit_grant,core_allocation_basis_points,benefit_pool_allocation_basis_points,limits_snapshot,valid_from,content_hash,created_by)
values('d2460000-0000-4000-8000-000000000002','d2460000-0000-4000-8000-000000000001',1,'ACTIVE','EUR',12345,123450,10,5000,5000,'{}',current_date-365,repeat('a',64),'a2460000-0000-4000-8000-000000000001');
insert into public.subscriptions(id,organization_id,status)values('e2460000-0000-4000-8000-000000000001','b2460000-0000-4000-8000-000000000001','TRIAL_EXPIRED');


insert into public.platform_user_roles(user_id,role_code)values('a2460000-0000-4000-8000-000000000001','FINANCE_MANAGER');

-- Historical published plan/Box configuration is explicit test input, not a
-- default policy or an approval for any real client. Report is three months.
insert into public.box_definitions(id,code,status,created_by)values('f2460000-0000-4000-8000-000000000001','FUNDING_246','ACTIVE','a2460000-0000-4000-8000-000000000001');
insert into public.box_versions(id,box_id,version,status,box_type,name_fr,name_ar,credit_budget,rollover_months,rules_snapshot,cost_low_minor,cost_expected_minor,cost_full_minor,currency,content_hash,effective_from,created_by,created_at)
values('f2460000-0000-4000-8000-000000000002','f2460000-0000-4000-8000-000000000001',1,'ACTIVE','FIXED','Test rollover 246','ترحيل اختباري',10,3,'{"fixture":"versioned-three-month-rollover"}',0,0,0,'EUR',repeat('b',64),now()-interval'1 year','a2460000-0000-4000-8000-000000000001',now()-interval'1 year');
insert into public.plan_box_rules(id,plan_version_id,box_version_id,status,effective_from,rule_snapshot,created_at)
values('f2460000-0000-4000-8000-000000000003','d2460000-0000-4000-8000-000000000002','f2460000-0000-4000-8000-000000000002','ACTIVE',now()-interval'1 year','{"fixture":"approved-plan-link"}',now()-interval'1 year');
insert into public.benefit_definitions(id,code,status,created_by)values('f2460000-0000-4000-8000-000000000004','FUNDING_BENEFIT_246','ACTIVE','a2460000-0000-4000-8000-000000000001');
insert into public.benefit_versions(id,benefit_id,version,status,benefit_type,fulfillment_mode,name_fr,name_ar,description_fr,description_ar,credit_cost,reference_value_minor,internal_cost_minor,currency,cancellation_rule_version,effective_from,content_hash,created_by)
values('f2460000-0000-4000-8000-000000000005','f2460000-0000-4000-8000-000000000004',1,'ACTIVE','CREDIT_SERVICE','MATRICIA_INTERNAL','Test funding','اختبار التمويل','Credit funding fixture','اختبار مصدر الرصيد',3,0,0,'EUR','CANCEL_TEST_V1',now()-interval'1 day',repeat('c',64),'a2460000-0000-4000-8000-000000000001');
create temporary table p246(k text primary key,v jsonb);

insert into public.plan_entitlements(plan_id,plan_version_id,entitlement_code,enabled)values('d2460000-0000-4000-8000-000000000001','d2460000-0000-4000-8000-000000000002','FUNDING_PROBE',true);
select set_config('request.jwt.claim.sub','a2460000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a2460000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into p246 values('prep',public.prepare_subscription_payment_intent_v2('b2460000-0000-4000-8000-000000000001','d2460000-0000-4000-8000-000000000002','MONTHLY','DEMO','DEMO','funding246-demo-prepare'));
select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into p246 values('intent',public.register_subscription_payment_intent_v2((select(v->>'preparation_id')::uuid from p246 where k='prep'),'DEMO','SYNTHETIC-CLONE-DEMO-ORDER-246',12345,'EUR'));
insert into p246 values('paid',public.process_verified_subscription_payment_v2('DEMO','DEMO','SYNTHETIC-DEMO-EVENT-246','SYNTHETIC-CLONE-DEMO-ORDER-246','PAYMENT_SUCCEEDED',12345,'EUR',clock_timestamp(),'SYNTHETIC-DEMO-CAPTURE-246',repeat('d',64),repeat('e',64)));
select set_config('request.jwt.claim.sub','a2460000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a2460000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
select set_config('test.demo_payment',(select id::text from public.subscription_payment_events where provider_event_id='SYNTHETIC-DEMO-EVENT-246'),true);
insert into p246 values('wallet',public.ensure_client_credit_wallet('b2460000-0000-4000-8000-000000000001','funding246-wallet'));
select set_config('test.wallet',(select v->>'wallet_id'from p246 where k='wallet'),true);
insert into p246 values('terms',public.get_subscription_credit_grant_context_v1('b2460000-0000-4000-8000-000000000001',current_setting('test.demo_payment')::bigint,1));
select is((select v#>>'{terms,quantity}'from p246 where k='terms'),'10','quantity is derived from the paid immutable plan');
select is((select v#>>'{terms,revenue_value_minor}'from p246 where k='terms'),'0','the subscription credit grant recognizes no additional revenue');
select is((select v#>>'{terms,revenue_recognition}'from p246 where k='terms'),'ALREADY_RECOGNIZED_IN_SUBSCRIPTION_LEDGER','funding and revenue recognition remain distinct');
select is((select v#>>'{terms,rollover_policy,rollover_months}'from p246 where k='terms'),'3','expiry comes from the actual versioned Box policy');
select set_config('test.journal_count',(select count(*)::text from public.financial_journals where organization_id='b2460000-0000-4000-8000-000000000001'),true);
insert into p246 values('subscription_lot',public.issue_subscription_credit_grant_v1('b2460000-0000-4000-8000-000000000001',current_setting('test.demo_payment')::bigint,1,(select v#>>'{terms,terms_hash}'from p246 where k='terms'),'funding246-subscription-grant'));
select set_config('test.demo_lot',(select v->>'credit_lot_id'from p246 where k='subscription_lot'),true);
select is((select currency::text from public.credit_lots where id=current_setting('test.demo_lot')::uuid),'EUR','the lot keeps the source currency instead of the legacy MAD default');
select is((select source_snapshot#>>'{benefit_pool_allocation_basis_points}'from public.credit_lot_payment_sources_v1 where credit_lot_id=current_setting('test.demo_lot')::uuid),'5000','the actual source pool configuration is preserved without a new allocation formula');
select is((select count(*)::text from public.financial_journals where organization_id='b2460000-0000-4000-8000-000000000001'),current_setting('test.journal_count'),'issuing subscription credits creates no additional financial revenue journal');
select is((public.issue_subscription_credit_grant_v1('b2460000-0000-4000-8000-000000000001',current_setting('test.demo_payment')::bigint,1,(select v#>>'{terms,terms_hash}'from p246 where k='terms'),'funding246-subscription-grant')->>'credit_lot_id'),current_setting('test.demo_lot'),'the same command replays its exact lot');
select throws_ok($$select public.issue_subscription_credit_grant_v1('b2460000-0000-4000-8000-000000000001',current_setting('test.demo_payment')::bigint,1,(select v#>>'{terms,terms_hash}'from p246 where k='terms'),'funding246-subscription-second-key')$$,'55000','CREDIT_SUBSCRIPTION_GRANT_ALREADY_ISSUED','another idempotency key cannot grant the same paid monthly slot twice');
select throws_ok($$select public.issue_subscription_credit_grant_v1('b2460000-0000-4000-8000-000000000001',current_setting('test.demo_payment')::bigint,1,repeat('f',64),'funding246-stale-terms')$$,'40001','STALE_SUBSCRIPTION_CREDIT_GRANT_TERMS','an unseen grant policy cannot be confirmed silently');
select throws_ok($$select public.issue_credits('b2460000-0000-4000-8000-000000000001',current_setting('test.wallet')::uuid,'SUBSCRIPTION_GRANT',11,(select(v#>>'{terms,expires_at}')::timestamptz from p246 where k='terms'),null,(select v#>>'{terms,source_reference}'from p246 where k='terms'),0,(select v#>>'{terms,rule_version}'from p246 where k='terms'),null,'funding246-excess-quantity')$$,'23514','CREDIT_SUBSCRIPTION_GRANT_TERMS_MISMATCH','the generic command cannot exceed the paid snapshot quantity');
select throws_ok($$select public.issue_credits('b2460000-0000-4000-8000-000000000001',current_setting('test.wallet')::uuid,'SUBSCRIPTION_GRANT',10,(select(v#>>'{terms,expires_at}')::timestamptz from p246 where k='terms'),null,(select v#>>'{terms,source_reference}'from p246 where k='terms'),1,(select v#>>'{terms,rule_version}'from p246 where k='terms'),null,'funding246-fake-revenue')$$,'23514','CREDIT_SUBSCRIPTION_GRANT_TERMS_MISMATCH','a valid payment cannot invent additional revenue recognition');
select throws_ok($$select public.issue_credits('b2460000-0000-4000-8000-000000000001',current_setting('test.wallet')::uuid,'SUBSCRIPTION_GRANT',10,(select(v#>>'{terms,expires_at}')::timestamptz from p246 where k='terms'),null,(select v#>>'{terms,source_reference}'from p246 where k='terms'),0,'CALLER_INVENTED_RULE',null,'funding246-fake-rule')$$,'23514','CREDIT_SUBSCRIPTION_GRANT_TERMS_MISMATCH','a caller cannot replace the canonical paid grant rule');
select throws_ok($$select public.issue_credits('b2460000-0000-4000-8000-000000000001',current_setting('test.wallet')::uuid,'SUBSCRIPTION_GRANT',10,now()+interval'10 years',null,(select v#>>'{terms,source_reference}'from p246 where k='terms'),0,(select v#>>'{terms,rule_version}'from p246 where k='terms'),null,'funding246-fake-expiry')$$,'23514','CREDIT_SUBSCRIPTION_GRANT_TERMS_MISMATCH','a caller cannot extend expiry beyond the versioned report');
select throws_ok($$select public.issue_credits('b2460000-0000-4000-8000-000000000001',current_setting('test.wallet')::uuid,'SUBSCRIPTION_GRANT',10,now()+interval'5 years',null,'unlinked-claim-246',0,'ARBITRARY',null,'funding246-unlinked-new')$$,'55000','CREDIT_SUBSCRIPTION_PAYMENT_SOURCE_REQUIRED','new subscription grants require an exact native payment source');
select is((select count(*)::integer from public.credit_lots where organization_id='b2460000-0000-4000-8000-000000000001'),1,'failed duplicate, stale, inflated and unlinked commands leave no lot');
select is((select count(*)::integer from public.credit_ledger_entries where organization_id='b2460000-0000-4000-8000-000000000001'and entry_type='GRANT'),1,'failed grants leave no credit ledger entry');
select is((select count(*)::integer from public.event_outbox where aggregate_id=current_setting('test.demo_lot')and event_type='CreditLotPaymentBoundV1'),1,'the immutable funding binding emits one outbox fact');
select throws_ok($$update public.credit_lot_payment_sources_v1 set source_hash=repeat('f',64)where credit_lot_id=current_setting('test.demo_lot')::uuid$$,'55000',null,'the funding snapshot cannot be rewritten');
-- Historical pre-migration unlinked lot. Disable only the NEW binding trigger
-- while constructing this old fixture; all ledger/role/identity guards remain.
-- No payment is fabricated or declared verified for this lot.
alter table public.credit_lots disable trigger credit_lot_subscription_payment_binding;
insert into p246 values('legacy_lot',public.issue_credits('b2460000-0000-4000-8000-000000000001',current_setting('test.wallet')::uuid,'SUBSCRIPTION_GRANT',5,now()+interval'2 days',null,'PRE_MIGRATION_UNKNOWN_246',0,'HISTORICAL_UNKNOWN',null,'funding246-historical-seed'));
alter table public.credit_lots enable trigger credit_lot_subscription_payment_binding;
select is(private.credit_lot_funding_status_v1((select(v->>'credit_lot_id')::uuid from p246 where k='legacy_lot')),'SOURCE_UNVERIFIED','an old unlinked lot remains visible but cannot acquire invented provenance');
insert into p246 values('demo_reservation',public.reserve_benefit_credits('b2460000-0000-4000-8000-000000000001',current_setting('test.wallet')::uuid,'f2460000-0000-4000-8000-000000000005',1,now()+interval'1 day','funding246-demo-reserve'));
select is((select credit_lot_id::text from public.credit_lot_movements where redemption_id=(select(v->>'redemption_id')::uuid from p246 where k='demo_reservation')),current_setting('test.demo_lot'),'FEFO skips the earlier historical lot whose provenance is missing');
insert into p246 values('gift_lot',public.issue_credits('b2460000-0000-4000-8000-000000000001',current_setting('test.wallet')::uuid,'ADMIN_GRANT',7,now()+interval'6 months',null,'APPROVED_MANUAL_246',0,'ADMIN_APPROVED_V1','explicit-fixture-approval-246','funding246-approved-gift'));
select set_config('test.balance_before_retag',(select balance::text from public.credit_wallet_balances where wallet_id=current_setting('test.wallet')::uuid),true);
update private.admin_execution_environment_v1 set environment='PRODUCTION',configuration_reference='transactional-retag-fixture-0246',configured_at=clock_timestamp()where singleton;
select is(private.credit_lot_funding_status_v1(current_setting('test.demo_lot')::uuid),'ENVIRONMENT_INCOMPATIBLE','a DEV DEMO lot cannot finance a new effect after trusted deployment retag');
select is((select balance::text from public.credit_wallet_balances where wallet_id=current_setting('test.wallet')::uuid),current_setting('test.balance_before_retag'),'retag never rewrites the historical credit balance');
select throws_ok($$insert into public.credit_lot_movements(organization_id,credit_lot_id,redemption_id,movement_type,quantity,idempotency_scope,idempotency_key,correlation_id,created_by)values('b2460000-0000-4000-8000-000000000001',current_setting('test.demo_lot')::uuid,(select(v->>'redemption_id')::uuid from p246 where k='demo_reservation'),'CONSUME',3,'credits.test','funding246-denied-consume',extensions.gen_random_uuid(),'a2460000-0000-4000-8000-000000000001')$$,'55000','CREDIT_LOT_FUNDING_NOT_ADMISSIBLE','the movement guard also refuses consumption of an already reserved DEMO lot');
select lives_ok($$select public.release_benefit_credits((select(v->>'redemption_id')::uuid from p246 where k='demo_reservation'),'CANCEL_INCOMPATIBLE_FUNDING','funding246-release-after-retag')$$,'an incompatible source does not prevent releasing its old reservation');
insert into p246 values('gift_reservation',public.reserve_benefit_credits('b2460000-0000-4000-8000-000000000001',current_setting('test.wallet')::uuid,'f2460000-0000-4000-8000-000000000005',1,now()+interval'1 day','funding246-gift-reserve'));
select is((select credit_lot_id::text from public.credit_lot_movements where redemption_id=(select(v->>'redemption_id')::uuid from p246 where k='gift_reservation')),(select v->>'credit_lot_id'from p246 where k='gift_lot'),'an eligible manual gift remains usable even with an older incompatible paid lot');
select throws_ok($$select public.reserve_benefit_credits('b2460000-0000-4000-8000-000000000001',current_setting('test.wallet')::uuid,'f2460000-0000-4000-8000-000000000005',2,now()+interval'1 day','funding246-no-eligible-more')$$,'23514','INSUFFICIENT_ELIGIBLE_CREDITS','historical balance cannot bypass the lack of compatible unspent lots');
-- A historical external intent is the upstream precondition for a late native
-- callback. The callback itself creates the payment, balanced journal and cycle.
-- No ledger, cycle or subscription activation is inserted by this fixture.
insert into public.subscriptions(id,organization_id,status)values('e2460000-0000-4000-8000-000000000002','b2460000-0000-4000-8000-000000000002','TRIAL_EXPIRED');
insert into public.subscription_payment_intents(id,organization_id,plan_version_id,billing_interval,gateway,provider_environment,deployment_environment,provider_intent_id,amount_minor,currency,idempotency_key,request_hash,correlation_id,created_by,created_at)
values('a2460000-0000-4000-8000-000000000101','b2460000-0000-4000-8000-000000000002','d2460000-0000-4000-8000-000000000002','MONTHLY','PAYPAL','LIVE','PRODUCTION','SYNTHETIC-HISTORICAL-LIVE-ORDER-246',12345,'EUR','funding246-historical-live-order',repeat('3',64),extensions.gen_random_uuid(),'a2460000-0000-4000-8000-000000000002',now()-interval'2 months'-interval'1 minute');
select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into p246 values('live_paid',public.process_verified_subscription_payment_v2('PAYPAL','LIVE','SYNTHETIC-LIVE-EVENT-246','SYNTHETIC-HISTORICAL-LIVE-ORDER-246','PAYMENT_SUCCEEDED',12345,'EUR',now()-interval'2 months','SYNTHETIC-LIVE-CAPTURE-246',repeat('4',64),repeat('5',64)));
select set_config('test.live_payment',(select id::text from public.subscription_payment_events where provider_event_id='SYNTHETIC-LIVE-EVENT-246'),true);
select set_config('request.jwt.claim.sub','a2460000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a2460000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into p246 values('live_wallet',public.ensure_client_credit_wallet('b2460000-0000-4000-8000-000000000002','funding246-live-wallet'));
insert into p246 values('live_terms',public.get_subscription_credit_grant_context_v1('b2460000-0000-4000-8000-000000000002',current_setting('test.live_payment')::bigint,1));
select ok((select(v#>>'{terms,period_end}')::timestamptz<clock_timestamp()from p246 where k='live_terms'),'the source payment cycle has already ended');
select ok((select(v#>>'{terms,expires_at}')::timestamptz>clock_timestamp()from p246 where k='live_terms'),'the actual versioned report still keeps the credits unexpired');
insert into p246 values('live_lot',public.issue_subscription_credit_grant_v1('b2460000-0000-4000-8000-000000000002',current_setting('test.live_payment')::bigint,1,(select v#>>'{terms,terms_hash}'from p246 where k='live_terms'),'funding246-live-reported-grant'));
insert into p246 values('live_reservation',public.reserve_benefit_credits('b2460000-0000-4000-8000-000000000002',(select(v->>'wallet_id')::uuid from p246 where k='live_wallet'),'f2460000-0000-4000-8000-000000000005',1,now()+interval'1 day','funding246-live-reported-reserve'));
select is(private.credit_lot_funding_status_v1((select(v->>'credit_lot_id')::uuid from p246 where k='live_lot')),'ELIGIBLE','a valid LIVE reported lot does not depend on a currently active paid period');
select is((select credit_lot_id::text from public.credit_lot_movements where redemption_id=(select(v->>'redemption_id')::uuid from p246 where k='live_reservation')),(select v->>'credit_lot_id'from p246 where k='live_lot'),'the real reservation command uses reported LIVE credits after the origin cycle expired');
-- Annual billing still grants monthly credits, not an arbitrary yearly amount.
insert into public.organizations(id,legal_name,display_name,status,created_by)values('b2460000-0000-4000-8000-000000000003','Annual fixture 246','Annual 246','ACTIVE','a2460000-0000-4000-8000-000000000001');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at)values('c2460000-0000-4000-8000-000000000003','b2460000-0000-4000-8000-000000000003','a2460000-0000-4000-8000-000000000001','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code)values('c2460000-0000-4000-8000-000000000003','CLIENT_OWNER');
insert into public.subscriptions(id,organization_id,status)values('e2460000-0000-4000-8000-000000000003','b2460000-0000-4000-8000-000000000003','TRIAL_EXPIRED');
insert into public.subscription_payment_intents(id,organization_id,plan_version_id,billing_interval,gateway,provider_environment,deployment_environment,provider_intent_id,amount_minor,currency,idempotency_key,request_hash,correlation_id,created_by,created_at)
values('a2460000-0000-4000-8000-000000000102','b2460000-0000-4000-8000-000000000003','d2460000-0000-4000-8000-000000000002','ANNUAL','PAYPAL','LIVE','PRODUCTION','SYNTHETIC-ANNUAL-LIVE-ORDER-246',123450,'EUR','funding246-annual-live-order',repeat('6',64),extensions.gen_random_uuid(),'a2460000-0000-4000-8000-000000000001',now()-interval'2 months'-interval'1 minute');
select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into p246 values('annual_paid',public.process_verified_subscription_payment_v2('PAYPAL','LIVE','SYNTHETIC-ANNUAL-EVENT-246','SYNTHETIC-ANNUAL-LIVE-ORDER-246','PAYMENT_SUCCEEDED',123450,'EUR',now()-interval'2 months','SYNTHETIC-ANNUAL-CAPTURE-246',repeat('7',64),repeat('8',64)));
select set_config('test.annual_payment',(select id::text from public.subscription_payment_events where provider_event_id='SYNTHETIC-ANNUAL-EVENT-246'),true);
select set_config('request.jwt.claim.sub','a2460000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a2460000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into p246 values('annual_wallet',public.ensure_client_credit_wallet('b2460000-0000-4000-8000-000000000003','funding246-annual-wallet'));
insert into p246 values('annual_terms1',public.get_subscription_credit_grant_context_v1('b2460000-0000-4000-8000-000000000003',current_setting('test.annual_payment')::bigint,1)),('annual_terms2',public.get_subscription_credit_grant_context_v1('b2460000-0000-4000-8000-000000000003',current_setting('test.annual_payment')::bigint,2)),('annual_future',public.get_subscription_credit_grant_context_v1('b2460000-0000-4000-8000-000000000003',current_setting('test.annual_payment')::bigint,4));
select is((select v#>>'{terms,quantity}'from p246 where k='annual_terms1'),'10','annual billing preserves the monthly credit quantity');
select lives_ok($$select public.issue_subscription_credit_grant_v1('b2460000-0000-4000-8000-000000000003',current_setting('test.annual_payment')::bigint,1,(select v#>>'{terms,terms_hash}'from p246 where k='annual_terms1'),'funding246-annual-month1')$$,'the first monthly slot of an annual payment can issue');
select lives_ok($$select public.issue_subscription_credit_grant_v1('b2460000-0000-4000-8000-000000000003',current_setting('test.annual_payment')::bigint,2,(select v#>>'{terms,terms_hash}'from p246 where k='annual_terms2'),'funding246-annual-month2')$$,'a distinct already due monthly slot is not treated as a duplicate');
select throws_ok($$select public.issue_subscription_credit_grant_v1('b2460000-0000-4000-8000-000000000003',current_setting('test.annual_payment')::bigint,4,(select v#>>'{terms,terms_hash}'from p246 where k='annual_future'),'funding246-annual-future')$$,'55000','CREDIT_SUBSCRIPTION_GRANT_NOT_DUE','an annual payment cannot release future monthly credits early');
select throws_ok($$select public.get_subscription_credit_grant_context_v1('b2460000-0000-4000-8000-000000000003',current_setting('test.annual_payment')::bigint,13)$$,'22023','CREDIT_SUBSCRIPTION_GRANT_MONTH_INVALID','annual grants are bounded to the twelve funded months');
select is((select count(*)::integer from public.credit_lot_payment_sources_v1 where payment_event_id=current_setting('test.annual_payment')::bigint),2,'future or invalid monthly grants leave no funding binding');
select throws_ok($$select public.get_subscription_credit_grant_context_v1('b2460000-0000-4000-8000-000000000001',current_setting('test.live_payment')::bigint,1)$$,'55000','CREDIT_SUBSCRIPTION_PAYMENT_SOURCE_REQUIRED','a payment from a different organization cannot be attached to the selected wallet');
select set_config('request.jwt.claims','{"sub":"a2460000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select throws_ok($$select public.issue_subscription_credit_grant_v1('b2460000-0000-4000-8000-000000000001',current_setting('test.demo_payment')::bigint,1,(select v#>>'{terms,terms_hash}'from p246 where k='terms'),'funding246-subscription-grant')$$,'42501','CREDIT_SUBSCRIPTION_GRANT_DENIED','AAL1 cannot even replay a sensitive grant');
set local role authenticated;
select set_config('request.jwt.claim.sub','a2460000-0000-4000-8000-000000000002',true);select set_config('request.jwt.claims','{"sub":"a2460000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);
select is((select count(*)::integer from public.credit_lot_payment_sources_v1 where organization_id='b2460000-0000-4000-8000-000000000001'),0,'another tenant cannot read funding provenance rows');
select throws_ok($$select public.list_credit_lot_funding_statuses_v1(array['b2460000-0000-4000-8000-000000000001'::uuid])$$,'42501','CREDIT_FUNDING_READ_DENIED','the status RPC rejects a foreign organization before returning any inventory');
select lives_ok($$select public.list_credit_lot_funding_statuses_v1(array['b2460000-0000-4000-8000-000000000002'::uuid])$$,'a member may read the status of their own historical lots');
select throws_ok($$select public.get_subscription_credit_grant_context_v1('b2460000-0000-4000-8000-000000000002',current_setting('test.live_payment')::bigint,1)$$,'42501','CREDIT_SUBSCRIPTION_GRANT_DENIED','a Client owner does not become a platform credit issuer');
select ok(not has_table_privilege('authenticated','public.credit_lot_payment_sources_v1','INSERT')and not has_table_privilege('service_role','public.credit_lot_payment_sources_v1','INSERT'),'neither authenticated users nor generic service role can fabricate funding bindings');
reset role;
select ok(not has_function_privilege('authenticated','private.subscription_credit_grant_terms_v1(uuid,bigint,integer)','EXECUTE'),'the privileged canonical terms helper is not an API bypass');
reset role;
select *from finish();
rollback;
