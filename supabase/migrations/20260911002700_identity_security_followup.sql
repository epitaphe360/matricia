-- P04 follow-up after final independent audit.

update public.organization_invitations
set invited_user_id = null
where status = 'PENDING' and invited_user_id is not null;

create or replace function private.has_platform_role(
  allowed_roles text[],
  target_user_id uuid default auth.uid()
) returns boolean
language sql
stable
security definer
set search_path = pg_catalog, private
as $$
  select exists (
    select 1
    from public.platform_user_roles platform_role
    left join public.role_security_policy_versions policy
      on policy.role_code = platform_role.role_code
     and policy.status = 'ACTIVE'
     and policy.effective_from <= clock_timestamp()
     and (policy.effective_to is null or policy.effective_to > clock_timestamp())
    where platform_role.user_id = target_user_id
      and platform_role.revoked_at is null
      and platform_role.role_code = any(allowed_roles)
      and (
        target_user_id is distinct from auth.uid()
        or auth.role() <> 'authenticated'
        or (policy.role_code is not null and not policy.mfa_required)
        or auth.jwt() ->> 'aal' = 'aal2'
      )
  );
$$;
revoke all on function private.has_platform_role(text[], uuid)
  from public, anon, authenticated, service_role;
grant execute on function private.has_platform_role(text[], uuid) to authenticated;

notify pgrst, 'reload schema';
