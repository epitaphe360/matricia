-- Runtime compatibility: avoid PL/pgSQL row-variable/table-alias ambiguity while
-- preserving the published-only and approved-active invariants from 10600.
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
revoke all on function private.clone_request_core(uuid,date,uuid,text,boolean)from public,anon,authenticated,service_role;
notify pgrst,'reload schema';
