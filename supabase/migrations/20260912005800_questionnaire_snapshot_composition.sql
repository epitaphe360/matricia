-- P06 Questionnaire Builder: authenticated composition of a mutable DRAFT snapshot.

create function private.refresh_draft_questionnaire_snapshot(p_version_id uuid) returns text
language plpgsql security definer set search_path=pg_catalog as $$
declare v public.questionnaire_versions%rowtype;v_hash text;
begin
 select * into v from public.questionnaire_versions where id=p_version_id;
 if not found or v.status<>'DRAFT' then raise exception 'CATALOG_QUESTIONNAIRE_NOT_EDITABLE' using errcode='55000';end if;
 v_hash:=private.compute_questionnaire_snapshot_hash(v.id,jsonb_build_object('questionnaire_id',v.questionnaire_id,'library_id',v.library_id,'release_id',v.catalog_release_id,'version',v.version,'title_fr',v.title_fr,'title_ar',v.title_ar,'description_fr',v.description_fr,'description_ar',v.description_ar,'audience',v.audience,'engine_version',v.engine_version,'policy_version',v.policy_version));
 update public.questionnaire_versions set snapshot_hash=v_hash,row_version=row_version+1 where id=v.id;
 return v_hash;
end $$;

create function private.assert_questionnaire_section_payload(p_payload jsonb) returns void
language plpgsql immutable security definer set search_path=pg_catalog as $$
begin
 if jsonb_typeof(p_payload)is distinct from'object'
  or not(p_payload?&array['section_key','label_fr','label_ar'])
  or exists(select 1 from jsonb_object_keys(p_payload)k where k not in('section_key','label_fr','label_ar','help_fr','help_ar'))
  or coalesce(p_payload->>'section_key','')!~'^[A-Z][A-Z0-9_-]{1,79}$'
  or length(btrim(coalesce(p_payload->>'label_fr','')))not between 1 and 240
  or length(btrim(coalesce(p_payload->>'label_ar','')))not between 1 and 240
  or length(btrim(coalesce(p_payload->>'help_fr','')))>2000
  or length(btrim(coalesce(p_payload->>'help_ar','')))>2000
 then raise exception 'INVALID_CATALOG_QUESTIONNAIRE_SECTION' using errcode='22023';end if;
end $$;

create function public.add_catalog_questionnaire_section(p_questionnaire_version_id uuid,p_payload jsonb,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_version public.questionnaire_versions%rowtype;v_hash text;v_command uuid;v_replay jsonb;v_order integer;v_section uuid;v_content_hash text;v_snapshot text;v_org uuid;v_response jsonb;
begin
 select * into v_version from public.questionnaire_versions where id=p_questionnaire_version_id;
 if v_actor is null or not found or not private.has_library_permission(v_version.library_id,'CATALOG_EDIT',v_actor)then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
 perform private.assert_questionnaire_section_payload(p_payload);
 if p_expected_row_version<1 then raise exception 'INVALID_CATALOG_QUESTIONNAIRE_SECTION' using errcode='22023';end if;
 if v_version.sensitive and auth.jwt()->>'aal'is distinct from'aal2'then raise exception 'CATALOG_SENSITIVE_MFA_REQUIRED' using errcode='42501';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.questionnaire.section.add.v1','version_id',p_questionnaire_version_id,'payload',p_payload,'expected_row_version',p_expected_row_version));
 select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.questionnaire.section.add',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('catalog-questionnaire-version:'||p_questionnaire_version_id::text,0));select * into v_version from public.questionnaire_versions where id=p_questionnaire_version_id for update;perform private.assert_catalog_permission_locked(v_version.library_id,'CATALOG_EDIT',v_actor);if v_replay is not null then return v_replay;end if;
 if v_version.status<>'DRAFT'then raise exception 'CATALOG_QUESTIONNAIRE_NOT_EDITABLE' using errcode='55000';end if;if v_version.row_version is distinct from p_expected_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001';end if;
 select coalesce(max(sort_order),0)+1 into v_order from public.questionnaire_sections where questionnaire_version_id=v_version.id;
 v_content_hash:=private.canonical_request_hash(jsonb_build_object('key',btrim(p_payload->>'section_key'),'label_fr',btrim(p_payload->>'label_fr'),'label_ar',btrim(p_payload->>'label_ar'),'help_fr',nullif(btrim(p_payload->>'help_fr'),''),'help_ar',nullif(btrim(p_payload->>'help_ar'),''),'sort_order',v_order));
 insert into public.questionnaire_sections(questionnaire_version_id,section_key,label_fr,label_ar,help_fr,help_ar,sort_order,content_hash)values(v_version.id,btrim(p_payload->>'section_key'),btrim(p_payload->>'label_fr'),btrim(p_payload->>'label_ar'),nullif(btrim(p_payload->>'help_fr'),''),nullif(btrim(p_payload->>'help_ar'),''),v_order,v_content_hash)returning id into v_section;
 v_snapshot:=private.refresh_draft_questionnaire_snapshot(v_version.id);select steward_organization_id into v_org from public.catalog_libraries where id=v_version.library_id;
 v_response:=jsonb_build_object('outcome','CATALOG_QUESTIONNAIRE_SECTION_ADDED','questionnaire_id',v_version.questionnaire_id,'version_id',v_version.id,'section_id',v_section,'sort_order',v_order,'version_row_version',p_expected_row_version+1,'snapshot_hash',v_snapshot,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)values(v_org,v_actor,'USER','catalog.questionnaire.section_added','catalog_questionnaire',v_version.questionnaire_id::text,p_correlation_id,jsonb_build_object('version_id',v_version.id,'section_id',v_section,'sort_order',v_order,'command_id',v_command),v_version.snapshot_hash,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(v_org,'catalog_questionnaire',v_version.questionnaire_id::text,'CatalogQuestionnaireSectionAddedV1',p_correlation_id,jsonb_build_object('questionnaire_id',v_version.questionnaire_id,'version_id',v_version.id,'section_id',v_section,'sort_order',v_order),p_idempotency_key,v_command);
 perform private.finish_catalog_command(v_actor,'catalog.questionnaire.section.add',p_idempotency_key,v_response);return v_response;
end $$;

create function public.add_catalog_questionnaire_question(p_questionnaire_version_id uuid,p_section_id uuid,p_question_version_id uuid,p_sort_order integer,p_required_override boolean,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_version public.questionnaire_versions%rowtype;v_question public.question_versions%rowtype;v_hash text;v_command uuid;v_replay jsonb;v_snapshot text;v_org uuid;v_response jsonb;
begin
 select * into v_version from public.questionnaire_versions where id=p_questionnaire_version_id;
 if v_actor is null or not found or not private.has_library_permission(v_version.library_id,'CATALOG_EDIT',v_actor)then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
 if p_sort_order<1 or p_expected_row_version<1 then raise exception 'INVALID_CATALOG_QUESTIONNAIRE_LINK' using errcode='22023';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.questionnaire.question.add.v1','version_id',p_questionnaire_version_id,'section_id',p_section_id,'question_version_id',p_question_version_id,'sort_order',p_sort_order,'required_override',p_required_override,'expected_row_version',p_expected_row_version));
 select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.questionnaire.question.add',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('catalog-questionnaire-version:'||p_questionnaire_version_id::text,0));select * into v_version from public.questionnaire_versions where id=p_questionnaire_version_id for update;perform private.assert_catalog_permission_locked(v_version.library_id,'CATALOG_EDIT',v_actor);if v_replay is not null then return v_replay;end if;
 if v_version.status<>'DRAFT'then raise exception 'CATALOG_QUESTIONNAIRE_NOT_EDITABLE' using errcode='55000';end if;if v_version.row_version is distinct from p_expected_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001';end if;
 select * into v_question from public.question_versions where id=p_question_version_id and library_id=v_version.library_id and status in('APPROVED','PUBLISHED');if not found or not exists(select 1 from public.questionnaire_sections where id=p_section_id and questionnaire_version_id=v_version.id)then raise exception 'CATALOG_QUESTIONNAIRE_LINK_NOT_FOUND' using errcode='P0002';end if;
 if (v_version.sensitive or v_question.sensitivity in('CONFIDENTIAL','RESTRICTED'))and auth.jwt()->>'aal'is distinct from'aal2'then raise exception 'CATALOG_SENSITIVE_MFA_REQUIRED' using errcode='42501';end if;
 insert into public.questionnaire_version_questions(questionnaire_version_id,library_id,section_id,question_version_id,sort_order,required_override)values(v_version.id,v_version.library_id,p_section_id,v_question.id,p_sort_order,p_required_override);
 v_snapshot:=private.refresh_draft_questionnaire_snapshot(v_version.id);select steward_organization_id into v_org from public.catalog_libraries where id=v_version.library_id;
 v_response:=jsonb_build_object('outcome','CATALOG_QUESTIONNAIRE_QUESTION_ADDED','questionnaire_id',v_version.questionnaire_id,'version_id',v_version.id,'section_id',p_section_id,'question_version_id',v_question.id,'sort_order',p_sort_order,'version_row_version',p_expected_row_version+1,'snapshot_hash',v_snapshot,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)values(v_org,v_actor,'USER','catalog.questionnaire.question_added','catalog_questionnaire',v_version.questionnaire_id::text,p_correlation_id,jsonb_build_object('version_id',v_version.id,'section_id',p_section_id,'question_version_id',v_question.id,'sort_order',p_sort_order,'command_id',v_command),v_version.snapshot_hash,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(v_org,'catalog_questionnaire',v_version.questionnaire_id::text,'CatalogQuestionnaireQuestionAddedV1',p_correlation_id,jsonb_build_object('questionnaire_id',v_version.questionnaire_id,'version_id',v_version.id,'section_id',p_section_id,'question_version_id',v_question.id,'sort_order',p_sort_order),p_idempotency_key,v_command);
 perform private.finish_catalog_command(v_actor,'catalog.questionnaire.question.add',p_idempotency_key,v_response);return v_response;
end $$;

create function public.add_catalog_questionnaire_rule(p_questionnaire_version_id uuid,p_rule_version_id uuid,p_evaluation_order integer,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_version public.questionnaire_versions%rowtype;v_rule public.question_rule_versions%rowtype;v_hash text;v_command uuid;v_replay jsonb;v_snapshot text;v_org uuid;v_response jsonb;
begin
 select * into v_version from public.questionnaire_versions where id=p_questionnaire_version_id;
 if v_actor is null or not found or not private.has_library_permission(v_version.library_id,'CATALOG_EDIT',v_actor)then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
 if p_evaluation_order<1 or p_expected_row_version<1 then raise exception 'INVALID_CATALOG_QUESTIONNAIRE_LINK' using errcode='22023';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.questionnaire.rule.add.v1','version_id',p_questionnaire_version_id,'rule_version_id',p_rule_version_id,'evaluation_order',p_evaluation_order,'expected_row_version',p_expected_row_version));
 select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.questionnaire.rule.add',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('catalog-questionnaire-version:'||p_questionnaire_version_id::text,0));select * into v_version from public.questionnaire_versions where id=p_questionnaire_version_id for update;perform private.assert_catalog_permission_locked(v_version.library_id,'CATALOG_EDIT',v_actor);if v_replay is not null then return v_replay;end if;
 if v_version.status<>'DRAFT'then raise exception 'CATALOG_QUESTIONNAIRE_NOT_EDITABLE' using errcode='55000';end if;if v_version.row_version is distinct from p_expected_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001';end if;
 select * into v_rule from public.question_rule_versions where id=p_rule_version_id and library_id=v_version.library_id and status in('APPROVED','PUBLISHED');if not found then raise exception 'CATALOG_QUESTIONNAIRE_LINK_NOT_FOUND' using errcode='P0002';end if;
 if (v_version.sensitive or v_rule.sensitive)and auth.jwt()->>'aal'is distinct from'aal2'then raise exception 'CATALOG_SENSITIVE_MFA_REQUIRED' using errcode='42501';end if;
 insert into public.questionnaire_version_rules(questionnaire_version_id,library_id,rule_version_id,evaluation_order)values(v_version.id,v_version.library_id,v_rule.id,p_evaluation_order);
 v_snapshot:=private.refresh_draft_questionnaire_snapshot(v_version.id);select steward_organization_id into v_org from public.catalog_libraries where id=v_version.library_id;
 v_response:=jsonb_build_object('outcome','CATALOG_QUESTIONNAIRE_RULE_ADDED','questionnaire_id',v_version.questionnaire_id,'version_id',v_version.id,'rule_version_id',v_rule.id,'evaluation_order',p_evaluation_order,'version_row_version',p_expected_row_version+1,'snapshot_hash',v_snapshot,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)values(v_org,v_actor,'USER','catalog.questionnaire.rule_added','catalog_questionnaire',v_version.questionnaire_id::text,p_correlation_id,jsonb_build_object('version_id',v_version.id,'rule_version_id',v_rule.id,'evaluation_order',p_evaluation_order,'command_id',v_command),v_version.snapshot_hash,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(v_org,'catalog_questionnaire',v_version.questionnaire_id::text,'CatalogQuestionnaireRuleAddedV1',p_correlation_id,jsonb_build_object('questionnaire_id',v_version.questionnaire_id,'version_id',v_version.id,'rule_version_id',v_rule.id,'evaluation_order',p_evaluation_order),p_idempotency_key,v_command);
 perform private.finish_catalog_command(v_actor,'catalog.questionnaire.rule.add',p_idempotency_key,v_response);return v_response;
end $$;

revoke all on function private.refresh_draft_questionnaire_snapshot(uuid),private.assert_questionnaire_section_payload(jsonb),public.add_catalog_questionnaire_section(uuid,jsonb,integer,text,uuid),public.add_catalog_questionnaire_question(uuid,uuid,uuid,integer,boolean,integer,text,uuid),public.add_catalog_questionnaire_rule(uuid,uuid,integer,integer,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.add_catalog_questionnaire_section(uuid,jsonb,integer,text,uuid),public.add_catalog_questionnaire_question(uuid,uuid,uuid,integer,boolean,integer,text,uuid),public.add_catalog_questionnaire_rule(uuid,uuid,integer,integer,text,uuid) to authenticated;
