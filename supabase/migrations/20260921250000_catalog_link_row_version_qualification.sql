-- Qualify row_version in joined catalog updates. Both link tables expose the column,
-- so an unqualified assignment raises 42702 inside submit and decide.

create or replace function public.submit_franchise_catalog_service(
  p_service_id uuid,
  p_version_id uuid,
  p_expected_identity_row_version integer,
  p_expected_version_row_version integer,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_identity public.catalog_services%rowtype;
  v_version public.catalog_service_versions%rowtype;
  v_org uuid;
  v_hash text;
  v_command uuid;
  v_replay jsonb;
  v_request uuid;
  v_response jsonb;
begin
  if p_service_id is null or p_version_id is null
     or p_expected_identity_row_version is null or p_expected_identity_row_version < 1
     or p_expected_version_row_version is null or p_expected_version_row_version < 1
  then
    raise exception 'INVALID_CATALOG_CHANGE' using errcode = '22023';
  end if;
  if v_actor is null then
    raise exception 'CATALOG_SCOPE_DENIED' using errcode = '42501';
  end if;
  select * into v_identity from public.catalog_services where id = p_service_id;
  if not found or not private.has_library_permission(v_identity.library_id, 'CATALOG_SUBMIT', v_actor) then
    raise exception 'CATALOG_SCOPE_DENIED' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('catalog-object:SERVICE:' || p_service_id::text, 0));
  select * into v_identity from public.catalog_services where id = p_service_id for update;
  select * into v_version from public.catalog_service_versions where id = p_version_id and service_id = p_service_id for update;
  if not found then
    raise exception 'CATALOG_VERSION_NOT_FOUND' using errcode = 'P0002';
  end if;
  perform private.assert_catalog_permission_locked(v_identity.library_id, 'CATALOG_SUBMIT', v_actor);
  if v_version.sensitive and auth.jwt()->>'aal' is distinct from 'aal2' then
    raise exception 'CATALOG_SENSITIVE_MFA_REQUIRED' using errcode = '42501';
  end if;
  v_hash := private.canonical_request_hash(jsonb_build_object(
    'operation', 'catalog.service.submit.v1',
    'service_id', p_service_id,
    'version_id', p_version_id,
    'expected_identity', p_expected_identity_row_version,
    'expected_version', p_expected_version_row_version
  ));
  select b.command_id, b.response_body into v_command, v_replay
    from private.begin_catalog_command(v_actor, 'catalog.service.submit', p_idempotency_key, v_hash) b;
  if v_replay is not null then
    return v_replay;
  end if;
  if v_identity.row_version is distinct from p_expected_identity_row_version
     or v_version.row_version is distinct from p_expected_version_row_version
  then
    raise exception 'STALE_CATALOG_VERSION' using errcode = '40001';
  end if;
  if p_version_id is distinct from coalesce(v_identity.current_draft_version_id, v_identity.current_published_version_id) then
    raise exception 'CATALOG_VERSION_NOT_CURRENT' using errcode = '55000';
  end if;
  if v_version.status is distinct from 'DRAFT' or v_identity.status is distinct from 'DRAFT' then
    raise exception 'INVALID_CATALOG_VERSION_STATE' using errcode = '55000';
  end if;
  insert into public.catalog_change_requests(library_id, target_type, target_id, target_version_id, sensitive, requested_by)
  values (v_identity.library_id, 'SERVICE', p_service_id, p_version_id, v_version.sensitive, v_actor)
  returning id into v_request;
  update public.catalog_service_versions set status = 'IN_REVIEW', row_version = row_version + 1 where id = p_version_id;
  update public.catalog_services set status = 'IN_REVIEW', row_version = row_version + 1 where id = p_service_id;
  update public.catalog_service_subcategory_link_versions lv
     set status = 'IN_REVIEW', row_version = lv.row_version + 1
    from public.catalog_service_subcategory_links l
   where l.service_id = p_service_id
     and l.link_type = 'PRIMARY'
     and l.status not in ('RETIRED', 'ARCHIVED')
     and lv.link_id = l.id
     and lv.id = l.current_version_id
     and lv.status = 'DRAFT';
  update public.catalog_service_subcategory_links
     set status = 'IN_REVIEW', row_version = row_version + 1
   where service_id = p_service_id and link_type = 'PRIMARY' and status = 'DRAFT';
  select steward_organization_id into v_org from public.catalog_libraries where id = v_identity.library_id;
  v_response := jsonb_build_object(
    'outcome', 'CATALOG_CHANGE_SUBMITTED',
    'change_request_id', v_request,
    'object_type', 'SERVICE',
    'object_id', p_service_id,
    'version_id', p_version_id,
    'identity_row_version', p_expected_identity_row_version + 1,
    'version_row_version', p_expected_version_row_version + 1,
    'sensitive', v_version.sensitive,
    'command_id', v_command
  );
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, previous_hash, event_hash)
  values (
    v_org, v_actor, 'USER', 'catalog.change.submitted', 'catalog_change_request', v_request::text, p_correlation_id,
    jsonb_build_object('object_type', 'SERVICE', 'object_id', p_service_id, 'version_id', p_version_id, 'sensitive', v_version.sensitive, 'command_id', v_command),
    v_version.content_hash, repeat('0', 64)
  );
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key, causation_id)
  values (
    v_org, 'catalog_change_request', v_request::text, 'CatalogChangeSubmittedV1', p_correlation_id,
    jsonb_build_object('change_request_id', v_request, 'object_type', 'SERVICE', 'object_id', p_service_id, 'version_id', p_version_id, 'sensitive', v_version.sensitive),
    p_idempotency_key, v_command
  );
  perform private.finish_catalog_command(v_actor, 'catalog.service.submit', p_idempotency_key, v_response);
  return v_response;
end;
$$;

create or replace function public.decide_catalog_change(
  p_change_request_id uuid,
  p_decision text,
  p_reason text,
  p_expected_row_version integer,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_change public.catalog_change_requests%rowtype;
  v_org uuid;
  v_hash text;
  v_command uuid;
  v_replay jsonb;
  v_status text;
  v_before_hash text;
  v_after_hash text;
  v_response jsonb;
begin
  if p_change_request_id is null or p_decision is null or p_decision not in ('APPROVE', 'REJECT')
     or p_expected_row_version is null or p_expected_row_version < 1
     or length(btrim(coalesce(p_reason, ''))) not between 3 and 1000
  then
    raise exception 'INVALID_CATALOG_DECISION' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('catalog-change:' || p_change_request_id::text, 0));
  select * into v_change from public.catalog_change_requests where id = p_change_request_id for update;
  if not found then
    raise exception 'CATALOG_CHANGE_NOT_FOUND' using errcode = 'P0002';
  end if;
  begin
    perform private.assert_catalog_central_aal2_locked(v_actor);
  exception
    when insufficient_privilege then
      raise exception 'CATALOG_APPROVAL_DENIED' using errcode = '42501';
  end;
  perform private.assert_catalog_permission_locked(v_change.library_id, 'CATALOG_APPROVE', v_actor);
  if v_change.requested_by = v_actor then
    raise exception 'CATALOG_SELF_APPROVAL_DENIED' using errcode = '42501';
  end if;
  v_hash := private.canonical_request_hash(jsonb_build_object(
    'operation', 'catalog.change.decide.v2',
    'change_request_id', p_change_request_id,
    'decision', p_decision,
    'reason', btrim(p_reason),
    'expected', p_expected_row_version
  ));
  select b.command_id, b.response_body into v_command, v_replay
    from private.begin_catalog_command(v_actor, 'catalog.change.decide', p_idempotency_key, v_hash) b;
  if v_replay is not null then
    return v_replay;
  end if;
  if v_change.status is distinct from 'IN_REVIEW' or v_change.row_version is distinct from p_expected_row_version then
    raise exception 'STALE_CATALOG_VERSION' using errcode = '40001';
  end if;
  perform private.assert_catalog_permission_locked(v_change.library_id, 'CATALOG_APPROVE', v_actor);
  v_status := case when p_decision = 'APPROVE' then 'APPROVED' else 'DRAFT' end;
  if v_change.target_type = 'LIBRARY' then
    select pv.content_hash into v_before_hash from public.catalog_libraries i left join public.catalog_library_versions pv on pv.id = i.current_published_version_id where i.id = v_change.target_id;
    perform 1 from public.catalog_library_versions where id = v_change.target_version_id and library_id = v_change.library_id and status = 'IN_REVIEW' for update;
    update public.catalog_library_versions set status = v_status, row_version = row_version + 1 where id = v_change.target_version_id and library_id = v_change.library_id and status = 'IN_REVIEW' returning content_hash into v_after_hash;
    update public.catalog_libraries set status = v_status, row_version = row_version + 1, updated_at = clock_timestamp() where id = v_change.target_id;
  elsif v_change.target_type = 'CATEGORY' then
    select pv.content_hash into v_before_hash from public.catalog_categories i left join public.catalog_category_versions pv on pv.id = i.current_published_version_id where i.id = v_change.target_id;
    perform 1 from public.catalog_category_versions where id = v_change.target_version_id and category_id = v_change.target_id and library_id = v_change.library_id and status = 'IN_REVIEW' for update;
    update public.catalog_category_versions set status = v_status, row_version = row_version + 1 where id = v_change.target_version_id and category_id = v_change.target_id and library_id = v_change.library_id and status = 'IN_REVIEW' returning content_hash into v_after_hash;
    update public.catalog_categories set status = v_status, row_version = row_version + 1 where id = v_change.target_id;
  elsif v_change.target_type = 'SUBCATEGORY' then
    select pv.content_hash into v_before_hash from public.catalog_subcategories i left join public.catalog_subcategory_versions pv on pv.id = i.current_published_version_id where i.id = v_change.target_id;
    perform 1 from public.catalog_subcategory_versions where id = v_change.target_version_id and subcategory_id = v_change.target_id and library_id = v_change.library_id and status = 'IN_REVIEW' for update;
    update public.catalog_subcategory_versions set status = v_status, row_version = row_version + 1 where id = v_change.target_version_id and subcategory_id = v_change.target_id and library_id = v_change.library_id and status = 'IN_REVIEW' returning content_hash into v_after_hash;
    update public.catalog_subcategories set status = v_status, row_version = row_version + 1 where id = v_change.target_id;
  elsif v_change.target_type = 'SERVICE' then
    select pv.content_hash into v_before_hash from public.catalog_services i left join public.catalog_service_versions pv on pv.id = i.current_published_version_id where i.id = v_change.target_id;
    perform 1 from public.catalog_service_versions where id = v_change.target_version_id and service_id = v_change.target_id and library_id = v_change.library_id and status = 'IN_REVIEW' for update;
    update public.catalog_service_versions set status = v_status, row_version = row_version + 1 where id = v_change.target_version_id and service_id = v_change.target_id and library_id = v_change.library_id and status = 'IN_REVIEW' returning content_hash into v_after_hash;
    update public.catalog_services set status = v_status, row_version = row_version + 1 where id = v_change.target_id;
    update public.catalog_service_subcategory_link_versions lv
       set status = v_status, row_version = lv.row_version + 1
      from public.catalog_service_subcategory_links l
     where l.service_id = v_change.target_id
       and l.link_type = 'PRIMARY'
       and l.status not in ('RETIRED', 'ARCHIVED')
       and lv.link_id = l.id
       and lv.id = l.current_version_id
       and lv.status = 'IN_REVIEW';
    update public.catalog_service_subcategory_links
       set status = v_status, row_version = row_version + 1
     where service_id = v_change.target_id and link_type = 'PRIMARY' and status = 'IN_REVIEW';
  elsif v_change.target_type = 'QUESTIONNAIRE' then
    select pv.snapshot_hash into v_before_hash from public.questionnaires i left join public.questionnaire_versions pv on pv.id = i.current_published_version_id where i.id = v_change.target_id;
    perform 1 from public.questionnaire_versions where id = v_change.target_version_id and questionnaire_id = v_change.target_id and library_id = v_change.library_id and status = 'CENTRAL_REVIEW' for update;
    update public.questionnaire_versions
       set status = case when p_decision = 'APPROVE' then 'APPROVED' else 'DRAFT' end, row_version = row_version + 1
     where id = v_change.target_version_id and questionnaire_id = v_change.target_id and library_id = v_change.library_id and status = 'CENTRAL_REVIEW'
     returning snapshot_hash into v_after_hash;
    update public.questionnaires set row_version = row_version + 1 where id = v_change.target_id;
    v_status := case when p_decision = 'APPROVE' then 'APPROVED' else 'DRAFT' end;
  elsif v_change.target_type = 'RULE' then
    select pv.compiled_hash into v_before_hash from public.question_rules i left join public.question_rule_versions pv on pv.id = i.current_published_version_id where i.id = v_change.target_id;
    perform 1 from public.question_rule_versions where id = v_change.target_version_id and rule_id = v_change.target_id and library_id = v_change.library_id and status = 'IN_REVIEW' for update;
    update public.question_rule_versions
       set status = v_status, row_version = row_version + 1
     where id = v_change.target_version_id and rule_id = v_change.target_id and library_id = v_change.library_id and status = 'IN_REVIEW'
     returning compiled_hash into v_after_hash;
    update public.question_rules set row_version = row_version + 1 where id = v_change.target_id;
  elsif v_change.target_type = 'RELEASE' then
    select r.snapshot_hash into v_before_hash from public.catalog_libraries l left join public.catalog_releases r on r.id = l.current_release_id where l.id = v_change.library_id;
    perform 1 from public.catalog_releases where id = v_change.target_id and library_id = v_change.library_id and status = 'IN_REVIEW' for update;
    if p_decision = 'APPROVE' then
      update public.catalog_releases set status = 'APPROVED', approved_by = v_actor, approved_at = clock_timestamp(), row_version = row_version + 1 where id = v_change.target_id and library_id = v_change.library_id and status = 'IN_REVIEW' returning snapshot_hash into v_after_hash;
    else
      update public.catalog_releases set status = 'DRAFT', approved_by = null, approved_at = null, row_version = row_version + 1 where id = v_change.target_id and library_id = v_change.library_id and status = 'IN_REVIEW' returning snapshot_hash into v_after_hash;
    end if;
  else
    raise exception 'UNSUPPORTED_CATALOG_CHANGE_TARGET' using errcode = '0A000';
  end if;
  if v_after_hash is null then
    raise exception 'INVALID_CATALOG_VERSION_STATE' using errcode = '55000';
  end if;
  update public.catalog_change_requests
    set status = case when p_decision = 'APPROVE' then 'APPROVED' else 'REJECTED' end,
        reviewed_by = v_actor,
        reviewed_at = clock_timestamp(),
        review_comment = btrim(p_reason),
        row_version = row_version + 1
  where id = p_change_request_id;
  select steward_organization_id into v_org from public.catalog_libraries where id = v_change.library_id;
  insert into public.catalog_approvals(change_request_id, library_id, decision, before_hash, after_hash, comment, decided_by, correlation_id)
  values (p_change_request_id, v_change.library_id, case when p_decision = 'APPROVE' then 'APPROVED' else 'REJECTED' end, v_before_hash, v_after_hash, btrim(p_reason), v_actor, p_correlation_id);
  v_response := jsonb_build_object(
    'outcome', case when p_decision = 'APPROVE' then 'CATALOG_CHANGE_APPROVED' else 'CATALOG_CHANGE_REJECTED' end,
    'change_request_id', p_change_request_id,
    'object_type', v_change.target_type,
    'object_id', v_change.target_id,
    'version_id', v_change.target_version_id,
    'change_row_version', p_expected_row_version + 1,
    'target_status', v_status,
    'command_id', v_command
  );
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, previous_hash, event_hash)
  values (
    v_org, v_actor, 'USER', case when p_decision = 'APPROVE' then 'catalog.change.approved' else 'catalog.change.rejected' end,
    'catalog_change_request', p_change_request_id::text, p_correlation_id,
    jsonb_build_object('object_type', v_change.target_type, 'object_id', v_change.target_id, 'version_id', v_change.target_version_id, 'reason', btrim(p_reason), 'command_id', v_command),
    null, repeat('0', 64)
  );
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key, causation_id)
  values (
    v_org, 'catalog_change_request', p_change_request_id::text,
    case when p_decision = 'APPROVE' then 'CatalogChangeApprovedV1' else 'CatalogChangeRejectedV1' end,
    p_correlation_id,
    jsonb_build_object('change_request_id', p_change_request_id, 'object_type', v_change.target_type, 'object_id', v_change.target_id, 'version_id', v_change.target_version_id),
    p_idempotency_key, v_command
  );
  perform private.finish_catalog_command(v_actor, 'catalog.change.decide', p_idempotency_key, v_response);
  return v_response;
end;
$$;

notify pgrst, 'reload schema';
