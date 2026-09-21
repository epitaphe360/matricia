begin;
set local search_path=public,private,extensions;
select plan(14);

select ok(to_regclass('private.provider_payment_proof_scan_results')is not null,'immutable payment-proof scan results exist');
select ok(to_regclass('private.provider_payment_proof_scan_claims')is not null and to_regclass('private.provider_payment_proof_scan_retry_history')is not null,'lease and retry infrastructure exists');
select ok((select bool_and(relrowsecurity)from pg_class where oid=any(array['private.provider_payment_proof_scan_results'::regclass,'private.provider_payment_proof_scan_claims'::regclass,'private.provider_payment_proof_scan_retry_history'::regclass])),'private scan tables enforce RLS');
select ok((select count(*)=3 from pg_trigger where tgname in('provider_payment_proof_scan_results_immutable','provider_payment_proof_scan_retry_history_immutable','provider_payment_proof_scan_idempotency_immutable')and not tgisinternal),'scan evidence, retries and idempotency are immutable');
select ok((select data_type='text'from information_schema.columns where table_schema='public'and table_name='provider_payment_proof_uploads'and column_name='scan_status'),'upload reservations expose a governed scan status');
select ok((select pg_get_constraintdef(oid)like'%scan_status%'and pg_get_constraintdef(oid)like'%current_scan_result_id%'from pg_constraint where conname='provider_payment_proof_scan_state_check'),'scan state requires immutable result linkage');
select ok((select prosecdef and proconfig::text like'%search_path=%'from pg_proc where oid='public.claim_provider_payment_proof_scan_jobs(uuid,integer,integer)'::regprocedure),'claim RPC is security definer with fixed search path');
select ok(has_function_privilege('service_role','public.claim_provider_payment_proof_scan_jobs(uuid,integer,integer)','EXECUTE')and not has_function_privilege('authenticated','public.claim_provider_payment_proof_scan_jobs(uuid,integer,integer)','EXECUTE'),'only service role can claim payment proof scans');
select ok((select pg_get_functiondef(oid)like'%scan_status=''PENDING''%'and pg_get_functiondef(oid)like'%for update skip locked%'from pg_proc where oid='public.claim_provider_payment_proof_scan_jobs(uuid,integer,integer)'::regprocedure),'claiming is pending-only and concurrency safe');
select ok((select pg_get_functiondef(oid)like'%IDEMPOTENCY_CONFLICT%'and pg_get_functiondef(oid)like'%ProviderPaymentProofQuarantinedV1%'from pg_proc where oid='public.record_provider_payment_proof_scan_result(uuid,text,text,text,text,text,uuid)'::regprocedure),'scan recording is idempotent, audited and quarantine-aware');
select ok((select pg_get_functiondef(oid)like'%attempt_count+1%'and pg_get_functiondef(oid)like'%PROVIDER_PAYMENT_PROOF_SCAN_DEAD_LETTERED%'from pg_proc where oid='public.fail_provider_payment_proof_scan_job(uuid,uuid,uuid,integer,text,text,uuid)'::regprocedure),'scanner failures retry then dead-letter');
select ok((select pg_get_functiondef(oid)like'%PAYMENT_PROOF_SCAN_NOT_CLEAN%'and pg_get_functiondef(oid)like'%result=''CLEAN''%'from pg_proc where oid='public.record_provider_payment(uuid,text,date,text,character,bigint,text,uuid,uuid,text,uuid)'::regprocedure),'financial recording fails closed without a matching CLEAN verdict');
select ok((select pg_get_functiondef(oid)like'%scan_result_id%'from pg_proc where oid='public.record_provider_payment(uuid,text,date,text,character,bigint,text,uuid,uuid,text,uuid)'::regprocedure),'financial evidence binds the exact scan result');
select ok(not exists(select 1 from information_schema.columns where table_schema in('public','private')and table_name like'provider_payment_proof_scan%'and data_type in('real','double precision')),'scan pipeline introduces no floating-point values');

select * from finish();
rollback;
