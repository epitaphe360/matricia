begin;

create or replace function public.get_admin_volume_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  result jsonb;
begin
  if actor is null or not private.volume_admin_access(actor) then
    raise exception 'ADMIN_VOLUME_DASHBOARD_DENIED' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'generated_at', clock_timestamp(),
    'capabilities', jsonb_build_object(
      'can_allocate', true,
      'can_consume', true
    ),
    'summary', jsonb_build_object(
      'pool_count', (select count(*) from public.service_inventory_pools),
      'active_pool_count', (select count(*) from public.service_inventory_pools where status in ('ACTIVE','LOW_STOCK')),
      'low_stock_count', (select count(*) from public.service_inventory_pools where status = 'LOW_STOCK'),
      'open_reservation_count', (select count(*) from public.service_reservations where status in ('RESERVED','COMMITTED','PARTIALLY_CONSUMED')),
      'client_count', (select count(distinct client_organization_id) from public.service_reservations),
      'provider_count', (select count(distinct provider_organization_id) from public.provider_capacity_commitments where status = 'ACTIVE')
    ),
    'pools', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'agreement_id', p.agreement_id,
        'agreement_version_id', p.agreement_version_id,
        'agreement_code', a.agreement_code,
        'sku_code', s.code,
        'unit_code', s.unit_code,
        'currency', av.currency,
        'contracted_units', p.contracted_units::text,
        'available_units', p.available_units::text,
        'reserved_units', p.reserved_units::text,
        'committed_units', p.committed_units::text,
        'consumed_units', p.consumed_units::text,
        'released_units', p.released_units::text,
        'status', p.status,
        'window_end', p.window_end,
        'row_version', p.row_version::text,
        'reservation_count', (select count(*) from public.service_reservations r where r.pool_id = p.id),
        'client_count', (select count(distinct r.client_organization_id) from public.service_reservations r where r.pool_id = p.id)
      ) order by p.window_end, p.id)
      from public.service_inventory_pools p
      join public.framework_agreements a on a.id = p.agreement_id
      join public.framework_agreement_versions av on av.id = p.agreement_version_id
      join public.service_skus s on s.id = a.sku_id
    ), '[]'::jsonb),
    'reservations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id,
        'pool_id', r.pool_id,
        'reserved_units', r.reserved_units::text,
        'consumed_units', r.consumed_units::text,
        'released_units', r.released_units::text,
        'status', r.status,
        'expires_at', r.expires_at,
        'allocated_units', coalesce((select sum(x.allocated_units) from public.service_provider_allocations x where x.reservation_id = r.id), 0)::text
      ) order by r.expires_at, r.id)
      from public.service_reservations r
      where r.status in ('RESERVED','COMMITTED','PARTIALLY_CONSUMED')
    ), '[]'::jsonb),
    'commitments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'agreement_version_id', c.agreement_version_id,
        'capacity_units', c.capacity_units::text,
        'remaining_units', (c.capacity_units-c.committed_units-c.consumed_units-c.released_units)::text,
        'allocation_share_basis_points', c.allocation_share_basis_points,
        'quality_score_basis_points', c.quality_score_basis_points,
        'unit_price_minor', c.unit_price_minor::text,
        'currency', av.currency,
        'status', c.status
      ) order by c.agreement_version_id, c.quality_score_basis_points desc, c.id)
      from public.provider_capacity_commitments c
      join public.framework_agreement_versions av on av.id = c.agreement_version_id
      where c.status = 'ACTIVE'
        and c.capacity_units-c.committed_units-c.consumed_units-c.released_units > 0
    ), '[]'::jsonb),
    'allocations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', x.id,
        'reservation_id', x.reservation_id,
        'provider_commitment_id', x.provider_commitment_id,
        'allocated_units', x.allocated_units::text,
        'consumed_units', coalesce((select sum(c.consumed_units) from public.service_provider_consumptions c where c.allocation_id = x.id), 0)::text,
        'unit_price_minor', x.unit_price_minor::text,
        'currency', x.currency,
        'allocated_at', x.allocated_at
      ) order by x.allocated_at desc, x.id)
      from public.service_provider_allocations x
      join public.service_reservations r on r.id = x.reservation_id
      where r.status in ('COMMITTED','PARTIALLY_CONSUMED')
    ), '[]'::jsonb)
  ) into result;

  return result;
end
$$;

revoke all on function public.get_admin_volume_dashboard()
  from public, anon, authenticated, service_role;
grant execute on function public.get_admin_volume_dashboard()
  to authenticated;

commit;
