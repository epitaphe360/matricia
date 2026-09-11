begin;
set local search_path=public,extensions;
select plan(5);

select has_trigger('public','catalog_approvals','catalog_approval_10_prepare_compatibility','release approval compatibility trigger exists');
select has_trigger('public','catalog_approvals','catalog_approval_90_audit_compatibility','legacy audit compatibility trigger exists');
select ok(not has_function_privilege('authenticated','private.prepare_catalog_approval_compatibility()','EXECUTE') and not has_function_privilege('service_role','private.audit_catalog_approval_compatibility()','EXECUTE'),'compatibility helpers are not runtime callable');
select ok((select prosecdef and proconfig::text like '%search_path=pg_catalog%' from pg_proc where oid='private.prepare_catalog_approval_compatibility()'::regprocedure),'hash compatibility helper is hardened');
select ok((select prosecdef and proconfig::text like '%search_path=pg_catalog%' from pg_proc where oid='private.audit_catalog_approval_compatibility()'::regprocedure),'audit compatibility helper is hardened');

select * from finish();
rollback;
