begin;
set local search_path = public, extensions;
select plan(12);

select has_table('public', 'organizations', 'organizations exists');
select has_table('public', 'audit_events', 'audit_events exists');
select has_table('public', 'event_outbox', 'event_outbox exists');
select has_table('public', 'financial_journals', 'financial_journals exists');
select has_table('public', 'financial_entries', 'financial_entries exists');
select has_table('public', 'credit_ledger_entries', 'credit_ledger_entries exists');
select is((select relrowsecurity from pg_class where oid='public.organizations'::regclass), true, 'organizations RLS enabled');
select is((select relrowsecurity from pg_class where oid='public.financial_entries'::regclass), true, 'financial entries RLS enabled');
select is((select relrowsecurity from pg_class where oid='public.credit_ledger_entries'::regclass), true, 'credit entries RLS enabled');
select is((select count(*) from public.role_definitions), 26::bigint, 'all Gold Master roles seeded');
select is((select franchisee_share_bps from public.franchise_economic_rule_versions where franchise_type='IT' and status='ACTIVE'), 5000, 'IT franchise share is 50 percent');
select is((select neoxa_share_bps from public.franchise_economic_rule_versions where franchise_type='IT' and status='ACTIVE'), 5000, 'NEOXA IT share is 50 percent');

select * from finish();
rollback;
