begin;
set local search_path=public,extensions;
select plan(8);

select has_function('public','list_admin_v41_overview',array['integer'],'V4.1 Admin overview exists');
select ok(has_function_privilege('authenticated','public.list_admin_v41_overview(integer)','EXECUTE') and not has_function_privilege('anon','public.list_admin_v41_overview(integer)','EXECUTE'),'Admin overview is authenticated-only');
select ok((select prosecdef and proconfig::text like '%search_path=pg_catalog%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='list_admin_v41_overview'),'Admin overview has fixed search path');
select ok((select pg_get_functiondef(p.oid) like '%ADMIN_V41_OVERVIEW_DENIED%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='list_admin_v41_overview'),'Admin overview enforces platform authorization');
select ok((select pg_get_functiondef(p.oid) like '%direct_client_provider_payments%' and pg_get_functiondef(p.oid) like '%matricia_own_revenue_payments%' and pg_get_functiondef(p.oid) like '%provider_commission_receipts%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='list_admin_v41_overview'),'Admin overview exposes the three financial flows separately');
select ok((select pg_get_functiondef(p.oid) like '%signature_envelopes%' and pg_get_functiondef(p.oid) like '%data_subject_requests%' and pg_get_functiondef(p.oid) like '%supplier_invoices%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='list_admin_v41_overview'),'Admin overview covers Signature Privacy and AP');
select ok((select pg_get_functiondef(p.oid) like '%ai_usage_events%' and pg_get_functiondef(p.oid) like '%benefit_margin_snapshots%' and pg_get_functiondef(p.oid) like '%treasury_cashflow_snapshots%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='list_admin_v41_overview'),'Admin overview covers FinOps margins and treasury');
select ok((select pg_get_functiondef(p.oid) like '%third_party_service_alerts%' and pg_get_functiondef(p.oid) like '%security_incidents%' and pg_get_functiondef(p.oid) like '%dead_letter_reprocess_requests%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='list_admin_v41_overview'),'Admin overview covers resilience and operational exceptions');

select * from finish();
rollback;
