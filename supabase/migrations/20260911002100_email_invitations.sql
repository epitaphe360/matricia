-- P04 email invitations: support people who do not have an auth account yet,
-- without exposing account existence or weakening tenant authorization.

alter table public.organization_invitations
  add column invited_email text;

update public.organization_invitations invitation
set invited_email = lower(btrim(auth_user.email))
from auth.users auth_user
where auth_user.id = invitation.invited_user_id;

alter table public.organization_invitations
  alter column invited_user_id drop not null,
  alter column invited_email set not null,
  add constraint organization_invitations_email_normalized_check
    check (
      invited_email = lower(btrim(invited_email))
      and length(invited_email) between 3 and 320
      and invited_email ~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
    );

create unique index organization_invitations_pending_email_uidx
  on public.organization_invitations (organization_id, invited_email)
  where status = 'PENDING';

create or replace function public.invite_organization_member_by_email(
  p_organization_id uuid,
  p_invited_email text,
  p_role_codes text[],
  p_expires_at timestamptz,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_actor_email text := lower(auth.jwt() ->> 'email');
  v_email text := lower(btrim(p_invited_email));
  v_invited_user_id uuid;
  v_invitation uuid;
  v_is_platform_admin boolean;
  v_request_hash text;
  v_existing private.identity_idempotency_keys%rowtype;
  v_response jsonb;
begin
  if v_actor is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;
  if p_organization_id is null
     or v_email is null
     or length(v_email) not between 3 and 320
     or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
     or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'INVALID_INVITATION' using errcode = '22023';
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
  if v_email = v_actor_email then
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

  v_request_hash := private.canonical_request_hash(jsonb_build_object(
    'operation', 'identity.email.invitation.v1',
    'organization_id', p_organization_id,
    'invited_email', v_email,
    'role_codes', (select jsonb_agg(role_code order by role_code) from unnest(p_role_codes) role_code),
    'expires_at', p_expires_at
  ));

  perform pg_advisory_xact_lock(
    hashtextextended(v_actor::text || ':identity.email.invitation:' || p_idempotency_key, 0)
  );
  select * into v_existing
  from private.identity_idempotency_keys
  where actor_user_id = v_actor
    and operation_scope = 'identity.email.invitation'
    and key = p_idempotency_key;
  if found then
    if v_existing.request_hash <> v_request_hash then
      raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode = '22000';
    end if;
    return v_existing.response_body;
  end if;

  select auth_user.id into v_invited_user_id
  from auth.users auth_user
  where lower(auth_user.email) = v_email;

  insert into public.organization_invitations (
    organization_id, invited_user_id, invited_email, invited_by, expires_at
  ) values (
    p_organization_id, v_invited_user_id, v_email, v_actor, p_expires_at
  ) returning id into v_invitation;

  insert into public.organization_invitation_roles (invitation_id, role_code)
  select v_invitation, requested.role_code
  from unnest(p_role_codes) requested(role_code)
  on conflict do nothing;

  v_response := jsonb_build_object(
    'outcome', 'INVITATION_CREATED',
    'invitation_id', v_invitation,
    'organization_id', p_organization_id
  );

  insert into public.audit_events (
    organization_id, actor_user_id, actor_type, action, resource_type,
    resource_id, correlation_id, metadata, previous_hash, event_hash
  ) values (
    p_organization_id, v_actor, 'USER', 'organization.invitation.created',
    'organization_invitation', v_invitation::text, p_correlation_id,
    jsonb_build_object('role_count', cardinality(p_role_codes), 'channel', 'EMAIL'),
    null, repeat('0', 64)
  );
  insert into public.event_outbox (
    organization_id, aggregate_type, aggregate_id, event_type,
    correlation_id, payload
  ) values (
    p_organization_id, 'organization_invitation', v_invitation::text,
    'OrganizationEmailInvitationRequestedV1', p_correlation_id,
    jsonb_build_object('invitation_id', v_invitation, 'organization_id', p_organization_id)
  );

  insert into private.identity_idempotency_keys (
    actor_user_id, operation_scope, key, request_hash, response_body, expires_at
  ) values (
    v_actor, 'identity.email.invitation', p_idempotency_key, v_request_hash,
    v_response, clock_timestamp() + interval '7 days'
  );
  return v_response;
end;
$$;

create or replace function public.invite_organization_member(
  p_organization_id uuid,
  p_invited_user_id uuid,
  p_role_codes text[],
  p_expires_at timestamptz,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, extensions
as $$
declare
  v_email text;
  v_response jsonb;
begin
  select lower(auth_user.email) into v_email
  from auth.users auth_user
  where auth_user.id = p_invited_user_id;
  if v_email is null then
    raise exception 'INVALID_INVITATION' using errcode = '22023';
  end if;
  v_response := public.invite_organization_member_by_email(
    p_organization_id,
    v_email,
    p_role_codes,
    p_expires_at,
    'legacy-' || extensions.gen_random_uuid()::text,
    p_correlation_id
  );
  return (v_response ->> 'invitation_id')::uuid;
end;
$$;

create or replace function public.accept_organization_invitation(
  p_invitation_id uuid,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_actor_email text := lower(auth.jwt() ->> 'email');
  v_invitation public.organization_invitations%rowtype;
  v_membership uuid;
begin
  if v_actor is null or v_actor_email is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;
  select * into v_invitation
  from public.organization_invitations
  where id = p_invitation_id
    and (invited_user_id = v_actor or invited_email = v_actor_email)
  for update;
  if not found then
    raise exception 'INVITATION_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_invitation.status <> 'PENDING' or v_invitation.expires_at <= clock_timestamp() then
    raise exception 'INVITATION_NOT_ACTIVE' using errcode = '55000';
  end if;

  insert into public.organization_memberships (
    organization_id, user_id, status, invited_by, activated_at
  ) values (
    v_invitation.organization_id, v_actor, 'ACTIVE',
    v_invitation.invited_by, clock_timestamp()
  ) on conflict (organization_id, user_id) do update
    set status = 'ACTIVE',
        invited_by = v_invitation.invited_by,
        activated_at = clock_timestamp()
  returning id into v_membership;

  insert into public.organization_member_roles (
    membership_id, role_code, granted_by, revoked_at
  )
  select v_membership, role_code, v_invitation.invited_by, null
  from public.organization_invitation_roles
  where invitation_id = p_invitation_id
  on conflict (membership_id, role_code) do update
    set granted_by = excluded.granted_by,
        granted_at = clock_timestamp(),
        revoked_at = null;

  update public.organization_invitations
  set status = 'ACCEPTED',
      invited_user_id = v_actor,
      accepted_at = clock_timestamp(),
      row_version = row_version + 1
  where id = p_invitation_id;

  insert into public.audit_events (
    organization_id, actor_user_id, actor_type, action, resource_type,
    resource_id, correlation_id, metadata, previous_hash, event_hash
  ) values (
    v_invitation.organization_id, v_actor, 'USER', 'organization.invitation.accepted',
    'organization_invitation', p_invitation_id::text, p_correlation_id,
    '{}'::jsonb, null, repeat('0', 64)
  );
  insert into public.event_outbox (
    organization_id, aggregate_type, aggregate_id, event_type,
    correlation_id, payload
  ) values (
    v_invitation.organization_id, 'organization_membership', v_membership::text,
    'OrganizationInvitationAcceptedV1', p_correlation_id,
    jsonb_build_object('membership_id', v_membership, 'invitation_id', p_invitation_id)
  );
  return v_membership;
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
  v_actor_email text := lower(auth.jwt() ->> 'email');
  v_invitation public.organization_invitations%rowtype;
begin
  if v_actor is null or v_actor_email is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;
  select * into v_invitation
  from public.organization_invitations
  where id = p_invitation_id
    and (invited_user_id = v_actor or invited_email = v_actor_email)
  for update;
  if not found then
    raise exception 'INVITATION_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_invitation.status = 'DECLINED' then
    return false;
  end if;
  if v_invitation.status <> 'PENDING' then
    raise exception 'INVITATION_NOT_ACTIVE' using errcode = '55000';
  end if;

  update public.organization_invitations
  set status = 'DECLINED',
      invited_user_id = coalesce(invited_user_id, v_actor),
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

drop policy invitations_visible on public.organization_invitations;
create policy invitations_visible
on public.organization_invitations
for select to authenticated
using (
  invited_user_id = auth.uid()
  or invited_email = lower(auth.jwt() ->> 'email')
  or private.has_org_role(
    organization_id,
    array[
      'CLIENT_OWNER', 'CLIENT_ADMIN', 'PROVIDER_OWNER', 'PROVIDER_MANAGER',
      'FRANCHISE_OWNER', 'FRANCHISE_MANAGER'
    ]
  )
  or private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'READ_ONLY_AUDITOR'])
);

drop policy invitation_roles_visible on public.organization_invitation_roles;
create policy invitation_roles_visible
on public.organization_invitation_roles
for select to authenticated
using (
  exists (
    select 1
    from public.organization_invitations invitation
    where invitation.id = invitation_id
      and (
        invitation.invited_user_id = auth.uid()
        or invitation.invited_email = lower(auth.jwt() ->> 'email')
        or private.has_org_role(
          invitation.organization_id,
          array[
            'CLIENT_OWNER', 'CLIENT_ADMIN', 'PROVIDER_OWNER', 'PROVIDER_MANAGER',
            'FRANCHISE_OWNER', 'FRANCHISE_MANAGER'
          ]
        )
        or private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'READ_ONLY_AUDITOR'])
      )
  )
);

revoke all on function public.invite_organization_member_by_email(uuid, text, text[], timestamptz, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.invite_organization_member_by_email(uuid, text, text[], timestamptz, text, uuid)
  to authenticated;

revoke all on function public.invite_organization_member(uuid, uuid, text[], timestamptz, uuid),
  public.accept_organization_invitation(uuid, uuid),
  public.decline_organization_invitation(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.invite_organization_member(uuid, uuid, text[], timestamptz, uuid),
  public.accept_organization_invitation(uuid, uuid),
  public.decline_organization_invitation(uuid, uuid)
  to authenticated;

notify pgrst, 'reload schema';
