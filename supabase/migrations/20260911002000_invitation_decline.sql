-- P04 invitation refusal: invitees can explicitly decline without creating a membership.

alter table public.organization_invitations
  drop constraint organization_invitations_status_check;

alter table public.organization_invitations
  add constraint organization_invitations_status_check
  check (status in ('PENDING', 'ACCEPTED', 'DECLINED', 'REVOKED', 'EXPIRED'));

create or replace function public.invite_organization_member(
  p_organization_id uuid,
  p_invited_user_id uuid,
  p_role_codes text[],
  p_expires_at timestamptz,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_invitation uuid;
  v_is_platform_admin boolean;
begin
  if v_actor is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;
  v_is_platform_admin := private.has_platform_role(
    array['SUPER_ADMIN', 'MATRICIA_ADMIN'], v_actor
  );
  if not private.has_org_role(
    p_organization_id,
    array[
      'CLIENT_OWNER', 'CLIENT_ADMIN', 'PROVIDER_OWNER', 'PROVIDER_MANAGER',
      'FRANCHISE_OWNER', 'FRANCHISE_MANAGER'
    ],
    v_actor
  ) and not v_is_platform_admin then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if p_invited_user_id = v_actor then
    raise exception 'SELF_INVITATION_FORBIDDEN' using errcode = '42501';
  end if;
  if p_expires_at <= clock_timestamp()
     or coalesce(cardinality(p_role_codes), 0) = 0
     or exists (
       select 1
       from unnest(p_role_codes) requested(role_code)
       left join public.role_definitions definition on definition.code = requested.role_code
       where definition.code is null
          or definition.scope_type = 'PLATFORM'
          or definition.scope_type not in ('ORGANIZATION', 'FRANCHISE')
     ) then
    raise exception 'INVALID_INVITATION' using errcode = '22023';
  end if;

  -- A tenant administrator cannot grant an OWNER role for a different domain.
  -- Cross-domain OWNER accumulation must pass through the centrally approved
  -- organization role-request workflow introduced in migration 019.
  if not v_is_platform_admin and exists (
    select 1
    from unnest(p_role_codes) requested(role_code)
    where right(requested.role_code, 6) = '_OWNER'
      and not exists (
        select 1
        from public.organization_memberships membership
        join public.organization_member_roles member_role
          on member_role.membership_id = membership.id
        where membership.organization_id = p_organization_id
          and membership.user_id = v_actor
          and membership.status = 'ACTIVE'
          and member_role.revoked_at is null
          and split_part(member_role.role_code, '_', 1)
            = split_part(requested.role_code, '_', 1)
      )
  ) then
    raise exception 'CROSS_DOMAIN_OWNER_INVITATION_FORBIDDEN' using errcode = '42501';
  end if;

  insert into public.organization_invitations (
    organization_id, invited_user_id, invited_by, expires_at
  ) values (
    p_organization_id, p_invited_user_id, v_actor, p_expires_at
  ) returning id into v_invitation;

  insert into public.organization_invitation_roles (invitation_id, role_code)
  select v_invitation, requested.role_code
  from unnest(p_role_codes) requested(role_code)
  on conflict do nothing;

  insert into public.audit_events (
    organization_id, actor_user_id, actor_type, action, resource_type,
    resource_id, correlation_id, metadata, previous_hash, event_hash
  ) values (
    p_organization_id, v_actor, 'USER', 'organization.invitation.created',
    'organization_invitation', v_invitation::text, p_correlation_id,
    jsonb_build_object('role_count', cardinality(p_role_codes)),
    null, repeat('0', 64)
  );

  insert into public.event_outbox (
    organization_id, aggregate_type, aggregate_id, event_type,
    correlation_id, payload
  ) values (
    p_organization_id, 'organization_invitation', v_invitation::text,
    'OrganizationInvitationCreatedV1', p_correlation_id,
    jsonb_build_object(
      'invitation_id', v_invitation,
      'invited_user_id', p_invited_user_id
    )
  );
  return v_invitation;
end;
$$;

create or replace function public.decline_organization_invitation(
  p_invitation_id uuid,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns boolean
language plpgsql
security definer
set search_path = pg_catalog, extensions
as $$
declare
  v_actor uuid := auth.uid();
  v_invitation public.organization_invitations%rowtype;
begin
  if v_actor is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;

  select *
    into v_invitation
  from public.organization_invitations
  where id = p_invitation_id
    and invited_user_id = v_actor
  for update;

  if not found then
    raise exception 'INVITATION_NOT_FOUND' using errcode = 'P0002';
  end if;

  -- An exact retry is a no-op and never duplicates audit or Outbox events.
  if v_invitation.status = 'DECLINED' then
    return false;
  end if;
  if v_invitation.status <> 'PENDING' then
    raise exception 'INVITATION_NOT_ACTIVE' using errcode = '55000';
  end if;

  update public.organization_invitations
  set status = 'DECLINED',
      accepted_at = null,
      row_version = row_version + 1
  where id = p_invitation_id;

  insert into public.audit_events (
    organization_id, actor_user_id, actor_type, action, resource_type,
    resource_id, correlation_id, metadata, previous_hash, event_hash
  ) values (
    v_invitation.organization_id, v_actor, 'USER', 'organization.invitation.declined',
    'organization_invitation', p_invitation_id::text, p_correlation_id,
    '{}'::jsonb, null, repeat('0', 64)
  );

  insert into public.event_outbox (
    organization_id, aggregate_type, aggregate_id, event_type,
    correlation_id, payload
  ) values (
    v_invitation.organization_id, 'organization_invitation', p_invitation_id::text,
    'OrganizationInvitationDeclinedV1', p_correlation_id,
    jsonb_build_object(
      'invitation_id', p_invitation_id,
      'organization_id', v_invitation.organization_id,
      'invited_user_id', v_actor
    )
  );

  return true;
end;
$$;

revoke all on function public.decline_organization_invitation(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.decline_organization_invitation(uuid, uuid)
  to authenticated;

revoke all on function public.invite_organization_member(uuid, uuid, text[], timestamptz, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.invite_organization_member(uuid, uuid, text[], timestamptz, uuid)
  to authenticated;

notify pgrst, 'reload schema';
