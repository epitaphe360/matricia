-- P04 identity workflows: additive, tenant-safe and server-authorized.

create table private.otp_rate_limit_buckets (
  bucket_type text not null check (bucket_type in ('IDENTIFIER','IP')),
  bucket_hash text not null check (bucket_hash ~ '^[0-9a-f]{64}$'),
  window_started_at timestamptz not null,
  request_count integer not null check (request_count > 0),
  blocked_until timestamptz,
  primary key (bucket_type,bucket_hash)
);
revoke all on private.otp_rate_limit_buckets from public,anon,authenticated,service_role;

create table private.identity_idempotency_keys (
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  operation_scope text not null check (operation_scope ~ '^[a-z][a-z0-9_.-]{2,99}$'),
  key text not null check (length(key) between 8 and 200),
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  response_body jsonb,
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null,
  primary key (actor_user_id,operation_scope,key),
  check (expires_at > created_at)
);
revoke all on private.identity_idempotency_keys from public,anon,authenticated,service_role;

create table public.organization_access_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  requester_user_id uuid not null references auth.users(id) on delete cascade,
  requested_role_code text not null references public.role_definitions(code),
  status text not null default 'PENDING' check (status in ('PENDING','APPROVED','REJECTED','CANCELLED','EXPIRED')),
  decided_by uuid references auth.users(id),
  decided_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check (row_version > 0),
  check ((status in ('APPROVED','REJECTED'))=(decided_by is not null and decided_at is not null))
);
create unique index organization_access_requests_pending_uidx
  on public.organization_access_requests(organization_id,requester_user_id,requested_role_code)
  where status='PENDING';

create table public.organization_invitations (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  invited_user_id uuid not null references auth.users(id) on delete cascade,
  invited_by uuid not null references auth.users(id),
  status text not null default 'PENDING' check (status in ('PENDING','ACCEPTED','REVOKED','EXPIRED')),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check (row_version > 0),
  check (expires_at > created_at),
  check ((status='ACCEPTED')=(accepted_at is not null))
);
create unique index organization_invitations_pending_uidx
  on public.organization_invitations(organization_id,invited_user_id)
  where status='PENDING';

create table public.organization_invitation_roles (
  invitation_id uuid not null references public.organization_invitations(id) on delete cascade,
  role_code text not null references public.role_definitions(code),
  primary key(invitation_id,role_code)
);

create or replace function private.normalize_ice(p_value text)
returns text language sql immutable strict security invoker set search_path=pg_catalog
as $$ select upper(regexp_replace(trim(p_value),'[^[:alnum:]]','','g')) $$;
revoke all on function private.normalize_ice(text) from public,anon,authenticated,service_role;

create or replace function private.normalize_organization_identifier()
returns trigger language plpgsql security invoker set search_path=pg_catalog,private
as $$
begin
  if new.identifier_type='ICE' then
    new.normalized_value:=private.normalize_ice(new.normalized_value::text);
    if length(new.normalized_value::text) not between 8 and 32 then
      raise exception 'INVALID_ICE' using errcode='22023';
    end if;
  end if;
  return new;
end;
$$;
create trigger organization_identifiers_normalize
before insert or update of identifier_type,normalized_value on public.organization_identifiers
for each row execute function private.normalize_organization_identifier();

update public.organization_identifiers
set normalized_value=private.normalize_ice(normalized_value::text)
where identifier_type='ICE';
create unique index organization_active_ice_uidx
on public.organization_identifiers(normalized_value)
where identifier_type='ICE' and is_active;

create or replace function private.create_user_profile()
returns trigger language plpgsql security definer set search_path=pg_catalog
as $$
declare v_display_name text;
begin
  v_display_name:=left(trim(coalesce(new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'name','')),120);
  if length(v_display_name)<2 then v_display_name:='Utilisateur'; end if;
  insert into public.user_profiles(id,display_name,preferred_locale)
  values(new.id,v_display_name,case when new.raw_user_meta_data->>'preferred_locale'='ar-MA' then 'ar-MA' else 'fr-MA' end)
  on conflict(id) do nothing;
  return new;
end;
$$;
revoke all on function private.create_user_profile() from public,anon,authenticated,service_role;
create trigger auth_user_create_profile after insert on auth.users
for each row execute function private.create_user_profile();

insert into public.user_profiles(id,display_name,preferred_locale)
select u.id,
  case when length(left(trim(coalesce(u.raw_user_meta_data->>'full_name',u.raw_user_meta_data->>'name','')),120))>=2
       then left(trim(coalesce(u.raw_user_meta_data->>'full_name',u.raw_user_meta_data->>'name','')),120)
       else 'Utilisateur' end,
  case when u.raw_user_meta_data->>'preferred_locale'='ar-MA' then 'ar-MA' else 'fr-MA' end
from auth.users u
left join public.user_profiles p on p.id=u.id
where p.id is null;

create or replace function public.reserve_otp_request(p_identifier text,p_client_ip inet default null)
returns table(allowed boolean,retry_after_seconds integer)
language plpgsql security definer set search_path=pg_catalog,extensions,private
as $$
declare
  v_now timestamptz:=clock_timestamp();
  v_identifier_hash text;
  v_ip_hash text;
  v_identifier private.otp_rate_limit_buckets%rowtype;
  v_ip private.otp_rate_limit_buckets%rowtype;
  v_retry integer:=0;
  v_correlation uuid:=extensions.gen_random_uuid();
begin
  if auth.role()<>'service_role' then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  if p_identifier is null or length(trim(p_identifier)) not between 3 and 320 then
    raise exception 'INVALID_IDENTIFIER' using errcode='22023';
  end if;
  v_identifier_hash:=encode(extensions.digest(convert_to(lower(trim(p_identifier)),'UTF8'),'sha256'),'hex');
  v_ip_hash:=encode(extensions.digest(convert_to(coalesce(host(p_client_ip),'unknown'),'UTF8'),'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended('otp.identifier.'||v_identifier_hash,0));
  perform pg_advisory_xact_lock(hashtextextended('otp.ip.'||v_ip_hash,0));

  insert into private.otp_rate_limit_buckets(bucket_type,bucket_hash,window_started_at,request_count)
  values('IDENTIFIER',v_identifier_hash,v_now,1),('IP',v_ip_hash,v_now,1)
  on conflict(bucket_type,bucket_hash) do update set
    window_started_at=case when excluded.window_started_at-private.otp_rate_limit_buckets.window_started_at>=interval '15 minutes' then excluded.window_started_at else private.otp_rate_limit_buckets.window_started_at end,
    request_count=case when excluded.window_started_at-private.otp_rate_limit_buckets.window_started_at>=interval '15 minutes' then 1 else private.otp_rate_limit_buckets.request_count+1 end,
    blocked_until=case
      when private.otp_rate_limit_buckets.blocked_until>excluded.window_started_at then private.otp_rate_limit_buckets.blocked_until
      when private.otp_rate_limit_buckets.bucket_type='IDENTIFIER' and private.otp_rate_limit_buckets.request_count+1>5 then excluded.window_started_at+interval '15 minutes'
      when private.otp_rate_limit_buckets.bucket_type='IP' and private.otp_rate_limit_buckets.request_count+1>20 then excluded.window_started_at+interval '15 minutes'
      else null end;
  select * into v_identifier from private.otp_rate_limit_buckets where bucket_type='IDENTIFIER' and bucket_hash=v_identifier_hash;
  select * into v_ip from private.otp_rate_limit_buckets where bucket_type='IP' and bucket_hash=v_ip_hash;
  v_retry:=greatest(
    case when v_identifier.blocked_until>v_now then ceil(extract(epoch from v_identifier.blocked_until-v_now))::integer else 0 end,
    case when v_ip.blocked_until>v_now then ceil(extract(epoch from v_ip.blocked_until-v_now))::integer else 0 end
  );
  insert into public.audit_events(actor_type,action,resource_type,resource_id,correlation_id,request_ip,metadata,previous_hash,event_hash)
  values('SERVICE','identity.otp.reserved','otp_rate_limit',v_identifier_hash,v_correlation,p_client_ip,
    jsonb_build_object('allowed',v_retry=0),null,repeat('0',64));
  return query select v_retry=0,v_retry;
end;
$$;
revoke all on function public.reserve_otp_request(text,inet) from public,anon,authenticated;
grant execute on function public.reserve_otp_request(text,inet) to service_role;

create or replace function public.create_or_request_organization(
  p_legal_name text,p_display_name text,p_ice text,p_owner_role text,
  p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private
as $$
declare
  v_actor uuid:=auth.uid(); v_ice text; v_hash text; v_existing private.identity_idempotency_keys%rowtype;
  v_org uuid; v_membership uuid; v_request uuid; v_response jsonb;
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode='42501'; end if;
  if length(trim(p_legal_name)) not between 2 and 200 or length(trim(p_display_name)) not between 2 and 200
     or p_owner_role not in ('CLIENT_OWNER','PROVIDER_OWNER','FRANCHISE_OWNER')
     or length(p_idempotency_key) not between 8 and 200 then raise exception 'INVALID_REQUEST' using errcode='22023'; end if;
  v_ice:=private.normalize_ice(p_ice);
  if length(v_ice) not between 8 and 32 then raise exception 'INVALID_ICE' using errcode='22023'; end if;
  v_hash:=private.canonical_request_hash(jsonb_build_object('operation','identity.create_or_request.v1','legal_name',trim(p_legal_name),'display_name',trim(p_display_name),'ice',v_ice,'owner_role',p_owner_role));
  select * into v_existing from private.identity_idempotency_keys where actor_user_id=v_actor and operation_scope='identity.create_or_request' and key=p_idempotency_key;
  if found then
    if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if;
    return v_existing.response_body;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('identity.ice.'||v_ice,0));
  select * into v_existing from private.identity_idempotency_keys where actor_user_id=v_actor and operation_scope='identity.create_or_request' and key=p_idempotency_key;
  if found then
    if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if;
    return v_existing.response_body;
  end if;
  select organization_id into v_org from public.organization_identifiers
  where identifier_type='ICE' and normalized_value=v_ice and is_active for update;
  if v_org is null then
    v_org:=extensions.gen_random_uuid(); v_membership:=extensions.gen_random_uuid();
    insert into public.organizations(id,legal_name,display_name,status,created_by) values(v_org,trim(p_legal_name),trim(p_display_name),'PENDING',v_actor);
    insert into public.organization_identifiers(organization_id,identifier_type,normalized_value,verification_status,is_active) values(v_org,'ICE',v_ice,'PENDING',true);
    insert into public.organization_memberships(id,organization_id,user_id,status,activated_at) values(v_membership,v_org,v_actor,'ACTIVE',clock_timestamp());
    insert into public.organization_member_roles(membership_id,role_code,granted_by) values(v_membership,p_owner_role,v_actor);
    v_response:=jsonb_build_object('outcome','ORGANIZATION_CREATED','organization_id',v_org);
    insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
      values(v_org,v_actor,'USER','organization.created','organization',v_org::text,p_correlation_id,jsonb_build_object('owner_role',p_owner_role),null,repeat('0',64));
    insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)
      values(v_org,'organization',v_org::text,'OrganizationCreatedV1',p_correlation_id,jsonb_build_object('organization_id',v_org,'owner_user_id',v_actor));
  else
    if exists(select 1 from public.organization_memberships where organization_id=v_org and user_id=v_actor and status='ACTIVE') then
      raise exception 'ALREADY_MEMBER' using errcode='23505';
    end if;
    insert into public.organization_access_requests(organization_id,requester_user_id,requested_role_code)
      values(v_org,v_actor,p_owner_role)
      on conflict(organization_id,requester_user_id,requested_role_code) where status='PENDING'
      do update set updated_at=clock_timestamp(),row_version=public.organization_access_requests.row_version+1
      returning id into v_request;
    v_response:=jsonb_build_object('outcome','ACCESS_REQUESTED','request_id',v_request);
    insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
      values(v_org,v_actor,'USER','organization.access.requested','organization_access_request',v_request::text,p_correlation_id,jsonb_build_object('requested_role',p_owner_role),null,repeat('0',64));
    insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)
      values(v_org,'organization_access_request',v_request::text,'OrganizationAccessRequestedV1',p_correlation_id,jsonb_build_object('request_id',v_request,'organization_id',v_org));
  end if;
  insert into private.identity_idempotency_keys(actor_user_id,operation_scope,key,request_hash,response_body,expires_at)
    values(v_actor,'identity.create_or_request',p_idempotency_key,v_hash,v_response,clock_timestamp()+interval '7 days');
  return v_response;
end;
$$;

create or replace function public.decide_organization_access_request(p_request_id uuid,p_approve boolean,p_correlation_id uuid default extensions.gen_random_uuid())
returns void language plpgsql security definer set search_path=pg_catalog,extensions,private
as $$
declare v_actor uuid:=auth.uid(); v_request public.organization_access_requests%rowtype; v_membership uuid;
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode='42501'; end if;
  select * into v_request from public.organization_access_requests where id=p_request_id for update;
  if not found then raise exception 'REQUEST_NOT_FOUND' using errcode='P0002'; end if;
  if not private.has_org_role(v_request.organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','PROVIDER_OWNER','PROVIDER_MANAGER','FRANCHISE_OWNER','FRANCHISE_MANAGER'],v_actor)
     and not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],v_actor)
  then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  if v_request.status<>'PENDING' then raise exception 'REQUEST_NOT_PENDING' using errcode='55000'; end if;
  update public.organization_access_requests set status=case when p_approve then 'APPROVED' else 'REJECTED' end,decided_by=v_actor,decided_at=clock_timestamp() where id=p_request_id;
  if p_approve then
    insert into public.organization_memberships(organization_id,user_id,status,invited_by,activated_at)
      values(v_request.organization_id,v_request.requester_user_id,'ACTIVE',v_actor,clock_timestamp())
      on conflict(organization_id,user_id) do update set status='ACTIVE',invited_by=v_actor,activated_at=clock_timestamp()
      returning id into v_membership;
    insert into public.organization_member_roles(membership_id,role_code,granted_by,revoked_at)
      values(v_membership,v_request.requested_role_code,v_actor,null)
      on conflict(membership_id,role_code) do update set granted_by=v_actor,granted_at=clock_timestamp(),revoked_at=null;
  end if;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
    values(v_request.organization_id,v_actor,'USER','organization.access.decided','organization_access_request',p_request_id::text,p_correlation_id,jsonb_build_object('approved',p_approve),null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)
    values(v_request.organization_id,'organization_access_request',p_request_id::text,'OrganizationAccessDecidedV1',p_correlation_id,jsonb_build_object('request_id',p_request_id,'approved',p_approve));
end;
$$;

create or replace function public.invite_organization_member(p_organization_id uuid,p_invited_user_id uuid,p_role_codes text[],p_expires_at timestamptz,p_correlation_id uuid default extensions.gen_random_uuid())
returns uuid language plpgsql security definer set search_path=pg_catalog,extensions,private
as $$
declare v_actor uuid:=auth.uid(); v_invitation uuid;
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode='42501'; end if;
  if not private.has_org_role(p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','PROVIDER_OWNER','PROVIDER_MANAGER','FRANCHISE_OWNER','FRANCHISE_MANAGER'],v_actor)
     and not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],v_actor)
  then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  if p_expires_at<=clock_timestamp() or coalesce(cardinality(p_role_codes),0)=0
    or exists(select 1 from unnest(p_role_codes) r left join public.role_definitions d on d.code=r where d.code is null or d.scope_type='PLATFORM')
  then raise exception 'INVALID_INVITATION' using errcode='22023'; end if;
  insert into public.organization_invitations(organization_id,invited_user_id,invited_by,expires_at)
    values(p_organization_id,p_invited_user_id,v_actor,p_expires_at) returning id into v_invitation;
  insert into public.organization_invitation_roles(invitation_id,role_code) select v_invitation,r from unnest(p_role_codes) r on conflict do nothing;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
    values(p_organization_id,v_actor,'USER','organization.invitation.created','organization_invitation',v_invitation::text,p_correlation_id,jsonb_build_object('role_count',cardinality(p_role_codes)),null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)
    values(p_organization_id,'organization_invitation',v_invitation::text,'OrganizationInvitationCreatedV1',p_correlation_id,jsonb_build_object('invitation_id',v_invitation,'invited_user_id',p_invited_user_id));
  return v_invitation;
end;
$$;

create or replace function public.accept_organization_invitation(p_invitation_id uuid,p_correlation_id uuid default extensions.gen_random_uuid())
returns uuid language plpgsql security definer set search_path=pg_catalog,extensions,private
as $$
declare v_actor uuid:=auth.uid(); v_invitation public.organization_invitations%rowtype; v_membership uuid;
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode='42501'; end if;
  select * into v_invitation from public.organization_invitations where id=p_invitation_id for update;
  if not found or v_invitation.invited_user_id<>v_actor then raise exception 'INVITATION_NOT_FOUND' using errcode='P0002'; end if;
  if v_invitation.status<>'PENDING' or v_invitation.expires_at<=clock_timestamp() then raise exception 'INVITATION_NOT_ACTIVE' using errcode='55000'; end if;
  insert into public.organization_memberships(organization_id,user_id,status,invited_by,activated_at)
    values(v_invitation.organization_id,v_actor,'ACTIVE',v_invitation.invited_by,clock_timestamp())
    on conflict(organization_id,user_id) do update set status='ACTIVE',invited_by=v_invitation.invited_by,activated_at=clock_timestamp()
    returning id into v_membership;
  insert into public.organization_member_roles(membership_id,role_code,granted_by,revoked_at)
    select v_membership,role_code,v_invitation.invited_by,null from public.organization_invitation_roles where invitation_id=p_invitation_id
    on conflict(membership_id,role_code) do update set granted_by=excluded.granted_by,granted_at=clock_timestamp(),revoked_at=null;
  update public.organization_invitations set status='ACCEPTED',accepted_at=clock_timestamp() where id=p_invitation_id;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
    values(v_invitation.organization_id,v_actor,'USER','organization.invitation.accepted','organization_invitation',p_invitation_id::text,p_correlation_id,'{}',null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)
    values(v_invitation.organization_id,'organization_membership',v_membership::text,'OrganizationInvitationAcceptedV1',p_correlation_id,jsonb_build_object('membership_id',v_membership,'invitation_id',p_invitation_id));
  return v_membership;
end;
$$;

create or replace function public.list_my_sessions()
returns table(id uuid,created_at timestamptz,updated_at timestamptz,refreshed_at timestamp,user_agent text,ip inet,not_after timestamptz)
language sql stable security definer set search_path=pg_catalog
as $$ select s.id,s.created_at,s.updated_at,s.refreshed_at,s.user_agent,s.ip,s.not_after from auth.sessions s where s.user_id=auth.uid() order by s.updated_at desc $$;

create or replace function public.revoke_my_session(p_session_id uuid,p_correlation_id uuid default extensions.gen_random_uuid())
returns boolean language plpgsql security definer set search_path=pg_catalog,extensions
as $$
declare v_actor uuid:=auth.uid(); v_deleted integer;
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode='42501'; end if;
  delete from auth.sessions where id=p_session_id and user_id=v_actor;
  get diagnostics v_deleted=row_count;
  if v_deleted=1 then
    insert into public.audit_events(actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
      values(v_actor,'USER','identity.session.revoked','auth_session',p_session_id::text,p_correlation_id,'{}',null,repeat('0',64));
    insert into public.event_outbox(aggregate_type,aggregate_id,event_type,correlation_id,payload)
      values('auth_session',p_session_id::text,'UserSessionRevokedV1',p_correlation_id,jsonb_build_object('session_id',p_session_id,'user_id',v_actor));
  end if;
  return v_deleted=1;
end;
$$;

alter table public.organization_access_requests enable row level security;
alter table public.organization_invitations enable row level security;
alter table public.organization_invitation_roles enable row level security;
revoke all on public.organization_access_requests,public.organization_invitations,public.organization_invitation_roles from public,anon,authenticated,service_role;
grant select on public.organization_access_requests,public.organization_invitations,public.organization_invitation_roles to authenticated;

create policy access_requests_visible on public.organization_access_requests for select to authenticated using(
  requester_user_id=auth.uid() or private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','PROVIDER_OWNER','PROVIDER_MANAGER','FRANCHISE_OWNER','FRANCHISE_MANAGER'])
  or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR'])
);
create policy invitations_visible on public.organization_invitations for select to authenticated using(
  invited_user_id=auth.uid() or private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','PROVIDER_OWNER','PROVIDER_MANAGER','FRANCHISE_OWNER','FRANCHISE_MANAGER'])
  or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'])
);
create policy invitation_roles_visible on public.organization_invitation_roles for select to authenticated using(exists(
  select 1 from public.organization_invitations i where i.id=invitation_id and (
    i.invited_user_id=auth.uid() or private.has_org_role(i.organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','PROVIDER_OWNER','PROVIDER_MANAGER','FRANCHISE_OWNER','FRANCHISE_MANAGER'])
    or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'])
  )
));

create trigger organization_access_requests_updated_at before update on public.organization_access_requests for each row execute function private.set_updated_at();
create trigger organization_invitations_updated_at before update on public.organization_invitations for each row execute function private.set_updated_at();
create index organization_access_requests_requester_idx on public.organization_access_requests(requester_user_id,status,created_at desc);
create index organization_invitations_user_idx on public.organization_invitations(invited_user_id,status,expires_at);

revoke all on function public.create_or_request_organization(text,text,text,text,text,uuid),public.decide_organization_access_request(uuid,boolean,uuid),public.invite_organization_member(uuid,uuid,text[],timestamptz,uuid),public.accept_organization_invitation(uuid,uuid),public.list_my_sessions(),public.revoke_my_session(uuid,uuid) from public,anon;
grant execute on function public.create_or_request_organization(text,text,text,text,text,uuid),public.decide_organization_access_request(uuid,boolean,uuid),public.invite_organization_member(uuid,uuid,text[],timestamptz,uuid),public.accept_organization_invitation(uuid,uuid),public.list_my_sessions(),public.revoke_my_session(uuid,uuid) to authenticated;
