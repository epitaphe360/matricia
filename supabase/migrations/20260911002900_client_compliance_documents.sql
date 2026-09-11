-- P05 private client-compliance documents.
-- Binary payloads stay in the private Supabase Storage bucket; PostgreSQL stores
-- only versioned business metadata, upload state and review evidence.

create table public.client_document_policy_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  document_type text not null check (document_type in (
    'REGISTRATION_DOCUMENT', 'REPRESENTATIVE_AUTHORITY', 'TAX_DOCUMENT'
  )),
  version integer not null check (version > 0),
  allowed_file_types jsonb not null check (
    jsonb_typeof(allowed_file_types) = 'array' and jsonb_array_length(allowed_file_types) > 0
  ),
  max_size_bytes bigint not null check (max_size_bytes between 1 and 52428800),
  status text not null check (status in ('DRAFT', 'ACTIVE', 'RETIRED')),
  effective_from timestamptz not null,
  effective_to timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  unique (document_type, version),
  check (effective_to is null or effective_to > effective_from)
);

create unique index client_document_policy_one_active_idx
  on public.client_document_policy_versions (document_type)
  where status = 'ACTIVE' and effective_to is null;

insert into public.client_document_policy_versions (
  document_type, version, allowed_file_types, max_size_bytes, status, effective_from
) values
  ('REGISTRATION_DOCUMENT', 1,
   '[{"extension":"pdf","mime":"application/pdf"},{"extension":"jpg","mime":"image/jpeg"},{"extension":"jpeg","mime":"image/jpeg"},{"extension":"png","mime":"image/png"}]',
   10485760, 'ACTIVE', clock_timestamp()),
  ('REPRESENTATIVE_AUTHORITY', 1,
   '[{"extension":"pdf","mime":"application/pdf"},{"extension":"jpg","mime":"image/jpeg"},{"extension":"jpeg","mime":"image/jpeg"},{"extension":"png","mime":"image/png"}]',
   10485760, 'ACTIVE', clock_timestamp()),
  ('TAX_DOCUMENT', 1,
   '[{"extension":"pdf","mime":"application/pdf"},{"extension":"jpg","mime":"image/jpeg"},{"extension":"jpeg","mime":"image/jpeg"},{"extension":"png","mime":"image/png"}]',
   10485760, 'ACTIVE', clock_timestamp());

create table public.client_compliance_documents (
  id uuid primary key default extensions.gen_random_uuid(),
  compliance_case_id uuid not null,
  organization_id uuid not null,
  document_type text not null check (document_type in (
    'REGISTRATION_DOCUMENT', 'REPRESENTATIVE_AUTHORITY', 'TAX_DOCUMENT'
  )),
  version integer not null check (version > 0),
  policy_version_id uuid not null references public.client_document_policy_versions(id) on delete restrict,
  document_number text not null check (length(btrim(document_number)) between 2 and 120),
  issuer text not null check (length(btrim(issuer)) between 2 and 200),
  issued_on date not null check (issued_on >= date '1900-01-01'),
  expires_on date,
  original_file_name text not null check (
    length(btrim(original_file_name)) between 3 and 255
    and original_file_name !~ '[\\/[:cntrl:]]'
  ),
  file_extension text not null check (file_extension ~ '^[a-z0-9]{2,8}$'),
  declared_mime_type text not null check (length(declared_mime_type) between 3 and 120),
  declared_size_bytes bigint not null check (declared_size_bytes > 0),
  declared_sha256 text not null check (declared_sha256 ~ '^[0-9a-f]{64}$'),
  storage_bucket text not null default 'client-compliance' check (storage_bucket = 'client-compliance'),
  storage_object_path text not null unique check (
    length(storage_object_path) between 32 and 500 and storage_object_path !~ '(^|/)\.\.(/|$)'
  ),
  detected_mime_type text,
  detected_size_bytes bigint check (detected_size_bytes is null or detected_size_bytes > 0),
  status text not null default 'UPLOAD_PENDING' check (status in (
    'UPLOAD_PENDING', 'PENDING_REVIEW', 'VERIFIED', 'REJECTED', 'QUARANTINED', 'SUPERSEDED'
  )),
  rejection_reason_public text check (
    rejection_reason_public is null or length(btrim(rejection_reason_public)) between 3 and 1000
  ),
  uploaded_at timestamptz,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check (row_version > 0),
  unique (compliance_case_id, document_type, version),
  unique (id, organization_id),
  foreign key (compliance_case_id, organization_id)
    references public.client_compliance_cases(id, organization_id) on delete restrict,
  check (expires_on is null or expires_on >= issued_on),
  check ((status = 'UPLOAD_PENDING') = (uploaded_at is null)),
  check ((status in ('VERIFIED', 'REJECTED', 'QUARANTINED', 'SUPERSEDED')) = (reviewed_by is not null and reviewed_at is not null)),
  check ((status = 'REJECTED') = (rejection_reason_public is not null))
);

create table private.client_compliance_document_reviews (
  id bigint generated always as identity primary key,
  document_id uuid not null,
  organization_id uuid not null,
  decision text not null check (decision in ('VERIFIED', 'REJECTED', 'QUARANTINED')),
  verified_sha256 text check (verified_sha256 is null or verified_sha256 ~ '^[0-9a-f]{64}$'),
  reason_internal text check (reason_internal is null or length(btrim(reason_internal)) between 3 and 2000),
  reason_public text check (reason_public is null or length(btrim(reason_public)) between 3 and 1000),
  reviewed_by uuid not null references auth.users(id),
  correlation_id uuid not null,
  reviewed_at timestamptz not null default clock_timestamp(),
  unique (document_id, decision, correlation_id),
  foreign key (document_id, organization_id)
    references public.client_compliance_documents(id, organization_id) on delete restrict,
  check ((decision = 'VERIFIED') = (verified_sha256 is not null)),
  check ((decision = 'REJECTED') = (reason_public is not null))
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'client-compliance', 'client-compliance', false, 10485760,
  array['application/pdf', 'image/jpeg', 'image/png']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

alter table public.client_document_policy_versions enable row level security;
alter table public.client_compliance_documents enable row level security;
alter table private.client_compliance_document_reviews enable row level security;

revoke all on public.client_document_policy_versions, public.client_compliance_documents
  from public, anon, authenticated, service_role;
revoke all on private.client_compliance_document_reviews
  from public, anon, authenticated, service_role;
grant select on public.client_document_policy_versions, public.client_compliance_documents
  to authenticated;

create policy client_document_policy_read
on public.client_document_policy_versions for select to authenticated
using (status = 'ACTIVE' and effective_from <= clock_timestamp()
  and (effective_to is null or effective_to > clock_timestamp()));

create policy client_compliance_documents_read
on public.client_compliance_documents for select to authenticated
using (
  private.has_org_role(organization_id, array['CLIENT_OWNER','CLIENT_ADMIN'], auth.uid())
  or private.has_platform_role(
    array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR'], auth.uid()
  )
);

-- Storage is private. Clients can insert only into a path reserved by the begin RPC;
-- overwrites and deletes deliberately have no authenticated policy.
create policy client_compliance_storage_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'client-compliance'
  and exists (
    select 1
    from public.client_compliance_documents document
    where document.storage_bucket = bucket_id
      and document.storage_object_path = name
      and document.status = 'UPLOAD_PENDING'
      and document.created_by = auth.uid()
      and private.has_org_role(
        document.organization_id, array['CLIENT_OWNER','CLIENT_ADMIN'], auth.uid()
      )
  )
);

create policy client_compliance_storage_read
on storage.objects for select to authenticated
using (
  bucket_id = 'client-compliance'
  and exists (
    select 1
    from public.client_compliance_documents document
    where document.storage_bucket = bucket_id
      and document.storage_object_path = name
      and (
        (document.status <> 'QUARANTINED' and private.has_org_role(
          document.organization_id, array['CLIENT_OWNER','CLIENT_ADMIN'], auth.uid()
        ))
        or private.has_platform_role(
          array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'], auth.uid()
        )
      )
  )
);

create or replace function public.begin_client_compliance_document_upload(
  p_compliance_case_id uuid,
  p_document_type text,
  p_document_number text,
  p_issuer text,
  p_issued_on date,
  p_expires_on date,
  p_original_file_name text,
  p_mime_type text,
  p_size_bytes bigint,
  p_sha256 text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_case public.client_compliance_cases%rowtype;
  v_policy public.client_document_policy_versions%rowtype;
  v_existing public.idempotency_keys%rowtype;
  v_hash text;
  v_extension text;
  v_version integer;
  v_document_id uuid := extensions.gen_random_uuid();
  v_path text;
  v_response jsonb;
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode = '42501'; end if;
  select * into v_case from public.client_compliance_cases
  where id = p_compliance_case_id for update;
  if not found or not private.has_org_role(
    v_case.organization_id, array['CLIENT_OWNER','CLIENT_ADMIN'], v_actor
  ) then raise exception 'COMPLIANCE_CASE_NOT_FOUND' using errcode = 'P0002'; end if;
  if length(coalesce(p_idempotency_key,'')) not between 8 and 200
     or length(btrim(coalesce(p_document_number,''))) not between 2 and 120
     or length(btrim(coalesce(p_issuer,''))) not between 2 and 200
     or p_issued_on is null or p_issued_on > current_date
     or (p_expires_on is not null and p_expires_on < p_issued_on)
     or length(btrim(coalesce(p_original_file_name,''))) not between 3 and 255
     or p_original_file_name ~ '[\\/[:cntrl:]]'
     or coalesce(p_sha256,'') !~ '^[0-9a-f]{64}$'
     or p_size_bytes is null or p_size_bytes <= 0 then
    raise exception 'INVALID_DOCUMENT_METADATA' using errcode = '22023';
  end if;
  v_extension := lower(substring(p_original_file_name from '\.([^.]+)$'));
  v_hash := private.canonical_request_hash(jsonb_build_object(
    'operation','client.document.begin.v1', 'case_id',p_compliance_case_id,
    'document_type',p_document_type, 'document_number',btrim(p_document_number),
    'issuer',btrim(p_issuer), 'issued_on',p_issued_on, 'expires_on',p_expires_on,
    'file_name',p_original_file_name, 'mime_type',lower(p_mime_type),
    'size_bytes',p_size_bytes, 'sha256',p_sha256
  ));
  perform pg_advisory_xact_lock(hashtextextended(
    v_case.organization_id::text || ':client.document.begin:' || p_idempotency_key, 0
  ));
  select * into v_existing from public.idempotency_keys
  where organization_id = v_case.organization_id
    and operation_scope = 'client.document.begin' and key = p_idempotency_key;
  if found then
    if v_existing.request_hash <> v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode = '22000'; end if;
    if v_existing.status = 'COMPLETED' then return v_existing.response_body; end if;
    raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode = '55000';
  end if;
  if v_case.current_profile_version is null
     or v_case.status not in ('PROFILE_IN_PROGRESS','DOCUMENTS_REQUIRED','QUESTION_REQUIRED','REJECTED') then
    raise exception 'DOCUMENT_UPLOAD_NOT_ALLOWED' using errcode = '55000';
  end if;
  select * into v_policy
  from public.client_document_policy_versions policy
  where policy.document_type = p_document_type
    and policy.status = 'ACTIVE'
    and policy.effective_from <= clock_timestamp()
    and (policy.effective_to is null or policy.effective_to > clock_timestamp());
  if not found then raise exception 'DOCUMENT_POLICY_NOT_FOUND' using errcode = '22023'; end if;
  if p_size_bytes > v_policy.max_size_bytes or not exists (
    select 1 from jsonb_array_elements(v_policy.allowed_file_types) allowed
    where allowed ->> 'extension' = v_extension and allowed ->> 'mime' = lower(p_mime_type)
  ) then raise exception 'DOCUMENT_FILE_TYPE_OR_SIZE_NOT_ALLOWED' using errcode = '22023'; end if;
  insert into public.idempotency_keys (
    organization_id, operation_scope, key, request_hash, created_by, expires_at
  ) values (v_case.organization_id, 'client.document.begin', p_idempotency_key,
    v_hash, v_actor, clock_timestamp() + interval '1 day');

  select coalesce(max(version),0) + 1 into v_version
  from public.client_compliance_documents
  where compliance_case_id = p_compliance_case_id and document_type = p_document_type;
  v_path := v_case.organization_id::text || '/' || p_compliance_case_id::text || '/'
    || v_document_id::text || '.' || v_extension;
  insert into public.client_compliance_documents (
    id, compliance_case_id, organization_id, document_type, version, policy_version_id,
    document_number, issuer, issued_on, expires_on, original_file_name, file_extension,
    declared_mime_type, declared_size_bytes, declared_sha256, storage_object_path, created_by
  ) values (
    v_document_id, p_compliance_case_id, v_case.organization_id, p_document_type, v_version,
    v_policy.id, btrim(p_document_number), btrim(p_issuer), p_issued_on, p_expires_on,
    btrim(p_original_file_name), v_extension, lower(p_mime_type), p_size_bytes,
    p_sha256, v_path, v_actor
  );
  update public.client_compliance_cases set status = 'DOCUMENTS_REQUIRED'
  where id = p_compliance_case_id and status in ('PROFILE_IN_PROGRESS','REJECTED');

  v_response := jsonb_build_object(
    'outcome','DOCUMENT_UPLOAD_RESERVED', 'document_id',v_document_id,
    'organization_id',v_case.organization_id, 'version',v_version,
    'bucket','client-compliance', 'object_path',v_path, 'status','UPLOAD_PENDING'
  );
  insert into public.audit_events (
    organization_id, actor_user_id, actor_type, action, resource_type,
    resource_id, correlation_id, metadata, previous_hash, event_hash
  ) values (v_case.organization_id, v_actor, 'USER', 'client.document.upload.reserved',
    'client_compliance_document', v_document_id::text, p_correlation_id,
    jsonb_build_object('document_type',p_document_type,'version',v_version), null, repeat('0',64));
  insert into public.event_outbox (
    organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload
  ) values (v_case.organization_id, 'client_compliance_document', v_document_id::text,
    'ClientDocumentUploadReservedV1', p_correlation_id,
    jsonb_build_object('document_id',v_document_id,'organization_id',v_case.organization_id,
      'compliance_case_id',p_compliance_case_id,'document_type',p_document_type,'version',v_version));
  update public.idempotency_keys set status='COMPLETED', response_code=201,
    response_body=v_response, completed_at=clock_timestamp()
  where organization_id=v_case.organization_id and operation_scope='client.document.begin'
    and key=p_idempotency_key;
  return v_response;
end;
$$;

create or replace function public.finalize_client_compliance_document_upload(
  p_document_id uuid,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_document public.client_compliance_documents%rowtype;
  v_object record;
  v_existing public.idempotency_keys%rowtype;
  v_hash text;
  v_response jsonb;
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode = '42501'; end if;
  select * into v_document from public.client_compliance_documents
  where id = p_document_id for update;
  if not found or not private.has_org_role(
    v_document.organization_id, array['CLIENT_OWNER','CLIENT_ADMIN'], v_actor
  ) then raise exception 'DOCUMENT_NOT_FOUND' using errcode = 'P0002'; end if;
  if length(coalesce(p_idempotency_key,'')) not between 8 and 200 then
    raise exception 'INVALID_IDEMPOTENCY_KEY' using errcode = '22023';
  end if;
  v_hash := private.canonical_request_hash(jsonb_build_object(
    'operation','client.document.finalize.v1','document_id',p_document_id
  ));
  perform pg_advisory_xact_lock(hashtextextended(
    v_document.organization_id::text || ':client.document.finalize:' || p_idempotency_key, 0
  ));
  select * into v_existing from public.idempotency_keys
  where organization_id=v_document.organization_id
    and operation_scope='client.document.finalize' and key=p_idempotency_key;
  if found then
    if v_existing.request_hash <> v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if;
    if v_existing.status='COMPLETED' then return v_existing.response_body; end if;
    raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000';
  end if;
  if v_document.status <> 'UPLOAD_PENDING' then
    raise exception 'INVALID_DOCUMENT_TRANSITION' using errcode='55000';
  end if;
  select object.metadata ->> 'mimetype' as mime_type,
         object.metadata ->> 'size' as size_text
  into v_object
  from storage.objects object
  where object.bucket_id=v_document.storage_bucket and object.name=v_document.storage_object_path;
  if not found then raise exception 'STORAGE_OBJECT_NOT_FOUND' using errcode='P0002'; end if;
  if coalesce(v_object.size_text,'') !~ '^[0-9]+$'
     or lower(coalesce(v_object.mime_type,'')) <> v_document.declared_mime_type
     or v_object.size_text::bigint <> v_document.declared_size_bytes then
    raise exception 'STORAGE_METADATA_MISMATCH' using errcode='22000';
  end if;
  insert into public.idempotency_keys (
    organization_id, operation_scope, key, request_hash, created_by, expires_at
  ) values (v_document.organization_id,'client.document.finalize',p_idempotency_key,
    v_hash,v_actor,clock_timestamp()+interval '7 days');
  update public.client_compliance_documents
  set status='PENDING_REVIEW', detected_mime_type=lower(v_object.mime_type),
      detected_size_bytes=v_object.size_text::bigint, uploaded_at=clock_timestamp(),
      row_version=row_version+1
  where id=p_document_id;
  v_response := jsonb_build_object('outcome','DOCUMENT_UPLOADED','document_id',p_document_id,
    'organization_id',v_document.organization_id,'status','PENDING_REVIEW');
  insert into public.audit_events (
    organization_id,actor_user_id,actor_type,action,resource_type,resource_id,
    correlation_id,metadata,previous_hash,event_hash
  ) values (v_document.organization_id,v_actor,'USER','client.document.upload.finalized',
    'client_compliance_document',p_document_id::text,p_correlation_id,
    jsonb_build_object('document_type',v_document.document_type,'version',v_document.version),null,repeat('0',64));
  insert into public.event_outbox (
    organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload
  ) values (v_document.organization_id,'client_compliance_document',p_document_id::text,
    'DocumentUploadedV1',p_correlation_id,jsonb_build_object('document_id',p_document_id,
      'organization_id',v_document.organization_id,'compliance_case_id',v_document.compliance_case_id,
      'document_type',v_document.document_type,'scan_status','PENDING'));
  update public.idempotency_keys set status='COMPLETED',response_code=202,
    response_body=v_response,completed_at=clock_timestamp()
  where organization_id=v_document.organization_id and operation_scope='client.document.finalize'
    and key=p_idempotency_key;
  return v_response;
end;
$$;

create or replace function public.review_client_compliance_document(
  p_document_id uuid,
  p_decision text,
  p_verified_sha256 text,
  p_reason_public text,
  p_reason_internal text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_document public.client_compliance_documents%rowtype;
  v_existing public.idempotency_keys%rowtype;
  v_hash text;
  v_response jsonb;
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode='42501'; end if;
  if not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],v_actor) then
    raise exception 'CENTRAL_COMPLIANCE_APPROVAL_REQUIRED' using errcode='42501';
  end if;
  if p_decision is null or p_decision not in ('VERIFIED','REJECTED','QUARANTINED')
     or length(coalesce(p_idempotency_key,'')) not between 8 and 200
     or (p_decision='VERIFIED' and coalesce(p_verified_sha256,'') !~ '^[0-9a-f]{64}$')
     or (p_decision='REJECTED' and length(btrim(coalesce(p_reason_public,''))) not between 3 and 1000)
     or (p_reason_public is not null and length(btrim(p_reason_public)) not between 3 and 1000)
     or (p_reason_internal is not null and length(btrim(p_reason_internal)) not between 3 and 2000) then
    raise exception 'INVALID_DOCUMENT_REVIEW' using errcode='22023';
  end if;
  select * into v_document from public.client_compliance_documents
  where id=p_document_id for update;
  if not found then raise exception 'DOCUMENT_NOT_FOUND' using errcode='P0002'; end if;
  v_hash := private.canonical_request_hash(jsonb_build_object(
    'operation','client.document.review.v1','document_id',p_document_id,
    'decision',p_decision,'verified_sha256',p_verified_sha256,
    'reason_public',nullif(btrim(p_reason_public),''),'reason_internal',nullif(btrim(p_reason_internal),'')
  ));
  perform pg_advisory_xact_lock(hashtextextended(
    v_document.organization_id::text || ':client.document.review:' || p_idempotency_key,0
  ));
  select * into v_existing from public.idempotency_keys
  where organization_id=v_document.organization_id
    and operation_scope='client.document.review' and key=p_idempotency_key;
  if found then
    if v_existing.request_hash <> v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if;
    if v_existing.status='COMPLETED' then return v_existing.response_body; end if;
    raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000';
  end if;
  if v_document.status <> 'PENDING_REVIEW' then
    raise exception 'INVALID_DOCUMENT_TRANSITION' using errcode='55000';
  end if;
  if p_decision='VERIFIED' and p_verified_sha256 <> v_document.declared_sha256 then
    raise exception 'DOCUMENT_HASH_MISMATCH' using errcode='22000';
  end if;
  insert into public.idempotency_keys (
    organization_id,operation_scope,key,request_hash,created_by,expires_at
  ) values (v_document.organization_id,'client.document.review',p_idempotency_key,
    v_hash,v_actor,clock_timestamp()+interval '7 days');
  update public.client_compliance_documents
  set status=p_decision,rejection_reason_public=case when p_decision='REJECTED' then btrim(p_reason_public) end,
      reviewed_by=v_actor,reviewed_at=clock_timestamp(),row_version=row_version+1
  where id=p_document_id;
  insert into private.client_compliance_document_reviews (
    document_id,organization_id,decision,verified_sha256,reason_internal,reason_public,
    reviewed_by,correlation_id
  ) values (p_document_id,v_document.organization_id,p_decision,
    case when p_decision='VERIFIED' then p_verified_sha256 end,
    nullif(btrim(p_reason_internal),''),nullif(btrim(p_reason_public),''),v_actor,p_correlation_id);
  if p_decision='VERIFIED' then
    update public.client_compliance_documents set status='SUPERSEDED',row_version=row_version+1
    where compliance_case_id=v_document.compliance_case_id
      and document_type=v_document.document_type and id<>p_document_id and status='VERIFIED';
    insert into public.client_compliance_evidence (
      compliance_case_id,organization_id,evidence_type,object_path,file_sha256,
      review_status,reviewed_by,reviewed_at,created_by
    ) values (v_document.compliance_case_id,v_document.organization_id,v_document.document_type,
      v_document.storage_object_path,p_verified_sha256,'VERIFIED',v_actor,clock_timestamp(),v_document.created_by)
    on conflict (compliance_case_id,evidence_type,file_sha256) do nothing;
  end if;
  v_response := jsonb_build_object('outcome','DOCUMENT_'||p_decision,'document_id',p_document_id,
    'organization_id',v_document.organization_id,'status',p_decision);
  insert into public.audit_events (
    organization_id,actor_user_id,actor_type,action,resource_type,resource_id,
    correlation_id,metadata,previous_hash,event_hash
  ) values (v_document.organization_id,v_actor,'USER','client.document.reviewed',
    'client_compliance_document',p_document_id::text,p_correlation_id,
    jsonb_build_object('decision',p_decision,'document_type',v_document.document_type,
      'public_reason_provided',nullif(btrim(p_reason_public),'') is not null),null,repeat('0',64));
  insert into public.event_outbox (
    organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload
  ) values (v_document.organization_id,'client_compliance_document',p_document_id::text,
    case p_decision when 'VERIFIED' then 'ClientDocumentVerifiedV1'
      when 'REJECTED' then 'ClientDocumentRejectedV1' else 'ClientDocumentQuarantinedV1' end,
    p_correlation_id,jsonb_build_object('document_id',p_document_id,
      'organization_id',v_document.organization_id,'compliance_case_id',v_document.compliance_case_id,
      'document_type',v_document.document_type,'status',p_decision));
  update public.idempotency_keys set status='COMPLETED',response_code=200,
    response_body=v_response,completed_at=clock_timestamp()
  where organization_id=v_document.organization_id and operation_scope='client.document.review'
    and key=p_idempotency_key;
  return v_response;
end;
$$;

create or replace function private.require_client_documents_for_review()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_required_type text;
begin
  if new.status = 'UNDER_REVIEW'
     and old.status in ('PROFILE_IN_PROGRESS','DOCUMENTS_REQUIRED') then
    foreach v_required_type in array array['REGISTRATION_DOCUMENT','REPRESENTATIVE_AUTHORITY'] loop
      if not exists (
        select 1
        from public.client_compliance_documents document
        where document.compliance_case_id = new.id
          and document.document_type = v_required_type
          and document.status in ('PENDING_REVIEW','VERIFIED')
          and (document.expires_on is null or document.expires_on >= current_date)
      ) and not exists (
        -- Backward-compatible trusted evidence created before this document workflow.
        select 1
        from public.client_compliance_evidence evidence
        where evidence.compliance_case_id = new.id
          and evidence.evidence_type = v_required_type
          and evidence.review_status = 'VERIFIED'
      ) then
        raise exception 'REQUIRED_CLIENT_DOCUMENTS_MISSING' using errcode='55000';
      end if;
    end loop;
  end if;
  return new;
end;
$$;
revoke all on function private.require_client_documents_for_review()
  from public,anon,authenticated,service_role;
create trigger client_compliance_require_documents_for_review
before update of status on public.client_compliance_cases
for each row execute function private.require_client_documents_for_review();

create trigger client_document_policies_immutable
before delete on public.client_document_policy_versions
for each row execute function private.prevent_update_delete();
create trigger client_document_reviews_immutable
before update or delete on private.client_compliance_document_reviews
for each row execute function private.prevent_update_delete();
create trigger client_compliance_documents_updated_at
before update on public.client_compliance_documents
for each row execute function private.set_updated_at();

create index client_compliance_documents_case_status_idx
  on public.client_compliance_documents (compliance_case_id,status,document_type,version desc);
create index client_compliance_documents_org_created_idx
  on public.client_compliance_documents (organization_id,created_at desc,id);
create index client_compliance_document_reviews_document_idx
  on private.client_compliance_document_reviews (document_id,reviewed_at desc,id desc);

revoke all on function public.begin_client_compliance_document_upload(
  uuid,text,text,text,date,date,text,text,bigint,text,text,uuid
), public.finalize_client_compliance_document_upload(uuid,text,uuid),
  public.review_client_compliance_document(uuid,text,text,text,text,text,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.begin_client_compliance_document_upload(
  uuid,text,text,text,date,date,text,text,bigint,text,text,uuid
), public.finalize_client_compliance_document_upload(uuid,text,uuid),
  public.review_client_compliance_document(uuid,text,text,text,text,text,uuid)
  to authenticated;

notify pgrst, 'reload schema';
