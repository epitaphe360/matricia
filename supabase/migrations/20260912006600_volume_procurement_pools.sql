-- Versioned volume procurement, exact capacity accounting and immutable economic events.

create table public.service_skus (
  id uuid primary key default extensions.gen_random_uuid(),
  service_id uuid not null references public.catalog_services(id) on delete restrict,
  code text not null check (code ~ '^[A-Z][A-Z0-9_-]{2,79}$'),
  version integer not null check (version > 0),
  status text not null check (status in ('DRAFT','ACTIVE','RETIRED')),
  unit_code text not null check (unit_code ~ '^[A-Z][A-Z0-9_]{1,39}$'),
  unit_quantity numeric(20,6) not null check (unit_quantity > 0),
  deliverables jsonb not null check (jsonb_typeof(deliverables) = 'array'),
  exclusions jsonb not null check (jsonb_typeof(exclusions) = 'array'),
  acceptance_criteria jsonb not null check (jsonb_typeof(acceptance_criteria) = 'array'),
  correction_limit integer not null check (correction_limit >= 0),
  sla_days integer not null check (sla_days > 0),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  reference_cost_minor bigint not null check (reference_cost_minor >= 0),
  credit_cost integer not null check (credit_cost >= 0),
  effective_from date not null,
  effective_to date,
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (code, version),
  unique (id, service_id),
  check (effective_to is null or effective_to >= effective_from)
);

create unique index service_skus_one_active_version_idx on public.service_skus(code) where status = 'ACTIVE';

create table public.framework_agreements (
  id uuid primary key default extensions.gen_random_uuid(),
  owner_organization_id uuid not null references public.organizations(id) on delete restrict,
  sku_id uuid not null references public.service_skus(id) on delete restrict,
  agreement_code text not null,
  status text not null default 'DRAFT' check (status in ('DRAFT','ACTIVE','SUSPENDED','EXPIRED','TERMINATED')),
  current_version integer not null default 1 check (current_version > 0),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (owner_organization_id, agreement_code),
  unique (owner_organization_id, id)
);

create table public.framework_agreement_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  agreement_id uuid not null references public.framework_agreements(id) on delete restrict,
  version integer not null check (version > 0),
  valid_from date not null,
  valid_to date not null,
  forecast_units numeric(20,6) not null check (forecast_units > 0),
  minimum_commitment_units numeric(20,6) not null check (minimum_commitment_units >= 0),
  maximum_units numeric(20,6) not null check (maximum_units > 0),
  payment_model text not null check (payment_model in ('PAY_PER_USE','PREPAID','HYBRID')),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  price_tiers jsonb not null check (jsonb_typeof(price_tiers) = 'array'),
  rebate_rules jsonb not null check (jsonb_typeof(rebate_rules) = 'array'),
  sla_snapshot jsonb not null check (jsonb_typeof(sla_snapshot) = 'object'),
  penalty_rules jsonb not null check (jsonb_typeof(penalty_rules) = 'array'),
  exit_rules jsonb not null check (jsonb_typeof(exit_rules) = 'object'),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (agreement_id, version),
  unique (agreement_id, id),
  check (valid_to >= valid_from),
  check (minimum_commitment_units <= maximum_units),
  check (forecast_units <= maximum_units)
);

create table public.provider_capacity_commitments (
  id uuid primary key default extensions.gen_random_uuid(),
  agreement_id uuid not null,
  agreement_version_id uuid not null,
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  capacity_units numeric(20,6) not null check (capacity_units > 0),
  committed_units numeric(20,6) not null default 0 check (committed_units >= 0),
  consumed_units numeric(20,6) not null default 0 check (consumed_units >= 0),
  released_units numeric(20,6) not null default 0 check (released_units >= 0),
  allocation_share_basis_points integer not null check (allocation_share_basis_points between 1 and 10000),
  quality_score_basis_points integer not null check (quality_score_basis_points between 0 and 10000),
  region_codes text[] not null default '{}',
  monthly_capacity_units numeric(20,6) not null check (monthly_capacity_units > 0),
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  status text not null default 'ACTIVE' check (status in ('ACTIVE','SUSPENDED','EXPIRED','TERMINATED')),
  created_at timestamptz not null default clock_timestamp(),
  foreign key (agreement_id, agreement_version_id) references public.framework_agreement_versions(agreement_id, id) on delete restrict,
  unique (agreement_version_id, provider_organization_id),
  unique (agreement_version_id, id),
  check (committed_units + consumed_units + released_units <= capacity_units)
);

create table public.service_inventory_pools (
  id uuid primary key default extensions.gen_random_uuid(),
  owner_organization_id uuid not null references public.organizations(id) on delete restrict,
  agreement_id uuid not null,
  agreement_version_id uuid not null,
  contracted_units numeric(20,6) not null check (contracted_units > 0),
  available_units numeric(20,6) not null check (available_units >= 0),
  reserved_units numeric(20,6) not null default 0 check (reserved_units >= 0),
  committed_units numeric(20,6) not null default 0 check (committed_units >= 0),
  consumed_units numeric(20,6) not null default 0 check (consumed_units >= 0),
  released_units numeric(20,6) not null default 0 check (released_units >= 0),
  low_stock_threshold_units numeric(20,6) not null check (low_stock_threshold_units >= 0),
  reservation_ttl interval not null check (reservation_ttl > interval '0 seconds'),
  window_start timestamptz not null,
  window_end timestamptz not null,
  overbooking_allowed boolean not null default false,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','LOW_STOCK','EXHAUSTED','CLOSED')),
  row_version bigint not null default 1 check (row_version > 0),
  created_at timestamptz not null default clock_timestamp(),
  foreign key (agreement_id, agreement_version_id) references public.framework_agreement_versions(agreement_id, id) on delete restrict,
  unique (owner_organization_id, id),
  check (window_end > window_start),
  check (low_stock_threshold_units <= contracted_units),
  check (available_units + reserved_units + committed_units + consumed_units + released_units = contracted_units),
  check (not overbooking_allowed or contracted_units > 0)
);

create table public.service_reservations (
  id uuid primary key default extensions.gen_random_uuid(),
  pool_id uuid not null references public.service_inventory_pools(id) on delete restrict,
  client_organization_id uuid not null references public.organizations(id) on delete restrict,
  benefit_reference text not null check (length(btrim(benefit_reference)) between 3 and 160),
  reserved_units numeric(20,6) not null check (reserved_units > 0),
  consumed_units numeric(20,6) not null default 0 check (consumed_units >= 0),
  released_units numeric(20,6) not null default 0 check (released_units >= 0),
  status text not null default 'RESERVED' check (status in ('RESERVED','COMMITTED','PARTIALLY_CONSUMED','CONSUMED','RELEASED','EXPIRED')),
  expires_at timestamptz not null,
  correlation_id uuid not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (client_organization_id, id),
  check (consumed_units + released_units <= reserved_units)
);

create table public.service_provider_allocations (
  id uuid primary key default extensions.gen_random_uuid(),
  reservation_id uuid not null references public.service_reservations(id) on delete restrict,
  agreement_version_id uuid not null,
  provider_commitment_id uuid not null,
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  allocated_units numeric(20,6) not null check (allocated_units > 0),
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  allocation_rule_snapshot jsonb not null check (jsonb_typeof(allocation_rule_snapshot) = 'object'),
  correlation_id uuid not null,
  allocated_by uuid not null references auth.users(id),
  allocated_at timestamptz not null default clock_timestamp(),
  foreign key (agreement_version_id, provider_commitment_id) references public.provider_capacity_commitments(agreement_version_id, id) on delete restrict,
  unique (reservation_id, provider_commitment_id),
  unique (id, provider_commitment_id)
);

create table public.service_inventory_transactions (
  id bigint generated always as identity primary key,
  pool_id uuid not null references public.service_inventory_pools(id) on delete restrict,
  reservation_id uuid references public.service_reservations(id) on delete restrict,
  transaction_type text not null check (transaction_type in ('RESERVED','COMMITTED','CONSUMED','RELEASED','EXPIRED')),
  units numeric(20,6) not null check (units > 0),
  state_before text not null,
  state_after text not null,
  idempotency_key text not null check (length(idempotency_key) between 8 and 200),
  correlation_id uuid not null,
  actor_user_id uuid not null references auth.users(id),
  occurred_at timestamptz not null default clock_timestamp(),
  unique (pool_id, transaction_type, idempotency_key)
);

create table public.service_provider_consumptions (
  id bigint generated always as identity primary key,
  reservation_id uuid not null references public.service_reservations(id) on delete restrict,
  allocation_id uuid not null,
  provider_commitment_id uuid not null,
  consumed_units numeric(20,6) not null check (consumed_units > 0),
  unit_cost_minor bigint not null check (unit_cost_minor >= 0),
  total_cost_minor bigint not null check (total_cost_minor >= 0),
  idempotency_key text not null check (length(idempotency_key) between 8 and 200),
  correlation_id uuid not null,
  consumed_by uuid not null references auth.users(id),
  consumed_at timestamptz not null default clock_timestamp(),
  foreign key (allocation_id, provider_commitment_id) references public.service_provider_allocations(id, provider_commitment_id) on delete restrict,
  unique (allocation_id, idempotency_key)
);

create table public.volume_rebate_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  agreement_id uuid not null references public.framework_agreements(id) on delete restrict,
  version integer not null check (version > 0),
  effective_from date not null,
  effective_to date,
  threshold_units numeric(20,6) not null check (threshold_units > 0),
  rebate_basis_points integer not null check (rebate_basis_points between 0 and 10000),
  calculation_basis text not null check (calculation_basis in ('CONSUMED_UNITS','CONSUMED_COST')),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (agreement_id, version),
  check (effective_to is null or effective_to >= effective_from)
);

create table public.volume_rebate_accruals (
  id uuid primary key default extensions.gen_random_uuid(),
  pool_id uuid not null references public.service_inventory_pools(id) on delete restrict,
  rebate_version_id uuid not null references public.volume_rebate_versions(id) on delete restrict,
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  qualifying_units numeric(20,6) not null check (qualifying_units > 0),
  qualifying_cost_minor bigint not null check (qualifying_cost_minor >= 0),
  rebate_amount_minor bigint not null check (rebate_amount_minor >= 0),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  idempotency_key text not null check (length(idempotency_key) between 8 and 200),
  correlation_id uuid not null,
  accrued_at timestamptz not null default clock_timestamp(),
  unique (pool_id, rebate_version_id, provider_organization_id),
  unique (pool_id, idempotency_key)
);

create or replace function private.volume_admin_access(p_actor uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=pg_catalog,private as $$
  select private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],p_actor)
$$;

create or replace function private.volume_pool_read_access(p_pool_id uuid,p_actor uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=pg_catalog,public,private as $$
  select private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','READ_ONLY_AUDITOR'],p_actor)
    or exists(select 1 from public.service_reservations r where r.pool_id=p_pool_id and private.is_active_org_member(r.client_organization_id,p_actor))
    or exists(select 1 from public.service_provider_allocations a where a.reservation_id in(select r.id from public.service_reservations r where r.pool_id=p_pool_id) and private.is_active_org_member(a.provider_organization_id,p_actor))
$$;

create or replace function private.begin_volume_command(p_organization_id uuid,p_scope text,p_key text,p_hash text,p_actor uuid) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public as $$
declare v public.idempotency_keys%rowtype;n integer;
begin
  if length(p_key) not between 8 and 200 or p_hash !~ '^[0-9a-f]{64}$' then raise exception 'INVALID_IDEMPOTENCY' using errcode='22023'; end if;
  insert into public.idempotency_keys(organization_id,operation_scope,key,request_hash,created_by,expires_at)
  values(p_organization_id,p_scope,p_key,p_hash,p_actor,now()+interval '30 days') on conflict do nothing;
  get diagnostics n=row_count;
  if n=1 then return null; end if;
  select * into v from public.idempotency_keys where organization_id=p_organization_id and operation_scope=p_scope and key=p_key for update;
  if v.request_hash<>p_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if;
  if v.status='COMPLETED' then return v.response_body; end if;
  raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000';
end$$;

create or replace function private.finish_volume_command(p_organization_id uuid,p_scope text,p_key text,p_response jsonb) returns void
language sql security definer set search_path=pg_catalog,public as $$
  update public.idempotency_keys set status='COMPLETED',response_code=201,response_body=p_response,completed_at=clock_timestamp()
  where organization_id=p_organization_id and operation_scope=p_scope and key=p_key and status='PROCESSING'
$$;

create or replace function public.reserve_service_units(p_pool_id uuid,p_client_organization_id uuid,p_benefit_reference text,p_units numeric,p_expires_at timestamptz,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();p public.service_inventory_pools%rowtype;h text;r jsonb;rid uuid;next_status text;
begin
  if a is null or not(private.has_org_role(p_client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],a)or private.volume_admin_access(a)) then raise exception 'VOLUME_RESERVATION_DENIED' using errcode='42501'; end if;
  if p_units is null or p_units<=0 or p_expires_at<=clock_timestamp() or length(btrim(coalesce(p_benefit_reference,'')))not between 3 and 160 then raise exception 'INVALID_VOLUME_RESERVATION' using errcode='22023';end if;
  h:=private.canonical_request_hash(jsonb_build_object('pool',p_pool_id,'client',p_client_organization_id,'benefit',p_benefit_reference,'units',p_units,'expires_at',p_expires_at));
  r:=private.begin_volume_command(p_client_organization_id,'volume.pool.reserve',p_idempotency_key,h,a);if r is not null then return r;end if;
  select * into p from public.service_inventory_pools where id=p_pool_id for update;
  if not found or p.status not in('ACTIVE','LOW_STOCK') or clock_timestamp() not between p.window_start and p.window_end then raise exception 'VOLUME_POOL_NOT_ACTIVE' using errcode='55000';end if;
  if p_expires_at>least(p.window_end,clock_timestamp()+p.reservation_ttl) then raise exception 'RESERVATION_EXPIRY_EXCEEDS_POLICY' using errcode='23514';end if;
  if p_units>p.available_units then raise exception 'VOLUME_POOL_EXHAUSTED' using errcode='23514';end if;
  next_status:=case when p.available_units-p_units=0 then 'EXHAUSTED' when p.available_units-p_units<=p.low_stock_threshold_units then 'LOW_STOCK' else 'ACTIVE'end;
  update public.service_inventory_pools set available_units=available_units-p_units,reserved_units=reserved_units+p_units,status=next_status,row_version=row_version+1 where id=p.id;
  insert into public.service_reservations(pool_id,client_organization_id,benefit_reference,reserved_units,expires_at,correlation_id,created_by)values(p.id,p_client_organization_id,p_benefit_reference,p_units,p_expires_at,p_correlation_id,a)returning id into rid;
  insert into public.service_inventory_transactions(pool_id,reservation_id,transaction_type,units,state_before,state_after,idempotency_key,correlation_id,actor_user_id)values(p.id,rid,'RESERVED',p_units,p.status,next_status,p_idempotency_key,p_correlation_id,a);
  r:=jsonb_build_object('outcome','SERVICE_UNITS_RESERVED','reservation_id',rid,'pool_id',p.id,'units',p_units,'pool_status',next_status);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_client_organization_id,a,'USER','volume.units_reserved','service_reservation',rid::text,p_correlation_id,jsonb_build_object('pool_id',p.id,'units',p_units),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_client_organization_id,'service_reservation',rid::text,'ServiceUnitReservedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_volume_command(p_client_organization_id,'volume.pool.reserve',p_idempotency_key,r);return r;
end$$;

create or replace function public.allocate_provider_from_pool(p_reservation_id uuid,p_provider_commitment_id uuid,p_units numeric,p_rule_snapshot jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();rs public.service_reservations%rowtype;p public.service_inventory_pools%rowtype;c public.provider_capacity_commitments%rowtype;av public.framework_agreement_versions%rowtype;already numeric;h text;r jsonb;aid uuid;fully boolean;
begin
  if a is null or not private.volume_admin_access(a) then raise exception 'PROVIDER_ALLOCATION_DENIED' using errcode='42501';end if;
  if p_units is null or p_units<=0 or jsonb_typeof(p_rule_snapshot)<>'object' then raise exception 'INVALID_PROVIDER_ALLOCATION' using errcode='22023';end if;
  select * into rs from public.service_reservations where id=p_reservation_id for update;if not found or rs.status not in('RESERVED')or rs.expires_at<=clock_timestamp()then raise exception 'RESERVATION_NOT_ALLOCATABLE' using errcode='55000';end if;
  select * into p from public.service_inventory_pools where id=rs.pool_id for update;
  h:=private.canonical_request_hash(jsonb_build_object('reservation',rs.id,'commitment',p_provider_commitment_id,'units',p_units,'rule',p_rule_snapshot));r:=private.begin_volume_command(p.owner_organization_id,'volume.pool.provider.allocate',p_idempotency_key,h,a);if r is not null then return r;end if;
  select * into c from public.provider_capacity_commitments where id=p_provider_commitment_id for update;
  if not found or c.status<>'ACTIVE'or c.agreement_version_id<>p.agreement_version_id or c.committed_units+c.consumed_units+p_units>c.capacity_units then raise exception 'PROVIDER_CAPACITY_EXCEEDED_OR_INELIGIBLE' using errcode='23514';end if;
  select coalesce(sum(allocated_units),0)into already from public.service_provider_allocations where reservation_id=rs.id;
  if already+p_units>rs.reserved_units then raise exception 'RESERVATION_OVERALLOCATED' using errcode='23514';end if;
  select * into av from public.framework_agreement_versions where id=p.agreement_version_id;
  insert into public.service_provider_allocations(reservation_id,agreement_version_id,provider_commitment_id,provider_organization_id,allocated_units,unit_price_minor,currency,allocation_rule_snapshot,correlation_id,allocated_by)values(rs.id,p.agreement_version_id,c.id,c.provider_organization_id,p_units,c.unit_price_minor,av.currency,p_rule_snapshot,p_correlation_id,a)returning id into aid;
  update public.provider_capacity_commitments set committed_units=committed_units+p_units where id=c.id;
  fully:=(already+p_units=rs.reserved_units);
  if fully then update public.service_reservations set status='COMMITTED'where id=rs.id;update public.service_inventory_pools set reserved_units=reserved_units-rs.reserved_units,committed_units=committed_units+rs.reserved_units,row_version=row_version+1 where id=p.id;insert into public.service_inventory_transactions(pool_id,reservation_id,transaction_type,units,state_before,state_after,idempotency_key,correlation_id,actor_user_id)values(p.id,rs.id,'COMMITTED',rs.reserved_units,'RESERVED','COMMITTED',p_idempotency_key,p_correlation_id,a);end if;
  r:=jsonb_build_object('outcome','PROVIDER_UNITS_ALLOCATED','allocation_id',aid,'reservation_id',rs.id,'provider_commitment_id',c.id,'units',p_units,'fully_allocated',fully);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p.owner_organization_id,a,'USER','volume.provider_allocated','service_provider_allocation',aid::text,p_correlation_id,jsonb_build_object('reservation_id',rs.id,'provider_organization_id',c.provider_organization_id,'units',p_units),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p.owner_organization_id,'service_reservation',rs.id::text,'ProviderAllocatedFromPoolV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_volume_command(p.owner_organization_id,'volume.pool.provider.allocate',p_idempotency_key,r);return r;
end$$;

create or replace function public.consume_service_units(p_reservation_id uuid,p_provider_consumptions jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();rs public.service_reservations%rowtype;p public.service_inventory_pools%rowtype;x jsonb;al public.service_provider_allocations%rowtype;used numeric;qty numeric;total numeric:=0;cost bigint:=0;line_cost bigint;h text;r jsonb;next_status text;
begin
  select * into rs from public.service_reservations where id=p_reservation_id for update;
  if a is null or not found or not(private.has_org_role(rs.client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],a)or private.volume_admin_access(a))then raise exception 'VOLUME_CONSUMPTION_DENIED' using errcode='42501';end if;
  if rs.status not in('COMMITTED','PARTIALLY_CONSUMED')or jsonb_typeof(p_provider_consumptions)<>'array'or jsonb_array_length(p_provider_consumptions)=0 then raise exception 'RESERVATION_NOT_CONSUMABLE' using errcode='55000';end if;
  h:=private.canonical_request_hash(jsonb_build_object('reservation',rs.id,'provider_consumptions',p_provider_consumptions));r:=private.begin_volume_command(rs.client_organization_id,'volume.pool.consume',p_idempotency_key,h,a);if r is not null then return r;end if;
  select * into p from public.service_inventory_pools where id=rs.pool_id for update;
  for x in select * from jsonb_array_elements(p_provider_consumptions)loop
    qty:=coalesce((x->>'units')::numeric,0);if qty<=0 then raise exception 'INVALID_CONSUMPTION_UNITS' using errcode='22023';end if;
    select * into al from public.service_provider_allocations where id=(x->>'allocation_id')::uuid and reservation_id=rs.id for update;if not found then raise exception 'PROVIDER_ALLOCATION_NOT_FOUND' using errcode='P0002';end if;
    select coalesce(sum(consumed_units),0)into used from public.service_provider_consumptions where allocation_id=al.id;if used+qty>al.allocated_units then raise exception 'PROVIDER_ALLOCATION_OVERCONSUMED' using errcode='23514';end if;
    line_cost:=round(qty*al.unit_price_minor)::bigint;total:=total+qty;cost:=cost+line_cost;
    insert into public.service_provider_consumptions(reservation_id,allocation_id,provider_commitment_id,consumed_units,unit_cost_minor,total_cost_minor,idempotency_key,correlation_id,consumed_by)values(rs.id,al.id,al.provider_commitment_id,qty,al.unit_price_minor,line_cost,p_idempotency_key,p_correlation_id,a);
    update public.provider_capacity_commitments set committed_units=committed_units-qty,consumed_units=consumed_units+qty where id=al.provider_commitment_id;
  end loop;
  if rs.consumed_units+total>rs.reserved_units then raise exception 'RESERVATION_OVERCONSUMED' using errcode='23514';end if;
  next_status:=case when rs.consumed_units+total=rs.reserved_units then 'CONSUMED'else'PARTIALLY_CONSUMED'end;
  update public.service_reservations set consumed_units=consumed_units+total,status=next_status where id=rs.id;
  update public.service_inventory_pools set committed_units=committed_units-total,consumed_units=consumed_units+total,row_version=row_version+1 where id=p.id;
  insert into public.service_inventory_transactions(pool_id,reservation_id,transaction_type,units,state_before,state_after,idempotency_key,correlation_id,actor_user_id)values(p.id,rs.id,'CONSUMED',total,rs.status,next_status,p_idempotency_key,p_correlation_id,a);
  r:=jsonb_build_object('outcome','SERVICE_UNITS_CONSUMED','reservation_id',rs.id,'units',total,'cost_minor',cost,'status',next_status);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(rs.client_organization_id,a,'USER','volume.units_consumed','service_reservation',rs.id::text,p_correlation_id,jsonb_build_object('units',total,'cost_minor',cost),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(rs.client_organization_id,'service_reservation',rs.id::text,'ServiceUnitConsumedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_volume_command(rs.client_organization_id,'volume.pool.consume',p_idempotency_key,r);return r;
end$$;

do $$declare t text;begin foreach t in array array['service_skus','framework_agreements','framework_agreement_versions','provider_capacity_commitments','service_inventory_pools','service_reservations','service_provider_allocations','service_inventory_transactions','service_provider_consumptions','volume_rebate_versions','volume_rebate_accruals']loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);end loop;end$$;

create policy service_skus_authenticated_read on public.service_skus for select to authenticated using(status='ACTIVE'or private.volume_admin_access());
create policy framework_agreements_central_read on public.framework_agreements for select to authenticated using(private.volume_admin_access()or private.has_platform_role(array['READ_ONLY_AUDITOR']));
create policy framework_versions_central_read on public.framework_agreement_versions for select to authenticated using(exists(select 1 from public.framework_agreements a where a.id=agreement_id and(private.volume_admin_access()or private.has_platform_role(array['READ_ONLY_AUDITOR']))));
create policy provider_commitments_scoped_read on public.provider_capacity_commitments for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.volume_admin_access()or private.has_platform_role(array['READ_ONLY_AUDITOR']));
create policy inventory_pools_scoped_read on public.service_inventory_pools for select to authenticated using(private.volume_pool_read_access(id));
create policy reservations_scoped_read on public.service_reservations for select to authenticated using(private.is_active_org_member(client_organization_id)or private.volume_admin_access()or private.has_platform_role(array['READ_ONLY_AUDITOR'])or exists(select 1 from public.service_provider_allocations a where a.reservation_id=id and private.is_active_org_member(a.provider_organization_id)));
create policy provider_allocations_scoped_read on public.service_provider_allocations for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.volume_admin_access()or private.has_platform_role(array['READ_ONLY_AUDITOR'])or exists(select 1 from public.service_reservations r where r.id=reservation_id and private.is_active_org_member(r.client_organization_id)));
create policy inventory_transactions_scoped_read on public.service_inventory_transactions for select to authenticated using(private.volume_pool_read_access(pool_id));
create policy provider_consumptions_scoped_read on public.service_provider_consumptions for select to authenticated using(exists(select 1 from public.service_provider_allocations a join public.service_reservations r on r.id=a.reservation_id where a.id=allocation_id and(private.is_active_org_member(a.provider_organization_id)or private.is_active_org_member(r.client_organization_id)or private.volume_admin_access()or private.has_platform_role(array['READ_ONLY_AUDITOR']))));
create policy rebate_versions_central_read on public.volume_rebate_versions for select to authenticated using(private.volume_admin_access()or private.has_platform_role(array['READ_ONLY_AUDITOR']));
create policy rebate_accruals_scoped_read on public.volume_rebate_accruals for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.volume_admin_access()or private.has_platform_role(array['READ_ONLY_AUDITOR']));

grant select on public.service_skus,public.framework_agreements,public.framework_agreement_versions,public.provider_capacity_commitments,public.service_inventory_pools,public.service_reservations,public.service_provider_allocations,public.service_inventory_transactions,public.service_provider_consumptions,public.volume_rebate_versions,public.volume_rebate_accruals to authenticated;

create trigger service_skus_immutable before update or delete on public.service_skus for each row execute function private.prevent_update_delete();
create trigger framework_versions_immutable before update or delete on public.framework_agreement_versions for each row execute function private.prevent_update_delete();
create trigger provider_allocations_immutable before update or delete on public.service_provider_allocations for each row execute function private.prevent_update_delete();
create trigger inventory_transactions_immutable before update or delete on public.service_inventory_transactions for each row execute function private.prevent_update_delete();
create trigger provider_consumptions_immutable before update or delete on public.service_provider_consumptions for each row execute function private.prevent_update_delete();
create trigger rebate_versions_immutable before update or delete on public.volume_rebate_versions for each row execute function private.prevent_update_delete();
create trigger rebate_accruals_immutable before update or delete on public.volume_rebate_accruals for each row execute function private.prevent_update_delete();

revoke all on function private.volume_admin_access(uuid),private.volume_pool_read_access(uuid,uuid),private.begin_volume_command(uuid,text,text,text,uuid),private.finish_volume_command(uuid,text,text,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.reserve_service_units(uuid,uuid,text,numeric,timestamptz,text,uuid),public.allocate_provider_from_pool(uuid,uuid,numeric,jsonb,text,uuid),public.consume_service_units(uuid,jsonb,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.reserve_service_units(uuid,uuid,text,numeric,timestamptz,text,uuid),public.allocate_provider_from_pool(uuid,uuid,numeric,jsonb,text,uuid),public.consume_service_units(uuid,jsonb,text,uuid) to authenticated;

create index framework_agreements_sku_status_idx on public.framework_agreements(sku_id,status);
create index provider_capacity_available_idx on public.provider_capacity_commitments(agreement_version_id,status,provider_organization_id);
create index inventory_pools_status_window_idx on public.service_inventory_pools(status,window_end);
create index reservations_client_status_idx on public.service_reservations(client_organization_id,status,expires_at);
create index provider_allocations_reservation_idx on public.service_provider_allocations(reservation_id,provider_organization_id);
create index inventory_transactions_pool_time_idx on public.service_inventory_transactions(pool_id,occurred_at desc,id desc);
create index provider_consumptions_reservation_idx on public.service_provider_consumptions(reservation_id,consumed_at desc);
