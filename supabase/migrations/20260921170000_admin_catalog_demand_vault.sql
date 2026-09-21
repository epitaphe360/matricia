-- ADM-031G/H packs and promotions (grant through issue_credits, no second ledger).
-- ADM-044 versioned platform parameters (allowlist, not a free-form editor).
-- ADM-VOL-002 demand history versus negotiated forecast.
-- ADM-010 admin document vault metadata (no storage paths, no file bytes).

create table public.credit_pack_definitions (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z][A-Z0-9_]{2,63}$'),
  status text not null default 'DRAFT' check (status in ('DRAFT', 'ACTIVE', 'RETIRED')),
  current_version integer not null default 1 check (current_version > 0),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp()
);

create table public.credit_pack_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  pack_id uuid not null references public.credit_pack_definitions(id) on delete restrict,
  version integer not null check (version > 0),
  name_fr text not null check (length(btrim(name_fr)) between 2 and 160),
  name_ar text not null check (length(btrim(name_ar)) between 2 and 160),
  quantity bigint not null check (quantity > 0),
  price_minor bigint not null check (price_minor >= 0),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  validity_days integer not null check (validity_days between 1 and 3660),
  status text not null default 'DRAFT' check (status in ('DRAFT', 'ACTIVE', 'RETIRED')),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (pack_id, version)
);

create unique index credit_pack_versions_one_active_idx
  on public.credit_pack_versions (pack_id)
  where status = 'ACTIVE';

create table public.credit_promotion_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null check (code ~ '^[A-Z][A-Z0-9_]{2,63}$'),
  version integer not null check (version > 0),
  name_fr text not null check (length(btrim(name_fr)) between 2 and 160),
  name_ar text not null check (length(btrim(name_ar)) between 2 and 160),
  bonus_credits bigint not null check (bonus_credits > 0),
  validity_days integer not null check (validity_days between 1 and 3660),
  status text not null default 'DRAFT' check (status in ('DRAFT', 'ACTIVE', 'RETIRED')),
  effective_from timestamptz not null,
  effective_until timestamptz,
  approval_reference text check (approval_reference is null or length(btrim(approval_reference)) between 3 and 160),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (code, version),
  check (effective_until is null or effective_until > effective_from),
  check (status <> 'ACTIVE' or approval_reference is not null)
);

create unique index credit_promotion_versions_one_active_idx
  on public.credit_promotion_versions (code)
  where status = 'ACTIVE';

create table public.platform_parameter_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  parameter_key text not null check (parameter_key in (
    'DOCUMENT_EXPIRY_WARNING_DAYS',
    'VOLUME_RESERVATION_DEFAULT_TTL_HOURS',
    'CREDIT_PROMOTION_MAX_BONUS'
  )),
  version integer not null check (version > 0),
  value_integer bigint not null check (value_integer > 0),
  status text not null default 'DRAFT' check (status in ('DRAFT', 'ACTIVE', 'RETIRED')),
  effective_from timestamptz not null,
  change_reason text not null check (length(btrim(change_reason)) between 10 and 500),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (parameter_key, version)
);

create unique index platform_parameter_versions_one_active_idx
  on public.platform_parameter_versions (parameter_key)
  where status = 'ACTIVE';

alter table public.credit_pack_definitions enable row level security;
alter table public.credit_pack_versions enable row level security;
alter table public.credit_promotion_versions enable row level security;
alter table public.platform_parameter_versions enable row level security;

create policy credit_pack_definitions_admin_read on public.credit_pack_definitions
  for select to authenticated
  using (private.credits_admin_access() or private.has_platform_role(array['READ_ONLY_AUDITOR']));
create policy credit_pack_versions_admin_read on public.credit_pack_versions
  for select to authenticated
  using (private.credits_admin_access() or private.has_platform_role(array['READ_ONLY_AUDITOR']));
create policy credit_promotion_versions_admin_read on public.credit_promotion_versions
  for select to authenticated
  using (private.credits_admin_access() or private.has_platform_role(array['READ_ONLY_AUDITOR']));
create policy platform_parameter_versions_admin_read on public.platform_parameter_versions
  for select to authenticated
  using (private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'FINANCE_MANAGER', 'READ_ONLY_AUDITOR']));

create or replace function public.create_credit_pack_version(
  p_audit_organization_id uuid,
  p_code text,
  p_name_fr text,
  p_name_ar text,
  p_quantity bigint,
  p_price_minor bigint,
  p_currency text,
  p_validity_days integer,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  hid text;
  cached jsonb;
  result jsonb;
  pid uuid;
  vid uuid;
  ver integer;
begin
  if a is null or not private.credits_admin_access(a) then
    raise exception 'CREDIT_CATALOG_DENIED' using errcode = '42501';
  end if;
  if not exists (select 1 from public.organizations where id = p_audit_organization_id and status = 'ACTIVE')
     or p_code !~ '^[A-Z][A-Z0-9_]{2,63}$'
     or length(btrim(coalesce(p_name_fr, ''))) not between 2 and 160
     or length(btrim(coalesce(p_name_ar, ''))) not between 2 and 160
     or p_quantity is null or p_quantity <= 0
     or p_price_minor is null or p_price_minor < 0
     or p_currency !~ '^[A-Z]{3}$'
     or p_validity_days is null or p_validity_days not between 1 and 3660 then
    raise exception 'INVALID_CREDIT_PACK' using errcode = '22023';
  end if;
  hid := private.canonical_request_hash(jsonb_build_object(
    'code', p_code, 'fr', p_name_fr, 'ar', p_name_ar, 'quantity', p_quantity,
    'price', p_price_minor, 'currency', p_currency, 'days', p_validity_days
  ));
  cached := private.begin_credit_command(p_audit_organization_id, 'credits.pack.draft', p_idempotency_key, hid, a);
  if cached is not null then return cached; end if;
  insert into public.credit_pack_definitions(code, status, current_version, created_by)
  values (p_code, 'DRAFT', 1, a)
  on conflict (code) do nothing;
  select id into pid from public.credit_pack_definitions where code = p_code;
  select coalesce(max(version), 0) + 1 into ver from public.credit_pack_versions where pack_id = pid;
  insert into public.credit_pack_versions(
    pack_id, version, name_fr, name_ar, quantity, price_minor, currency, validity_days, status, content_hash, created_by
  ) values (
    pid, ver, btrim(p_name_fr), btrim(p_name_ar), p_quantity, p_price_minor, p_currency, p_validity_days, 'DRAFT', hid, a
  ) returning id into vid;
  update public.credit_pack_definitions set current_version = ver where id = pid;
  result := jsonb_build_object('outcome', 'CREDIT_PACK_DRAFT_CREATED', 'pack_id', pid, 'pack_version_id', vid, 'version', ver, 'status', 'DRAFT');
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (p_audit_organization_id, a, 'USER', 'admin.credit_pack.drafted', 'credit_pack_version', vid::text, p_correlation_id, result, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (p_audit_organization_id, 'credit_pack_version', vid::text, 'CreditPackDraftedV1', p_correlation_id, result, p_idempotency_key);
  perform private.finish_credit_command(p_audit_organization_id, 'credits.pack.draft', p_idempotency_key, result);
  return result;
end
$$;

create or replace function public.activate_credit_pack_version(
  p_audit_organization_id uuid,
  p_pack_version_id uuid,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  row public.credit_pack_versions%rowtype;
  hid text;
  cached jsonb;
  result jsonb;
begin
  if a is null or not private.credits_admin_access(a) or auth.jwt()->>'aal' is distinct from 'aal2' then
    raise exception 'CREDIT_CATALOG_DENIED' using errcode = '42501';
  end if;
  select * into row from public.credit_pack_versions where id = p_pack_version_id for update;
  if not found or row.status <> 'DRAFT' then
    raise exception 'CREDIT_PACK_NOT_ACTIVATABLE' using errcode = '55000';
  end if;
  hid := private.canonical_request_hash(jsonb_build_object('pack_version', row.id, 'hash', row.content_hash));
  cached := private.begin_credit_command(p_audit_organization_id, 'credits.pack.activate', p_idempotency_key, hid, a);
  if cached is not null then return cached; end if;
  update public.credit_pack_versions set status = 'RETIRED' where pack_id = row.pack_id and status = 'ACTIVE';
  update public.credit_pack_versions set status = 'ACTIVE' where id = row.id;
  update public.credit_pack_definitions set status = 'ACTIVE', current_version = row.version where id = row.pack_id;
  result := jsonb_build_object('outcome', 'CREDIT_PACK_ACTIVE', 'pack_version_id', row.id, 'status', 'ACTIVE');
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (p_audit_organization_id, a, 'USER', 'admin.credit_pack.activated', 'credit_pack_version', row.id::text, p_correlation_id, result, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (p_audit_organization_id, 'credit_pack_version', row.id::text, 'CreditPackActivatedV1', p_correlation_id, result, p_idempotency_key);
  perform private.finish_credit_command(p_audit_organization_id, 'credits.pack.activate', p_idempotency_key, result);
  return result;
end
$$;

create or replace function public.grant_credit_pack(
  p_pack_version_id uuid,
  p_organization_id uuid,
  p_wallet_id uuid,
  p_payment_reference text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  row public.credit_pack_versions%rowtype;
  def public.credit_pack_definitions%rowtype;
  hid text;
  cached jsonb;
  issued jsonb;
  result jsonb;
  lot_key text;
begin
  if a is null or not private.credits_admin_access(a) or auth.jwt()->>'aal' is distinct from 'aal2' then
    raise exception 'CREDIT_CATALOG_DENIED' using errcode = '42501';
  end if;
  if length(coalesce(p_idempotency_key, '')) not between 8 and 180
     or length(btrim(coalesce(p_payment_reference, ''))) not between 3 and 160 then
    raise exception 'INVALID_CREDIT_PACK_GRANT' using errcode = '22023';
  end if;
  select * into row from public.credit_pack_versions where id = p_pack_version_id;
  select * into def from public.credit_pack_definitions where id = row.pack_id;
  if row.id is null or row.status <> 'ACTIVE' or def.id is null then
    raise exception 'CREDIT_PACK_NOT_ACTIVE' using errcode = '55000';
  end if;
  hid := private.canonical_request_hash(jsonb_build_object(
    'pack_version', row.id, 'organization', p_organization_id, 'wallet', p_wallet_id, 'payment', p_payment_reference
  ));
  cached := private.begin_credit_command(p_organization_id, 'credits.pack.grant', p_idempotency_key, hid, a);
  if cached is not null then return cached; end if;
  lot_key := p_idempotency_key || ':lot';
  issued := public.issue_credits(
    p_organization_id, p_wallet_id, 'EXTRA_PURCHASE', row.quantity,
    clock_timestamp() + make_interval(days => row.validity_days),
    null, p_payment_reference, row.price_minor, 'CREDIT_PACK_V1', null, lot_key, p_correlation_id
  );
  result := issued || jsonb_build_object('outcome', 'CREDIT_PACK_GRANTED', 'pack_version_id', row.id, 'pack_code', def.code);
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (p_organization_id, a, 'USER', 'admin.credit_pack.granted', 'credit_pack_version', row.id::text, p_correlation_id, result, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (p_organization_id, 'credit_pack_version', row.id::text, 'CreditPackGrantedV1', p_correlation_id, result, p_idempotency_key);
  perform private.finish_credit_command(p_organization_id, 'credits.pack.grant', p_idempotency_key, result);
  return result;
end
$$;

create or replace function public.create_credit_promotion_version(
  p_audit_organization_id uuid,
  p_code text,
  p_name_fr text,
  p_name_ar text,
  p_bonus_credits bigint,
  p_validity_days integer,
  p_effective_from timestamptz,
  p_effective_until timestamptz,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  hid text;
  cached jsonb;
  result jsonb;
  vid uuid;
  ver integer;
  cap bigint;
begin
  if a is null or not private.credits_admin_access(a) then
    raise exception 'CREDIT_CATALOG_DENIED' using errcode = '42501';
  end if;
  select value_integer into cap
  from public.platform_parameter_versions
  where parameter_key = 'CREDIT_PROMOTION_MAX_BONUS' and status = 'ACTIVE';
  if not exists (select 1 from public.organizations where id = p_audit_organization_id and status = 'ACTIVE')
     or p_code !~ '^[A-Z][A-Z0-9_]{2,63}$'
     or length(btrim(coalesce(p_name_fr, ''))) not between 2 and 160
     or length(btrim(coalesce(p_name_ar, ''))) not between 2 and 160
     or p_bonus_credits is null or p_bonus_credits <= 0
     or (cap is not null and p_bonus_credits > cap)
     or p_validity_days is null or p_validity_days not between 1 and 3660
     or p_effective_from is null
     or (p_effective_until is not null and p_effective_until <= p_effective_from) then
    raise exception 'INVALID_CREDIT_PROMOTION' using errcode = '22023';
  end if;
  hid := private.canonical_request_hash(jsonb_build_object(
    'code', p_code, 'fr', p_name_fr, 'ar', p_name_ar, 'bonus', p_bonus_credits,
    'days', p_validity_days, 'from', p_effective_from, 'until', p_effective_until
  ));
  cached := private.begin_credit_command(p_audit_organization_id, 'credits.promotion.draft', p_idempotency_key, hid, a);
  if cached is not null then return cached; end if;
  select coalesce(max(version), 0) + 1 into ver from public.credit_promotion_versions where code = p_code;
  insert into public.credit_promotion_versions(
    code, version, name_fr, name_ar, bonus_credits, validity_days, status, effective_from, effective_until, content_hash, created_by
  ) values (
    p_code, ver, btrim(p_name_fr), btrim(p_name_ar), p_bonus_credits, p_validity_days, 'DRAFT', p_effective_from, p_effective_until, hid, a
  ) returning id into vid;
  result := jsonb_build_object('outcome', 'CREDIT_PROMOTION_DRAFT_CREATED', 'promotion_version_id', vid, 'version', ver, 'status', 'DRAFT');
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (p_audit_organization_id, a, 'USER', 'admin.credit_promotion.drafted', 'credit_promotion_version', vid::text, p_correlation_id, result, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (p_audit_organization_id, 'credit_promotion_version', vid::text, 'CreditPromotionDraftedV1', p_correlation_id, result, p_idempotency_key);
  perform private.finish_credit_command(p_audit_organization_id, 'credits.promotion.draft', p_idempotency_key, result);
  return result;
end
$$;

create or replace function public.activate_credit_promotion_version(
  p_audit_organization_id uuid,
  p_promotion_version_id uuid,
  p_approval_reference text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  row public.credit_promotion_versions%rowtype;
  hid text;
  cached jsonb;
  result jsonb;
begin
  if a is null or not private.credits_admin_access(a) or auth.jwt()->>'aal' is distinct from 'aal2' then
    raise exception 'CREDIT_CATALOG_DENIED' using errcode = '42501';
  end if;
  if length(btrim(coalesce(p_approval_reference, ''))) not between 3 and 160 then
    raise exception 'INVALID_CREDIT_PROMOTION' using errcode = '22023';
  end if;
  select * into row from public.credit_promotion_versions where id = p_promotion_version_id for update;
  if not found or row.status <> 'DRAFT' then
    raise exception 'CREDIT_PROMOTION_NOT_ACTIVATABLE' using errcode = '55000';
  end if;
  hid := private.canonical_request_hash(jsonb_build_object('promotion', row.id, 'approval', p_approval_reference, 'hash', row.content_hash));
  cached := private.begin_credit_command(p_audit_organization_id, 'credits.promotion.activate', p_idempotency_key, hid, a);
  if cached is not null then return cached; end if;
  update public.credit_promotion_versions set status = 'RETIRED' where code = row.code and status = 'ACTIVE';
  update public.credit_promotion_versions
     set status = 'ACTIVE', approval_reference = btrim(p_approval_reference)
   where id = row.id;
  result := jsonb_build_object('outcome', 'CREDIT_PROMOTION_ACTIVE', 'promotion_version_id', row.id, 'status', 'ACTIVE');
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (p_audit_organization_id, a, 'USER', 'admin.credit_promotion.activated', 'credit_promotion_version', row.id::text, p_correlation_id, result, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (p_audit_organization_id, 'credit_promotion_version', row.id::text, 'CreditPromotionActivatedV1', p_correlation_id, result, p_idempotency_key);
  perform private.finish_credit_command(p_audit_organization_id, 'credits.promotion.activate', p_idempotency_key, result);
  return result;
end
$$;

create or replace function public.grant_credit_promotion(
  p_promotion_version_id uuid,
  p_organization_id uuid,
  p_wallet_id uuid,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  row public.credit_promotion_versions%rowtype;
  hid text;
  cached jsonb;
  issued jsonb;
  result jsonb;
  lot_key text;
  cap bigint;
begin
  if a is null or not private.credits_admin_access(a) or auth.jwt()->>'aal' is distinct from 'aal2' then
    raise exception 'CREDIT_CATALOG_DENIED' using errcode = '42501';
  end if;
  if length(coalesce(p_idempotency_key, '')) not between 8 and 180 then
    raise exception 'INVALID_CREDIT_PROMOTION' using errcode = '22023';
  end if;
  select * into row from public.credit_promotion_versions where id = p_promotion_version_id;
  select value_integer into cap
  from public.platform_parameter_versions
  where parameter_key = 'CREDIT_PROMOTION_MAX_BONUS' and status = 'ACTIVE';
  if row.id is null or row.status <> 'ACTIVE' or row.approval_reference is null
     or clock_timestamp() < row.effective_from
     or (row.effective_until is not null and clock_timestamp() >= row.effective_until)
     or (cap is not null and row.bonus_credits > cap) then
    raise exception 'CREDIT_PROMOTION_NOT_GRANTABLE' using errcode = '55000';
  end if;
  hid := private.canonical_request_hash(jsonb_build_object('promotion', row.id, 'organization', p_organization_id, 'wallet', p_wallet_id));
  cached := private.begin_credit_command(p_organization_id, 'credits.promotion.grant', p_idempotency_key, hid, a);
  if cached is not null then return cached; end if;
  lot_key := p_idempotency_key || ':lot';
  issued := public.issue_credits(
    p_organization_id, p_wallet_id, 'PROMOTION', row.bonus_credits,
    clock_timestamp() + make_interval(days => row.validity_days),
    null, row.code, 0, 'CREDIT_PROMOTION_V1', row.approval_reference, lot_key, p_correlation_id
  );
  result := issued || jsonb_build_object('outcome', 'CREDIT_PROMOTION_GRANTED', 'promotion_version_id', row.id, 'code', row.code);
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (p_organization_id, a, 'USER', 'admin.credit_promotion.granted', 'credit_promotion_version', row.id::text, p_correlation_id, result, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (p_organization_id, 'credit_promotion_version', row.id::text, 'CreditPromotionGrantedV1', p_correlation_id, result, p_idempotency_key);
  perform private.finish_credit_command(p_organization_id, 'credits.promotion.grant', p_idempotency_key, result);
  return result;
end
$$;

create or replace function public.create_platform_parameter_version(
  p_audit_organization_id uuid,
  p_parameter_key text,
  p_value_integer bigint,
  p_change_reason text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  hid text;
  cached jsonb;
  result jsonb;
  vid uuid;
  ver integer;
begin
  if a is null or not private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'FINANCE_MANAGER'], a) then
    raise exception 'PLATFORM_PARAMETER_DENIED' using errcode = '42501';
  end if;
  if not exists (select 1 from public.organizations where id = p_audit_organization_id and status = 'ACTIVE')
     or p_parameter_key not in ('DOCUMENT_EXPIRY_WARNING_DAYS', 'VOLUME_RESERVATION_DEFAULT_TTL_HOURS', 'CREDIT_PROMOTION_MAX_BONUS')
     or p_value_integer is null or p_value_integer <= 0
     or (p_parameter_key = 'DOCUMENT_EXPIRY_WARNING_DAYS' and p_value_integer > 365)
     or (p_parameter_key = 'VOLUME_RESERVATION_DEFAULT_TTL_HOURS' and p_value_integer > 2160)
     or (p_parameter_key = 'CREDIT_PROMOTION_MAX_BONUS' and p_value_integer > 1000000)
     or length(btrim(coalesce(p_change_reason, ''))) not between 10 and 500 then
    raise exception 'INVALID_PLATFORM_PARAMETER' using errcode = '22023';
  end if;
  hid := private.canonical_request_hash(jsonb_build_object('key', p_parameter_key, 'value', p_value_integer, 'reason', p_change_reason));
  cached := private.begin_credit_command(p_audit_organization_id, 'platform.parameter.draft', p_idempotency_key, hid, a);
  if cached is not null then return cached; end if;
  select coalesce(max(version), 0) + 1 into ver from public.platform_parameter_versions where parameter_key = p_parameter_key;
  insert into public.platform_parameter_versions(parameter_key, version, value_integer, status, effective_from, change_reason, content_hash, created_by)
  values (p_parameter_key, ver, p_value_integer, 'DRAFT', clock_timestamp(), btrim(p_change_reason), hid, a)
  returning id into vid;
  result := jsonb_build_object('outcome', 'PLATFORM_PARAMETER_DRAFT_CREATED', 'parameter_version_id', vid, 'version', ver, 'status', 'DRAFT');
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (p_audit_organization_id, a, 'USER', 'admin.platform_parameter.drafted', 'platform_parameter_version', vid::text, p_correlation_id, result, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (p_audit_organization_id, 'platform_parameter_version', vid::text, 'PlatformParameterDraftedV1', p_correlation_id, result, p_idempotency_key);
  perform private.finish_credit_command(p_audit_organization_id, 'platform.parameter.draft', p_idempotency_key, result);
  return result;
end
$$;

create or replace function public.activate_platform_parameter_version(
  p_audit_organization_id uuid,
  p_parameter_version_id uuid,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  row public.platform_parameter_versions%rowtype;
  hid text;
  cached jsonb;
  result jsonb;
begin
  if a is null or not private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'FINANCE_MANAGER'], a)
     or auth.jwt()->>'aal' is distinct from 'aal2' then
    raise exception 'PLATFORM_PARAMETER_DENIED' using errcode = '42501';
  end if;
  select * into row from public.platform_parameter_versions where id = p_parameter_version_id for update;
  if not found or row.status <> 'DRAFT' then
    raise exception 'PLATFORM_PARAMETER_NOT_ACTIVATABLE' using errcode = '55000';
  end if;
  hid := private.canonical_request_hash(jsonb_build_object('parameter', row.id, 'hash', row.content_hash));
  cached := private.begin_credit_command(p_audit_organization_id, 'platform.parameter.activate', p_idempotency_key, hid, a);
  if cached is not null then return cached; end if;
  update public.platform_parameter_versions set status = 'RETIRED' where parameter_key = row.parameter_key and status = 'ACTIVE';
  update public.platform_parameter_versions set status = 'ACTIVE', effective_from = clock_timestamp() where id = row.id;
  result := jsonb_build_object('outcome', 'PLATFORM_PARAMETER_ACTIVE', 'parameter_version_id', row.id, 'parameter_key', row.parameter_key, 'value_integer', row.value_integer::text);
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (p_audit_organization_id, a, 'USER', 'admin.platform_parameter.activated', 'platform_parameter_version', row.id::text, p_correlation_id, result, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (p_audit_organization_id, 'platform_parameter_version', row.id::text, 'PlatformParameterActivatedV1', p_correlation_id, result, p_idempotency_key);
  perform private.finish_credit_command(p_audit_organization_id, 'platform.parameter.activate', p_idempotency_key, result);
  return result;
end
$$;

create or replace function public.list_admin_commerce_catalog(p_limit integer default 100)
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
  if actor is null or not (private.credits_admin_access(actor) or private.has_platform_role(array['READ_ONLY_AUDITOR'], actor)) then
    raise exception 'CREDIT_CATALOG_DENIED' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'generated_at', clock_timestamp(),
    'capabilities', jsonb_build_object(
      'can_write', private.credits_admin_access(actor),
      'can_activate', private.credits_admin_access(actor)
    ),
    'packs', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id, 'pack_id', d.id, 'code', d.code, 'version', v.version, 'status', v.status,
        'name_fr', v.name_fr, 'name_ar', v.name_ar, 'quantity', v.quantity::text,
        'price_minor', v.price_minor::text, 'currency', v.currency, 'validity_days', v.validity_days
      ) order by d.code, v.version desc)
      from (select * from public.credit_pack_versions order by created_at desc limit lim) v
      join public.credit_pack_definitions d on d.id = v.pack_id
    ), '[]'::jsonb),
    'promotions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id, 'code', v.code, 'version', v.version, 'status', v.status,
        'name_fr', v.name_fr, 'name_ar', v.name_ar, 'bonus_credits', v.bonus_credits::text,
        'validity_days', v.validity_days, 'effective_from', v.effective_from, 'effective_until', v.effective_until,
        'approval_reference', v.approval_reference
      ) order by v.code, v.version desc)
      from (select * from public.credit_promotion_versions order by created_at desc limit lim) v
    ), '[]'::jsonb),
    'parameters', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id, 'parameter_key', v.parameter_key, 'version', v.version, 'status', v.status,
        'value_integer', v.value_integer::text, 'effective_from', v.effective_from, 'change_reason', v.change_reason
      ) order by v.parameter_key, v.version desc)
      from (select * from public.platform_parameter_versions order by created_at desc limit lim) v
    ), '[]'::jsonb)
  );
end
$$;

create or replace function public.list_admin_volume_demand(p_limit integer default 24)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  lim integer := greatest(1, least(coalesce(p_limit, 24), 60));
  ttl text;
begin
  if actor is null or not (private.volume_admin_access(actor) or private.has_platform_role(array['READ_ONLY_AUDITOR'], actor)) then
    raise exception 'ADMIN_VOLUME_DEMAND_DENIED' using errcode = '42501';
  end if;
  select value_integer::text into ttl
  from public.platform_parameter_versions
  where parameter_key = 'VOLUME_RESERVATION_DEFAULT_TTL_HOURS' and status = 'ACTIVE'
  limit 1;
  return jsonb_build_object(
    'generated_at', clock_timestamp(),
    'default_reservation_ttl_hours', ttl,
    'history', coalesce((
      select jsonb_agg(jsonb_build_object(
        'month_start', month_start, 'sku_code', sku_code,
        'reserved_units', reserved_units, 'consumed_units', consumed_units, 'reservation_count', reservation_count
      ) order by month_start desc, sku_code)
      from (
        select to_char(date_trunc('month', r.created_at), 'YYYY-MM-DD') as month_start,
               s.code as sku_code,
               sum(r.reserved_units)::text as reserved_units,
               sum(r.consumed_units)::text as consumed_units,
               count(*)::integer as reservation_count
        from public.service_reservations r
        join public.service_inventory_pools p on p.id = r.pool_id
        join public.framework_agreements a on a.id = p.agreement_id
        join public.service_skus s on s.id = a.sku_id
        where r.created_at >= clock_timestamp() - interval '12 months'
        group by 1, 2
        order by 1 desc, 2
        limit lim
      ) months
    ), '[]'::jsonb),
    'forecasts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'agreement_code', a.agreement_code, 'sku_code', s.code, 'status', a.status,
        'forecast_units', av.forecast_units::text, 'valid_from', av.valid_from, 'valid_to', av.valid_to
      ) order by a.agreement_code)
      from public.framework_agreements a
      join public.service_skus s on s.id = a.sku_id
      join lateral (
        select * from public.framework_agreement_versions v where v.agreement_id = a.id order by v.version desc limit 1
      ) av on true
      where a.status in ('DRAFT', 'ACTIVE')
      limit lim
    ), '[]'::jsonb)
  );
end
$$;

create or replace function public.list_admin_document_vault(p_limit integer default 80)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  lim integer := greatest(1, least(coalesce(p_limit, 80), 200));
  warn_days integer;
begin
  if actor is null or not private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'COMPLIANCE_MANAGER', 'READ_ONLY_AUDITOR'], actor) then
    raise exception 'ADMIN_DOCUMENT_VAULT_DENIED' using errcode = '42501';
  end if;
  select value_integer into warn_days
  from public.platform_parameter_versions
  where parameter_key = 'DOCUMENT_EXPIRY_WARNING_DAYS' and status = 'ACTIVE'
  limit 1;
  return jsonb_build_object(
    'generated_at', clock_timestamp(),
    'warning_days', warn_days,
    'documents', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', id, 'organization_id', organization_id, 'organization_name', organization_name,
        'source', source, 'document_type', document_type, 'status', status,
        'expires_on', expires_on, 'version', version, 'expiring', expiring
      ) order by expires_on nulls last, organization_name)
      from (
        select * from (
          select d.id, d.organization_id, o.display_name as organization_name, 'CLIENT'::text as source,
                 d.document_type, d.status, d.expires_on, d.version,
                 (warn_days is not null and d.expires_on is not null and d.expires_on <= (current_date + warn_days)) is true as expiring
          from public.client_compliance_documents d
          join public.organizations o on o.id = d.organization_id
          where d.status <> 'SUPERSEDED'
          union all
          select v.id, v.provider_organization_id, o.display_name, 'PROVIDER',
                 f.document_kind, v.status, v.expires_on, v.version_number,
                 (warn_days is not null and v.expires_on is not null and v.expires_on <= (current_date + warn_days)) is true
          from public.provider_document_versions v
          join public.provider_document_families f on f.id = v.family_id
          join public.organizations o on o.id = v.provider_organization_id
          where v.status <> 'SUPERSEDED'
        ) combined
        order by expires_on nulls last, organization_name
        limit lim
      ) docs
    ), '[]'::jsonb)
  );
end
$$;

revoke all on function public.create_credit_pack_version(uuid, text, text, text, bigint, bigint, text, integer, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.activate_credit_pack_version(uuid, uuid, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.grant_credit_pack(uuid, uuid, uuid, text, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.create_credit_promotion_version(uuid, text, text, text, bigint, integer, timestamptz, timestamptz, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.activate_credit_promotion_version(uuid, uuid, text, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.grant_credit_promotion(uuid, uuid, uuid, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.create_platform_parameter_version(uuid, text, bigint, text, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.activate_platform_parameter_version(uuid, uuid, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.list_admin_commerce_catalog(integer) from public, anon, authenticated, service_role;
revoke all on function public.list_admin_volume_demand(integer) from public, anon, authenticated, service_role;
revoke all on function public.list_admin_document_vault(integer) from public, anon, authenticated, service_role;

grant execute on function public.create_credit_pack_version(uuid, text, text, text, bigint, bigint, text, integer, text, uuid) to authenticated;
grant execute on function public.activate_credit_pack_version(uuid, uuid, text, uuid) to authenticated;
grant execute on function public.grant_credit_pack(uuid, uuid, uuid, text, text, uuid) to authenticated;
grant execute on function public.create_credit_promotion_version(uuid, text, text, text, bigint, integer, timestamptz, timestamptz, text, uuid) to authenticated;
grant execute on function public.activate_credit_promotion_version(uuid, uuid, text, text, uuid) to authenticated;
grant execute on function public.grant_credit_promotion(uuid, uuid, uuid, text, uuid) to authenticated;
grant execute on function public.create_platform_parameter_version(uuid, text, bigint, text, text, uuid) to authenticated;
grant execute on function public.activate_platform_parameter_version(uuid, uuid, text, uuid) to authenticated;
grant execute on function public.list_admin_commerce_catalog(integer) to authenticated;
grant execute on function public.list_admin_volume_demand(integer) to authenticated;
grant execute on function public.list_admin_document_vault(integer) to authenticated;

notify pgrst, 'reload schema';
