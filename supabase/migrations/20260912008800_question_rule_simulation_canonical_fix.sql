-- P06 canonical simulation fix: one normalized answer map drives validation and evaluation.

create function private.question_rule_comparable_value(p_value jsonb) returns jsonb
language plpgsql immutable security definer set search_path=pg_catalog as $$
begin
  if jsonb_typeof(p_value)='object'and p_value->>'kind'in('INTEGER','DECIMAL')and p_value->>'value'~'^-?(0|[1-9][0-9]*)(\.[0-9]+)?$'and(select count(*)from jsonb_object_keys(p_value))=2 then
    return to_jsonb((p_value->>'value')::numeric);
  end if;
  return p_value;
exception when numeric_value_out_of_range then return p_value;
end$$;

create or replace function private.evaluate_advanced_condition(p_node jsonb,p_answers jsonb,p_previous_answers jsonb) returns boolean
language plpgsql immutable security definer set search_path=pg_catalog as $$
declare v_child jsonb;v_group text;v_operator text;v_ref text;v_actual jsonb;v_previous jsonb;v_expected jsonb;v_result boolean;
begin
  if p_node?'group'then
    v_group:=p_node->>'group';v_result:=case when v_group='AND'then true else false end;
    for v_child in select value from jsonb_array_elements(p_node->'conditions')loop
      if v_group='AND'then v_result:=v_result and private.evaluate_advanced_condition(v_child,p_answers,p_previous_answers);exit when not v_result;
      elsif v_group='OR'then v_result:=v_result or private.evaluate_advanced_condition(v_child,p_answers,p_previous_answers);exit when v_result;
      else return not private.evaluate_advanced_condition(v_child,p_answers,p_previous_answers);end if;
    end loop;return v_result;
  end if;
  v_operator:=p_node->>'operator';v_ref:=p_node->>'question_version_id';
  v_actual:=private.question_rule_comparable_value(p_answers->v_ref);
  v_previous:=private.question_rule_comparable_value(p_previous_answers->v_ref);
  v_expected:=private.question_rule_comparable_value(p_node->'value');
  case v_operator
    when'EQ'then return v_actual=v_expected;
    when'NEQ'then return v_actual is distinct from v_expected;
    when'GT'then return jsonb_typeof(v_actual)='number'and jsonb_typeof(v_expected)='number'and(v_actual#>>'{}')::numeric>(v_expected#>>'{}')::numeric;
    when'GTE'then return jsonb_typeof(v_actual)='number'and jsonb_typeof(v_expected)='number'and(v_actual#>>'{}')::numeric>=(v_expected#>>'{}')::numeric;
    when'LT'then return jsonb_typeof(v_actual)='number'and jsonb_typeof(v_expected)='number'and(v_actual#>>'{}')::numeric<(v_expected#>>'{}')::numeric;
    when'LTE'then return jsonb_typeof(v_actual)='number'and jsonb_typeof(v_expected)='number'and(v_actual#>>'{}')::numeric<=(v_expected#>>'{}')::numeric;
    when'IN'then return v_expected@>jsonb_build_array(v_actual);
    when'CONTAINS'then return case when jsonb_typeof(v_actual)='array'then v_actual@>jsonb_build_array(v_expected)when jsonb_typeof(v_actual)='string'and jsonb_typeof(v_expected)='string'then position(v_expected#>>'{}'in v_actual#>>'{}')>0 else false end;
    when'EMPTY'then return v_actual is null or v_actual='null'::jsonb or v_actual='""'::jsonb or v_actual='[]'::jsonb or v_actual='{}'::jsonb;
    when'NOT_EMPTY'then return not(v_actual is null or v_actual='null'::jsonb or v_actual='""'::jsonb or v_actual='[]'::jsonb or v_actual='{}'::jsonb);
    when'REGEX'then return jsonb_typeof(v_actual)='string'and(v_actual#>>'{}')~(v_expected#>>'{}');
    when'DATE_BEFORE'then return jsonb_typeof(v_actual)='string'and(v_actual#>>'{}')~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'and(v_actual#>>'{}')::date<(v_expected#>>'{}')::date;
    when'DATE_AFTER'then return jsonb_typeof(v_actual)='string'and(v_actual#>>'{}')~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'and(v_actual#>>'{}')::date>(v_expected#>>'{}')::date;
    when'CHANGED'then return p_answers?v_ref and p_previous_answers?v_ref and v_actual is distinct from v_previous;
    else return false;
  end case;
end$$;

create or replace function public.simulate_questionnaire_rule_engine(p_questionnaire_version_id uuid,p_answers jsonb,p_previous_answers jsonb default'{}'::jsonb) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_version public.questionnaire_versions%rowtype;v_questions text[];v_item record;v_question public.question_versions%rowtype;v_rule record;v_action jsonb;v_actions jsonb:='[]'::jsonb;v_score integer:=0;v_result jsonb;v_validation jsonb;v_canonical_answer jsonb;v_normalized_answers jsonb:='{}'::jsonb;v_normalized_previous jsonb:='{}'::jsonb;
begin
  if auth.uid()is null then raise exception 'AUTHENTICATION_REQUIRED'using errcode='42501';end if;
  if jsonb_typeof(p_answers)is distinct from'object'or jsonb_typeof(p_previous_answers)is distinct from'object'or(select count(*)from jsonb_object_keys(p_answers))>500 or(select count(*)from jsonb_object_keys(p_previous_answers))>500 or octet_length(p_answers::text)>262144 or octet_length(p_previous_answers::text)>262144 then raise exception 'SIMULATION_INPUT_INVALID'using errcode='22023';end if;
  select*into v_version from public.questionnaire_versions where id=p_questionnaire_version_id;
  if not found or not private.can_read_questionnaire_version(v_version.id)then raise exception 'QUESTIONNAIRE_SCOPE_DENIED'using errcode='42501';end if;
  select coalesce(array_agg(question_version_id::text order by question_version_id::text),'{}')into v_questions from public.questionnaire_version_questions where questionnaire_version_id=v_version.id;
  for v_item in select*from jsonb_each(p_answers)loop
    if not(v_item.key=any(v_questions))then raise exception 'SIMULATION_UNKNOWN_QUESTION'using errcode='22023';end if;
    select q.*into v_question from public.question_versions q where q.id=v_item.key::uuid;
    v_canonical_answer:=private.normalize_questionnaire_simulation_answer(v_question.answer_type,v_item.value);
    if not private.is_valid_question_answer(v_question,v_canonical_answer)then raise exception 'SIMULATION_ANSWER_INVALID'using errcode='22023';end if;
    v_normalized_answers:=v_normalized_answers||jsonb_build_object(v_item.key,v_canonical_answer);
  end loop;
  for v_item in select*from jsonb_each(p_previous_answers)loop
    if not(v_item.key=any(v_questions))then raise exception 'SIMULATION_UNKNOWN_QUESTION'using errcode='22023';end if;
    select q.*into v_question from public.question_versions q where q.id=v_item.key::uuid;
    v_canonical_answer:=private.normalize_questionnaire_simulation_answer(v_question.answer_type,v_item.value);
    if not private.is_valid_question_answer(v_question,v_canonical_answer)then raise exception 'SIMULATION_ANSWER_INVALID'using errcode='22023';end if;
    v_normalized_previous:=v_normalized_previous||jsonb_build_object(v_item.key,v_canonical_answer);
  end loop;
  v_validation:=public.validate_questionnaire_rule_engine(v_version.id);if not(v_validation->>'valid')::boolean then raise exception 'QUESTIONNAIRE_RULES_INVALID'using errcode='23514';end if;
  for v_rule in select r.*,x.evaluation_order from public.questionnaire_version_rules x join public.question_rule_versions r on r.id=x.rule_version_id where x.questionnaire_version_id=v_version.id order by x.evaluation_order,r.priority,r.id loop
    if private.evaluate_advanced_condition(v_rule.condition_ast,v_normalized_answers,v_normalized_previous)then
      for v_action in select value from jsonb_array_elements(v_rule.actions)loop
        if v_action->>'type'='SCORE'then v_score:=greatest(0,least(10000,v_score+(v_action->>'delta_basis_points')::integer));end if;
        v_actions:=v_actions||jsonb_build_array(v_action||jsonb_build_object('rule_version_id',v_rule.id,'evaluation_order',v_rule.evaluation_order));
      end loop;
    end if;
  end loop;
  v_result:=jsonb_build_object('questionnaire_version_id',v_version.id,'engine_version',v_version.engine_version,'policy_version',v_version.policy_version,'score_basis_points',v_score,'triggered_actions',v_actions,'simulation',true);
  return v_result||jsonb_build_object('reproducibility_hash',encode(extensions.digest(convert_to(v_result::text,'UTF8'),'sha256'),'hex'));
exception when invalid_text_representation or datetime_field_overflow then raise exception 'SIMULATION_INPUT_INVALID'using errcode='22023';
end$$;

revoke all on function private.question_rule_comparable_value(jsonb),private.evaluate_advanced_condition(jsonb,jsonb,jsonb),public.simulate_questionnaire_rule_engine(uuid,jsonb,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.simulate_questionnaire_rule_engine(uuid,jsonb,jsonb)to authenticated;
notify pgrst,'reload schema';
