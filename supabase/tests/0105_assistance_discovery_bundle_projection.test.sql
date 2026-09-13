begin;
set local search_path=public,extensions;
select plan(13);

select has_function('public','discover_assistance_scope',array['uuid','text','text[]','integer'],'bounded assistance discovery exists');
select has_function('public','list_solution_bundles_v1',array[]::text[],'bundle projection exists');
select ok((select p.prosecdef and p.provolatile='s' and p.proconfig::text like '%search_path=pg_catalog, public, private, extensions%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='discover_assistance_scope'),'discovery is stable SECURITY DEFINER with fixed path');
select ok((select not p.prosecdef and p.provolatile='s' and p.proconfig::text like '%search_path=pg_catalog, public%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='list_solution_bundles_v1'),'bundle projection is stable SECURITY INVOKER with fixed path');
select ok(has_function_privilege('authenticated','public.discover_assistance_scope(uuid,text,text[],integer)','EXECUTE')
  and not has_function_privilege('anon','public.discover_assistance_scope(uuid,text,text[],integer)','EXECUTE')
  and not has_function_privilege('service_role','public.discover_assistance_scope(uuid,text,text[],integer)','EXECUTE'),'discovery ACL is authenticated-only');
select ok(has_function_privilege('authenticated','public.list_solution_bundles_v1()','EXECUTE')
  and not has_function_privilege('anon','public.list_solution_bundles_v1()','EXECUTE')
  and not has_function_privilege('service_role','public.list_solution_bundles_v1()','EXECUTE'),'bundle projection ACL is authenticated-only');
select ok((select p.prosrc like '%limit p_limit%' and p.prosrc like '%limit 50%' and p.prosrc like '%source_service_id%' and p.prosrc like '%revision.expires_at%' and p.prosrc like '%p_known_data_keys%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='discover_assistance_scope'),'discovery bounds services and only loads questions linked to selected services');
select ok((select p.prosrc like '%human_confirmation_required%' and p.prosrc not like '%service_requests%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='discover_assistance_scope'),'discovery requires human confirmation and creates no business object');
select ok((select p.prosrc like '%total_amount_minor::text%' and p.prosrc like '%amount_minor::text%' and p.prosrc like '%provenance%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='list_solution_bundles_v1'),'bundle projection preserves exact money and provenance');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
 ('fa050000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','a1-discovery@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by) values
 ('fa051000-0000-4000-8000-000000000001','A1 discovery','A1 discovery','ACTIVE','fa050000-0000-4000-8000-000000000001'),
 ('fa051000-0000-4000-8000-000000000002','A1 foreign','A1 foreign','ACTIVE','fa050000-0000-4000-8000-000000000001');
insert into public.organization_memberships(id,organization_id,user_id,status) values
 ('fa052000-0000-4000-8000-000000000001','fa051000-0000-4000-8000-000000000001','fa050000-0000-4000-8000-000000000001','ACTIVE');
insert into public.organization_member_roles(membership_id,role_code) values
 ('fa052000-0000-4000-8000-000000000001','CLIENT_ADMIN');

select set_config('request.jwt.claims','{"sub":"fa050000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select lives_ok($$select public.discover_assistance_scope('fa051000-0000-4000-8000-000000000001','sauvegarde cloud sécurisée',array['profile.sector'],20)$$,'own tenant can run bounded discovery');
select throws_ok($$select public.discover_assistance_scope('fa051000-0000-4000-8000-000000000002','sauvegarde cloud sécurisée','{}',20)$$,'42501','ASSISTANCE_ACCESS_DENIED','foreign tenant discovery is denied');
select throws_ok($$select public.discover_assistance_scope('fa051000-0000-4000-8000-000000000001','x','{}',20)$$,'22023','INVALID_ASSISTANCE_DISCOVERY','undersized text fails closed');
select throws_ok($$select public.discover_assistance_scope('fa051000-0000-4000-8000-000000000001','sauvegarde cloud sécurisée','{}',21)$$,'22023','INVALID_ASSISTANCE_DISCOVERY','service discovery limit fails closed above twenty');

select * from finish();
rollback;
