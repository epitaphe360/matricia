begin;
set local search_path = public, extensions;
select plan(8);

select ok((
  select p.prosecdef and p.proconfig::text like '%search_path=%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'create_credit_pack_version'
), 'credit pack draft is security definer with fixed search_path');

select ok((
  select pg_get_functiondef(p.oid) like '%issue_credits%'
     and pg_get_functiondef(p.oid) like '%EXTRA_PURCHASE%'
     and pg_get_functiondef(p.oid) like '%aal2%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'grant_credit_pack'
), 'pack grant reuses issue_credits and requires AAL2');

select ok((
  select pg_get_functiondef(p.oid) like '%PROMOTION%'
     and pg_get_functiondef(p.oid) like '%CREDIT_PROMOTION_MAX_BONUS%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'grant_credit_promotion'
), 'promotion grant respects the active bonus ceiling');

select ok((
  select pg_get_functiondef(p.oid) like '%DOCUMENT_EXPIRY_WARNING_DAYS%'
     and pg_get_functiondef(p.oid) like '%VOLUME_RESERVATION_DEFAULT_TTL_HOURS%'
     and pg_get_functiondef(p.oid) not like '%execute%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'create_platform_parameter_version'
), 'platform parameters stay on the allowlist');

select ok((
  select pg_get_functiondef(p.oid) not like '%storage_object_path%'
     and pg_get_functiondef(p.oid) like '%CLIENT%'
     and pg_get_functiondef(p.oid) like '%PROVIDER%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'list_admin_document_vault'
), 'document vault returns metadata without storage paths');

select ok((
  select pg_get_functiondef(p.oid) like '%forecast_units%'
     and pg_get_functiondef(p.oid) like '%reserved_units%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'list_admin_volume_demand'
), 'volume demand compares history with negotiated forecast');

select ok(
  not has_function_privilege('anon', 'public.create_credit_pack_version(uuid,text,text,text,bigint,bigint,text,integer,text,uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.list_admin_document_vault(integer)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.list_admin_commerce_catalog(integer)', 'EXECUTE'),
  'catalog and vault execute stay authenticated-only'
);

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('a1664000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tenant-1664@example.invalid', '', now(), '{}', '{}', now(), now());

select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','a1664000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claims','{"sub":"a1664000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true); select public.create_credit_pack_version('b1664000-0000-4000-8000-000000000001','PACK_IT','Pack','حزمة',10,1000,'MAD',30,'idemp-1664-tenant')$$,
  '42501',
  'CREDIT_CATALOG_DENIED',
  'tenant cannot draft a credit pack'
);

select * from finish();
rollback;
