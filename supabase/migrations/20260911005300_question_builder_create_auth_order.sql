-- Authorize the library before validating service-scoped references.

create or replace function public.create_catalog_question(p_library_id uuid,p_question_key text,p_scope text,p_payload jsonb,p_change_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_hash text;v_command uuid;v_replay jsonb;v_question uuid;v_version uuid;v_org uuid;v_response jsonb;
begin
 if v_actor is null or not private.has_library_permission(p_library_id,'CATALOG_EDIT',v_actor) then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
 perform private.assert_question_builder_payload(p_library_id,p_scope,p_payload);
 if btrim(coalesce(p_question_key,''))!~'^[A-Z][A-Z0-9_.-]{1,119}$' or length(btrim(coalesce(p_change_reason,''))) not between 3 and 500 then raise exception 'INVALID_CATALOG_QUESTION' using errcode='22023';end if;
 if p_scope='GLOBAL' then perform private.assert_catalog_central_aal2_locked(v_actor);end if;if p_payload->>'sensitivity'in('CONFIDENTIAL','RESTRICTED')and auth.jwt()->>'aal' is distinct from'aal2'then raise exception 'CATALOG_SENSITIVE_MFA_REQUIRED' using errcode='42501';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.question.create.v1','library_id',p_library_id,'question_key',btrim(p_question_key),'scope',p_scope,'payload',p_payload,'change_reason',btrim(p_change_reason)));select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.question.create',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('catalog-library:'||p_library_id::text,0));perform private.assert_catalog_permission_locked(p_library_id,'CATALOG_EDIT',v_actor);if v_replay is not null then return v_replay;end if;
 select steward_organization_id into v_org from public.catalog_libraries where id=p_library_id and status not in('RETIRED','ARCHIVED');if not found then raise exception 'CATALOG_LIBRARY_NOT_FOUND' using errcode='P0002';end if;
 insert into public.question_bank_questions(library_id,question_key,scope,status,created_by)values(p_library_id,btrim(p_question_key),p_scope,'DRAFT',v_actor)returning id into v_question;
 v_version:=private.insert_question_builder_version(v_question,p_library_id,p_payload,p_change_reason,v_actor,1);update public.question_bank_questions set current_draft_version_id=v_version where id=v_question;
 v_response:=jsonb_build_object('outcome','CATALOG_QUESTION_CREATED','question_id',v_question,'library_id',p_library_id,'version_id',v_version,'identity_row_version',1,'version_row_version',1,'content_hash',private.canonical_request_hash(p_payload),'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)values(v_org,v_actor,'USER','catalog.question.created','catalog_question',v_question::text,p_correlation_id,jsonb_build_object('version_id',v_version,'scope',p_scope,'command_id',v_command),null,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(v_org,'catalog_question',v_question::text,'CatalogQuestionCreatedV1',p_correlation_id,jsonb_build_object('question_id',v_question,'version_id',v_version),p_idempotency_key,v_command);perform private.finish_catalog_command(v_actor,'catalog.question.create',p_idempotency_key,v_response);return v_response;
end $$;

revoke all on function public.create_catalog_question(uuid,text,text,jsonb,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_catalog_question(uuid,text,text,jsonb,text,text,uuid) to authenticated;
