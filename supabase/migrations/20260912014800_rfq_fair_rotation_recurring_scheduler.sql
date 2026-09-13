-- MAT-FUNC-019 / MAT-FUNC-050: concurrent fair rotation and bounded recurring scheduler.

create index if not exists rfq_providers_provider_invited_idx
on public.rfq_providers(provider_organization_id, invited_at desc);

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
 where c.matching_run_id=p_matching_run_id and c.eligible and o.status='ACTIVE'and p.company_verified and p.documents_valid and p.financial_status='OK'and p.quality_status='OK'and p.capacity_status in('AVAILABLE','LIMITED')and p.partner_contract_signed and sp.qualification_status='APPROVED'and sp.required_certifications_valid
 order by (c.score_basis_points-(c.rotation_component::integer*10)) desc,history.invitation_count asc,history.last_invited_at asc nulls first,c.provider_organization_id
 limit v_run.target_panel_size;
 get diagnostics v_invited=row_count;if v_invited=0 then raise exception 'NO_CURRENTLY_ELIGIBLE_PROVIDER' using errcode='55000';end if;update public.rfqs set invited_count=v_invited where id=v_rfq;update public.service_requests set status='RFQ_OPEN',updated_at=clock_timestamp(),row_version=row_version+1 where id=p_request_id;
 v_response:=jsonb_build_object('outcome','RFQ_OPENED','request_id',p_request_id,'rfq_id',v_rfq,'matching_run_id',p_matching_run_id,'invited_count',v_invited,'fair_rotation_policy','FAIR-ROTATION-90D-V2','command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_request.client_organization_id,v_actor,'USER','rfq.opened','rfq',v_rfq::text,p_correlation_id,jsonb_build_object('request_id',p_request_id,'matching_run_id',p_matching_run_id,'invited_count',v_invited,'fair_rotation_policy','FAIR-ROTATION-90D-V2','command_id',v_command),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(v_request.client_organization_id,'rfq',v_rfq::text,'RFQ_OPENED',p_correlation_id,jsonb_build_object('request_id',p_request_id,'rfq_id',v_rfq,'invited_count',v_invited,'deadline',p_deadline,'fair_rotation_policy','FAIR-ROTATION-90D-V2'),p_idempotency_key,v_command);perform private.finish_rfq_command(v_actor,'rfq.open',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.schedule_recurring_service_requests(p_as_of date default current_date,p_limit integer default 100) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare candidate record;plan_row public.recurring_service_plans%rowtype;version_row public.recurring_service_plan_versions%rowtype;generated jsonb;next_date date;months integer;processed integer:=0;created integer:=0;skipped integer:=0;correlation uuid;
begin
 if auth.role()<>'service_role' then raise exception 'RECURRING_SCHEDULER_DENIED' using errcode='42501';end if;
 if p_as_of is null or p_as_of<current_date-1 or p_as_of>current_date+31 or p_limit not between 1 and 500 then raise exception 'INVALID_RECURRING_SCHEDULER_BOUNDS' using errcode='22023';end if;
 for candidate in
  select p.id,m.user_id actor_user_id
  from public.recurring_service_plans p
  join public.recurring_service_plan_versions v on v.plan_id=p.id and v.version_number=p.current_version and v.status='ACTIVE'
  join lateral(select om.user_id from public.organization_memberships om join public.organization_member_roles r on r.membership_id=om.id and r.revoked_at is null and r.role_code in('CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER') where om.organization_id=p.client_organization_id and om.status='ACTIVE' order by case r.role_code when'CLIENT_OWNER'then 1 when'CLIENT_ADMIN'then 2 else 3 end,om.user_id limit 1)m on true
  where p.status='ACTIVE'and v.starts_on<=p_as_of and(v.ends_on is null or v.ends_on>=p_as_of)
  order by p.id limit p_limit
 loop
  processed:=processed+1;perform pg_advisory_xact_lock(hashtextextended('recurring-plan:'||candidate.id::text,0));select * into plan_row from public.recurring_service_plans where id=candidate.id and status='ACTIVE' for update;if not found then skipped:=skipped+1;continue;end if;
  select * into version_row from public.recurring_service_plan_versions where plan_id=plan_row.id and version_number=plan_row.current_version and status='ACTIVE';months:=case version_row.cadence when'MONTHLY'then 1 when'QUARTERLY'then 3 when'ANNUALLY'then 12 else null end;if months is null then skipped:=skipped+1;continue;end if;
  next_date:=version_row.starts_on;while next_date<=p_as_of and(version_row.ends_on is null or next_date<=version_row.ends_on) loop
   if not exists(select 1 from public.recurring_service_occurrences occurrence where occurrence.plan_id=plan_row.id and occurrence.scheduled_on=next_date)then
    generated:=private.clone_request_core(plan_row.template_request_id,next_date,candidate.actor_user_id,'Génération planifiée automatique',false);
    insert into public.recurring_service_occurrences(plan_id,plan_version_id,client_organization_id,scheduled_on,generated_request_id,generated_request_version_id)values(plan_row.id,version_row.id,plan_row.client_organization_id,next_date,(generated->>'request_id')::uuid,(generated->>'request_version_id')::uuid)on conflict(plan_id,scheduled_on)do nothing;
    if found then created:=created+1;correlation:=extensions.gen_random_uuid();insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(plan_row.client_organization_id,candidate.actor_user_id,'SYSTEM','recurring.requests.scheduled','recurring_service_plan',plan_row.id::text,correlation,jsonb_build_object('scheduled_on',next_date,'plan_version_id',version_row.id,'autonomous_invitations',false,'autonomous_spend',false),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(plan_row.client_organization_id,'recurring_service_plan',plan_row.id::text,'RecurringServiceRequestScheduledV1',correlation,jsonb_build_object('plan_id',plan_row.id,'request_id',generated->>'request_id','scheduled_on',next_date,'autonomous_invitations',false,'autonomous_spend',false),'recurring-scheduler:'||plan_row.id::text||':'||next_date::text)on conflict do nothing;end if;
   end if;
   next_date:=(next_date+make_interval(months=>months))::date;
  end loop;
 end loop;
 return jsonb_build_object('outcome','RECURRING_SCHEDULER_COMPLETED','as_of',p_as_of,'processed_plans',processed,'created_drafts',created,'skipped_plans',skipped,'autonomous_invitations',false,'autonomous_spend',false);
end$$;

revoke all on function public.open_service_request_rfq(uuid,uuid,timestamptz,text,uuid),public.schedule_recurring_service_requests(date,integer) from public,anon,authenticated,service_role;
grant execute on function public.open_service_request_rfq(uuid,uuid,timestamptz,text,uuid) to authenticated;
grant execute on function public.schedule_recurring_service_requests(date,integer) to service_role;
notify pgrst,'reload schema';
