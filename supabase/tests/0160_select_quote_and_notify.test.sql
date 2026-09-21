begin;
select plan(9);
select has_table('public','quote_selection_decisions','selection decision table exists');
select has_function('public','select_quote_and_notify',array['uuid','uuid','text','uuid','text','uuid'],'selection wrapper exists');
select has_function('private','anonymised_not_selected_axes',array['jsonb','uuid'],'anonymised axes helper exists');
select ok(has_function_privilege('authenticated','public.select_quote_and_notify(uuid,uuid,text,uuid,text,uuid)','EXECUTE'),'authenticated clients can select with reason');
select ok(not has_function_privilege('anon','public.select_quote_and_notify(uuid,uuid,text,uuid,text,uuid)','EXECUTE'),'anonymous visitors cannot select');
select ok(not has_table_privilege('authenticated','public.quote_selection_decisions','INSERT'),'clients cannot bypass the decision contract');
select ok((select relrowsecurity from pg_class where oid='public.quote_selection_decisions'::regclass),'RLS is enabled');
select ok(
  pg_get_functiondef('public.select_quote_and_notify(uuid,uuid,text,uuid,text,uuid)'::regprocedure) like '%select_quote(%'
  and pg_get_functiondef('public.select_quote_and_notify(uuid,uuid,text,uuid,text,uuid)'::regprocedure) like '%publish_not_selected_feedback%'
  and pg_get_functiondef('public.select_quote_and_notify(uuid,uuid,text,uuid,text,uuid)'::regprocedure) like '%selection_reason%',
  'selection, reason and anonymised feedback are one transaction'
);
select ok(
  pg_get_functiondef('private.anonymised_not_selected_axes(jsonb,uuid)'::regprocedure) not like '%gagnant%'
  and pg_get_functiondef('private.anonymised_not_selected_axes(jsonb,uuid)'::regprocedure) not like '%winner%'
  and pg_get_functiondef('private.anonymised_not_selected_axes(jsonb,uuid)'::regprocedure) not like '%prix exact%'
  and pg_get_functiondef('private.anonymised_not_selected_axes(jsonb,uuid)'::regprocedure) not like '%email%',
  'anonymised axes omit winner identity and contacts'
);
select * from finish();
rollback;
