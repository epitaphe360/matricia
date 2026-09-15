-- Forward-only hardening for provider qualification evidence.
-- Rollback strategy: stop calling begin_provider_document_upload, then remove the
-- new policies/triggers/functions/table and bucket only after all unbound objects
-- have been purged. Existing provider document versions remain immutable.

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('provider-qualification','provider-qualification',false,10485760,array['application/pdf','image/jpeg','image/png'])
on conflict(id) do update
set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create table public.provider_document_upload_reservations(
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  storage_bucket text not null default 'provider-qualification' check(storage_bucket='provider-qualification'),
  storage_object_path text not null unique check(length(storage_object_path) between 40 and 300),
  declared_mime_type text not null check(declared_mime_type in('application/pdf','image/jpeg','image/png')),
  declared_size_bytes bigint not null check(declared_size_bytes between 1 and 10485760),
  status text not null default 'UPLOAD_PENDING' check(status in('UPLOAD_PENDING','BOUND')),
  document_version_id uuid references public.provider_document_versions(id) on delete restrict,
  expires_at timestamptz not null default clock_timestamp()+interval '30 minutes',
  created_at timestamptz not null default clock_timestamp(),
  bound_at timestamptz,
  check((status='BOUND')=(document_version_id is not null and bound_at is not null))
);

create index provider_document_upload_reservations_pending_idx
on public.provider_document_upload_reservations(expires_at,actor_user_id)
where status='UPLOAD_PENDING';

alter table public.provider_document_upload_reservations enable row level security;
revoke all on public.provider_document_upload_reservations from public,anon,authenticated,service_role;
grant select on public.provider_document_upload_reservations to authenticated;

create policy provider_document_upload_reservations_owner_read
on public.provider_document_upload_reservations for select to authenticated
using(actor_user_id=auth.uid() and private.can_manage_provider(provider_organization_id,auth.uid()));

create function public.begin_provider_document_upload(
  p_provider_organization_id uuid,
  p_declared_mime_type text,
  p_declared_size_bytes bigint
) returns jsonb
language plpgsql security definer set search_path=pg_catalog
as $$
declare
  v_actor uuid:=auth.uid();
  v_id uuid:=extensions.gen_random_uuid();
  v_extension text;
  v_path text;
  v_expiry timestamptz:=clock_timestamp()+interval '30 minutes';
begin
  if not private.can_manage_provider(p_provider_organization_id,v_actor) then
    raise exception 'PROVIDER_SCOPE_DENIED' using errcode='42501';
  end if;
  if p_declared_mime_type not in('application/pdf','image/jpeg','image/png')
     or p_declared_size_bytes not between 1 and 10485760 then
    raise exception 'INVALID_PROVIDER_DOCUMENT_FILE' using errcode='22023';
  end if;
  v_extension:=case p_declared_mime_type when 'application/pdf' then '.pdf' when 'image/jpeg' then '.jpg' else '.png' end;
  v_path:=p_provider_organization_id::text||'/'||v_actor::text||'/'||v_id::text||v_extension;
  insert into public.provider_document_upload_reservations(
    id,provider_organization_id,actor_user_id,storage_object_path,
    declared_mime_type,declared_size_bytes,expires_at
  ) values(v_id,p_provider_organization_id,v_actor,v_path,p_declared_mime_type,p_declared_size_bytes,v_expiry);
  return jsonb_build_object(
    'outcome','PROVIDER_DOCUMENT_UPLOAD_RESERVED','upload_id',v_id,
    'storage_bucket','provider-qualification','storage_object_path',v_path,'expires_at',v_expiry
  );
end
$$;

revoke all on function public.begin_provider_document_upload(uuid,text,bigint) from public,anon,service_role;
grant execute on function public.begin_provider_document_upload(uuid,text,bigint) to authenticated;

create function private.provider_document_upload_insert_allowed(p_bucket text,p_name text,p_actor uuid)
returns boolean language sql stable security definer set search_path=pg_catalog
as $$
  select p_actor is not null and p_bucket='provider-qualification' and exists(
    select 1 from public.provider_document_upload_reservations r
    where r.actor_user_id=p_actor and r.storage_bucket=p_bucket and r.storage_object_path=p_name
      and r.status='UPLOAD_PENDING' and r.expires_at>clock_timestamp()
      and private.can_manage_provider(r.provider_organization_id,p_actor)
  )
$$;

revoke all on function private.provider_document_upload_insert_allowed(text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function private.provider_document_upload_insert_allowed(text,text,uuid) to authenticated;

create policy provider_qualification_storage_reserved_insert
on storage.objects for insert to authenticated
with check(private.provider_document_upload_insert_allowed(bucket_id,name,auth.uid()));

create policy provider_qualification_storage_orphan_delete
on storage.objects for delete to authenticated
using(private.provider_document_upload_insert_allowed(bucket_id,name,auth.uid()));

create policy provider_qualification_storage_scoped_read
on storage.objects for select to authenticated
using(
  bucket_id='provider-qualification' and exists(
    select 1 from public.provider_document_versions d
    where d.storage_object_path=name and (
      private.is_active_org_member(d.provider_organization_id,auth.uid())
      or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR'],auth.uid())
    )
  )
);

create function private.validate_provider_document_storage_binding()
returns trigger language plpgsql security definer set search_path=pg_catalog,public,storage
as $$
declare
  v_reservation public.provider_document_upload_reservations%rowtype;
  v_mime text;
  v_size text;
begin
  -- Human review creates a new immutable decision version which deliberately
  -- reuses the already bound evidence object. It must not create a second upload.
  if new.status in('VERIFIED','REJECTED') and new.reviewed_by is not null and exists(
    select 1 from public.provider_document_versions previous
    where previous.id=new.supersedes_version_id and previous.family_id=new.family_id
      and previous.provider_organization_id=new.provider_organization_id
      and previous.storage_object_path=new.storage_object_path and previous.content_hash=new.content_hash
  ) then return new; end if;

  select * into v_reservation from public.provider_document_upload_reservations r
  where r.provider_organization_id=new.provider_organization_id
    and r.actor_user_id=new.submitted_by
    and r.storage_bucket='provider-qualification'
    and r.storage_object_path=new.storage_object_path
    and r.status='UPLOAD_PENDING' and r.expires_at>clock_timestamp()
  for update;
  if not found then raise exception 'PROVIDER_DOCUMENT_UPLOAD_RESERVATION_REQUIRED' using errcode='22000'; end if;

  select lower(o.metadata->>'mimetype'),o.metadata->>'size' into v_mime,v_size
  from storage.objects o where o.bucket_id=v_reservation.storage_bucket and o.name=v_reservation.storage_object_path;
  if not found then raise exception 'PROVIDER_DOCUMENT_STORAGE_OBJECT_NOT_FOUND' using errcode='P0002'; end if;
  if coalesce(v_size,'')!~'^[0-9]+$' or v_mime<>v_reservation.declared_mime_type
     or v_size::bigint<>v_reservation.declared_size_bytes
     or new.metadata->>'declared_mime_type'<>v_reservation.declared_mime_type
     or coalesce(new.metadata->>'declared_size_bytes','')!~'^[0-9]+$'
     or (new.metadata->>'declared_size_bytes')::bigint<>v_reservation.declared_size_bytes then
    raise exception 'PROVIDER_DOCUMENT_STORAGE_METADATA_MISMATCH' using errcode='22000';
  end if;
  new.metadata:=new.metadata||jsonb_build_object(
    'storage_bucket','provider-qualification','detected_mime_type',v_mime,'detected_size_bytes',v_size::bigint
  );
  return new;
end
$$;

create function private.bind_provider_document_upload()
returns trigger language plpgsql security definer set search_path=pg_catalog,public
as $$
begin
  if new.status in('VERIFIED','REJECTED') and new.reviewed_by is not null then return new; end if;
  update public.provider_document_upload_reservations
  set status='BOUND',document_version_id=new.id,bound_at=clock_timestamp()
  where provider_organization_id=new.provider_organization_id
    and actor_user_id=new.submitted_by and storage_object_path=new.storage_object_path
    and status='UPLOAD_PENDING';
  if not found then raise exception 'PROVIDER_DOCUMENT_UPLOAD_BINDING_FAILED' using errcode='55000'; end if;
  return new;
end
$$;

create trigger provider_document_versions_validate_storage
before insert on public.provider_document_versions for each row
execute function private.validate_provider_document_storage_binding();

create trigger provider_document_versions_bind_upload
after insert on public.provider_document_versions for each row
execute function private.bind_provider_document_upload();

revoke all on function private.validate_provider_document_storage_binding(),private.bind_provider_document_upload()
from public,anon,authenticated,service_role;
