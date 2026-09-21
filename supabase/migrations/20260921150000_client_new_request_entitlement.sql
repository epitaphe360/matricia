-- Block new Client service requests after trial expiry, unpaid subscription, or an unresolved expired-document anomaly.
-- Existing missions and request history stay readable. Unknown subscription does not invent a block.
-- Timestamp 20260921150000 avoids colliding with admin volume 20260921140000.

create or replace function private.client_may_open_new_service_request(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select
    not exists (
      select 1
      from public.subscriptions subscription
      where subscription.organization_id = p_organization_id
        and subscription.status not in ('TRIAL_ACTIVE', 'ACTIVE')
    )
    and not exists (
      select 1
      from public.client_trials trial
      where trial.organization_id = p_organization_id
        and trial.status = 'TRIAL_EXPIRED'
        and not exists (
          select 1
          from public.subscriptions paid
          where paid.organization_id = p_organization_id
            and paid.status = 'ACTIVE'
        )
    )
    and not exists (
      select 1
      from public.client_administrative_anomalies anomaly
      where anomaly.organization_id = p_organization_id
        and anomaly.anomaly_code = 'DOCUMENT_EXPIRED'
        and anomaly.status in ('OPEN', 'QUESTIONED')
    );
$$;

revoke all on function private.client_may_open_new_service_request(uuid) from public, anon, authenticated, service_role;

create or replace function public.create_service_request(p_client_organization_id uuid,p_library_id uuid,p_service_id uuid,p_questionnaire_version_id uuid,p_payload jsonb,p_change_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$declare v_actor uuid:=auth.uid();v_hash text;v_command uuid;v_replay jsonb;v_request uuid:=extensions.gen_random_uuid();v_version uuid:=extensions.gen_random_uuid();v_content text;v_complete boolean;v_response jsonb;begin
 if not private.can_manage_client_request(p_client_organization_id,v_actor) then raise exception 'REQUEST_SCOPE_DENIED' using errcode='42501';end if;
 if not private.client_may_open_new_service_request(p_client_organization_id) then raise exception 'CLIENT_REQUEST_NOT_ENTITLED' using errcode='42501';end if;
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

create or replace function private.clone_request_core(p_source_request_id uuid,p_scheduled_on date,p_actor uuid,p_reason text,p_provenance boolean)
returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare
 v_request public.service_requests%rowtype;
 v_request_version public.service_request_versions%rowtype;
 v_catalog_version public.catalog_service_versions%rowtype;
 v_questionnaire_version public.questionnaire_versions%rowtype;
 v_questionnaire public.questionnaires%rowtype;
 v_new_request_id uuid:=extensions.gen_random_uuid();
 v_new_version_id uuid:=extensions.gen_random_uuid();
 v_content_hash text;
begin
 select request_row.* into v_request from public.service_requests request_row where request_row.id=p_source_request_id;
 if not found or not private.can_manage_client_request(v_request.client_organization_id,p_actor)then raise exception'REQUEST_SCOPE_DENIED'using errcode='42501';end if;
 if not private.client_may_open_new_service_request(v_request.client_organization_id) then raise exception 'CLIENT_REQUEST_NOT_ENTITLED' using errcode='42501';end if;
 select version_row.* into v_request_version from public.service_request_versions version_row where version_row.id=v_request.current_version_id and version_row.request_id=v_request.id;
 if not found then raise exception'SOURCE_REQUEST_VERSION_MISSING'using errcode='55000';end if;
 select service_version_row.* into v_catalog_version
 from public.catalog_services service_row
 join public.catalog_service_versions service_version_row
  on service_version_row.id=service_row.current_published_version_id
 and service_version_row.service_id=service_row.id
 and service_version_row.library_id=service_row.library_id
 where service_row.id=v_request.service_id and service_row.library_id=v_request.library_id
  and service_row.status='PUBLISHED'and service_version_row.status='PUBLISHED';
 if not found then raise exception'SERVICE_VERSION_NOT_PUBLISHED'using errcode='55000';end if;
 if v_request.questionnaire_version_id is not null then
  select questionnaire_row.* into v_questionnaire from public.questionnaires questionnaire_row
  where questionnaire_row.library_id=v_request.library_id and questionnaire_row.status='PUBLISHED'
   and questionnaire_row.current_published_version_id=v_request.questionnaire_version_id;
  if not found then raise exception'QUESTIONNAIRE_VERSION_NOT_APPROVED_ACTIVE'using errcode='55000';end if;
  select questionnaire_version_row.* into v_questionnaire_version from public.questionnaire_versions questionnaire_version_row
  where questionnaire_version_row.id=v_request.questionnaire_version_id
   and questionnaire_version_row.questionnaire_id=v_questionnaire.id
   and questionnaire_version_row.library_id=v_questionnaire.library_id
   and questionnaire_version_row.status='PUBLISHED'
   and questionnaire_version_row.translation_review_status='APPROVED';
  if not found then raise exception'QUESTIONNAIRE_VERSION_NOT_APPROVED_ACTIVE'using errcode='55000';end if;
 end if;
 v_content_hash:=private.canonical_request_hash(jsonb_build_object('request_id',v_new_request_id,'version',1,'source_request_id',v_request.id,'catalog_hash',v_catalog_version.content_hash,'questionnaire_hash',coalesce(v_questionnaire_version.snapshot_hash,repeat('0',64)),'scheduled_on',p_scheduled_on));
 insert into public.service_requests(id,client_organization_id,site_id,library_id,service_id,questionnaire_version_id,status,created_by)
 values(v_new_request_id,v_request.client_organization_id,v_request.site_id,v_request.library_id,v_request.service_id,v_questionnaire_version.id,'DRAFT',p_actor);
 insert into public.service_request_versions(id,request_id,client_organization_id,library_id,version_number,description,urgency,desired_date,budget_minor,currency_code,required_quote_data,required_fields_complete,catalog_snapshot_hash,questionnaire_snapshot_hash,change_reason,content_hash,created_by)
 values(v_new_version_id,v_new_request_id,v_request.client_organization_id,v_request.library_id,1,v_request_version.description,v_request_version.urgency,coalesce(p_scheduled_on,v_request_version.desired_date),v_request_version.budget_minor,v_request_version.currency_code,v_request_version.required_quote_data,v_request_version.required_fields_complete,v_catalog_version.content_hash,coalesce(v_questionnaire_version.snapshot_hash,repeat('0',64)),p_reason,v_content_hash,p_actor);
 update public.service_requests set current_version_id=v_new_version_id where id=v_new_request_id;
 if p_provenance then
  insert into public.service_request_clone_provenance(client_organization_id,source_request_id,source_request_version_id,cloned_request_id,cloned_request_version_id,source_catalog_snapshot_hash,revalidated_catalog_snapshot_hash,source_questionnaire_snapshot_hash,revalidated_questionnaire_snapshot_hash,created_by)
  values(v_request.client_organization_id,v_request.id,v_request_version.id,v_new_request_id,v_new_version_id,v_request_version.catalog_snapshot_hash,v_catalog_version.content_hash,v_request_version.questionnaire_snapshot_hash,coalesce(v_questionnaire_version.snapshot_hash,repeat('0',64)),p_actor);
 end if;
 return jsonb_build_object('request_id',v_new_request_id,'request_version_id',v_new_version_id,'status','DRAFT','catalog_snapshot_hash',v_catalog_version.content_hash,'questionnaire_snapshot_hash',coalesce(v_questionnaire_version.snapshot_hash,repeat('0',64)));
end$$;

revoke all on function public.create_service_request(uuid,uuid,uuid,uuid,jsonb,text,text,uuid),private.clone_request_core(uuid,date,uuid,text,boolean) from public,anon,service_role;
grant execute on function public.create_service_request(uuid,uuid,uuid,uuid,jsonb,text,text,uuid) to authenticated;
notify pgrst,'reload schema';
