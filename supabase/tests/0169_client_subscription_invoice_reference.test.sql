begin;
select plan(3);

select ok(
  (
    select p.prosecdef and p.proconfig::text like '%search_path=pg_catalog%'
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname = 'get_client_subscription_historical_plan_projection'
  ),
  'client invoice projection stays security definer'
);

select ok(
  (
    select pg_get_functiondef(p.oid) like '%payment_reference%'
       and pg_get_functiondef(p.oid) not like '%payment_proof_hash%'
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname = 'get_client_subscription_historical_plan_projection'
  ),
  'the client reads the payment reference and not the proof hash'
);

select ok(
  has_function_privilege('authenticated', 'public.get_client_subscription_historical_plan_projection(uuid,integer)', 'EXECUTE')
    and not has_function_privilege('anon', 'public.get_client_subscription_historical_plan_projection(uuid,integer)', 'EXECUTE'),
  'authenticated can read the projection, anon cannot'
);

select * from finish();
rollback;
