begin;
set local search_path = public, extensions;
select plan(15);

select has_table('public', 'organizations', 'organizations exists');
select has_table('public', 'audit_events', 'audit_events exists');
select has_table('public', 'event_outbox', 'event_outbox exists');
select has_table('public', 'financial_journals', 'financial_journals exists');
select has_table('public', 'financial_entries', 'financial_entries exists');
select has_table('public', 'credit_ledger_entries', 'credit_ledger_entries exists');
select is((select relrowsecurity from pg_class where oid='public.organizations'::regclass), true, 'organizations RLS enabled');
select is((select relrowsecurity from pg_class where oid='public.financial_entries'::regclass), true, 'financial entries RLS enabled');
select is((select relrowsecurity from pg_class where oid='public.credit_ledger_entries'::regclass), true, 'credit entries RLS enabled');
select is((
  select count(*)
  from pg_class relation
  join pg_namespace namespace on namespace.oid=relation.relnamespace
  where namespace.nspname='public'
    and relation.relkind in ('r','p')
    and not relation.relrowsecurity
),0::bigint,'every exposed public table has RLS enabled');
select is((
  select count(*)
  from pg_proc procedure
  join pg_depend dependency on dependency.objid=procedure.oid and dependency.classid='pg_proc'::regclass
  join pg_extension extension on extension.oid=dependency.refobjid
  where extension.extname='pgtap'
    and has_schema_privilege('authenticated',procedure.pronamespace,'USAGE')
    and has_function_privilege('authenticated',procedure.oid,'EXECUTE')
),0::bigint,'authenticated has no effective access to any pgTAP function');
select ok(not has_schema_privilege('authenticated','extensions','USAGE'),'authenticated cannot access extension internals');
select is((select count(*) from public.role_definitions), 26::bigint, 'all Gold Master roles seeded');
select is((select franchisee_share_bps from public.franchise_economic_rule_versions where franchise_type='IT' and status='ACTIVE'), 5000, 'IT franchise share is 50 percent');
select is((select neoxa_share_bps from public.franchise_economic_rule_versions where franchise_type='IT' and status='ACTIVE'), 5000, 'NEOXA IT share is 50 percent');

select * from finish();
rollback;
