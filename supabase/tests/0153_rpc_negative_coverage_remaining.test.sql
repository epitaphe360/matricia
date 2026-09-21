begin;
set local search_path = public, extensions;
select plan(15);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  'f1530000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'rpc-negative-remaining@example.invalid', '', now(),
  '{}', '{}', now(), now()
);

insert into public.organizations (id, legal_name, display_name, status, created_by) values
  ('f1531000-0000-4000-8000-000000000001', 'RPC Remaining Own SARL', 'RPC Remaining Own', 'ACTIVE', 'f1530000-0000-4000-8000-000000000001'),
  ('f1531000-0000-4000-8000-000000000002', 'RPC Remaining Foreign SARL', 'RPC Remaining Foreign', 'ACTIVE', 'f1530000-0000-4000-8000-000000000001');

insert into public.organization_memberships (id, organization_id, user_id, status, activated_at)
values ('f1532000-0000-4000-8000-000000000001', 'f1531000-0000-4000-8000-000000000001', 'f1530000-0000-4000-8000-000000000001', 'ACTIVE', now());

insert into public.organization_member_roles (membership_id, role_code)
values ('f1532000-0000-4000-8000-000000000001', 'CLIENT_MEMBER');

select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','f1530000-0000-4000-8000-000000000001',true); select public.configure_franchise_followup_preference('f1533000-0000-4000-8000-000000000001',true,true,'fr','Africa/Casablanca','22:00','07:00',3,'Unauthorized preference change','rpc-remain-pref','f1534000-0000-4000-8000-000000000001')$$,
  '42501','FRANCHISE_FOLLOWUP_PREFERENCE_DENIED','non-franchise member cannot configure a follow-up preference'
);

select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','f1530000-0000-4000-8000-000000000001',true); select public.confirm_notification_email_consent('f1531000-0000-4000-8000-000000000002','MARKETING',1,'invalid-token','rpc-remain-confirm','f1534000-0000-4000-8000-000000000002')$$,
  '42501','NOTIFICATION_EMAIL_CONSENT_DENIED','member cannot confirm consent for another tenant'
);

select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','f1530000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claims','{"sub":"f1530000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true); select public.decide_abuse_case('f1533000-0000-4000-8000-000000000002',1,'DISMISSED','Unauthorized decision',repeat('a',64),'rpc-remain-abuse','f1534000-0000-4000-8000-000000000003')$$,
  '42501','ABUSE_CASE_DECISION_DENIED','ordinary member cannot decide an abuse case'
);

select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','f1530000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claims','{"sub":"f1530000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true); select public.decide_franchise_followup_policy('f1533000-0000-4000-8000-000000000003','REJECT','Unauthorized policy decision','rpc-remain-decide','f1534000-0000-4000-8000-000000000004')$$,
  '42501','FRANCHISE_FOLLOWUP_POLICY_DECIDE_DENIED','ordinary member cannot decide a franchise follow-up policy'
);

select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','f1530000-0000-4000-8000-000000000001',true); select public.get_client_subscription_historical_plan_projection('f1533000-0000-4000-8000-000000000004',12)$$,
  '42501','SUBSCRIPTION_HISTORY_ACCESS_DENIED','member cannot read an unavailable subscription history'
);

select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','',true); select set_config('request.jwt.claims','{"role":"authenticated"}',true); select public.list_internal_message_inbox(20)$$,
  '42501','AUTHENTICATION_REQUIRED','unauthenticated caller cannot list an internal message inbox'
);

select is(
  (select count(*) from public.list_my_client_trials()),
  0::bigint,
  'caller without an authenticated identity cannot read client trials'
);

select ok(
  not has_function_privilege('anon','public.open_rfq_message_thread(uuid,uuid,text,text,uuid)','EXECUTE'),
  'anonymous caller cannot execute the RFQ message-thread command'
);

select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','f1530000-0000-4000-8000-000000000001',true); select public.propose_franchise_followup_policy('f1533000-0000-4000-8000-000000000005',array['SENT'],array[60],array[5],2,3,120,clock_timestamp()+interval '1 hour',clock_timestamp()+interval '30 days','Unauthorized policy proposal','rpc-remain-propose','f1534000-0000-4000-8000-000000000005')$$,
  '42501','FRANCHISE_FOLLOWUP_POLICY_PROPOSE_DENIED','non-franchise member cannot propose a follow-up policy'
);

select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','f1530000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claims','{"sub":"f1530000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true); select public.publish_questionnaire_abandonment_policy(10,7,365,'Unauthorized policy publication','rpc-remain-analytics','f1534000-0000-4000-8000-000000000006')$$,
  '42501','QUESTIONNAIRE_ANALYTICS_POLICY_MFA_REQUIRED','ordinary member cannot publish questionnaire analytics policy'
);

select is(
  (select count(*) from public.questionnaire_prefill_suggestions('f1533000-0000-4000-8000-000000000006')),
  0::bigint,
  'caller cannot obtain prefill suggestions for an unavailable questionnaire session'
);

select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','f1530000-0000-4000-8000-000000000001',true); select public.request_notification_email_consent('f1531000-0000-4000-8000-000000000002','MARKETING','rpc-remain-request','f1534000-0000-4000-8000-000000000007')$$,
  '42501','NOTIFICATION_EMAIL_CONSENT_DENIED','member cannot request consent for another tenant'
);

select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','',true); select set_config('request.jwt.claims','{"role":"authenticated"}',true); select public.revoke_my_session('f1533000-0000-4000-8000-000000000007','f1534000-0000-4000-8000-000000000008')$$,
  '42501','UNAUTHENTICATED','unauthenticated caller cannot revoke a session'
);

select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','f1530000-0000-4000-8000-000000000001',true); select public.revoke_notification_email_consent('f1531000-0000-4000-8000-000000000002','MARKETING',1,'rpc-remain-revoke','f1534000-0000-4000-8000-000000000009')$$,
  '42501','NOTIFICATION_EMAIL_CONSENT_DENIED','member cannot revoke consent for another tenant'
);

select ok(
  not has_function_privilege('anon','public.send_internal_message(uuid,uuid,text,jsonb,text,uuid)','EXECUTE'),
  'anonymous caller cannot execute the internal-message command'
);

select * from finish();
rollback;
