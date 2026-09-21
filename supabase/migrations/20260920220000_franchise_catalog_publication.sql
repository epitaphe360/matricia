-- Franchisee publication of an approved library snapshot, plus questionnaire/rule
-- submit to Matricia. Additive: widens change-request targets and rule statuses.

alter table public.catalog_change_requests
  drop constraint catalog_change_requests_target_type_check;
alter table public.catalog_change_requests
  add constraint catalog_change_requests_target_type_check
  check (target_type in (
    'LIBRARY','CATEGORY','SUBCATEGORY','SERVICE','SERVICE_SUBCATEGORY_LINK','RELEASE','QUESTIONNAIRE','RULE'
  ));

alter table public.question_rule_versions
  drop constraint question_rule_versions_status_check;
alter table public.question_rule_versions
  add constraint question_rule_versions_status_check
  check (status in ('DRAFT','IN_REVIEW','APPROVED','PUBLISHED','SUPERSEDED','ARCHIVED'));

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
     set status = 'IN_REVIEW', row_version = row_version + 1
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

create function public.submit_franchise_catalog_questionnaire(
  p_questionnaire_id uuid,
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
  v_identity public.questionnaires%rowtype;
  v_version public.questionnaire_versions%rowtype;
  v_org uuid;
  v_hash text;
  v_command uuid;
  v_replay jsonb;
  v_request uuid;
  v_response jsonb;
begin
  if p_questionnaire_id is null or p_version_id is null
     or p_expected_identity_row_version is null or p_expected_identity_row_version < 1
     or p_expected_version_row_version is null or p_expected_version_row_version < 1
  then
    raise exception 'INVALID_CATALOG_CHANGE' using errcode = '22023';
  end if;
  if v_actor is null then
    raise exception 'CATALOG_SCOPE_DENIED' using errcode = '42501';
  end if;
  select * into v_identity from public.questionnaires where id = p_questionnaire_id;
  if not found or not private.has_library_permission(v_identity.library_id, 'CATALOG_SUBMIT', v_actor) then
    raise exception 'CATALOG_SCOPE_DENIED' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('catalog-object:QUESTIONNAIRE:' || p_questionnaire_id::text, 0));
  select * into v_identity from public.questionnaires where id = p_questionnaire_id for update;
  select * into v_version from public.questionnaire_versions where id = p_version_id and questionnaire_id = p_questionnaire_id for update;
  if not found then
    raise exception 'CATALOG_VERSION_NOT_FOUND' using errcode = 'P0002';
  end if;
  perform private.assert_catalog_permission_locked(v_identity.library_id, 'CATALOG_SUBMIT', v_actor);
  if v_version.sensitive and auth.jwt()->>'aal' is distinct from 'aal2' then
    raise exception 'CATALOG_SENSITIVE_MFA_REQUIRED' using errcode = '42501';
  end if;
  v_hash := private.canonical_request_hash(jsonb_build_object(
    'operation', 'catalog.questionnaire.submit.v1',
    'questionnaire_id', p_questionnaire_id,
    'version_id', p_version_id,
    'expected_identity', p_expected_identity_row_version,
    'expected_version', p_expected_version_row_version
  ));
  select b.command_id, b.response_body into v_command, v_replay
    from private.begin_catalog_command(v_actor, 'catalog.questionnaire.submit', p_idempotency_key, v_hash) b;
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
  if v_identity.status is distinct from 'DRAFT'
     or v_version.status not in ('DRAFT', 'LOCAL_TEST', 'FRANCHISE_REVIEW')
  then
    raise exception 'INVALID_CATALOG_VERSION_STATE' using errcode = '55000';
  end if;
  insert into public.catalog_change_requests(library_id, target_type, target_id, target_version_id, sensitive, requested_by)
  values (v_identity.library_id, 'QUESTIONNAIRE', p_questionnaire_id, p_version_id, v_version.sensitive, v_actor)
  returning id into v_request;
  update public.questionnaire_versions set status = 'CENTRAL_REVIEW', row_version = row_version + 1 where id = p_version_id;
  update public.questionnaires set row_version = row_version + 1 where id = p_questionnaire_id;
  select steward_organization_id into v_org from public.catalog_libraries where id = v_identity.library_id;
  v_response := jsonb_build_object(
    'outcome', 'CATALOG_CHANGE_SUBMITTED',
    'change_request_id', v_request,
    'object_type', 'QUESTIONNAIRE',
    'object_id', p_questionnaire_id,
    'version_id', p_version_id,
    'identity_row_version', p_expected_identity_row_version + 1,
    'version_row_version', p_expected_version_row_version + 1,
    'sensitive', v_version.sensitive,
    'command_id', v_command
  );
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, previous_hash, event_hash)
  values (
    v_org, v_actor, 'USER', 'catalog.change.submitted', 'catalog_change_request', v_request::text, p_correlation_id,
    jsonb_build_object('object_type', 'QUESTIONNAIRE', 'object_id', p_questionnaire_id, 'version_id', p_version_id, 'sensitive', v_version.sensitive, 'command_id', v_command),
    v_version.snapshot_hash, repeat('0', 64)
  );
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key, causation_id)
  values (
    v_org, 'catalog_change_request', v_request::text, 'CatalogChangeSubmittedV1', p_correlation_id,
    jsonb_build_object('change_request_id', v_request, 'object_type', 'QUESTIONNAIRE', 'object_id', p_questionnaire_id, 'version_id', p_version_id, 'sensitive', v_version.sensitive),
    p_idempotency_key, v_command
  );
  perform private.finish_catalog_command(v_actor, 'catalog.questionnaire.submit', p_idempotency_key, v_response);
  return v_response;
end;
$$;

create function public.submit_franchise_catalog_rule(
  p_rule_id uuid,
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
  v_identity public.question_rules%rowtype;
  v_version public.question_rule_versions%rowtype;
  v_org uuid;
  v_hash text;
  v_command uuid;
  v_replay jsonb;
  v_request uuid;
  v_response jsonb;
begin
  if p_rule_id is null or p_version_id is null
     or p_expected_identity_row_version is null or p_expected_identity_row_version < 1
     or p_expected_version_row_version is null or p_expected_version_row_version < 1
  then
    raise exception 'INVALID_CATALOG_CHANGE' using errcode = '22023';
  end if;
  if v_actor is null then
    raise exception 'CATALOG_SCOPE_DENIED' using errcode = '42501';
  end if;
  select * into v_identity from public.question_rules where id = p_rule_id;
  if not found or not private.has_library_permission(v_identity.library_id, 'CATALOG_SUBMIT', v_actor) then
    raise exception 'CATALOG_SCOPE_DENIED' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('catalog-object:RULE:' || p_rule_id::text, 0));
  select * into v_identity from public.question_rules where id = p_rule_id for update;
  select * into v_version from public.question_rule_versions where id = p_version_id and rule_id = p_rule_id for update;
  if not found then
    raise exception 'CATALOG_VERSION_NOT_FOUND' using errcode = 'P0002';
  end if;
  perform private.assert_catalog_permission_locked(v_identity.library_id, 'CATALOG_SUBMIT', v_actor);
  if v_version.sensitive and auth.jwt()->>'aal' is distinct from 'aal2' then
    raise exception 'CATALOG_SENSITIVE_MFA_REQUIRED' using errcode = '42501';
  end if;
  v_hash := private.canonical_request_hash(jsonb_build_object(
    'operation', 'catalog.rule.submit.v1',
    'rule_id', p_rule_id,
    'version_id', p_version_id,
    'expected_identity', p_expected_identity_row_version,
    'expected_version', p_expected_version_row_version
  ));
  select b.command_id, b.response_body into v_command, v_replay
    from private.begin_catalog_command(v_actor, 'catalog.rule.submit', p_idempotency_key, v_hash) b;
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
  if v_identity.status is distinct from 'DRAFT' or v_version.status is distinct from 'DRAFT' then
    raise exception 'INVALID_CATALOG_VERSION_STATE' using errcode = '55000';
  end if;
  insert into public.catalog_change_requests(library_id, target_type, target_id, target_version_id, sensitive, requested_by)
  values (v_identity.library_id, 'RULE', p_rule_id, p_version_id, v_version.sensitive, v_actor)
  returning id into v_request;
  update public.question_rule_versions set status = 'IN_REVIEW', row_version = row_version + 1 where id = p_version_id;
  update public.question_rules set row_version = row_version + 1 where id = p_rule_id;
  select steward_organization_id into v_org from public.catalog_libraries where id = v_identity.library_id;
  v_response := jsonb_build_object(
    'outcome', 'CATALOG_CHANGE_SUBMITTED',
    'change_request_id', v_request,
    'object_type', 'RULE',
    'object_id', p_rule_id,
    'version_id', p_version_id,
    'identity_row_version', p_expected_identity_row_version + 1,
    'version_row_version', p_expected_version_row_version + 1,
    'sensitive', v_version.sensitive,
    'command_id', v_command
  );
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, previous_hash, event_hash)
  values (
    v_org, v_actor, 'USER', 'catalog.change.submitted', 'catalog_change_request', v_request::text, p_correlation_id,
    jsonb_build_object('object_type', 'RULE', 'object_id', p_rule_id, 'version_id', p_version_id, 'sensitive', v_version.sensitive, 'command_id', v_command),
    v_version.compiled_hash, repeat('0', 64)
  );
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key, causation_id)
  values (
    v_org, 'catalog_change_request', v_request::text, 'CatalogChangeSubmittedV1', p_correlation_id,
    jsonb_build_object('change_request_id', v_request, 'object_type', 'RULE', 'object_id', p_rule_id, 'version_id', p_version_id, 'sensitive', v_version.sensitive),
    p_idempotency_key, v_command
  );
  perform private.finish_catalog_command(v_actor, 'catalog.rule.submit', p_idempotency_key, v_response);
  return v_response;
end;
$$;

create function private.franchise_catalog_snapshot_items(p_library_id uuid)
returns table(
  object_type text,
  object_id uuid,
  version_id uuid,
  content_hash text,
  version_status text,
  sensitive boolean,
  translation_review_status text
)
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select 'LIBRARY', p_library_id, v.id, v.content_hash, v.status, v.sensitive, v.translation_review_status
    from (
      select id, content_hash, status, sensitive, translation_review_status
        from public.catalog_library_versions
       where library_id = p_library_id and status in ('APPROVED', 'PUBLISHED')
       order by case when status = 'APPROVED' then 0 else 1 end, version desc
       limit 1
    ) v
  union all
  select 'CATEGORY', c.id, v.id, v.content_hash, v.status, v.sensitive, v.translation_review_status
    from public.catalog_categories c
    join lateral (
      select id, content_hash, status, sensitive, translation_review_status
        from public.catalog_category_versions x
       where x.category_id = c.id and x.status in ('APPROVED', 'PUBLISHED')
       order by case when x.status = 'APPROVED' then 0 else 1 end, x.version desc
       limit 1
    ) v on true
   where c.library_id = p_library_id and c.status <> 'ARCHIVED'
  union all
  select 'SUBCATEGORY', s.id, v.id, v.content_hash, v.status, v.sensitive, v.translation_review_status
    from public.catalog_subcategories s
    join lateral (
      select id, content_hash, status, sensitive, translation_review_status
        from public.catalog_subcategory_versions x
       where x.subcategory_id = s.id and x.status in ('APPROVED', 'PUBLISHED')
       order by case when x.status = 'APPROVED' then 0 else 1 end, x.version desc
       limit 1
    ) v on true
   where s.library_id = p_library_id and s.status <> 'ARCHIVED'
  union all
  select 'SERVICE', s.id, v.id, v.content_hash, v.status, v.sensitive, v.translation_review_status
    from public.catalog_services s
    join lateral (
      select id, content_hash, status, sensitive, translation_review_status
        from public.catalog_service_versions x
       where x.service_id = s.id and x.status in ('APPROVED', 'PUBLISHED')
       order by case when x.status = 'APPROVED' then 0 else 1 end, x.version desc
       limit 1
    ) v on true
   where s.library_id = p_library_id and s.status <> 'ARCHIVED'
  union all
  select 'SERVICE_SUBCATEGORY_LINK', l.id, v.id, v.content_hash, v.status, false, 'APPROVED'
    from public.catalog_service_subcategory_links l
    join lateral (
      select id, content_hash, status
        from public.catalog_service_subcategory_link_versions x
       where x.link_id = l.id and x.status in ('APPROVED', 'PUBLISHED')
       order by case when x.status = 'APPROVED' then 0 else 1 end, x.version desc
       limit 1
    ) v on true
   where l.library_id = p_library_id and l.status <> 'ARCHIVED';
$$;

create function public.submit_franchise_catalog_publication(
  p_library_id uuid,
  p_expected_library_row_version integer,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_library public.catalog_libraries%rowtype;
  v_hash text;
  v_command uuid;
  v_replay jsonb;
  v_release uuid;
  v_sort integer := 0;
  v_item record;
  v_snapshot text;
  v_bundle text;
  v_key text;
  v_sensitive boolean := false;
  v_has_approved_service boolean := false;
  v_status text;
  v_from timestamptz := clock_timestamp();
  v_audience jsonb := '{"kind":"PUBLIC"}'::jsonb;
  v_response jsonb;
  v_org uuid;
begin
  if p_library_id is null or p_expected_library_row_version is null or p_expected_library_row_version < 1 then
    raise exception 'INVALID_CATALOG_RELEASE' using errcode = '22023';
  end if;
  if v_actor is null or not private.has_library_permission(p_library_id, 'CATALOG_PUBLISH', v_actor) then
    raise exception 'CATALOG_SCOPE_DENIED' using errcode = '42501';
  end if;
  v_hash := private.canonical_request_hash(jsonb_build_object(
    'operation', 'catalog.franchise.publish.v1',
    'library_id', p_library_id,
    'expected', p_expected_library_row_version
  ));
  select b.command_id, b.response_body into v_command, v_replay
    from private.begin_catalog_command(v_actor, 'catalog.franchise.publish', p_idempotency_key, v_hash) b;
  if v_replay is not null then
    return v_replay;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('catalog-library:' || p_library_id::text, 0));
  select * into v_library from public.catalog_libraries where id = p_library_id for update;
  if not found then
    raise exception 'CATALOG_LIBRARY_NOT_FOUND' using errcode = 'P0002';
  end if;
  perform private.assert_catalog_permission_locked(p_library_id, 'CATALOG_PUBLISH', v_actor);
  perform private.assert_catalog_permission_locked(p_library_id, 'CATALOG_SUBMIT', v_actor);
  if v_library.row_version is distinct from p_expected_library_row_version then
    raise exception 'STALE_CATALOG_VERSION' using errcode = '40001';
  end if;
  if not exists(select 1 from private.franchise_catalog_snapshot_items(p_library_id) i where i.object_type = 'LIBRARY')
     or not exists(select 1 from private.franchise_catalog_snapshot_items(p_library_id) i where i.object_type = 'CATEGORY')
     or not exists(select 1 from private.franchise_catalog_snapshot_items(p_library_id) i where i.object_type = 'SUBCATEGORY')
     or not exists(select 1 from private.franchise_catalog_snapshot_items(p_library_id) i where i.object_type = 'SERVICE')
     or not exists(select 1 from private.franchise_catalog_snapshot_items(p_library_id) i where i.object_type = 'SERVICE_SUBCATEGORY_LINK')
  then
    raise exception 'INCOMPLETE_CATALOG_RELEASE' using errcode = '23514';
  end if;
  if exists(
    select 1 from private.franchise_catalog_snapshot_items(p_library_id) i
     where i.object_type in ('LIBRARY', 'CATEGORY', 'SUBCATEGORY', 'SERVICE')
       and i.translation_review_status is distinct from 'APPROVED'
  ) then
    raise exception 'CATALOG_AR_REVIEW_REQUIRED' using errcode = '23514';
  end if;
  select exists(
    select 1 from private.franchise_catalog_snapshot_items(p_library_id) i
     where i.object_type = 'SERVICE' and i.version_status = 'APPROVED'
  ) into v_has_approved_service;
  if not v_has_approved_service then
    raise exception 'INVALID_CATALOG_VERSION_STATE' using errcode = '55000';
  end if;
  select bool_or(i.sensitive) into v_sensitive from private.franchise_catalog_snapshot_items(p_library_id) i;
  v_sensitive := coalesce(v_sensitive, false);
  if v_sensitive and auth.jwt()->>'aal' is distinct from 'aal2' then
    raise exception 'CATALOG_SENSITIVE_MFA_REQUIRED' using errcode = '42501';
  end if;
  select encode(extensions.digest(convert_to(string_agg(
    i.object_type || ':' || i.object_id::text || ':' || i.version_id::text || ':' || i.content_hash, ','
    order by i.object_type, i.object_id
  ), 'UTF8'), 'sha256'), 'hex')
    into v_bundle
    from private.franchise_catalog_snapshot_items(p_library_id) i;
  v_key := 'FRN.' || regexp_replace(v_library.code, '[^A-Z0-9]', '', 'g') || '.' || upper(substr(encode(extensions.digest(convert_to(p_idempotency_key, 'UTF8'), 'sha256'), 'hex'), 1, 12));
  insert into public.catalog_releases(
    library_id, release_key, source_bundle_hash, based_on_release_id, requires_central_approval, created_by, audience
  ) values (
    p_library_id, v_key, v_bundle, v_library.current_release_id, v_sensitive, v_actor, v_audience
  ) returning id into v_release;
  for v_item in
    select * from private.franchise_catalog_snapshot_items(p_library_id)
    order by case object_type
      when 'LIBRARY' then 1 when 'CATEGORY' then 2 when 'SUBCATEGORY' then 3
      when 'SERVICE' then 4 else 5 end, object_id
  loop
    v_sort := v_sort + 1;
    insert into public.catalog_release_items(release_id, library_id, object_type, object_id, version_id, content_hash, sort_order)
    values (v_release, p_library_id, v_item.object_type, v_item.object_id, v_item.version_id, v_item.content_hash, v_sort);
  end loop;
  perform private.validate_catalog_release_tree(v_release);
  select encode(extensions.digest(convert_to(string_agg(
    object_type || ':' || object_id::text || ':' || version_id::text || ':' || content_hash || ':' || sort_order::text, ','
    order by sort_order, object_type, object_id
  ), 'UTF8'), 'sha256'), 'hex')
    into v_snapshot
    from public.catalog_release_items
   where release_id = v_release;
  v_status := case when v_sensitive then 'IN_REVIEW' else 'APPROVED' end;
  update public.catalog_releases
     set snapshot_hash = v_snapshot,
         requires_central_approval = v_sensitive,
         status = v_status,
         row_version = row_version + 1
   where id = v_release;
  if v_sensitive then
    insert into public.catalog_change_requests(library_id, target_type, target_id, target_version_id, sensitive, requested_by)
    values (p_library_id, 'RELEASE', v_release, v_release, true, v_actor);
  else
    if exists(
      select 1 from public.catalog_releases r
       where r.library_id = p_library_id
         and r.id <> v_release
         and r.status in ('SCHEDULED', 'PUBLISHING', 'PUBLISHED')
         and (r.status <> 'PUBLISHED' or r.id is distinct from v_library.current_release_id)
         and private.catalog_audiences_overlap(r.audience, v_audience)
         and tstzrange(r.effective_from, r.effective_until, '[)') && tstzrange(v_from, null, '[)')
    ) then
      raise exception 'CATALOG_SCHEDULE_CONFLICT' using errcode = '23P01';
    end if;
    update public.catalog_releases
       set status = 'SCHEDULED',
           effective_from = v_from,
           audience = v_audience,
           approved_by = v_actor,
           approved_at = v_from,
           row_version = row_version + 1
     where id = v_release;
    v_status := 'SCHEDULED';
  end if;
  update public.catalog_libraries
     set row_version = row_version + 1, updated_at = clock_timestamp()
   where id = p_library_id;
  select steward_organization_id into v_org from public.catalog_libraries where id = p_library_id;
  v_response := jsonb_build_object(
    'outcome', case when v_status = 'SCHEDULED' then 'CATALOG_RELEASE_SCHEDULED' else 'CATALOG_RELEASE_SUBMITTED' end,
    'release_id', v_release,
    'status', v_status,
    'snapshot_hash', v_snapshot,
    'library_row_version', p_expected_library_row_version + 1,
    'command_id', v_command
  );
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, previous_hash, event_hash)
  values (
    v_org, v_actor, 'USER',
    case when v_status = 'SCHEDULED' then 'catalog.release.scheduled' else 'catalog.release.submitted' end,
    'catalog_release', v_release::text, p_correlation_id,
    jsonb_build_object('library_id', p_library_id, 'status', v_status, 'snapshot_hash', v_snapshot, 'command_id', v_command),
    null, repeat('0', 64)
  );
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key, causation_id)
  values (
    v_org, 'catalog_release', v_release::text,
    case when v_status = 'SCHEDULED' then 'CatalogReleaseScheduledV1' else 'CatalogChangeSubmittedV1' end,
    p_correlation_id,
    jsonb_build_object('release_id', v_release, 'library_id', p_library_id, 'status', v_status),
    p_idempotency_key, v_command
  );
  perform private.finish_catalog_command(v_actor, 'catalog.franchise.publish', p_idempotency_key, v_response);
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
       set status = v_status, row_version = row_version + 1
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

revoke all on function private.franchise_catalog_snapshot_items(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.submit_franchise_catalog_questionnaire(uuid, uuid, integer, integer, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.submit_franchise_catalog_rule(uuid, uuid, integer, integer, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.submit_franchise_catalog_publication(uuid, integer, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.submit_franchise_catalog_questionnaire(uuid, uuid, integer, integer, text, uuid)
  to authenticated;
grant execute on function public.submit_franchise_catalog_rule(uuid, uuid, integer, integer, text, uuid)
  to authenticated;
grant execute on function public.submit_franchise_catalog_publication(uuid, integer, text, uuid)
  to authenticated;

notify pgrst, 'reload schema';
