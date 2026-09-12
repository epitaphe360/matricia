-- P07: versioned service requests, explainable matching and isolated RFQ invitations.

create table public.provider_match_profiles (
  provider_organization_id uuid primary key references public.organizations(id) on delete restrict,
  company_verified boolean not null default false,
  documents_valid boolean not null default false,
  financial_status text not null default 'RESTRICTED' check(financial_status in ('OK','RESTRICTED')),
  quality_status text not null default 'REVIEW' check(quality_status in ('OK','REVIEW','SUSPENDED')),
  capacity_status text not null default 'PAUSED' check(capacity_status in ('AVAILABLE','LIMITED','FULL','PAUSED')),
  region_codes text[] not null default '{}',
  partner_contract_signed boolean not null default false,
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check(row_version>0),
  check(array_position(region_codes,null) is null)
);

create table public.provider_service_match_profiles (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.provider_match_profiles(provider_organization_id) on delete restrict,
  service_id uuid not null references public.catalog_services(id) on delete restrict,
  qualification_status text not null default 'PENDING' check(qualification_status in ('PENDING','APPROVED','SUSPENDED','REJECTED')),
  required_certifications_valid boolean not null default false,
  service_fit_score smallint not null default 0 check(service_fit_score between 0 and 100),
  quality_score smallint not null default 0 check(quality_score between 0 and 100),
  historical_delay_score smallint not null default 0 check(historical_delay_score between 0 and 100),
  experience_score smallint not null default 0 check(experience_score between 0 and 100),
  satisfaction_score smallint not null default 0 check(satisfaction_score between 0 and 100),
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check(row_version>0),
  unique(provider_organization_id,service_id)
);

create table public.service_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  client_organization_id uuid not null references public.organizations(id) on delete restrict,
  site_id uuid,
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  service_id uuid not null references public.catalog_services(id) on delete restrict,
  questionnaire_version_id uuid references public.questionnaire_versions(id) on delete restrict,
  current_version_id uuid,
  status text not null default 'DRAFT' check(status in ('DRAFT','INFORMATION_REQUIRED','READY','MATCHING','RFQ_OPEN','QUOTES_RECEIVED','CLIENT_REVIEW','PROVIDER_SELECTED','CONTRACT_PENDING','CONTRACTED','CANCELLED','EXPIRED','NO_PROVIDER_AVAILABLE')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check(row_version>0),
  unique(id,client_organization_id), unique(id,library_id)
);

create table public.service_request_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null references public.service_requests(id) on delete restrict,
  client_organization_id uuid not null,
  library_id uuid not null,
  version_number integer not null check(version_number>0),
  description text not null check(length(btrim(description)) between 10 and 8000),
  urgency text not null check(urgency in ('LOW','NORMAL','HIGH','CRITICAL')),
  desired_date date,
  budget_minor bigint check(budget_minor is null or budget_minor>=0),
  currency_code char(3) not null default 'MAD' check(currency_code ~ '^[A-Z]{3}$'),
  required_quote_data jsonb not null check(jsonb_typeof(required_quote_data)='object'),
  required_fields_complete boolean not null default false,
  catalog_snapshot_hash text not null check(catalog_snapshot_hash ~ '^[0-9a-f]{64}$'),
  questionnaire_snapshot_hash text not null check(questionnaire_snapshot_hash ~ '^[0-9a-f]{64}$'),
  change_reason text not null check(length(btrim(change_reason)) between 3 and 500),
  content_hash text not null check(content_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique(request_id,version_number), unique(request_id,id),
  foreign key(request_id,client_organization_id) references public.service_requests(id,client_organization_id) on delete restrict,
  foreign key(request_id,library_id) references public.service_requests(id,library_id) on delete restrict
);
alter table public.service_requests add constraint service_requests_current_version_fk foreign key(id,current_version_id) references public.service_request_versions(request_id,id) on delete restrict;

create table public.matching_policy_versions (
  policy_version text primary key check(policy_version ~ '^[A-Z0-9][A-Z0-9._-]{2,39}$'),
  effective_from timestamptz not null,
  effective_until timestamptz,
  target_panel_size integer not null default 10 check(target_panel_size between 1 and 100),
  weights jsonb not null check(jsonb_typeof(weights)='object'),
  created_at timestamptz not null default clock_timestamp(),
  check(effective_until is null or effective_until>effective_from),
  check(weights='{"service_fit":30,"quality":20,"availability":15,"historical_delay":10,"experience":10,"fair_rotation":10,"satisfaction":5}'::jsonb)
);
insert into public.matching_policy_versions(policy_version,effective_from,target_panel_size,weights) values('MATCH-V1',clock_timestamp(),10,'{"service_fit":30,"quality":20,"availability":15,"historical_delay":10,"experience":10,"fair_rotation":10,"satisfaction":5}'::jsonb);

create table public.matching_runs (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null references public.service_requests(id) on delete restrict,
  request_version_id uuid not null,
  policy_version text not null references public.matching_policy_versions(policy_version) on delete restrict,
  status text not null default 'RUNNING' check(status in ('RUNNING','COMPLETED','NO_CANDIDATE','FAILED')),
  target_panel_size integer not null check(target_panel_size between 1 and 100),
  started_by uuid not null references auth.users(id),
  started_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  unique(request_id,id),
  foreign key(request_id,request_version_id) references public.service_request_versions(request_id,id) on delete restrict,
  check((status='RUNNING')=(completed_at is null))
);

create table public.matching_candidates (
  id uuid primary key default extensions.gen_random_uuid(),
  matching_run_id uuid not null references public.matching_runs(id) on delete restrict,
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  eligible boolean not null,
  exclusion_reasons text[] not null default '{}',
  score_basis_points integer not null check(score_basis_points between 0 and 10000),
  score_explanation jsonb not null check(jsonb_typeof(score_explanation)='object'),
  rotation_component smallint not null check(rotation_component between 0 and 100),
  created_at timestamptz not null default clock_timestamp(),
  unique(matching_run_id,provider_organization_id), unique(id,matching_run_id,provider_organization_id),
  check((eligible and cardinality(exclusion_reasons)=0) or (not eligible and cardinality(exclusion_reasons)>0))
);

create table public.rfqs (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null references public.service_requests(id) on delete restrict,
  request_version_id uuid not null,
  matching_run_id uuid not null,
  version_number integer not null default 1 check(version_number>0),
  deadline timestamptz not null,
  status text not null default 'OPEN' check(status in ('OPEN','CLOSED','CANCELLED','EXPIRED')),
  confidentiality_settings jsonb not null default '{"mask_direct_contacts":true,"competitor_offers_visible":false}'::jsonb check(jsonb_typeof(confidentiality_settings)='object'),
  invited_count integer not null check(invited_count>=0),
  opened_by uuid not null references auth.users(id),
  opened_at timestamptz not null default clock_timestamp(),
  closed_at timestamptz,
  unique(request_id,version_number), unique(id,request_id),
  foreign key(request_id,request_version_id) references public.service_request_versions(request_id,id) on delete restrict,
  foreign key(request_id,matching_run_id) references public.matching_runs(request_id,id) on delete restrict,
  check(deadline>opened_at), check((status='CLOSED')=(closed_at is not null))
);

create table public.rfq_providers (
  id uuid primary key default extensions.gen_random_uuid(),
  rfq_id uuid not null references public.rfqs(id) on delete restrict,
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  matching_candidate_id uuid not null,
  status text not null default 'INVITED' check(status in ('INVITED','VIEWED','ACCEPTED','DECLINED','WITHDRAWN','SUSPENDED')),
  invited_at timestamptz not null default clock_timestamp(),
  responded_at timestamptz,
  decline_reason text check(decline_reason is null or length(btrim(decline_reason)) between 3 and 500),
  row_version integer not null default 1 check(row_version>0),
  unique(rfq_id,provider_organization_id), unique(id,rfq_id,provider_organization_id),
  foreign key(matching_candidate_id) references public.matching_candidates(id) on delete restrict,
  check((status in ('ACCEPTED','DECLINED'))=(responded_at is not null)),
  check((status='DECLINED')=(decline_reason is not null))
);

create table private.rfq_command_keys (
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  operation_scope text not null check(operation_scope in ('rfq.request.create','rfq.request.ready','rfq.matching.run','rfq.open','rfq.invitation.respond')),
  key text not null check(length(key) between 8 and 200),
  request_hash text not null check(request_hash ~ '^[0-9a-f]{64}$'),
  response_body jsonb,
  command_id uuid not null default extensions.gen_random_uuid() unique,
  created_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  primary key(actor_user_id,operation_scope,key),
  check((response_body is null)=(completed_at is null))
);

create or replace function private.prevent_rfq_snapshot_mutation() returns trigger language plpgsql security definer set search_path=pg_catalog as $$begin raise exception 'IMMUTABLE_RFQ_SNAPSHOT' using errcode='55000';end$$;
revoke all on function private.prevent_rfq_snapshot_mutation() from public,anon,authenticated,service_role;
create trigger service_request_versions_immutable before update or delete on public.service_request_versions for each row execute function private.prevent_rfq_snapshot_mutation();
create trigger matching_candidates_immutable before update or delete on public.matching_candidates for each row execute function private.prevent_rfq_snapshot_mutation();
create trigger matching_policy_versions_immutable before update or delete on public.matching_policy_versions for each row execute function private.prevent_rfq_snapshot_mutation();

create or replace function private.begin_rfq_command(p_actor uuid,p_scope text,p_key text,p_hash text) returns table(command_id uuid,response_body jsonb)
language plpgsql security definer set search_path=pg_catalog as $$declare v private.rfq_command_keys%rowtype;begin
 if p_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';end if;
 if length(coalesce(p_key,''))<8 or p_hash!~'^[0-9a-f]{64}$' then raise exception 'INVALID_COMMAND_IDENTITY' using errcode='22023';end if;
 insert into private.rfq_command_keys(actor_user_id,operation_scope,key,request_hash)values(p_actor,p_scope,p_key,p_hash)on conflict do nothing;
 select * into v from private.rfq_command_keys k where k.actor_user_id=p_actor and k.operation_scope=p_scope and k.key=p_key for update;
 if v.request_hash<>p_hash then raise exception 'IDEMPOTENCY_KEY_REUSED' using errcode='22000';end if;
 return query select v.command_id,v.response_body;
end$$;
create or replace function private.finish_rfq_command(p_actor uuid,p_scope text,p_key text,p_response jsonb) returns void language plpgsql security definer set search_path=pg_catalog as $$begin update private.rfq_command_keys set response_body=p_response,completed_at=clock_timestamp()where actor_user_id=p_actor and operation_scope=p_scope and key=p_key;end$$;
revoke all on function private.begin_rfq_command(uuid,text,text,text),private.finish_rfq_command(uuid,text,text,jsonb) from public,anon,authenticated,service_role;

create or replace function private.can_manage_client_request(p_organization_id uuid,p_actor uuid default auth.uid()) returns boolean language sql stable security definer set search_path=pg_catalog as $$
 select private.has_org_role(p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],p_actor) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],p_actor)
$$;
create or replace function private.is_provider_actor(p_provider_organization_id uuid,p_actor uuid default auth.uid()) returns boolean language sql stable security definer set search_path=pg_catalog as $$
 select private.has_org_role(p_provider_organization_id,array['PROVIDER_OWNER','PROVIDER_MANAGER','PROVIDER_SALES'],p_actor)
$$;
create or replace function private.can_read_service_request(p_request_id uuid,p_actor uuid default auth.uid()) returns boolean language sql stable security definer set search_path=pg_catalog as $$
 select exists(select 1 from public.service_requests r where r.id=p_request_id and private.is_active_org_member(r.client_organization_id,p_actor))
 or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'],p_actor)
 or exists(select 1 from public.rfqs q join public.rfq_providers rp on rp.rfq_id=q.id where q.request_id=p_request_id and private.is_active_org_member(rp.provider_organization_id,p_actor))
$$;
revoke all on function private.can_manage_client_request(uuid,uuid),private.is_provider_actor(uuid,uuid),private.can_read_service_request(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function private.can_manage_client_request(uuid,uuid),private.is_provider_actor(uuid,uuid),private.can_read_service_request(uuid,uuid) to authenticated;

create or replace function public.create_service_request(p_client_organization_id uuid,p_library_id uuid,p_service_id uuid,p_questionnaire_version_id uuid,p_payload jsonb,p_change_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$declare v_actor uuid:=auth.uid();v_hash text;v_command uuid;v_replay jsonb;v_request uuid:=extensions.gen_random_uuid();v_version uuid:=extensions.gen_random_uuid();v_content text;v_complete boolean;v_response jsonb;begin
 if not private.can_manage_client_request(p_client_organization_id,v_actor) then raise exception 'REQUEST_SCOPE_DENIED' using errcode='42501';end if;
 if not exists(select 1 from public.catalog_services s where s.id=p_service_id and s.library_id=p_library_id and s.status<>'ARCHIVED') then raise exception 'SERVICE_NOT_AVAILABLE' using errcode='22023';end if;
 if jsonb_typeof(p_payload)<>'object' or length(btrim(coalesce(p_payload->>'description','')))<10 or coalesce(p_payload->>'urgency','') not in('LOW','NORMAL','HIGH','CRITICAL') or coalesce(p_payload->>'catalog_snapshot_hash','')!~'^[0-9a-f]{64}$' or coalesce(p_payload->>'questionnaire_snapshot_hash','')!~'^[0-9a-f]{64}$' then raise exception 'INVALID_REQUEST_PAYLOAD' using errcode='22023';end if;
 v_complete:=coalesce((p_payload->>'required_fields_complete')::boolean,false);
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','rfq.request.create.v1','organization_id',p_client_organization_id,'library_id',p_library_id,'service_id',p_service_id,'questionnaire_version_id',p_questionnaire_version_id,'payload',p_payload,'reason',btrim(p_change_reason))::text,'UTF8'),'sha256'),'hex');
 select b.command_id,b.response_body into v_command,v_replay from private.begin_rfq_command(v_actor,'rfq.request.create',p_idempotency_key,v_hash)b;if v_replay is not null then return v_replay;end if;
 v_content:=encode(extensions.digest(convert_to(jsonb_build_object('request_id',v_request,'version',1,'payload',p_payload)::text,'UTF8'),'sha256'),'hex');
 insert into public.service_requests(id,client_organization_id,site_id,library_id,service_id,questionnaire_version_id,status,created_by)values(v_request,p_client_organization_id,nullif(p_payload->>'site_id','')::uuid,p_library_id,p_service_id,p_questionnaire_version_id,case when v_complete and p_questionnaire_version_id is not null then 'DRAFT' else 'INFORMATION_REQUIRED' end,v_actor);
 insert into public.service_request_versions(id,request_id,client_organization_id,library_id,version_number,description,urgency,desired_date,budget_minor,currency_code,required_quote_data,required_fields_complete,catalog_snapshot_hash,questionnaire_snapshot_hash,change_reason,content_hash,created_by)values(v_version,v_request,p_client_organization_id,p_library_id,1,btrim(p_payload->>'description'),p_payload->>'urgency',nullif(p_payload->>'desired_date','')::date,nullif(p_payload->>'budget_minor','')::bigint,coalesce(nullif(p_payload->>'currency_code',''),'MAD'),coalesce(p_payload->'required_quote_data','{}'::jsonb),v_complete,p_payload->>'catalog_snapshot_hash',p_payload->>'questionnaire_snapshot_hash',btrim(p_change_reason),v_content,v_actor);
 update public.service_requests set current_version_id=v_version where id=v_request;
 v_response:=jsonb_build_object('outcome','SERVICE_REQUEST_CREATED','request_id',v_request,'request_version_id',v_version,'status',case when v_complete and p_questionnaire_version_id is not null then 'DRAFT' else 'INFORMATION_REQUIRED' end,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_client_organization_id,v_actor,'USER','rfq.request.created','service_request',v_request::text,p_correlation_id,jsonb_build_object('request_version_id',v_version,'service_id',p_service_id,'command_id',v_command),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(p_client_organization_id,'service_request',v_request::text,'ServiceRequestCreatedV1',p_correlation_id,jsonb_build_object('request_id',v_request,'request_version_id',v_version,'service_id',p_service_id),p_idempotency_key,v_command);
 perform private.finish_rfq_command(v_actor,'rfq.request.create',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.mark_service_request_ready(p_request_id uuid,p_expected_row_version integer,p_change_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$declare v_actor uuid:=auth.uid();v_request public.service_requests%rowtype;v_version public.service_request_versions%rowtype;v_hash text;v_command uuid;v_replay jsonb;v_response jsonb;begin
 select * into v_request from public.service_requests where id=p_request_id;if not found or not private.can_manage_client_request(v_request.client_organization_id,v_actor) then raise exception 'REQUEST_SCOPE_DENIED' using errcode='42501';end if;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','rfq.request.ready.v1','request_id',p_request_id,'expected',p_expected_row_version,'reason',btrim(p_change_reason))::text,'UTF8'),'sha256'),'hex');select b.command_id,b.response_body into v_command,v_replay from private.begin_rfq_command(v_actor,'rfq.request.ready',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('service-request:'||p_request_id::text,0));select * into v_request from public.service_requests where id=p_request_id for update;if v_replay is not null then return v_replay;end if;
 if v_request.row_version<>p_expected_row_version then raise exception 'STALE_REQUEST_VERSION' using errcode='40001';end if;if v_request.status not in('DRAFT','INFORMATION_REQUIRED') then raise exception 'INVALID_REQUEST_TRANSITION' using errcode='55000';end if;
 select * into v_version from public.service_request_versions where id=v_request.current_version_id;if not v_version.required_fields_complete or v_request.questionnaire_version_id is null or coalesce(v_version.required_quote_data->>'region_code','')='' then raise exception 'REQUEST_INFORMATION_INCOMPLETE' using errcode='23514';end if;
 update public.service_requests set status='READY',updated_at=clock_timestamp(),row_version=row_version+1 where id=p_request_id;
 v_response:=jsonb_build_object('outcome','SERVICE_REQUEST_READY','request_id',p_request_id,'request_version_id',v_version.id,'status','READY','row_version',p_expected_row_version+1,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_request.client_organization_id,v_actor,'USER','rfq.request.ready','service_request',p_request_id::text,p_correlation_id,jsonb_build_object('request_version_id',v_version.id,'command_id',v_command,'change_reason',btrim(p_change_reason)),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(v_request.client_organization_id,'service_request',p_request_id::text,'REQUEST_READY',p_correlation_id,jsonb_build_object('request_id',p_request_id,'request_version_id',v_version.id),p_idempotency_key,v_command);perform private.finish_rfq_command(v_actor,'rfq.request.ready',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.run_service_request_matching(p_request_id uuid,p_policy_version text,p_target_panel_size integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$declare v_actor uuid:=auth.uid();v_request public.service_requests%rowtype;v_version public.service_request_versions%rowtype;v_policy public.matching_policy_versions%rowtype;v_hash text;v_command uuid;v_replay jsonb;v_run uuid:=extensions.gen_random_uuid();v_eligible integer;v_response jsonb;begin
 select * into v_request from public.service_requests where id=p_request_id;if not found or not private.can_manage_client_request(v_request.client_organization_id,v_actor) then raise exception 'REQUEST_SCOPE_DENIED' using errcode='42501';end if;
 select * into v_policy from public.matching_policy_versions where policy_version=p_policy_version and statement_timestamp()>=effective_from and(effective_until is null or statement_timestamp()<effective_until);if not found then raise exception 'MATCHING_POLICY_NOT_ACTIVE' using errcode='22023';end if;
 if p_target_panel_size is not null and p_target_panel_size not between 1 and 100 then raise exception 'INVALID_PANEL_TARGET' using errcode='22023';end if;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','rfq.matching.run.v1','request_id',p_request_id,'policy',p_policy_version,'target',coalesce(p_target_panel_size,v_policy.target_panel_size))::text,'UTF8'),'sha256'),'hex');select b.command_id,b.response_body into v_command,v_replay from private.begin_rfq_command(v_actor,'rfq.matching.run',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('service-request:'||p_request_id::text,0));select * into v_request from public.service_requests where id=p_request_id for update;if v_replay is not null then return v_replay;end if;if v_request.status<>'READY' then raise exception 'REQUEST_NOT_READY' using errcode='55000';end if;select * into v_version from public.service_request_versions where id=v_request.current_version_id;
 insert into public.matching_runs(id,request_id,request_version_id,policy_version,target_panel_size,started_by)values(v_run,p_request_id,v_version.id,p_policy_version,coalesce(p_target_panel_size,v_policy.target_panel_size),v_actor);
 with profiles as(select sp.*,p.company_verified,p.documents_valid,p.financial_status,p.quality_status,p.capacity_status,p.region_codes,p.partner_contract_signed,o.status organization_status,
   greatest(0,100-least(100,10*(select count(*) from public.rfq_providers prior where prior.provider_organization_id=p.provider_organization_id and prior.invited_at>=statement_timestamp()-interval '90 days')))::smallint rotation_score
   from public.provider_service_match_profiles sp join public.provider_match_profiles p using(provider_organization_id) join public.organizations o on o.id=p.provider_organization_id where sp.service_id=v_request.service_id), evaluated as(select x.*,array_remove(array[
   case when organization_status<>'ACTIVE'then'ORGANIZATION_INACTIVE'end,case when provider_organization_id=v_request.client_organization_id then'SAME_ORGANIZATION'end,case when not company_verified then'COMPANY_NOT_VERIFIED'end,case when qualification_status<>'APPROVED'then'SERVICE_NOT_APPROVED'end,case when not documents_valid then'DOCUMENTS_INVALID'end,case when financial_status<>'OK'then'FINANCIAL_RESTRICTED'end,case when quality_status<>'OK'then'QUALITY_RESTRICTED'end,case when not(coalesce(v_version.required_quote_data->>'region_code','')=any(region_codes))then'REGION_MISMATCH'end,case when capacity_status not in('AVAILABLE','LIMITED')then'CAPACITY_UNAVAILABLE'end,case when not required_certifications_valid then'CERTIFICATIONS_INVALID'end,case when not partner_contract_signed then'PARTNER_CONTRACT_UNSIGNED'end],null)::text[] reasons from profiles x)
 insert into public.matching_candidates(matching_run_id,provider_organization_id,eligible,exclusion_reasons,score_basis_points,score_explanation,rotation_component)
 select v_run,provider_organization_id,cardinality(reasons)=0,reasons,(service_fit_score*30+quality_score*20+(case capacity_status when'AVAILABLE'then 100 when'LIMITED'then 50 else 0 end)*15+historical_delay_score*10+experience_score*10+rotation_score*10+satisfaction_score*5),jsonb_build_object('policy_version',p_policy_version,'service_fit',jsonb_build_object('value',service_fit_score,'weight',30),'quality',jsonb_build_object('value',quality_score,'weight',20),'availability',jsonb_build_object('value',case capacity_status when'AVAILABLE'then 100 when'LIMITED'then 50 else 0 end,'weight',15),'historical_delay',jsonb_build_object('value',historical_delay_score,'weight',10),'experience',jsonb_build_object('value',experience_score,'weight',10),'fair_rotation',jsonb_build_object('value',rotation_score,'weight',10),'satisfaction',jsonb_build_object('value',satisfaction_score,'weight',5),'exclusion_reasons',to_jsonb(reasons)),rotation_score from evaluated;
 select count(*) into v_eligible from public.matching_candidates where matching_run_id=v_run and eligible;
 update public.matching_runs set status=case when v_eligible=0 then'NO_CANDIDATE'else'COMPLETED'end,completed_at=clock_timestamp()where id=v_run;update public.service_requests set status=case when v_eligible=0 then'NO_PROVIDER_AVAILABLE'else'MATCHING'end,updated_at=clock_timestamp(),row_version=row_version+1 where id=p_request_id;
 v_response:=jsonb_build_object('outcome',case when v_eligible=0 then'NO_MATCHING_PROVIDER'else'MATCHING_COMPLETED'end,'request_id',p_request_id,'matching_run_id',v_run,'eligible_count',v_eligible,'evaluated_count',(select count(*)from public.matching_candidates where matching_run_id=v_run),'policy_version',p_policy_version,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_request.client_organization_id,v_actor,'USER','rfq.matching.completed','matching_run',v_run::text,p_correlation_id,jsonb_build_object('request_id',p_request_id,'eligible_count',v_eligible,'policy_version',p_policy_version,'command_id',v_command),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(v_request.client_organization_id,'matching_run',v_run::text,case when v_eligible=0 then'NO_MATCHING_PROVIDER'else'MATCHING_COMPLETED'end,p_correlation_id,jsonb_build_object('request_id',p_request_id,'matching_run_id',v_run,'eligible_count',v_eligible,'policy_version',p_policy_version),p_idempotency_key,v_command);perform private.finish_rfq_command(v_actor,'rfq.matching.run',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.open_service_request_rfq(p_request_id uuid,p_matching_run_id uuid,p_deadline timestamptz,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$declare v_actor uuid:=auth.uid();v_request public.service_requests%rowtype;v_run public.matching_runs%rowtype;v_hash text;v_command uuid;v_replay jsonb;v_rfq uuid:=extensions.gen_random_uuid();v_invited integer;v_response jsonb;begin
 select * into v_request from public.service_requests where id=p_request_id;if not found or not private.can_manage_client_request(v_request.client_organization_id,v_actor) then raise exception 'REQUEST_SCOPE_DENIED' using errcode='42501';end if;if p_deadline<=statement_timestamp()+interval '1 hour' then raise exception 'INVALID_RFQ_DEADLINE' using errcode='22023';end if;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','rfq.open.v1','request_id',p_request_id,'matching_run_id',p_matching_run_id,'deadline',p_deadline)::text,'UTF8'),'sha256'),'hex');select b.command_id,b.response_body into v_command,v_replay from private.begin_rfq_command(v_actor,'rfq.open',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('service-request:'||p_request_id::text,0));select * into v_request from public.service_requests where id=p_request_id for update;if v_replay is not null then return v_replay;end if;if v_request.status<>'MATCHING' then raise exception 'REQUEST_NOT_MATCHED' using errcode='55000';end if;select * into v_run from public.matching_runs where id=p_matching_run_id and request_id=p_request_id and request_version_id=v_request.current_version_id and status='COMPLETED';if not found then raise exception 'MATCHING_RUN_NOT_OPENABLE' using errcode='55000';end if;
 insert into public.rfqs(id,request_id,request_version_id,matching_run_id,deadline,invited_count,opened_by)values(v_rfq,p_request_id,v_request.current_version_id,p_matching_run_id,p_deadline,0,v_actor);
 insert into public.rfq_providers(rfq_id,provider_organization_id,matching_candidate_id)
 select v_rfq,c.provider_organization_id,c.id from public.matching_candidates c join public.provider_match_profiles p on p.provider_organization_id=c.provider_organization_id join public.provider_service_match_profiles sp on sp.provider_organization_id=c.provider_organization_id and sp.service_id=v_request.service_id join public.organizations o on o.id=c.provider_organization_id where c.matching_run_id=p_matching_run_id and c.eligible and o.status='ACTIVE'and p.company_verified and p.documents_valid and p.financial_status='OK'and p.quality_status='OK'and p.capacity_status in('AVAILABLE','LIMITED')and p.partner_contract_signed and sp.qualification_status='APPROVED'and sp.required_certifications_valid order by c.score_basis_points desc,c.rotation_component desc,c.provider_organization_id limit v_run.target_panel_size;
 get diagnostics v_invited=row_count;if v_invited=0 then raise exception 'NO_CURRENTLY_ELIGIBLE_PROVIDER' using errcode='55000';end if;update public.rfqs set invited_count=v_invited where id=v_rfq;update public.service_requests set status='RFQ_OPEN',updated_at=clock_timestamp(),row_version=row_version+1 where id=p_request_id;
 v_response:=jsonb_build_object('outcome','RFQ_OPENED','request_id',p_request_id,'rfq_id',v_rfq,'matching_run_id',p_matching_run_id,'invited_count',v_invited,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_request.client_organization_id,v_actor,'USER','rfq.opened','rfq',v_rfq::text,p_correlation_id,jsonb_build_object('request_id',p_request_id,'matching_run_id',p_matching_run_id,'invited_count',v_invited,'command_id',v_command),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(v_request.client_organization_id,'rfq',v_rfq::text,'RFQ_OPENED',p_correlation_id,jsonb_build_object('request_id',p_request_id,'rfq_id',v_rfq,'invited_count',v_invited,'deadline',p_deadline),p_idempotency_key,v_command);perform private.finish_rfq_command(v_actor,'rfq.open',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.respond_to_rfq_invitation(p_rfq_provider_id uuid,p_decision text,p_reason text,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$declare v_actor uuid:=auth.uid();v_invite public.rfq_providers%rowtype;v_rfq public.rfqs%rowtype;v_request public.service_requests%rowtype;v_hash text;v_command uuid;v_replay jsonb;v_response jsonb;begin
 select * into v_invite from public.rfq_providers where id=p_rfq_provider_id;if not found or not private.is_provider_actor(v_invite.provider_organization_id,v_actor) then raise exception 'RFQ_INVITATION_SCOPE_DENIED' using errcode='42501';end if;if p_decision not in('ACCEPT','DECLINE')or(p_decision='DECLINE'and length(btrim(coalesce(p_reason,'')))<3)then raise exception 'INVALID_INVITATION_DECISION' using errcode='22023';end if;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','rfq.invitation.respond.v1','invitation_id',p_rfq_provider_id,'decision',p_decision,'reason',nullif(btrim(coalesce(p_reason,'')),''),'expected',p_expected_row_version)::text,'UTF8'),'sha256'),'hex');select b.command_id,b.response_body into v_command,v_replay from private.begin_rfq_command(v_actor,'rfq.invitation.respond',p_idempotency_key,v_hash)b;perform pg_advisory_xact_lock(hashtextextended('rfq-invitation:'||p_rfq_provider_id::text,0));select * into v_invite from public.rfq_providers where id=p_rfq_provider_id for update;if v_replay is not null then return v_replay;end if;if v_invite.row_version<>p_expected_row_version then raise exception 'STALE_INVITATION_VERSION' using errcode='40001';end if;if v_invite.status<>'INVITED' then raise exception 'INVITATION_ALREADY_RESPONDED' using errcode='55000';end if;select * into v_rfq from public.rfqs where id=v_invite.rfq_id;if v_rfq.status<>'OPEN'or v_rfq.deadline<=statement_timestamp()then raise exception 'RFQ_NOT_OPEN' using errcode='55000';end if;select * into v_request from public.service_requests where id=v_rfq.request_id;
 update public.rfq_providers set status=case when p_decision='ACCEPT'then'ACCEPTED'else'DECLINED'end,responded_at=clock_timestamp(),decline_reason=case when p_decision='DECLINE'then btrim(p_reason)else null end,row_version=row_version+1 where id=p_rfq_provider_id;
 v_response:=jsonb_build_object('outcome',case when p_decision='ACCEPT'then'RFQ_INVITATION_ACCEPTED'else'RFQ_INVITATION_DECLINED'end,'rfq_provider_id',p_rfq_provider_id,'rfq_id',v_rfq.id,'row_version',p_expected_row_version+1,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_invite.provider_organization_id,v_actor,'USER',case when p_decision='ACCEPT'then'rfq.invitation.accepted'else'rfq.invitation.declined'end,'rfq_provider',p_rfq_provider_id::text,p_correlation_id,jsonb_build_object('rfq_id',v_rfq.id,'client_organization_id',v_request.client_organization_id,'command_id',v_command,'reason_recorded',p_decision='DECLINE'),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(v_invite.provider_organization_id,'rfq_provider',p_rfq_provider_id::text,case when p_decision='ACCEPT'then'RFQ_INVITATION_ACCEPTED'else'RFQ_INVITATION_DECLINED'end,p_correlation_id,jsonb_build_object('rfq_id',v_rfq.id,'rfq_provider_id',p_rfq_provider_id,'provider_organization_id',v_invite.provider_organization_id),p_idempotency_key,v_command);perform private.finish_rfq_command(v_actor,'rfq.invitation.respond',p_idempotency_key,v_response);return v_response;
end$$;

alter table public.provider_match_profiles enable row level security;alter table public.provider_service_match_profiles enable row level security;alter table public.service_requests enable row level security;alter table public.service_request_versions enable row level security;alter table public.matching_policy_versions enable row level security;alter table public.matching_runs enable row level security;alter table public.matching_candidates enable row level security;alter table public.rfqs enable row level security;alter table public.rfq_providers enable row level security;
create policy provider_match_profiles_own_read on public.provider_match_profiles for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy provider_service_match_profiles_own_read on public.provider_service_match_profiles for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy service_requests_authorized_read on public.service_requests for select to authenticated using(private.can_read_service_request(id));
create policy service_request_versions_authorized_read on public.service_request_versions for select to authenticated using(private.can_read_service_request(request_id));
create policy matching_policy_versions_authenticated_read on public.matching_policy_versions for select to authenticated using(true);
create policy matching_runs_client_read on public.matching_runs for select to authenticated using(private.can_manage_client_request((select r.client_organization_id from public.service_requests r where r.id=request_id))or private.has_platform_role(array['READ_ONLY_AUDITOR']));
create policy matching_candidates_client_read on public.matching_candidates for select to authenticated using(exists(select 1 from public.matching_runs mr join public.service_requests r on r.id=mr.request_id where mr.id=matching_run_id and(private.can_manage_client_request(r.client_organization_id)or private.has_platform_role(array['READ_ONLY_AUDITOR']))));
create policy rfqs_authorized_read on public.rfqs for select to authenticated using(private.can_read_service_request(request_id));
create policy rfq_providers_scoped_read on public.rfq_providers for select to authenticated using(private.is_active_org_member(provider_organization_id)or exists(select 1 from public.rfqs q join public.service_requests r on r.id=q.request_id where q.id=rfq_id and private.can_manage_client_request(r.client_organization_id))or private.has_platform_role(array['READ_ONLY_AUDITOR']));

revoke all on public.provider_match_profiles,public.provider_service_match_profiles,public.service_requests,public.service_request_versions,public.matching_policy_versions,public.matching_runs,public.matching_candidates,public.rfqs,public.rfq_providers from anon,authenticated,service_role;
grant select on public.provider_match_profiles,public.provider_service_match_profiles,public.service_requests,public.service_request_versions,public.matching_policy_versions,public.matching_runs,public.matching_candidates,public.rfqs,public.rfq_providers to authenticated;
grant execute on function public.create_service_request(uuid,uuid,uuid,uuid,jsonb,text,text,uuid),public.mark_service_request_ready(uuid,integer,text,text,uuid),public.run_service_request_matching(uuid,text,integer,text,uuid),public.open_service_request_rfq(uuid,uuid,timestamptz,text,uuid),public.respond_to_rfq_invitation(uuid,text,text,integer,text,uuid) to authenticated;
revoke all on function public.create_service_request(uuid,uuid,uuid,uuid,jsonb,text,text,uuid),public.mark_service_request_ready(uuid,integer,text,text,uuid),public.run_service_request_matching(uuid,text,integer,text,uuid),public.open_service_request_rfq(uuid,uuid,timestamptz,text,uuid),public.respond_to_rfq_invitation(uuid,text,text,integer,text,uuid) from public,anon,service_role;

create index provider_service_match_profiles_service_idx on public.provider_service_match_profiles(service_id,qualification_status,provider_organization_id);
create index service_requests_client_status_idx on public.service_requests(client_organization_id,status,created_at desc);
create index matching_runs_request_idx on public.matching_runs(request_id,started_at desc);
create index matching_candidates_rank_idx on public.matching_candidates(matching_run_id,eligible,score_basis_points desc,rotation_component desc);
create index rfqs_request_status_idx on public.rfqs(request_id,status,deadline);
create index rfq_providers_provider_status_idx on public.rfq_providers(provider_organization_id,status,invited_at desc);
