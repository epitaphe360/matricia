-- P04 role accumulation: explicit requests, central approval for cross-domain owners,
-- and no route from an organization role to a platform privilege.

alter table public.organization_access_requests
  add column requires_central_approval boolean not null default false;

alter table public.organization_access_requests
  add constraint organization_access_requests_no_self_decision
  check (decided_by is null or decided_by <> requester_user_id) not valid;

create or replace function private.enforce_organization_access_request_scope()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_scope text;
begin
  select role.scope_type
    into v_scope
  from public.role_definitions role
  where role.code = new.requested_role_code;

  if v_scope is null then
    raise exception 'UNKNOWN_ROLE' using errcode = '22023';
  end if;
  if v_scope = 'PLATFORM' then
    raise exception 'PLATFORM_ROLE_FORBIDDEN' using errcode = '42501';
  end if;
  if v_scope not in ('ORGANIZATION', 'FRANCHISE') then
    raise exception 'INVALID_ROLE_SCOPE' using errcode = '22023';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_organization_access_request_scope()
  from public, anon, authenticated, service_role;

create trigger organization_access_requests_scope_guard
before insert or update of requested_role_code
on public.organization_access_requests
for each row execute function private.enforce_organization_access_request_scope();

create or replace function public.request_additional_organization_role(
  p_organization_id uuid,
  p_requested_role_code text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_membership_id uuid;
  v_role_scope text;
  v_role_domain text;
  v_requires_central boolean := false;
  v_request_hash text;
  v_existing private.identity_idempotency_keys%rowtype;
  v_request_id uuid;
  v_created boolean := false;
  v_response jsonb;
begin
  if v_actor is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;
  if p_organization_id is null
     or p_requested_role_code is null
     or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'INVALID_REQUEST' using errcode = '22023';
  end if;

  select role.scope_type, split_part(role.code, '_', 1)
    into v_role_scope, v_role_domain
  from public.role_definitions role
  where role.code = p_requested_role_code;

  if v_role_scope is null then
    raise exception 'UNKNOWN_ROLE' using errcode = '22023';
  end if;
  if v_role_scope = 'PLATFORM' then
    raise exception 'PLATFORM_ROLE_FORBIDDEN' using errcode = '42501';
  end if;
  if v_role_scope not in ('ORGANIZATION', 'FRANCHISE')
     or v_role_domain not in ('CLIENT', 'PROVIDER', 'FRANCHISE') then
    raise exception 'INVALID_ROLE_SCOPE' using errcode = '22023';
  end if;

  select membership.id
    into v_membership_id
  from public.organization_memberships membership
  where membership.organization_id = p_organization_id
    and membership.user_id = v_actor
    and membership.status = 'ACTIVE'
  for update;

  if v_membership_id is null then
    raise exception 'ACTIVE_MEMBERSHIP_REQUIRED' using errcode = '42501';
  end if;

  if exists (
    select 1
    from public.organization_member_roles member_role
    where member_role.membership_id = v_membership_id
      and member_role.role_code = p_requested_role_code
      and member_role.revoked_at is null
  ) then
    raise exception 'ROLE_ALREADY_GRANTED' using errcode = '23505';
  end if;

  v_requires_central := right(p_requested_role_code, 6) = '_OWNER'
    and exists (
      select 1
      from public.organization_member_roles member_role
      where member_role.membership_id = v_membership_id
        and member_role.revoked_at is null
        and split_part(member_role.role_code, '_', 1) in ('CLIENT', 'PROVIDER', 'FRANCHISE')
        and split_part(member_role.role_code, '_', 1) <> v_role_domain
    );

  v_request_hash := private.canonical_request_hash(jsonb_build_object(
    'operation', 'identity.role.request.v1',
    'organization_id', p_organization_id,
    'requested_role_code', p_requested_role_code
  ));

  -- Serialize the actor/key pair so concurrent retries cannot race the private
  -- idempotency record or emit duplicate durable events.
  perform pg_advisory_xact_lock(
    hashtextextended(v_actor::text || ':identity.role.request:' || p_idempotency_key, 0)
  );

  select *
    into v_existing
  from private.identity_idempotency_keys
  where actor_user_id = v_actor
    and operation_scope = 'identity.role.request'
    and key = p_idempotency_key;

  if found then
    if v_existing.request_hash <> v_request_hash then
      raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode = '22000';
    end if;
    return v_existing.response_body;
  end if;

  insert into public.organization_access_requests (
    organization_id,
    requester_user_id,
    requested_role_code,
    requires_central_approval
  ) values (
    p_organization_id,
    v_actor,
    p_requested_role_code,
    v_requires_central
  )
  on conflict (organization_id, requester_user_id, requested_role_code)
    where status = 'PENDING'
  do nothing
  returning id into v_request_id;

  if v_request_id is not null then
    v_created := true;
  else
    select request.id
      into v_request_id
    from public.organization_access_requests request
    where request.organization_id = p_organization_id
      and request.requester_user_id = v_actor
      and request.requested_role_code = p_requested_role_code
      and request.status = 'PENDING'
    for update;
  end if;

  if v_request_id is null then
    raise exception 'ROLE_REQUEST_CONFLICT' using errcode = '40001';
  end if;

  v_response := jsonb_build_object(
    'outcome', case when v_created then 'ROLE_REQUESTED' else 'ROLE_REQUEST_ALREADY_PENDING' end,
    'request_id', v_request_id,
    'organization_id', p_organization_id,
    'requested_role_code', p_requested_role_code,
    'requires_central_approval', v_requires_central
  );

  if v_created then
    insert into public.audit_events (
      organization_id, actor_user_id, actor_type, action, resource_type,
      resource_id, correlation_id, metadata, previous_hash, event_hash
    ) values (
      p_organization_id, v_actor, 'USER', 'organization.role.requested',
      'organization_access_request', v_request_id::text, p_correlation_id,
      jsonb_build_object(
        'requested_role', p_requested_role_code,
        'requires_central_approval', v_requires_central
      ), null, repeat('0', 64)
    );

    insert into public.event_outbox (
      organization_id, aggregate_type, aggregate_id, event_type,
      correlation_id, payload
    ) values (
      p_organization_id, 'organization_access_request', v_request_id::text,
      'OrganizationRoleRequestedV1', p_correlation_id,
      jsonb_build_object(
        'request_id', v_request_id,
        'organization_id', p_organization_id,
        'requested_role_code', p_requested_role_code,
        'requires_central_approval', v_requires_central
      )
    );
  end if;

  insert into private.identity_idempotency_keys (
    actor_user_id, operation_scope, key, request_hash, response_body, expires_at
  ) values (
    v_actor, 'identity.role.request', p_idempotency_key, v_request_hash,
    v_response, clock_timestamp() + interval '7 days'
  );

  return v_response;
end;
$$;

create or replace function public.decide_organization_access_request(
  p_request_id uuid,
  p_approve boolean,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns void
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_request public.organization_access_requests%rowtype;
  v_membership uuid;
  v_role_scope text;
  v_requested_domain text;
  v_requires_central boolean;
  v_is_central_approver boolean;
  v_is_org_approver boolean;
begin
  if v_actor is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;

  select *
    into v_request
  from public.organization_access_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'REQUEST_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_request.requester_user_id = v_actor then
    raise exception 'SELF_APPROVAL_FORBIDDEN' using errcode = '42501';
  end if;
  if v_request.status <> 'PENDING' then
    raise exception 'REQUEST_NOT_PENDING' using errcode = '55000';
  end if;

  select role.scope_type, split_part(role.code, '_', 1)
    into v_role_scope, v_requested_domain
  from public.role_definitions role
  where role.code = v_request.requested_role_code;

  if v_role_scope is null then
    raise exception 'UNKNOWN_ROLE' using errcode = '22023';
  end if;
  if v_role_scope = 'PLATFORM' then
    raise exception 'PLATFORM_ROLE_FORBIDDEN' using errcode = '42501';
  end if;
  if v_role_scope not in ('ORGANIZATION', 'FRANCHISE') then
    raise exception 'INVALID_ROLE_SCOPE' using errcode = '22023';
  end if;

  -- Recompute the rule at decision time as defense in depth for legacy requests
  -- and for role changes that happened while this request was pending.
  v_requires_central := v_request.requires_central_approval
    or (
      right(v_request.requested_role_code, 6) = '_OWNER'
      and exists (
        select 1
        from public.organization_memberships membership
        join public.organization_member_roles member_role
          on member_role.membership_id = membership.id
        where membership.organization_id = v_request.organization_id
          and membership.user_id = v_request.requester_user_id
          and membership.status = 'ACTIVE'
          and member_role.revoked_at is null
          and split_part(member_role.role_code, '_', 1) in ('CLIENT', 'PROVIDER', 'FRANCHISE')
          and split_part(member_role.role_code, '_', 1) <> v_requested_domain
      )
    );

  v_is_central_approver := private.has_platform_role(
    array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'COMPLIANCE_MANAGER'], v_actor
  );
  v_is_org_approver := private.has_org_role(
    v_request.organization_id,
    array[
      'CLIENT_OWNER', 'CLIENT_ADMIN', 'PROVIDER_OWNER', 'PROVIDER_MANAGER',
      'FRANCHISE_OWNER', 'FRANCHISE_MANAGER'
    ],
    v_actor
  );

  -- Return a neutral error to arbitrary UUID probes from another tenant before
  -- revealing whether a request requires a central compliance decision.
  if not v_is_central_approver and not v_is_org_approver then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if v_requires_central and not v_is_central_approver then
    raise exception 'CENTRAL_COMPLIANCE_APPROVAL_REQUIRED' using errcode = '42501';
  end if;

  update public.organization_access_requests
  set status = case when p_approve then 'APPROVED' else 'REJECTED' end,
      decided_by = v_actor,
      decided_at = clock_timestamp(),
      requires_central_approval = v_requires_central
  where id = p_request_id;

  if p_approve then
    insert into public.organization_memberships (
      organization_id, user_id, status, invited_by, activated_at
    ) values (
      v_request.organization_id, v_request.requester_user_id, 'ACTIVE',
      v_actor, clock_timestamp()
    )
    on conflict (organization_id, user_id) do update
    set status = 'ACTIVE',
        invited_by = v_actor,
        activated_at = clock_timestamp()
    returning id into v_membership;

    insert into public.organization_member_roles (
      membership_id, role_code, granted_by, revoked_at
    ) values (
      v_membership, v_request.requested_role_code, v_actor, null
    )
    on conflict (membership_id, role_code) do update
    set granted_by = v_actor,
        granted_at = clock_timestamp(),
        revoked_at = null;
  end if;

  insert into public.audit_events (
    organization_id, actor_user_id, actor_type, action, resource_type,
    resource_id, correlation_id, metadata, previous_hash, event_hash
  ) values (
    v_request.organization_id, v_actor, 'USER', 'organization.access.decided',
    'organization_access_request', p_request_id::text, p_correlation_id,
    jsonb_build_object(
      'approved', p_approve,
      'requested_role', v_request.requested_role_code,
      'requires_central_approval', v_requires_central
    ), null, repeat('0', 64)
  );

  insert into public.event_outbox (
    organization_id, aggregate_type, aggregate_id, event_type,
    correlation_id, payload
  ) values (
    v_request.organization_id, 'organization_access_request', p_request_id::text,
    'OrganizationAccessDecidedV1', p_correlation_id,
    jsonb_build_object(
      'request_id', p_request_id,
      'approved', p_approve,
      'requested_role_code', v_request.requested_role_code,
      'requires_central_approval', v_requires_central
    )
  );
end;
$$;

revoke all on function public.request_additional_organization_role(uuid, text, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.request_additional_organization_role(uuid, text, text, uuid)
  to authenticated;

revoke all on function public.decide_organization_access_request(uuid, boolean, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.decide_organization_access_request(uuid, boolean, uuid)
  to authenticated;

create index organization_access_requests_central_queue_idx
  on public.organization_access_requests (status, created_at, id)
  where status = 'PENDING' and requires_central_approval;

notify pgrst, 'reload schema';
