begin;
set local search_path = public, extensions;
select plan(14);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  'f1520000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'rpc-negative-member@example.invalid', '', now(),
  '{}', '{}', now(), now()
);

insert into public.organizations (id, legal_name, display_name, status, created_by) values
  ('f1521000-0000-4000-8000-000000000001', 'RPC Negative Own SARL', 'RPC Negative Own', 'ACTIVE', 'f1520000-0000-4000-8000-000000000001'),
  ('f1521000-0000-4000-8000-000000000002', 'RPC Negative Foreign SARL', 'RPC Negative Foreign', 'ACTIVE', 'f1520000-0000-4000-8000-000000000001');

insert into public.organization_memberships (id, organization_id, user_id, status, activated_at)
values ('f1522000-0000-4000-8000-000000000001', 'f1521000-0000-4000-8000-000000000001', 'f1520000-0000-4000-8000-000000000001', 'ACTIVE', now());

insert into public.organization_member_roles (membership_id, role_code)
values ('f1522000-0000-4000-8000-000000000001', 'CLIENT_MEMBER');

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','f1520000-0000-4000-8000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"f1520000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
    select public.list_admin_finance_dashboard(10)$$,
  '42501', 'ADMIN_FINANCE_DASHBOARD_DENIED',
  'ordinary tenant member cannot read the global finance dashboard'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','f1520000-0000-4000-8000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"f1520000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
    select public.get_admin_volume_dashboard()$$,
  '42501', 'ADMIN_VOLUME_DASHBOARD_DENIED',
  'ordinary tenant member cannot read the global volume dashboard'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','f1520000-0000-4000-8000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"f1520000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
    select public.record_security_control_result('RLS_TEST','DEVELOPMENT','REQUIRED_NOT_COMPLETED',null,null,null,null,null,'Negative authorization test','rpc-negative-security-control','f1523000-0000-4000-8000-000000000001')$$,
  '42501', 'SECURITY_EVIDENCE_AAL2_REQUIRED',
  'ordinary tenant member cannot record platform security evidence'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','f1520000-0000-4000-8000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"f1520000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
    select public.get_admin_client_compliance_projection('fr',10)$$,
  '42501', 'CLIENT_COMPLIANCE_ADMIN_SCOPE_REQUIRED',
  'ordinary tenant member cannot read the administration compliance projection'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','f1520000-0000-4000-8000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"f1520000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
    select public.explain_client_compliance_four_eyes('f1524000-0000-4000-8000-000000000001')$$,
  '42501', 'CLIENT_COMPLIANCE_ADMIN_SCOPE_REQUIRED',
  'ordinary tenant member cannot inspect four-eyes administration details'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','f1520000-0000-4000-8000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"f1520000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
    select * from public.get_questionnaire_abandonment_policy()$$,
  '42501', 'QUESTIONNAIRE_ANALYTICS_READ_DENIED',
  'ordinary tenant member cannot read restricted questionnaire analytics policy'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','f1520000-0000-4000-8000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"f1520000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
    select * from public.get_questionnaire_abandonment_analytics(current_date-7,current_date,null,10)$$,
  '42501', 'QUESTIONNAIRE_ANALYTICS_READ_DENIED',
  'ordinary tenant member cannot read restricted questionnaire analytics'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','f1520000-0000-4000-8000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"f1520000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
    select public.list_dispute_reassignment_candidates('f1524000-0000-4000-8000-000000000002',10)$$,
  '42501', 'REASSIGNMENT_CANDIDATES_DENIED',
  'ordinary tenant member cannot enumerate reassignment candidates'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','f1520000-0000-4000-8000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"f1520000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
    select public.reconcile_provider_commission_forecast('f1524000-0000-4000-8000-000000000003','f1524000-0000-4000-8000-000000000004','unauthorized reconciliation','rpc-negative-commission','f1523000-0000-4000-8000-000000000002')$$,
  '42501', 'COMMISSION_FORECAST_RECONCILIATION_DENIED',
  'ordinary tenant member cannot reconcile provider commission forecasts'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','f1520000-0000-4000-8000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"f1520000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
    select public.evaluate_abuse_signal('f1521000-0000-4000-8000-000000000002','AUTH.FAILURE','USER',repeat('a',64),50,'{}','rpc-negative-abuse-signal','f1523000-0000-4000-8000-000000000003')$$,
  '42501', 'ABUSE_SIGNAL_DENIED',
  'tenant member cannot evaluate an abuse signal for a foreign organization'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','f1520000-0000-4000-8000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"f1520000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
    select public.create_abuse_rule_version('RPC_NEGATIVE','AUTH.FAILURE',300,5,50,80,'{}',false,'rpc-negative-abuse-rule','f1523000-0000-4000-8000-000000000004')$$,
  '42501', 'ABUSE_RULE_ADMIN_DENIED',
  'ordinary tenant member cannot create an abuse rule version'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','f1520000-0000-4000-8000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"f1520000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
    select public.record_prefill_fact('f1521000-0000-4000-8000-000000000002','profile.name','PROFILE',null,'"foreign"','BUSINESS',clock_timestamp(),'rpc-negative-prefill','f1523000-0000-4000-8000-000000000005')$$,
  '42501', 'PREFILL_FACT_DENIED',
  'tenant member cannot record prefill data for a foreign organization'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','f1520000-0000-4000-8000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"f1520000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
    select public.run_assisted_anomaly_similarity('f1521000-0000-4000-8000-000000000002','{}'::uuid[],'f1524000-0000-4000-8000-000000000005','rpc-negative-assistance','f1523000-0000-4000-8000-000000000006')$$,
  '42501', 'ASSISTANCE_ACCESS_DENIED',
  'tenant member cannot run assisted analysis for a foreign organization'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','f1520000-0000-4000-8000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"f1520000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
    select public.get_internal_message_thread('f1524000-0000-4000-8000-000000000006',20)$$,
  '42501', 'MESSAGE_THREAD_SCOPE_DENIED',
  'tenant member cannot read a message thread outside its scope'
);

select * from finish();
rollback;
