begin;
set local search_path=public,extensions;
select plan(19);

select has_table('public','quotes','quote aggregate exists');
select has_table('public','quote_versions','versioned quote snapshots exist');
select has_table('public','quote_items','exact quote lines exist');
select has_table('public','quote_comparison_snapshots','normalized comparison snapshots exist');
select has_function('public','create_quote_revision',array['uuid','jsonb','text','text','uuid'],'revision command exists');
select has_function('public','submit_quote',array['uuid','uuid','text','uuid'],'submission command exists');
select has_function('public','request_quote_revision',array['uuid','uuid','text','text','uuid'],'negotiation revision request exists');
select has_function('public','compare_quotes',array['uuid','text','uuid'],'comparison command exists');
select has_function('public','select_quote',array['uuid','uuid','text','uuid'],'selection command exists');
select ok((select bool_and(p.prosecdef and p.proconfig::text like '%search_path=pg_catalog%')from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname in('create_quote_revision','submit_quote','compare_quotes','select_quote')),'quote commands are security definers with fixed search paths');
select ok(not has_function_privilege('anon','public.create_quote_revision(uuid,jsonb,text,text,uuid)','EXECUTE')and not has_function_privilege('service_role','public.create_quote_revision(uuid,jsonb,text,text,uuid)','EXECUTE'),'revision command excludes anonymous and service roles');
select ok(not has_table_privilege('authenticated','public.quotes','INSERT')and not has_table_privilege('authenticated','public.quote_versions','UPDATE')and not has_table_privilege('authenticated','public.quote_items','DELETE'),'direct quote mutation remains denied');
select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'and c.relname='quotes')and(select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'and c.relname='quote_versions'),'tenant quote tables enforce RLS');
select ok((select count(*)=0 from information_schema.columns where table_schema='public'and table_name in('quote_versions','quote_items','quote_options')and data_type in('real','double precision')),'quote money never uses floating point');
select col_type_is('public','quote_versions','subtotal_minor','bigint','subtotal uses minor-unit bigint');
select col_type_is('public','quote_versions','tax_minor','bigint','tax uses minor-unit bigint');
select col_type_is('public','quote_items','quantity','numeric(18,4)','quantity uses exact decimal');
select ok(exists(select 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'and c.relname='quote_items'and t.tgname='quote_items_immutable'and not t.tgisinternal),'line items are immutable');
select ok(exists(select 1 from pg_indexes where schemaname='public'and tablename='quotes'and indexname='quotes_one_selected_per_rfq_idx'and indexdef like '%WHERE (status =%SELECTED%'),'only one quote can be selected per RFQ');

select * from finish();
rollback;
