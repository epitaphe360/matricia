-- Atomic conversion of one authorized diagnostic opportunity into one request.
-- Rollback: revoke/drop this wrapper only; created requests and provenance remain.
create function public.create_service_request_from_opportunity(
  p_opportunity_id uuid,
  p_payload jsonb,
  p_change_reason text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  opportunity public.diagnostic_opportunities%rowtype;
  diagnostic public.diagnostic_runs%rowtype;
  snapshot public.questionnaire_session_snapshots%rowtype;
  service public.catalog_services%rowtype;
  service_version public.catalog_service_versions%rowtype;
  controlled_payload jsonb;
  response jsonb;
  request_id uuid;
begin
  select * into opportunity from public.diagnostic_opportunities where id=p_opportunity_id for update;
  if auth.uid() is null or not found or not private.can_manage_client_request(opportunity.organization_id,auth.uid()) then
    raise exception 'OPPORTUNITY_REQUEST_SCOPE_DENIED' using errcode='42501';
  end if;
  if opportunity.status='CONVERTED' and opportunity.service_request_id is not null then
    if not exists(select 1 from public.service_requests r where r.id=opportunity.service_request_id and r.client_organization_id=opportunity.organization_id) then
      raise exception 'OPPORTUNITY_REQUEST_LINK_INVALID' using errcode='23514';
    end if;
    return jsonb_build_object('outcome','SERVICE_REQUEST_CREATED','request_id',opportunity.service_request_id,'status','DRAFT','replayed',true);
  end if;
  if opportunity.status<>'RFQ_READY' or opportunity.service_id is null or opportunity.missing_fields<>'[]'::jsonb then
    raise exception 'OPPORTUNITY_NOT_REQUEST_READY' using errcode='55000';
  end if;

  select * into diagnostic from public.diagnostic_runs where id=opportunity.diagnostic_run_id and organization_id=opportunity.organization_id;
  select * into snapshot from public.questionnaire_session_snapshots where session_id=diagnostic.questionnaire_session_id and organization_id=opportunity.organization_id;
  select * into service from public.catalog_services where id=opportunity.service_id and library_id=diagnostic.library_id and status='PUBLISHED';
  select * into service_version from public.catalog_service_versions where id=service.current_published_version_id and service_id=service.id and library_id=service.library_id and status='PUBLISHED';
  if diagnostic.id is null or snapshot.session_id is null or service.id is null or service_version.id is null then
    raise exception 'OPPORTUNITY_REQUEST_CONTEXT_INVALID' using errcode='23514';
  end if;

  controlled_payload:=jsonb_build_object(
    'description',btrim(coalesce(p_payload->>'description','')),
    'urgency',p_payload->>'urgency',
    'desired_date',coalesce(p_payload->>'desired_date',''),
    'budget_minor',coalesce(p_payload->>'budget_minor',''),
    'currency_code',coalesce(nullif(p_payload->>'currency_code',''),'MAD'),
    'required_quote_data',jsonb_build_object('region_code',p_payload->>'region_code'),
    'required_fields_complete',true,
    'catalog_snapshot_hash',service_version.content_hash,
    'questionnaire_snapshot_hash',snapshot.questionnaire_snapshot_hash
  );
  response:=public.create_service_request(
    opportunity.organization_id,diagnostic.library_id,service.id,snapshot.questionnaire_version_id,
    controlled_payload,p_change_reason,p_opportunity_id::text,p_correlation_id
  );
  request_id:=(response->>'request_id')::uuid;
  update public.diagnostic_opportunities
    set status='CONVERTED',service_request_id=request_id,row_version=row_version+1,updated_at=clock_timestamp()
    where id=opportunity.id and status='RFQ_READY';
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
    values(opportunity.organization_id,auth.uid(),'USER','diagnostic.opportunity.converted','diagnostic_opportunity',opportunity.id::text,p_correlation_id,jsonb_build_object('service_request_id',request_id),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
    values(opportunity.organization_id,'diagnostic_opportunity',opportunity.id::text,'DiagnosticOpportunityConvertedV1',p_correlation_id,jsonb_build_object('opportunity_id',opportunity.id,'service_request_id',request_id),'diagnostic-opportunity-converted:'||opportunity.id::text)
    on conflict do nothing;
  return response||jsonb_build_object('opportunity_id',opportunity.id,'replayed',false);
end$$;

revoke all on function public.create_service_request_from_opportunity(uuid,jsonb,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_service_request_from_opportunity(uuid,jsonb,text,uuid) to authenticated;
