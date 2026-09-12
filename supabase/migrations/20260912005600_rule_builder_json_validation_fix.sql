-- Replace unsupported JSON object-length calls while preserving the 055 public contract.

create or replace function private.assert_rule_builder_payload(p_payload jsonb) returns void
language plpgsql immutable security definer set search_path=pg_catalog as $$
begin
  if jsonb_typeof(p_payload) is distinct from 'object'
    or not (p_payload ?& array['condition_ast','actions','dependency_graph','priority','sensitive'])
    or exists(select 1 from jsonb_object_keys(p_payload) k where k not in('condition_ast','actions','dependency_graph','priority','sensitive'))
    or octet_length(p_payload::text)>262144
    or jsonb_typeof(p_payload->'condition_ast') is distinct from 'object'
    or (select count(*) from jsonb_object_keys(p_payload->'condition_ast'))=0
    or jsonb_typeof(p_payload->'actions') is distinct from 'array'
    or jsonb_array_length(p_payload->'actions') not between 1 and 64
    or exists(select 1 from jsonb_array_elements(p_payload->'actions') a where jsonb_typeof(a) is distinct from 'object' or (select count(*) from jsonb_object_keys(a))=0)
    or jsonb_typeof(p_payload->'dependency_graph') is distinct from 'object'
    or (select count(*) from jsonb_object_keys(p_payload->'dependency_graph'))>256
    or jsonb_typeof(p_payload->'priority') is distinct from 'number'
    or (p_payload->>'priority')!~'^(0|[1-9][0-9]{0,5})$'
    or (p_payload->>'priority')::integer>100000
    or jsonb_typeof(p_payload->'sensitive') is distinct from 'boolean'
  then raise exception 'INVALID_CATALOG_RULE' using errcode='22023'; end if;
end $$;

revoke all on function private.assert_rule_builder_payload(jsonb) from public,anon,authenticated,service_role;
