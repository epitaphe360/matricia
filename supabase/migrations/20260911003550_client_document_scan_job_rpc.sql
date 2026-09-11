-- P05 worker adapter: least-privilege access to one finalized document scan job.

create function public.get_client_document_scan_job(p_document_id uuid)
returns table(
  document_id uuid,
  organization_id uuid,
  compliance_case_id uuid,
  status text,
  storage_bucket text,
  storage_object_path text,
  declared_sha256 text,
  detected_mime_type text,
  detected_size_bytes bigint
)
language plpgsql stable security definer
set search_path=pg_catalog
as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'TRUSTED_SCANNER_SERVICE_REQUIRED' using errcode='42501';
  end if;
  return query
  select document.id,document.organization_id,document.compliance_case_id,
    document.status,document.storage_bucket,document.storage_object_path,
    document.declared_sha256,document.detected_mime_type,document.detected_size_bytes
  from public.client_compliance_documents document
  where document.id=p_document_id
    and document.status in ('PENDING_REVIEW','VERIFIED','QUARANTINED')
    and document.detected_mime_type is not null
    and document.detected_size_bytes is not null;
end;
$$;

revoke all on function public.get_client_document_scan_job(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.get_client_document_scan_job(uuid) to service_role;

notify pgrst,'reload schema';
