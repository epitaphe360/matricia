begin;
set local search_path = public, extensions;
select plan(11);

select ok((
  select count(*) = 8 and bool_and(p.prosecdef and p.proconfig::text like '%search_path=%')
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = any(array[
    'create_benefit_version','activate_benefit_version','create_box_version','activate_box_version',
    'link_plan_box_rule','list_admin_boxes_dashboard','list_admin_pnl_dashboard',
    'list_admin_provider_closure_dashboard'
  ])
), 'boxes and dashboard commands are security definer with fixed search_path');

select ok((
  select p.prosecdef and p.proconfig::text like '%search_path=%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'sweep_admin_exceptions'
), 'exception sweep is security definer');

select ok((
  select p.prosecdef and p.proconfig::text like '%search_path=%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'create_framework_agreement_draft'
), 'framework draft is security definer');

select ok((
  select not exists(
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = any(array[
      'create_benefit_version','activate_benefit_version','create_box_version','activate_box_version',
      'link_plan_box_rule','list_admin_boxes_dashboard','list_admin_pnl_dashboard',
      'list_admin_provider_closure_dashboard','sweep_admin_exceptions','create_framework_agreement_draft'
    ])
    and (has_function_privilege('anon', p.oid, 'EXECUTE') or has_function_privilege('service_role', p.oid, 'EXECUTE'))
  )
), 'new admin commands exclude anon and service_role');

select ok((
  select pg_get_functiondef(p.oid) like '%BOX_COST_APPROVAL_REQUIRED%'
     and pg_get_functiondef(p.oid) like '%cost_full_minor%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'activate_box_version'
), 'unprofitable Box activation requires approval evidence');

select ok((
  select pg_get_functiondef(p.oid) like '%open_admin_work_item%'
     and pg_get_functiondef(p.oid) like '%BILLING_EXCEPTION%'
     and pg_get_functiondef(p.oid) like '%LOW_STOCK%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'sweep_admin_exceptions'
), 'sweep opens EXCEPTIONS work items from billing, matching and volume signals');

select ok((
  select pg_get_functiondef(p.oid) like '%agreements%'
     and pg_get_functiondef(p.oid) like '%profitability%'
     and pg_get_functiondef(p.oid) like '%can_negotiate%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'get_admin_volume_dashboard'
), 'volume dashboard exposes negotiation and profitability');

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at) values
('a1624000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tenant-1624@example.invalid', '', now(), '{}', '{}', now(), now()),
('a1624000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin-1624@example.invalid', '', now(), '{}', '{}', now(), now());
insert into public.organizations(id, legal_name, display_name, status, created_by)
values ('b1624000-0000-4000-8000-000000000001', 'Boxes Org 1624', 'Boxes 1624', 'ACTIVE', 'a1624000-0000-4000-8000-000000000001');
insert into public.platform_user_roles(user_id, role_code) values
('a1624000-0000-4000-8000-000000000002', 'MATRICIA_ADMIN');

select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','a1624000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claims','{"sub":"a1624000-0000-4000-8000-000000000001","role":"authenticated"}',true); select public.list_admin_boxes_dashboard(10)$$,
  '42501',
  'ADMIN_BOXES_DENIED',
  'tenant cannot read boxes dashboard'
);

select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','a1624000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claims','{"sub":"a1624000-0000-4000-8000-000000000001","role":"authenticated"}',true); select public.sweep_admin_exceptions()$$,
  '42501',
  'ADMIN_SWEEP_DENIED',
  'tenant cannot sweep exceptions'
);

create temporary table p1624_observed(value jsonb);
grant select, insert on p1624_observed to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1624000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claims', '{"sub":"a1624000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}', true);
insert into p1624_observed values (public.list_admin_boxes_dashboard(10));
insert into p1624_observed values (public.list_admin_pnl_dashboard(10));
insert into p1624_observed values (public.list_admin_provider_closure_dashboard(10));
reset role;

select ok((
  select bool_and(value ? 'generated_at')
     and bool_or(value ? 'benefits' and value ? 'boxes' and value ? 'plan_matrix' and value ? 'wallets')
     and bool_or(value ? 'books' and value ? 'rules')
     and bool_or(value ? 'unstatemented' and value ? 'overdue_invoices')
  from p1624_observed
), 'admin dashboards return boxes, pnl and closure keys');

select ok((
  select has_function_privilege('authenticated', 'public.list_admin_boxes_dashboard(integer)', 'EXECUTE')
     and has_function_privilege('authenticated', 'public.sweep_admin_exceptions()', 'EXECUTE')
     and not has_function_privilege('anon', 'public.list_admin_boxes_dashboard(integer)', 'EXECUTE')
), 'execute remains authenticated-only');

select * from finish();
rollback;
