-- P05 forward-only hardening: trusted scan evidence, expiry enforcement and
-- serialization of document review by compliance case and document type.

alter table public.client_compliance_documents
  add column scan_status text not null default 'PENDING'
    check (scan_status in ('PENDING','CLEAN','INFECTED','ERROR')),
  add column scanned_at timestamptz;

alter table public.client_compliance_evidence
  add column source_document_id uuid references public.client_compliance_documents(id) on delete restrict,
  add column valid_until date;

create table private.client_document_scan_results (
  id uuid primary key default extensions.gen_random_uuid(),
  document_id uuid not null,
  organization_id uuid not null,
  sequence integer not null check(sequence>0),
  result text not null check (result in ('CLEAN','INFECTED','ERROR')),
  engine_code text not null check (engine_code ~ '^[A-Z][A-Z0-9_.-]{2,79}$'),
  engine_version text not null check (length(btrim(engine_version)) between 1 and 80),
  computed_sha256 text not null check (computed_sha256 ~ '^[0-9a-f]{64}$'),
  detected_mime_type text not null check (length(detected_mime_type) between 3 and 120),
  detected_size_bytes bigint not null check (detected_size_bytes > 0),
  observed_claims jsonb not null default '{}'::jsonb check (
    jsonb_typeof(observed_claims)='object' and octet_length(observed_claims::text)<=65536
  ),
  recorded_by uuid references auth.users(id),
  scanner_principal text not null check(scanner_principal='SUPABASE_SERVICE_ROLE'),
  correlation_id uuid not null,
  recorded_at timestamptz not null default clock_timestamp(),
  unique (document_id, correlation_id),
  unique (document_id, sequence),
  unique (id, document_id, organization_id),
  foreign key (document_id, organization_id)
    references public.client_compliance_documents(id, organization_id) on delete restrict
);

alter table public.client_compliance_documents
  add column current_scan_result_id uuid
    references private.client_document_scan_results(id) on delete restrict;
alter table public.client_compliance_documents
  drop constraint client_compliance_documents_current_scan_result_id_fkey,
  add constraint client_documents_current_scan_tenant_fk
    foreign key(current_scan_result_id,id,organization_id)
    references private.client_document_scan_results(id,document_id,organization_id)
    on delete restrict;
alter table public.client_compliance_documents
  add constraint client_documents_current_scan_state_chk
    check(
      (scan_status='PENDING')=(current_scan_result_id is null)
      and (current_scan_result_id is null)=(scanned_at is null)
    ) not valid;
alter table public.client_compliance_documents
  validate constraint client_documents_current_scan_state_chk;

-- An antivirus quarantine is a machine decision, not a human review. Replace the
-- original unnamed review-state constraint so a quarantined row may keep the
-- human review pair null while all human terminal decisions remain attributed.
do $$
declare v_constraint name;
begin
  select constraint_record.conname into strict v_constraint
  from pg_constraint constraint_record
  where constraint_record.conrelid='public.client_compliance_documents'::regclass
    and constraint_record.contype='c'
    and lower(pg_get_constraintdef(constraint_record.oid)) like '%reviewed_by is not null%'
    and lower(pg_get_constraintdef(constraint_record.oid)) like '%superseded%'
    and lower(pg_get_constraintdef(constraint_record.oid)) like '%quarantined%';
  execute format('alter table public.client_compliance_documents drop constraint %I',v_constraint);
end;
$$;
alter table public.client_compliance_documents
  add constraint client_documents_human_review_state_chk check(
    case
      when status in ('VERIFIED','REJECTED','SUPERSEDED')
        then reviewed_by is not null and reviewed_at is not null
      when status in ('UPLOAD_PENDING','PENDING_REVIEW')
        then reviewed_by is null and reviewed_at is null
      else (reviewed_by is null)=(reviewed_at is null)
    end
  ) not valid;
alter table public.client_compliance_documents
  validate constraint client_documents_human_review_state_chk;

alter table public.client_compliance_evidence
  add column validation_state text not null default 'LEGACY_UNSCANNED'
    check(validation_state in ('LEGACY_UNSCANNED','SCANNED_CLEAN'));

create table private.client_document_scan_idempotency (
  organization_id uuid not null references public.organizations(id) on delete restrict,
  key text not null check(length(key) between 8 and 200),
  request_hash text not null check(request_hash~'^[0-9a-f]{64}$'),
  response_body jsonb not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key(organization_id,key)
);
alter table private.client_document_scan_idempotency enable row level security;
revoke all on private.client_document_scan_idempotency
  from public,anon,authenticated,service_role;
create trigger client_document_scan_idempotency_immutable
before update or delete on private.client_document_scan_idempotency
for each row execute function private.prevent_update_delete();

alter table private.client_document_scan_results enable row level security;
revoke all on private.client_document_scan_results from public,anon,authenticated,service_role;
create trigger client_document_scan_results_immutable
before update or delete on private.client_document_scan_results
for each row execute function private.prevent_update_delete();

drop trigger if exists client_document_policies_immutable
  on public.client_document_policy_versions;
create trigger client_document_policies_immutable
before update or delete on public.client_document_policy_versions
for each row execute function private.prevent_update_delete();

create trigger client_compliance_evidence_immutable
before update or delete on public.client_compliance_evidence
for each row execute function private.prevent_update_delete();

do $$
begin
  if exists (
    select 1 from public.client_compliance_documents
    where status='VERIFIED'
    group by compliance_case_id,document_type having count(*)>1
  ) then
    raise exception 'DUPLICATE_VERIFIED_CLIENT_DOCUMENTS_REQUIRE_REVIEW';
  end if;
end;
$$;

create unique index client_documents_one_verified_per_type_uidx
  on public.client_compliance_documents(compliance_case_id,document_type)
  where status='VERIFIED';

create or replace function public.record_client_document_scan_result(
  p_document_id uuid,
  p_result text,
  p_engine_code text,
  p_engine_version text,
  p_computed_sha256 text,
  p_detected_mime_type text,
  p_detected_size_bytes bigint,
  p_observed_claims jsonb,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer
set search_path=pg_catalog,extensions,private
as $$
declare
  v_actor uuid:=auth.uid();
  v_document public.client_compliance_documents%rowtype;
  v_hash text;
  v_scan_id uuid;
  v_sequence integer;
  v_existing_service private.client_document_scan_idempotency%rowtype;
  v_response jsonb;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'TRUSTED_SCANNER_SERVICE_REQUIRED' using errcode='42501';
  end if;
  if p_result is null or p_result not in ('CLEAN','INFECTED','ERROR')
     or coalesce(p_engine_code,'') !~ '^[A-Z][A-Z0-9_.-]{2,79}$'
     or length(btrim(coalesce(p_engine_version,''))) not between 1 and 80
     or coalesce(p_computed_sha256,'') !~ '^[0-9a-f]{64}$'
     or length(lower(coalesce(p_detected_mime_type,''))) not between 3 and 120
     or coalesce(p_detected_size_bytes,0)<=0
     or jsonb_typeof(coalesce(p_observed_claims,'null'::jsonb))<>'object'
     or octet_length(coalesce(p_observed_claims,'null'::jsonb)::text)>65536
     or length(coalesce(p_idempotency_key,'')) not between 8 and 200 then
    raise exception 'INVALID_DOCUMENT_SCAN_RESULT' using errcode='22023';
  end if;
  select * into v_document from public.client_compliance_documents where id=p_document_id;
  if not found then raise exception 'DOCUMENT_NOT_FOUND' using errcode='P0002'; end if;
  perform pg_advisory_xact_lock(hashtextextended(
    v_document.compliance_case_id::text||':client.document.type:'||v_document.document_type,0
  ));
  select * into v_document from public.client_compliance_documents where id=p_document_id for update;
  v_hash:=private.canonical_request_hash(jsonb_build_object(
    'operation','client.document.scan.v1','document_id',p_document_id,'result',p_result,
    'engine_code',p_engine_code,'engine_version',btrim(p_engine_version),
    'computed_sha256',p_computed_sha256,'detected_mime_type',lower(p_detected_mime_type),
    'detected_size_bytes',p_detected_size_bytes,'observed_claims',p_observed_claims
  ));
  select * into v_existing_service from private.client_document_scan_idempotency
  where organization_id=v_document.organization_id and key=p_idempotency_key;
  if found then
    if v_existing_service.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if;
    return v_existing_service.response_body;
  end if;
  if v_document.status<>'PENDING_REVIEW' then
    raise exception 'INVALID_DOCUMENT_TRANSITION' using errcode='55000';
  end if;
  if p_computed_sha256<>v_document.declared_sha256
     or lower(p_detected_mime_type)<>v_document.detected_mime_type
     or p_detected_size_bytes<>v_document.detected_size_bytes then
    raise exception 'SCAN_STORAGE_EVIDENCE_MISMATCH' using errcode='22000';
  end if;
  select coalesce(max(scan.sequence),0)+1 into v_sequence
  from private.client_document_scan_results scan where scan.document_id=p_document_id;
  insert into private.client_document_scan_results(
    document_id,organization_id,sequence,result,engine_code,engine_version,computed_sha256,
    detected_mime_type,detected_size_bytes,observed_claims,recorded_by,scanner_principal,correlation_id
  ) values(p_document_id,v_document.organization_id,v_sequence,p_result,p_engine_code,btrim(p_engine_version),
    p_computed_sha256,lower(p_detected_mime_type),p_detected_size_bytes,p_observed_claims,
    v_actor,'SUPABASE_SERVICE_ROLE',p_correlation_id) returning id into v_scan_id;
  update public.client_compliance_documents
  set scan_status=p_result,scanned_at=clock_timestamp(),current_scan_result_id=v_scan_id,
      status=case when p_result='INFECTED' then 'QUARANTINED' else status end,
      row_version=row_version+1
  where id=p_document_id;
  v_response:=jsonb_build_object('outcome','DOCUMENT_SCAN_RECORDED','document_id',p_document_id,
    'scan_id',v_scan_id,'result',p_result);
  insert into public.audit_events(
    organization_id,actor_user_id,actor_type,action,resource_type,resource_id,
    correlation_id,metadata,previous_hash,event_hash
  ) values(v_document.organization_id,v_actor,'SERVICE','client.document.scan.recorded',
    'client_compliance_document',p_document_id::text,p_correlation_id,
    jsonb_build_object('result',p_result,'engine_code',p_engine_code),null,repeat('0',64));
  insert into public.event_outbox(
    organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload
  ) values(v_document.organization_id,'client_compliance_document',p_document_id::text,
    case when p_result='CLEAN' then 'ClientDocumentScanCleanV1'
      when p_result='INFECTED' then 'ClientDocumentQuarantinedV1'
      else 'ClientDocumentScanFailedV1' end,p_correlation_id,
    jsonb_build_object('document_id',p_document_id,'organization_id',v_document.organization_id,
      'compliance_case_id',v_document.compliance_case_id,'result',p_result));
  insert into private.client_document_scan_idempotency(
    organization_id,key,request_hash,response_body
  ) values(v_document.organization_id,p_idempotency_key,v_hash,v_response);
  return v_response;
end;
$$;

create or replace function public.review_client_compliance_document(
  p_document_id uuid,p_decision text,p_verified_sha256 text,p_reason_public text,
  p_reason_internal text,p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer
set search_path=pg_catalog,extensions,private
as $$
declare
  v_actor uuid:=auth.uid();
  v_document public.client_compliance_documents%rowtype;
  v_existing public.idempotency_keys%rowtype;
  v_hash text;
  v_response jsonb;
begin
  if v_actor is null or not private.has_platform_role(
    array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],v_actor
  ) then raise exception 'CENTRAL_COMPLIANCE_APPROVAL_REQUIRED' using errcode='42501'; end if;
  if p_decision is null or p_decision not in ('VERIFIED','REJECTED','QUARANTINED')
     or length(coalesce(p_idempotency_key,'')) not between 8 and 200
     or (p_decision='VERIFIED' and coalesce(p_verified_sha256,'') !~ '^[0-9a-f]{64}$')
     or (p_decision='REJECTED' and length(btrim(coalesce(p_reason_public,''))) not between 3 and 1000)
     or (p_reason_public is not null and length(btrim(p_reason_public)) not between 3 and 1000)
     or (p_reason_internal is not null and length(btrim(p_reason_internal)) not between 3 and 2000) then
    raise exception 'INVALID_DOCUMENT_REVIEW' using errcode='22023';
  end if;
  select * into v_document from public.client_compliance_documents where id=p_document_id;
  if not found then raise exception 'DOCUMENT_NOT_FOUND' using errcode='P0002'; end if;
  perform pg_advisory_xact_lock(hashtextextended(
    v_document.compliance_case_id::text||':client.document.type:'||v_document.document_type,0
  ));
  select * into v_document from public.client_compliance_documents where id=p_document_id for update;
  v_hash:=private.canonical_request_hash(jsonb_build_object(
    'operation','client.document.review.v2','document_id',p_document_id,
    'decision',p_decision,'verified_sha256',p_verified_sha256,
    'reason_public',nullif(btrim(p_reason_public),''),
    'reason_internal',nullif(btrim(p_reason_internal),'')
  ));
  select * into v_existing from public.idempotency_keys
  where organization_id=v_document.organization_id
    and operation_scope='client.document.review' and key=p_idempotency_key;
  if found then
    if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if;
    if v_existing.status='COMPLETED' then return v_existing.response_body; end if;
    raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000';
  end if;
  if v_document.status<>'PENDING_REVIEW' then raise exception 'INVALID_DOCUMENT_TRANSITION' using errcode='55000'; end if;
  if p_decision='VERIFIED' then
    if v_document.expires_on is not null and v_document.expires_on<current_date then
      raise exception 'DOCUMENT_EXPIRED' using errcode='55000';
    end if;
    if p_verified_sha256<>v_document.declared_sha256 then raise exception 'DOCUMENT_HASH_MISMATCH' using errcode='22000'; end if;
    if v_document.scan_status<>'CLEAN' or v_document.current_scan_result_id is null or not exists(
      select 1 from private.client_document_scan_results scan
      where scan.id=v_document.current_scan_result_id
        and scan.document_id=v_document.id and scan.result='CLEAN'
        and scan.sequence=(select max(latest.sequence)
          from private.client_document_scan_results latest
          where latest.document_id=v_document.id)
        and scan.computed_sha256=p_verified_sha256
        and scan.detected_mime_type=v_document.detected_mime_type
        and scan.detected_size_bytes=v_document.detected_size_bytes
    ) then raise exception 'CLEAN_DOCUMENT_SCAN_REQUIRED' using errcode='55000'; end if;
  end if;
  insert into public.idempotency_keys(
    organization_id,operation_scope,key,request_hash,created_by,expires_at
  ) values(v_document.organization_id,'client.document.review',p_idempotency_key,
    v_hash,v_actor,clock_timestamp()+interval '7 days');
  if p_decision='VERIFIED' then
    update public.client_compliance_documents set status='SUPERSEDED',row_version=row_version+1
    where compliance_case_id=v_document.compliance_case_id
      and document_type=v_document.document_type and id<>p_document_id and status='VERIFIED';
  end if;
  update public.client_compliance_documents
  set status=p_decision,
      rejection_reason_public=case when p_decision='REJECTED' then btrim(p_reason_public) end,
      reviewed_by=v_actor,reviewed_at=clock_timestamp(),row_version=row_version+1
  where id=p_document_id;
  insert into private.client_compliance_document_reviews(
    document_id,organization_id,decision,verified_sha256,reason_internal,reason_public,
    reviewed_by,correlation_id
  ) values(p_document_id,v_document.organization_id,p_decision,
    case when p_decision='VERIFIED' then p_verified_sha256 end,
    nullif(btrim(p_reason_internal),''),nullif(btrim(p_reason_public),''),v_actor,p_correlation_id);
  if p_decision='VERIFIED' then
    insert into public.client_compliance_evidence(
      compliance_case_id,organization_id,evidence_type,object_path,file_sha256,
      review_status,reviewed_by,reviewed_at,created_by,source_document_id,valid_until,
      validation_state
    ) values(v_document.compliance_case_id,v_document.organization_id,v_document.document_type,
      v_document.storage_object_path,p_verified_sha256,'VERIFIED',v_actor,clock_timestamp(),
      v_document.created_by,p_document_id,v_document.expires_on,'SCANNED_CLEAN')
    on conflict(compliance_case_id,evidence_type,file_sha256) do nothing;
  end if;
  v_response:=jsonb_build_object('outcome','DOCUMENT_'||p_decision,'document_id',p_document_id,
    'organization_id',v_document.organization_id,'status',p_decision);
  insert into public.audit_events(
    organization_id,actor_user_id,actor_type,action,resource_type,resource_id,
    correlation_id,metadata,previous_hash,event_hash
  ) values(v_document.organization_id,v_actor,'USER','client.document.reviewed',
    'client_compliance_document',p_document_id::text,p_correlation_id,
    jsonb_build_object('decision',p_decision,'document_type',v_document.document_type,
      'public_reason_provided',nullif(btrim(p_reason_public),'') is not null),null,repeat('0',64));
  insert into public.event_outbox(
    organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload
  ) values(v_document.organization_id,'client_compliance_document',p_document_id::text,
    case p_decision when 'VERIFIED' then 'ClientDocumentVerifiedV1'
      when 'REJECTED' then 'ClientDocumentRejectedV1' else 'ClientDocumentQuarantinedV1' end,
    p_correlation_id,jsonb_build_object('document_id',p_document_id,
      'organization_id',v_document.organization_id,'compliance_case_id',v_document.compliance_case_id,
      'document_type',v_document.document_type,'status',p_decision));
  update public.idempotency_keys set status='COMPLETED',response_code=200,
    response_body=v_response,completed_at=clock_timestamp()
  where organization_id=v_document.organization_id
    and operation_scope='client.document.review' and key=p_idempotency_key;
  return v_response;
end;
$$;

create or replace function private.require_verified_client_compliance()
returns trigger language plpgsql security definer set search_path=pg_catalog
as $$
declare v_required_type text;
begin
  if new.status='VERIFIED' and old.status is distinct from 'VERIFIED' then
    if exists(select 1 from public.client_administrative_anomalies anomaly
      where anomaly.compliance_case_id=new.id and anomaly.blocking
        and anomaly.status in ('OPEN','QUESTIONED')) then
      raise exception 'BLOCKING_COMPLIANCE_ANOMALY' using errcode='55000';
    end if;
    if exists(select 1 from public.client_compliance_questions question
      where question.compliance_case_id=new.id and question.status in ('OPEN','ANSWERED')) then
      raise exception 'OPEN_COMPLIANCE_QUESTION' using errcode='55000';
    end if;
    if not exists(select 1 from public.organization_identifiers i where i.organization_id=new.organization_id and i.identifier_type='ICE' and i.is_active and i.verification_status='VERIFIED')
       or not exists(select 1 from public.organization_identifiers i where i.organization_id=new.organization_id and i.identifier_type='IF' and i.is_active and i.verification_status='VERIFIED')
       or not exists(select 1 from public.organization_identifiers i where i.organization_id=new.organization_id and i.identifier_type='RC' and i.is_active and i.verification_status='VERIFIED') then
      raise exception 'VERIFIED_IDENTIFIERS_REQUIRED' using errcode='55000';
    end if;
    foreach v_required_type in array array['REGISTRATION_DOCUMENT','REPRESENTATIVE_AUTHORITY'] loop
      if not exists(
        select 1 from public.client_compliance_evidence evidence
        where evidence.compliance_case_id=new.id
          and evidence.evidence_type=v_required_type and evidence.review_status='VERIFIED'
          and evidence.validation_state='SCANNED_CLEAN'
          and evidence.source_document_id is not null and exists(
            select 1 from public.client_compliance_documents document
            where document.id=evidence.source_document_id and document.status='VERIFIED'
              and (document.expires_on is null or document.expires_on>=current_date)
              and document.scan_status='CLEAN' and document.current_scan_result_id is not null
              and exists(select 1 from private.client_document_scan_results scan
                where scan.id=document.current_scan_result_id
                  and scan.document_id=document.id and scan.result='CLEAN'
                  and scan.sequence=(select max(latest.sequence)
                    from private.client_document_scan_results latest
                    where latest.document_id=document.id)
                  and scan.computed_sha256=document.declared_sha256)
          )
      ) then raise exception 'VERIFIED_COMPLIANCE_EVIDENCE_REQUIRED' using errcode='55000'; end if;
    end loop;
  end if;
  return new;
end;
$$;

revoke all on function public.record_client_document_scan_result(
  uuid,text,text,text,text,text,bigint,jsonb,text,uuid
) from public,anon,authenticated,service_role;
grant execute on function public.record_client_document_scan_result(
  uuid,text,text,text,text,text,bigint,jsonb,text,uuid
) to service_role;
revoke all on function private.require_verified_client_compliance()
  from public,anon,authenticated,service_role;

notify pgrst,'reload schema';
