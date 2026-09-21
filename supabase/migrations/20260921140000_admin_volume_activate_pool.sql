-- ADM-VOL-005/006: activate framework (FRAMEWORK_ACTIVE) then open virtual pool (POOL_ACTIVE).
-- Reuses volume_admin_access, begin_volume_command and AAL2. Versions remain immutable.

create unique index if not exists service_inventory_pools_one_open_version_idx
  on public.service_inventory_pools (agreement_version_id)
  where status in ('ACTIVE', 'LOW_STOCK', 'EXHAUSTED');

create or replace function public.activate_framework_pool(
  p_agreement_id uuid,
  p_contracted_units numeric,
  p_low_stock_threshold_units numeric,
  p_reservation_ttl_hours integer,
  p_provider_organization_id uuid,
  p_provider_capacity_units numeric,
  p_unit_price_minor bigint,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  agr public.framework_agreements%rowtype;
  av public.framework_agreement_versions%rowtype;
  hid text;
  cached jsonb;
  result jsonb;
  contracted numeric(20,6);
  threshold numeric(20,6);
  ttl interval;
  win_start timestamptz;
  win_end timestamptz;
  pid uuid;
  cid uuid;
  existing uuid;
begin
  if a is null or not private.volume_admin_access(a) or auth.jwt()->>'aal' is distinct from 'aal2' then
    raise exception 'FRAMEWORK_POOL_DENIED' using errcode = '42501';
  end if;

  select * into agr from public.framework_agreements where id = p_agreement_id for update;
  if not found or agr.status not in ('DRAFT', 'ACTIVE') then
    raise exception 'FRAMEWORK_NOT_ACTIVATABLE' using errcode = '55000';
  end if;
  if not exists (select 1 from public.organizations where id = agr.owner_organization_id and status = 'ACTIVE')
     or not exists (select 1 from public.service_skus where id = agr.sku_id and status = 'ACTIVE') then
    raise exception 'FRAMEWORK_SKU_OR_OWNER_INACTIVE' using errcode = '55000';
  end if;

  select * into av from public.framework_agreement_versions
   where agreement_id = agr.id
   order by version desc
   limit 1;
  if not found then
    raise exception 'FRAMEWORK_VERSION_REQUIRED' using errcode = 'P0002';
  end if;

  contracted := coalesce(p_contracted_units, av.forecast_units);
  threshold := coalesce(p_low_stock_threshold_units, 0);
  ttl := make_interval(hours => coalesce(p_reservation_ttl_hours, 168));
  win_start := av.valid_from::timestamptz;
  win_end := (av.valid_to + 1)::timestamptz;

  if contracted is null or contracted <= 0
     or contracted < av.minimum_commitment_units
     or contracted > av.maximum_units
     or threshold < 0 or threshold > contracted
     or coalesce(p_reservation_ttl_hours, 168) not between 1 and 2160
     or win_end <= win_start
     or (p_provider_organization_id is null) <> (p_provider_capacity_units is null)
     or (p_provider_organization_id is null) <> (p_unit_price_minor is null)
     or (p_provider_organization_id is not null and (
          p_provider_capacity_units <= 0
          or p_unit_price_minor < 0
          or not exists (select 1 from public.organizations where id = p_provider_organization_id and status = 'ACTIVE')
        )) then
    raise exception 'INVALID_FRAMEWORK_POOL' using errcode = '22023';
  end if;

  hid := private.canonical_request_hash(jsonb_build_object(
    'agreement', agr.id, 'version', av.id, 'contracted', contracted, 'threshold', threshold,
    'ttl_hours', coalesce(p_reservation_ttl_hours, 168),
    'provider', p_provider_organization_id, 'capacity', p_provider_capacity_units, 'price', p_unit_price_minor
  ));
  cached := private.begin_volume_command(agr.owner_organization_id, 'volume.framework.pool.activate', p_idempotency_key, hid, a);
  if cached is not null then return cached; end if;

  select p.id into existing
  from public.service_inventory_pools p
  where p.agreement_version_id = av.id
    and p.status in ('ACTIVE', 'LOW_STOCK', 'EXHAUSTED');
  if existing is not null then
    raise exception 'POOL_ALREADY_ACTIVE' using errcode = '55000';
  end if;

  if agr.status = 'DRAFT' then
    update public.framework_agreements set status = 'ACTIVE' where id = agr.id;
  end if;

  insert into public.service_inventory_pools(
    owner_organization_id, agreement_id, agreement_version_id,
    contracted_units, available_units, reserved_units, committed_units, consumed_units, released_units,
    low_stock_threshold_units, reservation_ttl, window_start, window_end, overbooking_allowed, status
  ) values (
    agr.owner_organization_id, agr.id, av.id,
    contracted, contracted, 0, 0, 0, 0,
    threshold, ttl, win_start, win_end, false, 'ACTIVE'
  ) returning id into pid;

  if p_provider_organization_id is not null then
    insert into public.provider_capacity_commitments(
      agreement_id, agreement_version_id, provider_organization_id,
      capacity_units, allocation_share_basis_points, quality_score_basis_points,
      monthly_capacity_units, unit_price_minor, status
    ) values (
      agr.id, av.id, p_provider_organization_id,
      p_provider_capacity_units, 10000, 5000,
      p_provider_capacity_units, p_unit_price_minor, 'ACTIVE'
    )
    on conflict (agreement_version_id, provider_organization_id) do nothing;
    select id into cid
    from public.provider_capacity_commitments
    where agreement_version_id = av.id and provider_organization_id = p_provider_organization_id;
  end if;

  result := jsonb_build_object(
    'outcome', 'POOL_ACTIVE',
    'framework_status', 'ACTIVE',
    'agreement_id', agr.id,
    'agreement_version_id', av.id,
    'pool_id', pid,
    'provider_commitment_id', cid,
    'contracted_units', contracted::text
  );
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (agr.owner_organization_id, a, 'USER', 'admin.framework.pool_activated', 'service_inventory_pool', pid::text, p_correlation_id, result, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (agr.owner_organization_id, 'service_inventory_pool', pid::text, 'VolumePoolActivatedV1', p_correlation_id, result, p_idempotency_key);
  perform private.finish_volume_command(agr.owner_organization_id, 'volume.framework.pool.activate', p_idempotency_key, result);
  return result;
end
$$;

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
      'can_consume', true,
      'can_negotiate', true,
      'can_activate_pool', true
    ),
    'summary', jsonb_build_object(
      'pool_count', (select count(*) from public.service_inventory_pools),
      'active_pool_count', (select count(*) from public.service_inventory_pools where status in ('ACTIVE', 'LOW_STOCK')),
      'low_stock_count', (select count(*) from public.service_inventory_pools where status = 'LOW_STOCK'),
      'open_reservation_count', (select count(*) from public.service_reservations where status in ('RESERVED', 'COMMITTED', 'PARTIALLY_CONSUMED')),
      'client_count', (select count(distinct client_organization_id) from public.service_reservations),
      'provider_count', (select count(distinct provider_organization_id) from public.provider_capacity_commitments where status = 'ACTIVE'),
      'draft_agreement_count', (select count(*) from public.framework_agreements where status = 'DRAFT')
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
      where r.status in ('RESERVED', 'COMMITTED', 'PARTIALLY_CONSUMED')
    ), '[]'::jsonb),
    'commitments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'agreement_version_id', c.agreement_version_id,
        'capacity_units', c.capacity_units::text,
        'remaining_units', (c.capacity_units - c.committed_units - c.consumed_units - c.released_units)::text,
        'allocation_share_basis_points', c.allocation_share_basis_points,
        'quality_score_basis_points', c.quality_score_basis_points,
        'unit_price_minor', c.unit_price_minor::text,
        'currency', av.currency,
        'status', c.status
      ) order by c.agreement_version_id, c.quality_score_basis_points desc, c.id)
      from public.provider_capacity_commitments c
      join public.framework_agreement_versions av on av.id = c.agreement_version_id
      where c.status = 'ACTIVE'
        and c.capacity_units - c.committed_units - c.consumed_units - c.released_units > 0
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
      where r.status in ('COMMITTED', 'PARTIALLY_CONSUMED')
    ), '[]'::jsonb),
    'agreements', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'agreement_code', a.agreement_code, 'status', a.status, 'sku_code', s.code,
        'agreement_version_id', av.id, 'currency', av.currency, 'valid_from', av.valid_from, 'valid_to', av.valid_to,
        'forecast_units', av.forecast_units::text, 'minimum_commitment_units', av.minimum_commitment_units::text,
        'maximum_units', av.maximum_units::text, 'payment_model', av.payment_model,
        'owner_organization_id', a.owner_organization_id, 'pool_id', pool.id, 'pool_status', pool.status
      ) order by a.created_at desc)
      from public.framework_agreements a
      join public.service_skus s on s.id = a.sku_id
      left join lateral (
        select * from public.framework_agreement_versions v where v.agreement_id = a.id order by v.version desc limit 1
      ) av on true
      left join lateral (
        select p.id, p.status
        from public.service_inventory_pools p
        where p.agreement_version_id = av.id and p.status in ('ACTIVE', 'LOW_STOCK', 'EXHAUSTED')
        order by p.created_at desc
        limit 1
      ) pool on true
    ), '[]'::jsonb),
    'skus', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'code', s.code, 'unit_code', s.unit_code, 'currency', s.currency,
        'reference_cost_minor', s.reference_cost_minor::text
      ) order by s.code)
      from public.service_skus s
      where s.status = 'ACTIVE'
    ), '[]'::jsonb),
    'profitability', coalesce((
      select jsonb_agg(jsonb_build_object(
        'agreement_code', a.agreement_code, 'sku_code', s.code, 'currency', av.currency,
        'consumed_units', p.consumed_units::text,
        'consumed_cost_minor', coalesce((
          select sum(c.total_cost_minor) from public.service_provider_consumptions c
          join public.service_reservations r on r.id = c.reservation_id
          where r.pool_id = p.id
        ), 0)::text,
        'reference_cost_minor', s.reference_cost_minor::text
      ) order by a.agreement_code)
      from public.service_inventory_pools p
      join public.framework_agreements a on a.id = p.agreement_id
      join public.framework_agreement_versions av on av.id = p.agreement_version_id
      join public.service_skus s on s.id = a.sku_id
    ), '[]'::jsonb)
  ) into result;

  return result;
end
$$;

revoke all on function public.activate_framework_pool(uuid, numeric, numeric, integer, uuid, numeric, bigint, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.get_admin_volume_dashboard() from public, anon, authenticated, service_role;
grant execute on function public.activate_framework_pool(uuid, numeric, numeric, integer, uuid, numeric, bigint, text, uuid) to authenticated;
grant execute on function public.get_admin_volume_dashboard() to authenticated;

notify pgrst, 'reload schema';
