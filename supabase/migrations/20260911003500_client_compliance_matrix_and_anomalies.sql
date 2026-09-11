-- P05 versioned document requirement matrix and deterministic anomaly coverage.

alter table public.client_document_policy_versions
  add constraint client_document_policy_bucket_size_chk
  check(max_size_bytes<=10485760) not valid;
alter table public.client_document_policy_versions
  validate constraint client_document_policy_bucket_size_chk;

create table public.client_document_requirement_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_kind text not null check (organization_kind in ('CLIENT')),
  library_code text check (library_code is null or library_code ~ '^[A-Z][A-Z0-9_-]{1,79}$'),
  document_type text not null check (document_type in (
    'REGISTRATION_DOCUMENT','REPRESENTATIVE_AUTHORITY','TAX_DOCUMENT'
  )),
  version integer not null check (version>0),
  required boolean not null,
  status text not null check (status in ('DRAFT','ACTIVE','RETIRED')),
  effective_from timestamptz not null,
  effective_to timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  unique nulls not distinct(organization_kind,library_code,document_type,version),
  check(effective_to is null or effective_to>effective_from)
);

create unique index client_document_requirements_one_active_uidx
on public.client_document_requirement_versions(
  organization_kind,coalesce(library_code,''),document_type
) where status='ACTIVE' and effective_to is null;

insert into public.client_document_requirement_versions(
  organization_kind,library_code,document_type,version,required,status,effective_from
) values
('CLIENT',null,'REGISTRATION_DOCUMENT',1,true,'ACTIVE',clock_timestamp()),
('CLIENT',null,'REPRESENTATIVE_AUTHORITY',1,true,'ACTIVE',clock_timestamp())
on conflict(organization_kind,library_code,document_type,version) do nothing;

alter table public.client_document_requirement_versions enable row level security;
revoke all on public.client_document_requirement_versions from public,anon,authenticated,service_role;
grant select on public.client_document_requirement_versions to authenticated;
create policy client_document_requirements_read
on public.client_document_requirement_versions for select to authenticated
using(status='ACTIVE' and effective_from<=clock_timestamp()
  and (effective_to is null or effective_to>clock_timestamp()));
create trigger client_document_requirements_immutable
before update or delete on public.client_document_requirement_versions
for each row execute function private.prevent_update_delete();

create or replace function private.protect_client_document_version_content()
returns trigger language plpgsql security definer set search_path=pg_catalog
as $$
begin
  if tg_op='DELETE' then raise exception 'IMMUTABLE_RECORD' using errcode='55000'; end if;
  if (to_jsonb(new)-'status'-'effective_to') is distinct from
     (to_jsonb(old)-'status'-'effective_to') then
    raise exception 'IMMUTABLE_RECORD' using errcode='55000';
  end if;
  if not (
    (new.status=old.status and new.effective_to is not distinct from old.effective_to)
    or (old.status='DRAFT' and new.status='ACTIVE' and new.effective_to is null)
    or (old.status='ACTIVE' and new.status='RETIRED'
      and old.effective_to is null and new.effective_to is not null
      and new.effective_to>new.effective_from)
  ) then raise exception 'INVALID_VERSION_LIFECYCLE' using errcode='55000'; end if;
  return new;
end;
$$;
revoke all on function private.protect_client_document_version_content()
  from public,anon,authenticated,service_role;
drop trigger client_document_policies_immutable on public.client_document_policy_versions;
create trigger client_document_policies_immutable
before update or delete on public.client_document_policy_versions
for each row execute function private.protect_client_document_version_content();
drop trigger client_document_requirements_immutable on public.client_document_requirement_versions;
create trigger client_document_requirements_immutable
before update or delete on public.client_document_requirement_versions
for each row execute function private.protect_client_document_version_content();

alter table public.client_administrative_anomalies
  add constraint client_anomalies_identity_tenant_uidx
  unique(id,organization_id,compliance_case_id);
alter table public.client_compliance_questions
  drop constraint client_compliance_questions_anomaly_id_fkey,
  add constraint client_questions_anomaly_tenant_fk
    foreign key(anomaly_id,organization_id,compliance_case_id)
    references public.client_administrative_anomalies(id,organization_id,compliance_case_id)
    on delete restrict,
  add constraint client_questions_expected_document_type_chk
    check(expected_document_type is null or expected_document_type in (
      'REGISTRATION_DOCUMENT','REPRESENTATIVE_AUTHORITY','TAX_DOCUMENT'
    )) not valid,
  add constraint client_questions_acceptance_pair_chk
    check((accepted_by is null)=(accepted_at is null)) not valid;
alter table public.client_compliance_questions
  validate constraint client_questions_expected_document_type_chk,
  validate constraint client_questions_acceptance_pair_chk;

alter table public.client_administrative_anomalies
  add constraint client_anomalies_resolution_pair_chk
    check((resolved_by is null)=(resolved_at is null)) not valid;
alter table public.client_administrative_anomalies
  validate constraint client_anomalies_resolution_pair_chk;

alter table public.client_compliance_documents
  add constraint client_documents_review_pair_chk
    check((reviewed_by is null)=(reviewed_at is null)) not valid;
alter table public.client_compliance_documents
  validate constraint client_documents_review_pair_chk;

alter table public.client_compliance_evidence
  drop constraint client_compliance_evidence_source_document_id_fkey,
  add constraint client_evidence_source_document_tenant_fk
    foreign key(source_document_id,organization_id)
    references public.client_compliance_documents(id,organization_id) on delete restrict;

create or replace function private.set_client_compliance_anomaly(
  p_case_id uuid,p_organization_id uuid,p_code text,p_field_path text,
  p_detected boolean,p_message_fr text,p_message_ar text,p_actor uuid,
  p_entered_digest text default null,p_observed_digest text default null
) returns void
language plpgsql security definer set search_path=pg_catalog
as $$
begin
  if p_detected then
    insert into public.client_administrative_anomalies(
      compliance_case_id,organization_id,anomaly_code,field_path,severity,blocking,
      status,client_message_fr,client_message_ar,entered_value_digest,
      observed_value_digest,detected_by
    ) values(p_case_id,p_organization_id,p_code,p_field_path,'CRITICAL',true,'OPEN',
      p_message_fr,p_message_ar,p_entered_digest,p_observed_digest,'RULE_ENGINE')
    on conflict(compliance_case_id,anomaly_code) do update
    set field_path=excluded.field_path,severity=excluded.severity,blocking=excluded.blocking,
        client_message_fr=excluded.client_message_fr,client_message_ar=excluded.client_message_ar,
        entered_value_digest=excluded.entered_value_digest,
        observed_value_digest=excluded.observed_value_digest,
        status=case
          when public.client_administrative_anomalies.status='QUESTIONED'
            and exists(select 1 from public.client_compliance_questions question
              where question.anomaly_id=public.client_administrative_anomalies.id
                and question.status in ('OPEN','ANSWERED')) then 'QUESTIONED'
          else 'OPEN' end,
        resolved_by=null,resolved_at=null,updated_at=clock_timestamp(),
        row_version=public.client_administrative_anomalies.row_version+1
    where public.client_administrative_anomalies.status<>'ACCEPTED_EXCEPTION';
  else
    update public.client_administrative_anomalies
    set status='RESOLVED',resolved_by=p_actor,resolved_at=clock_timestamp(),
        updated_at=clock_timestamp(),row_version=row_version+1
    where compliance_case_id=p_case_id and anomaly_code=p_code
      and status not in ('RESOLVED','ACCEPTED_EXCEPTION')
      and not (status='QUESTIONED' and exists(
        select 1 from public.client_compliance_questions question
        where question.anomaly_id=public.client_administrative_anomalies.id
          and question.status in ('OPEN','ANSWERED')));
  end if;
end;
$$;
revoke all on function private.set_client_compliance_anomaly(
  uuid,uuid,text,text,boolean,text,text,uuid,text,text
) from public,anon,authenticated,service_role;

create or replace function public.evaluate_client_compliance(
  p_compliance_case_id uuid,p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer set search_path=pg_catalog,private
as $$
declare
  v_actor uuid:=auth.uid();
  v_case public.client_compliance_cases%rowtype;
  v_profile jsonb;
  v_code text;
  v_required record;
  v_observed_claims jsonb;
  v_missing boolean;
  v_open integer;
  v_hash text;
  v_existing public.idempotency_keys%rowtype;
  v_response jsonb;
  v_entered text;
  v_observed text;
  v_representative_claims jsonb;
  v_requirement_snapshot jsonb;
begin
  if v_actor is null or not private.has_platform_role(
    array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],v_actor
  ) then raise exception 'CENTRAL_COMPLIANCE_REVIEW_REQUIRED' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('client-compliance-case:'||p_compliance_case_id::text,0));
  select * into v_case from public.client_compliance_cases where id=p_compliance_case_id for update;
  if not found then raise exception 'COMPLIANCE_CASE_NOT_FOUND' using errcode='P0002'; end if;
  if length(coalesce(p_idempotency_key,'')) not between 8 and 200 then
    raise exception 'INVALID_IDEMPOTENCY_KEY' using errcode='22023';
  end if;
  select profile_data into v_profile from public.client_profile_versions
  where compliance_case_id=v_case.id and version=v_case.current_profile_version;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',requirement.id,
    'version',requirement.version,
    'document_type',requirement.document_type,
    'library_code',requirement.library_code,
    'required',requirement.required
  ) order by requirement.id::text),'[]'::jsonb) into v_requirement_snapshot
  from public.client_document_requirement_versions requirement
  where requirement.organization_kind='CLIENT'
    and (requirement.library_code is null or exists(
      select 1 from jsonb_array_elements_text(case
        when jsonb_typeof(v_profile->'library_codes')='array' then v_profile->'library_codes'
        else '[]'::jsonb end) as selected(code)
      where selected.code=requirement.library_code
    ))
    and requirement.status='ACTIVE'
    and requirement.effective_from<=clock_timestamp()
    and (requirement.effective_to is null or requirement.effective_to>clock_timestamp());
  v_hash:=private.canonical_request_hash(jsonb_build_object(
    'operation','client.compliance.evaluate.v2','case_id',p_compliance_case_id,
    'profile_version',v_case.current_profile_version,
    'requirement_versions',v_requirement_snapshot,
    'evidence_revision',(select coalesce(max(document.row_version),0)
      from public.client_compliance_documents document where document.compliance_case_id=v_case.id)
  ));
  select * into v_existing from public.idempotency_keys
  where organization_id=v_case.organization_id
    and operation_scope='client.compliance.evaluate' and key=p_idempotency_key;
  if found then
    if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if;
    if v_existing.status='COMPLETED' then return v_existing.response_body; end if;
    raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000';
  end if;
  insert into public.idempotency_keys(
    organization_id,operation_scope,key,request_hash,created_by,expires_at
  ) values(v_case.organization_id,'client.compliance.evaluate',p_idempotency_key,
    v_hash,v_actor,clock_timestamp()+interval '7 days');

  foreach v_code in array array['ICE','IF','RC'] loop
    v_missing:=not exists(select 1 from public.organization_identifiers i
      where i.organization_id=v_case.organization_id and i.identifier_type=v_code
        and i.is_active and i.verification_status='VERIFIED');
    perform private.set_client_compliance_anomaly(v_case.id,v_case.organization_id,
      v_code||'_NOT_VERIFIED','identifiers.'||lower(v_code),v_missing,
      'L’identifiant '||v_code||' doit être vérifié.',
      'يجب التحقق من المعرّف '||v_code||'.',v_actor);
  end loop;

  for v_required in
    select requirement.document_type
    from public.client_document_requirement_versions requirement
    where requirement.organization_kind='CLIENT'
      and (requirement.library_code is null or exists(
        select 1 from jsonb_array_elements_text(case
          when jsonb_typeof(v_profile->'library_codes')='array' then v_profile->'library_codes'
          else '[]'::jsonb end) as selected(code)
        where selected.code=requirement.library_code
      ))
      and requirement.required and requirement.status='ACTIVE'
      and requirement.effective_from<=clock_timestamp()
      and (requirement.effective_to is null or requirement.effective_to>clock_timestamp())
  loop
    v_missing:=not exists(
      select 1 from public.client_compliance_evidence evidence
      where evidence.compliance_case_id=v_case.id
        and evidence.evidence_type=v_required.document_type
        and evidence.review_status='VERIFIED'
        and evidence.validation_state='SCANNED_CLEAN'
        and evidence.source_document_id is not null and exists(
          select 1 from public.client_compliance_documents document
          where document.id=evidence.source_document_id and document.status='VERIFIED'
            and (document.expires_on is null or document.expires_on>=current_date)
            and document.scan_status='CLEAN' and document.current_scan_result_id is not null
            and exists(select 1 from private.client_document_scan_results scan
              where scan.id=document.current_scan_result_id and scan.result='CLEAN'
                and scan.sequence=(select max(latest.sequence)
                  from private.client_document_scan_results latest
                  where latest.document_id=document.id)
                and scan.computed_sha256=document.declared_sha256
                and scan.detected_mime_type=document.detected_mime_type
                and scan.detected_size_bytes=document.detected_size_bytes))
    );
    perform private.set_client_compliance_anomaly(v_case.id,v_case.organization_id,
      v_required.document_type||'_MISSING','documents.'||lower(v_required.document_type),v_missing,
      'Le document requis doit être validé.','يجب اعتماد الوثيقة المطلوبة.',v_actor);
  end loop;

  perform private.set_client_compliance_anomaly(v_case.id,v_case.organization_id,
    'DOCUMENT_EXPIRED','documents',exists(
      select 1
      from public.client_compliance_documents document
      join public.client_document_requirement_versions requirement
        on requirement.document_type=document.document_type
      where document.compliance_case_id=v_case.id and document.expires_on<current_date
        and document.status in ('PENDING_REVIEW','VERIFIED')
        and document.version=(select max(newer.version)
          from public.client_compliance_documents newer
          where newer.compliance_case_id=document.compliance_case_id
            and newer.document_type=document.document_type
            and newer.status<>'SUPERSEDED')
        and requirement.organization_kind='CLIENT' and requirement.required
        and requirement.status='ACTIVE' and requirement.effective_from<=clock_timestamp()
        and (requirement.effective_to is null or requirement.effective_to>clock_timestamp())
        and (requirement.library_code is null or exists(
          select 1 from jsonb_array_elements_text(case
            when jsonb_typeof(v_profile->'library_codes')='array' then v_profile->'library_codes'
            else '[]'::jsonb end) as selected(code)
          where selected.code=requirement.library_code))) ,
    'Un document obligatoire est expiré.','إحدى الوثائق الإلزامية منتهية الصلاحية.',v_actor);
  perform private.set_client_compliance_anomaly(v_case.id,v_case.organization_id,
    'DOCUMENT_UNREADABLE','documents',exists(
      select 1
      from public.client_compliance_documents document
      join public.client_document_requirement_versions requirement
        on requirement.document_type=document.document_type
      where document.compliance_case_id=v_case.id and document.scan_status='ERROR'
        and document.status='PENDING_REVIEW'
        and document.version=(select max(newer.version)
          from public.client_compliance_documents newer
          where newer.compliance_case_id=document.compliance_case_id
            and newer.document_type=document.document_type
            and newer.status<>'SUPERSEDED')
        and requirement.organization_kind='CLIENT' and requirement.required
        and requirement.status='ACTIVE' and requirement.effective_from<=clock_timestamp()
        and (requirement.effective_to is null or requirement.effective_to>clock_timestamp())
        and (requirement.library_code is null or exists(
          select 1 from jsonb_array_elements_text(case
            when jsonb_typeof(v_profile->'library_codes')='array' then v_profile->'library_codes'
            else '[]'::jsonb end) as selected(code)
          where selected.code=requirement.library_code))),
    'Un document ne peut pas être lu et doit être remplacé.','تعذر قراءة إحدى الوثائق ويجب استبدالها.',v_actor);

  select scan.observed_claims into v_observed_claims
  from private.client_document_scan_results scan
  join public.client_compliance_documents document
    on document.id=scan.document_id and document.current_scan_result_id=scan.id
  join public.client_document_requirement_versions requirement
    on requirement.document_type=document.document_type
  where document.compliance_case_id=v_case.id and scan.result='CLEAN'
    and document.scan_status='CLEAN' and document.status in ('PENDING_REVIEW','VERIFIED')
    and scan.sequence=(select max(latest.sequence)
      from private.client_document_scan_results latest
      where latest.document_id=document.id)
    and scan.computed_sha256=document.declared_sha256
    and scan.detected_mime_type=document.detected_mime_type
    and scan.detected_size_bytes=document.detected_size_bytes
    and scan.observed_claims<>'{}'::jsonb
    and document.version=(select max(newer.version)
      from public.client_compliance_documents newer
      where newer.compliance_case_id=document.compliance_case_id
        and newer.document_type=document.document_type and newer.status<>'SUPERSEDED')
    and requirement.organization_kind='CLIENT' and requirement.required
    and requirement.status='ACTIVE' and requirement.effective_from<=clock_timestamp()
    and (requirement.effective_to is null or requirement.effective_to>clock_timestamp())
    and (requirement.library_code is null or exists(
      select 1 from jsonb_array_elements_text(case
        when jsonb_typeof(v_profile->'library_codes')='array' then v_profile->'library_codes'
        else '[]'::jsonb end) as selected(code)
      where selected.code=requirement.library_code))
    and requirement.document_type='REGISTRATION_DOCUMENT'
  order by document.version desc,scan.recorded_at desc limit 1;
  if found then
    if v_observed_claims ? 'legal_name' then
      v_entered:=lower(btrim((select legal_name from public.organizations where id=v_case.organization_id)));
      v_observed:=lower(btrim(v_observed_claims->>'legal_name'));
      perform private.set_client_compliance_anomaly(v_case.id,v_case.organization_id,
        'LEGAL_NAME_MISMATCH','legal_name',v_observed<>'' and v_entered<>v_observed,
        'La raison sociale diffère du document.','الاسم القانوني مختلف عن الوثيقة.',v_actor,
        private.canonical_request_hash(to_jsonb(v_entered)),private.canonical_request_hash(to_jsonb(v_observed)));
    end if;
    if v_observed_claims ? 'legal_form' then
      v_entered:=lower(btrim(v_profile->>'legal_form'));
      v_observed:=lower(btrim(v_observed_claims->>'legal_form'));
      perform private.set_client_compliance_anomaly(v_case.id,v_case.organization_id,
        'LEGAL_FORM_MISMATCH','legal_form',v_observed<>'' and v_entered<>v_observed,
        'La forme juridique diffère du document.','الشكل القانوني مختلف عن الوثيقة.',v_actor,
        private.canonical_request_hash(to_jsonb(v_entered)),private.canonical_request_hash(to_jsonb(v_observed)));
    end if;
    if v_observed_claims ? 'registered_address' then
      perform private.set_client_compliance_anomaly(v_case.id,v_case.organization_id,
        'ADDRESS_MISMATCH','registered_address',private.canonical_request_hash(v_profile->'registered_address')<>
          private.canonical_request_hash(v_observed_claims->'registered_address'),
        'L’adresse diffère du document.','العنوان مختلف عن الوثيقة.',v_actor,
        private.canonical_request_hash(v_profile->'registered_address'),
        private.canonical_request_hash(v_observed_claims->'registered_address'));
    end if;
  end if;

  select scan.observed_claims into v_representative_claims
  from private.client_document_scan_results scan
  join public.client_compliance_documents document
    on document.id=scan.document_id and document.current_scan_result_id=scan.id
  join public.client_document_requirement_versions requirement
    on requirement.document_type=document.document_type
  where document.compliance_case_id=v_case.id and scan.result='CLEAN'
    and document.scan_status='CLEAN' and document.status in ('PENDING_REVIEW','VERIFIED')
    and scan.sequence=(select max(latest.sequence)
      from private.client_document_scan_results latest
      where latest.document_id=document.id)
    and scan.computed_sha256=document.declared_sha256
    and scan.detected_mime_type=document.detected_mime_type
    and scan.detected_size_bytes=document.detected_size_bytes
    and scan.observed_claims ? 'representative'
    and document.version=(select max(newer.version)
      from public.client_compliance_documents newer
      where newer.compliance_case_id=document.compliance_case_id
        and newer.document_type=document.document_type and newer.status<>'SUPERSEDED')
    and requirement.organization_kind='CLIENT' and requirement.required
    and requirement.status='ACTIVE' and requirement.effective_from<=clock_timestamp()
    and (requirement.effective_to is null or requirement.effective_to>clock_timestamp())
    and (requirement.library_code is null or exists(
      select 1 from jsonb_array_elements_text(case
        when jsonb_typeof(v_profile->'library_codes')='array' then v_profile->'library_codes'
        else '[]'::jsonb end) as selected(code)
      where selected.code=requirement.library_code))
  order by (document.document_type='REPRESENTATIVE_AUTHORITY') desc,
    document.version desc,scan.recorded_at desc limit 1;
  if found then
    perform private.set_client_compliance_anomaly(v_case.id,v_case.organization_id,
      'REPRESENTATIVE_MISMATCH','representative',private.canonical_request_hash(v_profile->'representative')<>
        private.canonical_request_hash(v_representative_claims->'representative'),
      'Le représentant diffère du document.','بيانات الممثل مختلفة عن الوثيقة.',v_actor,
      private.canonical_request_hash(v_profile->'representative'),
      private.canonical_request_hash(v_representative_claims->'representative'));
  end if;

  select count(*) into v_open from public.client_administrative_anomalies
  where compliance_case_id=v_case.id and blocking and status in ('OPEN','QUESTIONED');
  if v_case.status in ('PROFILE_IN_PROGRESS','DOCUMENTS_REQUIRED') then
    update public.client_compliance_cases set status=case when v_open>0 then 'DOCUMENTS_REQUIRED'
      else 'PROFILE_IN_PROGRESS' end where id=v_case.id;
  end if;
  v_response:=jsonb_build_object('outcome','CLIENT_COMPLIANCE_EVALUATED',
    'compliance_case_id',v_case.id,'blocking_anomalies',v_open);
  insert into public.audit_events(
    organization_id,actor_user_id,actor_type,action,resource_type,resource_id,
    correlation_id,metadata,previous_hash,event_hash
  ) values(v_case.organization_id,v_actor,'USER','client.compliance.evaluated',
    'client_compliance_case',v_case.id::text,p_correlation_id,
    jsonb_build_object('blocking_anomalies',v_open,
      'requirement_versions',v_requirement_snapshot),null,repeat('0',64));
  insert into public.event_outbox(
    organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload
  ) values(v_case.organization_id,'client_compliance_case',v_case.id::text,
    'ClientComplianceEvaluatedV1',p_correlation_id,
    jsonb_build_object('compliance_case_id',v_case.id,'blocking_anomalies',v_open,
      'requirement_versions',v_requirement_snapshot));
  update public.idempotency_keys set status='COMPLETED',response_code=200,
    response_body=v_response,completed_at=clock_timestamp()
  where organization_id=v_case.organization_id
    and operation_scope='client.compliance.evaluate' and key=p_idempotency_key;
  return v_response;
end;
$$;

create or replace function private.require_client_documents_for_review()
returns trigger language plpgsql security definer set search_path=pg_catalog
as $$
declare v_required record;
begin
  if new.status='UNDER_REVIEW'
     and old.status in ('PROFILE_IN_PROGRESS','DOCUMENTS_REQUIRED') then
    for v_required in
      select requirement.document_type
      from public.client_document_requirement_versions requirement
      where requirement.organization_kind='CLIENT'
        and (requirement.library_code is null or exists(
          select 1
          from public.client_profile_versions profile,
            lateral jsonb_array_elements_text(case
              when jsonb_typeof(profile.profile_data->'library_codes')='array'
                then profile.profile_data->'library_codes' else '[]'::jsonb end) as selected(code)
          where profile.compliance_case_id=new.id
            and profile.version=new.current_profile_version
            and selected.code=requirement.library_code
        ))
        and requirement.required and requirement.status='ACTIVE'
        and requirement.effective_from<=clock_timestamp()
        and (requirement.effective_to is null or requirement.effective_to>clock_timestamp())
    loop
      if not exists(select 1 from public.client_compliance_documents document
        where document.compliance_case_id=new.id
          and document.document_type=v_required.document_type
          and document.status in ('PENDING_REVIEW','VERIFIED')
          and (document.expires_on is null or document.expires_on>=current_date))
      and not exists(select 1 from public.client_compliance_evidence evidence
        where evidence.compliance_case_id=new.id
          and evidence.evidence_type=v_required.document_type
          and evidence.review_status='VERIFIED' and evidence.source_document_id is null) then
        raise exception 'REQUIRED_CLIENT_DOCUMENTS_MISSING' using errcode='55000';
      end if;
    end loop;
  end if;
  return new;
end;
$$;

create or replace function private.require_verified_client_compliance()
returns trigger language plpgsql security definer set search_path=pg_catalog
as $$
declare v_required record;
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
    for v_required in select requirement.document_type
      from public.client_document_requirement_versions requirement
      where requirement.organization_kind='CLIENT'
        and (requirement.library_code is null or exists(
          select 1
          from public.client_profile_versions profile,
            lateral jsonb_array_elements_text(case
              when jsonb_typeof(profile.profile_data->'library_codes')='array'
                then profile.profile_data->'library_codes' else '[]'::jsonb end) as selected(code)
          where profile.compliance_case_id=new.id
            and profile.version=new.current_profile_version
            and selected.code=requirement.library_code
        ))
        and requirement.required and requirement.status='ACTIVE'
        and requirement.effective_from<=clock_timestamp()
        and (requirement.effective_to is null or requirement.effective_to>clock_timestamp())
    loop
      if not exists(select 1 from public.client_compliance_evidence evidence
        where evidence.compliance_case_id=new.id
          and evidence.evidence_type=v_required.document_type
          and evidence.review_status='VERIFIED'
          and evidence.validation_state='SCANNED_CLEAN'
          and evidence.source_document_id is not null and exists(
            select 1 from public.client_compliance_documents document
            where document.id=evidence.source_document_id and document.status='VERIFIED'
              and (document.expires_on is null or document.expires_on>=current_date)
              and document.scan_status='CLEAN' and document.current_scan_result_id is not null
              and exists(select 1 from private.client_document_scan_results scan
                where scan.id=document.current_scan_result_id and scan.result='CLEAN'
                  and scan.sequence=(select max(latest.sequence)
                    from private.client_document_scan_results latest
                    where latest.document_id=document.id)
                  and scan.computed_sha256=document.declared_sha256
                  and scan.detected_mime_type=document.detected_mime_type
                  and scan.detected_size_bytes=document.detected_size_bytes))) then
        raise exception 'VERIFIED_COMPLIANCE_EVIDENCE_REQUIRED' using errcode='55000';
      end if;
    end loop;
  end if;
  return new;
end;
$$;

revoke all on function public.evaluate_client_compliance(uuid,text,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.evaluate_client_compliance(uuid,text,uuid) to authenticated;
revoke all on function private.require_client_documents_for_review(),
  private.require_verified_client_compliance()
  from public,anon,authenticated,service_role;

notify pgrst,'reload schema';
