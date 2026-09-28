-- Restore the closure dashboard and exception sweep after 20260921120000
-- replaced the later OVERDUE definitions, and point dispute supervision at the
-- security definer helper instead of an inline policy join.

create or replace function public.list_admin_provider_closure_dashboard(p_limit integer default 100)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  lim integer := greatest(1, least(coalesce(p_limit, 100), 200));
begin
  if actor is null or not private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'FINANCE_MANAGER', 'READ_ONLY_AUDITOR'], actor) then
    raise exception 'ADMIN_CLOSURE_DENIED' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'generated_at', clock_timestamp(),
    'capabilities', jsonb_build_object(
      'can_issue_statement', private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'FINANCE_MANAGER'], actor)
    ),
    'unstatemented', coalesce((
      select jsonb_agg(jsonb_build_object(
        'provider_organization_id', x.provider_organization_id,
        'organization_name', o.display_name,
        'currency', x.currency,
        'event_count', x.event_count,
        'subtotal_minor', x.subtotal_minor::text,
        'tax_minor', x.tax_minor::text,
        'total_minor', (x.subtotal_minor + x.tax_minor)::text
      ) order by o.display_name)
      from (
        select e.provider_organization_id, e.currency, count(*)::integer as event_count,
               coalesce(sum(e.commission_amount_minor), 0)::bigint as subtotal_minor,
               coalesce(sum(e.tax_amount_minor), 0)::bigint as tax_minor
        from public.provider_payable_events e
        where not exists (select 1 from public.provider_statement_lines l where l.payable_event_id = e.id)
        group by e.provider_organization_id, e.currency
        having coalesce(sum(e.commission_amount_minor), 0) + coalesce(sum(e.tax_amount_minor), 0) > 0
        limit lim
      ) x
      join public.organizations o on o.id = x.provider_organization_id
    ), '[]'::jsonb),
    'statements', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'provider_organization_id', s.provider_organization_id, 'organization_name', o.display_name,
        'statement_number', s.statement_number, 'period_start', s.period_start, 'period_end', s.period_end,
        'currency', s.currency, 'total_minor', s.total_minor::text, 'invoiced', exists(select 1 from public.provider_invoices i where i.statement_id = s.id)
      ) order by s.issued_at desc)
      from (
        select * from public.provider_statements order by issued_at desc limit lim
      ) s
      join public.organizations o on o.id = s.provider_organization_id
    ), '[]'::jsonb),
    'overdue_invoices', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', b.id, 'provider_organization_id', b.provider_organization_id, 'organization_name', o.display_name,
        'invoice_number', b.invoice_number, 'due_on', b.due_on, 'currency', b.currency,
        'outstanding_minor', b.outstanding_minor::text,
        'blocks_new_opportunities', true
      ) order by b.due_on)
      from public.provider_invoice_balances b
      join public.organizations o on o.id = b.provider_organization_id
      where b.payment_status = 'OVERDUE'
      limit lim
    ), '[]'::jsonb)
  );
end
$$;

create or replace function public.sweep_admin_exceptions()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  actor uuid := auth.uid();
  rec record;
  opened integer := 0;
  skipped integer := 0;
  due timestamptz := clock_timestamp() + interval '4 hours';
  key text;
  existing uuid;
begin
  if actor is null or not private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'COMPLIANCE_MANAGER', 'SUPPORT_AGENT'], actor) then
    raise exception 'ADMIN_SWEEP_DENIED' using errcode = '42501';
  end if;

  for rec in
    select 'FINANCE'::text as source_kind, 'BILLING_EXCEPTION'::text as resource_type, b.id::text as resource_id,
           b.provider_organization_id as organization_id, 'HIGH'::text as priority,
           'Facture prestataire échue'::text as title_fr, 'فاتورة مقدم خدمة متأخرة'::text as title_ar,
           jsonb_build_object('kind', 'OVERDUE_INVOICE', 'due_on', b.due_on) as context
    from public.provider_invoice_balances b
    where b.payment_status = 'OVERDUE'
    union all
    select 'FINANCE', 'UNSTATMENTED_PAYABLE', e.id::text, e.provider_organization_id, 'MEDIUM',
           'Événement payable non relevé', 'حدث مستحق غير مدرج في كشف',
           jsonb_build_object('kind', 'UNSTATMENTED_PAYABLE', 'occurred_on', e.occurred_on)
    from public.provider_payable_events e
    where not exists (select 1 from public.provider_statement_lines l where l.payable_event_id = e.id)
    union all
    select 'EXCEPTION', 'MATCHING_RUN', m.id::text, r.client_organization_id,
           case when m.status = 'FAILED' then 'HIGH' else 'MEDIUM' end,
           'Matching sans candidat ou en échec', 'مطابقة دون مرشح أو فاشلة',
           jsonb_build_object('kind', 'MATCHING_EXCEPTION', 'status', m.status)
    from public.matching_runs m
    join public.service_requests r on r.id = m.request_id
    where m.status in ('FAILED', 'NO_CANDIDATE')
    union all
    select 'POOL', 'INVENTORY_POOL', p.id::text, p.owner_organization_id, 'MEDIUM',
           'Pool volume en stock faible', 'مجمع حجم بمخزون منخفض',
           jsonb_build_object('kind', 'LOW_STOCK', 'status', p.status)
    from public.service_inventory_pools p
    where p.status = 'LOW_STOCK'
    union all
    select 'FINANCE', 'SUBSCRIPTION', s.id::text, s.organization_id, 'HIGH',
           'Abonnement échu', 'اشتراك متأخر',
           jsonb_build_object('kind', 'PAST_DUE_SUBSCRIPTION', 'status', s.status)
    from public.subscriptions s
    where s.status = 'PAST_DUE'
  loop
    select w.id into existing
    from public.admin_work_items w
    join public.admin_queue_versions q on q.id = w.queue_version_id
    where q.queue_key = 'EXCEPTIONS' and q.status = 'ACTIVE'
      and w.source_kind = rec.source_kind
      and w.resource_type = rec.resource_type
      and w.resource_id = rec.resource_id;
    if existing is not null then
      skipped := skipped + 1;
      continue;
    end if;
    key := left('sweep:' || rec.resource_type || ':' || rec.resource_id, 200);
    begin
      perform public.open_admin_work_item(
        'EXCEPTIONS', rec.organization_id, rec.source_kind, rec.resource_type, rec.resource_id,
        rec.title_fr, rec.title_ar, rec.priority, due, rec.context, rec.title_fr, key, extensions.gen_random_uuid()
      );
      opened := opened + 1;
    exception
      when unique_violation then
        skipped := skipped + 1;
    end;
  end loop;

  return jsonb_build_object('outcome', 'ADMIN_EXCEPTIONS_SWEPT', 'opened', opened, 'skipped', skipped);
end
$$;

revoke all on function public.list_admin_provider_closure_dashboard(integer) from public, anon, authenticated, service_role;
revoke all on function public.sweep_admin_exceptions() from public, anon, authenticated, service_role;
grant execute on function public.list_admin_provider_closure_dashboard(integer) to authenticated;
grant execute on function public.sweep_admin_exceptions() to authenticated;

create or replace function private.franchise_supervises_dispute(p_case_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.dispute_cases d
    join public.missions m on m.id = d.mission_id
    where d.id = p_case_id
      and private.franchise_supervises_contract(m.contract_id, p_actor)
  );
$$;

revoke all on function private.franchise_supervises_dispute(uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function private.franchise_supervises_dispute(uuid, uuid) to authenticated;

drop policy if exists dispute_cases_franchise_library_read on public.dispute_cases;
create policy dispute_cases_franchise_library_read on public.dispute_cases
  for select to authenticated
  using (private.franchise_supervises_dispute(dispute_cases.id));

notify pgrst, 'reload schema';
