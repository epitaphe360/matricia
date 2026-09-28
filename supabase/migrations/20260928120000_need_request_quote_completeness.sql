-- Need → request conversion reuses the intake answers and computes required_for_quote completeness server-side.
-- Clients complete only the missing fields; each completion is a new immutable request version.
-- New-request entitlement also blocks once client_trials.trial_ends_at has passed, without waiting for a status job.
-- Rollback: re-apply the function bodies of 20260920210000 and 20260921150000, then drop
-- public.complete_service_request_information, public.get_service_request_quote_questions,
-- private.parse_need_intake_answers, private.service_quote_questions and private.service_request_missing_quote_keys.

create or replace function private.parse_need_intake_answers(p_text text) returns jsonb
language sql immutable set search_path = pg_catalog as $$
  select coalesce(jsonb_object_agg(parts[1], left(btrim(parts[2]), 1200)), '{}'::jsonb)
  from (
    select regexp_match(line, '^([A-Za-z][A-Za-z0-9_.-]{1,159}): (.+)$') as parts
    from regexp_split_to_table(coalesce(p_text, ''), E'\n') as line
  ) parsed
  where parts is not null and btrim(parts[2]) <> ''
$$;

create or replace function private.service_quote_questions(p_service_id uuid)
returns table(data_key text, required boolean, answer_type text, label_fr text, label_ar text, help_fr text, help_ar text, options jsonb)
language sql stable security definer set search_path = pg_catalog, public as $$
  select distinct on (question.data_key)
    question.data_key, question.required_for_quote, question.answer_type,
    question.label_fr, question.label_ar, question.help_fr, question.help_ar, question.options
  from public.question_versions question
  where question.source_service_id = p_service_id
    and question.status = 'PUBLISHED'
    and question.answer_type not in ('FILE', 'MULTI_FILE', 'IMAGE', 'TABLE', 'REPEATER')
  order by question.data_key, question.version desc
$$;

create or replace function private.service_request_missing_quote_keys(p_service_id uuid, p_data jsonb) returns text[]
language sql stable security definer set search_path = pg_catalog, public, private as $$
  select coalesce(array_agg(question.data_key order by question.data_key), '{}'::text[])
  from private.service_quote_questions(p_service_id) question
  where question.required and btrim(coalesce(p_data->>question.data_key, '')) = ''
$$;

revoke all on function private.parse_need_intake_answers(text) from public, anon, authenticated, service_role;
revoke all on function private.service_quote_questions(uuid) from public, anon, authenticated, service_role;
revoke all on function private.service_request_missing_quote_keys(uuid, jsonb) from public, anon, authenticated, service_role;

create or replace function public.create_service_request_from_need_intake(
  p_intake_id uuid,
  p_service_code text,
  p_payload jsonb,
  p_change_reason text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  intake public.public_need_intakes%rowtype;
  conversion public.public_need_intake_conversions%rowtype;
  service public.catalog_services%rowtype;
  service_version public.catalog_service_versions%rowtype;
  questionnaire_version public.questionnaire_versions%rowtype;
  snapshot_code text;
  intake_answers jsonb;
  region text;
  quote_data jsonb;
  missing text[];
  controlled_payload jsonb;
  response jsonb;
  request_id uuid;
begin
  if auth.uid() is null
     or p_service_code is null
     or p_service_code !~ '^[A-Z][A-Z0-9_-]{1,79}$'
     or jsonb_typeof(p_payload) <> 'object'
     or length(btrim(coalesce(p_change_reason, ''))) not between 3 and 500 then
    raise exception 'INVALID_NEED_REQUEST' using errcode='22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('need-intake-request:' || p_intake_id::text, 0));
  select * into intake from public.public_need_intakes where id = p_intake_id for update;
  if not found or not private.can_manage_client_request(intake.organization_id, auth.uid()) then
    raise exception 'NEED_REQUEST_SCOPE_DENIED' using errcode='42501';
  end if;

  select * into conversion from public.public_need_intake_conversions where intake_id = p_intake_id;
  if found then
    if conversion.service_code <> p_service_code then
      raise exception 'NEED_INTAKE_ALREADY_CONVERTED' using errcode='55000';
    end if;
    if not exists (
      select 1 from public.service_requests request
      where request.id = conversion.service_request_id
        and request.client_organization_id = conversion.organization_id
    ) then
      raise exception 'NEED_REQUEST_LINK_INVALID' using errcode='23514';
    end if;
    return jsonb_build_object(
      'outcome', 'SERVICE_REQUEST_CREATED',
      'request_id', conversion.service_request_id,
      'status', (select request.status from public.service_requests request where request.id = conversion.service_request_id),
      'replayed', true
    );
  end if;

  snapshot_code := (
    select match[1]
    from regexp_matches(intake.constraints_text, '\(([A-Z][A-Z0-9_-]*-[A-Z0-9_-]+)\)', 'g') as match
    limit 1
  );
  if snapshot_code is not null and snapshot_code <> p_service_code then
    raise exception 'NEED_SERVICE_MISMATCH' using errcode='22023';
  end if;

  select * into service
  from public.catalog_services
  where code = p_service_code and status = 'PUBLISHED';
  select * into service_version
  from public.catalog_service_versions
  where id = service.current_published_version_id
    and service_id = service.id
    and library_id = service.library_id
    and status = 'PUBLISHED';
  if service.id is null or service_version.id is null then
    raise exception 'NEED_SERVICE_UNAVAILABLE' using errcode='55000';
  end if;

  select qv.* into questionnaire_version
  from public.questionnaires questionnaire
  join public.questionnaire_versions qv
    on qv.id = questionnaire.current_published_version_id
   and qv.questionnaire_id = questionnaire.id
   and qv.library_id = questionnaire.library_id
   and qv.status = 'PUBLISHED'
   and qv.audience = 'CLIENT'
  where questionnaire.library_id = service.library_id
    and questionnaire.status = 'PUBLISHED'
    and exists (
      select 1
      from public.questionnaire_version_questions link
      join public.question_versions question on question.id = link.question_version_id
      where link.questionnaire_version_id = qv.id
        and question.source_service_id = service.id
    )
  order by qv.id
  limit 1;

  if questionnaire_version.id is null then
    select qv.* into questionnaire_version
    from public.questionnaires questionnaire
    join public.questionnaire_versions qv
      on qv.id = questionnaire.current_published_version_id
     and qv.questionnaire_id = questionnaire.id
     and qv.library_id = questionnaire.library_id
     and qv.status = 'PUBLISHED'
     and qv.audience = 'CLIENT'
    where questionnaire.library_id = service.library_id
      and questionnaire.status = 'PUBLISHED'
    order by qv.id
    limit 1;
  end if;

  if questionnaire_version.id is null then
    raise exception 'NEED_QUESTIONNAIRE_UNAVAILABLE' using errcode='55000';
  end if;

  intake_answers := (
    select coalesce(jsonb_object_agg(answer.key, answer.value), '{}'::jsonb)
    from jsonb_each(private.parse_need_intake_answers(intake.constraints_text)) answer
    where exists (select 1 from private.service_quote_questions(service.id) question where question.data_key = answer.key)
  );
  region := upper(btrim(coalesce(p_payload->>'region_code', '')));
  if region <> '' and region !~ '^[A-Z][A-Z0-9_]{1,59}$' then
    raise exception 'INVALID_NEED_REQUEST' using errcode='22023';
  end if;
  quote_data := intake_answers || jsonb_build_object('region_code', region);
  missing := private.service_request_missing_quote_keys(service.id, quote_data);

  controlled_payload := jsonb_build_object(
    'description', btrim(coalesce(p_payload->>'description', '')),
    'urgency', p_payload->>'urgency',
    'desired_date', coalesce(p_payload->>'desired_date', ''),
    'budget_minor', coalesce(p_payload->>'budget_minor', ''),
    'currency_code', coalesce(nullif(p_payload->>'currency_code', ''), 'MAD'),
    'required_quote_data', quote_data,
    'required_fields_complete', region <> '' and cardinality(missing) = 0,
    'catalog_snapshot_hash', service_version.content_hash,
    'questionnaire_snapshot_hash', questionnaire_version.snapshot_hash
  );

  response := public.create_service_request(
    intake.organization_id,
    service.library_id,
    service.id,
    questionnaire_version.id,
    controlled_payload,
    p_change_reason,
    p_intake_id::text,
    p_correlation_id
  );
  request_id := (response->>'request_id')::uuid;

  insert into public.public_need_intake_conversions (
    intake_id, organization_id, service_request_id, service_id, library_id, service_code,
    catalog_snapshot_hash, questionnaire_version_id, questionnaire_snapshot_hash, created_by
  ) values (
    intake.id, intake.organization_id, request_id, service.id, service.library_id, p_service_code,
    service_version.content_hash, questionnaire_version.id, questionnaire_version.snapshot_hash, auth.uid()
  );

  insert into public.audit_events (
    organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash
  ) values (
    intake.organization_id, auth.uid(), 'USER', 'public_need.intake.converted', 'public_need_intake', intake.id::text,
    p_correlation_id, jsonb_build_object('service_request_id', request_id, 'service_code', p_service_code, 'missing_quote_keys', to_jsonb(missing)), repeat('0', 64)
  );
  insert into public.event_outbox (
    organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key
  ) values (
    intake.organization_id, 'public_need_intake', intake.id::text, 'PublicNeedIntakeConvertedV1', p_correlation_id,
    jsonb_build_object('intake_id', intake.id, 'service_request_id', request_id, 'service_code', p_service_code),
    'need-intake-converted:' || intake.id::text
  ) on conflict do nothing;

  return response || jsonb_build_object('intake_id', intake.id, 'missing_quote_keys', to_jsonb(missing), 'replayed', false);
end$$;

revoke all on function public.create_service_request_from_need_intake(uuid, text, jsonb, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.create_service_request_from_need_intake(uuid, text, jsonb, text, uuid) to authenticated;

create or replace function public.get_service_request_quote_questions(p_request_id uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, private as $$
declare
  request public.service_requests%rowtype;
  version public.service_request_versions%rowtype;
begin
  select * into request from public.service_requests where id = p_request_id;
  if not found or not private.can_manage_client_request(request.client_organization_id, auth.uid()) then
    raise exception 'REQUEST_SCOPE_DENIED' using errcode='42501';
  end if;
  select * into version from public.service_request_versions where id = request.current_version_id;
  return jsonb_build_object(
    'request_id', request.id,
    'status', request.status,
    'row_version', request.row_version,
    'version_number', version.version_number,
    'required_fields_complete', version.required_fields_complete,
    'region_code', coalesce(version.required_quote_data->>'region_code', ''),
    'questions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'data_key', question.data_key,
        'required', question.required,
        'answer_type', question.answer_type,
        'label_fr', question.label_fr,
        'label_ar', question.label_ar,
        'help_fr', question.help_fr,
        'help_ar', question.help_ar,
        'options', question.options,
        'answer', coalesce(version.required_quote_data->>question.data_key, '')
      ) order by question.required desc, question.data_key)
      from private.service_quote_questions(request.service_id) question
    ), '[]'::jsonb)
  );
end$$;

revoke all on function public.get_service_request_quote_questions(uuid) from public, anon, authenticated, service_role;
grant execute on function public.get_service_request_quote_questions(uuid) to authenticated;

create or replace function public.complete_service_request_information(
  p_request_id uuid,
  p_expected_row_version integer,
  p_answers jsonb,
  p_region_code text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare
  actor uuid := auth.uid();
  request public.service_requests%rowtype;
  version public.service_request_versions%rowtype;
  request_hash text;
  command uuid;
  replay jsonb;
  clean jsonb;
  region text;
  quote_data jsonb;
  missing text[];
  complete boolean;
  next_status text;
  next_version uuid := extensions.gen_random_uuid();
  content text;
  response jsonb;
begin
  if jsonb_typeof(coalesce(p_answers, '{}'::jsonb)) <> 'object' then
    raise exception 'INVALID_REQUEST_INFORMATION' using errcode='22023';
  end if;
  select * into request from public.service_requests where id = p_request_id;
  if not found or not private.can_manage_client_request(request.client_organization_id, actor) then
    raise exception 'REQUEST_SCOPE_DENIED' using errcode='42501';
  end if;
  request_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'operation', 'rfq.request.complete.v1', 'request_id', p_request_id, 'expected', p_expected_row_version,
    'answers', coalesce(p_answers, '{}'::jsonb), 'region', coalesce(p_region_code, '')
  )::text, 'UTF8'), 'sha256'), 'hex');
  select b.command_id, b.response_body into command, replay
  from private.begin_rfq_command(actor, 'rfq.request.complete', p_idempotency_key, request_hash) b;
  perform pg_advisory_xact_lock(hashtextextended('service-request:' || p_request_id::text, 0));
  select * into request from public.service_requests where id = p_request_id for update;
  if replay is not null then return replay; end if;
  if request.row_version <> p_expected_row_version then
    raise exception 'STALE_REQUEST_VERSION' using errcode='40001';
  end if;
  if request.status not in ('DRAFT', 'INFORMATION_REQUIRED') then
    raise exception 'INVALID_REQUEST_TRANSITION' using errcode='55000';
  end if;
  select * into version from public.service_request_versions where id = request.current_version_id;

  clean := (
    select coalesce(jsonb_object_agg(question.data_key, left(btrim(p_answers->>question.data_key), 1200)), '{}'::jsonb)
    from private.service_quote_questions(request.service_id) question
    where btrim(coalesce(p_answers->>question.data_key, '')) <> ''
  );
  region := upper(btrim(coalesce(nullif(btrim(coalesce(p_region_code, '')), ''), version.required_quote_data->>'region_code', '')));
  if region <> '' and region !~ '^[A-Z][A-Z0-9_]{1,59}$' then
    raise exception 'INVALID_REQUEST_INFORMATION' using errcode='22023';
  end if;
  quote_data := version.required_quote_data || clean || jsonb_build_object('region_code', region);
  missing := private.service_request_missing_quote_keys(request.service_id, quote_data);
  complete := region <> '' and cardinality(missing) = 0 and request.questionnaire_version_id is not null;
  next_status := case when complete then 'DRAFT' else 'INFORMATION_REQUIRED' end;
  content := encode(extensions.digest(convert_to(jsonb_build_object(
    'request_id', request.id, 'version', version.version_number + 1, 'base', version.content_hash, 'required_quote_data', quote_data
  )::text, 'UTF8'), 'sha256'), 'hex');

  insert into public.service_request_versions(
    id, request_id, client_organization_id, library_id, version_number, description, urgency, desired_date, budget_minor,
    currency_code, required_quote_data, required_fields_complete, catalog_snapshot_hash, questionnaire_snapshot_hash,
    change_reason, content_hash, created_by
  ) values (
    next_version, request.id, request.client_organization_id, request.library_id, version.version_number + 1, version.description,
    version.urgency, version.desired_date, version.budget_minor, version.currency_code, quote_data, complete,
    version.catalog_snapshot_hash, version.questionnaire_snapshot_hash, 'Compléments client pour les devis', content, actor
  );
  update public.service_requests
    set current_version_id = next_version, status = next_status, row_version = row_version + 1, updated_at = clock_timestamp()
    where id = request.id;

  response := jsonb_build_object(
    'outcome', 'SERVICE_REQUEST_INFORMATION_UPDATED', 'request_id', request.id, 'request_version_id', next_version,
    'status', next_status, 'row_version', p_expected_row_version + 1, 'missing_quote_keys', to_jsonb(missing), 'command_id', command
  );
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (request.client_organization_id, actor, 'USER', 'rfq.request.information_completed', 'service_request', request.id::text, p_correlation_id,
    jsonb_build_object('request_version_id', next_version, 'command_id', command, 'missing_quote_keys', to_jsonb(missing)), repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key, causation_id)
  values (request.client_organization_id, 'service_request', request.id::text, 'ServiceRequestInformationCompletedV1', p_correlation_id,
    jsonb_build_object('request_id', request.id, 'request_version_id', next_version, 'status', next_status), p_idempotency_key, command);
  perform private.finish_rfq_command(actor, 'rfq.request.complete', p_idempotency_key, response);
  return response;
end$$;

revoke all on function public.complete_service_request_information(uuid, integer, jsonb, text, text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.complete_service_request_information(uuid, integer, jsonb, text, text, uuid) to authenticated;

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
        and (trial.status = 'TRIAL_EXPIRED' or trial.trial_ends_at <= now())
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
