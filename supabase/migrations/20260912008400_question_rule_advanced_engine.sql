-- P06 advanced deterministic rule validation and side-effect-free simulation.

create function private.assert_advanced_condition_node(p_node jsonb,p_question_ids text[],p_depth integer default 0) returns void
language plpgsql immutable security definer set search_path=pg_catalog as $$
declare v_child jsonb;v_operator text;v_ref text;v_value jsonb;
begin
  if p_depth>16 or jsonb_typeof(p_node) is distinct from 'object' then raise exception 'RULE_AST_MALFORMED' using errcode='22023';end if;
  if p_node?'group' then
    if (p_node-array['group','conditions'])<>'{}'::jsonb or p_node->>'group' not in('AND','OR','NOT') or jsonb_typeof(p_node->'conditions') is distinct from 'array' or jsonb_array_length(p_node->'conditions') not between 1 and 32 or(p_node->>'group'='NOT'and jsonb_array_length(p_node->'conditions')<>1)then raise exception 'RULE_GROUP_MALFORMED' using errcode='22023';end if;
    for v_child in select value from jsonb_array_elements(p_node->'conditions')loop perform private.assert_advanced_condition_node(v_child,p_question_ids,p_depth+1);end loop;
    if p_node->>'group'='AND'and exists(select 1 from jsonb_array_elements(p_node->'conditions')with ordinality a(value,n)join jsonb_array_elements(p_node->'conditions')with ordinality b(value,n)on a.n<b.n where a.value->>'question_version_id'=b.value->>'question_version_id'and((a.value->>'operator'='EQ'and b.value->>'operator'='EQ'and a.value->'value'is distinct from b.value->'value')or(a.value->>'operator'='EQ'and b.value->>'operator'='NEQ'and a.value->'value'=b.value->'value')or(a.value->>'operator'='NEQ'and b.value->>'operator'='EQ'and a.value->'value'=b.value->'value')))then raise exception 'RULE_DEAD_BRANCH'using errcode='23514';end if;
    return;
  end if;
  if (p_node-array['operator','question_version_id','value'])<>'{}'::jsonb or not(p_node?&array['operator','question_version_id'])then raise exception 'RULE_PREDICATE_MALFORMED' using errcode='22023';end if;
  v_operator:=p_node->>'operator';v_ref:=p_node->>'question_version_id';v_value:=p_node->'value';
  if v_operator not in('EQ','NEQ','GT','GTE','LT','LTE','IN','CONTAINS','EMPTY','NOT_EMPTY','REGEX','DATE_BEFORE','DATE_AFTER','CHANGED')or v_ref is null or not(v_ref=any(p_question_ids))then raise exception 'RULE_REFERENCE_OR_OPERATOR_INVALID' using errcode='22023';end if;
  if v_operator in('EMPTY','NOT_EMPTY','CHANGED')and p_node?'value' then raise exception 'RULE_OPERAND_INVALID' using errcode='22023';end if;
  if v_operator not in('EMPTY','NOT_EMPTY','CHANGED')and not(p_node?'value')then raise exception 'RULE_OPERAND_INVALID' using errcode='22023';end if;
  if v_operator='IN'and jsonb_typeof(v_value)is distinct from 'array'then raise exception 'RULE_OPERAND_INVALID' using errcode='22023';end if;
  if v_operator='REGEX'and(jsonb_typeof(v_value)is distinct from 'string'or length(v_value#>>'{}')not between 1 and 128 or(v_value#>>'{}')~'\(\?|\\[1-9]')then raise exception 'RULE_REGEX_UNSAFE' using errcode='22023';end if;
  if v_operator in('DATE_BEFORE','DATE_AFTER')and(jsonb_typeof(v_value)is distinct from 'string'or(v_value#>>'{}')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$')then raise exception 'RULE_OPERAND_INVALID' using errcode='22023';end if;
end$$;

create function private.assert_advanced_rule_contract(p_ast jsonb,p_actions jsonb,p_graph jsonb,p_question_ids text[]) returns void
language plpgsql immutable security definer set search_path=pg_catalog as $$
declare v_entry record;v_dep jsonb;v_action jsonb;v_type text;
begin
  perform private.assert_advanced_condition_node(p_ast,p_question_ids,0);
  if jsonb_typeof(p_graph)is distinct from 'object'or(select count(*)from jsonb_object_keys(p_graph))>256 then raise exception 'RULE_DEPENDENCY_GRAPH_MALFORMED' using errcode='22023';end if;
  for v_entry in select * from jsonb_each(p_graph)loop
    if not(v_entry.key=any(p_question_ids))or jsonb_typeof(v_entry.value)is distinct from 'array'then raise exception 'RULE_DEPENDENCY_REFERENCE_INVALID' using errcode='22023';end if;
    for v_dep in select value from jsonb_array_elements(v_entry.value)loop if jsonb_typeof(v_dep)is distinct from 'string'or not((v_dep#>>'{}')=any(p_question_ids))then raise exception 'RULE_DEPENDENCY_REFERENCE_INVALID' using errcode='22023';end if;end loop;
  end loop;
  if exists(with recursive edges(src,dst)as(select e.key,d.value#>>'{}'from jsonb_each(p_graph)e cross join lateral jsonb_array_elements(e.value)d),walk(node,path,cycle)as(select dst,array[src,dst],src=dst from edges union all select e.dst,w.path||e.dst,e.dst=any(w.path)from walk w join edges e on e.src=w.node where not w.cycle and cardinality(w.path)<=257)select 1 from walk where cycle)then raise exception 'RULE_DEPENDENCY_CYCLE' using errcode='23514';end if;
  if jsonb_typeof(p_actions)is distinct from 'array'or jsonb_array_length(p_actions)not between 1 and 64 then raise exception 'RULE_ACTIONS_MALFORMED' using errcode='22023';end if;
  for v_action in select value from jsonb_array_elements(p_actions)loop
    if jsonb_typeof(v_action)is distinct from 'object'or not(v_action?'type')or(v_action-array['type','target','metadata','value','dimension','delta_basis_points','duration_days'])<>'{}'::jsonb then raise exception 'RULE_ACTION_MALFORMED' using errcode='22023';end if;
    v_type:=v_action->>'type';
    if v_type not in('SHOW','HIDE','REQUIRED','OPTIONAL','SCORE','ANOMALY','RISK','RECOMMENDATION','OPPORTUNITY','SOLUTION_LEVEL','REQUIRE_DOCUMENT','HUMAN_REVIEW','BLOCK_PUBLICATION','BLOCK_RFQ','SUGGEST_SERVICE','START_CHILD_DIAGNOSTIC','SET_VALIDITY_DAYS')then raise exception 'RULE_ACTION_TYPE_INVALID' using errcode='22023';end if;
    if v_type in('SHOW','HIDE','REQUIRED','OPTIONAL','ANOMALY','RISK','RECOMMENDATION','OPPORTUNITY','SOLUTION_LEVEL','REQUIRE_DOCUMENT','SUGGEST_SERVICE','START_CHILD_DIAGNOSTIC')and(jsonb_typeof(v_action->'target')is distinct from'string'or length(btrim(v_action->>'target'))not between 1 and 160)then raise exception 'RULE_ACTION_TARGET_INVALID'using errcode='22023';end if;
    if v_type='SCORE'and(not(v_action?&array['dimension','delta_basis_points'])or(v_action->>'dimension')!~'^[A-Z][A-Z0-9_.-]{1,79}$'or jsonb_typeof(v_action->'delta_basis_points')is distinct from 'number'or(v_action->>'delta_basis_points')!~'^-?(0|[1-9][0-9]{0,4})$'or(v_action->>'delta_basis_points')::integer not between -10000 and 10000)then raise exception 'RULE_SCORE_ACTION_INVALID' using errcode='22023';end if;
    if v_type='SET_VALIDITY_DAYS'and(jsonb_typeof(v_action->'duration_days')is distinct from 'number'or(v_action->>'duration_days')!~'^[1-9][0-9]{0,3}$'or(v_action->>'duration_days')::integer>3650)then raise exception 'RULE_VALIDITY_ACTION_INVALID' using errcode='22023';end if;
  end loop;
end$$;

create function private.evaluate_advanced_condition(p_node jsonb,p_answers jsonb,p_previous_answers jsonb) returns boolean
language plpgsql immutable security definer set search_path=pg_catalog as $$
declare v_child jsonb;v_group text;v_operator text;v_ref text;v_actual jsonb;v_expected jsonb;v_result boolean;
begin
  if p_node?'group'then
    v_group:=p_node->>'group';v_result:=case when v_group='AND'then true else false end;
    for v_child in select value from jsonb_array_elements(p_node->'conditions')loop
      if v_group='AND'then v_result:=v_result and private.evaluate_advanced_condition(v_child,p_answers,p_previous_answers);exit when not v_result;
      elsif v_group='OR'then v_result:=v_result or private.evaluate_advanced_condition(v_child,p_answers,p_previous_answers);exit when v_result;
      else return not private.evaluate_advanced_condition(v_child,p_answers,p_previous_answers);end if;
    end loop;return v_result;
  end if;
  v_operator:=p_node->>'operator';v_ref:=p_node->>'question_version_id';v_actual:=p_answers->v_ref;v_expected:=p_node->'value';
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
    when'CHANGED'then return p_answers?v_ref and p_previous_answers?v_ref and v_actual is distinct from p_previous_answers->v_ref;
    else return false;
  end case;
end$$;

create function public.validate_questionnaire_rule_engine(p_questionnaire_version_id uuid) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_version public.questionnaire_versions%rowtype;v_rule record;v_questions text[];v_errors jsonb:='[]'::jsonb;v_count integer:=0;
begin
  if auth.uid()is null then raise exception 'AUTHENTICATION_REQUIRED'using errcode='42501';end if;
  select*into v_version from public.questionnaire_versions where id=p_questionnaire_version_id;
  if not found or not private.can_read_questionnaire_version(v_version.id)then raise exception 'QUESTIONNAIRE_SCOPE_DENIED'using errcode='42501';end if;
  select coalesce(array_agg(question_version_id::text order by question_version_id::text),'{}')into v_questions from public.questionnaire_version_questions where questionnaire_version_id=v_version.id;
  for v_rule in select r.*from public.questionnaire_version_rules x join public.question_rule_versions r on r.id=x.rule_version_id where x.questionnaire_version_id=v_version.id order by x.evaluation_order,r.id loop
    v_count:=v_count+1;begin perform private.assert_advanced_rule_contract(v_rule.condition_ast,v_rule.actions,v_rule.dependency_graph,v_questions);exception when others then v_errors:=v_errors||jsonb_build_array(jsonb_build_object('rule_version_id',v_rule.id,'code',sqlerrm));end;
  end loop;
  return jsonb_build_object('valid',jsonb_array_length(v_errors)=0,'questionnaire_version_id',v_version.id,'engine_version',v_version.engine_version,'policy_version',v_version.policy_version,'question_count',cardinality(v_questions),'rule_count',v_count,'errors',v_errors);
end$$;

create function public.simulate_questionnaire_rule_engine(p_questionnaire_version_id uuid,p_answers jsonb,p_previous_answers jsonb default'{}'::jsonb) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_version public.questionnaire_versions%rowtype;v_questions text[];v_item record;v_question public.question_versions%rowtype;v_rule record;v_action jsonb;v_actions jsonb:='[]'::jsonb;v_score integer:=0;v_result jsonb;v_validation jsonb;
begin
  if auth.uid()is null then raise exception 'AUTHENTICATION_REQUIRED'using errcode='42501';end if;
  if jsonb_typeof(p_answers)is distinct from'object'or jsonb_typeof(p_previous_answers)is distinct from'object'or(select count(*)from jsonb_object_keys(p_answers))>500 or octet_length(p_answers::text)>262144 then raise exception 'SIMULATION_INPUT_INVALID'using errcode='22023';end if;
  select*into v_version from public.questionnaire_versions where id=p_questionnaire_version_id;
  if not found or not private.can_read_questionnaire_version(v_version.id)then raise exception 'QUESTIONNAIRE_SCOPE_DENIED'using errcode='42501';end if;
  select coalesce(array_agg(question_version_id::text order by question_version_id::text),'{}')into v_questions from public.questionnaire_version_questions where questionnaire_version_id=v_version.id;
  for v_item in select*from jsonb_each(p_answers)loop
    if not(v_item.key=any(v_questions))then raise exception 'SIMULATION_UNKNOWN_QUESTION'using errcode='22023';end if;
    select q.*into v_question from public.question_versions q where q.id=v_item.key::uuid;if not private.is_valid_question_answer(v_question,v_item.value)then raise exception 'SIMULATION_ANSWER_INVALID'using errcode='22023';end if;
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

revoke all on function private.assert_advanced_condition_node(jsonb,text[],integer),private.assert_advanced_rule_contract(jsonb,jsonb,jsonb,text[]),private.evaluate_advanced_condition(jsonb,jsonb,jsonb),public.validate_questionnaire_rule_engine(uuid),public.simulate_questionnaire_rule_engine(uuid,jsonb,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.validate_questionnaire_rule_engine(uuid),public.simulate_questionnaire_rule_engine(uuid,jsonb,jsonb)to authenticated;
notify pgrst,'reload schema';
