create table public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (length(trim(display_name)) between 2 and 120),
  preferred_locale text not null default 'fr-MA' check (preferred_locale in ('fr-MA','ar-MA')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version integer not null default 1 check (row_version > 0)
);

create table public.organizations (
  id uuid primary key default extensions.gen_random_uuid(),
  legal_name text not null check (length(trim(legal_name)) between 2 and 200),
  display_name text not null check (length(trim(display_name)) between 2 and 200),
  country_code char(2) not null default 'MA' check (country_code ~ '^[A-Z]{2}$'),
  status text not null default 'PENDING' check (status in ('PENDING','ACTIVE','SUSPENDED','ARCHIVED')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version integer not null default 1 check (row_version > 0)
);

create table public.organization_identifiers (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  identifier_type text not null check (identifier_type in ('ICE','RC','IF','CNSS','OTHER')),
  normalized_value extensions.citext not null,
  verification_status text not null default 'UNVERIFIED' check (verification_status in ('UNVERIFIED','PENDING','VERIFIED','REJECTED')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, identifier_type, normalized_value)
);

create unique index organization_verified_ice_uidx
on public.organization_identifiers (normalized_value)
where identifier_type = 'ICE' and verification_status = 'VERIFIED' and is_active;

create table public.organization_memberships (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'INVITED' check (status in ('INVITED','ACTIVE','SUSPENDED','REVOKED')),
  invited_by uuid references auth.users(id),
  activated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version integer not null default 1 check (row_version > 0),
  unique (organization_id, user_id)
);

create table public.organization_member_roles (
  membership_id uuid not null references public.organization_memberships(id) on delete cascade,
  role_code text not null references public.role_definitions(code),
  library_id uuid,
  franchise_id uuid,
  granted_by uuid references auth.users(id),
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  primary key (membership_id, role_code)
);

create table public.platform_user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role_code text not null references public.role_definitions(code),
  granted_by uuid references auth.users(id),
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  primary key (user_id, role_code)
);

create or replace function private.is_active_org_member(target_organization_id uuid, target_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1 from public.organization_memberships membership
    where membership.organization_id = target_organization_id
      and membership.user_id = target_user_id
      and membership.status = 'ACTIVE'
  );
$$;

create or replace function private.has_org_role(target_organization_id uuid, allowed_roles text[], target_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.organization_memberships membership
    join public.organization_member_roles member_role on member_role.membership_id = membership.id
    where membership.organization_id = target_organization_id
      and membership.user_id = target_user_id
      and membership.status = 'ACTIVE'
      and member_role.revoked_at is null
      and member_role.role_code = any(allowed_roles)
  );
$$;

create or replace function private.has_platform_role(allowed_roles text[], target_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1 from public.platform_user_roles platform_role
    where platform_role.user_id = target_user_id
      and platform_role.revoked_at is null
      and platform_role.role_code = any(allowed_roles)
  );
$$;

revoke all on function private.is_active_org_member(uuid, uuid), private.has_org_role(uuid, text[], uuid), private.has_platform_role(text[], uuid) from public, anon;
grant execute on function private.is_active_org_member(uuid, uuid), private.has_org_role(uuid, text[], uuid), private.has_platform_role(text[], uuid) to authenticated;

alter table public.user_profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.organization_identifiers enable row level security;
alter table public.organization_memberships enable row level security;
alter table public.organization_member_roles enable row level security;
alter table public.platform_user_roles enable row level security;

create policy user_profiles_self_read on public.user_profiles for select to authenticated using (id = auth.uid());
create policy user_profiles_self_update on public.user_profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy organizations_member_read on public.organizations for select to authenticated using (private.is_active_org_member(id));
create policy organization_identifiers_member_read on public.organization_identifiers for select to authenticated using (private.is_active_org_member(organization_id));
create policy memberships_org_read on public.organization_memberships for select to authenticated using (
  user_id = auth.uid()
  or private.has_org_role(organization_id, array['CLIENT_OWNER','CLIENT_ADMIN','PROVIDER_OWNER','PROVIDER_MANAGER','FRANCHISE_OWNER','FRANCHISE_MANAGER'])
  or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR'])
);
create policy member_roles_visible_to_member on public.organization_member_roles for select to authenticated using (
  exists (
    select 1 from public.organization_memberships membership
    where membership.id = membership_id
      and (
        membership.user_id = auth.uid()
        or private.has_org_role(membership.organization_id, array['CLIENT_OWNER','CLIENT_ADMIN','PROVIDER_OWNER','PROVIDER_MANAGER','FRANCHISE_OWNER','FRANCHISE_MANAGER'])
        or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR'])
      )
  )
);

revoke insert, update, delete on public.organizations, public.organization_identifiers, public.organization_memberships, public.organization_member_roles, public.platform_user_roles from anon, authenticated;
grant select on public.organizations, public.organization_identifiers, public.organization_memberships, public.organization_member_roles to authenticated;
grant select, update on public.user_profiles to authenticated;

create trigger user_profiles_set_updated_at before update on public.user_profiles for each row execute function private.set_updated_at();
create trigger organizations_set_updated_at before update on public.organizations for each row execute function private.set_updated_at();
create trigger memberships_set_updated_at before update on public.organization_memberships for each row execute function private.set_updated_at();

create index organization_memberships_user_idx on public.organization_memberships (user_id, organization_id, status);
create index organization_memberships_org_idx on public.organization_memberships (organization_id, status);
create index organization_member_roles_active_idx on public.organization_member_roles (membership_id, role_code) where revoked_at is null;
