-- Align baseline validation with canonical library-scoped Diagnostic/Provider
-- questions and explicit YES/NO/UNKNOWN answer options.

create or replace function private.catalog_import_payload_error(p_entity_type text,p_business_key text,p_payload jsonb) returns text
language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_answer_type text;v_phase text;v_category text;v_service text;
begin
 if jsonb_typeof(p_payload) is distinct from 'object' then return 'PAYLOAD_NOT_OBJECT';end if;
 if p_entity_type='LIBRARY' then
  if p_business_key!~'^[A-Z][A-Z0-9_-]{1,31}$' or p_payload->>'code' is distinct from p_business_key then return 'LIBRARY_CODE_INVALID';end if;
 elsif p_entity_type in('CATEGORY','SUBCATEGORY','SERVICE') then
  if p_business_key!~'^[A-Z][A-Z0-9_-]{1,79}$' or p_payload->>'code' is distinct from p_business_key then return 'ENTITY_CODE_INVALID';end if;
 end if;
 if p_entity_type in('LIBRARY','CATEGORY','SUBCATEGORY','SERVICE') then
  if length(btrim(coalesce(p_payload->>'name_fr',''))) not between 2 and (case when p_entity_type='SERVICE' then 240 else 200 end) then return 'NAME_FR_INVALID';end if;
  if length(btrim(coalesce(p_payload->>'description_fr',''))) not between 3 and (case when p_entity_type='SERVICE' then 8000 else 2000 end) then return 'DESCRIPTION_FR_INVALID';end if;
  if coalesce(p_payload->>'order','')!~'^[1-9][0-9]{0,8}$' then return 'SORT_ORDER_INVALID';end if;
  if p_payload->>'status' is distinct from 'ACTIVE' or p_payload->>'version' is distinct from '1' then return 'SOURCE_LIFECYCLE_INVALID';end if;
 end if;
 if p_entity_type<>'LIBRARY' and p_payload->>'library_code' is null then return 'LIBRARY_CODE_REQUIRED';end if;
 if p_entity_type='CATEGORY' then
  if jsonb_typeof(p_payload->'franchisee_can_edit') is distinct from 'boolean' or jsonb_typeof(p_payload->'subcategories_json') is distinct from 'array' then return 'CATEGORY_SCHEMA_INVALID';end if;
 elsif p_entity_type='SUBCATEGORY' then
  if coalesce(p_payload->>'macro_category_code','')!~'^[A-Z][A-Z0-9_-]{1,79}$' or jsonb_typeof(p_payload->'franchisee_can_edit') is distinct from 'boolean' then return 'SUBCATEGORY_SCHEMA_INVALID';end if;
 elsif p_entity_type='SERVICE' then
  if coalesce(p_payload->>'subcategory_code','')!~'^[A-Z][A-Z0-9_-]{1,79}$' or p_payload->>'category_code' is distinct from p_payload->>'subcategory_code' or coalesce(p_payload->>'macro_category_code','')!~'^[A-Z][A-Z0-9_-]{1,79}$' then return 'SERVICE_PARENT_INVALID';end if;
  if coalesce(p_payload->>'service_type','')!~'^[A-Z][A-Z0-9_]{1,79}$' or length(btrim(coalesce(p_payload->>'unit_label_fr','')))=0 then return 'SERVICE_TYPE_INVALID';end if;
  if jsonb_typeof(p_payload->'credit_eligible') is distinct from 'boolean' or jsonb_typeof(p_payload->'volume_eligible') is distinct from 'boolean' or jsonb_typeof(p_payload->'recurring_eligible') is distinct from 'boolean' or jsonb_typeof(p_payload->'central_approval_flags') is distinct from 'array' then return 'SERVICE_FLAGS_INVALID';end if;
 elsif p_entity_type='SERVICE_SUBCATEGORY_LINK' then
  if coalesce(p_payload->>'service_code','')!~'^[A-Z][A-Z0-9_-]{1,79}$' or coalesce(p_payload->>'subcategory_code','')!~'^[A-Z][A-Z0-9_-]{1,79}$' or p_payload->>'link_type' not in('PRIMARY','SECONDARY') or p_payload->>'status' is distinct from 'ACTIVE' then return 'LINK_SCHEMA_INVALID';end if;
 elsif p_entity_type='QUESTION' then
  v_answer_type:=p_payload->>'answer_type';v_phase:=p_payload->>'phase';v_category:=coalesce(p_payload->>'category_code','');v_service:=coalesce(p_payload->>'service_code','');
  if p_business_key!~'^[A-Z][A-Z0-9_.-]{1,119}$' then return 'QUESTION_IDENTITY_INVALID';end if;
  if v_phase not in('RFQ','DIAGNOSTIC','PROVIDER_QUALIFICATION')
    or (v_phase='RFQ' and (v_category!~'^[A-Z][A-Z0-9_-]{1,79}$' or v_service!~'^[A-Z][A-Z0-9_-]{1,75}$'))
    or (v_phase<>'RFQ' and ((v_category='' and v_service<>'') or (v_category<>'' and v_category!~'^[A-Z][A-Z0-9_-]{1,79}$') or (v_service<>'' and v_service!~'^[A-Z][A-Z0-9_-]{1,75}$'))) then return 'QUESTION_SCOPE_INVALID';end if;
  if length(btrim(coalesce(p_payload->>'section',''))) not between 1 and 240 or coalesce(p_payload->>'order','')!~'^[1-9][0-9]{0,8}$' or length(btrim(coalesce(p_payload->>'label_fr',''))) not between 1 and 1000 then return 'QUESTION_TEXT_INVALID';end if;
  if v_answer_type not in('YES_NO','SINGLE_CHOICE','MULTIPLE_CHOICE','SHORT_TEXT','LONG_TEXT','INTEGER','DECIMAL','PERCENTAGE','MONEY','CURRENCY','DATE','DATE_RANGE','TIME','EMAIL','PHONE','URL','ADDRESS','GEO_AREA','RATING_5','RATING_10','QUANTITY','UNIT_VALUE','FILE','MULTI_FILE','IMAGE','TABLE','REPEATER','CONTACT','ORGANIZATION','PRODUCT_LIST','SITE_LIST','MILESTONE_LIST','BUDGET_BREAKDOWN') then return 'QUESTION_TYPE_INVALID';end if;
  if jsonb_typeof(p_payload->'options') is distinct from 'array' or jsonb_typeof(p_payload->'validation_schema') is distinct from 'object' or jsonb_typeof(p_payload->'condition') is distinct from 'object' then return 'QUESTION_SCHEMA_INVALID';end if;
  if (v_answer_type in('SINGLE_CHOICE','MULTIPLE_CHOICE') and jsonb_array_length(p_payload->'options')=0)
    or (v_answer_type not in('SINGLE_CHOICE','MULTIPLE_CHOICE','YES_NO') and jsonb_array_length(p_payload->'options')>0)
    or (v_answer_type='YES_NO' and exists(select 1 from jsonb_array_elements_text(p_payload->'options') option(value) where option.value not in('YES','NO','UNKNOWN'))) then return 'QUESTION_SCHEMA_INVALID';end if;
  if p_payload->'condition'<>'{}'::jsonb then return 'SOURCE_RULE_CONTRACT_MISSING';end if;
  if jsonb_typeof(p_payload->'required') is distinct from 'boolean' or jsonb_typeof(p_payload->'required_for_quote') is distinct from 'boolean' then return 'QUESTION_FLAGS_INVALID';end if;
  if coalesce(p_payload->>'data_key','')!~'^[A-Za-z][A-Za-z0-9_.-]{1,159}$' or coalesce(p_payload->>'weight','')!~'^[0-9]{1,14}(?:\.[0-9]{1,6})?$' or coalesce(p_payload->>'max_score','')!~'^[0-9]{1,14}(?:\.[0-9]{1,6})?$' then return 'QUESTION_NUMERIC_INVALID';end if;
  if p_payload->>'sensitivity' not in('PUBLIC','BUSINESS','CONFIDENTIAL','RESTRICTED') then return 'QUESTION_SENSITIVITY_INVALID';end if;
 end if;
 return null;
end$$;

create function private.suppress_catalog_import_library_scope_reference_error()
returns trigger language plpgsql security definer set search_path=pg_catalog as $$
begin
 if new.error_code='MISSING_REFERENCE' and new.import_row_id is not null and exists(
  select 1 from public.catalog_import_rows r where r.id=new.import_row_id and r.batch_id=new.batch_id
   and r.entity_type='QUESTION' and r.payload->>'phase' in('DIAGNOSTIC','PROVIDER_QUALIFICATION')
   and coalesce(r.payload->>'category_code','')='' and coalesce(r.payload->>'service_code','')=''
 ) then return null;end if;
 return new;
end$$;

create trigger catalog_import_error_10_scope_compatibility
before insert on public.catalog_import_errors for each row
execute function private.suppress_catalog_import_library_scope_reference_error();

revoke all on function private.catalog_import_payload_error(text,text,jsonb),private.suppress_catalog_import_library_scope_reference_error() from public,anon,authenticated,service_role;

