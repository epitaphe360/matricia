begin;
select plan(4);
select ok(pg_get_functiondef('private.validate_provider_document_storage_binding()'::regprocedure) like '%session_user%authenticator%','only direct maintenance sessions bypass reservation validation');
select ok(pg_get_functiondef('private.bind_provider_document_upload()'::regprocedure) like '%session_user%authenticator%','only direct maintenance sessions bypass reservation binding');
select ok(pg_get_functiondef('private.validate_provider_document_storage_binding()'::regprocedure) like '%PROVIDER_DOCUMENT_UPLOAD_RESERVATION_REQUIRED%' and pg_get_functiondef('private.validate_provider_document_storage_binding()'::regprocedure) like '%PROVIDER_DOCUMENT_STORAGE_METADATA_MISMATCH%','PostgREST validation remains fail closed');
select ok(not has_function_privilege('authenticated','private.validate_provider_document_storage_binding()','EXECUTE') and not has_function_privilege('service_role','private.bind_provider_document_upload()','EXECUTE'),'trigger helpers remain non-callable runtime internals');
select * from finish();
rollback;
