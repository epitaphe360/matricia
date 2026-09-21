begin;
set local search_path = public, extensions;
select plan(10);

select ok(
  has_function_privilege('authenticated', 'public.list_admin_supervision_projection(integer)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.list_admin_supervision_projection(integer)', 'EXECUTE'),
  'supervision projection execute is authenticated-only'
);
select ok(
  has_function_privilege('authenticated', 'public.get_admin_organization_fiche(uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.get_admin_organization_fiche(uuid)', 'EXECUTE'),
  'organization fiche execute is authenticated-only'
);
select ok((
  select prosecdef and provolatile = 's' and proconfig::text like '%search_path=pg_catalog%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'list_admin_supervision_projection'
), 'supervision projection is stable security definer with fixed search path');
select ok((
  select pg_get_functiondef(p.oid) !~* '\m(insert|update|delete)\M'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'list_admin_supervision_projection'
), 'supervision projection exposes no mutation verbs');

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at) values
('a1612000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tenant-1612@example.invalid', '', now(), '{}', '{}', now(), now()),
('a1612000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin-1612@example.invalid', '', now(), '{}', '{}', now(), now()),
('a1612000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'auditor-1612@example.invalid', '', now(), '{}', '{}', now(), now());
insert into public.organizations(id, legal_name, display_name, status, created_by)
values ('b1612000-0000-4000-8000-000000000001', 'Supervision Org 1612', 'Supervision 1612', 'ACTIVE', 'a1612000-0000-4000-8000-000000000001');
insert into public.organization_memberships(id, organization_id, user_id, status, activated_at)
values ('c1612000-0000-4000-8000-000000000001', 'b1612000-0000-4000-8000-000000000001', 'a1612000-0000-4000-8000-000000000001', 'ACTIVE', now());
insert into public.organization_member_roles(membership_id, role_code)
values ('c1612000-0000-4000-8000-000000000001', 'CLIENT_ADMIN');
insert into public.platform_user_roles(user_id, role_code) values
('a1612000-0000-4000-8000-000000000002', 'MATRICIA_ADMIN'),
('a1612000-0000-4000-8000-000000000003', 'READ_ONLY_AUDITOR');

select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','a1612000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claims','{"sub":"a1612000-0000-4000-8000-000000000001","role":"authenticated"}',true); select public.list_admin_supervision_projection(10)$$,
  '42501',
  'ADMIN_SUPERVISION_DENIED',
  'tenant role is denied supervision projection'
);

create temporary table p1612_observed(role_code text primary key, value jsonb);
grant select, insert on p1612_observed to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1612000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claims', '{"sub":"a1612000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}', true);
insert into p1612_observed values ('MATRICIA_ADMIN', public.list_admin_supervision_projection(20));
insert into p1612_observed values ('FICHE', public.get_admin_organization_fiche('b1612000-0000-4000-8000-000000000001'));
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1612000-0000-4000-8000-000000000003', true);
select set_config('request.jwt.claims', '{"sub":"a1612000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal2"}', true);
insert into p1612_observed values ('READ_ONLY_AUDITOR', public.list_admin_supervision_projection(5));
reset role;

select ok((select value ? 'organizations' and value ? 'requests' and value ? 'quotes' and value ? 'missions' and value ? 'diagnostics' from p1612_observed where role_code = 'MATRICIA_ADMIN'), 'admin projection returns parcours keys');
select ok((select (value->>'read_only')::boolean is false from p1612_observed where role_code = 'MATRICIA_ADMIN'), 'matricia admin is not forced read-only');
select ok((select (value->>'read_only')::boolean is true from p1612_observed where role_code = 'READ_ONLY_AUDITOR'), 'auditor projection is read-only');
select ok((select value ? 'organization' and value ? 'timeline' and value ? 'memberships' from p1612_observed where role_code = 'FICHE'), 'organization fiche returns composed sections');
select is((select value->'organization'->>'display_name' from p1612_observed where role_code = 'FICHE'), 'Supervision 1612', 'fiche resolves the requested organization');

select * from finish();
rollback;
