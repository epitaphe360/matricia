-- Defense in depth: self-invitation is forbidden independently of JWT email claims.

create or replace function private.prevent_self_organization_invitation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if auth.uid() is not null and new.invited_user_id = auth.uid() then
    raise exception 'SELF_INVITATION_FORBIDDEN' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function private.prevent_self_organization_invitation()
  from public, anon, authenticated, service_role;

create trigger organization_invitations_prevent_self
before insert
on public.organization_invitations
for each row execute function private.prevent_self_organization_invitation();
