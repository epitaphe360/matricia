-- ADM-035 / criterion 73: a Matricia invoice past due_on with outstanding
-- balance blocks new RFQ opportunities. Existing missions stay unchanged.
-- The hold is derived; financial_status is not mutated.

create or replace function private.provider_has_overdue_matricia_invoice(p_provider_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.provider_invoices invoice
    left join (
      select allocation.invoice_id, sum(allocation.amount_minor)::bigint as paid_minor
      from public.provider_payment_allocations allocation
      group by allocation.invoice_id
    ) paid on paid.invoice_id = invoice.id
    where invoice.provider_organization_id = p_provider_organization_id
      and invoice.due_on < current_date
      and invoice.total_minor - coalesce(paid.paid_minor, 0) > 0
  );
$$;

revoke all on function private.provider_has_overdue_matricia_invoice(uuid)
  from public, anon, authenticated, service_role;

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
  if qualification.id is null then reasons:=array_append(reasons,'QUALIFICATION_NOT_DECIDED');elsif qualification.effective_from is null or qualification.effective_from>statement_timestamp()then reasons:=array_append(reasons,'QUALIFICATION_NOT_EFFECTIVE');elsif qualification.status<>'APPROVED'then reasons:=array_append(reasons,'QUALIFICATION_'||qualification.status);elsif qualification.expires_at is not null and qualification.expires_at<=statement_timestamp()then reasons:=array_append(reasons,'QUALIFICATION_EXPIRED');elsif not exists(select 1 from public.questionnaire_sessions session where session.id=qualification.questionnaire_session_id and session.organization_id=p_provider_organization_id and session.questionnaire_version_id=qualification.questionnaire_version_id and session.status='SUBMITTED'and not session.is_simulation)then reasons:=array_append(reasons,'QUALIFICATION_EVIDENCE_INVALID');end if;
  if exists(select 1 from public.provider_document_service_links link join public.provider_document_versions document on document.id=link.document_version_id where link.provider_service_id=service_row.id and link.is_mandatory and(document.status<>'VERIFIED'or(document.expires_on is not null and document.expires_on<=current_date)))then reasons:=array_append(reasons,'MANDATORY_DOCUMENT_INVALID');end if;
 end if;
 select version.capacity_status into capacity from public.provider_capacity_versions version where version.provider_organization_id=p_provider_organization_id and(version.service_id=p_service_id or version.service_id is null)and version.effective_from<=statement_timestamp()and(version.effective_until is null or version.effective_until>statement_timestamp())order by(version.service_id is not null)desc,version.version_number desc limit 1;
 if capacity is null then reasons:=array_append(reasons,'CAPACITY_NOT_DECLARED');elsif capacity not in('AVAILABLE','LIMITED')then reasons:=array_append(reasons,'CAPACITY_'||capacity);end if;
 if exists(select 1 from public.provider_restriction_decisions restriction where restriction.provider_organization_id=p_provider_organization_id and(restriction.service_id is null or restriction.service_id=p_service_id)and restriction.action='IMPOSED'and not exists(select 1 from public.provider_restriction_decisions newer where newer.provider_organization_id=restriction.provider_organization_id and newer.service_id is not distinct from restriction.service_id and newer.restriction_type=restriction.restriction_type and newer.decision_version>restriction.decision_version))then reasons:=array_append(reasons,'ACTIVE_HUMAN_RESTRICTION');end if;
 if private.provider_has_overdue_matricia_invoice(p_provider_organization_id) then reasons:=array_append(reasons,'OVERDUE_INVOICE');end if;
 return jsonb_build_object('eligible',cardinality(reasons)=0,'provider_organization_id',p_provider_organization_id,'service_id',p_service_id,'reasons',to_jsonb(reasons),'qualification_status',coalesce(qualification.status,'NOT_REQUESTED'),'qualification_decision_version',qualification.decision_version,'capacity_status',coalesce(capacity,'NOT_DECLARED'),'company_decision_version',company.decision_version,'checked_at',statement_timestamp());
end$$;
revoke all on function private.provider_service_eligibility_snapshot(uuid,uuid) from public,anon,authenticated,service_role;

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
   case when organization_status<>'ACTIVE'then'ORGANIZATION_INACTIVE'end,case when provider_organization_id=v_request.client_organization_id then'SAME_ORGANIZATION'end,case when not company_verified then'COMPANY_NOT_VERIFIED'end,case when qualification_status<>'APPROVED'then'SERVICE_NOT_APPROVED'end,case when not documents_valid then'DOCUMENTS_INVALID'end,case when financial_status<>'OK'then'FINANCIAL_RESTRICTED'end,case when private.provider_has_overdue_matricia_invoice(provider_organization_id) then'OVERDUE_INVOICE'end,case when quality_status<>'OK'then'QUALITY_RESTRICTED'end,case when not(coalesce(v_version.required_quote_data->>'region_code','')=any(region_codes))then'REGION_MISMATCH'end,case when capacity_status not in('AVAILABLE','LIMITED')then'CAPACITY_UNAVAILABLE'end,case when not required_certifications_valid then'CERTIFICATIONS_INVALID'end,case when not partner_contract_signed then'PARTNER_CONTRACT_UNSIGNED'end],null)::text[] reasons from profiles x)
 insert into public.matching_candidates(matching_run_id,provider_organization_id,eligible,exclusion_reasons,score_basis_points,score_explanation,rotation_component)
 select v_run,provider_organization_id,cardinality(reasons)=0,reasons,(service_fit_score*30+quality_score*20+(case capacity_status when'AVAILABLE'then 100 when'LIMITED'then 50 else 0 end)*15+historical_delay_score*10+experience_score*10+rotation_score*10+satisfaction_score*5),jsonb_build_object('policy_version',p_policy_version,'service_fit',jsonb_build_object('value',service_fit_score,'weight',30),'quality',jsonb_build_object('value',quality_score,'weight',20),'availability',jsonb_build_object('value',case capacity_status when'AVAILABLE'then 100 when'LIMITED'then 50 else 0 end,'weight',15),'historical_delay',jsonb_build_object('value',historical_delay_score,'weight',10),'experience',jsonb_build_object('value',experience_score,'weight',10),'fair_rotation',jsonb_build_object('value',rotation_score,'weight',10),'satisfaction',jsonb_build_object('value',satisfaction_score,'weight',5),'exclusion_reasons',to_jsonb(reasons)),rotation_score from evaluated;
 select count(*) into v_eligible from public.matching_candidates where matching_run_id=v_run and eligible;
 update public.matching_runs set status=case when v_eligible=0 then'NO_CANDIDATE'else'COMPLETED'end,completed_at=clock_timestamp()where id=v_run;update public.service_requests set status=case when v_eligible=0 then'NO_PROVIDER_AVAILABLE'else'MATCHING'end,updated_at=clock_timestamp(),row_version=row_version+1 where id=p_request_id;
 v_response:=jsonb_build_object('outcome',case when v_eligible=0 then'NO_MATCHING_PROVIDER'else'MATCHING_COMPLETED'end,'request_id',p_request_id,'matching_run_id',v_run,'eligible_count',v_eligible,'evaluated_count',(select count(*)from public.matching_candidates where matching_run_id=v_run),'policy_version',p_policy_version,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_request.client_organization_id,v_actor,'USER','rfq.matching.completed','matching_run',v_run::text,p_correlation_id,jsonb_build_object('request_id',p_request_id,'eligible_count',v_eligible,'policy_version',p_policy_version,'command_id',v_command),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(v_request.client_organization_id,'matching_run',v_run::text,case when v_eligible=0 then'NO_MATCHING_PROVIDER'else'MATCHING_COMPLETED'end,p_correlation_id,jsonb_build_object('request_id',p_request_id,'matching_run_id',v_run,'eligible_count',v_eligible,'policy_version',p_policy_version),p_idempotency_key,v_command);perform private.finish_rfq_command(v_actor,'rfq.matching.run',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.list_admin_provider_closure_dashboard(p_limit integer default 100)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  lim integer := greatest(1, least(coalesce(p_limit, 100), 200));
begin
  if actor is null or not private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'FINANCE_MANAGER', 'READ_ONLY_AUDITOR'], actor) then
    raise exception 'ADMIN_CLOSURE_DENIED' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'generated_at', clock_timestamp(),
    'capabilities', jsonb_build_object(
      'can_issue_statement', private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'FINANCE_MANAGER'], actor)
    ),
    'unstatemented', coalesce((
      select jsonb_agg(jsonb_build_object(
        'provider_organization_id', x.provider_organization_id,
        'organization_name', o.display_name,
        'currency', x.currency,
        'event_count', x.event_count,
        'subtotal_minor', x.subtotal_minor::text,
        'tax_minor', x.tax_minor::text,
        'total_minor', (x.subtotal_minor + x.tax_minor)::text
      ) order by o.display_name)
      from (
        select e.provider_organization_id, e.currency, count(*)::integer as event_count,
               coalesce(sum(e.commission_amount_minor), 0)::bigint as subtotal_minor,
               coalesce(sum(e.tax_amount_minor), 0)::bigint as tax_minor
        from public.provider_payable_events e
        where not exists (select 1 from public.provider_statement_lines l where l.payable_event_id = e.id)
        group by e.provider_organization_id, e.currency
        having coalesce(sum(e.commission_amount_minor), 0) + coalesce(sum(e.tax_amount_minor), 0) > 0
        limit lim
      ) x
      join public.organizations o on o.id = x.provider_organization_id
    ), '[]'::jsonb),
    'statements', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'provider_organization_id', s.provider_organization_id, 'organization_name', o.display_name,
        'statement_number', s.statement_number, 'period_start', s.period_start, 'period_end', s.period_end,
        'currency', s.currency, 'total_minor', s.total_minor::text, 'invoiced', exists(select 1 from public.provider_invoices i where i.statement_id = s.id)
      ) order by s.issued_at desc)
      from (
        select * from public.provider_statements order by issued_at desc limit lim
      ) s
      join public.organizations o on o.id = s.provider_organization_id
    ), '[]'::jsonb),
    'overdue_invoices', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id, 'provider_organization_id', i.provider_organization_id, 'organization_name', o.display_name,
        'invoice_number', i.invoice_number, 'due_on', i.due_on, 'currency', i.currency,
        'outstanding_minor', (i.total_minor - coalesce(p.paid_minor, 0))::text,
        'blocks_new_opportunities', true
      ) order by i.due_on)
      from public.provider_invoices i
      join public.organizations o on o.id = i.provider_organization_id
      left join (
        select invoice_id, sum(amount_minor)::bigint as paid_minor
        from public.provider_payment_allocations
        group by invoice_id
      ) p on p.invoice_id = i.id
      where i.due_on < current_date and i.total_minor - coalesce(p.paid_minor, 0) > 0
      limit lim
    ), '[]'::jsonb)
  );
end
$$;

notify pgrst, 'reload schema';
