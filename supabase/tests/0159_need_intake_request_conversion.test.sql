begin;
select plan(10);
select has_table('public','public_need_intake_conversions','need intake conversion table exists');
select has_function('public','create_service_request_from_need_intake',array['uuid','text','jsonb','text','uuid'],'atomic need conversion exists');
select ok(has_function_privilege('authenticated','public.create_service_request_from_need_intake(uuid,text,jsonb,text,uuid)','EXECUTE'),'authenticated clients can invoke conversion');
select ok(not has_function_privilege('anon','public.create_service_request_from_need_intake(uuid,text,jsonb,text,uuid)','EXECUTE'),'anonymous visitors cannot convert');
select ok(not has_table_privilege('authenticated','public.public_need_intake_conversions','INSERT'),'clients cannot bypass the conversion contract');
select ok(has_table_privilege('authenticated','public.public_need_intake_conversions','SELECT'),'authorized clients may read conversions through RLS');
select ok((select relrowsecurity from pg_class where oid='public.public_need_intake_conversions'::regclass),'RLS is enabled');
select policies_are('public','public_need_intake_conversions',array['public_need_intake_conversions_client_read'],'only the tenant read policy exists');
select ok(pg_get_functiondef('public.create_service_request_from_need_intake(uuid,text,jsonb,text,uuid)'::regprocedure) like '%for update%' and pg_get_functiondef('public.create_service_request_from_need_intake(uuid,text,jsonb,text,uuid)'::regprocedure) like '%pg_advisory_xact_lock%','intake is locked');
select ok(
  pg_get_functiondef('public.create_service_request_from_need_intake(uuid,text,jsonb,text,uuid)'::regprocedure) like '%create_service_request(%'
  and pg_get_functiondef('public.create_service_request_from_need_intake(uuid,text,jsonb,text,uuid)'::regprocedure) like '%public_need_intake_conversions%'
  and pg_get_functiondef('public.create_service_request_from_need_intake(uuid,text,jsonb,text,uuid)'::regprocedure) not like '%mark_service_request_ready%'
  and pg_get_functiondef('public.create_service_request_from_need_intake(uuid,text,jsonb,text,uuid)'::regprocedure) not like '%open_service_request_rfq%',
  'request and provenance are one transaction without opening a consultation'
);
select * from finish();
rollback;
