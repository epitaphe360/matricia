create schema if not exists extensions;
revoke all on schema extensions from public;
grant usage on schema extensions to anon, authenticated, service_role;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists citext with schema extensions;
create extension if not exists btree_gist with schema extensions;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog
as $$
begin
  new.updated_at := statement_timestamp();
  new.row_version := old.row_version + 1;
  return new;
end;
$$;

create or replace function private.prevent_update_delete()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog
as $$
begin
  raise exception 'IMMUTABLE_RECORD' using errcode = '55000';
end;
$$;

create table public.role_definitions (
  code text primary key check (code ~ '^[A-Z][A-Z0-9_]{1,63}$'),
  scope_type text not null check (scope_type in ('PLATFORM','ORGANIZATION','LIBRARY','FRANCHISE')),
  label_fr text not null,
  label_ar text not null,
  created_at timestamptz not null default now()
);

create table public.tax_rule_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  jurisdiction_code text not null,
  category_code text not null,
  version integer not null check (version > 0),
  rate_basis_points integer not null check (rate_basis_points between 0 and 10000),
  effective_from date not null,
  effective_to date,
  status text not null check (status in ('DRAFT','ACTIVE','RETIRED')),
  professional_validation_status text not null check (professional_validation_status in ('DEMO','PENDING','VALIDATED')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  unique (jurisdiction_code, category_code, version),
  check (effective_to is null or effective_to >= effective_from)
);

create table public.franchise_economic_rule_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  franchise_type text not null check (franchise_type in ('IT','STANDARD')),
  version integer not null check (version > 0),
  entry_fee_minor bigint not null check (entry_fee_minor >= 0),
  currency char(3) not null default 'MAD' check (currency ~ '^[A-Z]{3}$'),
  franchisee_share_bps integer not null check (franchisee_share_bps between 0 and 10000),
  neoxa_share_bps integer not null check (neoxa_share_bps between 0 and 10000),
  matricia_share_bps integer not null check (matricia_share_bps between 0 and 10000),
  distribution_basis text not null check (distribution_basis = 'DISTRIBUTABLE_PROFIT'),
  effective_from date not null,
  effective_to date,
  status text not null check (status in ('DRAFT','ACTIVE','RETIRED')),
  created_at timestamptz not null default now(),
  unique (franchise_type, version),
  check (franchisee_share_bps + neoxa_share_bps + matricia_share_bps = 10000),
  check (effective_to is null or effective_to >= effective_from),
  check (franchise_type <> 'IT' or (entry_fee_minor = 0 and franchisee_share_bps = 5000 and neoxa_share_bps = 5000 and matricia_share_bps = 0))
);

alter table public.role_definitions enable row level security;
alter table public.tax_rule_versions enable row level security;
alter table public.franchise_economic_rule_versions enable row level security;

revoke all on public.role_definitions, public.tax_rule_versions, public.franchise_economic_rule_versions from anon, authenticated;
grant select on public.role_definitions, public.tax_rule_versions, public.franchise_economic_rule_versions to authenticated;

create policy role_definitions_authenticated_read on public.role_definitions for select to authenticated using (true);
create policy active_tax_rules_authenticated_read on public.tax_rule_versions for select to authenticated using (status = 'ACTIVE');
create policy active_franchise_rules_authenticated_read on public.franchise_economic_rule_versions for select to authenticated using (status = 'ACTIVE');

create index tax_rule_versions_lookup_idx on public.tax_rule_versions (jurisdiction_code, category_code, effective_from desc) where status = 'ACTIVE';
create index franchise_economic_rules_lookup_idx on public.franchise_economic_rule_versions (franchise_type, effective_from desc) where status = 'ACTIVE';
