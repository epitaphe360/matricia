-- Client site inheritance on questionnaire sessions and missions,
-- and entitlement gate when opening an RFQ on an existing matched request.
-- start_questionnaire_session keeps 6-arg callers via a default null site_id.

drop function if exists public.start_questionnaire_session(uuid, uuid, text, timestamptz, text, uuid);

create or replace function public.start_questionnaire_session(
  p_organization_id uuid,
  p_questionnaire_version_id uuid,
  p_locale text,
  p_due_at timestamptz,
  p_idempotency_key text,
  p_correlation_id uuid,
  p_site_id uuid default null
) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$
declare a uuid:=auth.uid();v public.questionnaire_versions%rowtype;k private.questionnaire_command_keys%rowtype;h text;s uuid;ss uuid;r jsonb;cmd uuid;payload jsonb;begin
  if a is null then raise exception 'AUTHENTICATION_REQUIRED'using errcode='42501';end if;
  if p_correlation_id is null or length(p_idempotency_key)not between 8 and 200 or p_locale not in('fr-MA','ar-MA')then raise exception 'INVALID_SESSION_REQUEST'using errcode='22023';end if;
  perform pg_advisory_xact_lock(hashtextextended(a::text||':questionnaire.session.start:'||p_idempotency_key,0));
  select*into v from public.questionnaire_versions where id=p_questionnaire_version_id;
  if not found or v.status<>'PUBLISHED'or not private.can_read_catalog_release(v.catalog_release_id,a)or not exists(select 1 from public.questionnaires q where q.id=v.questionnaire_id and q.status='PUBLISHED'and q.current_published_version_id=v.id)or not exists(select 1 from public.catalog_releases x where x.id=v.catalog_release_id and x.status='PUBLISHED'and statement_timestamp()>=x.effective_from and(x.effective_until is null or statement_timestamp()<x.effective_until)and(x.audience->>'kind'='PUBLIC'or(x.audience->>'kind'='ORGANIZATIONS'and coalesce(x.audience->'organization_ids','[]')?p_organization_id::text)))then raise exception 'QUESTIONNAIRE_NOT_AVAILABLE'using errcode='42501';end if;
  if not private.has_questionnaire_audience_access(p_organization_id,v.library_id,v.audience,'START',a)then raise exception 'ORGANIZATION_SCOPE_DENIED'using errcode='42501';end if;
  if p_due_at is not null and p_due_at<=statement_timestamp()then raise exception 'INVALID_SESSION_DUE_AT'using errcode='22023';end if;
  if p_site_id is not null then
    if v.audience<>'CLIENT' then raise exception 'SITE_NOT_APPLICABLE' using errcode='22023'; end if;
    if not exists(select 1 from public.client_sites site where site.id=p_site_id and site.organization_id=p_organization_id and site.status='ACTIVE') then raise exception 'SITE_SCOPE_DENIED' using errcode='42501'; end if;
  end if;
  payload:=jsonb_build_object('organization_id',p_organization_id,'questionnaire_version_id',p_questionnaire_version_id,'locale',p_locale,'due_at',p_due_at);
  if p_site_id is not null then payload:=payload||jsonb_build_object('site_id',p_site_id); end if;
  h:=encode(extensions.digest(convert_to(payload::text,'UTF8'),'sha256'),'hex');
  select*into k from private.questionnaire_command_keys where actor_user_id=a and operation_scope='questionnaire.session.start'and key=p_idempotency_key for update;
  if found then if k.request_hash<>h then raise exception 'IDEMPOTENCY_KEY_REUSED'using errcode='23505';end if;return k.response_body;end if;
  insert into private.questionnaire_command_keys values(a,'questionnaire.session.start',p_idempotency_key,h,null,clock_timestamp(),null,default)returning command_id into cmd;
  insert into public.questionnaire_sessions(organization_id,actor_user_id,library_id,catalog_release_id,questionnaire_version_id,audience,locale,status,due_at,site_id)values(p_organization_id,a,v.library_id,v.catalog_release_id,v.id,v.audience,p_locale,'DRAFT',p_due_at,p_site_id)returning id into s;
  ss:=private.create_questionnaire_session_snapshot(s);
  insert into public.questionnaire_session_state_events(session_id,organization_id,from_status,to_status,reason_code,actor_user_id,correlation_id,idempotency_key)values(s,p_organization_id,null,'DRAFT','SESSION_STARTED',a,p_correlation_id,p_idempotency_key);
  r:=jsonb_build_object('outcome','QUESTIONNAIRE_SESSION_STARTED','session_id',s,'row_version',1,'questionnaire_version_id',v.id,'session_snapshot_id',ss,'session_snapshot_hash',(select snapshot_hash from public.questionnaire_session_snapshots where id=ss));
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,a,'USER','questionnaire.session.started','questionnaire_session',s::text,p_correlation_id,jsonb_build_object('questionnaire_version_id',v.id,'session_snapshot_id',ss,'site_id',p_site_id),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(p_organization_id,'questionnaire_session',s::text,'QuestionnaireSessionStartedV1',p_correlation_id,r,p_idempotency_key,cmd);
  update private.questionnaire_command_keys set response_body=r,completed_at=clock_timestamp()where actor_user_id=a and operation_scope='questionnaire.session.start'and key=p_idempotency_key;return r;
end$$;

revoke all on function public.start_questionnaire_session(uuid,uuid,text,timestamptz,text,uuid,uuid) from public, anon, authenticated, service_role;
grant execute on function public.start_questionnaire_session(uuid,uuid,text,timestamptz,text,uuid,uuid) to authenticated;

create or replace function public.open_service_request_rfq(p_request_id uuid,p_matching_run_id uuid,p_deadline timestamptz,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$
declare v_actor uuid:=auth.uid();v_request public.service_requests%rowtype;v_run public.matching_runs%rowtype;v_hash text;v_command uuid;v_replay jsonb;v_rfq uuid:=extensions.gen_random_uuid();v_invited integer;v_response jsonb;
begin
 select * into v_request from public.service_requests where id=p_request_id;if not found or not private.can_manage_client_request(v_request.client_organization_id,v_actor) then raise exception 'REQUEST_SCOPE_DENIED' using errcode='42501';end if;
 if not private.client_may_open_new_service_request(v_request.client_organization_id) then raise exception 'CLIENT_REQUEST_NOT_ENTITLED' using errcode='42501';end if;
 if p_deadline<=statement_timestamp()+interval '1 hour' then raise exception 'INVALID_RFQ_DEADLINE' using errcode='22023';end if;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','rfq.open.v2','request_id',p_request_id,'matching_run_id',p_matching_run_id,'deadline',p_deadline)::text,'UTF8'),'sha256'),'hex');select b.command_id,b.response_body into v_command,v_replay from private.begin_rfq_command(v_actor,'rfq.open',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('service-request:'||p_request_id::text,0));select * into v_request from public.service_requests where id=p_request_id for update;if v_replay is not null then return v_replay;end if;if v_request.status<>'MATCHING' then raise exception 'REQUEST_NOT_MATCHED' using errcode='55000';end if;select * into v_run from public.matching_runs where id=p_matching_run_id and request_id=p_request_id and request_version_id=v_request.current_version_id and status='COMPLETED';if not found then raise exception 'MATCHING_RUN_NOT_OPENABLE' using errcode='55000';end if;
 perform pg_advisory_xact_lock(hashtextextended('rfq-fair-rotation:'||v_request.service_id::text,0));
 insert into public.rfqs(id,request_id,request_version_id,matching_run_id,deadline,invited_count,opened_by)values(v_rfq,p_request_id,v_request.current_version_id,p_matching_run_id,p_deadline,0,v_actor);
 insert into public.rfq_providers(rfq_id,provider_organization_id,matching_candidate_id)
 select v_rfq,c.provider_organization_id,c.id
 from public.matching_candidates c
 join public.provider_match_profiles p on p.provider_organization_id=c.provider_organization_id
 join public.provider_service_match_profiles sp on sp.provider_organization_id=c.provider_organization_id and sp.service_id=v_request.service_id
 join public.organizations o on o.id=c.provider_organization_id
 left join lateral(select count(*)::integer invitation_count,max(prior.invited_at) last_invited_at from public.rfq_providers prior where prior.provider_organization_id=c.provider_organization_id and prior.invited_at>=statement_timestamp()-interval '90 days') history on true
 where c.matching_run_id=p_matching_run_id and c.eligible and o.status='ACTIVE'and p.company_verified and p.documents_valid and p.financial_status='OK'and p.quality_status='OK'and p.capacity_status in('AVAILABLE','LIMITED')and p.partner_contract_signed and sp.qualification_status='APPROVED'and sp.required_certifications_valid and (private.provider_service_eligibility_snapshot(c.provider_organization_id,v_request.service_id)->>'eligible')::boolean and coalesce((select version.required_quote_data->>'region_code' from public.service_request_versions version where version.id=v_request.current_version_id),'')=any(p.region_codes)
 order by (c.score_basis_points-(c.rotation_component::integer*10)) desc,history.invitation_count asc,history.last_invited_at asc nulls first,c.provider_organization_id
 limit v_run.target_panel_size;
 get diagnostics v_invited=row_count;if v_invited=0 then raise exception 'NO_CURRENTLY_ELIGIBLE_PROVIDER' using errcode='55000';end if;update public.rfqs set invited_count=v_invited where id=v_rfq;update public.service_requests set status='RFQ_OPEN',updated_at=clock_timestamp(),row_version=row_version+1 where id=p_request_id;
 v_response:=jsonb_build_object('outcome','RFQ_OPENED','request_id',p_request_id,'rfq_id',v_rfq,'matching_run_id',p_matching_run_id,'invited_count',v_invited,'fair_rotation_policy','FAIR-ROTATION-90D-V2','command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_request.client_organization_id,v_actor,'USER','rfq.opened','rfq',v_rfq::text,p_correlation_id,jsonb_build_object('request_id',p_request_id,'matching_run_id',p_matching_run_id,'invited_count',v_invited,'fair_rotation_policy','FAIR-ROTATION-90D-V2','command_id',v_command),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(v_request.client_organization_id,'rfq',v_rfq::text,'RFQ_OPENED',p_correlation_id,jsonb_build_object('request_id',p_request_id,'rfq_id',v_rfq,'invited_count',v_invited,'deadline',p_deadline,'fair_rotation_policy','FAIR-ROTATION-90D-V2'),p_idempotency_key,v_command);perform private.finish_rfq_command(v_actor,'rfq.open',p_idempotency_key,v_response);return v_response;
end$$;

revoke all on function public.open_service_request_rfq(uuid,uuid,timestamptz,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.open_service_request_rfq(uuid,uuid,timestamptz,text,uuid) to authenticated;

alter table public.missions add column if not exists site_id uuid;
do $$begin
  if not exists (select 1 from pg_constraint where conname='missions_site_organization_fk') then
    alter table public.missions
      add constraint missions_site_organization_fk
      foreign key (site_id, client_organization_id)
      references public.client_sites(id, organization_id)
      on delete restrict;
  end if;
end$$;
create index if not exists missions_site_idx on public.missions(site_id) where site_id is not null;

create or replace function public.create_mission(p_contract_id uuid,p_contract_version_id uuid,p_milestones jsonb,p_deliverables jsonb,p_acceptance_criteria jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare r jsonb;s public.mission_checklist_snapshots%rowtype;t public.service_checklist_templates%rowtype;sv public.catalog_service_versions%rowtype;cs public.catalog_services%rowtype;
begin
 r:=public.create_mission_legacy_0191(p_contract_id,p_contract_version_id,p_milestones,p_deliverables,p_acceptance_criteria,p_idempotency_key,p_correlation_id);
 select * into s from public.mission_checklist_snapshots where mission_id=nullif(r->>'mission_id','')::uuid;
 select * into t from public.service_checklist_templates where id=s.service_checklist_template_id;
 select * into sv from public.catalog_service_versions where id=s.service_version_id;
 select * into cs from public.catalog_services where id=sv.service_id;
 if s.id is null or t.publication_status<>'PUBLISHED' or t.published_at is null or t.published_by is null or not private.valid_published_checklist_items_v1(t.items) or sv.status<>'PUBLISHED' or cs.current_published_version_id is distinct from sv.id then raise exception'MISSION_EXECUTABLE_PUBLISHED_CHECKLIST_REQUIRED'using errcode='55000';end if;
 update public.missions mission
    set site_id = request.site_id
   from public.contract_versions version
   join public.quote_versions quote_version on quote_version.id = version.selected_quote_version_id
   join public.quotes quote on quote.id = quote_version.quote_id
   join public.rfqs rfq on rfq.id = quote.rfq_id
   join public.service_requests request on request.id = rfq.request_id
  where mission.id = nullif(r->>'mission_id','')::uuid
    and version.id = p_contract_version_id
    and request.site_id is not null
    and request.client_organization_id = mission.client_organization_id
    and exists (select 1 from public.client_sites site where site.id = request.site_id and site.organization_id = mission.client_organization_id);
 return r;
end$$;

revoke all on function public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid) from public,anon,service_role;
grant execute on function public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid) to authenticated;

update public.missions mission
   set site_id = request.site_id
  from public.contract_versions version
  join public.quote_versions quote_version on quote_version.id = version.selected_quote_version_id
  join public.quotes quote on quote.id = quote_version.quote_id
  join public.rfqs rfq on rfq.id = quote.rfq_id
  join public.service_requests request on request.id = rfq.request_id
 where mission.contract_version_id = version.id
   and mission.site_id is null
   and request.site_id is not null
   and request.client_organization_id = mission.client_organization_id
   and exists (select 1 from public.client_sites site where site.id = request.site_id and site.organization_id = mission.client_organization_id);

notify pgrst,'reload schema';
