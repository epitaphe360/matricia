begin;
set local search_path=public,extensions;
select plan(3);

select has_trigger('public','catalog_import_errors','catalog_import_error_10_scope_compatibility','draft compatibility reuses the guarded import-error trigger');
select ok((select prosecdef and proconfig::text like '%search_path=pg_catalog%' from pg_proc where oid='private.suppress_catalog_import_library_scope_reference_error()'::regprocedure),'draft compatibility helper is hardened');
select ok(not has_function_privilege('authenticated','private.suppress_catalog_import_library_scope_reference_error()','EXECUTE'),'draft compatibility helper remains private');

select * from finish();
rollback;
