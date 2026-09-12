-- P06 simulation input compatibility: accept exact JSON numeric shorthand without
-- weakening the canonical persisted answer contract.

create function private.normalize_questionnaire_simulation_answer(p_answer_type text,p_value jsonb) returns jsonb
language plpgsql immutable security definer set search_path=pg_catalog as $$
declare v_text text;
begin
  if jsonb_typeof(p_value)<>'number'then return p_value;end if;
  v_text:=p_value#>>'{}';
  if p_answer_type in('INTEGER','RATING_5','RATING_10')and v_text~'^-?(0|[1-9][0-9]*)$'then
    return jsonb_build_object('kind','INTEGER','value',v_text);
  end if;
  if p_answer_type in('DECIMAL','PERCENTAGE','QUANTITY','UNIT_VALUE')and v_text~'^-?(0|[1-9][0-9]*)(\.[0-9]+)?$'then
    return jsonb_build_object('kind','DECIMAL','value',v_text);
  end if;
  return p_value;
end$$;

create or replace function public.simulate_questionnaire_rule_engine(p_questionnaire_version_id uuid,p_answers jsonb,p_previous_answers jsonb default'{}'::jsonb) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_version public.questionnaire_versions%rowtype;v_questions text[];v_item record;v_question public.question_versions%rowtype;v_rule record;v_action jsonb;v_actions jsonb:='[]'::jsonb;v_score integer:=0;v_result jsonb;v_validation jsonb;v_canonical_answer jsonb;
begin
  if auth.uid()is null then raise exception 'AUTHENTICATION_REQUIRED'using errcode='42501';end if;
  if jsonb_typeof(p_answers)is distinct from'object'or jsonb_typeof(p_previous_answers)is distinct from'object'or(select count(*)from jsonb_object_keys(p_answers))>500 or octet_length(p_answers::text)>262144 then raise exception 'SIMULATION_INPUT_INVALID'using errcode='22023';end if;
  select*into v_version from public.questionnaire_versions where id=p_questionnaire_version_id;
  if not found or not private.can_read_questionnaire_version(v_version.id)then raise exception 'QUESTIONNAIRE_SCOPE_DENIED'using errcode='42501';end if;
  select coalesce(array_agg(question_version_id::text order by question_version_id::text),'{}')into v_questions from public.questionnaire_version_questions where questionnaire_version_id=v_version.id;
  for v_item in select*from jsonb_each(p_answers)loop
    if not(v_item.key=any(v_questions))then raise exception 'SIMULATION_UNKNOWN_QUESTION'using errcode='22023';end if;
    select q.*into v_question from public.question_versions q where q.id=v_item.key::uuid;
    v_canonical_answer:=private.normalize_questionnaire_simulation_answer(v_question.answer_type,v_item.value);
    if not private.is_valid_question_answer(v_question,v_canonical_answer)then raise exception 'SIMULATION_ANSWER_INVALID'using errcode='22023';end if;
  end loop;
  v_validation:=public.validate_questionnaire_rule_engine(v_version.id);if not(v_validation->>'valid')::boolean then raise exception 'QUESTIONNAIRE_RULES_INVALID'using errcode='23514';end if;
  for v_rule in select r.*,x.evaluation_order from public.questionnaire_version_rules x join public.question_rule_versions r on r.id=x.rule_version_id where x.questionnaire_version_id=v_version.id order by x.evaluation_order,r.priority,r.id loop
    if private.evaluate_advanced_condition(v_rule.condition_ast,p_answers,p_previous_answers)then
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

revoke all on function private.normalize_questionnaire_simulation_answer(text,jsonb),public.simulate_questionnaire_rule_engine(uuid,jsonb,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.simulate_questionnaire_rule_engine(uuid,jsonb,jsonb)to authenticated;
notify pgrst,'reload schema';
