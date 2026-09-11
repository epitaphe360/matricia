-- P04 versioned MFA policy and trusted audit bridge for Supabase Auth changes.

create table public.role_security_policy_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  role_code text not null references public.role_definitions(code),
  version integer not null check (version > 0),
  mfa_required boolean not null,
  password_allowed boolean not null default true,
  status text not null check (status in ('DRAFT', 'ACTIVE', 'RETIRED')),
  effective_from timestamptz not null,
  effective_to timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (role_code, version),
  check (effective_to is null or effective_to > effective_from)
);

create unique index role_security_policy_one_active_uidx
  on public.role_security_policy_versions (role_code)
  where status = 'ACTIVE';

insert into public.role_security_policy_versions (
  role_code, version, mfa_required, password_allowed, status, effective_from
)
select role.code, 1, true, true, 'ACTIVE', '2026-09-11T00:00:00Z'::timestamptz
from public.role_definitions role
where role.scope_type = 'PLATFORM'
on conflict (role_code, version) do nothing;

alter table public.role_security_policy_versions enable row level security;
revoke all on public.role_security_policy_versions from public, anon, authenticated, service_role;
grant select on public.role_security_policy_versions to authenticated;
create policy role_security_policy_authenticated_read
on public.role_security_policy_versions
for select to authenticated
using (status = 'ACTIVE');

create or replace function public.get_my_account_security_requirement()
returns table (
  mfa_required boolean,
  current_aal text,
  requirement_satisfied boolean,
  matched_role_codes text[]
)
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
  v_aal text := coalesce(auth.jwt() ->> 'aal', 'aal1');
  v_roles text[];
  v_required boolean;
begin
  if v_actor is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;
  select coalesce(array_agg(platform_role.role_code order by platform_role.role_code), '{}'::text[]),
         coalesce(bool_or(policy.mfa_required), false)
    into v_roles, v_required
  from public.platform_user_roles platform_role
  join public.role_security_policy_versions policy
    on policy.role_code = platform_role.role_code
   and policy.status = 'ACTIVE'
   and policy.effective_from <= clock_timestamp()
   and (policy.effective_to is null or policy.effective_to > clock_timestamp())
  where platform_role.user_id = v_actor
    and platform_role.revoked_at is null;

  return query select v_required, v_aal, (not v_required or v_aal = 'aal2'), v_roles;
end;
$$;

create or replace function public.record_account_security_event(
  p_actor_user_id uuid,
  p_action text,
  p_resource_id text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_event_type text;
begin
  if auth.role() <> 'service_role' then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if not exists (select 1 from auth.users auth_user where auth_user.id = p_actor_user_id) then
    raise exception 'UNKNOWN_USER' using errcode = '22023';
  end if;
  v_event_type := case p_action
    when 'identity.password.updated' then 'UserPasswordUpdatedV1'
    when 'identity.mfa.enrolled' then 'UserMfaEnrolledV1'
    when 'identity.mfa.unenrolled' then 'UserMfaUnenrolledV1'
    else null
  end;
  if v_event_type is null
     or p_resource_id is null
     or length(p_resource_id) not between 1 and 160 then
    raise exception 'INVALID_SECURITY_EVENT' using errcode = '22023';
  end if;

  insert into public.audit_events (
    actor_user_id, actor_type, action, resource_type, resource_id,
    correlation_id, metadata, previous_hash, event_hash
  ) values (
    p_actor_user_id, 'USER', p_action, 'account_security', p_resource_id,
    p_correlation_id, jsonb_build_object('recorded_by', 'AUTH_SERVICE'),
    null, repeat('0', 64)
  );
  insert into public.event_outbox (
    aggregate_type, aggregate_id, event_type, correlation_id, payload
  ) values (
    'user_account', p_actor_user_id::text, v_event_type, p_correlation_id,
    jsonb_build_object('user_id', p_actor_user_id, 'resource_id', p_resource_id)
  );
end;
$$;

revoke all on function public.get_my_account_security_requirement()
  from public, anon, authenticated, service_role;
grant execute on function public.get_my_account_security_requirement()
  to authenticated;

revoke all on function public.record_account_security_event(uuid, text, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.record_account_security_event(uuid, text, text, uuid)
  to service_role;

notify pgrst, 'reload schema';
