-- P06: rule validation and simulation are catalogue-authoring operations.
-- Published questionnaire visibility must never grant access to rule internals.

create or replace function private.can_execute_questionnaire_rule_engine(
  p_library_id uuid,
  p_actor_id uuid default auth.uid()
) returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select p_actor_id is not null
    and auth.jwt()->>'aal' = 'aal2'
    and exists (
      select 1
      from public.platform_user_roles role_assignment
      join public.catalog_permission_policies permission_policy
        on permission_policy.role_code = role_assignment.role_code
      where role_assignment.user_id = p_actor_id
        and role_assignment.revoked_at is null
        and permission_policy.permission_code = 'CATALOG_VIEW_DRAFT'
        and permission_policy.active
        and statement_timestamp() >= permission_policy.valid_from
        and (
          permission_policy.valid_until is null
          or statement_timestamp() < permission_policy.valid_until
        )
    )
    and private.has_library_permission(
      p_library_id,
      'CATALOG_VIEW_DRAFT',
      p_actor_id
    )
$$;

revoke all on function private.can_execute_questionnaire_rule_engine(uuid,uuid)
from public, anon, authenticated, service_role;

create or replace function private.validate_questionnaire_rule_engine_core(
  p_questionnaire_version_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
declare
  v_version public.questionnaire_versions%rowtype;
  v_rule record;
  v_questions text[];
  v_errors jsonb := '[]'::jsonb;
  v_count integer := 0;
  v_error_code text;
begin
  select *
  into v_version
  from public.questionnaire_versions
  where id = p_questionnaire_version_id;

  if not found then
    raise exception 'QUESTIONNAIRE_SCOPE_DENIED' using errcode = '42501';
  end if;

  select coalesce(
    array_agg(question_version_id::text order by question_version_id::text),
    '{}'
  )
  into v_questions
  from public.questionnaire_version_questions
  where questionnaire_version_id = v_version.id;

  for v_rule in
    select rule_version.*
    from public.questionnaire_version_rules version_rule
    join public.question_rule_versions rule_version
      on rule_version.id = version_rule.rule_version_id
    where version_rule.questionnaire_version_id = v_version.id
    order by version_rule.evaluation_order, rule_version.id
  loop
    v_count := v_count + 1;
    begin
      perform private.assert_advanced_rule_contract(
        v_rule.condition_ast,
        v_rule.actions,
        v_rule.dependency_graph,
        v_questions
      );
    exception when others then
      v_error_code := case sqlerrm
        when 'RULE_AST_MALFORMED' then 'RULE_AST_MALFORMED'
        when 'RULE_GROUP_MALFORMED' then 'RULE_GROUP_MALFORMED'
        when 'RULE_PREDICATE_MALFORMED' then 'RULE_PREDICATE_MALFORMED'
        when 'RULE_REFERENCE_OR_OPERATOR_INVALID' then 'RULE_REFERENCE_OR_OPERATOR_INVALID'
        when 'RULE_OPERAND_INVALID' then 'RULE_OPERAND_INVALID'
        when 'RULE_REGEX_UNSAFE' then 'RULE_REGEX_UNSAFE'
        when 'RULE_DEAD_BRANCH' then 'RULE_DEAD_BRANCH'
        when 'RULE_ACTIONS_MALFORMED' then 'RULE_ACTIONS_MALFORMED'
        when 'RULE_ACTION_MALFORMED' then 'RULE_ACTION_MALFORMED'
        when 'RULE_ACTION_TYPE_INVALID' then 'RULE_ACTION_TYPE_INVALID'
        when 'RULE_ACTION_TARGET_INVALID' then 'RULE_ACTION_TARGET_INVALID'
        when 'RULE_SCORE_ACTION_INVALID' then 'RULE_SCORE_ACTION_INVALID'
        when 'RULE_VALIDITY_ACTION_INVALID' then 'RULE_VALIDITY_ACTION_INVALID'
        when 'RULE_DEPENDENCY_GRAPH_MALFORMED' then 'RULE_DEPENDENCY_GRAPH_MALFORMED'
        when 'RULE_DEPENDENCY_REFERENCE_INVALID' then 'RULE_DEPENDENCY_REFERENCE_INVALID'
        when 'RULE_DEPENDENCY_CYCLE' then 'RULE_DEPENDENCY_CYCLE'
        else 'RULE_VALIDATION_FAILED'
      end;
      v_errors := v_errors || jsonb_build_array(
        jsonb_build_object(
          'rule_version_id', v_rule.id,
          'code', v_error_code
        )
      );
    end;
  end loop;

  return jsonb_build_object(
    'valid', jsonb_array_length(v_errors) = 0,
    'questionnaire_version_id', v_version.id,
    'engine_version', v_version.engine_version,
    'policy_version', v_version.policy_version,
    'question_count', cardinality(v_questions),
    'rule_count', v_count,
    'errors', v_errors
  );
exception when others then
  if sqlerrm = 'QUESTIONNAIRE_SCOPE_DENIED' then
    raise exception 'QUESTIONNAIRE_SCOPE_DENIED' using errcode = '42501';
  end if;
  raise exception 'QUESTIONNAIRE_RULE_VALIDATION_FAILED' using errcode = 'P0001';
end
$$;

revoke all on function private.validate_questionnaire_rule_engine_core(uuid)
from public, anon, authenticated, service_role;

create or replace function public.validate_questionnaire_rule_engine(
  p_questionnaire_version_id uuid
) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_library_id uuid;
begin
  if auth.uid()is null then raise exception 'AUTHENTICATION_REQUIRED'using errcode='42501';end if;
  select library_id into v_library_id from public.questionnaire_versions where id=p_questionnaire_version_id;
  if not found or not private.can_execute_questionnaire_rule_engine(v_library_id,auth.uid())then raise exception 'QUESTIONNAIRE_SCOPE_DENIED'using errcode='42501';end if;
  return private.validate_questionnaire_rule_engine_core(p_questionnaire_version_id);
exception when others then
  if sqlerrm='AUTHENTICATION_REQUIRED'then raise exception 'AUTHENTICATION_REQUIRED'using errcode='42501';
  elsif sqlerrm='QUESTIONNAIRE_SCOPE_DENIED'then raise exception 'QUESTIONNAIRE_SCOPE_DENIED'using errcode='42501';end if;
  raise exception 'QUESTIONNAIRE_RULE_VALIDATION_FAILED'using errcode='P0001';
end$$;

create or replace function private.simulate_questionnaire_rule_engine_core(
  p_questionnaire_version_id uuid,
  p_answers jsonb,
  p_previous_answers jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
declare
  v_version public.questionnaire_versions%rowtype;
  v_questions text[];
  v_item record;
  v_question public.question_versions%rowtype;
  v_rule record;
  v_action jsonb;
  v_actions jsonb := '[]'::jsonb;
  v_score integer := 0;
  v_result jsonb;
  v_validation jsonb;
  v_canonical_answer jsonb;
  v_normalized_answers jsonb := '{}'::jsonb;
  v_normalized_previous jsonb := '{}'::jsonb;
begin
  if jsonb_typeof(p_answers) is distinct from 'object'
    or jsonb_typeof(p_previous_answers) is distinct from 'object'
    or (select count(*) from jsonb_object_keys(p_answers)) > 500
    or (select count(*) from jsonb_object_keys(p_previous_answers)) > 500
    or octet_length(p_answers::text) > 262144
    or octet_length(p_previous_answers::text) > 262144
  then
    raise exception 'SIMULATION_INPUT_INVALID' using errcode = '22023';
  end if;

  select *
  into v_version
  from public.questionnaire_versions
  where id = p_questionnaire_version_id;

  if not found then
    raise exception 'QUESTIONNAIRE_SCOPE_DENIED' using errcode = '42501';
  end if;

  select coalesce(
    array_agg(question_version_id::text order by question_version_id::text),
    '{}'
  )
  into v_questions
  from public.questionnaire_version_questions
  where questionnaire_version_id = v_version.id;

  for v_item in select * from jsonb_each(p_answers)
  loop
    if not (v_item.key = any(v_questions)) then
      raise exception 'SIMULATION_UNKNOWN_QUESTION' using errcode = '22023';
    end if;
    select question.*
    into v_question
    from public.question_versions question
    where question.id = v_item.key::uuid;
    v_canonical_answer := private.normalize_questionnaire_simulation_answer(
      v_question.answer_type,
      v_item.value
    );
    if not private.is_valid_question_answer(v_question, v_canonical_answer) then
      raise exception 'SIMULATION_ANSWER_INVALID' using errcode = '22023';
    end if;
    v_normalized_answers := v_normalized_answers
      || jsonb_build_object(v_item.key, v_canonical_answer);
  end loop;

  for v_item in select * from jsonb_each(p_previous_answers)
  loop
    if not (v_item.key = any(v_questions)) then
      raise exception 'SIMULATION_UNKNOWN_QUESTION' using errcode = '22023';
    end if;
    select question.*
    into v_question
    from public.question_versions question
    where question.id = v_item.key::uuid;
    v_canonical_answer := private.normalize_questionnaire_simulation_answer(
      v_question.answer_type,
      v_item.value
    );
    if not private.is_valid_question_answer(v_question, v_canonical_answer) then
      raise exception 'SIMULATION_ANSWER_INVALID' using errcode = '22023';
    end if;
    v_normalized_previous := v_normalized_previous
      || jsonb_build_object(v_item.key, v_canonical_answer);
  end loop;

  v_validation := private.validate_questionnaire_rule_engine_core(v_version.id);
  if not (v_validation->>'valid')::boolean then
    raise exception 'QUESTIONNAIRE_RULES_INVALID' using errcode = '23514';
  end if;

  for v_rule in
    select rule_version.*, version_rule.evaluation_order
    from public.questionnaire_version_rules version_rule
    join public.question_rule_versions rule_version
      on rule_version.id = version_rule.rule_version_id
    where version_rule.questionnaire_version_id = v_version.id
    order by version_rule.evaluation_order, rule_version.priority, rule_version.id
  loop
    if private.evaluate_advanced_condition(
      v_rule.condition_ast,
      v_normalized_answers,
      v_normalized_previous
    ) then
      for v_action in select value from jsonb_array_elements(v_rule.actions)
      loop
        if v_action->>'type' = 'SCORE' then
          v_score := greatest(
            0,
            least(10000, v_score + (v_action->>'delta_basis_points')::integer)
          );
        end if;
        v_actions := v_actions || jsonb_build_array(
          v_action || jsonb_build_object(
            'rule_version_id', v_rule.id,
            'evaluation_order', v_rule.evaluation_order
          )
        );
      end loop;
    end if;
  end loop;

  v_result := jsonb_build_object(
    'questionnaire_version_id', v_version.id,
    'engine_version', v_version.engine_version,
    'policy_version', v_version.policy_version,
    'score_basis_points', v_score,
    'triggered_actions', v_actions,
    'simulation', true
  );
  return v_result || jsonb_build_object(
    'reproducibility_hash',
    encode(extensions.digest(convert_to(v_result::text, 'UTF8'), 'sha256'), 'hex')
  );
exception
  when invalid_text_representation
    or datetime_field_overflow
    or numeric_value_out_of_range
    or invalid_regular_expression
  then
    raise exception 'SIMULATION_INPUT_INVALID' using errcode = '22023';
  when others then
    if sqlerrm = 'QUESTIONNAIRE_SCOPE_DENIED' then
      raise exception 'QUESTIONNAIRE_SCOPE_DENIED' using errcode = '42501';
    elsif sqlerrm = 'SIMULATION_INPUT_INVALID' then
      raise exception 'SIMULATION_INPUT_INVALID' using errcode = '22023';
    elsif sqlerrm = 'SIMULATION_UNKNOWN_QUESTION' then
      raise exception 'SIMULATION_UNKNOWN_QUESTION' using errcode = '22023';
    elsif sqlerrm = 'SIMULATION_ANSWER_INVALID' then
      raise exception 'SIMULATION_ANSWER_INVALID' using errcode = '22023';
    elsif sqlerrm = 'QUESTIONNAIRE_RULES_INVALID' then
      raise exception 'QUESTIONNAIRE_RULES_INVALID' using errcode = '23514';
    end if;
    raise exception 'QUESTIONNAIRE_RULE_SIMULATION_FAILED' using errcode = 'P0001';
end
$$;

revoke all on function private.simulate_questionnaire_rule_engine_core(uuid,jsonb,jsonb)
from public, anon, authenticated, service_role;

create or replace function public.simulate_questionnaire_rule_engine(
  p_questionnaire_version_id uuid,
  p_answers jsonb,
  p_previous_answers jsonb default '{}'::jsonb
) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_library_id uuid;
begin
  if auth.uid()is null then raise exception 'AUTHENTICATION_REQUIRED'using errcode='42501';end if;
  select library_id into v_library_id from public.questionnaire_versions where id=p_questionnaire_version_id;
  if not found or not private.can_execute_questionnaire_rule_engine(v_library_id,auth.uid())then raise exception 'QUESTIONNAIRE_SCOPE_DENIED'using errcode='42501';end if;
  return private.simulate_questionnaire_rule_engine_core(p_questionnaire_version_id,p_answers,p_previous_answers);
exception
  when invalid_text_representation or datetime_field_overflow or numeric_value_out_of_range or invalid_regular_expression then raise exception 'SIMULATION_INPUT_INVALID'using errcode='22023';
  when others then
    if sqlerrm='AUTHENTICATION_REQUIRED'then raise exception 'AUTHENTICATION_REQUIRED'using errcode='42501';
    elsif sqlerrm='QUESTIONNAIRE_SCOPE_DENIED'then raise exception 'QUESTIONNAIRE_SCOPE_DENIED'using errcode='42501';
    elsif sqlerrm='SIMULATION_INPUT_INVALID'then raise exception 'SIMULATION_INPUT_INVALID'using errcode='22023';
    elsif sqlerrm='SIMULATION_UNKNOWN_QUESTION'then raise exception 'SIMULATION_UNKNOWN_QUESTION'using errcode='22023';
    elsif sqlerrm='SIMULATION_ANSWER_INVALID'then raise exception 'SIMULATION_ANSWER_INVALID'using errcode='22023';
    elsif sqlerrm='QUESTIONNAIRE_RULES_INVALID'then raise exception 'QUESTIONNAIRE_RULES_INVALID'using errcode='23514';end if;
    raise exception 'QUESTIONNAIRE_RULE_SIMULATION_FAILED'using errcode='P0001';
end$$;

-- This is the original session command with only its engine call redirected to
-- the unexposed core. Its tenant, state, idempotency, audit and Outbox guards
-- remain unchanged.
create or replace function public.submit_questionnaire_session(p_session_id uuid,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid)returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$
declare a uuid:=auth.uid();s public.questionnaire_sessions%rowtype;k private.questionnaire_command_keys%rowtype;h text;manifest jsonb;mh text;r jsonb;cmd uuid;answers jsonb;previous jsonb:='{}';evaluation jsonb;payload jsonb;rh text;snapshot_id uuid;eid uuid;hidden text[]:='{}';required_rule text[]:='{}';optional_rule text[]:='{}';act jsonb;missing integer;contradiction boolean;from_state text;engine text;policy text;begin
  if a is null then raise exception 'AUTHENTICATION_REQUIRED'using errcode='42501';end if;if p_correlation_id is null or p_expected_row_version is null or p_expected_row_version<1 or length(p_idempotency_key)not between 8 and 200 then raise exception 'INVALID_SUBMIT_REQUEST'using errcode='22023';end if;
  perform pg_advisory_xact_lock(hashtextextended(a::text||':questionnaire.session.submit:'||p_idempotency_key,0));select*into s from public.questionnaire_sessions where id=p_session_id for update;
  if not found or s.actor_user_id<>a or not private.has_questionnaire_audience_access(s.organization_id,s.library_id,s.audience,'SUBMIT',a)then raise exception 'SESSION_SCOPE_DENIED'using errcode='42501';end if;
  h:=encode(extensions.digest(convert_to(jsonb_build_object('session_id',p_session_id,'expected_row_version',p_expected_row_version)::text,'UTF8'),'sha256'),'hex');select*into k from private.questionnaire_command_keys where actor_user_id=a and operation_scope='questionnaire.session.submit'and key=p_idempotency_key for update;
  if found then if k.request_hash<>h then raise exception 'IDEMPOTENCY_KEY_REUSED'using errcode='23505';end if;return k.response_body;end if;
  if s.status not in('IN_PROGRESS','READY')then raise exception 'SESSION_NOT_SUBMITTABLE'using errcode='55000';end if;if s.row_version<>p_expected_row_version then raise exception 'STALE_SESSION_VERSION'using errcode='40001';end if;if s.due_at is not null and s.due_at<=statement_timestamp()then raise exception 'SESSION_EXPIRED'using errcode='55000';end if;
  select id,engine_version,policy_version into snapshot_id,engine,policy from public.questionnaire_session_snapshots where session_id=s.id;if snapshot_id is null then raise exception 'SESSION_SNAPSHOT_MISSING'using errcode='23514';end if;
  answers:=private.questionnaire_session_answers_object(s.id);if s.revision_of_session_id is not null then previous:=private.questionnaire_session_answers_object(s.revision_of_session_id);end if;
  if engine='1'or engine like'1.%'then evaluation:=jsonb_build_object('questionnaire_version_id',s.questionnaire_version_id,'engine_version',engine,'policy_version',policy,'score_basis_points',0,'triggered_actions','[]'::jsonb,'simulation',false,'legacy_compatibility',true);else evaluation:=private.simulate_questionnaire_rule_engine_core(s.questionnaire_version_id,answers,previous);end if;
  for act in select value from jsonb_array_elements(evaluation->'triggered_actions')loop
    if act->>'type'='HIDE'then hidden:=array_append(hidden,act->>'target');elsif act->>'type'='REQUIRED'then required_rule:=array_append(required_rule,act->>'target');elsif act->>'type'='OPTIONAL'then optional_rule:=array_append(optional_rule,act->>'target');end if;
  end loop;
  select exists(select 1 from unnest(required_rule)x where x=any(hidden))into contradiction;if contradiction then raise exception 'CONTRADICTORY_REQUIRED_VISIBILITY'using errcode='23514';end if;
  select count(*)into missing from public.questionnaire_version_questions x join public.question_versions q on q.id=x.question_version_id left join public.questionnaire_answers z on z.session_id=s.id and z.question_version_id=q.id left join public.questionnaire_answer_revisions ar on ar.id=z.current_revision_id where x.questionnaire_version_id=s.questionnaire_version_id and not(q.id::text=any(hidden))and((coalesce(x.required_override,q.required_by_default)and not(q.id::text=any(optional_rule)))or q.id::text=any(required_rule))and(z.current_revision_id is null or ar.value='null'::jsonb or(ar.expires_at is not null and ar.expires_at<=statement_timestamp()));
  if missing>0 then raise exception 'REQUIRED_ANSWERS_MISSING'using errcode='23514';end if;
  select coalesce(jsonb_agg(jsonb_build_object('question_version_id',z.question_version_id,'answer_revision_id',z.current_revision_id,'answer_hash',ar.answer_hash)order by z.question_version_id::text),'[]')into manifest from public.questionnaire_answers z join public.questionnaire_answer_revisions ar on ar.id=z.current_revision_id where z.session_id=s.id;
  mh:=encode(extensions.digest(convert_to(manifest::text,'UTF8'),'sha256'),'hex');payload:=(evaluation-'simulation'-'reproducibility_hash')||jsonb_build_object('mode','FINAL','session_snapshot_id',snapshot_id,'answer_manifest_hash',mh);rh:=encode(extensions.digest(convert_to(jsonb_build_object('snapshot_hash',(select snapshot_hash from public.questionnaire_session_snapshots where id=snapshot_id),'result',payload)::text,'UTF8'),'sha256'),'hex');
  insert into private.questionnaire_command_keys values(a,'questionnaire.session.submit',p_idempotency_key,h,null,clock_timestamp(),null,default)returning command_id into cmd;from_state:=s.status;
  insert into public.questionnaire_session_evaluations(session_id,organization_id,session_snapshot_id,questionnaire_version_id,engine_version,policy_version,score_basis_points,triggered_actions,answer_manifest_hash,result_payload,reproducibility_hash,evaluated_by)values(s.id,s.organization_id,snapshot_id,s.questionnaire_version_id,evaluation->>'engine_version',evaluation->>'policy_version',(evaluation->>'score_basis_points')::integer,evaluation->'triggered_actions',mh,payload,rh,a)returning id into eid;
  update public.questionnaire_sessions set status='SUBMITTED',submitted_at=clock_timestamp(),updated_at=clock_timestamp(),answer_manifest=manifest,answer_manifest_hash=mh,row_version=row_version+1 where id=s.id returning*into s;
  insert into public.questionnaire_session_state_events(session_id,organization_id,from_status,to_status,reason_code,actor_user_id,correlation_id,idempotency_key)values(s.id,s.organization_id,from_state,'SUBMITTED','VALIDATION_COMPLETED',a,p_correlation_id,p_idempotency_key);
  r:=jsonb_build_object('outcome','QUESTIONNAIRE_SESSION_SUBMITTED','session_id',s.id,'row_version',s.row_version,'answer_manifest_hash',mh,'evaluation_id',eid,'score_basis_points',(evaluation->>'score_basis_points')::integer,'reproducibility_hash',rh);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(s.organization_id,a,'USER','questionnaire.session.submitted','questionnaire_session',s.id::text,p_correlation_id,jsonb_build_object('questionnaire_version_id',s.questionnaire_version_id,'session_snapshot_id',snapshot_id,'answer_manifest_hash',mh,'evaluation_id',eid,'reproducibility_hash',rh),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(s.organization_id,'questionnaire_session',s.id::text,'QuestionnaireSessionSubmittedV1',p_correlation_id,r,p_idempotency_key,cmd);
  update private.questionnaire_command_keys set response_body=r,completed_at=clock_timestamp()where actor_user_id=a and operation_scope='questionnaire.session.submit'and key=p_idempotency_key;return r;
end$$;

revoke all on function public.validate_questionnaire_rule_engine(uuid)
from public, anon, authenticated, service_role;
revoke all on function public.simulate_questionnaire_rule_engine(uuid,jsonb,jsonb)
from public, anon, authenticated, service_role;

grant execute on function public.validate_questionnaire_rule_engine(uuid)
to authenticated;
grant execute on function public.simulate_questionnaire_rule_engine(uuid,jsonb,jsonb)
to authenticated;
revoke all on function public.submit_questionnaire_session(uuid,integer,text,uuid)
from public, anon, authenticated, service_role;
grant execute on function public.submit_questionnaire_session(uuid,integer,text,uuid)
to authenticated;

notify pgrst, 'reload schema';
