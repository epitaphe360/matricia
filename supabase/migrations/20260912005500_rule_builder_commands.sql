-- P06 Rule Builder commands: immutable drafts, optimistic concurrency, audit and Outbox.

create function private.assert_rule_builder_payload(p_payload jsonb) returns void
language plpgsql immutable security definer set search_path=pg_catalog as $$
begin
  if jsonb_typeof(p_payload) is distinct from 'object'
    or not (p_payload ?& array['condition_ast','actions','dependency_graph','priority','sensitive'])
    or exists(select 1 from jsonb_object_keys(p_payload) k where k not in('condition_ast','actions','dependency_graph','priority','sensitive'))
    or octet_length(p_payload::text)>262144
    or jsonb_typeof(p_payload->'condition_ast') is distinct from 'object'
    or jsonb_object_length(p_payload->'condition_ast')=0
    or jsonb_typeof(p_payload->'actions') is distinct from 'array'
    or jsonb_array_length(p_payload->'actions') not between 1 and 64
    or exists(select 1 from jsonb_array_elements(p_payload->'actions') a where jsonb_typeof(a) is distinct from 'object' or jsonb_object_length(a)=0)
    or jsonb_typeof(p_payload->'dependency_graph') is distinct from 'object'
    or jsonb_object_length(p_payload->'dependency_graph')>256
    or jsonb_typeof(p_payload->'priority') is distinct from 'number'
    or (p_payload->>'priority')!~'^(0|[1-9][0-9]{0,5})$'
    or (p_payload->>'priority')::integer>100000
    or jsonb_typeof(p_payload->'sensitive') is distinct from 'boolean'
  then raise exception 'INVALID_CATALOG_RULE' using errcode='22023'; end if;
end $$;

create function private.insert_rule_builder_version(p_rule_id uuid,p_library_id uuid,p_payload jsonb,p_change_reason text,p_actor uuid,p_version integer) returns uuid
language plpgsql security definer set search_path=pg_catalog,private as $$
declare v_id uuid;v_hash text;
begin
  if length(btrim(coalesce(p_change_reason,''))) not between 3 and 500 or p_version<1 then raise exception 'INVALID_CATALOG_RULE' using errcode='22023';end if;
  v_hash:=private.canonical_request_hash(jsonb_build_object('condition_ast',p_payload->'condition_ast','actions',p_payload->'actions','dependency_graph',p_payload->'dependency_graph','priority',(p_payload->>'priority')::integer,'sensitive',(p_payload->>'sensitive')::boolean));
  insert into public.question_rule_versions(rule_id,library_id,version,status,condition_ast,actions,dependency_graph,priority,sensitive,compiled_hash,change_reason,created_by)
  values(p_rule_id,p_library_id,p_version,'DRAFT',p_payload->'condition_ast',p_payload->'actions',p_payload->'dependency_graph',(p_payload->>'priority')::integer,(p_payload->>'sensitive')::boolean,v_hash,btrim(p_change_reason),p_actor)
  returning id into v_id;return v_id;
end $$;

create function public.create_catalog_rule(p_library_id uuid,p_rule_key text,p_payload jsonb,p_change_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_hash text;v_command uuid;v_replay jsonb;v_rule uuid;v_version uuid;v_org uuid;v_compiled text;v_response jsonb;
begin
  if v_actor is null or btrim(coalesce(p_rule_key,''))!~'^[A-Z][A-Z0-9_.-]{1,119}$' or length(btrim(coalesce(p_change_reason,''))) not between 3 and 500 or not private.has_library_permission(p_library_id,'CATALOG_EDIT',v_actor) then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
  perform private.assert_rule_builder_payload(p_payload);
  if (p_payload->>'sensitive')::boolean and auth.jwt()->>'aal' is distinct from 'aal2' then raise exception 'CATALOG_SENSITIVE_MFA_REQUIRED' using errcode='42501';end if;
  v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.rule.create.v1','library_id',p_library_id,'rule_key',btrim(p_rule_key),'payload',p_payload,'change_reason',btrim(p_change_reason)));
  select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.rule.create',p_idempotency_key,v_hash)b;
  perform pg_advisory_xact_lock(hashtextextended('catalog-library:'||p_library_id::text,0));perform private.assert_catalog_permission_locked(p_library_id,'CATALOG_EDIT',v_actor);if v_replay is not null then return v_replay;end if;
  select steward_organization_id into v_org from public.catalog_libraries where id=p_library_id and status not in('RETIRED','ARCHIVED');if not found then raise exception 'CATALOG_LIBRARY_NOT_FOUND' using errcode='P0002';end if;
  insert into public.question_rules(library_id,rule_key,status,created_by) values(p_library_id,btrim(p_rule_key),'DRAFT',v_actor) returning id into v_rule;
  v_version:=private.insert_rule_builder_version(v_rule,p_library_id,p_payload,p_change_reason,v_actor,1);update public.question_rules set current_draft_version_id=v_version where id=v_rule;
  select compiled_hash into v_compiled from public.question_rule_versions where id=v_version;
  v_response:=jsonb_build_object('outcome','CATALOG_RULE_CREATED','rule_id',v_rule,'library_id',p_library_id,'version_id',v_version,'identity_row_version',1,'version_row_version',1,'compiled_hash',v_compiled,'command_id',v_command);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_org,v_actor,'USER','catalog.rule.created','catalog_rule',v_rule::text,p_correlation_id,jsonb_build_object('version_id',v_version,'sensitive',(p_payload->>'sensitive')::boolean,'command_id',v_command),null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id) values(v_org,'catalog_rule',v_rule::text,'CatalogRuleCreatedV1',p_correlation_id,jsonb_build_object('rule_id',v_rule,'version_id',v_version),p_idempotency_key,v_command);
  perform private.finish_catalog_command(v_actor,'catalog.rule.create',p_idempotency_key,v_response);return v_response;
end $$;

create function public.save_catalog_rule_draft(p_rule_id uuid,p_source_version_id uuid,p_payload jsonb,p_change_reason text,p_expected_identity_row_version integer,p_expected_source_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_identity public.question_rules%rowtype;v_source public.question_rule_versions%rowtype;v_hash text;v_command uuid;v_replay jsonb;v_number integer;v_version uuid;v_org uuid;v_compiled text;v_response jsonb;
begin
  if v_actor is null or p_expected_identity_row_version<1 or p_expected_source_row_version<1 then raise exception 'INVALID_CATALOG_RULE' using errcode='22023';end if;
  select * into v_identity from public.question_rules where id=p_rule_id;if not found or not private.has_library_permission(v_identity.library_id,'CATALOG_EDIT',v_actor) then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
  perform private.assert_rule_builder_payload(p_payload);select * into v_source from public.question_rule_versions where id=p_source_version_id and rule_id=p_rule_id;if not found then raise exception 'CATALOG_RULE_VERSION_NOT_FOUND' using errcode='P0002';end if;
  if (p_payload->>'sensitive')::boolean and auth.jwt()->>'aal' is distinct from 'aal2' then raise exception 'CATALOG_SENSITIVE_MFA_REQUIRED' using errcode='42501';end if;
  v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.rule.save.v1','rule_id',p_rule_id,'source_version_id',p_source_version_id,'payload',p_payload,'change_reason',btrim(p_change_reason),'expected_identity',p_expected_identity_row_version,'expected_source',p_expected_source_row_version));
  select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.rule.save',p_idempotency_key,v_hash)b;
  perform pg_advisory_xact_lock(hashtextextended('catalog-rule:'||p_rule_id::text,0));select * into v_identity from public.question_rules where id=p_rule_id for update;select * into v_source from public.question_rule_versions where id=p_source_version_id and rule_id=p_rule_id for share;perform private.assert_catalog_permission_locked(v_identity.library_id,'CATALOG_EDIT',v_actor);if v_replay is not null then return v_replay;end if;
  if v_identity.status='ARCHIVED' or p_source_version_id is distinct from coalesce(v_identity.current_draft_version_id,v_identity.current_published_version_id) then raise exception 'CATALOG_RULE_NOT_EDITABLE' using errcode='55000';end if;
  if v_identity.row_version is distinct from p_expected_identity_row_version or v_source.row_version is distinct from p_expected_source_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001';end if;
  select coalesce(max(version),0)+1 into v_number from public.question_rule_versions where rule_id=p_rule_id;v_version:=private.insert_rule_builder_version(p_rule_id,v_identity.library_id,p_payload,p_change_reason,v_actor,v_number);select steward_organization_id into v_org from public.catalog_libraries where id=v_identity.library_id;
  update public.question_rules set status=case when current_published_version_id is null then'DRAFT'else'PUBLISHED'end,current_draft_version_id=v_version,row_version=row_version+1 where id=p_rule_id;select compiled_hash into v_compiled from public.question_rule_versions where id=v_version;
  v_response:=jsonb_build_object('outcome','CATALOG_RULE_DRAFT_SAVED','rule_id',p_rule_id,'library_id',v_identity.library_id,'version_id',v_version,'version_number',v_number,'identity_row_version',p_expected_identity_row_version+1,'version_row_version',1,'compiled_hash',v_compiled,'command_id',v_command);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_org,v_actor,'USER','catalog.rule.draft_saved','catalog_rule',p_rule_id::text,p_correlation_id,jsonb_build_object('source_version_id',p_source_version_id,'version_id',v_version,'sensitive',(p_payload->>'sensitive')::boolean,'command_id',v_command),v_source.compiled_hash,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id) values(v_org,'catalog_rule',p_rule_id::text,'CatalogRuleDraftSavedV1',p_correlation_id,jsonb_build_object('rule_id',p_rule_id,'version_id',v_version),p_idempotency_key,v_command);
  perform private.finish_catalog_command(v_actor,'catalog.rule.save',p_idempotency_key,v_response);return v_response;
end $$;

revoke all on function private.assert_rule_builder_payload(jsonb),private.insert_rule_builder_version(uuid,uuid,jsonb,text,uuid,integer),public.create_catalog_rule(uuid,text,jsonb,text,text,uuid),public.save_catalog_rule_draft(uuid,uuid,jsonb,text,integer,integer,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_catalog_rule(uuid,text,jsonb,text,text,uuid),public.save_catalog_rule_draft(uuid,uuid,jsonb,text,integer,integer,text,uuid) to authenticated;
