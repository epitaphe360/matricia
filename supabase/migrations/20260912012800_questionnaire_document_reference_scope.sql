create or replace function private.is_valid_questionnaire_document_references(
  p_answer_type text,
  p_structured_schema jsonb,
  p_value jsonb,
  p_organization_id uuid
) returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
declare
  v_item jsonb;
  v_row jsonb;
  v_field jsonb;
  v_fields jsonb;
  v_document_id uuid;
begin
  if p_answer_type in ('FILE','IMAGE') then
    if jsonb_typeof(p_value) <> 'string' or (p_value #>> '{}') !~ '^[0-9a-fA-F-]{36}$' then return false; end if;
    begin v_document_id := (p_value #>> '{}')::uuid; exception when others then return false; end;
    return exists (
      select 1 from public.client_compliance_documents d
      where d.id = v_document_id
        and d.organization_id = p_organization_id
        and d.status in ('PENDING_REVIEW','VERIFIED')
        and (p_answer_type <> 'IMAGE' or d.declared_mime_type like 'image/%')
    );
  end if;
  if p_answer_type = 'MULTI_FILE' then
    if jsonb_typeof(p_value) <> 'array' then return false; end if;
    for v_item in select value from jsonb_array_elements(p_value) loop
      if not private.is_valid_questionnaire_document_references('FILE',null,v_item,p_organization_id) then return false; end if;
    end loop;
    return (select count(*) from jsonb_array_elements(p_value)) =
      (select count(distinct value #>> '{}') from jsonb_array_elements(p_value));
  end if;
  if p_answer_type in ('TABLE','REPEATER') then
    if jsonb_typeof(p_value) <> 'array' or jsonb_typeof(p_structured_schema) <> 'object' then return false; end if;
    v_fields := p_structured_schema -> case when p_answer_type='TABLE' then 'columns' else 'children' end;
    if jsonb_typeof(v_fields) <> 'array' then return false; end if;
    for v_row in select value from jsonb_array_elements(p_value) loop
      for v_field in select value from jsonb_array_elements(v_fields) loop
        if v_field->>'type' in ('FILE','IMAGE','MULTI_FILE','TABLE','REPEATER')
           and not private.is_valid_questionnaire_document_references(
             v_field->>'type',
             v_field->'structured',
             v_row->(v_field->>'key'),
             p_organization_id
           ) then return false; end if;
      end loop;
    end loop;
  end if;
  return true;
exception when others then
  return false;
end
$$;

revoke all on function private.is_valid_questionnaire_document_references(text,jsonb,jsonb,uuid)
from public, anon, authenticated, service_role;

create or replace function private.enforce_questionnaire_document_reference_scope()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_answer_type text;
  v_structured_schema jsonb;
begin
  select q.answer_type,q.structured_schema
    into v_answer_type,v_structured_schema
  from public.question_versions q
  where q.id = new.question_version_id;
  if not found or not private.is_valid_questionnaire_document_references(
    v_answer_type,v_structured_schema,new.value,new.organization_id
  ) then
    raise exception 'INVALID_QUESTIONNAIRE_DOCUMENT_REFERENCE' using errcode='23514';
  end if;
  return new;
end
$$;

revoke all on function private.enforce_questionnaire_document_reference_scope()
from public, anon, authenticated, service_role;

create trigger questionnaire_answer_revision_document_scope
before insert on public.questionnaire_answer_revisions
for each row execute function private.enforce_questionnaire_document_reference_scope();
