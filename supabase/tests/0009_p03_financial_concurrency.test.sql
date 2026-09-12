begin;
set local search_path = public, extensions;
select plan(8);

select ok((select prosecdef from pg_proc where oid='public.post_financial_journal(uuid,text,text,text,char,timestamptz,text,jsonb,uuid)'::regprocedure),'journal command is a server-authorized SECURITY DEFINER RPC');
select ok((select prosecdef from pg_proc where oid='public.issue_credits(uuid,uuid,text,bigint,timestamptz,uuid,text,bigint,text,text,text,uuid)'::regprocedure),'credit issue command is a server-authorized SECURITY DEFINER RPC');
select is((select proconfig from pg_proc where oid='public.post_financial_journal(uuid,text,text,text,char,timestamptz,text,jsonb,uuid)'::regprocedure),array['search_path=pg_catalog, extensions, private']::text[],'journal RPC has a fixed search path');
select is((select proconfig from pg_proc where oid='public.issue_credits(uuid,uuid,text,bigint,timestamptz,uuid,text,bigint,text,text,text,uuid)'::regprocedure),array['search_path=pg_catalog, public, private, extensions']::text[],'credit issue RPC has a fixed search path');
select ok(has_function_privilege('authenticated','public.post_financial_journal(uuid,text,text,text,char,timestamptz,text,jsonb,uuid)','EXECUTE'),'authenticated may invoke the journal command');
select ok(has_function_privilege('authenticated','public.issue_credits(uuid,uuid,text,bigint,timestamptz,uuid,text,bigint,text,text,text,uuid)','EXECUTE'),'authenticated may invoke the role-checked credit issue command');
select ok(not has_table_privilege('authenticated','public.financial_entries','INSERT'),'journal entries cannot bypass the command RPC');
select ok(not has_table_privilege('authenticated','public.credit_ledger_entries','INSERT'),'credit entries cannot bypass the command RPC');

select * from finish();
rollback;
