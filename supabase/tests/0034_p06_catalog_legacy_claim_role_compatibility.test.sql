begin;
set local search_path=public,extensions;
select plan(8);
grant usage on schema extensions to authenticated;

select ok(has_function_privilege('authenticated','public.decide_catalog_change(uuid,boolean,text,integer,text,uuid)','EXECUTE') and not has_function_privilege('anon','public.decide_catalog_change(uuid,boolean,text,integer,text,uuid)','EXECUTE'),'legacy decision facade is authenticated-only');
select ok(has_function_privilege('authenticated','public.revoke_catalog_library_mandate(uuid,integer,text,text,uuid)','EXECUTE') and not has_function_privilege('service_role','public.revoke_catalog_library_mandate(uuid,integer,text,text,uuid)','EXECUTE'),'legacy revoke facade is authenticated-only');
select ok(not has_function_privilege('authenticated','public.decide_catalog_change_legacy_core(uuid,boolean,text,integer,text,uuid)','EXECUTE') and not has_function_privilege('authenticated','public.revoke_catalog_library_mandate_core_v2(uuid,integer,text,text,uuid)','EXECUTE'),'legacy cores are not runtime callable');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('f3400000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-compat-central@example.invalid','',now(),'{}','{}',now(),now()),
('f3400000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-compat-outsider@example.invalid','',now(),'{}','{}',now(),now());
insert into public.platform_user_roles(user_id,role_code) values('f3400000-0000-0000-0000-000000000001','MATRICIA_ADMIN');

set local role authenticated;
select set_config('request.jwt.claim.role','service_role',true);
select set_config('request.jwt.claims','{"sub":"f3400000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal1"}',true);
select throws_ok($$select public.decide_catalog_change('f34f0000-0000-0000-0000-000000000001',true,'Décision legacy',1,'p06-compat-aal1')$$,'42501','CENTRAL_MFA_REQUIRED','AAL1 remains denied');
select set_config('request.jwt.claims','{"sub":"f3400000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}',true);
select throws_ok($$select public.decide_catalog_change('f34f0000-0000-0000-0000-000000000001',true,'Décision legacy',1,'p06-compat-outsider')$$,'42501','CENTRAL_MFA_REQUIRED','non-central caller remains denied before target lookup');
select throws_ok($$select public.revoke_catalog_library_mandate('f34f0000-0000-0000-0000-000000000002',1,'Révocation interdite','p06-compat-revoke-outsider')$$,'42501','CATALOG_MANDATE_REVOKE_DENIED','non-central revoke remains denied before target lookup');
select set_config('request.jwt.claims','{"sub":"f3400000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true);
select throws_ok($$select public.decide_catalog_change('f34f0000-0000-0000-0000-000000000001',true,'Décision legacy',1,'p06-compat-central')$$,'P0002','CATALOG_CHANGE_NOT_FOUND','central AAL2 legacy decision survives stale scalar role claim');
select throws_ok($$select public.revoke_catalog_library_mandate('f34f0000-0000-0000-0000-000000000002',1,'Révocation contrôlée','p06-compat-revoke-central')$$,'P0002','CATALOG_MANDATE_NOT_FOUND','central AAL2 legacy revoke survives stale scalar role claim');
reset role;

select * from finish();
rollback;
