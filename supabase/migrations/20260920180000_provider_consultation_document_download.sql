-- Invited providers may list and download Client documents bound to the RFQ
-- service request. Bindings stay client-admin readable; this SECURITY DEFINER
-- path is the only provider access. Storage objects remain private.

create function private.provider_consultation_invitation(p_rfq_provider_id uuid, p_actor uuid)
returns public.rfq_providers
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  invite public.rfq_providers%rowtype;
begin
  if p_actor is null or auth.role() is distinct from 'authenticated' then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;
  select * into invite from public.rfq_providers where id = p_rfq_provider_id;
  if not found
    or invite.status not in ('INVITED', 'VIEWED', 'ACCEPTED')
    or not private.has_org_role(
      invite.provider_organization_id,
      array['PROVIDER_OWNER', 'PROVIDER_MANAGER', 'PROVIDER_SALES', 'PROVIDER_VIEWER'],
      p_actor
    )
  then
    raise exception 'RFQ_DOCUMENT_DENIED' using errcode = '42501';
  end if;
  return invite;
end;
$$;

create function private.provider_consultation_shared_document(p_rfq_id uuid, p_document_id uuid)
returns public.client_compliance_documents
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  document public.client_compliance_documents%rowtype;
begin
  select d.* into document
  from public.client_compliance_documents d
  join public.client_document_bindings b
    on b.document_id = d.id
   and b.target_type = 'SERVICE_REQUEST'
  join public.rfqs r
    on r.request_id = b.target_id
   and r.id = p_rfq_id
  where d.id = p_document_id
    and d.status = 'VERIFIED'
    and d.scan_status = 'CLEAN'
    and d.current_scan_result_id is not null
    and (d.expires_on is null or d.expires_on >= current_date)
    and not exists (
      select 1
      from public.client_document_binding_revocations rev
      where rev.binding_id = b.id
    )
    and exists (
      select 1
      from private.client_document_scan_results scan
      where scan.id = d.current_scan_result_id
        and scan.document_id = d.id
        and scan.organization_id = d.organization_id
        and scan.result = 'CLEAN'
        and scan.computed_sha256 = d.declared_sha256
    );
  if not found then
    raise exception 'RFQ_DOCUMENT_DENIED' using errcode = '42501';
  end if;
  return document;
end;
$$;

create function public.list_provider_consultation_documents(p_rfq_provider_id uuid)
returns table(
  document_id uuid,
  title text,
  file_extension text,
  size_bytes bigint
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  invite public.rfq_providers%rowtype;
begin
  invite := private.provider_consultation_invitation(p_rfq_provider_id, auth.uid());
  return query
    select d.id, d.original_file_name, d.file_extension, d.declared_size_bytes
    from public.client_compliance_documents d
    join public.client_document_bindings b
      on b.document_id = d.id
     and b.target_type = 'SERVICE_REQUEST'
    join public.rfqs r
      on r.request_id = b.target_id
     and r.id = invite.rfq_id
    where d.status = 'VERIFIED'
      and d.scan_status = 'CLEAN'
      and d.current_scan_result_id is not null
      and (d.expires_on is null or d.expires_on >= current_date)
      and not exists (
        select 1
        from public.client_document_binding_revocations rev
        where rev.binding_id = b.id
      )
      and exists (
        select 1
        from private.client_document_scan_results scan
        where scan.id = d.current_scan_result_id
          and scan.document_id = d.id
          and scan.organization_id = d.organization_id
          and scan.result = 'CLEAN'
          and scan.computed_sha256 = d.declared_sha256
      )
    order by d.original_file_name, d.id
    limit 20;
end;
$$;

create function public.authorize_provider_consultation_document(p_rfq_provider_id uuid, p_document_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  actor uuid := auth.uid();
  invite public.rfq_providers%rowtype;
  document public.client_compliance_documents%rowtype;
begin
  invite := private.provider_consultation_invitation(p_rfq_provider_id, actor);
  document := private.provider_consultation_shared_document(invite.rfq_id, p_document_id);
  insert into public.audit_events(
    organization_id, actor_user_id, actor_type, action, resource_type,
    resource_id, correlation_id, metadata, event_hash
  ) values (
    document.organization_id,
    actor,
    'USER',
    'provider.consultation.document.downloaded',
    'client_compliance_document',
    document.id::text,
    extensions.gen_random_uuid(),
    jsonb_build_object(
      'rfq_provider_id', invite.id,
      'provider_organization_id', invite.provider_organization_id,
      'document_version', document.version
    ),
    repeat('0', 64)
  );
  return jsonb_build_object(
    'outcome', 'PROVIDER_CONSULTATION_DOCUMENT_AUTHORIZED',
    'document_id', document.id,
    'bucket', document.storage_bucket,
    'object_path', document.storage_object_path,
    'file_name', document.original_file_name,
    'mime_type', document.declared_mime_type,
    'size_bytes', document.declared_size_bytes
  );
end;
$$;

revoke all on function private.provider_consultation_invitation(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.provider_consultation_shared_document(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.list_provider_consultation_documents(uuid)
  from public, anon, service_role;
revoke all on function public.authorize_provider_consultation_document(uuid, uuid)
  from public, anon, service_role;
grant execute on function public.list_provider_consultation_documents(uuid) to authenticated;
grant execute on function public.authorize_provider_consultation_document(uuid, uuid) to authenticated;
