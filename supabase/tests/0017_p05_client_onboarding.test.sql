begin;
set local search_path = public, extensions;
select plan(37);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
('b1700000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p05-owner-a@example.invalid','',now(),'{}','{}',now(),now()),
('b1700000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p05-owner-b@example.invalid','',now(),'{}','{}',now(),now()),
('b1700000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p05-compliance@example.invalid','',now(),'{}','{}',now(),now());

insert into public.organizations (id, legal_name, display_name, status, created_by) values
('b1710000-0000-0000-0000-000000000001','P05 Client A SARL','P05 Client A','PENDING','b1700000-0000-0000-0000-000000000001'),
('b1710000-0000-0000-0000-000000000002','P05 Client B SARL','P05 Client B','PENDING','b1700000-0000-0000-0000-000000000002');
insert into public.organization_identifiers (
  organization_id, identifier_type, normalized_value, verification_status, is_active
) values
('b1710000-0000-0000-0000-000000000001','ICE','P05CLIENTA001','PENDING',true),
('b1710000-0000-0000-0000-000000000002','ICE','P05CLIENTB002','PENDING',true);
insert into public.organization_memberships (
  id, organization_id, user_id, status, activated_at
) values
('b1720000-0000-0000-0000-000000000001','b1710000-0000-0000-0000-000000000001','b1700000-0000-0000-0000-000000000001','ACTIVE',now()),
('b1720000-0000-0000-0000-000000000002','b1710000-0000-0000-0000-000000000002','b1700000-0000-0000-0000-000000000002','ACTIVE',now());
insert into public.organization_member_roles (membership_id, role_code) values
('b1720000-0000-0000-0000-000000000001','CLIENT_OWNER'),
('b1720000-0000-0000-0000-000000000002','CLIENT_OWNER');
insert into public.platform_user_roles (user_id, role_code) values
('b1700000-0000-0000-0000-000000000003','COMPLIANCE_MANAGER');

create temporary table p05_fixture (key text primary key, payload jsonb not null);
create temporary table p05_observed (key text primary key, value jsonb not null);
grant select on p05_fixture to authenticated;
grant select, insert on p05_observed to authenticated;

insert into p05_fixture values
('a', jsonb_build_object(
  'legal_form','SARL', 'incorporation_date','2020-02-20',
  'activity','Conseil aux entreprises', 'sector','Services professionnels',
  'employee_count',12, 'registered_city','Casablanca',
  'registered_address',jsonb_build_object('line1','10 rue Exemple','postal_code','20000','country_code','MA'),
  'contact',jsonb_build_object('phone','+212522000001','email','contact-a@example.invalid'),
  'representative',jsonb_build_object(
    'first_name','Amal','last_name','Alami','title','Gérante',
    'email','amal.alami@example.invalid','phone','+212600000001','power','Gérante statutaire'
  ),
  'declarations',jsonb_build_object('accuracy_confirmed',true,'representation_authorized',true),
  'if_number','IF-A-001', 'rc_number','RC-A-001'
)),
('b', jsonb_build_object(
  'legal_form','SARL', 'incorporation_date','2019-03-10',
  'activity','Services numériques', 'sector','Technologies',
  'employee_count',8, 'registered_city','Rabat',
  'registered_address',jsonb_build_object('line1','20 avenue Exemple','postal_code','10000','country_code','MA'),
  'contact',jsonb_build_object('phone','+212537000002','email','contact-b@example.invalid'),
  'representative',jsonb_build_object(
    'first_name','Nadia','last_name','Bennani','title','Directrice',
    'email','nadia.bennani@example.invalid','phone','+212600000002','power','Mandat de représentation'
  ),
  'declarations',jsonb_build_object('accuracy_confirmed',true,'representation_authorized',true),
  'if_number','IF-B-002', 'rc_number','RC-B-002'
));

set local role authenticated;
select set_config('request.jwt.claim.sub','b1700000-0000-0000-0000-000000000001',true);
insert into p05_observed values ('save-a', public.save_client_profile_draft(
  'b1710000-0000-0000-0000-000000000001',
  (select payload from p05_fixture where key='a'), 'p05-save-client-a-0001'
));
insert into p05_observed values ('save-a-retry', public.save_client_profile_draft(
  'b1710000-0000-0000-0000-000000000001',
  (select payload from p05_fixture where key='a'), 'p05-save-client-a-0001'
));
reset role;

select is((select value->>'outcome' from p05_observed where key='save-a'),
  'CLIENT_PROFILE_VERSION_CREATED','a Client Owner creates a server-validated company profile version');
select is((select value from p05_observed where key='save-a-retry'),
  (select value from p05_observed where key='save-a'),'profile save retries return the stored response');
select is((select count(*) from public.client_profile_versions where organization_id='b1710000-0000-0000-0000-000000000001'),
  1::bigint,'an idempotent retry creates no profile version duplicate');
select is((select current_profile_version from public.client_compliance_cases where organization_id='b1710000-0000-0000-0000-000000000001'),
  1,'the compliance case points to version one');
select is((select organization_snapshot->>'legal_name' from public.client_profile_versions where organization_id='b1710000-0000-0000-0000-000000000001'),
  'P05 Client A SARL','the version snapshots legal identity from the shared organization passport');
select is((select count(*) from public.organization_identifiers where organization_id='b1710000-0000-0000-0000-000000000001' and identifier_type in ('IF','RC') and verification_status='UNVERIFIED'),
  2::bigint,'IF and RC remain explicitly unverified without an authorized registry adapter');
select is((select count(*) from public.client_trials where organization_id='b1710000-0000-0000-0000-000000000001'),
  0::bigint,'saving a profile never starts a trial');

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','b1700000-0000-0000-0000-000000000002',true);
    select public.save_client_profile_draft(
      'b1710000-0000-0000-0000-000000000001',
      (select payload from p05_fixture where key='a'), 'p05-cross-tenant-save-key'
    )$$,
  '42501','FORBIDDEN','another tenant cannot mutate the client profile');
reset role;

update public.organization_identifiers
set verification_status = 'VERIFIED'
where organization_id = 'b1710000-0000-0000-0000-000000000001'
  and identifier_type in ('ICE','IF','RC') and is_active;
insert into public.client_compliance_evidence (
  compliance_case_id, organization_id, evidence_type, object_path, file_sha256,
  review_status, reviewed_by, reviewed_at, created_by
) values
((select (value->>'compliance_case_id')::uuid from p05_observed where key='save-a'),
 'b1710000-0000-0000-0000-000000000001','REGISTRATION_DOCUMENT',
 'compliance/client-a/registration.pdf',repeat('a',64),'VERIFIED',
 'b1700000-0000-0000-0000-000000000003',clock_timestamp(),'b1700000-0000-0000-0000-000000000001'),
((select (value->>'compliance_case_id')::uuid from p05_observed where key='save-a'),
 'b1710000-0000-0000-0000-000000000001','REPRESENTATIVE_AUTHORITY',
 'compliance/client-a/authority.pdf',repeat('b',64),'VERIFIED',
 'b1700000-0000-0000-0000-000000000003',clock_timestamp(),'b1700000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','b1700000-0000-0000-0000-000000000002',true);
insert into p05_observed values ('profile-a-visible-to-b', jsonb_build_object(
  'count',(select count(*) from public.client_profile_versions where organization_id='b1710000-0000-0000-0000-000000000001')
));
reset role;
select is((select (value->>'count')::bigint from p05_observed where key='profile-a-visible-to-b'),
  0::bigint,'profile RLS hides representative and company data across tenants');

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','b1700000-0000-0000-0000-000000000001',true);
    update public.client_profile_versions set profile_data='{}'::jsonb
    where organization_id='b1710000-0000-0000-0000-000000000001'$$,
  '42501',null,'authenticated clients cannot directly rewrite profile history');
reset role;
select throws_ok(
  $$update public.client_profile_versions set profile_data='{}'::jsonb
    where organization_id='b1710000-0000-0000-0000-000000000001'$$,
  '55000','IMMUTABLE_RECORD','profile versions are immutable even for privileged SQL');

set local role authenticated;
select set_config('request.jwt.claim.sub','b1700000-0000-0000-0000-000000000001',true);
insert into p05_observed values ('submit-a', public.submit_client_compliance(
  (select (value->>'compliance_case_id')::uuid from p05_observed where key='save-a'),
  'p05-submit-client-a-0001'
));
insert into p05_observed values ('submit-a-retry', public.submit_client_compliance(
  (select (value->>'compliance_case_id')::uuid from p05_observed where key='save-a'),
  'p05-submit-client-a-0001'
));
reset role;
select is((select value->>'status' from p05_observed where key='submit-a'),
  'UNDER_REVIEW','profile submission enters the explicit review state');
select is((select value from p05_observed where key='submit-a-retry'),
  (select value from p05_observed where key='submit-a'),'submission is idempotent');
select is((select count(*) from public.client_trials where organization_id='b1710000-0000-0000-0000-000000000001'),
  0::bigint,'submission and review still do not start the trial');

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','b1700000-0000-0000-0000-000000000001',true);
    select public.decide_client_compliance(
      (select (value->>'compliance_case_id')::uuid from p05_observed where key='save-a'),
      'VERIFIED',null,'p05-owner-self-verify-key'
    )$$,
  '42501','CENTRAL_COMPLIANCE_APPROVAL_REQUIRED','a tenant owner cannot self-validate compliance');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','b1700000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"b1700000-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2"}',true);
insert into p05_observed values ('verify-a', public.decide_client_compliance(
  (select (value->>'compliance_case_id')::uuid from p05_observed where key='save-a'),
  'VERIFIED',null,'p05-central-verify-a-0001'
));
insert into p05_observed values ('verify-a-retry', public.decide_client_compliance(
  (select (value->>'compliance_case_id')::uuid from p05_observed where key='save-a'),
  'VERIFIED',null,'p05-central-verify-a-0001'
));
reset role;

select is((select status from public.client_compliance_cases where organization_id='b1710000-0000-0000-0000-000000000001'),
  'VERIFIED','central compliance validates the submitted case');
select is((select status from public.organizations where id='b1710000-0000-0000-0000-000000000001'),
  'ACTIVE','verification atomically activates the organization');
select is((select status from public.client_trials where organization_id='b1710000-0000-0000-0000-000000000001'),
  'TRIAL_ACTIVE','a trial starts only on verified activation');
select is((select trial_ends_at-trial_started_at from public.client_trials where organization_id='b1710000-0000-0000-0000-000000000001'),
  interval '30 days','the free trial lasts exactly 30 calendar days');
select is((select value from p05_observed where key='verify-a-retry'),
  (select value from p05_observed where key='verify-a'),'central verification retry is idempotent');
select is((select count(*) from public.client_trials where organization_id='b1710000-0000-0000-0000-000000000001'),
  1::bigint,'verification retries never create a second trial');
select ok(not exists(
  select 1 from information_schema.columns
  where table_schema='public' and table_name='client_trials' and column_name like '%payment%'
),'the trial lifecycle stores and requires no card or payment method');

select is((select count(*) from public.audit_events where organization_id='b1710000-0000-0000-0000-000000000001' and action='client.profile.version.created'),
  1::bigint,'profile creation is audited once');
select is((select count(*) from public.event_outbox where organization_id='b1710000-0000-0000-0000-000000000001' and event_type='ClientComplianceSubmittedV1'),
  1::bigint,'submission emits one durable Outbox event');
select is((select count(*) from public.audit_events where organization_id='b1710000-0000-0000-0000-000000000001' and action='client.trial.started'),
  1::bigint,'trial activation is audited exactly once');
select is((select count(*) from public.event_outbox where organization_id='b1710000-0000-0000-0000-000000000001' and event_type='TrialStartedV1'),
  1::bigint,'trial activation emits one durable event');

set local role authenticated;
select set_config('request.jwt.claim.sub','b1700000-0000-0000-0000-000000000002',true);
insert into p05_observed values ('save-b', public.save_client_profile_draft(
  'b1710000-0000-0000-0000-000000000002',
  (select payload from p05_fixture where key='b'), 'p05-save-client-b-0001'
));
select public.submit_client_compliance(
  (select (value->>'compliance_case_id')::uuid from p05_observed where key='save-b'),
  'p05-submit-client-b-0001'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b1700000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"b1700000-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2"}',true);
select public.decide_client_compliance(
  (select (value->>'compliance_case_id')::uuid from p05_observed where key='save-b'),
  'REJECTED','Justificatif de représentation à corriger','p05-central-reject-b-0001'
);
reset role;
select is((select status from public.client_compliance_cases where organization_id='b1710000-0000-0000-0000-000000000002'),
  'REJECTED','central compliance can reject with a client-visible reason');
select is((select count(*) from public.client_trials where organization_id='b1710000-0000-0000-0000-000000000002'),
  0::bigint,'a rejected case never starts a trial');

set local role authenticated;
select set_config('request.jwt.claim.sub','b1700000-0000-0000-0000-000000000002',true);
insert into p05_observed values ('correct-b', public.save_client_profile_draft(
  'b1710000-0000-0000-0000-000000000002',
  (select payload || jsonb_build_object('activity','Services numériques et conseil') from p05_fixture where key='b'),
  'p05-correct-client-b-0002'
));
reset role;
select is((select current_profile_version from public.client_compliance_cases where organization_id='b1710000-0000-0000-0000-000000000002'),
  2,'a rejected client can create a corrected immutable version');
select is((select status from public.client_compliance_cases where organization_id='b1710000-0000-0000-0000-000000000002'),
  'PROFILE_IN_PROGRESS','correction explicitly returns the case to profile preparation');
select is((select profile_data->>'activity' from public.client_profile_versions where organization_id='b1710000-0000-0000-0000-000000000002' and version=1),
  'Services numériques','correction preserves the original profile version');
select is((select profile_data->>'activity' from public.client_profile_versions where organization_id='b1710000-0000-0000-0000-000000000002' and version=2),
  'Services numériques et conseil','the corrected profile is stored as version two');

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','b1700000-0000-0000-0000-000000000002',true);
    select public.save_client_profile_draft(
      'b1710000-0000-0000-0000-000000000002',
      (select payload #- '{declarations}' from p05_fixture where key='b'),
      'p05-invalid-client-b-key'
    )$$,
  '22023','CLIENT_PROFILE_REQUIRED_FIELDS_MISSING','required declarations are server validated');
reset role;
select is((select count(*) from public.client_profile_versions where organization_id='b1710000-0000-0000-0000-000000000002'),
  2::bigint,'an invalid profile produces no partial version');

select ok(not has_table_privilege('authenticated','public.client_compliance_cases','INSERT'),
  'authenticated clients cannot bypass onboarding RPCs with direct inserts');
select ok(not has_function_privilege('anon','public.save_client_profile_draft(uuid,jsonb,text,uuid)','EXECUTE'),
  'anonymous actors cannot call the profile mutation RPC');
select ok(has_function_privilege('authenticated','public.submit_client_compliance(uuid,text,uuid)','EXECUTE'),
  'authenticated actors receive only the guarded compliance RPC surface');

select * from finish();
rollback;
