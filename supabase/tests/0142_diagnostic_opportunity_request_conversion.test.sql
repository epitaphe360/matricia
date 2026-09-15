begin;
select plan(5);
select has_function('public','create_service_request_from_opportunity',array['uuid','jsonb','text','uuid'],'atomic opportunity conversion exists');
select ok(has_function_privilege('authenticated','public.create_service_request_from_opportunity(uuid,jsonb,text,uuid)','EXECUTE'),'authenticated clients can invoke conversion');
select ok(not has_function_privilege('anon','public.create_service_request_from_opportunity(uuid,jsonb,text,uuid)','EXECUTE'),'anonymous visitors cannot convert');
select ok(pg_get_functiondef('public.create_service_request_from_opportunity(uuid,jsonb,text,uuid)'::regprocedure) like '%for update%','opportunity is locked');
select ok(pg_get_functiondef('public.create_service_request_from_opportunity(uuid,jsonb,text,uuid)'::regprocedure) like '%service_request_id=request_id%' and pg_get_functiondef('public.create_service_request_from_opportunity(uuid,jsonb,text,uuid)'::regprocedure) like '%create_service_request(%','request and provenance are one transaction');
select * from finish();
rollback;
