-- Preserve trusted direct-database migration and test imports while keeping every
-- PostgREST caller (including service_role JWTs) behind upload reservations.
-- Rollback: restore both function bodies from migration 199.
create or replace function private.validate_provider_document_storage_binding()
returns trigger language plpgsql security definer set search_path=pg_catalog,public,storage
as $$
declare
  v_reservation public.provider_document_upload_reservations%rowtype;
  v_mime text;
  v_size text;
begin
  if session_user<>'authenticator' then return new; end if;
  if new.status in('VERIFIED','REJECTED') and new.reviewed_by is not null and exists(
    select 1 from public.provider_document_versions previous
    where previous.id=new.supersedes_version_id and previous.family_id=new.family_id
      and previous.provider_organization_id=new.provider_organization_id
      and previous.storage_object_path=new.storage_object_path and previous.content_hash=new.content_hash
  ) then return new; end if;
  select * into v_reservation from public.provider_document_upload_reservations r
  where r.provider_organization_id=new.provider_organization_id and r.actor_user_id=new.submitted_by
    and r.storage_bucket='provider-qualification' and r.storage_object_path=new.storage_object_path
    and r.status='UPLOAD_PENDING' and r.expires_at>clock_timestamp() for update;
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
  new.metadata:=new.metadata||jsonb_build_object('storage_bucket','provider-qualification','detected_mime_type',v_mime,'detected_size_bytes',v_size::bigint);
  return new;
end$$;

create or replace function private.bind_provider_document_upload()
returns trigger language plpgsql security definer set search_path=pg_catalog,public
as $$
begin
  if session_user<>'authenticator' then return new; end if;
  if new.status in('VERIFIED','REJECTED') and new.reviewed_by is not null then return new; end if;
  update public.provider_document_upload_reservations set status='BOUND',document_version_id=new.id,bound_at=clock_timestamp()
  where provider_organization_id=new.provider_organization_id and actor_user_id=new.submitted_by
    and storage_object_path=new.storage_object_path and status='UPLOAD_PENDING';
  if not found then raise exception 'PROVIDER_DOCUMENT_UPLOAD_BINDING_FAILED' using errcode='55000'; end if;
  return new;
end$$;
revoke all on function private.validate_provider_document_storage_binding(),private.bind_provider_document_upload() from public,anon,authenticated,service_role;
