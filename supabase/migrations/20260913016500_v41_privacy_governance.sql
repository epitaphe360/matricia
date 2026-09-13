-- V4.1 P0 privacy governance / CNDP / Moroccan Law 09-08.
-- Additive only. Pseudonymous subject references are stored as SHA-256 digests;
-- audit and outbox evidence intentionally excludes those digests and all PII.

create function private.privacy_read_access(p_org uuid,p_actor uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=pg_catalog,private as $$
  select p_actor is not null and (
    private.has_org_role(p_org,array['CLIENT_OWNER','CLIENT_ADMIN','PROVIDER_OWNER','PROVIDER_MANAGER','FRANCHISE_OWNER','FRANCHISE_MANAGER'],p_actor)
    or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR'],p_actor)
  )
$$;

create function private.privacy_manage_access(p_org uuid,p_actor uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=pg_catalog,private as $$
  select p_actor is not null and (
    private.has_org_role(p_org,array['CLIENT_OWNER','CLIENT_ADMIN','PROVIDER_OWNER','PROVIDER_MANAGER','FRANCHISE_OWNER','FRANCHISE_MANAGER'],p_actor)
    or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],p_actor)
  )
$$;

create table public.processing_activities(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  activity_key text not null check(activity_key~'^[a-z][a-z0-9-]{2,99}$'),
  name_fr text not null check(length(btrim(name_fr)) between 2 and 300),
  name_ar text not null check(length(btrim(name_ar)) between 2 and 300),
  controller_role text not null check(controller_role in('CONTROLLER','JOINT_CONTROLLER','PROCESSOR')),
  data_subject_types text[] not null default '{}',
  systems text[] not null check(cardinality(systems)>0),
  countries_regions text[] not null check(cardinality(countries_regions)>0),
  cndp_formality_status text not null check(cndp_formality_status in('NOT_REQUIRED','TO_ASSESS','REQUIRED_NOT_COMPLETED','SUBMITTED','COMPLETED','REJECTED')),
  cndp_reference text,
  cndp_completed_at timestamptz,
  status text not null default 'DRAFT' check(status in('DRAFT','ACTIVE','SUSPENDED','RETIRED')),
  effective_from date,
  effective_until date,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check(row_version>0),
  unique(organization_id,activity_key),
  check(effective_until is null or effective_from is not null and effective_until>=effective_from),
  check((cndp_formality_status='COMPLETED')=(cndp_reference is not null and cndp_completed_at is not null))
);

create table public.processing_purposes(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  processing_activity_id uuid not null references public.processing_activities(id) on delete restrict,
  purpose_key text not null check(purpose_key~'^[a-z][a-z0-9-]{2,99}$'),
  label_fr text not null,
  label_ar text not null,
  legal_basis text not null check(legal_basis in('CONSENT','CONTRACT','LEGAL_OBLIGATION','VITAL_INTEREST','PUBLIC_INTEREST','LEGITIMATE_INTEREST')),
  legal_basis_reference text not null,
  is_marketing boolean not null default false,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique(processing_activity_id,purpose_key)
);

create table public.data_categories(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  processing_activity_id uuid not null references public.processing_activities(id) on delete restrict,
  category_key text not null check(category_key~'^[a-z][a-z0-9-]{2,99}$'),
  label_fr text not null,
  label_ar text not null,
  data_subject_types text[] not null check(cardinality(data_subject_types)>0),
  sensitivity text not null check(sensitivity in('PUBLIC','INTERNAL','PERSONAL','SENSITIVE','HIGHLY_RESTRICTED')),
  minimization_rationale text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique(processing_activity_id,category_key)
);

create table public.data_recipients(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  processing_activity_id uuid not null references public.processing_activities(id) on delete restrict,
  recipient_name text not null,
  recipient_type text not null check(recipient_type in('INTERNAL_ROLE','PROCESSOR','SUBPROCESSOR','PUBLIC_AUTHORITY','OTHER')),
  country_region text not null,
  data_category_keys text[] not null check(cardinality(data_category_keys)>0),
  disclosure_basis text not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp()
);

create table public.processors(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  provider_key text not null check(provider_key~'^[a-z][a-z0-9-]{2,99}$'),
  legal_name text not null,
  services text[] not null check(cardinality(services)>0),
  processing_regions text[] not null check(cardinality(processing_regions)>0),
  dpa_status text not null check(dpa_status in('NOT_REQUIRED','REQUIRED_NOT_COMPLETED','IN_REVIEW','SIGNED','EXPIRED')),
  dpa_reference text,
  contract_reference text,
  security_review_status text not null check(security_review_status in('NOT_STARTED','IN_REVIEW','APPROVED','REJECTED','EXPIRED')),
  status text not null default 'ACTIVE' check(status in('PROPOSED','ACTIVE','SUSPENDED','EXITED')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique(organization_id,provider_key),
  check(dpa_status<>'SIGNED' or dpa_reference is not null)
);

create table public.subprocessor_register(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  processor_id uuid not null references public.processors(id) on delete restrict,
  legal_name text not null,
  service_purpose text not null,
  countries_regions text[] not null check(cardinality(countries_regions)>0),
  data_category_keys text[] not null check(cardinality(data_category_keys)>0),
  authorization_status text not null check(authorization_status in('PROPOSED','NOTICE_SENT','APPROVED','OBJECTED','REMOVED')),
  effective_from date,
  effective_until date,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  check(effective_until is null or effective_from is not null and effective_until>=effective_from)
);

create table public.international_transfers(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  processing_activity_id uuid not null references public.processing_activities(id) on delete restrict,
  processor_id uuid references public.processors(id) on delete restrict,
  provider_name text not null,
  destination_country text not null check(destination_country~'^[A-Z]{2}$'),
  destination_region text,
  transfer_mechanism text not null check(transfer_mechanism in('ADEQUACY','CONTRACTUAL_SAFEGUARDS','EXPLICIT_CONSENT','LEGAL_EXCEPTION','LOCAL_ONLY')),
  compliance_status text not null check(compliance_status in('TO_ASSESS','REQUIRED_NOT_COMPLETED','IN_REVIEW','APPROVED','BLOCKED','EXPIRED')),
  assessment_reference text,
  approved_at timestamptz,
  expires_at timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  check(compliance_status<>'APPROVED' or assessment_reference is not null or transfer_mechanism='LOCAL_ONLY')
);

create table public.retention_policies(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  data_category_id uuid not null references public.data_categories(id) on delete restrict,
  version integer not null check(version>0),
  status text not null check(status in('DRAFT','ACTIVE','RETIRED')),
  retention_days integer not null check(retention_days between 0 and 36500),
  trigger_event text not null,
  disposition text not null check(disposition in('ANONYMIZE','PURGE','LEGAL_ARCHIVE')),
  legal_basis_reference text not null,
  effective_from date not null,
  effective_until date,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique(data_category_id,version),
  check(effective_until is null or effective_until>=effective_from)
);

create table public.privacy_notices(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  notice_key text not null,
  version integer not null check(version>0),
  locale text not null check(locale in('fr-MA','ar-MA')),
  content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),
  storage_reference text not null check(storage_reference!~'\.\.'),
  status text not null check(status in('DRAFT','PUBLISHED','RETIRED')),
  published_at timestamptz,
  effective_from timestamptz not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique(organization_id,notice_key,version,locale),
  check(status<>'PUBLISHED' or published_at is not null)
);

create table public.consent_records(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  processing_purpose_id uuid not null references public.processing_purposes(id) on delete restrict,
  privacy_notice_id uuid not null references public.privacy_notices(id) on delete restrict,
  subject_reference_hash text not null check(subject_reference_hash~'^[0-9a-f]{64}$'),
  status text not null check(status in('GRANTED','DENIED','WITHDRAWN','EXPIRED')),
  channel text not null check(channel in('WEB','MOBILE','EMAIL','PAPER','ADMIN_IMPORT')),
  legal_basis_reference text not null,
  proof_hash text not null check(proof_hash~'^[0-9a-f]{64}$'),
  occurred_at timestamptz not null,
  correlation_id uuid not null,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique(organization_id,correlation_id)
);

create table public.data_subject_requests(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  request_type text not null check(request_type in('ACCESS','RECTIFICATION','OPPOSITION','ERASURE','RESTRICTION','PORTABILITY','CONSENT_WITHDRAWAL','OTHER')),
  subject_reference_hash text not null check(subject_reference_hash~'^[0-9a-f]{64}$'),
  identity_verification_level text not null check(identity_verification_level in('STANDARD','ENHANCED','IN_PERSON')),
  locale text not null check(locale in('fr-MA','ar-MA')),
  status text not null default 'RECEIVED' check(status in('RECEIVED','IDENTITY_PENDING','IDENTITY_VERIFIED','IN_REVIEW','FULFILLED','REJECTED','COMPLETED','CANCELLED')),
  due_at timestamptz not null,
  verified_at timestamptz,
  fulfilled_at timestamptz,
  export_storage_reference text check(export_storage_reference is null or export_storage_reference!~'\.\.'),
  decision_reason_code text,
  correlation_id uuid not null,
  assigned_to uuid references auth.users(id),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check(row_version>0),
  unique(organization_id,correlation_id)
);

create table public.privacy_incidents(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  incident_reference text not null,
  detected_at timestamptz not null,
  severity text not null check(severity in('LOW','MEDIUM','HIGH','CRITICAL')),
  status text not null check(status in('OPEN','CONTAINED','ASSESSING_NOTIFICATION','NOTIFIED','CLOSED')),
  categories_impacted text[] not null check(cardinality(categories_impacted)>0),
  approximate_subject_count bigint check(approximate_subject_count is null or approximate_subject_count>=0),
  cndp_notification_status text not null check(cndp_notification_status in('NOT_ASSESSED','NOT_REQUIRED','REQUIRED','SUBMITTED','ACKNOWLEDGED')),
  evidence_reference text not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique(organization_id,incident_reference)
);

create table public.privacy_legal_holds(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  subject_reference_hash text not null check(subject_reference_hash~'^[0-9a-f]{64}$'),
  reason_code text not null,
  status text not null check(status in('ACTIVE','RELEASED','EXPIRED')),
  starts_at timestamptz not null,
  ends_at timestamptz,
  evidence_reference text,
  created_by uuid not null references auth.users(id),
  released_by uuid references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  check(ends_at is null or ends_at>starts_at)
);

create table public.privacy_retention_actions(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  retention_policy_id uuid not null references public.retention_policies(id) on delete restrict,
  subject_reference_hash text not null check(subject_reference_hash~'^[0-9a-f]{64}$'),
  action_type text not null check(action_type in('ANONYMIZE','PURGE','LEGAL_ARCHIVE')),
  status text not null default 'PENDING' check(status in('PENDING','RUNNING','COMPLETED','FAILED','BLOCKED_LEGAL_HOLD')),
  idempotency_key text not null check(length(idempotency_key) between 8 and 200),
  correlation_id uuid not null,
  requested_by uuid not null references auth.users(id),
  requested_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  result_summary jsonb not null default '{}' check(jsonb_typeof(result_summary)='object'),
  unique(organization_id,idempotency_key)
);

create table public.privacy_cookie_policies(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  tracker_key text not null,
  version integer not null check(version>0),
  category text not null check(category in('NECESSARY','PREFERENCES','ANALYTICS','MARKETING')),
  provider_name text not null,
  purpose_fr text not null,
  purpose_ar text not null,
  lifetime_seconds bigint not null check(lifetime_seconds>=0),
  requires_consent boolean not null,
  status text not null check(status in('DRAFT','ACTIVE','RETIRED')),
  effective_from timestamptz not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique(organization_id,tracker_key,version),
  check(category='NECESSARY' or requires_consent)
);

create function private.enforce_privacy_tenant_scope() returns trigger
language plpgsql set search_path=pg_catalog,public as $$
declare expected_org uuid; notice_org uuid;
begin
  case tg_table_name
    when 'processing_purposes','data_categories','data_recipients' then
      select organization_id into expected_org from public.processing_activities where id=new.processing_activity_id;
    when 'subprocessor_register' then select organization_id into expected_org from public.processors where id=new.processor_id;
    when 'international_transfers' then
      select organization_id into expected_org from public.processing_activities where id=new.processing_activity_id;
      if new.processor_id is not null and not exists(select 1 from public.processors where id=new.processor_id and organization_id=expected_org) then raise exception 'PRIVACY_CROSS_TENANT_REFERENCE' using errcode='42501'; end if;
    when 'retention_policies' then select organization_id into expected_org from public.data_categories where id=new.data_category_id;
    when 'consent_records' then
      select a.organization_id into expected_org from public.processing_purposes p join public.processing_activities a on a.id=p.processing_activity_id where p.id=new.processing_purpose_id;
      select organization_id into notice_org from public.privacy_notices where id=new.privacy_notice_id;
      if notice_org is null or notice_org<>expected_org then raise exception 'PRIVACY_CROSS_TENANT_REFERENCE' using errcode='42501'; end if;
    when 'privacy_retention_actions' then select organization_id into expected_org from public.retention_policies where id=new.retention_policy_id;
    else raise exception 'UNSUPPORTED_PRIVACY_TENANT_TABLE' using errcode='55000';
  end case;
  if expected_org is null or expected_org<>new.organization_id then raise exception 'PRIVACY_CROSS_TENANT_REFERENCE' using errcode='42501'; end if;
  return new;
end$$;

do $$declare t text;begin
  foreach t in array array['processing_purposes','data_categories','data_recipients','subprocessor_register','international_transfers','retention_policies','consent_records','privacy_retention_actions'] loop
    execute format('create trigger %I before insert or update on public.%I for each row execute function private.enforce_privacy_tenant_scope()',t||'_tenant_scope',t);
  end loop;
end$$;

create function private.prevent_privacy_history_change() returns trigger language plpgsql set search_path=pg_catalog as $$begin raise exception 'PRIVACY_HISTORY_IMMUTABLE' using errcode='55000'; end$$;
create trigger privacy_notices_immutable before update or delete on public.privacy_notices for each row execute function private.prevent_privacy_history_change();
create trigger consent_records_immutable before update or delete on public.consent_records for each row execute function private.prevent_privacy_history_change();
create trigger retention_policies_immutable before update or delete on public.retention_policies for each row execute function private.prevent_privacy_history_change();
create trigger retention_actions_no_delete before delete on public.privacy_retention_actions for each row execute function private.prevent_privacy_history_change();

create function public.assert_privacy_production_ready(p_organization_id uuid) returns boolean
language plpgsql stable security definer set search_path=pg_catalog,public,private as $$
begin
  if not private.privacy_manage_access(p_organization_id) then raise exception 'PRIVACY_PRODUCTION_GATE_DENIED' using errcode='42501'; end if;
  if exists(select 1 from public.processing_activities where organization_id=p_organization_id and status<>'RETIRED' and cndp_formality_status in('TO_ASSESS','REQUIRED_NOT_COMPLETED','REJECTED'))
    or exists(select 1 from public.international_transfers where organization_id=p_organization_id and compliance_status in('TO_ASSESS','REQUIRED_NOT_COMPLETED','BLOCKED','EXPIRED'))
    or exists(select 1 from public.processors where organization_id=p_organization_id and status='ACTIVE' and (dpa_status in('REQUIRED_NOT_COMPLETED','EXPIRED') or security_review_status in('NOT_STARTED','REJECTED','EXPIRED'))) then
    raise exception 'PRIVACY_PRODUCTION_GATE_BLOCKED' using errcode='55000';
  end if;
  return true;
end$$;

create function public.register_data_subject_request(p_organization_id uuid,p_request_type text,p_subject_reference_hash text,p_verification_level text,p_locale text,p_sla_days integer,p_correlation_id uuid) returns uuid
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare v_actor uuid:=auth.uid(); v_id uuid; v_now timestamptz:=clock_timestamp();
begin
  if not private.privacy_manage_access(p_organization_id,v_actor) then raise exception 'PRIVACY_DSR_REGISTER_DENIED' using errcode='42501'; end if;
  if p_subject_reference_hash!~'^[0-9a-f]{64}$' or p_sla_days not between 1 and 365 or p_correlation_id is null then raise exception 'INVALID_PRIVACY_DSR_REQUEST' using errcode='22023'; end if;
  select id into v_id from public.data_subject_requests where organization_id=p_organization_id and correlation_id=p_correlation_id;
  if v_id is not null then return v_id; end if;
  insert into public.data_subject_requests(organization_id,request_type,subject_reference_hash,identity_verification_level,locale,due_at,correlation_id,created_by)
  values(p_organization_id,p_request_type,p_subject_reference_hash,p_verification_level,p_locale,v_now+make_interval(days=>p_sla_days),p_correlation_id,v_actor) returning id into v_id;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
  values(p_organization_id,v_actor,'USER','privacy.dsr.registered','data_subject_request',v_id::text,p_correlation_id,jsonb_build_object('request_type',p_request_type,'verification_level',p_verification_level,'sla_days',p_sla_days),null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)
  values(p_organization_id,'data_subject_request',v_id::text,'PrivacyDataSubjectRequestRegisteredV1',p_correlation_id,jsonb_build_object('request_id',v_id,'request_type',p_request_type,'due_at',v_now+make_interval(days=>p_sla_days)));
  return v_id;
end$$;

create function public.transition_data_subject_request(p_request_id uuid,p_expected_version integer,p_new_status text,p_decision_reason_code text,p_export_storage_reference text,p_correlation_id uuid) returns integer
language plpgsql security definer set search_path=pg_catalog,public,private as $$
declare v_actor uuid:=auth.uid(); v_row public.data_subject_requests%rowtype; v_next integer;
begin
  select * into v_row from public.data_subject_requests where id=p_request_id for update;
  if v_row.id is null or not private.privacy_manage_access(v_row.organization_id,v_actor) then raise exception 'PRIVACY_DSR_TRANSITION_DENIED' using errcode='42501'; end if;
  if v_row.row_version<>p_expected_version then raise exception 'PRIVACY_DSR_VERSION_CONFLICT' using errcode='40001'; end if;
  if not ((v_row.status='RECEIVED' and p_new_status in('IDENTITY_PENDING','IDENTITY_VERIFIED','CANCELLED')) or (v_row.status='IDENTITY_PENDING' and p_new_status in('IDENTITY_VERIFIED','REJECTED','CANCELLED')) or (v_row.status='IDENTITY_VERIFIED' and p_new_status='IN_REVIEW') or (v_row.status='IN_REVIEW' and p_new_status in('FULFILLED','REJECTED')) or (v_row.status in('FULFILLED','REJECTED') and p_new_status='COMPLETED')) then raise exception 'INVALID_PRIVACY_DSR_TRANSITION' using errcode='22023'; end if;
  update public.data_subject_requests set status=p_new_status,decision_reason_code=p_decision_reason_code,export_storage_reference=p_export_storage_reference,verified_at=case when p_new_status='IDENTITY_VERIFIED' then clock_timestamp() else verified_at end,fulfilled_at=case when p_new_status='FULFILLED' then clock_timestamp() else fulfilled_at end,updated_at=clock_timestamp(),row_version=row_version+1 where id=p_request_id returning row_version into v_next;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_row.organization_id,v_actor,'USER','privacy.dsr.transitioned','data_subject_request',p_request_id::text,p_correlation_id,jsonb_build_object('from_status',v_row.status,'to_status',p_new_status,'has_export',p_export_storage_reference is not null),null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values(v_row.organization_id,'data_subject_request',p_request_id::text,'PrivacyDataSubjectRequestTransitionedV1',p_correlation_id,jsonb_build_object('request_id',p_request_id,'from_status',v_row.status,'to_status',p_new_status));
  return v_next;
end$$;

create function public.request_privacy_retention_action(p_policy_id uuid,p_subject_reference_hash text,p_action_type text,p_idempotency_key text,p_correlation_id uuid) returns uuid
language plpgsql security definer set search_path=pg_catalog,public,private as $$
declare v_actor uuid:=auth.uid(); v_policy public.retention_policies%rowtype; v_id uuid;
begin
  select * into v_policy from public.retention_policies where id=p_policy_id and status='ACTIVE';
  if v_policy.id is null or not private.privacy_manage_access(v_policy.organization_id,v_actor) then raise exception 'PRIVACY_RETENTION_ACTION_DENIED' using errcode='42501'; end if;
  if p_subject_reference_hash!~'^[0-9a-f]{64}$' or p_action_type<>v_policy.disposition then raise exception 'INVALID_PRIVACY_RETENTION_ACTION' using errcode='22023'; end if;
  if exists(select 1 from public.privacy_legal_holds where organization_id=v_policy.organization_id and subject_reference_hash=p_subject_reference_hash and status='ACTIVE' and (ends_at is null or ends_at>clock_timestamp())) then raise exception 'PRIVACY_LEGAL_HOLD_ACTIVE' using errcode='55000'; end if;
  select id into v_id from public.privacy_retention_actions where organization_id=v_policy.organization_id and idempotency_key=p_idempotency_key;
  if v_id is not null then return v_id; end if;
  insert into public.privacy_retention_actions(organization_id,retention_policy_id,subject_reference_hash,action_type,idempotency_key,correlation_id,requested_by) values(v_policy.organization_id,p_policy_id,p_subject_reference_hash,p_action_type,p_idempotency_key,p_correlation_id,v_actor) returning id into v_id;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_policy.organization_id,v_actor,'USER','privacy.retention.requested','privacy_retention_action',v_id::text,p_correlation_id,jsonb_build_object('policy_id',p_policy_id,'action_type',p_action_type),null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values(v_policy.organization_id,'privacy_retention_action',v_id::text,'PrivacyRetentionActionRequestedV1',p_correlation_id,jsonb_build_object('action_id',v_id,'policy_id',p_policy_id,'action_type',p_action_type));
  return v_id;
end$$;

create function public.record_privacy_consent(p_organization_id uuid,p_purpose_id uuid,p_notice_id uuid,p_subject_reference_hash text,p_status text,p_channel text,p_legal_basis_reference text,p_proof_hash text,p_occurred_at timestamptz,p_correlation_id uuid) returns uuid
language plpgsql security definer set search_path=pg_catalog,public,private as $$
declare v_actor uuid:=auth.uid(); v_id uuid;
begin
  if not private.privacy_manage_access(p_organization_id,v_actor) then raise exception 'PRIVACY_CONSENT_RECORD_DENIED' using errcode='42501'; end if;
  if p_status not in('GRANTED','DENIED','WITHDRAWN','EXPIRED') or p_subject_reference_hash!~'^[0-9a-f]{64}$' or p_proof_hash!~'^[0-9a-f]{64}$' then raise exception 'INVALID_PRIVACY_CONSENT_RECORD' using errcode='22023'; end if;
  select id into v_id from public.consent_records where organization_id=p_organization_id and correlation_id=p_correlation_id;
  if v_id is not null then return v_id; end if;
  insert into public.consent_records(organization_id,processing_purpose_id,privacy_notice_id,subject_reference_hash,status,channel,legal_basis_reference,proof_hash,occurred_at,correlation_id,created_by) values(p_organization_id,p_purpose_id,p_notice_id,p_subject_reference_hash,p_status,p_channel,p_legal_basis_reference,p_proof_hash,p_occurred_at,p_correlation_id,v_actor) returning id into v_id;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(p_organization_id,v_actor,'USER','privacy.consent.recorded','consent_record',v_id::text,p_correlation_id,jsonb_build_object('purpose_id',p_purpose_id,'status',p_status,'channel',p_channel),null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values(p_organization_id,'consent_record',v_id::text,'PrivacyConsentRecordedV1',p_correlation_id,jsonb_build_object('consent_id',v_id,'purpose_id',p_purpose_id,'status',p_status));
  return v_id;
end$$;

do $$declare t text;begin
  foreach t in array array['processing_activities','processing_purposes','data_categories','data_recipients','processors','subprocessor_register','international_transfers','retention_policies','privacy_notices','consent_records','data_subject_requests','privacy_incidents','privacy_legal_holds','privacy_retention_actions','privacy_cookie_policies'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
    execute format('create policy %I on public.%I for select to authenticated using (private.privacy_read_access(organization_id))',t||'_scoped_read',t);
    execute format('grant select on public.%I to authenticated',t);
  end loop;
end$$;

create index v41_privacy_activities_org_status on public.processing_activities(organization_id,status,cndp_formality_status);
create index v41_privacy_purposes_activity on public.processing_purposes(organization_id,processing_activity_id,is_marketing);
create index v41_privacy_categories_activity on public.data_categories(organization_id,processing_activity_id,sensitivity);
create index v41_privacy_recipients_activity on public.data_recipients(organization_id,processing_activity_id);
create index v41_privacy_processors_org_status on public.processors(organization_id,status,dpa_status,security_review_status);
create index v41_privacy_subprocessors_processor on public.subprocessor_register(organization_id,processor_id,authorization_status);
create index v41_privacy_transfers_gate on public.international_transfers(organization_id,compliance_status,expires_at);
create index v41_privacy_retention_active on public.retention_policies(organization_id,data_category_id,status,effective_from desc);
create index v41_privacy_notices_active on public.privacy_notices(organization_id,notice_key,locale,status,effective_from desc);
create index v41_privacy_consents_subject on public.consent_records(organization_id,subject_reference_hash,processing_purpose_id,occurred_at desc);
create index v41_privacy_dsr_queue on public.data_subject_requests(organization_id,status,due_at);
create index v41_privacy_incidents_queue on public.privacy_incidents(organization_id,status,severity,detected_at desc);
create index v41_privacy_holds_subject on public.privacy_legal_holds(organization_id,subject_reference_hash,status,ends_at);
create index v41_privacy_retention_queue on public.privacy_retention_actions(organization_id,status,requested_at);
create index v41_privacy_cookie_active on public.privacy_cookie_policies(organization_id,category,status,effective_from desc);

revoke all on function private.privacy_read_access(uuid,uuid),private.privacy_manage_access(uuid,uuid),private.enforce_privacy_tenant_scope(),private.prevent_privacy_history_change() from public,anon,authenticated,service_role;
revoke all on function public.assert_privacy_production_ready(uuid),public.register_data_subject_request(uuid,text,text,text,text,integer,uuid),public.transition_data_subject_request(uuid,integer,text,text,text,uuid),public.request_privacy_retention_action(uuid,text,text,text,uuid),public.record_privacy_consent(uuid,uuid,uuid,text,text,text,text,text,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.assert_privacy_production_ready(uuid),public.register_data_subject_request(uuid,text,text,text,text,integer,uuid),public.transition_data_subject_request(uuid,integer,text,text,text,uuid),public.request_privacy_retention_action(uuid,text,text,text,uuid),public.record_privacy_consent(uuid,uuid,uuid,text,text,text,text,text,timestamptz,uuid) to authenticated;

notify pgrst,'reload schema';
