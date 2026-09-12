-- MAT-FUNC-020/065: enforce platform MFA and qualification effective dates.
begin;

-- P1: canonical helper excludes revoked platform roles.

create or replace function public.list_admin_operations_projection(p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  outbox_counts jsonb;
  delivery_counts jsonb;
  outbox_rows jsonb;
  delivery_rows jsonb;
begin
  if actor is null or coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' or not private.has_platform_role(
    array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'READ_ONLY_AUDITOR'],
    actor
  ) then
    raise exception 'ADMIN_OPERATIONS_PROJECTION_DENIED' using errcode = '42501';
  end if;

  if p_limit is null or p_limit not between 1 and 200 then
    raise exception 'INVALID_ADMIN_OPERATIONS_LIMIT' using errcode = '22023';
  end if;

  select jsonb_build_object(
    'total', count(*),
    'pending', count(*) filter (where operation.published_at is null and operation.last_error_code is null),
    'failed', count(*) filter (where operation.published_at is null and operation.last_error_code is not null),
    'published', count(*) filter (where operation.published_at is not null)
  )
  into outbox_counts
  from public.event_outbox operation;

  select jsonb_build_object(
    'total', count(*),
    'pending', count(*) filter (where delivery.status = 'PENDING'),
    'queued_digest', count(*) filter (where delivery.status = 'QUEUED_DIGEST'),
    'sent', count(*) filter (where delivery.status = 'SENT'),
    'delivered', count(*) filter (where delivery.status = 'DELIVERED'),
    'failed', count(*) filter (where delivery.status = 'FAILED'),
    'dead_letter', count(*) filter (where delivery.status = 'DEAD_LETTER'),
    'skipped', count(*) filter (where delivery.status = 'SKIPPED')
  )
  into delivery_counts
  from public.notification_deliveries delivery;

  select coalesce(
    jsonb_agg(
      to_jsonb(bounded_operation)
      order by bounded_operation.occurred_at desc, bounded_operation.sequence desc
    ),
    '[]'::jsonb
  )
  into outbox_rows
  from (
    select
      operation.id as sequence,
      operation.event_type,
      case
        when operation.published_at is not null then 'PUBLISHED'
        when operation.last_error_code is not null then 'FAILED'
        else 'PENDING'
      end as status,
      operation.attempt_count,
      operation.occurred_at,
      operation.available_at,
      operation.published_at,
      case when operation.last_error_code is null then null else 'REDACTED' end as error_code
    from public.event_outbox operation
    order by operation.occurred_at desc, operation.id desc
    limit p_limit
  ) bounded_operation;

  select coalesce(
    jsonb_agg(
      to_jsonb(bounded_delivery)
      order by bounded_delivery.created_at desc, bounded_delivery.sequence desc
    ),
    '[]'::jsonb
  )
  into delivery_rows
  from (
    select
      delivery.id as sequence,
      delivery.channel,
      delivery.delivery_mode,
      delivery.status,
      delivery.attempt_count,
      delivery.next_attempt_at,
      delivery.created_at,
      delivery.updated_at,
      case when delivery.last_error_code is null then null else 'REDACTED' end as error_code
    from public.notification_deliveries delivery
    order by delivery.created_at desc, delivery.id desc
    limit p_limit
  ) bounded_delivery;

  return jsonb_build_object(
    'as_of', statement_timestamp(),
    'outbox_counts', outbox_counts,
    'delivery_counts', delivery_counts,
    'outbox', outbox_rows,
    'deliveries', delivery_rows
  );
end
$$;

revoke all on function public.list_admin_operations_projection(integer)
  from public, anon, authenticated, service_role;
grant execute on function public.list_admin_operations_projection(integer) to authenticated;

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
