begin;
set local search_path=public,extensions;
select plan(16);

select ok(
  has_function_privilege('authenticated','public.list_admin_operations_projection(integer)','EXECUTE')
  and not has_function_privilege('anon','public.list_admin_operations_projection(integer)','EXECUTE')
  and not has_function_privilege('service_role','public.list_admin_operations_projection(integer)','EXECUTE'),
  'projection execute is authenticated-only and excludes service role'
);
select ok((select prosecdef and provolatile='s' and proconfig::text like '%search_path=pg_catalog%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='list_admin_operations_projection'),
  'projection is stable security definer with fixed search path'
);
select ok((select pg_get_functiondef(p.oid)!~*'(payload|recipient_user_id|variables_snapshot|request_ip|user_agent|metadata)'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='list_admin_operations_projection'),
  'projection definition excludes payload, PII, recipient and audit metadata columns'
);
select ok((select pg_get_functiondef(p.oid)!~*'\m(insert|update|delete|retry|replay)\M'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='list_admin_operations_projection'),
  'projection exposes no mutation, retry or replay action'
);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values
('a9600000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','tenant-96@example.invalid','',now(),'{}','{}',now(),now()),
('a9600000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','finance-96@example.invalid','',now(),'{}','{}',now(),now()),
('a9600000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','super-96@example.invalid','',now(),'{}','{}',now(),now()),
('a9600000-0000-4000-8000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','admin-96@example.invalid','',now(),'{}','{}',now(),now()),
('a9600000-0000-4000-8000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','auditor-96@example.invalid','',now(),'{}','{}',now(),now()),
('a9600000-0000-4000-8000-000000000006','00000000-0000-0000-0000-000000000000','authenticated','authenticated','revoked-admin-96@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)values('b9600000-0000-4000-8000-000000000001','Operations Security 96','Operations 96','ACTIVE','a9600000-0000-4000-8000-000000000001');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at)values('c9600000-0000-4000-8000-000000000001','b9600000-0000-4000-8000-000000000001','a9600000-0000-4000-8000-000000000001','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code)values('c9600000-0000-4000-8000-000000000001','CLIENT_ADMIN');
insert into public.platform_user_roles(user_id,role_code)values
('a9600000-0000-4000-8000-000000000002','FINANCE_MANAGER'),
('a9600000-0000-4000-8000-000000000003','SUPER_ADMIN'),
('a9600000-0000-4000-8000-000000000004','MATRICIA_ADMIN'),
('a9600000-0000-4000-8000-000000000005','READ_ONLY_AUDITOR'),
('a9600000-0000-4000-8000-000000000006','MATRICIA_ADMIN');
update public.platform_user_roles set revoked_at=now() where user_id='a9600000-0000-4000-8000-000000000006';

select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','a9600000-0000-4000-8000-000000000006',true);select set_config('request.jwt.claims','{"sub":"a9600000-0000-4000-8000-000000000006","role":"authenticated","aal":"aal2"}',true);select public.list_admin_operations_projection(10)$$,'42501','ADMIN_OPERATIONS_PROJECTION_DENIED','revoked platform role is denied at runtime');
select ok((select p.prosrc like '%has_platform_role%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='list_admin_operations_projection'),'projection delegates platform authorization to the canonical revocation-aware guard');
insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,attempt_count,last_error_code)
values('b9600000-0000-4000-8000-000000000001','security_fixture','hidden-id','SecurityFixtureV1','f9600000-0000-4000-8000-000000000001','{"recipient_user_id":"hidden","secret":"hidden"}',1,'unsafe free form detail');

select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','a9600000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a9600000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);select public.list_admin_operations_projection(10)$$,'42501','ADMIN_OPERATIONS_PROJECTION_DENIED','tenant organization role is denied');
select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','a9600000-0000-4000-8000-000000000002',true);select set_config('request.jwt.claims','{"sub":"a9600000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);select public.list_admin_operations_projection(10)$$,'42501','ADMIN_OPERATIONS_PROJECTION_DENIED','unlisted platform role is denied');

create temporary table p96_observed(role_code text primary key,value jsonb);
grant select,insert on p96_observed to authenticated;
set local role authenticated;select set_config('request.jwt.claim.sub','a9600000-0000-4000-8000-000000000003',true);select set_config('request.jwt.claims','{"sub":"a9600000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal2"}',true);insert into p96_observed values('SUPER_ADMIN',public.list_admin_operations_projection(1));reset role;
set local role authenticated;select set_config('request.jwt.claim.sub','a9600000-0000-4000-8000-000000000004',true);select set_config('request.jwt.claims','{"sub":"a9600000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal2"}',true);insert into p96_observed values('MATRICIA_ADMIN',public.list_admin_operations_projection(1));reset role;
set local role authenticated;select set_config('request.jwt.claim.sub','a9600000-0000-4000-8000-000000000005',true);select set_config('request.jwt.claims','{"sub":"a9600000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal2"}',true);insert into p96_observed values('READ_ONLY_AUDITOR',public.list_admin_operations_projection(1));reset role;
select ok((select value?'as_of' and value?'outbox_counts' and value?'delivery_counts' from p96_observed where role_code='SUPER_ADMIN'),'SUPER_ADMIN is allowed');
select ok((select value?'as_of' from p96_observed where role_code='MATRICIA_ADMIN'),'MATRICIA_ADMIN is allowed');
select ok((select value?'as_of' from p96_observed where role_code='READ_ONLY_AUDITOR'),'READ_ONLY_AUDITOR is allowed');
select is((select jsonb_array_length(value->'outbox') from p96_observed where role_code='SUPER_ADMIN'),1,'outbox projection obeys the requested bound');
select ok((select (value->'outbox'->0->>'error_code')='REDACTED' from p96_observed where role_code='SUPER_ADMIN'),'unstable error detail is redacted');
select ok((select value::text!~*'(hidden-id|recipient_user_id|secret|unsafe free form detail)' from p96_observed where role_code='SUPER_ADMIN'),'result excludes aggregate identity, payload, PII and raw error detail');
select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','a9600000-0000-4000-8000-000000000003',true);select set_config('request.jwt.claims','{"sub":"a9600000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal2"}',true);select public.list_admin_operations_projection(0)$$,'22023','INVALID_ADMIN_OPERATIONS_LIMIT','zero limit is denied');
select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','a9600000-0000-4000-8000-000000000003',true);select set_config('request.jwt.claims','{"sub":"a9600000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal2"}',true);select public.list_admin_operations_projection(201)$$,'22023','INVALID_ADMIN_OPERATIONS_LIMIT','limit above 200 is denied');

select * from finish();
rollback;
