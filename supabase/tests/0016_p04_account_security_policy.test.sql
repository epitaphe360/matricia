begin;
set local search_path = public, extensions;
select plan(15);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
('a1600000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p04-security-standard@example.invalid','',now(),'{}','{}',now(),now()),
('a1600000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p04-security-admin@example.invalid','',now(),'{}','{}',now(),now());
insert into public.platform_user_roles (user_id, role_code)
values ('a1600000-0000-0000-0000-000000000002','FINANCE_MANAGER');

select is((select count(*) from public.role_security_policy_versions where status='ACTIVE'),8::bigint,'all eight central roles have an active security policy');
select ok((select bool_and(mfa_required) from public.role_security_policy_versions where status='ACTIVE'),'MFA is required for every active central role policy');
select is((select count(*) from public.role_security_policy_versions where role_code='FINANCE_MANAGER' and version=1),1::bigint,'the finance policy is explicitly versioned');

create temporary table p04_security_observed (key text primary key, value jsonb not null);
grant select, insert on p04_security_observed to authenticated, service_role;

set local role authenticated;
select set_config('request.jwt.claim.sub','a1600000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"a1600000-0000-0000-0000-000000000001","email":"p04-security-standard@example.invalid","role":"authenticated","aal":"aal1"}',true);
insert into p04_security_observed
select 'standard',to_jsonb(requirement) from public.get_my_account_security_requirement() requirement;
reset role;
select is((select value->>'mfa_required' from p04_security_observed where key='standard'),'false','a standard user is not forced into MFA by a platform policy');
select is((select value->>'requirement_satisfied' from p04_security_observed where key='standard'),'true','a standard user satisfies the default account policy');

set local role authenticated;
select set_config('request.jwt.claim.sub','a1600000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"a1600000-0000-0000-0000-000000000002","email":"p04-security-admin@example.invalid","role":"authenticated","aal":"aal1"}',true);
insert into p04_security_observed
select 'admin_aal1',to_jsonb(requirement) from public.get_my_account_security_requirement() requirement;
reset role;
select is((select value->>'mfa_required' from p04_security_observed where key='admin_aal1'),'true','a finance manager requires MFA');
select is((select value->>'requirement_satisfied' from p04_security_observed where key='admin_aal1'),'false','aal1 does not satisfy a central role policy');
select is((select value->>'matched_role_codes' from p04_security_observed where key='admin_aal1'),'["FINANCE_MANAGER"]','the requirement explains the matched central role');

set local role authenticated;
select set_config('request.jwt.claim.sub','a1600000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"a1600000-0000-0000-0000-000000000002","email":"p04-security-admin@example.invalid","role":"authenticated","aal":"aal2"}',true);
insert into p04_security_observed
select 'admin_aal2',to_jsonb(requirement) from public.get_my_account_security_requirement() requirement;
reset role;
select is((select value->>'requirement_satisfied' from p04_security_observed where key='admin_aal2'),'true','aal2 satisfies a central role policy');

select ok(not has_function_privilege('anon','public.get_my_account_security_requirement()','EXECUTE'),'anonymous actors cannot query account requirements');
select ok(has_function_privilege('authenticated','public.get_my_account_security_requirement()','EXECUTE'),'authenticated users can query only their own requirement');
select ok(not has_function_privilege('authenticated','public.record_account_security_event(uuid,text,text,uuid)','EXECUTE'),'authenticated clients cannot forge security audit events');
select ok(not has_table_privilege('authenticated','public.role_security_policy_versions','UPDATE'),'runtime users cannot rewrite active security policy versions');

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select public.record_account_security_event(
  'a1600000-0000-0000-0000-000000000002','identity.password.updated','password',
  'a1610000-0000-4000-8000-000000000001'
);
reset role;
select is((select count(*) from public.audit_events where correlation_id='a1610000-0000-4000-8000-000000000001'),1::bigint,'the trusted bridge records one immutable security audit event');
select is((select count(*) from public.event_outbox where correlation_id='a1610000-0000-4000-8000-000000000001' and event_type='UserPasswordUpdatedV1'),1::bigint,'the trusted bridge emits the matching Outbox event');

select * from finish();
rollback;
