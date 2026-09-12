-- P09: Provider onboarding, versioned evidence, service qualification, capacity and restrictions.

create table public.provider_profiles (
  provider_organization_id uuid primary key references public.organizations(id) on delete restrict,
  company_status text not null default 'PROFILE_INCOMPLETE' check(company_status in ('PROFILE_INCOMPLETE','UNDER_REVIEW','VERIFIED','REJECTED','SUSPENDED')),
  overall_status text not null default 'PROFILE_INCOMPLETE' check(overall_status in ('PROFILE_INCOMPLETE','UNDER_REVIEW','QUALIFICATION_IN_PROGRESS','PARTIALLY_QUALIFIED','ACTIVE','FINANCIAL_RESTRICTED','QUALITY_RESTRICTED','COMPLIANCE_RESTRICTED','SUSPENDED','TERMINATED')),
  activity_summary text not null check(length(btrim(activity_summary)) between 10 and 2000),
  team_size integer not null check(team_size between 1 and 1000000),
  years_experience integer not null check(years_experience between 0 and 200),
  secondary_subcontracting_allowed boolean not null default false,
  accounting_contact_email extensions.citext,
  partner_contract_status text not null default 'NOT_SIGNED' check(partner_contract_status in ('NOT_SIGNED','PENDING','SIGNED','EXPIRED','TERMINATED')),
  partner_contract_expires_at timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check(row_version>0),
  check(accounting_contact_email is null or accounting_contact_email::text ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  check((partner_contract_status='SIGNED' and partner_contract_expires_at is null) or partner_contract_status<>'SIGNED' or partner_contract_expires_at>created_at)
);

create table public.provider_services (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.provider_profiles(provider_organization_id) on delete restrict,
  service_id uuid not null references public.catalog_services(id) on delete restrict,
  request_status text not null default 'DRAFT' check(request_status in ('DRAFT','SUBMITTED','UNDER_REVIEW','INFORMATION_REQUIRED','DECIDED','WITHDRAWN')),
  requested_by uuid not null references auth.users(id),
  requested_at timestamptz,
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check(row_version>0),
  unique(provider_organization_id,service_id),
  unique(id,provider_organization_id),
  unique(id,provider_organization_id,service_id),
  check((request_status in ('DRAFT','WITHDRAWN')) or requested_at is not null)
);

create table public.provider_company_decisions (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.provider_profiles(provider_organization_id) on delete restrict,
  decision_version integer not null check(decision_version>0),
  company_status text not null check(company_status in ('UNDER_REVIEW','VERIFIED','REJECTED','SUSPENDED')),
  partner_contract_status text not null check(partner_contract_status in ('NOT_SIGNED','PENDING','SIGNED','EXPIRED','TERMINATED')),
  partner_contract_expires_at timestamptz,
  reason text not null check(length(btrim(reason)) between 3 and 2000),
  rule_version text not null check(rule_version ~ '^[A-Z0-9][A-Z0-9._-]{2,79}$'),
  decided_by uuid not null references auth.users(id),
  correlation_id uuid not null,
  decided_at timestamptz not null default clock_timestamp(),
  unique(provider_organization_id,decision_version),
  check(partner_contract_status<>'SIGNED' or partner_contract_expires_at is null or partner_contract_expires_at>decided_at)
);

create table public.provider_document_families (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.provider_profiles(provider_organization_id) on delete restrict,
  document_kind text not null check(document_kind in ('LEGAL','FISCAL','INSURANCE','CERTIFICATION','LICENSE','ACCREDITATION','REFERENCE','PORTFOLIO','PARTNER_CONTRACT')),
  code text not null check(code ~ '^[A-Z][A-Z0-9_.-]{1,79}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique(provider_organization_id,code),
  unique(id,provider_organization_id)
);

create table public.provider_document_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null,
  provider_organization_id uuid not null,
  version_number integer not null check(version_number>0),
  status text not null default 'DRAFT' check(status in ('DRAFT','SUBMITTED','UNDER_REVIEW','VERIFIED','REJECTED','EXPIRED','SUPERSEDED')),
  issuer_name text,
  reference_number text,
  issued_on date,
  expires_on date,
  storage_object_path text not null check(length(btrim(storage_object_path)) between 3 and 1000 and storage_object_path !~ '(^|/)\.\.(/|$)'),
  content_hash text not null check(content_hash ~ '^[0-9a-f]{64}$'),
  metadata jsonb not null default '{}'::jsonb check(jsonb_typeof(metadata)='object'),
  change_reason text not null check(length(btrim(change_reason)) between 3 and 500),
  supersedes_version_id uuid,
  submitted_by uuid not null references auth.users(id),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  unique(family_id,version_number),
  unique(family_id,id),
  unique(id,provider_organization_id),
  foreign key(family_id,provider_organization_id) references public.provider_document_families(id,provider_organization_id) on delete restrict,
  foreign key(family_id,supersedes_version_id) references public.provider_document_versions(family_id,id) on delete restrict,
  check(expires_on is null or issued_on is null or expires_on>issued_on),
  check((status in ('VERIFIED','REJECTED'))=(reviewed_by is not null and reviewed_at is not null)),
  check((version_number=1 and supersedes_version_id is null) or (version_number>1 and supersedes_version_id is not null))
);

create index provider_document_versions_history_idx on public.provider_document_versions(family_id,version_number desc);

create table public.provider_document_service_links (
  document_version_id uuid not null,
  provider_service_id uuid not null,
  provider_organization_id uuid not null,
  is_mandatory boolean not null default true,
  created_at timestamptz not null default clock_timestamp(),
  primary key(document_version_id,provider_service_id),
  foreign key(document_version_id,provider_organization_id) references public.provider_document_versions(id,provider_organization_id) on delete restrict,
  foreign key(provider_service_id,provider_organization_id) references public.provider_services(id,provider_organization_id) on delete restrict
);

create table public.provider_qualifications (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_service_id uuid not null references public.provider_services(id) on delete restrict,
  provider_organization_id uuid not null,
  service_id uuid not null,
  current_decision_id uuid,
  created_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check(row_version>0),
  unique(provider_service_id),
  unique(id,provider_organization_id,service_id),
  foreign key(provider_service_id,provider_organization_id,service_id) references public.provider_services(id,provider_organization_id,service_id) on delete restrict
);

create table public.provider_qualification_decisions (
  id uuid primary key default extensions.gen_random_uuid(),
  qualification_id uuid not null,
  provider_organization_id uuid not null,
  service_id uuid not null,
  decision_version integer not null check(decision_version>0),
  status text not null check(status in ('NOT_REQUESTED','PENDING','INFORMATION_REQUIRED','APPROVED','CONDITIONAL','SUSPENDED','EXPIRED','REJECTED')),
  questionnaire_version_id uuid references public.questionnaire_versions(id) on delete restrict,
  questionnaire_session_id uuid,
  score_basis_points integer check(score_basis_points between 0 and 10000),
  mandatory_checks jsonb not null default '[]'::jsonb check(jsonb_typeof(mandatory_checks)='array'),
  blocking_conditions jsonb not null default '[]'::jsonb check(jsonb_typeof(blocking_conditions)='array'),
  rationale text not null check(length(btrim(rationale)) between 3 and 2000),
  rule_version text not null check(rule_version ~ '^[A-Z0-9][A-Z0-9._-]{2,79}$'),
  effective_from timestamptz not null default clock_timestamp(),
  expires_at timestamptz,
  decided_by uuid not null references auth.users(id),
  decided_at timestamptz not null default clock_timestamp(),
  correlation_id uuid not null,
  unique(qualification_id,decision_version),
  unique(qualification_id,id),
  foreign key(qualification_id,provider_organization_id,service_id) references public.provider_qualifications(id,provider_organization_id,service_id) on delete restrict,
  foreign key(provider_organization_id,questionnaire_session_id) references public.questionnaire_sessions(organization_id,id) on delete restrict,
  check(expires_at is null or expires_at>effective_from),
  check((questionnaire_session_id is null)=(questionnaire_version_id is null)),
  check(status not in ('APPROVED','CONDITIONAL') or (questionnaire_session_id is not null and score_basis_points is not null and jsonb_array_length(mandatory_checks)>0)),
  check((status in ('APPROVED','CONDITIONAL')) or score_basis_points is null or score_basis_points between 0 and 10000),
  check(status<>'CONDITIONAL' or jsonb_array_length(blocking_conditions)>0)
);
alter table public.provider_qualifications add constraint provider_qualifications_current_decision_fk foreign key(id,current_decision_id) references public.provider_qualification_decisions(qualification_id,id) on delete restrict;

create table public.provider_capacity_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.provider_profiles(provider_organization_id) on delete restrict,
  service_id uuid references public.catalog_services(id) on delete restrict,
  version_number integer not null check(version_number>0),
  capacity_status text not null check(capacity_status in ('AVAILABLE','LIMITED','FULL','PAUSED')),
  available_units integer check(available_units is null or available_units>=0),
  lead_time_days integer not null check(lead_time_days between 0 and 3650),
  effective_from timestamptz not null default clock_timestamp(),
  effective_until timestamptz,
  reason text not null check(length(btrim(reason)) between 3 and 500),
  declared_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique(provider_organization_id,service_id,version_number),
  foreign key(provider_organization_id,service_id) references public.provider_services(provider_organization_id,service_id) on delete restrict,
  check(effective_until is null or effective_until>effective_from),
  check((capacity_status='FULL' and coalesce(available_units,0)=0) or capacity_status<>'FULL'),
  check((capacity_status='PAUSED' and available_units is null) or capacity_status<>'PAUSED')
);
create index provider_capacity_global_history_idx on public.provider_capacity_versions(provider_organization_id,version_number desc) where service_id is null;
create index provider_capacity_service_history_idx on public.provider_capacity_versions(provider_organization_id,service_id,version_number desc) where service_id is not null;
create unique index provider_capacity_global_version_uidx on public.provider_capacity_versions(provider_organization_id,version_number) where service_id is null;

create table public.provider_restriction_decisions (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.provider_profiles(provider_organization_id) on delete restrict,
  service_id uuid references public.catalog_services(id) on delete restrict,
  restriction_type text not null check(restriction_type in ('FINANCIAL','QUALITY','COMPLIANCE','SUSPENSION','TERMINATION_REVIEW')),
  decision_version integer not null check(decision_version>0),
  action text not null check(action in ('IMPOSED','LIFTED')),
  reason text not null check(length(btrim(reason)) between 3 and 2000),
  evidence_refs jsonb not null check(jsonb_typeof(evidence_refs)='array' and jsonb_array_length(evidence_refs)>0),
  rule_version text not null check(rule_version ~ '^[A-Z0-9][A-Z0-9._-]{2,79}$'),
  effective_at timestamptz not null default clock_timestamp(),
  decided_by uuid not null references auth.users(id),
  correlation_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  unique(provider_organization_id,service_id,restriction_type,decision_version),
  foreign key(provider_organization_id,service_id) references public.provider_services(provider_organization_id,service_id) on delete restrict
);
create unique index provider_restriction_global_version_uidx on public.provider_restriction_decisions(provider_organization_id,restriction_type,decision_version) where service_id is null;
create unique index provider_restriction_service_version_uidx on public.provider_restriction_decisions(provider_organization_id,service_id,restriction_type,decision_version) where service_id is not null;

create table private.provider_qualification_command_keys (
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  operation_scope text not null check(operation_scope in ('provider.profile.submit','provider.company.decide','provider.service.request','provider.document.version','provider.document.review','provider.capacity.declare','provider.qualification.decide','provider.restriction.decide')),
  key text not null check(length(key) between 8 and 200),
  request_hash text not null check(request_hash ~ '^[0-9a-f]{64}$'),
  response_body jsonb,
  command_id uuid not null default extensions.gen_random_uuid() unique,
  created_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  primary key(actor_user_id,operation_scope,key),
  check((response_body is null)=(completed_at is null))
);

create or replace function private.prevent_provider_snapshot_mutation() returns trigger language plpgsql security definer set search_path=pg_catalog as $$begin raise exception 'IMMUTABLE_PROVIDER_SNAPSHOT' using errcode='55000';end$$;
revoke all on function private.prevent_provider_snapshot_mutation() from public,anon,authenticated,service_role;
create trigger provider_document_versions_immutable before update or delete on public.provider_document_versions for each row execute function private.prevent_provider_snapshot_mutation();
create trigger provider_company_decisions_immutable before update or delete on public.provider_company_decisions for each row execute function private.prevent_provider_snapshot_mutation();
create trigger provider_qualification_decisions_immutable before update or delete on public.provider_qualification_decisions for each row execute function private.prevent_provider_snapshot_mutation();
create trigger provider_capacity_versions_immutable before update or delete on public.provider_capacity_versions for each row execute function private.prevent_provider_snapshot_mutation();
create trigger provider_restriction_decisions_immutable before update or delete on public.provider_restriction_decisions for each row execute function private.prevent_provider_snapshot_mutation();

create or replace function private.begin_provider_qualification_command(p_actor uuid,p_scope text,p_key text,p_hash text) returns table(command_id uuid,response_body jsonb)
language plpgsql security definer set search_path=pg_catalog as $$declare v private.provider_qualification_command_keys%rowtype;begin
 if p_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';end if;
 if length(coalesce(p_key,''))<8 or p_hash!~'^[0-9a-f]{64}$' then raise exception 'INVALID_COMMAND_IDENTITY' using errcode='22023';end if;
 insert into private.provider_qualification_command_keys(actor_user_id,operation_scope,key,request_hash)values(p_actor,p_scope,p_key,p_hash)on conflict do nothing;
 select * into v from private.provider_qualification_command_keys k where k.actor_user_id=p_actor and k.operation_scope=p_scope and k.key=p_key for update;
 if v.request_hash<>p_hash then raise exception 'IDEMPOTENCY_KEY_REUSED' using errcode='22000';end if;
 return query select v.command_id,v.response_body;
end$$;
create or replace function private.finish_provider_qualification_command(p_actor uuid,p_scope text,p_key text,p_response jsonb) returns void language plpgsql security definer set search_path=pg_catalog as $$begin update private.provider_qualification_command_keys set response_body=p_response,completed_at=clock_timestamp()where actor_user_id=p_actor and operation_scope=p_scope and key=p_key;end$$;
revoke all on function private.begin_provider_qualification_command(uuid,text,text,text),private.finish_provider_qualification_command(uuid,text,text,jsonb) from public,anon,authenticated,service_role;

create or replace function private.can_manage_provider(p_organization_id uuid,p_actor uuid default auth.uid()) returns boolean language sql stable security definer set search_path=pg_catalog as $$
 select private.has_org_role(p_organization_id,array['PROVIDER_OWNER','PROVIDER_MANAGER'],p_actor) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],p_actor)
$$;
create or replace function private.can_decide_provider_qualification(p_actor uuid default auth.uid()) returns boolean language sql stable security definer set search_path=pg_catalog as $$
 select private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],p_actor)
$$;
revoke all on function private.can_manage_provider(uuid,uuid),private.can_decide_provider_qualification(uuid) from public,anon,authenticated,service_role;

create or replace function public.submit_provider_profile(p_provider_organization_id uuid,p_profile jsonb,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$declare v_actor uuid:=auth.uid();v_hash text;v_command uuid;v_replay jsonb;v_response jsonb;v_existing public.provider_profiles%rowtype;begin
 if not private.can_manage_provider(p_provider_organization_id,v_actor) then raise exception 'PROVIDER_SCOPE_DENIED' using errcode='42501';end if;
 if jsonb_typeof(p_profile)<>'object' or length(btrim(coalesce(p_profile->>'activity_summary','')))<10 or coalesce((p_profile->>'team_size')::integer,0)<1 or coalesce((p_profile->>'years_experience')::integer,-1)<0 then raise exception 'INVALID_PROVIDER_PROFILE' using errcode='22023';end if;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','provider.profile.submit.v1','organization_id',p_provider_organization_id,'profile',p_profile,'expected',p_expected_row_version)::text,'UTF8'),'sha256'),'hex');select b.command_id,b.response_body into v_command,v_replay from private.begin_provider_qualification_command(v_actor,'provider.profile.submit',p_idempotency_key,v_hash)b;if v_replay is not null then return v_replay;end if;
 perform pg_advisory_xact_lock(hashtextextended('provider-profile:'||p_provider_organization_id::text,0));select * into v_existing from public.provider_profiles where provider_organization_id=p_provider_organization_id for update;
 if found and v_existing.row_version<>p_expected_row_version then raise exception 'STALE_PROVIDER_PROFILE' using errcode='40001';end if;if not found and p_expected_row_version<>0 then raise exception 'STALE_PROVIDER_PROFILE' using errcode='40001';end if;
 insert into public.provider_profiles(provider_organization_id,company_status,overall_status,activity_summary,team_size,years_experience,secondary_subcontracting_allowed,accounting_contact_email,created_by)
 values(p_provider_organization_id,'UNDER_REVIEW','UNDER_REVIEW',btrim(p_profile->>'activity_summary'),(p_profile->>'team_size')::integer,(p_profile->>'years_experience')::integer,coalesce((p_profile->>'secondary_subcontracting_allowed')::boolean,false),nullif(btrim(p_profile->>'accounting_contact_email'),''),v_actor)
 on conflict(provider_organization_id)do update set company_status='UNDER_REVIEW',overall_status=case when provider_profiles.overall_status in('SUSPENDED','TERMINATED')then provider_profiles.overall_status else'UNDER_REVIEW'end,activity_summary=excluded.activity_summary,team_size=excluded.team_size,years_experience=excluded.years_experience,secondary_subcontracting_allowed=excluded.secondary_subcontracting_allowed,accounting_contact_email=excluded.accounting_contact_email,updated_at=clock_timestamp(),row_version=provider_profiles.row_version+1;
 insert into public.provider_match_profiles(provider_organization_id)values(p_provider_organization_id)on conflict do nothing;
 v_response:=jsonb_build_object('outcome','PROVIDER_PROFILE_SUBMITTED','provider_organization_id',p_provider_organization_id,'status','UNDER_REVIEW','row_version',p_expected_row_version+1,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_provider_organization_id,v_actor,'USER','provider.profile.submitted','provider_profile',p_provider_organization_id::text,p_correlation_id,jsonb_build_object('command_id',v_command),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(p_provider_organization_id,'provider_profile',p_provider_organization_id::text,'ProviderProfileSubmittedV1',p_correlation_id,jsonb_build_object('provider_organization_id',p_provider_organization_id),p_idempotency_key,v_command);
 perform private.finish_provider_qualification_command(v_actor,'provider.profile.submit',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.request_provider_service(p_provider_organization_id uuid,p_service_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$declare v_actor uuid:=auth.uid();v_hash text;v_command uuid;v_replay jsonb;v_service uuid;v_qualification uuid;v_response jsonb;begin
 if not private.can_manage_provider(p_provider_organization_id,v_actor) then raise exception 'PROVIDER_SCOPE_DENIED' using errcode='42501';end if;if not exists(select 1 from public.provider_profiles p where p.provider_organization_id=p_provider_organization_id)then raise exception 'PROVIDER_PROFILE_REQUIRED' using errcode='23514';end if;if not exists(select 1 from public.catalog_services s where s.id=p_service_id and s.status<>'ARCHIVED')then raise exception 'SERVICE_NOT_AVAILABLE' using errcode='22023';end if;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','provider.service.request.v1','organization_id',p_provider_organization_id,'service_id',p_service_id)::text,'UTF8'),'sha256'),'hex');select b.command_id,b.response_body into v_command,v_replay from private.begin_provider_qualification_command(v_actor,'provider.service.request',p_idempotency_key,v_hash)b;if v_replay is not null then return v_replay;end if;
 insert into public.provider_services(provider_organization_id,service_id,request_status,requested_by,requested_at)values(p_provider_organization_id,p_service_id,'SUBMITTED',v_actor,clock_timestamp())on conflict(provider_organization_id,service_id)do update set request_status='SUBMITTED',requested_at=clock_timestamp(),updated_at=clock_timestamp(),row_version=provider_services.row_version+1 returning id into v_service;
 if v_service is null then select id into v_service from public.provider_services where provider_organization_id=p_provider_organization_id and service_id=p_service_id;end if;
 insert into public.provider_qualifications(provider_service_id,provider_organization_id,service_id)values(v_service,p_provider_organization_id,p_service_id)on conflict(provider_service_id)do update set row_version=provider_qualifications.row_version+1 returning id into v_qualification;
 insert into public.provider_service_match_profiles(provider_organization_id,service_id)values(p_provider_organization_id,p_service_id)on conflict(provider_organization_id,service_id)do nothing;
 update public.provider_profiles set overall_status='QUALIFICATION_IN_PROGRESS',updated_at=clock_timestamp(),row_version=row_version+1 where provider_organization_id=p_provider_organization_id and overall_status not in('SUSPENDED','TERMINATED');
 v_response:=jsonb_build_object('outcome','PROVIDER_SERVICE_REQUESTED','provider_service_id',v_service,'qualification_id',v_qualification,'status','PENDING','command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_provider_organization_id,v_actor,'USER','provider.service.requested','provider_service',v_service::text,p_correlation_id,jsonb_build_object('service_id',p_service_id,'command_id',v_command),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(p_provider_organization_id,'provider_service',v_service::text,'ProviderServiceRequestedV1',p_correlation_id,jsonb_build_object('provider_organization_id',p_provider_organization_id,'service_id',p_service_id),p_idempotency_key,v_command);perform private.finish_provider_qualification_command(v_actor,'provider.service.request',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.decide_provider_company(p_provider_organization_id uuid,p_company_status text,p_partner_contract_status text,p_partner_contract_expires_at timestamptz,p_reason text,p_rule_version text,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$declare v_actor uuid:=auth.uid();v_profile public.provider_profiles%rowtype;v_hash text;v_command uuid;v_replay jsonb;v_response jsonb;v_version integer;v_decision uuid;begin
 if not private.can_decide_provider_qualification(v_actor)then raise exception 'HUMAN_COMPANY_DECISION_REQUIRED' using errcode='42501';end if;select * into v_profile from public.provider_profiles where provider_organization_id=p_provider_organization_id;if not found then raise exception 'PROVIDER_PROFILE_NOT_FOUND' using errcode='P0002';end if;
 if p_company_status not in('UNDER_REVIEW','VERIFIED','REJECTED','SUSPENDED')or p_partner_contract_status not in('NOT_SIGNED','PENDING','SIGNED','EXPIRED','TERMINATED')or length(btrim(coalesce(p_reason,'')))<3 or p_rule_version!~'^[A-Z0-9][A-Z0-9._-]{2,79}$'or(p_partner_contract_status='SIGNED'and p_partner_contract_expires_at is not null and p_partner_contract_expires_at<=statement_timestamp())then raise exception 'INVALID_COMPANY_DECISION' using errcode='22023';end if;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','provider.company.decide.v1','organization_id',p_provider_organization_id,'company_status',p_company_status,'contract_status',p_partner_contract_status,'contract_expires_at',p_partner_contract_expires_at,'reason',btrim(p_reason),'rule_version',p_rule_version,'expected',p_expected_row_version)::text,'UTF8'),'sha256'),'hex');select b.command_id,b.response_body into v_command,v_replay from private.begin_provider_qualification_command(v_actor,'provider.company.decide',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('provider-profile:'||p_provider_organization_id::text,0));select * into v_profile from public.provider_profiles where provider_organization_id=p_provider_organization_id for update;if v_replay is not null then return v_replay;end if;if v_profile.row_version<>p_expected_row_version then raise exception 'STALE_PROVIDER_PROFILE' using errcode='40001';end if;
 select coalesce(max(decision_version),0)+1 into v_version from public.provider_company_decisions where provider_organization_id=p_provider_organization_id;insert into public.provider_company_decisions(provider_organization_id,decision_version,company_status,partner_contract_status,partner_contract_expires_at,reason,rule_version,decided_by,correlation_id)values(p_provider_organization_id,v_version,p_company_status,p_partner_contract_status,p_partner_contract_expires_at,btrim(p_reason),p_rule_version,v_actor,p_correlation_id)returning id into v_decision;
 update public.provider_profiles set company_status=p_company_status,partner_contract_status=p_partner_contract_status,partner_contract_expires_at=p_partner_contract_expires_at,overall_status=case when p_company_status='SUSPENDED'then'SUSPENDED'when p_company_status='REJECTED'then'COMPLIANCE_RESTRICTED'when p_company_status='VERIFIED'then'QUALIFICATION_IN_PROGRESS'else'UNDER_REVIEW'end,updated_at=clock_timestamp(),row_version=row_version+1 where provider_organization_id=p_provider_organization_id;
 update public.provider_match_profiles set company_verified=p_company_status='VERIFIED',partner_contract_signed=p_partner_contract_status='SIGNED'and(p_partner_contract_expires_at is null or p_partner_contract_expires_at>statement_timestamp()),updated_at=clock_timestamp(),row_version=row_version+1 where provider_organization_id=p_provider_organization_id;
 v_response:=jsonb_build_object('outcome','PROVIDER_COMPANY_DECIDED','provider_organization_id',p_provider_organization_id,'company_decision_id',v_decision,'decision_version',v_version,'company_status',p_company_status,'partner_contract_status',p_partner_contract_status,'row_version',p_expected_row_version+1,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_provider_organization_id,v_actor,'USER','provider.company.decided','provider_profile',p_provider_organization_id::text,p_correlation_id,jsonb_build_object('company_status',p_company_status,'partner_contract_status',p_partner_contract_status,'reason',btrim(p_reason),'rule_version',p_rule_version,'command_id',v_command),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(p_provider_organization_id,'provider_profile',p_provider_organization_id::text,'ProviderCompanyDecidedV1',p_correlation_id,jsonb_build_object('provider_organization_id',p_provider_organization_id,'company_status',p_company_status,'partner_contract_status',p_partner_contract_status,'rule_version',p_rule_version),p_idempotency_key,v_command);perform private.finish_provider_qualification_command(v_actor,'provider.company.decide',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.record_provider_document_version(p_provider_organization_id uuid,p_document_kind text,p_code text,p_document jsonb,p_provider_service_ids uuid[],p_change_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$declare v_actor uuid:=auth.uid();v_family uuid;v_previous uuid;v_version integer;v_document uuid;v_hash text;v_command uuid;v_replay jsonb;v_response jsonb;begin
 if not private.can_manage_provider(p_provider_organization_id,v_actor)then raise exception 'PROVIDER_SCOPE_DENIED' using errcode='42501';end if;if p_document_kind not in('LEGAL','FISCAL','INSURANCE','CERTIFICATION','LICENSE','ACCREDITATION','REFERENCE','PORTFOLIO','PARTNER_CONTRACT')or p_code!~'^[A-Z][A-Z0-9_.-]{1,79}$'or jsonb_typeof(p_document)<>'object'or coalesce(p_document->>'storage_object_path','')=''or coalesce(p_document->>'content_hash','')!~'^[0-9a-f]{64}$'or length(btrim(coalesce(p_change_reason,'')))<3 then raise exception 'INVALID_PROVIDER_DOCUMENT' using errcode='22023';end if;if exists(select 1 from unnest(coalesce(p_provider_service_ids,'{}'::uuid[]))s(id)left join public.provider_services ps on ps.id=s.id and ps.provider_organization_id=p_provider_organization_id where ps.id is null)then raise exception 'PROVIDER_DOCUMENT_SERVICE_SCOPE_DENIED' using errcode='42501';end if;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','provider.document.version.v1','organization_id',p_provider_organization_id,'kind',p_document_kind,'code',p_code,'document',p_document,'service_ids',p_provider_service_ids,'reason',btrim(p_change_reason))::text,'UTF8'),'sha256'),'hex');select b.command_id,b.response_body into v_command,v_replay from private.begin_provider_qualification_command(v_actor,'provider.document.version',p_idempotency_key,v_hash)b;if v_replay is not null then return v_replay;end if;
 insert into public.provider_document_families(provider_organization_id,document_kind,code,created_by)values(p_provider_organization_id,p_document_kind,p_code,v_actor)on conflict(provider_organization_id,code)do update set document_kind=provider_document_families.document_kind returning id into v_family;if not exists(select 1 from public.provider_document_families where id=v_family and document_kind=p_document_kind)then raise exception 'DOCUMENT_CODE_KIND_CONFLICT' using errcode='23505';end if;
 perform pg_advisory_xact_lock(hashtextextended('provider-document:'||v_family::text,0));select id,version_number into v_previous,v_version from public.provider_document_versions where family_id=v_family order by version_number desc limit 1;v_version:=coalesce(v_version,0)+1;
 insert into public.provider_document_versions(family_id,provider_organization_id,version_number,status,issuer_name,reference_number,issued_on,expires_on,storage_object_path,content_hash,metadata,change_reason,supersedes_version_id,submitted_by)values(v_family,p_provider_organization_id,v_version,'SUBMITTED',nullif(btrim(p_document->>'issuer_name'),''),nullif(btrim(p_document->>'reference_number'),''),nullif(p_document->>'issued_on','')::date,nullif(p_document->>'expires_on','')::date,btrim(p_document->>'storage_object_path'),p_document->>'content_hash',coalesce(p_document->'metadata','{}'::jsonb),btrim(p_change_reason),v_previous,v_actor)returning id into v_document;
 insert into public.provider_document_service_links(document_version_id,provider_service_id,provider_organization_id)select v_document,x,p_provider_organization_id from unnest(coalesce(p_provider_service_ids,'{}'::uuid[]))x;
 update public.provider_match_profiles set documents_valid=false,updated_at=clock_timestamp(),row_version=row_version+1 where provider_organization_id=p_provider_organization_id;
 v_response:=jsonb_build_object('outcome','PROVIDER_DOCUMENT_VERSION_RECORDED','document_version_id',v_document,'family_id',v_family,'version_number',v_version,'status','SUBMITTED','command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_provider_organization_id,v_actor,'USER','provider.document.version.recorded','provider_document_version',v_document::text,p_correlation_id,jsonb_build_object('document_kind',p_document_kind,'family_id',v_family,'version_number',v_version,'command_id',v_command),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(p_provider_organization_id,'provider_document',v_family::text,'ProviderDocumentVersionRecordedV1',p_correlation_id,jsonb_build_object('provider_organization_id',p_provider_organization_id,'document_version_id',v_document,'document_kind',p_document_kind,'version_number',v_version),p_idempotency_key,v_command);perform private.finish_provider_qualification_command(v_actor,'provider.document.version',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.declare_provider_capacity(p_provider_organization_id uuid,p_service_id uuid,p_capacity_status text,p_available_units integer,p_lead_time_days integer,p_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$declare v_actor uuid:=auth.uid();v_hash text;v_command uuid;v_replay jsonb;v_version integer;v_id uuid;v_response jsonb;begin
 if not private.can_manage_provider(p_provider_organization_id,v_actor)then raise exception 'PROVIDER_SCOPE_DENIED' using errcode='42501';end if;if p_capacity_status not in('AVAILABLE','LIMITED','FULL','PAUSED')or p_lead_time_days not between 0 and 3650 or length(btrim(coalesce(p_reason,'')))<3 or(p_capacity_status='FULL'and coalesce(p_available_units,0)<>0)or(p_capacity_status='PAUSED'and p_available_units is not null)then raise exception 'INVALID_PROVIDER_CAPACITY' using errcode='22023';end if;if p_service_id is not null and not exists(select 1 from public.provider_services s where s.provider_organization_id=p_provider_organization_id and s.service_id=p_service_id)then raise exception 'PROVIDER_SERVICE_REQUIRED' using errcode='23514';end if;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','provider.capacity.declare.v1','organization_id',p_provider_organization_id,'service_id',p_service_id,'status',p_capacity_status,'available_units',p_available_units,'lead_time_days',p_lead_time_days,'reason',btrim(p_reason))::text,'UTF8'),'sha256'),'hex');select b.command_id,b.response_body into v_command,v_replay from private.begin_provider_qualification_command(v_actor,'provider.capacity.declare',p_idempotency_key,v_hash)b;if v_replay is not null then return v_replay;end if;
 perform pg_advisory_xact_lock(hashtextextended('provider-capacity:'||p_provider_organization_id::text||':'||coalesce(p_service_id::text,'GLOBAL'),0));select coalesce(max(version_number),0)+1 into v_version from public.provider_capacity_versions where provider_organization_id=p_provider_organization_id and service_id is not distinct from p_service_id;
 insert into public.provider_capacity_versions(provider_organization_id,service_id,version_number,capacity_status,available_units,lead_time_days,reason,declared_by)values(p_provider_organization_id,p_service_id,v_version,p_capacity_status,p_available_units,p_lead_time_days,btrim(p_reason),v_actor)returning id into v_id;
 if p_service_id is null then update public.provider_match_profiles set capacity_status=p_capacity_status,updated_at=clock_timestamp(),row_version=row_version+1 where provider_organization_id=p_provider_organization_id;end if;
 v_response:=jsonb_build_object('outcome','PROVIDER_CAPACITY_DECLARED','capacity_version_id',v_id,'version_number',v_version,'capacity_status',p_capacity_status,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_provider_organization_id,v_actor,'USER','provider.capacity.declared','provider_capacity_version',v_id::text,p_correlation_id,jsonb_build_object('service_id',p_service_id,'capacity_status',p_capacity_status,'command_id',v_command),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(p_provider_organization_id,'provider_capacity',v_id::text,'ProviderCapacityDeclaredV1',p_correlation_id,jsonb_build_object('provider_organization_id',p_provider_organization_id,'service_id',p_service_id,'capacity_status',p_capacity_status),p_idempotency_key,v_command);perform private.finish_provider_qualification_command(v_actor,'provider.capacity.declare',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.review_provider_document(p_document_version_id uuid,p_status text,p_rationale text,p_rule_version text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$declare v_actor uuid:=auth.uid();v_source public.provider_document_versions%rowtype;v_version integer;v_review uuid;v_hash text;v_command uuid;v_replay jsonb;v_response jsonb;begin
 if not private.can_decide_provider_qualification(v_actor)then raise exception 'HUMAN_DOCUMENT_REVIEW_REQUIRED' using errcode='42501';end if;select * into v_source from public.provider_document_versions where id=p_document_version_id;if not found then raise exception 'PROVIDER_DOCUMENT_NOT_FOUND' using errcode='P0002';end if;if p_status not in('VERIFIED','REJECTED')or length(btrim(coalesce(p_rationale,'')))<3 or p_rule_version!~'^[A-Z0-9][A-Z0-9._-]{2,79}$'then raise exception 'INVALID_DOCUMENT_REVIEW' using errcode='22023';end if;if exists(select 1 from public.provider_document_versions d where d.family_id=v_source.family_id and d.version_number>v_source.version_number)then raise exception 'STALE_DOCUMENT_VERSION' using errcode='40001';end if;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','provider.document.review.v1','document_version_id',p_document_version_id,'status',p_status,'rationale',btrim(p_rationale),'rule_version',p_rule_version)::text,'UTF8'),'sha256'),'hex');select b.command_id,b.response_body into v_command,v_replay from private.begin_provider_qualification_command(v_actor,'provider.document.review',p_idempotency_key,v_hash)b;if v_replay is not null then return v_replay;end if;
 perform pg_advisory_xact_lock(hashtextextended('provider-document:'||v_source.family_id::text,0));v_version:=v_source.version_number+1;insert into public.provider_document_versions(family_id,provider_organization_id,version_number,status,issuer_name,reference_number,issued_on,expires_on,storage_object_path,content_hash,metadata,change_reason,supersedes_version_id,submitted_by,reviewed_by,reviewed_at)values(v_source.family_id,v_source.provider_organization_id,v_version,p_status,v_source.issuer_name,v_source.reference_number,v_source.issued_on,v_source.expires_on,v_source.storage_object_path,v_source.content_hash,v_source.metadata||jsonb_build_object('review_rationale',btrim(p_rationale),'review_rule_version',p_rule_version),'Human document review',v_source.id,v_source.submitted_by,v_actor,clock_timestamp())returning id into v_review;
 insert into public.provider_document_service_links(document_version_id,provider_service_id,provider_organization_id,is_mandatory)select v_review,l.provider_service_id,l.provider_organization_id,l.is_mandatory from public.provider_document_service_links l where l.document_version_id=v_source.id;
 update public.provider_service_match_profiles m set required_certifications_valid=not exists(select 1 from public.provider_document_families f join lateral(select d.* from public.provider_document_versions d where d.family_id=f.id order by d.version_number desc limit 1)d on true join public.provider_document_service_links l on l.document_version_id=d.id join public.provider_services ps on ps.id=l.provider_service_id where f.provider_organization_id=v_source.provider_organization_id and ps.service_id=m.service_id and l.is_mandatory and(d.status<>'VERIFIED'or(d.expires_on is not null and d.expires_on<=current_date))),updated_at=clock_timestamp(),row_version=m.row_version+1 where m.provider_organization_id=v_source.provider_organization_id;
 update public.provider_match_profiles m set documents_valid=(select count(distinct f.document_kind)=3 from public.provider_document_families f where f.provider_organization_id=v_source.provider_organization_id and f.document_kind in('LEGAL','FISCAL','INSURANCE'))and not exists(select 1 from public.provider_document_families f join lateral(select d.* from public.provider_document_versions d where d.family_id=f.id order by d.version_number desc limit 1)d on true where f.provider_organization_id=v_source.provider_organization_id and f.document_kind in('LEGAL','FISCAL','INSURANCE')and(d.status<>'VERIFIED'or(d.expires_on is not null and d.expires_on<=current_date))),updated_at=clock_timestamp(),row_version=m.row_version+1 where m.provider_organization_id=v_source.provider_organization_id;
 v_response:=jsonb_build_object('outcome','PROVIDER_DOCUMENT_REVIEWED','document_version_id',v_review,'family_id',v_source.family_id,'version_number',v_version,'status',p_status,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_source.provider_organization_id,v_actor,'USER','provider.document.reviewed','provider_document_version',v_review::text,p_correlation_id,jsonb_build_object('source_version_id',p_document_version_id,'status',p_status,'reason',btrim(p_rationale),'rule_version',p_rule_version,'command_id',v_command),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(v_source.provider_organization_id,'provider_document',v_source.family_id::text,'ProviderDocumentReviewedV1',p_correlation_id,jsonb_build_object('provider_organization_id',v_source.provider_organization_id,'document_version_id',v_review,'status',p_status,'rule_version',p_rule_version),p_idempotency_key,v_command);perform private.finish_provider_qualification_command(v_actor,'provider.document.review',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.decide_provider_qualification(p_qualification_id uuid,p_status text,p_questionnaire_session_id uuid,p_score_basis_points integer,p_mandatory_checks jsonb,p_blocking_conditions jsonb,p_rationale text,p_rule_version text,p_expires_at timestamptz,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$declare v_actor uuid:=auth.uid();v_q public.provider_qualifications%rowtype;v_hash text;v_command uuid;v_replay jsonb;v_version integer;v_decision uuid;v_response jsonb;v_approved integer;v_previous_status text;v_questionnaire_version uuid;begin
 if not private.can_decide_provider_qualification(v_actor)then raise exception 'HUMAN_QUALIFICATION_DECISION_REQUIRED' using errcode='42501';end if;select * into v_q from public.provider_qualifications where id=p_qualification_id;if not found then raise exception 'QUALIFICATION_NOT_FOUND' using errcode='P0002';end if;
 if p_status not in('PENDING','INFORMATION_REQUIRED','APPROVED','CONDITIONAL','SUSPENDED','EXPIRED','REJECTED')or jsonb_typeof(p_mandatory_checks)<>'array'or jsonb_typeof(p_blocking_conditions)<>'array'or length(btrim(coalesce(p_rationale,'')))<3 or p_rule_version!~'^[A-Z0-9][A-Z0-9._-]{2,79}$'or(p_status='CONDITIONAL'and jsonb_array_length(p_blocking_conditions)=0)or(p_status in('APPROVED','CONDITIONAL')and(p_questionnaire_session_id is null or p_score_basis_points is null or jsonb_array_length(p_mandatory_checks)=0 or exists(select 1 from jsonb_array_elements(p_mandatory_checks)c where jsonb_typeof(c)<>'object'or coalesce((c->>'passed')::boolean,false)=false)))then raise exception 'INVALID_QUALIFICATION_DECISION' using errcode='22023';end if;
 if p_questionnaire_session_id is not null then select s.questionnaire_version_id into v_questionnaire_version from public.questionnaire_sessions s where s.id=p_questionnaire_session_id and s.organization_id=v_q.provider_organization_id and s.audience='PROVIDER'and s.status='SUBMITTED'and not s.is_simulation;if v_questionnaire_version is null then raise exception 'SUBMITTED_PROVIDER_QUESTIONNAIRE_REQUIRED' using errcode='23514';end if;end if;
 select d.status into v_previous_status from public.provider_qualification_decisions d where d.id=v_q.current_decision_id;if not((v_previous_status is null and p_status in('PENDING','INFORMATION_REQUIRED','APPROVED','CONDITIONAL','REJECTED'))or(v_previous_status='PENDING'and p_status in('INFORMATION_REQUIRED','APPROVED','CONDITIONAL','REJECTED'))or(v_previous_status='INFORMATION_REQUIRED'and p_status='PENDING')or(v_previous_status in('APPROVED','CONDITIONAL')and p_status in('PENDING','SUSPENDED','EXPIRED'))or(v_previous_status in('SUSPENDED','EXPIRED','REJECTED')and p_status='PENDING'))then raise exception 'INVALID_QUALIFICATION_TRANSITION' using errcode='55000';end if;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','provider.qualification.decide.v1','qualification_id',p_qualification_id,'status',p_status,'questionnaire_session_id',p_questionnaire_session_id,'score',p_score_basis_points,'mandatory_checks',p_mandatory_checks,'blocking_conditions',p_blocking_conditions,'rationale',btrim(p_rationale),'rule_version',p_rule_version,'expires_at',p_expires_at,'expected',p_expected_row_version)::text,'UTF8'),'sha256'),'hex');select b.command_id,b.response_body into v_command,v_replay from private.begin_provider_qualification_command(v_actor,'provider.qualification.decide',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('provider-qualification:'||p_qualification_id::text,0));select * into v_q from public.provider_qualifications where id=p_qualification_id for update;if v_replay is not null then return v_replay;end if;if v_q.row_version<>p_expected_row_version then raise exception 'STALE_PROVIDER_QUALIFICATION' using errcode='40001';end if;
 select coalesce(max(decision_version),0)+1 into v_version from public.provider_qualification_decisions where qualification_id=p_qualification_id;insert into public.provider_qualification_decisions(qualification_id,provider_organization_id,service_id,decision_version,status,questionnaire_version_id,questionnaire_session_id,score_basis_points,mandatory_checks,blocking_conditions,rationale,rule_version,expires_at,decided_by,correlation_id)values(p_qualification_id,v_q.provider_organization_id,v_q.service_id,v_version,p_status,v_questionnaire_version,p_questionnaire_session_id,p_score_basis_points,p_mandatory_checks,p_blocking_conditions,btrim(p_rationale),p_rule_version,p_expires_at,v_actor,p_correlation_id)returning id into v_decision;
 update public.provider_qualifications set current_decision_id=v_decision,row_version=row_version+1 where id=p_qualification_id;update public.provider_services set request_status=case when p_status='INFORMATION_REQUIRED'then'INFORMATION_REQUIRED'when p_status='PENDING'then'UNDER_REVIEW'else'DECIDED'end,updated_at=clock_timestamp(),row_version=row_version+1 where id=v_q.provider_service_id;
 update public.provider_service_match_profiles set qualification_status=case when p_status='APPROVED'then'APPROVED'when p_status in('SUSPENDED','EXPIRED')then'SUSPENDED'when p_status='REJECTED'then'REJECTED'else'PENDING'end,required_certifications_valid=not exists(select 1 from public.provider_document_families f join lateral(select d.* from public.provider_document_versions d where d.family_id=f.id order by d.version_number desc limit 1)d on true join public.provider_document_service_links l on l.document_version_id=d.id where l.provider_service_id=v_q.provider_service_id and l.is_mandatory and(d.status<>'VERIFIED'or(d.expires_on is not null and d.expires_on<=current_date))),updated_at=clock_timestamp(),row_version=row_version+1 where provider_organization_id=v_q.provider_organization_id and service_id=v_q.service_id;
 select count(*)into v_approved from public.provider_qualifications q join public.provider_qualification_decisions d on d.id=q.current_decision_id where q.provider_organization_id=v_q.provider_organization_id and d.status='APPROVED'and(d.expires_at is null or d.expires_at>statement_timestamp());update public.provider_profiles set overall_status=case when v_approved>0 and partner_contract_status='SIGNED'then'ACTIVE'when v_approved>0 then'PARTIALLY_QUALIFIED'else'QUALIFICATION_IN_PROGRESS'end,updated_at=clock_timestamp(),row_version=row_version+1 where provider_organization_id=v_q.provider_organization_id and overall_status not in('FINANCIAL_RESTRICTED','QUALITY_RESTRICTED','COMPLIANCE_RESTRICTED','SUSPENDED','TERMINATED');
 v_response:=jsonb_build_object('outcome','PROVIDER_QUALIFICATION_DECIDED','qualification_id',p_qualification_id,'decision_id',v_decision,'decision_version',v_version,'status',p_status,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_q.provider_organization_id,v_actor,'USER','provider.qualification.decided','provider_qualification_decision',v_decision::text,p_correlation_id,jsonb_build_object('qualification_id',p_qualification_id,'service_id',v_q.service_id,'status',p_status,'rule_version',p_rule_version,'reason_recorded',true,'command_id',v_command),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(v_q.provider_organization_id,'provider_qualification',p_qualification_id::text,'ProviderQualificationDecidedV1',p_correlation_id,jsonb_build_object('qualification_id',p_qualification_id,'decision_id',v_decision,'service_id',v_q.service_id,'status',p_status,'rule_version',p_rule_version),p_idempotency_key,v_command);perform private.finish_provider_qualification_command(v_actor,'provider.qualification.decide',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.explain_provider_service_eligibility(p_provider_organization_id uuid,p_service_id uuid) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $$declare v_actor uuid:=auth.uid();v_profile public.provider_profiles%rowtype;v_service public.provider_services%rowtype;v_decision public.provider_qualification_decisions%rowtype;v_capacity text;v_reasons text[]:='{}';begin
 if not(private.is_active_org_member(p_provider_organization_id,v_actor)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR'],v_actor))then raise exception 'PROVIDER_ELIGIBILITY_SCOPE_DENIED' using errcode='42501';end if;
 select * into v_profile from public.provider_profiles where provider_organization_id=p_provider_organization_id;select * into v_service from public.provider_services where provider_organization_id=p_provider_organization_id and service_id=p_service_id;select d.* into v_decision from public.provider_qualifications q join public.provider_qualification_decisions d on d.id=q.current_decision_id where q.provider_organization_id=p_provider_organization_id and q.service_id=p_service_id;
 select c.capacity_status into v_capacity from public.provider_capacity_versions c where c.provider_organization_id=p_provider_organization_id and(c.service_id=p_service_id or c.service_id is null)and c.effective_from<=statement_timestamp()and(c.effective_until is null or c.effective_until>statement_timestamp())order by(c.service_id is not null)desc,c.version_number desc limit 1;
 if v_profile.provider_organization_id is null then v_reasons:=array_append(v_reasons,'PROFILE_MISSING');else if v_profile.company_status<>'VERIFIED'then v_reasons:=array_append(v_reasons,'COMPANY_NOT_VERIFIED');end if;if(select count(distinct f.document_kind)<3 from public.provider_document_families f where f.provider_organization_id=p_provider_organization_id and f.document_kind in('LEGAL','FISCAL','INSURANCE'))or exists(select 1 from public.provider_document_families f join lateral(select d.* from public.provider_document_versions d where d.family_id=f.id order by d.version_number desc limit 1)d on true where f.provider_organization_id=p_provider_organization_id and f.document_kind in('LEGAL','FISCAL','INSURANCE')and(d.status<>'VERIFIED'or(d.expires_on is not null and d.expires_on<=current_date)))then v_reasons:=array_append(v_reasons,'COMPANY_DOCUMENTS_INVALID');end if;if v_profile.partner_contract_status<>'SIGNED'or(v_profile.partner_contract_expires_at is not null and v_profile.partner_contract_expires_at<=statement_timestamp())then v_reasons:=array_append(v_reasons,'PARTNER_CONTRACT_INVALID');end if;if v_profile.overall_status in('FINANCIAL_RESTRICTED','QUALITY_RESTRICTED','COMPLIANCE_RESTRICTED','SUSPENDED','TERMINATED')then v_reasons:=array_append(v_reasons,v_profile.overall_status);end if;end if;
 if v_service.id is null then v_reasons:=array_append(v_reasons,'SERVICE_NOT_REQUESTED');end if;if v_decision.id is null then v_reasons:=array_append(v_reasons,'QUALIFICATION_NOT_DECIDED');elsif v_decision.status<>'APPROVED'then v_reasons:=array_append(v_reasons,'QUALIFICATION_'||v_decision.status);elsif v_decision.expires_at is not null and v_decision.expires_at<=statement_timestamp()then v_reasons:=array_append(v_reasons,'QUALIFICATION_EXPIRED');end if;
 if exists(select 1 from public.provider_document_families f join lateral(select d.* from public.provider_document_versions d where d.family_id=f.id order by d.version_number desc limit 1)d on true join public.provider_document_service_links l on l.document_version_id=d.id where l.provider_service_id=v_service.id and l.is_mandatory and(d.status<>'VERIFIED'or(d.expires_on is not null and d.expires_on<=current_date)))then v_reasons:=array_append(v_reasons,'MANDATORY_DOCUMENT_INVALID');end if;if v_capacity is null then v_reasons:=array_append(v_reasons,'CAPACITY_NOT_DECLARED');elsif v_capacity in('FULL','PAUSED')then v_reasons:=array_append(v_reasons,'CAPACITY_'||v_capacity);end if;
 if exists(select 1 from public.provider_restriction_decisions r where r.provider_organization_id=p_provider_organization_id and(r.service_id is null or r.service_id=p_service_id)and r.action='IMPOSED'and not exists(select 1 from public.provider_restriction_decisions newer where newer.provider_organization_id=r.provider_organization_id and newer.service_id is not distinct from r.service_id and newer.restriction_type=r.restriction_type and newer.decision_version>r.decision_version))then v_reasons:=array_append(v_reasons,'ACTIVE_HUMAN_RESTRICTION');end if;
 return jsonb_build_object('eligible',cardinality(v_reasons)=0,'provider_organization_id',p_provider_organization_id,'service_id',p_service_id,'reasons',to_jsonb(v_reasons),'qualification_status',coalesce(v_decision.status,'NOT_REQUESTED'),'capacity_status',coalesce(v_capacity,'NOT_DECLARED'),'decision_version',v_decision.decision_version,'rule_version',v_decision.rule_version);
end$$;

create or replace function public.decide_provider_restriction(p_provider_organization_id uuid,p_service_id uuid,p_restriction_type text,p_action text,p_reason text,p_evidence_refs jsonb,p_rule_version text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$declare v_actor uuid:=auth.uid();v_hash text;v_command uuid;v_replay jsonb;v_version integer;v_decision uuid;v_response jsonb;v_status text;begin
 if not private.can_decide_provider_qualification(v_actor)then raise exception 'HUMAN_RESTRICTION_DECISION_REQUIRED' using errcode='42501';end if;if not exists(select 1 from public.provider_profiles where provider_organization_id=p_provider_organization_id)or(p_service_id is not null and not exists(select 1 from public.provider_services where provider_organization_id=p_provider_organization_id and service_id=p_service_id))then raise exception 'PROVIDER_SCOPE_NOT_FOUND' using errcode='P0002';end if;if p_restriction_type not in('FINANCIAL','QUALITY','COMPLIANCE','SUSPENSION','TERMINATION_REVIEW')or p_action not in('IMPOSED','LIFTED')or length(btrim(coalesce(p_reason,'')))<3 or jsonb_typeof(p_evidence_refs)<>'array'or jsonb_array_length(p_evidence_refs)=0 or p_rule_version!~'^[A-Z0-9][A-Z0-9._-]{2,79}$'then raise exception 'INVALID_RESTRICTION_DECISION' using errcode='22023';end if;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','provider.restriction.decide.v1','organization_id',p_provider_organization_id,'service_id',p_service_id,'type',p_restriction_type,'action',p_action,'reason',btrim(p_reason),'evidence_refs',p_evidence_refs,'rule_version',p_rule_version)::text,'UTF8'),'sha256'),'hex');select b.command_id,b.response_body into v_command,v_replay from private.begin_provider_qualification_command(v_actor,'provider.restriction.decide',p_idempotency_key,v_hash)b;if v_replay is not null then return v_replay;end if;
 perform pg_advisory_xact_lock(hashtextextended('provider-restriction:'||p_provider_organization_id::text||':'||coalesce(p_service_id::text,'GLOBAL')||':'||p_restriction_type,0));select coalesce(max(decision_version),0)+1 into v_version from public.provider_restriction_decisions where provider_organization_id=p_provider_organization_id and service_id is not distinct from p_service_id and restriction_type=p_restriction_type;insert into public.provider_restriction_decisions(provider_organization_id,service_id,restriction_type,decision_version,action,reason,evidence_refs,rule_version,decided_by,correlation_id)values(p_provider_organization_id,p_service_id,p_restriction_type,v_version,p_action,btrim(p_reason),p_evidence_refs,p_rule_version,v_actor,p_correlation_id)returning id into v_decision;
 if p_service_id is null then v_status:=case when p_action='IMPOSED'and p_restriction_type='FINANCIAL'then'FINANCIAL_RESTRICTED'when p_action='IMPOSED'and p_restriction_type='QUALITY'then'QUALITY_RESTRICTED'when p_action='IMPOSED'and p_restriction_type='COMPLIANCE'then'COMPLIANCE_RESTRICTED'when p_action='IMPOSED'then'SUSPENDED'else'QUALIFICATION_IN_PROGRESS'end;update public.provider_profiles set overall_status=v_status,updated_at=clock_timestamp(),row_version=row_version+1 where provider_organization_id=p_provider_organization_id;update public.provider_match_profiles set financial_status=case when p_restriction_type='FINANCIAL'then case when p_action='IMPOSED'then'RESTRICTED'else'OK'end else financial_status end,quality_status=case when p_restriction_type='QUALITY'then case when p_action='IMPOSED'then'SUSPENDED'else'OK'end else quality_status end,updated_at=clock_timestamp(),row_version=row_version+1 where provider_organization_id=p_provider_organization_id;else update public.provider_service_match_profiles set qualification_status=case when p_action='IMPOSED'then'SUSPENDED'else'PENDING'end,updated_at=clock_timestamp(),row_version=row_version+1 where provider_organization_id=p_provider_organization_id and service_id=p_service_id;end if;
 v_response:=jsonb_build_object('outcome','PROVIDER_RESTRICTION_DECIDED','restriction_decision_id',v_decision,'decision_version',v_version,'action',p_action,'restriction_type',p_restriction_type,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_provider_organization_id,v_actor,'USER','provider.restriction.decided','provider_restriction_decision',v_decision::text,p_correlation_id,jsonb_build_object('service_id',p_service_id,'restriction_type',p_restriction_type,'action',p_action,'reason',btrim(p_reason),'evidence_refs',p_evidence_refs,'rule_version',p_rule_version,'command_id',v_command),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(p_provider_organization_id,'provider_restriction',v_decision::text,'ProviderRestrictionDecidedV1',p_correlation_id,jsonb_build_object('provider_organization_id',p_provider_organization_id,'service_id',p_service_id,'restriction_type',p_restriction_type,'action',p_action,'rule_version',p_rule_version),p_idempotency_key,v_command);perform private.finish_provider_qualification_command(v_actor,'provider.restriction.decide',p_idempotency_key,v_response);return v_response;
end$$;

alter table public.provider_profiles enable row level security;alter table public.provider_company_decisions enable row level security;alter table public.provider_services enable row level security;alter table public.provider_document_families enable row level security;alter table public.provider_document_versions enable row level security;alter table public.provider_document_service_links enable row level security;alter table public.provider_qualifications enable row level security;alter table public.provider_qualification_decisions enable row level security;alter table public.provider_capacity_versions enable row level security;alter table public.provider_restriction_decisions enable row level security;
create policy provider_profiles_scoped_read on public.provider_profiles for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR']));
create policy provider_company_decisions_scoped_read on public.provider_company_decisions for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR']));
create policy provider_services_scoped_read on public.provider_services for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR']));
create policy provider_document_families_scoped_read on public.provider_document_families for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR']));
create policy provider_document_versions_scoped_read on public.provider_document_versions for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR']));
create policy provider_document_service_links_scoped_read on public.provider_document_service_links for select to authenticated using(exists(select 1 from public.provider_services s where s.id=provider_service_id and(private.is_active_org_member(s.provider_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR']))));
create policy provider_qualifications_scoped_read on public.provider_qualifications for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR']));
create policy provider_qualification_decisions_scoped_read on public.provider_qualification_decisions for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR']));
create policy provider_capacity_versions_scoped_read on public.provider_capacity_versions for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR']));
create policy provider_restriction_decisions_scoped_read on public.provider_restriction_decisions for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR']));

revoke all on public.provider_profiles,public.provider_company_decisions,public.provider_services,public.provider_document_families,public.provider_document_versions,public.provider_document_service_links,public.provider_qualifications,public.provider_qualification_decisions,public.provider_capacity_versions,public.provider_restriction_decisions from anon,authenticated,service_role;
grant select on public.provider_profiles,public.provider_company_decisions,public.provider_services,public.provider_document_families,public.provider_document_versions,public.provider_document_service_links,public.provider_qualifications,public.provider_qualification_decisions,public.provider_capacity_versions,public.provider_restriction_decisions to authenticated;
revoke all on function public.submit_provider_profile(uuid,jsonb,integer,text,uuid),public.decide_provider_company(uuid,text,text,timestamptz,text,text,integer,text,uuid),public.request_provider_service(uuid,uuid,text,uuid),public.record_provider_document_version(uuid,text,text,jsonb,uuid[],text,text,uuid),public.review_provider_document(uuid,text,text,text,text,uuid),public.declare_provider_capacity(uuid,uuid,text,integer,integer,text,text,uuid),public.decide_provider_qualification(uuid,text,uuid,integer,jsonb,jsonb,text,text,timestamptz,integer,text,uuid),public.decide_provider_restriction(uuid,uuid,text,text,text,jsonb,text,text,uuid),public.explain_provider_service_eligibility(uuid,uuid) from public,anon,service_role;
grant execute on function public.submit_provider_profile(uuid,jsonb,integer,text,uuid),public.decide_provider_company(uuid,text,text,timestamptz,text,text,integer,text,uuid),public.request_provider_service(uuid,uuid,text,uuid),public.record_provider_document_version(uuid,text,text,jsonb,uuid[],text,text,uuid),public.review_provider_document(uuid,text,text,text,text,uuid),public.declare_provider_capacity(uuid,uuid,text,integer,integer,text,text,uuid),public.decide_provider_qualification(uuid,text,uuid,integer,jsonb,jsonb,text,text,timestamptz,integer,text,uuid),public.decide_provider_restriction(uuid,uuid,text,text,text,jsonb,text,text,uuid),public.explain_provider_service_eligibility(uuid,uuid) to authenticated;

create index provider_services_service_status_idx on public.provider_services(service_id,request_status,provider_organization_id);
create index provider_document_versions_expiry_idx on public.provider_document_versions(expires_on,status) where expires_on is not null;
create index provider_qualification_decisions_status_expiry_idx on public.provider_qualification_decisions(status,expires_at) where status in('APPROVED','CONDITIONAL');
create index provider_capacity_matching_idx on public.provider_capacity_versions(service_id,capacity_status,effective_from desc) where effective_until is null;
create index provider_restriction_active_idx on public.provider_restriction_decisions(provider_organization_id,service_id,restriction_type,decision_version desc);
