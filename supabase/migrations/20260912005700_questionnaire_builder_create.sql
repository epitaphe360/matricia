-- P06 Questionnaire Builder: create an immutable DRAFT snapshot with its first section.

create function private.assert_questionnaire_builder_payload(p_payload jsonb) returns void
language plpgsql immutable security definer set search_path=pg_catalog as $$
begin
 if jsonb_typeof(p_payload) is distinct from 'object'
  or not(p_payload?&array['title_fr','title_ar','description_fr','description_ar','audience','engine_version','policy_version','sensitive','section_key','section_label_fr','section_label_ar'])
  or exists(select 1 from jsonb_object_keys(p_payload)k where k not in('title_fr','title_ar','description_fr','description_ar','audience','engine_version','policy_version','sensitive','section_key','section_label_fr','section_label_ar','section_help_fr','section_help_ar'))
  or length(btrim(coalesce(p_payload->>'title_fr','')))not between 2 and 240 or length(btrim(coalesce(p_payload->>'title_ar','')))not between 2 and 240
  or length(btrim(coalesce(p_payload->>'description_fr','')))not between 3 and 4000 or length(btrim(coalesce(p_payload->>'description_ar','')))not between 3 and 4000
  or coalesce(p_payload->>'audience','')not in('CLIENT','PROVIDER','FRANCHISE','INTERNAL')
  or coalesce(p_payload->>'engine_version','')!~'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$' or coalesce(p_payload->>'policy_version','')!~'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$'
  or jsonb_typeof(p_payload->'sensitive')is distinct from'boolean' or coalesce(p_payload->>'section_key','')!~'^[A-Z][A-Z0-9_-]{1,79}$'
  or length(btrim(coalesce(p_payload->>'section_label_fr','')))not between 1 and 240 or length(btrim(coalesce(p_payload->>'section_label_ar','')))not between 1 and 240
  or length(btrim(coalesce(p_payload->>'section_help_fr',''))) > 2000 or length(btrim(coalesce(p_payload->>'section_help_ar',''))) > 2000
 then raise exception 'INVALID_CATALOG_QUESTIONNAIRE' using errcode='22023';end if;
end $$;

create function public.create_catalog_questionnaire(p_library_id uuid,p_catalog_release_id uuid,p_code text,p_payload jsonb,p_change_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_hash text;v_command uuid;v_replay jsonb;v_questionnaire uuid;v_version uuid;v_section uuid;v_org uuid;v_snapshot text;v_section_hash text;v_response jsonb;
begin
 if v_actor is null or btrim(coalesce(p_code,''))!~'^[A-Z][A-Z0-9_-]{1,79}$' or length(btrim(coalesce(p_change_reason,'')))not between 3 and 500 or not private.has_library_permission(p_library_id,'CATALOG_EDIT',v_actor)then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
 perform private.assert_questionnaire_builder_payload(p_payload);if(p_payload->>'sensitive')::boolean and auth.jwt()->>'aal'is distinct from'aal2'then raise exception 'CATALOG_SENSITIVE_MFA_REQUIRED' using errcode='42501';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.questionnaire.create.v1','library_id',p_library_id,'release_id',p_catalog_release_id,'code',btrim(p_code),'payload',p_payload,'change_reason',btrim(p_change_reason)));
 select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.questionnaire.create',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('catalog-library:'||p_library_id::text,0));perform private.assert_catalog_permission_locked(p_library_id,'CATALOG_EDIT',v_actor);if v_replay is not null then return v_replay;end if;
 select l.steward_organization_id into v_org from public.catalog_libraries l join public.catalog_releases r on r.id=p_catalog_release_id and r.library_id=l.id and r.status in('DRAFT','IN_REVIEW','APPROVED')where l.id=p_library_id and l.status not in('RETIRED','ARCHIVED');if not found then raise exception 'CATALOG_QUESTIONNAIRE_RELEASE_NOT_EDITABLE' using errcode='23514';end if;
 v_snapshot:=private.canonical_request_hash(p_payload);v_section_hash:=private.canonical_request_hash(jsonb_build_object('key',btrim(p_payload->>'section_key'),'label_fr',btrim(p_payload->>'section_label_fr'),'label_ar',btrim(p_payload->>'section_label_ar'),'help_fr',nullif(btrim(p_payload->>'section_help_fr'),''),'help_ar',nullif(btrim(p_payload->>'section_help_ar'),''),'sort_order',1));
 insert into public.questionnaires(library_id,code,status,created_by)values(p_library_id,btrim(p_code),'DRAFT',v_actor)returning id into v_questionnaire;
 insert into public.questionnaire_versions(questionnaire_id,library_id,catalog_release_id,version,status,title_fr,title_ar,description_fr,description_ar,audience,engine_version,policy_version,snapshot_hash,sensitive,translation_review_status,change_reason,created_by)
 values(v_questionnaire,p_library_id,p_catalog_release_id,1,'DRAFT',btrim(p_payload->>'title_fr'),btrim(p_payload->>'title_ar'),btrim(p_payload->>'description_fr'),btrim(p_payload->>'description_ar'),p_payload->>'audience',p_payload->>'engine_version',p_payload->>'policy_version',v_snapshot,(p_payload->>'sensitive')::boolean,'PENDING',btrim(p_change_reason),v_actor)returning id into v_version;
 insert into public.questionnaire_sections(questionnaire_version_id,section_key,label_fr,label_ar,help_fr,help_ar,sort_order,content_hash)values(v_version,btrim(p_payload->>'section_key'),btrim(p_payload->>'section_label_fr'),btrim(p_payload->>'section_label_ar'),nullif(btrim(p_payload->>'section_help_fr'),''),nullif(btrim(p_payload->>'section_help_ar'),''),1,v_section_hash)returning id into v_section;
 update public.questionnaires set current_draft_version_id=v_version where id=v_questionnaire;
 v_response:=jsonb_build_object('outcome','CATALOG_QUESTIONNAIRE_CREATED','questionnaire_id',v_questionnaire,'library_id',p_library_id,'version_id',v_version,'section_id',v_section,'identity_row_version',1,'version_row_version',1,'snapshot_hash',v_snapshot,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)values(v_org,v_actor,'USER','catalog.questionnaire.created','catalog_questionnaire',v_questionnaire::text,p_correlation_id,jsonb_build_object('version_id',v_version,'section_id',v_section,'release_id',p_catalog_release_id,'sensitive',(p_payload->>'sensitive')::boolean,'command_id',v_command),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(v_org,'catalog_questionnaire',v_questionnaire::text,'CatalogQuestionnaireCreatedV1',p_correlation_id,jsonb_build_object('questionnaire_id',v_questionnaire,'version_id',v_version,'section_id',v_section),p_idempotency_key,v_command);
 perform private.finish_catalog_command(v_actor,'catalog.questionnaire.create',p_idempotency_key,v_response);return v_response;
end $$;

revoke all on function private.assert_questionnaire_builder_payload(jsonb),public.create_catalog_questionnaire(uuid,uuid,text,jsonb,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_catalog_questionnaire(uuid,uuid,text,jsonb,text,text,uuid) to authenticated;
