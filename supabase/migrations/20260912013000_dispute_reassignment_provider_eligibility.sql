-- P11 hardening: authoritative provider eligibility and bounded reassignment candidates.

create or replace function private.dispute_target_service(p_dispute_case_id uuid)
returns uuid language sql stable security definer
set search_path=pg_catalog,public as $function$
  select sr.service_id
  from public.dispute_cases d
  join public.contract_versions cv on cv.id=d.contract_version_id
  join public.quote_versions qv on qv.id=cv.selected_quote_version_id
  join public.quotes q on q.id=qv.quote_id
  join public.rfqs r on r.id=q.rfq_id
  join public.service_requests sr on sr.id=r.request_id
  where d.id=p_dispute_case_id
$function$;

create or replace function private.provider_service_eligibility_snapshot(p_provider_organization_id uuid,p_service_id uuid)
returns jsonb language plpgsql stable security definer
set search_path=pg_catalog,public,private as $function$
declare
  v_organization public.organizations%rowtype;
  v_profile public.provider_match_profiles%rowtype;
  v_service public.provider_service_match_profiles%rowtype;
  v_capacity text;
  v_reasons text[]:='{}';
begin
  select * into v_organization from public.organizations where id=p_provider_organization_id;
  select * into v_profile from public.provider_match_profiles where provider_organization_id=p_provider_organization_id;
  select * into v_service from public.provider_service_match_profiles where provider_organization_id=p_provider_organization_id and service_id=p_service_id;
  select c.capacity_status into v_capacity
  from public.provider_capacity_versions c
  where c.provider_organization_id=p_provider_organization_id
    and (c.service_id=p_service_id or c.service_id is null)
    and c.effective_from<=statement_timestamp()
    and (c.effective_until is null or c.effective_until>statement_timestamp())
  order by (c.service_id is not null) desc,c.version_number desc limit 1;

  if v_organization.id is null or v_organization.status<>'ACTIVE' then v_reasons:=array_append(v_reasons,'ORGANIZATION_INACTIVE');end if;
  if v_profile.provider_organization_id is null then
    v_reasons:=array_append(v_reasons,'PROFILE_MISSING');
  else
    if not v_profile.company_verified then v_reasons:=array_append(v_reasons,'COMPANY_NOT_VERIFIED');end if;
    if not v_profile.documents_valid then v_reasons:=array_append(v_reasons,'DOCUMENTS_INVALID');end if;
    if v_profile.financial_status<>'OK' then v_reasons:=array_append(v_reasons,'FINANCIAL_RESTRICTED');end if;
    if v_profile.quality_status<>'OK' then v_reasons:=array_append(v_reasons,'QUALITY_RESTRICTED');end if;
    if not v_profile.partner_contract_signed then v_reasons:=array_append(v_reasons,'PARTNER_CONTRACT_UNSIGNED');end if;
  end if;
  if v_service.id is null then
    v_reasons:=array_append(v_reasons,'SERVICE_NOT_REQUESTED');
  else
    if v_service.qualification_status<>'APPROVED' then v_reasons:=array_append(v_reasons,'QUALIFICATION_'||v_service.qualification_status);end if;
    if not v_service.required_certifications_valid then v_reasons:=array_append(v_reasons,'CERTIFICATIONS_INVALID');end if;
  end if;
  if v_capacity is null then v_reasons:=array_append(v_reasons,'CAPACITY_NOT_DECLARED');
  elsif v_capacity not in('AVAILABLE','LIMITED') then v_reasons:=array_append(v_reasons,'CAPACITY_'||v_capacity);end if;
  if exists(
    select 1 from public.provider_restriction_decisions r
    where r.provider_organization_id=p_provider_organization_id
      and (r.service_id is null or r.service_id=p_service_id)
      and r.action='IMPOSED'
      and not exists(
        select 1 from public.provider_restriction_decisions newer
        where newer.provider_organization_id=r.provider_organization_id
          and newer.service_id is not distinct from r.service_id
          and newer.restriction_type=r.restriction_type
          and newer.decision_version>r.decision_version
      )
  ) then v_reasons:=array_append(v_reasons,'ACTIVE_HUMAN_RESTRICTION');end if;

  return jsonb_build_object(
    'eligible',cardinality(v_reasons)=0,
    'provider_organization_id',p_provider_organization_id,
    'service_id',p_service_id,
    'reasons',to_jsonb(v_reasons),
    'qualification_status',coalesce(v_service.qualification_status,'NOT_REQUESTED'),
    'capacity_status',coalesce(v_capacity,'NOT_DECLARED'),
    'checked_at',statement_timestamp()
  );
end
$function$;

create or replace function public.explain_provider_service_eligibility(p_provider_organization_id uuid,p_service_id uuid)
returns jsonb language plpgsql stable security definer
set search_path=pg_catalog,public,private as $function$
declare v_actor uuid:=auth.uid();begin
  if not(private.is_active_org_member(p_provider_organization_id,v_actor)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','DISPUTE_MANAGER','READ_ONLY_AUDITOR'],v_actor))then
    raise exception 'PROVIDER_ELIGIBILITY_SCOPE_DENIED' using errcode='42501';
  end if;
  return private.provider_service_eligibility_snapshot(p_provider_organization_id,p_service_id);
end
$function$;

create or replace function public.list_dispute_reassignment_candidates(p_reassignment_id uuid,p_limit integer default 30)
returns jsonb language plpgsql stable security definer
set search_path=pg_catalog,public,private as $function$
declare
  v_actor uuid:=auth.uid();v_reassignment public.mission_reassignments%rowtype;v_case public.dispute_cases%rowtype;v_service uuid;v_candidates jsonb;
begin
  select * into v_reassignment from public.mission_reassignments where id=p_reassignment_id;
  select * into v_case from public.dispute_cases where id=v_reassignment.dispute_case_id;
  if v_actor is null or v_reassignment.id is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','DISPUTE_MANAGER'],v_actor)then
    raise exception 'REASSIGNMENT_CANDIDATES_DENIED' using errcode='42501';
  end if;
  if v_reassignment.status<>'OPEN' or p_limit not between 1 and 50 then raise exception 'INVALID_REASSIGNMENT_CANDIDATE_QUERY' using errcode='22023';end if;
  v_service:=private.dispute_target_service(v_case.id);
  if v_service is null then raise exception 'DISPUTE_TARGET_SERVICE_NOT_FOUND' using errcode='P0002';end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'organization_id',candidate.provider_organization_id,
    'display_name',candidate.display_name,
    'qualification_status',candidate.eligibility->>'qualification_status',
    'capacity_status',candidate.eligibility->>'capacity_status'
  ) order by candidate.display_name,candidate.provider_organization_id),'[]'::jsonb) into v_candidates
  from (
    select sp.provider_organization_id,o.display_name,private.provider_service_eligibility_snapshot(sp.provider_organization_id,v_service) eligibility
    from public.provider_service_match_profiles sp
    join public.organizations o on o.id=sp.provider_organization_id
    where sp.service_id=v_service
      and sp.provider_organization_id not in(v_case.client_organization_id,v_case.provider_organization_id)
    order by sp.service_fit_score desc,sp.quality_score desc,sp.provider_organization_id
    limit p_limit
  ) candidate
  where (candidate.eligibility->>'eligible')::boolean;
  return jsonb_build_object('service_id',v_service,'candidates',v_candidates);
end
$function$;

create or replace function public.propose_mission_reassignment(p_reassignment_id uuid,p_provider_organization_id uuid,p_pricing_mode text,p_quote_version_id uuid,p_proposed_cost_minor bigint,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $function$
declare a uuid:=auth.uid();x public.mission_reassignments%rowtype;d public.dispute_cases%rowtype;h text;r jsonb;delta bigint;v_service uuid;v_eligibility jsonb;begin
 select * into x from public.mission_reassignments where id=p_reassignment_id;select * into d from public.dispute_cases where id=x.dispute_case_id;
 if a is null or not found or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','DISPUTE_MANAGER'],a)then raise exception 'REASSIGNMENT_PROPOSE_DENIED' using errcode='42501';end if;
 v_service:=private.dispute_target_service(d.id);v_eligibility:=private.provider_service_eligibility_snapshot(p_provider_organization_id,v_service);
 if x.status<>'OPEN'or x.row_version<>p_expected_row_version or v_service is null or p_provider_organization_id in(d.client_organization_id,d.provider_organization_id)or coalesce((v_eligibility->>'eligible')::boolean,false)is not true or p_pricing_mode not in('FRAMEWORK_RATE','NEW_QUOTE')or p_proposed_cost_minor<0 or(p_pricing_mode='NEW_QUOTE'and p_quote_version_id is null)then raise exception 'INVALID_REASSIGNMENT_PROPOSAL' using errcode='22023';end if;
 delta:=p_proposed_cost_minor-x.original_cost_minor;h:=private.canonical_request_hash(jsonb_build_object('reassignment',x.id,'service',v_service,'provider',p_provider_organization_id,'eligibility',v_eligibility,'mode',p_pricing_mode,'quote',p_quote_version_id,'cost',p_proposed_cost_minor,'expected',p_expected_row_version));r:=private.begin_contract_command(d.client_organization_id,'reassignment.propose.'||x.id::text,p_idempotency_key,h,a);if r is not null then return r;end if;
 update public.mission_reassignments set proposed_provider_organization_id=p_provider_organization_id,pricing_mode=p_pricing_mode,proposed_quote_version_id=p_quote_version_id,proposed_cost_minor=p_proposed_cost_minor,cost_delta_minor=delta,status=case when delta>0 then'AWAITING_CLIENT_APPROVAL'else'APPROVED'end,updated_at=clock_timestamp(),row_version=row_version+1 where id=x.id and row_version=p_expected_row_version;if not found then raise exception 'STALE_REASSIGNMENT' using errcode='40001';end if;
 r:=jsonb_build_object('outcome',case when delta>0 then'CLIENT_APPROVAL_REQUIRED'else'REASSIGNMENT_APPROVED'end,'reassignment_id',x.id,'service_id',v_service,'provider_organization_id',p_provider_organization_id,'cost_delta_minor',delta);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(d.client_organization_id,a,'USER','reassignment.proposed','mission_reassignment',x.id::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(d.client_organization_id,'mission_reassignment',x.id::text,case when delta>0 then'ReassignmentClientApprovalRequiredV1'else'ReassignmentApprovedV1'end,p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(d.client_organization_id,'reassignment.propose.'||x.id::text,p_idempotency_key,r);return r;
end
$function$;

create or replace function public.respond_to_mission_dispute(p_dispute_case_id uuid,p_response_type text,p_statement text,p_evidence jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $function$
declare a uuid:=auth.uid();d public.dispute_cases%rowtype;h text;r jsonb;begin select * into d from public.dispute_cases where id=p_dispute_case_id;if a is null or not found or not private.has_org_role(d.provider_organization_id,array['PROVIDER_OWNER','PROVIDER_MANAGER'],a)then raise exception 'DISPUTE_RESPONSE_DENIED' using errcode='42501';end if;if d.status<>'WARNING_LEVEL_1'or p_response_type not in('ACKNOWLEDGE_AND_CORRECT','CONTEST','OUT_OF_SCOPE')or length(btrim(coalesce(p_statement,'')))not between 10 and 4000 or jsonb_typeof(p_evidence)<>'array'then raise exception 'INVALID_DISPUTE_RESPONSE' using errcode='22023';end if;h:=private.canonical_request_hash(jsonb_build_object('case',d.id,'type',p_response_type,'statement',p_statement,'evidence',p_evidence));r:=private.begin_contract_command(d.client_organization_id,'dispute.respond.'||d.id::text,p_idempotency_key,h,a);if r is not null then return r;end if;select * into d from public.dispute_cases where id=d.id for update;if d.status<>'WARNING_LEVEL_1'then raise exception 'STALE_DISPUTE_STATE' using errcode='40001';end if;insert into public.dispute_responses(dispute_case_id,response_type,statement,submitted_by)values(d.id,p_response_type,p_statement,a);perform private.append_dispute_evidence(d.id,p_evidence,a,d.provider_organization_id);update public.dispute_cases set status='MEDIATION_REVIEW',review_due_at=clock_timestamp()+make_interval(days=>(policy_snapshot->>'review_business_days')::integer),row_version=row_version+1 where id=d.id;insert into public.dispute_case_events(dispute_case_id,event_type,from_status,to_status,actor_user_id,correlation_id,metadata)values(d.id,'PROVIDER_RESPONSE','WARNING_LEVEL_1','PROVIDER_RESPONDED',a,p_correlation_id,jsonb_build_object('response_type',p_response_type)),(d.id,'MEDIATION_STARTED','PROVIDER_RESPONDED','MEDIATION_REVIEW',a,p_correlation_id,jsonb_build_object('automatic_queueing',true));r:=jsonb_build_object('outcome','MEDIATION_REVIEW','dispute_case_id',d.id);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(d.client_organization_id,a,'USER','dispute.responded','dispute_case',d.id::text,p_correlation_id,jsonb_build_object('response_type',p_response_type,'contradictory_status','PROVIDER_RESPONDED'),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(d.client_organization_id,'dispute_case',d.id::text,'DisputeResponseSubmittedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(d.client_organization_id,'dispute.respond.'||d.id::text,p_idempotency_key,r);return r;end
$function$;

revoke all on function private.dispute_target_service(uuid),private.provider_service_eligibility_snapshot(uuid,uuid) from public,anon,authenticated,service_role;
revoke all on function public.list_dispute_reassignment_candidates(uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.list_dispute_reassignment_candidates(uuid,integer) to authenticated;
revoke all on function public.explain_provider_service_eligibility(uuid,uuid),public.propose_mission_reassignment(uuid,uuid,text,uuid,bigint,integer,text,uuid),public.respond_to_mission_dispute(uuid,text,text,jsonb,text,uuid) from public,anon,service_role;
grant execute on function public.explain_provider_service_eligibility(uuid,uuid),public.propose_mission_reassignment(uuid,uuid,text,uuid,bigint,integer,text,uuid),public.respond_to_mission_dispute(uuid,text,text,jsonb,text,uuid) to authenticated;

notify pgrst,'reload schema';
