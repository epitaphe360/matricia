begin;
set local search_path=public,extensions;
select plan(5);

select has_trigger('public','catalog_import_errors','catalog_import_error_10_scope_compatibility','library-scope reference compatibility trigger exists');
select ok(not has_function_privilege('authenticated','private.suppress_catalog_import_library_scope_reference_error()','EXECUTE'),'scope compatibility helper is private');
select is(private.catalog_import_payload_error('QUESTION','Q-DIAG-SCOPE',jsonb_build_object('library_code','IT','category_code','','service_code','','phase','DIAGNOSTIC','section','Général','order',1,'label_fr','Question','answer_type','YES_NO','required',true,'required_for_quote',false,'options',jsonb_build_array('YES','NO','UNKNOWN'),'validation_schema','{}'::jsonb,'condition','{}'::jsonb,'data_key','diagnostic.scope','weight',1,'max_score',10,'sensitivity','BUSINESS')),null,'library-scoped diagnostic YES_NO question is valid');
select is(private.catalog_import_payload_error('QUESTION','Q-RFQ-SCOPE',jsonb_build_object('library_code','IT','category_code','','service_code','','phase','RFQ','section','Général','order',1,'label_fr','Question','answer_type','YES_NO','required',true,'required_for_quote',true,'options','[]'::jsonb,'validation_schema','{}'::jsonb,'condition','{}'::jsonb,'data_key','rfq.scope','weight',1,'max_score',10,'sensitivity','BUSINESS')),'QUESTION_SCOPE_INVALID','RFQ still requires service scope');
select is(private.catalog_import_payload_error('QUESTION','Q-DIAG-OPTIONS',jsonb_build_object('library_code','IT','category_code','','service_code','','phase','DIAGNOSTIC','section','Général','order',1,'label_fr','Question','answer_type','YES_NO','required',true,'required_for_quote',false,'options',jsonb_build_array('YES','MAYBE'),'validation_schema','{}'::jsonb,'condition','{}'::jsonb,'data_key','diagnostic.options','weight',1,'max_score',10,'sensitivity','BUSINESS')),'QUESTION_SCHEMA_INVALID','YES_NO rejects noncanonical options');

select * from finish();
rollback;
