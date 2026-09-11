begin;
set local search_path=public,extensions;
select plan(11);
grant usage on schema extensions to authenticated;

select ok(has_function_privilege('authenticated','public.decide_catalog_change(uuid,boolean,text,integer,text,uuid)','EXECUTE') and not has_function_privilege('anon','public.decide_catalog_change(uuid,boolean,text,integer,text,uuid)','EXECUTE'),'legacy decision overload remains authenticated-only');
select ok(has_function_privilege('authenticated','public.revoke_catalog_library_mandate(uuid,integer,text,text,uuid)','EXECUTE') and not has_function_privilege('service_role','public.revoke_catalog_library_mandate(uuid,integer,text,text,uuid)','EXECUTE'),'mandate revocation remains a human-only command');
select ok((select prosecdef and proconfig::text like '%search_path=pg_catalog%' from pg_proc where oid='public.decide_catalog_change(uuid,boolean,text,integer,text,uuid)'::regprocedure),'legacy wrapper is SECURITY DEFINER with fixed search path');
select ok(pg_get_functiondef('public.decide_catalog_change(uuid,boolean,text,integer,text,uuid)'::regprocedure) like '%CENTRAL_MFA_REQUIRED%','legacy wrapper preserves the MFA error contract');
select ok(pg_get_functiondef('public.revoke_catalog_library_mandate_core_v2(uuid,integer,text,text,uuid)'::regprocedure) like '%assert_catalog_permission_locked%' and pg_get_functiondef('public.revoke_catalog_library_mandate_core_v2(uuid,integer,text,text,uuid)'::regprocedure) like '%pg_advisory_xact_lock%','mandate revocation core locks and rechecks authorization');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('f3300000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-legacy-central@example.invalid','',now(),'{}','{}',now(),now()),
('f3300000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-legacy-outsider@example.invalid','',now(),'{}','{}',now(),now());
insert into public.platform_user_roles(user_id,role_code) values('f3300000-0000-0000-0000-000000000001','MATRICIA_ADMIN');
insert into public.organizations(id,legal_name,display_name,status,created_by) values('f3310000-0000-0000-0000-000000000001','P06 Legacy','P06 Legacy','ACTIVE','f3300000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f3300000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal1"}',true);
select extensions.throws_ok($$select public.decide_catalog_change('f33f0000-0000-0000-0000-000000000001',true,'Décision legacy',1,'p06-legacy-aal1')$$,'42501'::char(5),'CENTRAL_MFA_REQUIRED','legacy boolean decision preserves fail-closed AAL1 behavior');
select set_config('request.jwt.claims','{"sub":"f3300000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true);
select extensions.throws_ok($$select public.decide_catalog_change('f33f0000-0000-0000-0000-000000000001',null,'Décision legacy',1,'p06-legacy-null')$$,'22023'::char(5),'INVALID_CATALOG_DECISION','legacy boolean decision rejects NULL');
select public.create_catalog_library('f3310000-0000-0000-0000-000000000001','P06_LEGACY','p06-legacy','Bibliothèque legacy','مكتبة قديمة','Compatibilité','التوافق','legacy',1,false,'Fixture legacy','p06-legacy-create');
reset role;

select is((select count(*) from public.catalog_libraries where code='P06_LEGACY'),1::bigint,'legacy fixture library is created through the command API');
create temporary table p06_legacy_ids(mandate_id uuid not null);
insert into p06_legacy_ids select id from public.catalog_library_mandates where library_id=(select id from public.catalog_libraries where code='P06_LEGACY');
grant select on p06_legacy_ids to authenticated;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f3300000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}',true);
select extensions.throws_ok($$select public.revoke_catalog_library_mandate('f33f0000-0000-0000-0000-000000000099',1,'Tentative interdite','p06-legacy-revoke-hidden')$$,'42501'::char(5),'CATALOG_MANDATE_REVOKE_DENIED','unauthorized caller cannot distinguish an unknown mandate');
select extensions.throws_ok($$select public.revoke_catalog_library_mandate((select mandate_id from p06_legacy_ids),1,'Tentative interdite','p06-legacy-revoke-denied')$$,'42501'::char(5),'CATALOG_MANDATE_REVOKE_DENIED','cross-tenant outsider cannot revoke a mandate');
select set_config('request.jwt.claims','{"sub":"f3300000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true);
select is(public.revoke_catalog_library_mandate((select mandate_id from p06_legacy_ids),1,'Révocation contrôlée','p06-legacy-revoke')->>'outcome','CATALOG_MANDATE_REVOKED','central AAL2 reviewer revokes through the hardened command');
reset role;

select * from finish();
rollback;
