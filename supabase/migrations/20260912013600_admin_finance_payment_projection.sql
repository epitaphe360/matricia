begin;

create function public.list_admin_finance_dashboard(p_limit integer default 100)
returns jsonb
language plpgsql
security definer
stable
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  result jsonb;
begin
  if actor is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'], actor) then
    raise exception 'ADMIN_FINANCE_DASHBOARD_DENIED' using errcode = '42501';
  end if;
  if p_limit not between 1 and 200 then
    raise exception 'INVALID_ADMIN_FINANCE_LIMIT' using errcode = '22023';
  end if;

  select jsonb_build_object(
    'as_of', statement_timestamp(),
    'payment_intents', coalesce((
      select jsonb_agg(x.item order by x.created_at desc, x.id)
      from (
        select i.id, i.created_at, jsonb_build_object(
          'id', i.id,
          'organization_id', i.organization_id,
          'organization_name', o.display_name,
          'plan_version_id', i.plan_version_id,
          'billing_interval', i.billing_interval,
          'gateway', i.gateway,
          'amount_minor', i.amount_minor::text,
          'currency', i.currency,
          'status', case when exists(select 1 from public.subscription_payment_events e where e.payment_intent_id=i.id) then 'ACTIVATED' else 'PENDING_VERIFICATION' end,
          'created_at', i.created_at
        ) item
        from public.subscription_payment_intents i
        join public.organizations o on o.id=i.organization_id
        order by i.created_at desc, i.id
        limit p_limit
      ) x
    ), '[]'::jsonb),
    'payment_events', coalesce((
      select jsonb_agg(x.item order by x.received_at desc, x.id desc)
      from (
        select e.id, e.received_at, jsonb_build_object(
          'id', e.id::text,
          'payment_intent_id', e.payment_intent_id,
          'organization_id', e.organization_id,
          'organization_name', o.display_name,
          'gateway', e.gateway,
          'event_type', e.event_type,
          'amount_minor', e.amount_minor::text,
          'currency', e.currency,
          'paid_at', e.paid_at,
          'received_at', e.received_at
        ) item
        from public.subscription_payment_events e
        join public.organizations o on o.id=e.organization_id
        order by e.received_at desc, e.id desc
        limit p_limit
      ) x
    ), '[]'::jsonb),
    'subscriptions', coalesce((
      select jsonb_agg(x.item order by x.updated_at desc, x.id)
      from (
        select s.id, s.updated_at, jsonb_build_object(
          'id', s.id,
          'organization_id', s.organization_id,
          'organization_name', o.display_name,
          'status', s.status,
          'plan_code', p.code,
          'billing_interval', s.billing_interval,
          'current_period_start', s.current_period_start,
          'current_period_end', s.current_period_end,
          'pending_plan_version_id', s.pending_plan_version_id,
          'pending_change_effective_at', s.pending_change_effective_at,
          'row_version', s.row_version::text,
          'updated_at', s.updated_at
        ) item
        from public.subscriptions s
        join public.organizations o on o.id=s.organization_id
        left join public.subscription_plan_versions pv on pv.id=s.plan_version_id
        left join public.subscription_plans p on p.id=pv.plan_id
        order by s.updated_at desc, s.id
        limit p_limit
      ) x
    ), '[]'::jsonb),
    'cycles', coalesce((
      select jsonb_agg(x.item order by x.created_at desc, x.id)
      from (
        select c.id, c.created_at, jsonb_build_object(
          'id', c.id,
          'subscription_id', c.subscription_id,
          'organization_id', c.organization_id,
          'organization_name', o.display_name,
          'plan_code', p.code,
          'cycle_number', c.cycle_number,
          'period_start', c.period_start,
          'period_end', c.period_end,
          'currency', c.currency,
          'amount_minor', c.amount_minor::text,
          'created_at', c.created_at
        ) item
        from public.subscription_cycles c
        join public.organizations o on o.id=c.organization_id
        join public.subscription_plan_versions pv on pv.id=c.plan_version_id
        join public.subscription_plans p on p.id=pv.plan_id
        order by c.created_at desc, c.id
        limit p_limit
      ) x
    ), '[]'::jsonb),
    'provider_payments', coalesce((
      select jsonb_agg(x.item order by x.paid_on desc, x.id)
      from (
        select pay.id, pay.paid_on, jsonb_build_object(
          'id', pay.id,
          'organization_id', pay.provider_organization_id,
          'organization_name', o.display_name,
          'payment_reference', pay.payment_reference,
          'currency', pay.currency,
          'amount_minor', pay.amount_minor::text,
          'allocated_minor', coalesce(sum(a.amount_minor),0)::bigint::text,
          'unallocated_minor', (pay.amount_minor-coalesce(sum(a.amount_minor),0)::bigint)::text,
          'paid_on', pay.paid_on
        ) item
        from public.provider_payments pay
        join public.organizations o on o.id=pay.provider_organization_id
        left join public.provider_payment_allocations a on a.payment_id=pay.id
        group by pay.id, o.display_name
        order by pay.paid_on desc, pay.id
        limit p_limit
      ) x
    ), '[]'::jsonb),
    'provider_invoices', coalesce((
      select jsonb_agg(x.item order by x.due_on, x.id)
      from (
        select b.id, b.due_on, jsonb_build_object(
          'id', b.id,
          'organization_id', b.provider_organization_id,
          'organization_name', o.display_name,
          'invoice_number', b.invoice_number,
          'currency', b.currency,
          'total_minor', b.total_minor::text,
          'paid_minor', b.paid_minor::text,
          'outstanding_minor', b.outstanding_minor::text,
          'payment_status', b.payment_status,
          'due_on', b.due_on
        ) item
        from public.provider_invoice_balances b
        join public.organizations o on o.id=b.provider_organization_id
        where b.outstanding_minor>0
        order by b.due_on, b.id
        limit p_limit
      ) x
    ), '[]'::jsonb)
  ) into result;
  return result;
end
$$;

revoke all on function public.list_admin_finance_dashboard(integer) from public, anon, authenticated, service_role;
grant execute on function public.list_admin_finance_dashboard(integer) to authenticated;

notify pgrst, 'reload schema';
commit;
