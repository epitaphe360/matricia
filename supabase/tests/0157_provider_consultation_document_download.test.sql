begin;
select plan(16);

select has_function(
  'public',
  'list_provider_consultation_documents',
  array['uuid'],
  'consultation document list exists'
);
select has_function(
  'public',
  'authorize_provider_consultation_document',
  array['uuid', 'uuid'],
  'consultation document authorize exists'
);
select is_definer(
  'public',
  'list_provider_consultation_documents',
  array['uuid'],
  'list is security definer'
);
select is_definer(
  'public',
  'authorize_provider_consultation_document',
  array['uuid', 'uuid'],
  'authorize is security definer'
);
select ok(
  (
    select prosecdef and proconfig::text like '%search_path=pg_catalog, public, private%'
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'list_provider_consultation_documents'
  ),
  'list uses a fixed search_path'
);
select ok(
  (
    select prosecdef and proconfig::text like '%search_path=pg_catalog, public, private, extensions%'
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'authorize_provider_consultation_document'
  ),
  'authorize uses a fixed search_path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.list_provider_consultation_documents(uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.list_provider_consultation_documents(uuid)',
    'EXECUTE'
  ),
  'list is authenticated-only'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.authorize_provider_consultation_document(uuid,uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.authorize_provider_consultation_document(uuid,uuid)',
    'EXECUTE'
  ),
  'authorize is authenticated-only'
);
select ok(
  (
    select pg_get_functiondef(p.oid)
      like '%INVITED%'
     and pg_get_functiondef(p.oid) like '%VIEWED%'
     and pg_get_functiondef(p.oid) like '%ACCEPTED%'
     and pg_get_functiondef(p.oid) like '%PROVIDER_VIEWER%'
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'provider_consultation_invitation'
  ),
  'only invited provider members can open the pack'
);
select ok(
  (
    select pg_get_functiondef(p.oid) like '%client_document_binding_revocations%'
       and pg_get_functiondef(p.oid) like '%VERIFIED%'
       and pg_get_functiondef(p.oid) like '%CLEAN%'
       and pg_get_functiondef(p.oid) like '%expires_on%'
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'provider_consultation_shared_document'
  ),
  'only clean, unrevoked, non-expired bound documents are shared'
);
select ok(
  (
    select pg_get_functiondef(p.oid) like '%audit_events%'
       and pg_get_functiondef(p.oid) like '%provider.consultation.document.downloaded%'
       and pg_get_functiondef(p.oid) like '%document_version%'
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'authorize_provider_consultation_document'
  ),
  'download is audited on the client document'
);
select ok(
  (
    select pg_get_functiondef(p.oid) not like '%INSERT%'
       and pg_get_functiondef(p.oid) like '%provider_consultation_invitation%'
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'list_provider_consultation_documents'
  )
  and exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private'
      and p.proname = 'provider_consultation_invitation'
      and pg_get_functiondef(p.oid) like '%RFQ_DOCUMENT_DENIED%'
  ),
  'list is read-only and fail-closed'
);
select throws_ok(
  $$select public.list_provider_consultation_documents('11111111-1111-4111-8111-111111111111')$$,
  '42501',
  'UNAUTHENTICATED',
  'anonymous list is denied'
);
select throws_ok(
  $$select public.authorize_provider_consultation_document(
    '11111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222'
  )$$,
  '42501',
  'UNAUTHENTICATED',
  'anonymous authorize is denied'
);
select ok(
  not has_table_privilege('authenticated', 'public.client_document_bindings', 'INSERT')
  and not has_table_privilege('authenticated', 'public.client_compliance_documents', 'UPDATE'),
  'provider download does not open write paths on client documents'
);
select ok(
  not exists (
    select 1
    from pg_policy
    where polrelid = 'storage.objects'::regclass
      and polname = 'client_compliance_rfq_provider_read'
  ),
  'no extra storage policy is opened for providers'
);

select * from finish();
rollback;
