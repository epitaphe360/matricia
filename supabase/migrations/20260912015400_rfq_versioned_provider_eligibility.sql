-- MAT-FUNC-018/020: authoritative time-aware eligibility from immutable Provider evidence.
begin;

create or replace function private.provider_service_eligibility_snapshot(p_provider_organization_id uuid,p_service_id uuid)
returns jsonb language plpgsql stable security definer set search_path=pg_catalog,public,private as $$
declare company public.provider_company_decisions%rowtype;service_row public.provider_services%rowtype;qualification public.provider_qualification_decisions%rowtype;capacity text;reasons text[]:='{}';kind text;
begin
 if not exists(select 1 from public.organizations o where o.id=p_provider_organization_id and o.status='ACTIVE')then reasons:=array_append(reasons,'ORGANIZATION_INACTIVE');end if;
 select * into company from public.provider_company_decisions d where d.provider_organization_id=p_provider_organization_id order by d.decision_version desc limit 1;
 if company.id is null or company.company_status<>'VERIFIED'then reasons:=array_append(reasons,'COMPANY_NOT_VERIFIED');end if;
 if company.id is null or company.partner_contract_status<>'SIGNED'or(company.partner_contract_expires_at is not null and company.partner_contract_expires_at<=statement_timestamp())then reasons:=array_append(reasons,'PARTNER_CONTRACT_INVALID');end if;
 foreach kind in array array['LEGAL','FISCAL','INSURANCE'] loop
  if not exists(select 1 from public.provider_document_families family join lateral(select version.* from public.provider_document_versions version where version.family_id=family.id order by version.version_number desc limit 1)latest on true where family.provider_organization_id=p_provider_organization_id and family.document_kind=kind and latest.status='VERIFIED'and(latest.expires_on is null or latest.expires_on>current_date))then reasons:=array_append(reasons,'DOCUMENT_'||kind||'_INVALID');end if;
 end loop;
 select * into service_row from public.provider_services s where s.provider_organization_id=p_provider_organization_id and s.service_id=p_service_id;
 if service_row.id is null then reasons:=array_append(reasons,'SERVICE_NOT_REQUESTED');else
  select decision.* into qualification from public.provider_qualifications aggregate join public.provider_qualification_decisions decision on decision.id=aggregate.current_decision_id and decision.qualification_id=aggregate.id where aggregate.provider_organization_id=p_provider_organization_id and aggregate.service_id=p_service_id;
  if qualification.id is null then reasons:=array_append(reasons,'QUALIFICATION_NOT_DECIDED');elsif qualification.status<>'APPROVED'then reasons:=array_append(reasons,'QUALIFICATION_'||qualification.status);elsif qualification.expires_at is not null and qualification.expires_at<=statement_timestamp()then reasons:=array_append(reasons,'QUALIFICATION_EXPIRED');elsif not exists(select 1 from public.questionnaire_sessions session where session.id=qualification.questionnaire_session_id and session.organization_id=p_provider_organization_id and session.questionnaire_version_id=qualification.questionnaire_version_id and session.status='SUBMITTED'and not session.is_simulation)then reasons:=array_append(reasons,'QUALIFICATION_EVIDENCE_INVALID');end if;
  if exists(select 1 from public.provider_document_service_links link join public.provider_document_versions document on document.id=link.document_version_id where link.provider_service_id=service_row.id and link.is_mandatory and(document.status<>'VERIFIED'or(document.expires_on is not null and document.expires_on<=current_date)))then reasons:=array_append(reasons,'MANDATORY_DOCUMENT_INVALID');end if;
 end if;
 select version.capacity_status into capacity from public.provider_capacity_versions version where version.provider_organization_id=p_provider_organization_id and(version.service_id=p_service_id or version.service_id is null)and version.effective_from<=statement_timestamp()and(version.effective_until is null or version.effective_until>statement_timestamp())order by(version.service_id is not null)desc,version.version_number desc limit 1;
 if capacity is null then reasons:=array_append(reasons,'CAPACITY_NOT_DECLARED');elsif capacity not in('AVAILABLE','LIMITED')then reasons:=array_append(reasons,'CAPACITY_'||capacity);end if;
 if exists(select 1 from public.provider_restriction_decisions restriction where restriction.provider_organization_id=p_provider_organization_id and(restriction.service_id is null or restriction.service_id=p_service_id)and restriction.action='IMPOSED'and not exists(select 1 from public.provider_restriction_decisions newer where newer.provider_organization_id=restriction.provider_organization_id and newer.service_id is not distinct from restriction.service_id and newer.restriction_type=restriction.restriction_type and newer.decision_version>restriction.decision_version))then reasons:=array_append(reasons,'ACTIVE_HUMAN_RESTRICTION');end if;
 return jsonb_build_object('eligible',cardinality(reasons)=0,'provider_organization_id',p_provider_organization_id,'service_id',p_service_id,'reasons',to_jsonb(reasons),'qualification_status',coalesce(qualification.status,'NOT_REQUESTED'),'qualification_decision_version',qualification.decision_version,'capacity_status',coalesce(capacity,'NOT_DECLARED'),'company_decision_version',company.decision_version,'checked_at',statement_timestamp());
end$$;
revoke all on function private.provider_service_eligibility_snapshot(uuid,uuid) from public,anon,authenticated,service_role;

create or replace function private.enforce_rfq_invitation_current_eligibility() returns trigger
language plpgsql security definer set search_path=pg_catalog,public,private as $$
declare request_row public.service_requests%rowtype;request_version public.service_request_versions%rowtype;rfq_row public.rfqs%rowtype;evidence jsonb;
begin
 select * into rfq_row from public.rfqs where id=new.rfq_id;select * into request_row from public.service_requests where id=rfq_row.request_id;select * into request_version from public.service_request_versions where id=request_row.current_version_id and request_id=request_row.id;evidence:=private.provider_service_eligibility_snapshot(new.provider_organization_id,request_row.service_id);
 if rfq_row.id is null or request_row.id is null or request_version.id is null or coalesce((rfq_row.confidentiality_settings->>'mask_direct_contacts')::boolean,false)is not true or new.provider_organization_id=request_row.client_organization_id or not coalesce((evidence->>'eligible')::boolean,false)or coalesce(request_version.required_quote_data->>'region_code','')<>all(coalesce((select profile.region_codes from public.provider_match_profiles profile where profile.provider_organization_id=new.provider_organization_id),'{}'::text[]))or not exists(select 1 from public.matching_candidates candidate where candidate.id=new.matching_candidate_id and candidate.matching_run_id=rfq_row.matching_run_id and candidate.provider_organization_id=new.provider_organization_id and candidate.eligible)then raise exception 'RFQ_PROVIDER_NOT_CURRENTLY_ELIGIBLE' using errcode='23514';end if;
 return new;
end$$;
revoke all on function private.enforce_rfq_invitation_current_eligibility() from public,anon,authenticated,service_role;

commit;


begin;

create or replace function public.open_service_request_rfq(p_request_id uuid,p_matching_run_id uuid,p_deadline timestamptz,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$
declare v_actor uuid:=auth.uid();v_request public.service_requests%rowtype;v_run public.matching_runs%rowtype;v_hash text;v_command uuid;v_replay jsonb;v_rfq uuid:=extensions.gen_random_uuid();v_invited integer;v_response jsonb;
begin
 select * into v_request from public.service_requests where id=p_request_id;if not found or not private.can_manage_client_request(v_request.client_organization_id,v_actor) then raise exception 'REQUEST_SCOPE_DENIED' using errcode='42501';end if;if p_deadline<=statement_timestamp()+interval '1 hour' then raise exception 'INVALID_RFQ_DEADLINE' using errcode='22023';end if;
 v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','rfq.open.v2','request_id',p_request_id,'matching_run_id',p_matching_run_id,'deadline',p_deadline)::text,'UTF8'),'sha256'),'hex');select b.command_id,b.response_body into v_command,v_replay from private.begin_rfq_command(v_actor,'rfq.open',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('service-request:'||p_request_id::text,0));select * into v_request from public.service_requests where id=p_request_id for update;if v_replay is not null then return v_replay;end if;if v_request.status<>'MATCHING' then raise exception 'REQUEST_NOT_MATCHED' using errcode='55000';end if;select * into v_run from public.matching_runs where id=p_matching_run_id and request_id=p_request_id and request_version_id=v_request.current_version_id and status='COMPLETED';if not found then raise exception 'MATCHING_RUN_NOT_OPENABLE' using errcode='55000';end if;
 -- Different requests for the same service share this lock: invitation history cannot be
 -- read concurrently and award the same tie to the same provider twice.
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
notify pgrst,'reload schema';
commit;
