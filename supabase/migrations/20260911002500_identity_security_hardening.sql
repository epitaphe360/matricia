-- P04 security hardening after independent red-team review.

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
        or not coalesce(policy.mfa_required, false)
        or auth.jwt() ->> 'aal' = 'aal2'
      )
  );
$$;

revoke all on function private.has_platform_role(text[], uuid)
  from public, anon, authenticated, service_role;
grant execute on function private.has_platform_role(text[], uuid)
  to authenticated;

drop function public.get_my_account_security_requirement();
create function public.get_my_account_security_requirement()
returns table (
  mfa_required boolean,
  password_allowed boolean,
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
  v_mfa_required boolean;
  v_password_allowed boolean;
begin
  if v_actor is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;
  select coalesce(array_agg(platform_role.role_code order by platform_role.role_code), '{}'::text[]),
         coalesce(bool_or(policy.mfa_required), false),
         coalesce(bool_and(policy.password_allowed), true)
    into v_roles, v_mfa_required, v_password_allowed
  from public.platform_user_roles platform_role
  join public.role_security_policy_versions policy
    on policy.role_code = platform_role.role_code
   and policy.status = 'ACTIVE'
   and policy.effective_from <= clock_timestamp()
   and (policy.effective_to is null or policy.effective_to > clock_timestamp())
  where platform_role.user_id = v_actor
    and platform_role.revoked_at is null;
  return query select v_mfa_required, v_password_allowed, v_aal,
    (not v_mfa_required or v_aal = 'aal2'), v_roles;
end;
$$;
revoke all on function public.get_my_account_security_requirement()
  from public, anon, authenticated, service_role;
grant execute on function public.get_my_account_security_requirement()
  to authenticated;

create table private.invitation_rate_limit_buckets (
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  window_started_at timestamptz not null,
  request_count integer not null check (request_count between 1 and 20),
  primary key (actor_user_id, organization_id)
);
revoke all on private.invitation_rate_limit_buckets
  from public, anon, authenticated, service_role;

create or replace function private.enforce_organization_invitation_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_bucket private.invitation_rate_limit_buckets%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  perform pg_advisory_xact_lock(hashtextextended(
    'invitation-rate:' || new.invited_by::text || ':' || new.organization_id::text, 0
  ));
  select * into v_bucket
  from private.invitation_rate_limit_buckets
  where actor_user_id = new.invited_by and organization_id = new.organization_id
  for update;
  if not found then
    insert into private.invitation_rate_limit_buckets (
      actor_user_id, organization_id, window_started_at, request_count
    ) values (new.invited_by, new.organization_id, v_now, 1);
    return new;
  end if;
  if v_now - v_bucket.window_started_at >= interval '1 hour' then
    update private.invitation_rate_limit_buckets
    set window_started_at = v_now, request_count = 1
    where actor_user_id = new.invited_by and organization_id = new.organization_id;
    return new;
  end if;
  if v_bucket.request_count >= 20 then
    raise exception 'INVITATION_RATE_LIMITED' using errcode = '54000';
  end if;
  update private.invitation_rate_limit_buckets
  set request_count = request_count + 1
  where actor_user_id = new.invited_by and organization_id = new.organization_id;
  return new;
end;
$$;
revoke all on function private.enforce_organization_invitation_rate_limit()
  from public, anon, authenticated, service_role;

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
  if new.expires_at > clock_timestamp() + interval '30 days' then
    raise exception 'INVITATION_EXPIRY_TOO_LONG' using errcode = '22023';
  end if;
  -- Never expose whether a submitted email already belongs to an auth account.
  -- Recipient identity is bound only after a verified-email acceptance/decline.
  new.invited_user_id := null;
  return new;
end;
$$;

create or replace function private.validate_organization_invitation_transition()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
declare
  v_actor uuid := auth.uid();
  v_verified_email text;
  v_inviter_authorized boolean;
  v_inviter_platform_admin boolean;
begin
  if new.status = old.status or new.status not in ('ACCEPTED', 'DECLINED') then
    return new;
  end if;
  select lower(auth_user.email)
    into v_verified_email
  from auth.users auth_user
  where auth_user.id = v_actor
    and auth_user.email_confirmed_at is not null;
  if v_actor is null
     or new.invited_user_id is distinct from v_actor
     or v_verified_email is null
     or v_verified_email <> old.invited_email then
    raise exception 'INVITATION_RECIPIENT_MISMATCH' using errcode = '42501';
  end if;
  if new.status = 'DECLINED' then
    return new;
  end if;

  select exists (
    select 1
    from public.platform_user_roles platform_role
    where platform_role.user_id = old.invited_by
      and platform_role.revoked_at is null
      and platform_role.role_code in ('SUPER_ADMIN', 'MATRICIA_ADMIN')
  ) into v_inviter_platform_admin;
  v_inviter_authorized := v_inviter_platform_admin or private.has_org_role(
    old.organization_id,
    array[
      'CLIENT_OWNER', 'CLIENT_ADMIN', 'PROVIDER_OWNER', 'PROVIDER_MANAGER',
      'FRANCHISE_OWNER', 'FRANCHISE_MANAGER'
    ],
    old.invited_by
  );
  if not v_inviter_authorized then
    raise exception 'INVITATION_AUTHORITY_REVOKED' using errcode = '42501';
  end if;
  if exists (
    select 1
    from public.organization_invitation_roles invitation_role
    join public.role_definitions definition on definition.code = invitation_role.role_code
    where invitation_role.invitation_id = old.id
      and (definition.scope_type = 'PLATFORM' or definition.scope_type not in ('ORGANIZATION', 'FRANCHISE'))
  ) then
    raise exception 'INVITATION_ROLE_FORBIDDEN' using errcode = '42501';
  end if;
  if not v_inviter_platform_admin and exists (
    select 1
    from public.organization_invitation_roles requested
    where requested.invitation_id = old.id
      and right(requested.role_code, 6) = '_OWNER'
      and not exists (
        select 1
        from public.organization_memberships membership
        join public.organization_member_roles member_role
          on member_role.membership_id = membership.id
        where membership.organization_id = old.organization_id
          and membership.user_id = old.invited_by
          and membership.status = 'ACTIVE'
          and member_role.revoked_at is null
          and split_part(member_role.role_code, '_', 1)
            = split_part(requested.role_code, '_', 1)
      )
  ) then
    raise exception 'INVITATION_ROLE_AUTHORITY_REVOKED' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function private.validate_organization_invitation_transition()
  from public, anon, authenticated, service_role;

create trigger organization_invitations_validate_transition
before update of status, invited_user_id
on public.organization_invitations
for each row execute function private.validate_organization_invitation_transition();

create trigger organization_invitations_rate_limit
before insert
on public.organization_invitations
for each row execute function private.enforce_organization_invitation_rate_limit();

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
    when 'identity.password.change.requested' then 'UserPasswordChangeRequestedV1'
    when 'identity.password.updated' then 'UserPasswordUpdatedV1'
    when 'identity.mfa.enrollment.requested' then 'UserMfaEnrollmentRequestedV1'
    when 'identity.mfa.verification.requested' then 'UserMfaVerificationRequestedV1'
    when 'identity.mfa.enrolled' then 'UserMfaEnrolledV1'
    when 'identity.mfa.unenrollment.requested' then 'UserMfaUnenrollmentRequestedV1'
    when 'identity.mfa.unenrolled' then 'UserMfaUnenrolledV1'
    else null
  end;
  if v_event_type is null or p_resource_id is null or length(p_resource_id) not between 1 and 160 then
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
revoke all on function public.record_account_security_event(uuid, text, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.record_account_security_event(uuid, text, text, uuid)
  to service_role;

-- The UUID-based invitation endpoint leaks user existence through different
-- outcomes and is superseded by the neutral email workflow.
revoke all on function public.invite_organization_member(uuid, uuid, text[], timestamptz, uuid)
  from public, anon, authenticated, service_role;

notify pgrst, 'reload schema';
