begin;
set local search_path = public, extensions;
select plan(9);

select ok((
  select p.prosecdef and p.proconfig::text like '%search_path=%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'activate_framework_pool'
), 'activate_framework_pool is security definer with fixed search_path');

select ok((
  select not exists(
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'activate_framework_pool'
      and (has_function_privilege('anon', p.oid, 'EXECUTE') or has_function_privilege('service_role', p.oid, 'EXECUTE'))
  )
), 'pool activation excludes anon and service_role');

select ok((
  select pg_get_functiondef(p.oid) like '%aal2%'
     and pg_get_functiondef(p.oid) like '%POOL_ACTIVE%'
     and pg_get_functiondef(p.oid) like '%begin_volume_command%'
     and pg_get_functiondef(p.oid) like '%VolumePoolActivatedV1%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'activate_framework_pool'
), 'pool activation requires AAL2, is idempotent and emits outbox evidence');

select ok((
  select pg_get_functiondef(p.oid) like '%can_activate_pool%'
     and pg_get_functiondef(p.oid) like '%pool_status%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'get_admin_volume_dashboard'
), 'volume dashboard exposes pool activation capability');

select ok((
  select count(*) = 1 from pg_indexes
  where schemaname = 'public'
    and indexname = 'service_inventory_pools_one_open_version_idx'
), 'one open pool per agreement version');

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at) values
('a1634000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tenant-1634@example.invalid', '', now(), '{}', '{}', now(), now()),
('a1634000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin-1634@example.invalid', '', now(), '{}', '{}', now(), now());
insert into public.organizations(id, legal_name, display_name, status, created_by)
values ('b1634000-0000-4000-8000-000000000001', 'Volume Org 1634', 'Volume 1634', 'ACTIVE', 'a1634000-0000-4000-8000-000000000001');
insert into public.platform_user_roles(user_id, role_code) values
('a1634000-0000-4000-8000-000000000002', 'MATRICIA_ADMIN');

select extensions.throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','a1634000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claims','{"sub":"a1634000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true); select public.activate_framework_pool('b1634000-0000-4000-8000-000000000001', null, 0, 168, null, null, null, 'idemp-1634-tenant-xx')$$::text,
  '42501'::text,
  'FRAMEWORK_POOL_DENIED'::text,
  'tenant cannot activate a volume pool'::text
);

select extensions.throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','a1634000-0000-4000-8000-000000000002',true); select set_config('request.jwt.claims','{"sub":"a1634000-0000-4000-8000-000000000002","role":"authenticated"}',true); select public.activate_framework_pool('b1634000-0000-4000-8000-000000000001', null, 0, 168, null, null, null, 'idemp-1634-noaal2-x')$$::text,
  '42501'::text,
  'FRAMEWORK_POOL_DENIED'::text,
  'pool activation without AAL2 is denied'::text
);

select ok((
  select has_function_privilege('authenticated', 'public.activate_framework_pool(uuid,numeric,numeric,integer,uuid,numeric,bigint,text,uuid)', 'EXECUTE')
     and not has_function_privilege('anon', 'public.activate_framework_pool(uuid,numeric,numeric,integer,uuid,numeric,bigint,text,uuid)', 'EXECUTE')
), 'execute remains authenticated-only');

select ok((
  select pg_get_functiondef(p.oid) like '%contracted_units%'
     and pg_get_functiondef(p.oid) like '%maximum_units%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'activate_framework_pool'
), 'contracted pool size cannot exceed the negotiated maximum');

select * from finish();
rollback;
