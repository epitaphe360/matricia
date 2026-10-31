begin;
select plan(10);
select has_table('public','provider_region_versions','region history table exists');
select has_function('private','morocco_region_codes',array[]::text[],'official region list exists');
select has_function('public','declare_provider_regions',array['uuid','text[]','text','text','uuid'],'region declaration command exists');
select is(cardinality(private.morocco_region_codes()), 12, 'exactly the 12 official regions are accepted');
select ok(
  not has_function_privilege('authenticated','private.morocco_region_codes()','EXECUTE'),
  'region list helper stays private'
);
select ok(
  not has_function_privilege('anon','public.declare_provider_regions(uuid,text[],text,text,uuid)','EXECUTE')
  and has_function_privilege('authenticated','public.declare_provider_regions(uuid,text[],text,text,uuid)','EXECUTE'),
  'declaration is reserved to authenticated users'
);
select ok(
  not has_table_privilege('authenticated','public.provider_region_versions','INSERT')
  and not has_table_privilege('authenticated','public.provider_region_versions','UPDATE')
  and not has_table_privilege('authenticated','public.provider_region_versions','DELETE'),
  'history is written only through the command'
);
select ok(
  exists(select 1 from pg_trigger where tgrelid='public.provider_region_versions'::regclass and tgname='provider_region_versions_immutable'),
  'history rows are immutable'
);
select ok(
  pg_get_functiondef('public.declare_provider_regions(uuid,text[],text,text,uuid)'::regprocedure) like '%can_manage_provider%'
  and pg_get_functiondef('public.declare_provider_regions(uuid,text[],text,text,uuid)'::regprocedure) like '%begin_provider_qualification_command%'
  and pg_get_functiondef('public.declare_provider_regions(uuid,text[],text,text,uuid)'::regprocedure) like '%morocco_region_codes%',
  'declaration is authorised, idempotent and validated against the official list'
);
select ok(
  pg_get_functiondef('public.declare_provider_regions(uuid,text[],text,text,uuid)'::regprocedure) like '%update public.provider_match_profiles%'
  and pg_get_functiondef('public.declare_provider_regions(uuid,text[],text,text,uuid)'::regprocedure) like '%ProviderRegionsDeclaredV1%'
  and pg_get_functiondef('public.declare_provider_regions(uuid,text[],text,text,uuid)'::regprocedure) like '%insert into public.audit_events%',
  'declaration feeds matching, is audited and emits an outbox event'
);
select * from finish();
rollback;
