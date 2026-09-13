begin;
set local search_path=public,extensions;
select plan(12);

select has_table('public','ai_provider_invoice_reconciliations','AI provider invoices are reconciled against computed usage');
select ok((select count(*)=3 and bool_and(data_type='bigint') from information_schema.columns where table_schema='public' and table_name='ai_provider_invoice_reconciliations' and column_name in('invoiced_minor','computed_minor','variance_minor')),'AI invoice reconciliation uses exact minor units');
select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='ai_provider_invoice_reconciliations'),'AI invoice reconciliation has RLS');
select is((select count(*) from pg_trigger where tgrelid='public.ai_provider_invoice_reconciliations'::regclass and not tgisinternal and tgname='ai_provider_invoice_reconciliations_immutable'),1::bigint,'AI reconciliation evidence is immutable');

select ok(has_function_privilege('service_role','public.capture_benefit_margin_snapshot(uuid,uuid,text,bigint,character,text,text,uuid)','EXECUTE') and not has_function_privilege('authenticated','public.capture_benefit_margin_snapshot(uuid,uuid,text,bigint,character,text,text,uuid)','EXECUTE'),'margin capture is service-role-only');
select ok(has_function_privilege('service_role','public.reconcile_ai_provider_invoice(uuid,text,timestamptz,timestamptz,bigint,character,text,text,uuid)','EXECUTE') and not has_function_privilege('authenticated','public.reconcile_ai_provider_invoice(uuid,text,timestamptz,timestamptz,bigint,character,text,text,uuid)','EXECUTE'),'AI invoice reconciliation is service-role-only');
select ok((select prosecdef and proconfig::text like '%search_path=pg_catalog%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='capture_benefit_margin_snapshot'),'margin command has fixed search path');
select ok((select pg_get_functiondef(p.oid) like '%ACTUAL_COST_EVIDENCE_REQUIRED%' and pg_get_functiondef(p.oid) like '%MARGIN_SNAPSHOT_REPLAY_MISMATCH%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='capture_benefit_margin_snapshot'),'actual margin requires costs and rejects altered replay');
select ok((select pg_get_functiondef(p.oid) like '%AI_INVOICE_REPLAY_MISMATCH%' and pg_get_functiondef(p.oid) like '%AiProviderInvoiceReconciledV1%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='reconcile_ai_provider_invoice'),'AI reconciliation is anti-replay and emits Outbox');
select ok((select count(*)=2 and bool_and(pg_get_functiondef(p.oid) like '%pg_advisory_xact_lock%') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname=any(array['capture_benefit_margin_snapshot','reconcile_ai_provider_invoice'])),'margin and AI invoice replays are serialized');
select ok(exists(select 1 from pg_constraint where conrelid='public.benefit_margin_snapshots'::regclass and contype='u' and pg_get_constraintdef(oid) like '%idempotency_key%'),'margin snapshots carry a durable idempotency key');
select ok((select count(*) from pg_indexes where schemaname='public' and indexname='ai_provider_invoice_period_idx')=1,'AI invoice reconciliation period is indexed');

select * from finish();
rollback;
