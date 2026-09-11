-- P06 baseline importer: bounded staging, deterministic validation and atomic draft materialization.

alter table public.catalog_import_rows drop constraint catalog_import_rows_entity_type_check;
alter table public.catalog_import_rows add constraint catalog_import_rows_entity_type_check
  check(entity_type in ('LIBRARY','CATEGORY','SUBCATEGORY','SERVICE','SERVICE_SUBCATEGORY_LINK','QUESTION'));

alter table public.catalog_import_batches
  add column library_code text check(library_code is null or library_code~'^[A-Z][A-Z0-9_-]{1,31}$'),
  add column steward_organization_id uuid references public.organizations(id) on delete restrict,
  add column expected_counts jsonb check(expected_counts is null or jsonb_typeof(expected_counts)='object'),
  add column actual_counts jsonb check(actual_counts is null or jsonb_typeof(actual_counts)='object'),
  add column import_report jsonb check(import_report is null or jsonb_typeof(import_report)='object'),
  add column correlation_id uuid,
  add column command_id uuid,
  add column candidate_release_id uuid references public.catalog_releases(id) on delete restrict;

create table public.catalog_source_files(
  batch_id uuid not null references public.catalog_import_batches(id) on delete restrict,
  source_path text not null check(source_path~'^catalogue/Matricia_Catalogue_Metier_V1/[A-Za-z0-9_.-]{3,120}$'),
  sha256 text not null check(sha256~'^[0-9a-f]{64}$'),
  byte_size bigint not null check(byte_size>0),data_rows integer not null check(data_rows>=0),
  generator_version text not null check(length(btrim(generator_version)) between 1 and 80),
  imported_at timestamptz not null default clock_timestamp(),primary key(batch_id,source_path)
);
alter table public.catalog_source_files enable row level security;
revoke all on table public.catalog_source_files from public,anon,authenticated,service_role;
create index catalog_source_files_batch_idx on public.catalog_source_files(batch_id);
create index catalog_import_rows_batch_entity_idx on public.catalog_import_rows(batch_id,entity_type,business_key);

create table public.catalog_import_chunks(
  command_id uuid primary key,
  batch_id uuid not null references public.catalog_import_batches(id) on delete restrict,
  source_file text not null,
  source_sha256 text not null check(source_sha256~'^[0-9a-f]{64}$'),
  source_byte_size bigint not null check(source_byte_size>0),
  source_data_rows integer not null check(source_data_rows>=0),
  entity_type text not null check(entity_type in ('LIBRARY','CATEGORY','SUBCATEGORY','SERVICE','SERVICE_SUBCATEGORY_LINK','QUESTION')),
  chunk_hash text not null check(chunk_hash~'^[0-9a-f]{64}$'),
  row_count integer not null check(row_count between 1 and 200),
  correlation_id uuid not null,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  foreign key(batch_id,source_file) references public.catalog_source_files(batch_id,source_path) on delete restrict,
  unique(batch_id,entity_type,source_file,chunk_hash)
);
create table public.catalog_import_chunk_rows(
  command_id uuid not null references public.catalog_import_chunks(command_id) on delete restrict,
  import_row_id bigint not null references public.catalog_import_rows(id) on delete restrict,
  primary key(command_id,import_row_id)
);
alter table public.catalog_import_chunks enable row level security;
alter table public.catalog_import_chunk_rows enable row level security;
revoke all on table public.catalog_import_chunks,public.catalog_import_chunk_rows from public,anon,authenticated,service_role;
create unique index catalog_import_chunk_row_single_source_uidx on public.catalog_import_chunk_rows(import_row_id);
create index catalog_import_chunks_batch_idx on public.catalog_import_chunks(batch_id,source_file,entity_type);

alter table public.question_versions
  add column source_phase text check(source_phase is null or source_phase in ('RFQ','DIAGNOSTIC','PROVIDER_QUALIFICATION')),
  add column source_service_id uuid references public.catalog_services(id) on delete restrict,
  add column source_import_batch_id uuid,
  add column source_file text,
  add column source_line_number integer check(source_line_number is null or source_line_number>0),
  add column source_row_hash text check(source_row_hash is null or source_row_hash~'^[0-9a-f]{64}$'),
  add constraint question_version_import_source_fk foreign key(source_import_batch_id,source_file) references public.catalog_source_files(batch_id,source_path) on delete restrict,
  add constraint question_version_import_source_complete check((source_import_batch_id is null and source_file is null and source_line_number is null and source_row_hash is null) or (source_import_batch_id is not null and source_file is not null and source_line_number is not null and source_row_hash is not null)),
  add constraint question_version_phase_service_check check(source_phase is null or ((source_phase='RFQ')=(source_service_id is not null)));
create index question_versions_import_source_idx on public.question_versions(source_import_batch_id,source_file,source_line_number) where source_import_batch_id is not null;

create or replace function private.validate_questionnaire_snapshot_link() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare v_parent_status text;
begin
  select status into v_parent_status from public.questionnaire_versions where id=new.questionnaire_version_id and library_id=new.library_id;
  if v_parent_status is null then raise exception 'QUESTIONNAIRE_VERSION_NOT_LINKABLE' using errcode='23514';end if;
  if tg_table_name='questionnaire_version_questions' then
    if not exists(select 1 from public.question_versions q where q.id=new.question_version_id and q.library_id=new.library_id and (q.status in ('APPROVED','PUBLISHED') or (q.status='DRAFT' and v_parent_status='DRAFT'))) then raise exception 'QUESTION_VERSION_NOT_LINKABLE' using errcode='23514';end if;
  elsif tg_table_name='questionnaire_version_rules' then
    if not exists(select 1 from public.question_rule_versions r where r.id=new.rule_version_id and r.library_id=new.library_id and (r.status in ('APPROVED','PUBLISHED') or (r.status='DRAFT' and v_parent_status='DRAFT'))) then raise exception 'RULE_VERSION_NOT_LINKABLE' using errcode='23514';end if;
  end if;
  return new;
end$$;
revoke all on function private.validate_questionnaire_snapshot_link() from public,anon,authenticated,service_role;

create function private.catalog_baseline_uuid(p_namespace text,p_key text) returns uuid
language sql immutable security definer set search_path=pg_catalog,extensions
as $$select (substr(x,1,8)||'-'||substr(x,9,4)||'-5'||substr(x,14,3)||'-a'||substr(x,18,3)||'-'||substr(x,21,12))::uuid from(select encode(extensions.digest(convert_to(p_namespace||':'||p_key,'UTF8'),'sha256'),'hex')x)s$$;
create function private.catalog_baseline_slug(p_code text) returns text
language sql immutable security definer set search_path=pg_catalog
as $$select trim(both '-' from regexp_replace(lower(p_code),'[^a-z0-9]+','-','g'))$$;
create function private.catalog_canonical_json(p_value jsonb) returns text
language plpgsql immutable strict security definer set search_path=pg_catalog as $$
declare v_result text;v_item record;
begin
 if jsonb_typeof(p_value)='array' then
  v_result:='[';for v_item in select value,ordinality from jsonb_array_elements(p_value)with ordinality order by ordinality loop v_result:=v_result||case when v_result='['then ''else ','end||private.catalog_canonical_json(v_item.value);end loop;return v_result||']';
 elsif jsonb_typeof(p_value)='object' then
  v_result:='{';for v_item in select key,value from jsonb_each(p_value)order by key collate "C" loop v_result:=v_result||case when v_result='{'then ''else ','end||to_jsonb(v_item.key)::text||':'||private.catalog_canonical_json(v_item.value);end loop;return v_result||'}';
 else return p_value::text;end if;
end$$;
revoke all on function private.catalog_baseline_uuid(text,text),private.catalog_baseline_slug(text),private.catalog_canonical_json(jsonb) from public,anon,authenticated,service_role;

create function private.catalog_import_payload_error(p_entity_type text,p_business_key text,p_payload jsonb) returns text
language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_answer_type text;v_phase text;
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
  v_answer_type:=p_payload->>'answer_type';v_phase:=p_payload->>'phase';
  if p_business_key!~'^[A-Z][A-Z0-9_.-]{1,119}$' then return 'QUESTION_IDENTITY_INVALID';end if;
  if v_phase not in('RFQ','DIAGNOSTIC','PROVIDER_QUALIFICATION') or coalesce(p_payload->>'category_code','')!~'^[A-Z][A-Z0-9_-]{1,79}$' or ((v_phase='RFQ') is distinct from (coalesce(p_payload->>'service_code','')~'^[A-Z][A-Z0-9_-]{1,75}$')) then return 'QUESTION_SCOPE_INVALID';end if;
  if length(btrim(coalesce(p_payload->>'section',''))) not between 1 and 240 or coalesce(p_payload->>'order','')!~'^[1-9][0-9]{0,8}$' or length(btrim(coalesce(p_payload->>'label_fr',''))) not between 1 and 1000 then return 'QUESTION_TEXT_INVALID';end if;
  if v_answer_type not in('YES_NO','SINGLE_CHOICE','MULTIPLE_CHOICE','SHORT_TEXT','LONG_TEXT','INTEGER','DECIMAL','PERCENTAGE','MONEY','CURRENCY','DATE','DATE_RANGE','TIME','EMAIL','PHONE','URL','ADDRESS','GEO_AREA','RATING_5','RATING_10','QUANTITY','UNIT_VALUE','FILE','MULTI_FILE','IMAGE','TABLE','REPEATER','CONTACT','ORGANIZATION','PRODUCT_LIST','SITE_LIST','MILESTONE_LIST','BUDGET_BREAKDOWN') then return 'QUESTION_TYPE_INVALID';end if;
  if jsonb_typeof(p_payload->'options') is distinct from 'array' or jsonb_typeof(p_payload->'validation_schema') is distinct from 'object' or jsonb_typeof(p_payload->'condition') is distinct from 'object' then return 'QUESTION_SCHEMA_INVALID';end if;
  if (v_answer_type in('SINGLE_CHOICE','MULTIPLE_CHOICE')) is distinct from (jsonb_array_length(p_payload->'options')>0) then return 'QUESTION_SCHEMA_INVALID';end if;
  if p_payload->'condition'<>'{}'::jsonb then return 'SOURCE_RULE_CONTRACT_MISSING';end if;
  if jsonb_typeof(p_payload->'required') is distinct from 'boolean' or jsonb_typeof(p_payload->'required_for_quote') is distinct from 'boolean' then return 'QUESTION_FLAGS_INVALID';end if;
  if coalesce(p_payload->>'data_key','')!~'^[A-Za-z][A-Za-z0-9_.-]{1,159}$' or coalesce(p_payload->>'weight','')!~'^[0-9]{1,14}(?:\.[0-9]{1,6})?$' or coalesce(p_payload->>'max_score','')!~'^[0-9]{1,14}(?:\.[0-9]{1,6})?$' then return 'QUESTION_NUMERIC_INVALID';end if;
  if p_payload->>'sensitivity' not in('PUBLIC','BUSINESS','CONFIDENTIAL','RESTRICTED') then return 'QUESTION_SENSITIVITY_INVALID';end if;
 end if;
 return null;
end$$;
revoke all on function private.catalog_import_payload_error(text,text,jsonb) from public,anon,authenticated,service_role;

create function private.assert_catalog_baseline_actor() returns uuid
language plpgsql stable security definer set search_path=pg_catalog,private as $$
declare v_actor uuid:=auth.uid();
begin
 if v_actor is null or auth.role() is distinct from 'authenticated' or auth.jwt()->>'aal' is distinct from 'aal2'
    or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],v_actor) then
  raise exception 'CATALOG_IMPORT_DENIED' using errcode='42501';
 end if;return v_actor;
end$$;
revoke all on function private.assert_catalog_baseline_actor() from public,anon,authenticated,service_role;

create function public.begin_catalog_import(
 p_baseline_key text,p_bundle_hash text,p_manifest jsonb,p_library_code text,p_steward_organization_id uuid,
 p_expected_counts jsonb,p_source_files jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=private.assert_catalog_baseline_actor();v_hash text;v_existing public.catalog_command_keys%rowtype;
 v_batch public.catalog_import_batches%rowtype;v_file jsonb;v_response jsonb;v_canonical_sources jsonb;v_computed_bundle text;v_command uuid:=extensions.gen_random_uuid();
begin
 if p_baseline_key is null or p_baseline_key!~'^[A-Z][A-Z0-9_.:-]{7,119}$' or p_bundle_hash!~'^[0-9a-f]{64}$'
  or p_library_code!~'^[A-Z][A-Z0-9_-]{1,31}$' or p_correlation_id is null
  or jsonb_typeof(p_manifest) is distinct from 'object' or jsonb_typeof(p_expected_counts) is distinct from 'object'
  or jsonb_typeof(p_source_files) is distinct from 'array' or jsonb_array_length(p_source_files)<>10
  or coalesce(length(p_idempotency_key),0) not between 8 and 200 then raise exception 'INVALID_CATALOG_IMPORT_REQUEST' using errcode='22023';end if;
 if (select array_agg(k.key order by k.key)from jsonb_object_keys(p_expected_counts)as k(key)) is distinct from array['categories','diagnostic_questions','libraries','provider_questions','rfq_questions','service_subcategory_links','services','subcategories','total_questions']::text[] or exists(select 1 from jsonb_each_text(p_expected_counts)e where e.value!~'^[0-9]{1,6}$') then raise exception 'CATALOG_LIBRARY_MANIFEST_COUNTS_INVALID' using errcode='22023';end if;
 if not exists(select 1 from public.organizations where id=p_steward_organization_id and status='ACTIVE') then raise exception 'CATALOG_IMPORT_ORGANIZATION_INACTIVE' using errcode='42501';end if;
 if p_manifest#>>'{counts,libraries}' is distinct from '10' or p_manifest#>>'{counts,categories}' is distinct from '40'
  or p_manifest#>>'{counts,subcategories}' is distinct from '80' or p_manifest#>>'{counts,services}' is distinct from '200'
  or p_manifest#>>'{counts,service_subcategory_links}' is distinct from '212' or p_manifest#>>'{counts,total_questions}' is distinct from '6000'
  or p_manifest#>>'{counts,rfq_questions}' is distinct from '5000' or p_manifest#>>'{counts,diagnostic_questions}' is distinct from '700'
 or p_manifest#>>'{counts,provider_questions}' is distinct from '300' then raise exception 'CATALOG_MANIFEST_COUNTS_INVALID' using errcode='22023';end if;
 if exists(select 1 from jsonb_array_elements(p_source_files)f where jsonb_typeof(f)<>'object' or not(f?&array['path','sha256','byte_size','data_rows','generator_version']) or (f->>'sha256')!~'^[0-9a-f]{64}$' or (f->>'byte_size')!~'^[1-9][0-9]{0,15}$' or (f->>'data_rows')!~'^[0-9]{1,8}$' or f->>'generator_version' is distinct from p_manifest->>'catalog_version') then raise exception 'INVALID_CATALOG_SOURCE_FILE' using errcode='22023';end if;
 select jsonb_agg(jsonb_build_object('path',f->>'path','sha256',f->>'sha256','byte_size',(f->>'byte_size')::bigint,'data_rows',(f->>'data_rows')::integer) order by f->>'path') into v_canonical_sources from jsonb_array_elements(p_source_files)f;
 if (select array_agg(f->>'path' order by f->>'path') from jsonb_array_elements(p_source_files)f) is distinct from array[
  'catalogue/Matricia_Catalogue_Metier_V1/catalog_manifest.json','catalogue/Matricia_Catalogue_Metier_V1/categories.csv','catalogue/Matricia_Catalogue_Metier_V1/libraries.csv','catalogue/Matricia_Catalogue_Metier_V1/questions_all.jsonl','catalogue/Matricia_Catalogue_Metier_V1/questions_diagnostic.csv','catalogue/Matricia_Catalogue_Metier_V1/questions_provider_qualification.csv','catalogue/Matricia_Catalogue_Metier_V1/questions_rfq.csv','catalogue/Matricia_Catalogue_Metier_V1/service_subcategory_links.csv','catalogue/Matricia_Catalogue_Metier_V1/services.csv','catalogue/Matricia_Catalogue_Metier_V1/subcategories.csv'
 ]::text[] then raise exception 'CATALOG_SOURCE_ALLOWLIST_INVALID' using errcode='22023';end if;
 if exists(select 1 from jsonb_array_elements(p_source_files)f where (f->>'data_rows')::integer is distinct from case f->>'path' when 'catalogue/Matricia_Catalogue_Metier_V1/catalog_manifest.json'then 1 when 'catalogue/Matricia_Catalogue_Metier_V1/libraries.csv'then 10 when 'catalogue/Matricia_Catalogue_Metier_V1/categories.csv'then 40 when 'catalogue/Matricia_Catalogue_Metier_V1/subcategories.csv'then 80 when 'catalogue/Matricia_Catalogue_Metier_V1/services.csv'then 200 when 'catalogue/Matricia_Catalogue_Metier_V1/service_subcategory_links.csv'then 212 when 'catalogue/Matricia_Catalogue_Metier_V1/questions_rfq.csv'then 5000 when 'catalogue/Matricia_Catalogue_Metier_V1/questions_diagnostic.csv'then 700 when 'catalogue/Matricia_Catalogue_Metier_V1/questions_provider_qualification.csv'then 300 when 'catalogue/Matricia_Catalogue_Metier_V1/questions_all.jsonl'then 6000 end) then raise exception 'CATALOG_SOURCE_COUNTS_INVALID' using errcode='22023';end if;
 v_computed_bundle:=encode(extensions.digest(convert_to(private.catalog_canonical_json(jsonb_build_object('manifest',p_manifest,'sources',v_canonical_sources)),'UTF8'),'sha256'),'hex');
 if p_bundle_hash is distinct from v_computed_bundle then raise exception 'CATALOG_BUNDLE_HASH_MISMATCH' using errcode='22000';end if;
 if p_expected_counts->>'libraries' is distinct from '1'
  or p_expected_counts->>'categories' is distinct from p_manifest#>>array['by_library',p_library_code,'categories']
  or p_expected_counts->>'subcategories' is distinct from p_manifest#>>array['by_library',p_library_code,'subcategories']
  or p_expected_counts->>'services' is distinct from p_manifest#>>array['by_library',p_library_code,'services']
  or p_expected_counts->>'rfq_questions' is distinct from p_manifest#>>array['by_library',p_library_code,'rfq_questions']
  or p_expected_counts->>'diagnostic_questions' is distinct from p_manifest#>>array['by_library',p_library_code,'diagnostic_questions']
  or p_expected_counts->>'provider_questions' is distinct from p_manifest#>>array['by_library',p_library_code,'provider_questions']
  or (p_expected_counts->>'total_questions')::integer is distinct from ((p_expected_counts->>'rfq_questions')::integer+(p_expected_counts->>'diagnostic_questions')::integer+(p_expected_counts->>'provider_questions')::integer)
  or (p_expected_counts->>'service_subcategory_links')::integer < (p_expected_counts->>'services')::integer then raise exception 'CATALOG_LIBRARY_MANIFEST_COUNTS_INVALID' using errcode='22023';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.import.begin.v1','baseline_key',p_baseline_key,'bundle_hash',p_bundle_hash,'manifest',p_manifest,'library_code',p_library_code,'organization_id',p_steward_organization_id,'expected_counts',p_expected_counts,'source_files',p_source_files));
 perform pg_advisory_xact_lock(hashtextextended(v_actor::text||':catalog.import.begin:'||p_idempotency_key,0));
 perform pg_advisory_xact_lock(hashtextextended('catalog-import-baseline:'||p_baseline_key,0));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.import.begin' and key=p_idempotency_key;
 if found then
  if v_existing.request_hash is distinct from v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000';end if;
  if v_existing.response_body is null or coalesce(v_existing.response_body->>'batch_id','')!~'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception 'CATALOG_IMPORT_REPLAY_CORRUPT' using errcode='55000';end if;
  select * into v_batch from public.catalog_import_batches where id=(v_existing.response_body->>'batch_id')::uuid for update;
  if not found or v_batch.baseline_key is distinct from p_baseline_key or v_batch.bundle_hash is distinct from p_bundle_hash
    or v_batch.created_by is distinct from v_actor or v_batch.library_code is distinct from p_library_code
    or v_batch.steward_organization_id is distinct from p_steward_organization_id or v_batch.manifest is distinct from p_manifest
    or v_batch.expected_counts is distinct from p_expected_counts or v_batch.source_kind is distinct from 'GOLD_MASTER_BASELINE'
    or v_batch.correlation_id is distinct from p_correlation_id or v_batch.command_id is distinct from (v_existing.response_body->>'command_id')::uuid
    or (select count(*) from public.catalog_source_files where batch_id=v_batch.id)<>10 or exists(
      select 1 from public.catalog_source_files s where s.batch_id=v_batch.id and not exists(
       select 1 from jsonb_array_elements(p_source_files) f where f->>'path'=s.source_path and f->>'sha256'=s.sha256
        and (f->>'byte_size')::bigint=s.byte_size and (f->>'data_rows')::integer=s.data_rows and f->>'generator_version'=s.generator_version)) then
   raise exception 'CATALOG_IMPORT_REPLAY_SCOPE_MISMATCH' using errcode='42501';
  end if;
  return v_existing.response_body;
 end if;
 if exists(select 1 from public.catalog_import_batches where baseline_key=p_baseline_key and bundle_hash<>p_bundle_hash) then raise exception 'CATALOG_BASELINE_KEY_CONFLICT' using errcode='22000';end if;
 select * into v_batch from public.catalog_import_batches where baseline_key=p_baseline_key and bundle_hash=p_bundle_hash for update;
 if not found then
  insert into public.catalog_import_batches(status,baseline_key,bundle_hash,manifest,source_kind,created_by,library_code,steward_organization_id,expected_counts,correlation_id,command_id)
  values('RECEIVED',p_baseline_key,p_bundle_hash,p_manifest,'GOLD_MASTER_BASELINE',v_actor,p_library_code,p_steward_organization_id,p_expected_counts,p_correlation_id,v_command) returning * into v_batch;
 else
  if v_batch.created_by is distinct from v_actor or v_batch.library_code is distinct from p_library_code
    or v_batch.steward_organization_id is distinct from p_steward_organization_id or v_batch.manifest is distinct from p_manifest
    or v_batch.expected_counts is distinct from p_expected_counts or v_batch.source_kind is distinct from 'GOLD_MASTER_BASELINE'
    or v_batch.correlation_id is distinct from p_correlation_id then
   raise exception 'CATALOG_IMPORT_BATCH_SCOPE_MISMATCH' using errcode='42501';
  end if;
 end if;
 for v_file in select value from jsonb_array_elements(p_source_files) loop
  insert into public.catalog_source_files(batch_id,source_path,sha256,byte_size,data_rows,generator_version)
  values(v_batch.id,v_file->>'path',v_file->>'sha256',(v_file->>'byte_size')::bigint,(v_file->>'data_rows')::integer,v_file->>'generator_version')
  on conflict(batch_id,source_path) do update set sha256=excluded.sha256
   where public.catalog_source_files.sha256=excluded.sha256 and public.catalog_source_files.byte_size=excluded.byte_size and public.catalog_source_files.data_rows=excluded.data_rows and public.catalog_source_files.generator_version=excluded.generator_version;
  if not found then raise exception 'CATALOG_SOURCE_FILE_MISMATCH' using errcode='22000';end if;
 end loop;
 if (select count(*) from public.catalog_source_files where batch_id=v_batch.id)<>10 or exists(
  select 1 from public.catalog_source_files s where s.batch_id=v_batch.id and not exists(
   select 1 from jsonb_array_elements(p_source_files) f where f->>'path'=s.source_path and f->>'sha256'=s.sha256
    and (f->>'byte_size')::bigint=s.byte_size and (f->>'data_rows')::integer=s.data_rows and f->>'generator_version'=s.generator_version)) then
  raise exception 'CATALOG_SOURCE_FILE_MISMATCH' using errcode='22000';
 end if;
 v_response:=jsonb_build_object('outcome','CATALOG_IMPORT_RECEIVED','batch_id',v_batch.id,'status',v_batch.status,'row_version',v_batch.row_version,'library_code',p_library_code,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(p_steward_organization_id,v_actor,'USER','catalog.import.begun','catalog_import_batch',v_batch.id::text,p_correlation_id,jsonb_build_object('baseline_key',p_baseline_key,'bundle_hash',p_bundle_hash,'library_code',p_library_code,'command_id',v_command),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id) values(p_steward_organization_id,'catalog_import_batch',v_batch.id::text,'CatalogImportBegunV1',p_correlation_id,jsonb_build_object('batch_id',v_batch.id,'bundle_hash',p_bundle_hash,'library_code',p_library_code),p_idempotency_key,v_command);
 insert into public.catalog_command_keys(actor_user_id,operation_scope,key,request_hash,response_body,completed_at) values(v_actor,'catalog.import.begin',p_idempotency_key,v_hash,v_response,clock_timestamp());return v_response;
end$$;

create function public.stage_catalog_import_rows(p_batch_id uuid,p_source_file text,p_entity_type text,p_rows jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=private.assert_catalog_baseline_actor();v_batch public.catalog_import_batches%rowtype;v_source public.catalog_source_files%rowtype;v_hash text;v_existing public.catalog_command_keys%rowtype;v_row jsonb;v_row_hash text;v_count integer:=0;v_response jsonb;v_command uuid:=extensions.gen_random_uuid();v_import_row_id bigint;
begin
 if p_batch_id is null or p_entity_type not in('LIBRARY','CATEGORY','SUBCATEGORY','SERVICE','SERVICE_SUBCATEGORY_LINK','QUESTION')
  or jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows) not between 1 and 200 or octet_length(p_rows::text)>2097152
  or coalesce(length(p_idempotency_key),0) not between 8 and 200 or p_correlation_id is null then raise exception 'INVALID_CATALOG_IMPORT_CHUNK' using errcode='22023';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.import.stage.v1','batch_id',p_batch_id,'source_file',p_source_file,'entity_type',p_entity_type,'rows',p_rows));
 perform pg_advisory_xact_lock(hashtextextended(v_actor::text||':catalog.import.stage:'||p_idempotency_key,0));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.import.stage' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000';end if;return v_existing.response_body;end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-import:'||p_batch_id::text,0));
 select * into v_batch from public.catalog_import_batches where id=p_batch_id for update;
 if not found or v_batch.created_by<>v_actor or v_batch.status not in('RECEIVED','VALIDATING') then raise exception 'CATALOG_IMPORT_NOT_STAGEABLE' using errcode='55000';end if;
 select * into v_source from public.catalog_source_files where batch_id=p_batch_id and source_path=p_source_file;
 if not found then raise exception 'CATALOG_SOURCE_FILE_NOT_REGISTERED' using errcode='22023';end if;
 if p_source_file is distinct from (case p_entity_type
   when 'LIBRARY' then 'catalogue/Matricia_Catalogue_Metier_V1/libraries.csv'
   when 'CATEGORY' then 'catalogue/Matricia_Catalogue_Metier_V1/categories.csv'
   when 'SUBCATEGORY' then 'catalogue/Matricia_Catalogue_Metier_V1/subcategories.csv'
   when 'SERVICE' then 'catalogue/Matricia_Catalogue_Metier_V1/services.csv'
   when 'SERVICE_SUBCATEGORY_LINK' then 'catalogue/Matricia_Catalogue_Metier_V1/service_subcategory_links.csv'
   when 'QUESTION' then 'catalogue/Matricia_Catalogue_Metier_V1/questions_all.jsonl'
  end) then raise exception 'CATALOG_SOURCE_ENTITY_MISMATCH' using errcode='22023';end if;
 insert into public.catalog_import_chunks(command_id,batch_id,source_file,source_sha256,source_byte_size,source_data_rows,entity_type,chunk_hash,row_count,correlation_id,created_by)
 values(v_command,p_batch_id,p_source_file,v_source.sha256,v_source.byte_size,v_source.data_rows,p_entity_type,private.canonical_request_hash(p_rows),jsonb_array_length(p_rows),p_correlation_id,v_actor);
 for v_row in select value from jsonb_array_elements(p_rows) loop
  if jsonb_typeof(v_row)<>'object' or not(v_row?&array['line_number','business_key','payload']) or (v_row->>'line_number')!~'^[1-9][0-9]{0,7}$'
    or (v_row->>'line_number')::integer < (case when right(p_source_file,4)='.csv' then 2 else 1 end)
    or (v_row->>'line_number')::integer > (case when right(p_source_file,4)='.csv' then v_source.data_rows+1 else v_source.data_rows end)
    or length(v_row->>'business_key') not between 2 and 160 or jsonb_typeof(v_row->'payload')<>'object' or octet_length((v_row->'payload')::text)>65536 then raise exception 'INVALID_CATALOG_IMPORT_ROW' using errcode='22023';end if;
  v_row_hash:=encode(extensions.digest(convert_to((v_row->'payload')::text,'UTF8'),'sha256'),'hex');
  insert into public.catalog_import_rows(batch_id,source_file,line_number,entity_type,business_key,payload,row_hash)
  values(p_batch_id,p_source_file,(v_row->>'line_number')::integer,p_entity_type,v_row->>'business_key',v_row->'payload',v_row_hash)
  on conflict(batch_id,entity_type,business_key) do update set business_key=excluded.business_key
   where public.catalog_import_rows.source_file=excluded.source_file and public.catalog_import_rows.line_number=excluded.line_number and public.catalog_import_rows.row_hash=excluded.row_hash returning id into v_import_row_id;
  if v_import_row_id is null then raise exception 'CATALOG_IMPORT_ROW_MISMATCH' using errcode='22000';end if;
  insert into public.catalog_import_chunk_rows(command_id,import_row_id) values(v_command,v_import_row_id);
  v_count:=v_count+1;
 end loop;
 update public.catalog_import_batches set status='VALIDATING',row_version=row_version+1 where id=p_batch_id;
 v_response:=jsonb_build_object('outcome','CATALOG_IMPORT_ROWS_STAGED','batch_id',p_batch_id,'accepted',v_count,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_batch.steward_organization_id,v_actor,'USER','catalog.import.rows_staged','catalog_import_batch',p_batch_id::text,p_correlation_id,jsonb_build_object('entity_type',p_entity_type,'source_file',p_source_file,'source_sha256',v_source.sha256,'row_count',v_count,'chunk_hash',private.canonical_request_hash(p_rows),'command_id',v_command),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id) values(v_batch.steward_organization_id,'catalog_import_batch',p_batch_id::text,'CatalogImportRowsStagedV1',p_correlation_id,jsonb_build_object('batch_id',p_batch_id,'entity_type',p_entity_type,'source_file',p_source_file,'source_sha256',v_source.sha256,'row_count',v_count,'chunk_hash',private.canonical_request_hash(p_rows)),p_idempotency_key,v_command);
 insert into public.catalog_command_keys(actor_user_id,operation_scope,key,request_hash,response_body,completed_at) values(v_actor,'catalog.import.stage',p_idempotency_key,v_hash,v_response,clock_timestamp());return v_response;
end$$;

create function private.catalog_import_actual_counts(p_batch_id uuid) returns jsonb
language sql stable security definer set search_path=pg_catalog as $$
 select jsonb_build_object(
  'libraries',count(*)filter(where entity_type='LIBRARY'),'categories',count(*)filter(where entity_type='CATEGORY'),
  'subcategories',count(*)filter(where entity_type='SUBCATEGORY'),'services',count(*)filter(where entity_type='SERVICE'),
  'service_subcategory_links',count(*)filter(where entity_type='SERVICE_SUBCATEGORY_LINK'),
  'rfq_questions',count(*)filter(where entity_type='QUESTION' and payload->>'phase'='RFQ'),
  'diagnostic_questions',count(*)filter(where entity_type='QUESTION' and payload->>'phase'='DIAGNOSTIC'),
  'provider_questions',count(*)filter(where entity_type='QUESTION' and payload->>'phase'='PROVIDER_QUALIFICATION'),
  'total_questions',count(*)filter(where entity_type='QUESTION')) from public.catalog_import_rows where batch_id=p_batch_id
$$;
revoke all on function private.catalog_import_actual_counts(uuid) from public,anon,authenticated,service_role;

create function public.validate_catalog_import(p_batch_id uuid,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=private.assert_catalog_baseline_actor();v_batch public.catalog_import_batches%rowtype;v_hash text;v_existing public.catalog_command_keys%rowtype;v_actual jsonb;v_errors integer;v_response jsonb;v_command uuid:=extensions.gen_random_uuid();
begin
 if p_batch_id is null or p_expected_row_version is null or p_expected_row_version<1 or coalesce(length(p_idempotency_key),0) not between 8 and 200 or p_correlation_id is null then raise exception 'INVALID_CATALOG_IMPORT_VALIDATION' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-import:'||p_batch_id::text,0));select * into v_batch from public.catalog_import_batches where id=p_batch_id for update;
 if not found or v_batch.created_by<>v_actor then raise exception 'CATALOG_IMPORT_NOT_FOUND' using errcode='P0002';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.import.validate.v1','batch_id',p_batch_id,'expected',p_expected_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.import.validate' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000';end if;return v_existing.response_body;end if;
 if v_batch.status<>'VALIDATING' then raise exception 'CATALOG_IMPORT_NOT_VALIDATABLE' using errcode='55000';end if;
 if v_batch.row_version<>p_expected_row_version then raise exception 'STALE_CATALOG_IMPORT' using errcode='40001';end if;
 delete from public.catalog_import_errors where batch_id=p_batch_id;
 v_actual:=private.catalog_import_actual_counts(p_batch_id);
 if v_actual is distinct from v_batch.expected_counts then insert into public.catalog_import_errors(batch_id,error_code,public_message) values(p_batch_id,'COUNT_MISMATCH','Les compteurs recalculés ne correspondent pas au manifeste de la bibliothèque.');end if;
 insert into public.catalog_import_errors(batch_id,error_code,field_name,public_message)
 select p_batch_id,'SOURCE_CHUNK_MISMATCH','source_file','Les chunks ne correspondent pas exactement aux lignes et empreintes des sources enregistrées.' where exists(
  select 1 from public.catalog_import_chunks c join public.catalog_source_files s on s.batch_id=c.batch_id and s.source_path=c.source_file left join public.catalog_import_chunk_rows cr on cr.command_id=c.command_id
  where c.batch_id=p_batch_id group by c.command_id,c.source_sha256,c.source_byte_size,c.source_data_rows,c.row_count,s.sha256,s.byte_size,s.data_rows
  having c.source_sha256 is distinct from s.sha256 or c.source_byte_size is distinct from s.byte_size or c.source_data_rows is distinct from s.data_rows or count(cr.import_row_id) is distinct from c.row_count::bigint);
 insert into public.catalog_import_errors(batch_id,import_row_id,error_code,field_name,public_message)
 select p_batch_id,r.id,'SOURCE_ROW_UNBOUND','source_file','La ligne importée n’est pas liée à un chunk source unique et attesté.' from public.catalog_import_rows r
 where r.batch_id=p_batch_id and 1<>(select count(*) from public.catalog_import_chunk_rows cr where cr.import_row_id=r.id) order by r.source_file,r.line_number,r.id;
 insert into public.catalog_import_errors(batch_id,import_row_id,error_code,field_name,public_message)
 select p_batch_id,r.id,'SOURCE_LINE_INVALID','line_number','Le numéro de ligne dépasse les bornes de la source enregistrée.' from public.catalog_import_rows r join public.catalog_source_files s on s.batch_id=r.batch_id and s.source_path=r.source_file
 where r.batch_id=p_batch_id and r.line_number>case when right(r.source_file,4)='.csv' then s.data_rows+1 else s.data_rows end order by r.source_file,r.line_number,r.id;
 insert into public.catalog_import_errors(batch_id,import_row_id,error_code,field_name,public_message)
 select p_batch_id,r.id,'SOURCE_ROW_HASH_MISMATCH','row_hash','L’empreinte canonique de la ligne ne correspond pas au payload stocké.' from public.catalog_import_rows r
 where r.batch_id=p_batch_id and r.row_hash is distinct from private.canonical_request_hash(r.payload) order by r.source_file,r.line_number,r.id;
 insert into public.catalog_import_errors(batch_id,import_row_id,error_code,field_name,public_message)
 select p_batch_id,r.id,private.catalog_import_payload_error(r.entity_type,r.business_key,r.payload),'payload','Le payload ne respecte pas le contrat typé de son entité.' from public.catalog_import_rows r
 where r.batch_id=p_batch_id and private.catalog_import_payload_error(r.entity_type,r.business_key,r.payload) is not null order by r.source_file,r.line_number,r.id;
 insert into public.catalog_import_errors(batch_id,import_row_id,error_code,field_name,public_message)
 select p_batch_id,r.id,'LIBRARY_SCOPE_MISMATCH','library_code','La ligne ne relève pas de la bibliothèque ciblée.' from public.catalog_import_rows r where r.batch_id=p_batch_id and coalesce(r.payload->>'library_code',r.payload->>'code')<>v_batch.library_code;
 insert into public.catalog_import_errors(batch_id,import_row_id,error_code,field_name,public_message)
 select p_batch_id,r.id,'MISSING_REFERENCE','reference','Une référence catalogue de la ligne est absente du batch.' from public.catalog_import_rows r where r.batch_id=p_batch_id and(
  (r.entity_type='CATEGORY' and not exists(select 1 from public.catalog_import_rows p where p.batch_id=p_batch_id and p.entity_type='LIBRARY' and p.business_key=r.payload->>'library_code')) or
  (r.entity_type='SUBCATEGORY' and not exists(select 1 from public.catalog_import_rows p where p.batch_id=p_batch_id and p.entity_type='CATEGORY' and p.business_key=r.payload->>'macro_category_code')) or
  (r.entity_type='SERVICE' and not exists(select 1 from public.catalog_import_rows p where p.batch_id=p_batch_id and p.entity_type='SUBCATEGORY' and p.business_key=r.payload->>'subcategory_code' and p.payload->>'macro_category_code'=r.payload->>'macro_category_code')) or
  (r.entity_type='SERVICE_SUBCATEGORY_LINK' and (not exists(select 1 from public.catalog_import_rows p where p.batch_id=p_batch_id and p.entity_type='SERVICE' and p.business_key=r.payload->>'service_code') or not exists(select 1 from public.catalog_import_rows p where p.batch_id=p_batch_id and p.entity_type='SUBCATEGORY' and p.business_key=r.payload->>'subcategory_code'))) or
  (r.entity_type='QUESTION' and (not exists(select 1 from public.catalog_import_rows p where p.batch_id=p_batch_id and p.entity_type='SUBCATEGORY' and p.business_key=r.payload->>'category_code') or (r.payload->>'phase'='RFQ' and not exists(select 1 from public.catalog_import_rows p where p.batch_id=p_batch_id and p.entity_type='SERVICE' and p.business_key=r.payload->>'service_code')))));
 insert into public.catalog_import_errors(batch_id,error_code,field_name,public_message)
 select p_batch_id,'PRIMARY_LINK_INVALID','link_type','Chaque service doit avoir exactement un lien principal.' where exists(
  select 1 from public.catalog_import_rows s where s.batch_id=p_batch_id and s.entity_type='SERVICE' and 1<>(select count(*) from public.catalog_import_rows l where l.batch_id=p_batch_id and l.entity_type='SERVICE_SUBCATEGORY_LINK' and l.payload->>'service_code'=s.business_key and l.payload->>'link_type'='PRIMARY'));
 insert into public.catalog_import_errors(batch_id,error_code,field_name,public_message)
 select p_batch_id,'RFQ_COUNT_INVALID','phase','Chaque service doit contenir exactement 25 questions RFQ.' where exists(
  select 1 from public.catalog_import_rows s where s.batch_id=p_batch_id and s.entity_type='SERVICE' and 25<>(select count(*) from public.catalog_import_rows q where q.batch_id=p_batch_id and q.entity_type='QUESTION' and q.payload->>'phase'='RFQ' and q.payload->>'service_code'=s.business_key));
 insert into public.catalog_import_errors(batch_id,error_code,field_name,public_message)
 select p_batch_id,'QUESTION_DISTRIBUTION_INVALID','phase','La bibliothèque doit contenir 70 questions diagnostic et 30 qualification Provider.' where
  (select count(*) from public.catalog_import_rows q where q.batch_id=p_batch_id and q.entity_type='QUESTION' and q.payload->>'phase'='DIAGNOSTIC')<>70 or
  (select count(*) from public.catalog_import_rows q where q.batch_id=p_batch_id and q.entity_type='QUESTION' and q.payload->>'phase'='PROVIDER_QUALIFICATION')<>30;
 insert into public.catalog_import_errors(batch_id,error_code,field_name,public_message)
 select p_batch_id,'QUESTION_ORDER_DUPLICATE','order','L’ordre des questions doit être unique dans chaque questionnaire cible.' where exists(select 1 from public.catalog_import_rows q where q.batch_id=p_batch_id and q.entity_type='QUESTION' group by q.payload->>'phase',case when q.payload->>'phase'='RFQ'then q.payload->>'service_code'else ''end,q.payload->>'order' having count(*)>1);
 select count(*) into v_errors from public.catalog_import_errors where batch_id=p_batch_id;
 update public.catalog_import_rows set validation_status=case when v_errors=0 then 'VALID' else 'INVALID' end where batch_id=p_batch_id;
 update public.catalog_import_batches set status=case when v_errors=0 then 'READY' else 'INVALID' end,validated_at=clock_timestamp(),actual_counts=v_actual,
  import_report=jsonb_build_object('valid',v_errors=0,'error_count',v_errors,'actual_counts',v_actual),row_version=row_version+1 where id=p_batch_id returning * into v_batch;
 v_response:=jsonb_build_object('outcome',case when v_errors=0 then 'CATALOG_IMPORT_VALIDATED' else 'CATALOG_IMPORT_INVALID' end,'batch_id',p_batch_id,'status',v_batch.status,'error_count',v_errors,'actual_counts',v_actual,'row_version',v_batch.row_version,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_batch.steward_organization_id,v_actor,'USER','catalog.import.validated','catalog_import_batch',p_batch_id::text,p_correlation_id,jsonb_build_object('valid',v_errors=0,'error_count',v_errors,'actual_counts',v_actual,'bundle_hash',v_batch.bundle_hash,'command_id',v_command),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id) values(v_batch.steward_organization_id,'catalog_import_batch',p_batch_id::text,'CatalogImportValidatedV1',p_correlation_id,jsonb_build_object('batch_id',p_batch_id,'valid',v_errors=0,'error_count',v_errors,'actual_counts',v_actual,'bundle_hash',v_batch.bundle_hash),p_idempotency_key,v_command);
 insert into public.catalog_command_keys(actor_user_id,operation_scope,key,request_hash,response_body,completed_at) values(v_actor,'catalog.import.validate',p_idempotency_key,v_hash,v_response,clock_timestamp());return v_response;
end$$;

revoke all on function public.begin_catalog_import(text,text,jsonb,text,uuid,jsonb,jsonb,text,uuid),public.stage_catalog_import_rows(uuid,text,text,jsonb,text,uuid),public.validate_catalog_import(uuid,integer,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.begin_catalog_import(text,text,jsonb,text,uuid,jsonb,jsonb,text,uuid),public.stage_catalog_import_rows(uuid,text,text,jsonb,text,uuid),public.validate_catalog_import(uuid,integer,text,uuid) to authenticated;

create function public.commit_catalog_import(p_batch_id uuid,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=private.assert_catalog_baseline_actor();v_batch public.catalog_import_batches%rowtype;v_hash text;v_existing public.catalog_command_keys%rowtype;
 v_row record;v_child record;v_payload jsonb;v_library_id uuid;v_id uuid;v_version_id uuid;v_parent_id uuid;v_service_id uuid;v_subcategory_id uuid;
 v_release_id uuid;v_questionnaire_id uuid;v_questionnaire_version_id uuid;v_question_id uuid;v_question_version_id uuid;v_section_id uuid;v_rule_id uuid;v_rule_version_id uuid;
 v_code text;v_qcode text;v_section text;v_phase text;v_sort integer;v_snapshot text;v_response jsonb;v_command uuid;v_existing_hash text;
begin
 if p_batch_id is null or p_expected_row_version is null or p_expected_row_version<1 or coalesce(length(p_idempotency_key),0) not between 8 and 200 or p_correlation_id is null then raise exception 'INVALID_CATALOG_IMPORT_COMMIT' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-import:'||p_batch_id::text,0));select * into v_batch from public.catalog_import_batches where id=p_batch_id for update;
 if not found or v_batch.created_by<>v_actor then raise exception 'CATALOG_IMPORT_NOT_FOUND' using errcode='P0002';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.import.commit.v1','batch_id',p_batch_id,'expected',p_expected_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.import.commit' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000';end if;return v_existing.response_body;end if;
 if v_batch.row_version<>p_expected_row_version then raise exception 'STALE_CATALOG_IMPORT' using errcode='40001';end if;
 if v_batch.status<>'READY' or exists(select 1 from public.catalog_import_errors where batch_id=p_batch_id) then raise exception 'CATALOG_IMPORT_NOT_READY' using errcode='55000';end if;
 select * into v_row from public.catalog_import_rows where batch_id=p_batch_id and entity_type='LIBRARY';
 if not found then raise exception 'CATALOG_BASELINE_LIBRARY_MISSING' using errcode='22000';end if;
 v_payload:=v_row.payload;v_code:=v_payload->>'code';
 v_library_id:=private.catalog_baseline_uuid('catalog-library',v_code);v_version_id:=private.catalog_baseline_uuid('catalog-library-version',v_code||':1');
 perform pg_advisory_xact_lock(hashtextextended('catalog-import-materialize-library:'||v_code,0));
 if exists(select 1 from public.catalog_libraries where code=v_code or id=v_library_id) then raise exception 'CATALOG_BASELINE_TARGET_ALREADY_EXISTS' using errcode='22000';end if;
 update public.catalog_import_batches set status='IMPORTING',row_version=row_version+1 where id=p_batch_id;
 insert into public.catalog_libraries(id,code,slug,status,steward_organization_id,created_by)
 values(v_library_id,v_code,private.catalog_baseline_slug(v_code),'DRAFT',v_batch.steward_organization_id,v_actor);
 insert into public.catalog_library_versions(id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,change_reason,content_hash,sensitive,created_by,code,slug)
 values(v_version_id,v_library_id,1,'DRAFT',v_payload->>'name_fr',v_payload->>'name_fr',v_payload->>'description_fr',v_payload->>'description_fr','library-'||private.catalog_baseline_slug(v_code),(v_payload->>'order')::integer,'Import baseline Gold Master',v_row.row_hash,false,v_actor,v_code,private.catalog_baseline_slug(v_code));
 select content_hash into v_existing_hash from public.catalog_library_versions where id=v_version_id and library_id=v_library_id;if v_existing_hash is distinct from v_row.row_hash then raise exception 'CATALOG_BASELINE_VERSION_CONFLICT' using errcode='22000';end if;
 update public.catalog_libraries set current_draft_version_id=v_version_id where id=v_library_id and current_draft_version_id is null;

 for v_row in select * from public.catalog_import_rows where batch_id=p_batch_id and entity_type='CATEGORY' order by (payload->>'order')::integer,business_key loop
  v_payload:=v_row.payload;v_code:=v_row.business_key;v_id:=private.catalog_baseline_uuid('catalog-category',v_code);v_version_id:=private.catalog_baseline_uuid('catalog-category-version',v_code||':1');
  if exists(select 1 from public.catalog_categories where library_id=v_library_id and code=v_code and id<>v_id) then raise exception 'CATALOG_BASELINE_IDENTITY_CONFLICT' using errcode='23505';end if;
  insert into public.catalog_categories(id,library_id,code,slug,status,created_by) values(v_id,v_library_id,v_code,private.catalog_baseline_slug(v_code),'DRAFT',v_actor);
  insert into public.catalog_category_versions(id,category_id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,created_by,code,slug)
  values(v_version_id,v_id,v_library_id,1,'DRAFT',v_payload->>'name_fr',v_payload->>'name_fr',v_payload->>'description_fr',v_payload->>'description_fr',(v_payload->>'order')::integer,'Import baseline Gold Master',v_row.row_hash,v_actor,v_code,private.catalog_baseline_slug(v_code));
  select content_hash into v_existing_hash from public.catalog_category_versions where id=v_version_id and category_id=v_id;if v_existing_hash is distinct from v_row.row_hash then raise exception 'CATALOG_BASELINE_VERSION_CONFLICT' using errcode='22000';end if;
  update public.catalog_categories set current_draft_version_id=v_version_id where id=v_id and current_draft_version_id is null;
 end loop;

 for v_row in select * from public.catalog_import_rows where batch_id=p_batch_id and entity_type='SUBCATEGORY' order by (payload->>'order')::integer,business_key loop
  v_payload:=v_row.payload;v_code:=v_row.business_key;v_id:=private.catalog_baseline_uuid('catalog-subcategory',v_code);v_version_id:=private.catalog_baseline_uuid('catalog-subcategory-version',v_code||':1');v_parent_id:=private.catalog_baseline_uuid('catalog-category',v_payload->>'macro_category_code');
  if exists(select 1 from public.catalog_subcategories where library_id=v_library_id and code=v_code and id<>v_id) then raise exception 'CATALOG_BASELINE_IDENTITY_CONFLICT' using errcode='23505';end if;
  insert into public.catalog_subcategories(id,library_id,category_id,code,slug,status,created_by) values(v_id,v_library_id,v_parent_id,v_code,private.catalog_baseline_slug(v_code),'DRAFT',v_actor);
  insert into public.catalog_subcategory_versions(id,subcategory_id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,created_by,category_id,code,slug)
  values(v_version_id,v_id,v_library_id,1,'DRAFT',v_payload->>'name_fr',v_payload->>'name_fr',v_payload->>'description_fr',v_payload->>'description_fr',(v_payload->>'order')::integer,'Import baseline Gold Master',v_row.row_hash,v_actor,v_parent_id,v_code,private.catalog_baseline_slug(v_code));
  select content_hash into v_existing_hash from public.catalog_subcategory_versions where id=v_version_id and subcategory_id=v_id;if v_existing_hash is distinct from v_row.row_hash then raise exception 'CATALOG_BASELINE_VERSION_CONFLICT' using errcode='22000';end if;
  update public.catalog_subcategories set current_draft_version_id=v_version_id where id=v_id and current_draft_version_id is null;
 end loop;

 for v_row in select * from public.catalog_import_rows where batch_id=p_batch_id and entity_type='SERVICE' order by (payload->>'order')::integer,business_key loop
  v_payload:=v_row.payload;v_code:=v_row.business_key;v_id:=private.catalog_baseline_uuid('catalog-service',v_code);v_version_id:=private.catalog_baseline_uuid('catalog-service-version',v_code||':1');v_parent_id:=private.catalog_baseline_uuid('catalog-subcategory',v_payload->>'subcategory_code');
  if exists(select 1 from public.catalog_services where code=v_code and id<>v_id) then raise exception 'CATALOG_BASELINE_IDENTITY_CONFLICT' using errcode='23505';end if;
  insert into public.catalog_services(id,library_id,primary_subcategory_id,code,slug,status,created_by) values(v_id,v_library_id,v_parent_id,v_code,private.catalog_baseline_slug(v_code),'DRAFT',v_actor);
  insert into public.catalog_service_versions(id,service_id,library_id,version,status,name_fr,name_ar,short_description_fr,short_description_ar,long_description_fr,long_description_ar,service_type,unit_label_fr,unit_label_ar,credit_eligible,volume_eligible,recurring_eligible,sort_order,fulfillment_config,change_reason,content_hash,sensitive,created_by,primary_subcategory_id,code,slug)
  values(v_version_id,v_id,v_library_id,1,'DRAFT',v_payload->>'name_fr',v_payload->>'name_fr',v_payload->>'description_fr',v_payload->>'description_fr',v_payload->>'description_fr',v_payload->>'description_fr',v_payload->>'service_type',v_payload->>'unit_label_fr',v_payload->>'unit_label_fr',coalesce((v_payload->>'credit_eligible')::boolean,false),coalesce((v_payload->>'volume_eligible')::boolean,false),coalesce((v_payload->>'recurring_eligible')::boolean,false),(v_payload->>'order')::integer,jsonb_build_object('standard_deliverables_fr',v_payload->>'standard_deliverables_fr','standard_proof_fr',v_payload->>'standard_proof_fr'),'Import baseline Gold Master',v_row.row_hash,jsonb_array_length(coalesce(v_payload->'central_approval_flags','[]'::jsonb))>0,v_actor,v_parent_id,v_code,private.catalog_baseline_slug(v_code));
  select content_hash into v_existing_hash from public.catalog_service_versions where id=v_version_id and service_id=v_id;if v_existing_hash is distinct from v_row.row_hash then raise exception 'CATALOG_BASELINE_VERSION_CONFLICT' using errcode='22000';end if;
  update public.catalog_services set current_draft_version_id=v_version_id where id=v_id and current_draft_version_id is null;
 end loop;

 for v_row in select * from public.catalog_import_rows where batch_id=p_batch_id and entity_type='SERVICE_SUBCATEGORY_LINK' order by business_key loop
  v_payload:=v_row.payload;v_service_id:=private.catalog_baseline_uuid('catalog-service',v_payload->>'service_code');v_subcategory_id:=private.catalog_baseline_uuid('catalog-subcategory',v_payload->>'subcategory_code');
  v_id:=private.catalog_baseline_uuid('catalog-link',(v_payload->>'service_code')||':'||(v_payload->>'subcategory_code'));v_version_id:=private.catalog_baseline_uuid('catalog-link-version',(v_payload->>'service_code')||':'||(v_payload->>'subcategory_code')||':1');
  insert into public.catalog_service_subcategory_links(id,service_id,subcategory_id,library_id,link_type,status,created_by) values(v_id,v_service_id,v_subcategory_id,v_library_id,v_payload->>'link_type','DRAFT',v_actor);
  insert into public.catalog_service_subcategory_link_versions(id,link_id,library_id,version,status,change_reason,content_hash,created_by,service_id,subcategory_id,link_type)
  values(v_version_id,v_id,v_library_id,1,'DRAFT','Import baseline Gold Master',v_row.row_hash,v_actor,v_service_id,v_subcategory_id,v_payload->>'link_type');
  select content_hash into v_existing_hash from public.catalog_service_subcategory_link_versions where id=v_version_id and link_id=v_id;if v_existing_hash is distinct from v_row.row_hash then raise exception 'CATALOG_BASELINE_VERSION_CONFLICT' using errcode='22000';end if;
  update public.catalog_service_subcategory_links set current_version_id=v_version_id where id=v_id and current_version_id is null;
 end loop;

 v_release_id:=private.catalog_baseline_uuid('catalog-release',v_batch.baseline_key);
 insert into public.catalog_releases(id,library_id,release_key,status,source_bundle_hash,requires_central_approval,created_by)
 values(v_release_id,v_library_id,upper(replace(v_batch.baseline_key,':','_')),'DRAFT',v_batch.bundle_hash,true,v_actor);
 if not exists(select 1 from public.catalog_releases where id=v_release_id and library_id=v_library_id and release_key=upper(replace(v_batch.baseline_key,':','_')) and source_bundle_hash=v_batch.bundle_hash and status='DRAFT' and snapshot_hash is null and based_on_release_id is null and rollback_target_release_id is null and requires_central_approval and created_by=v_actor and approved_by is null and published_by is null and audience='{"kind":"PUBLIC"}'::jsonb and effective_until is null and lease_token is null and last_lease_token is null and lease_worker_id is null and leased_until is null and next_attempt_at is null and terminal_at is null and publish_attempts=0 and last_error_code is null and approved_at is null and published_at is null and retired_at is null and row_version=1) then raise exception 'CATALOG_BASELINE_RELEASE_CONFLICT' using errcode='22000';end if;
 v_sort:=0;
 for v_row in select * from public.catalog_import_rows where batch_id=p_batch_id and entity_type<>'QUESTION' order by case entity_type when 'LIBRARY'then 1 when 'CATEGORY'then 2 when 'SUBCATEGORY'then 3 when 'SERVICE'then 4 else 5 end,(payload->>'order')::integer nulls last,business_key loop
  v_sort:=v_sort+1;v_payload:=v_row.payload;
  if v_row.entity_type='LIBRARY' then v_id:=v_library_id;v_version_id:=private.catalog_baseline_uuid('catalog-library-version',v_row.business_key||':1');
  elsif v_row.entity_type='CATEGORY' then v_id:=private.catalog_baseline_uuid('catalog-category',v_row.business_key);v_version_id:=private.catalog_baseline_uuid('catalog-category-version',v_row.business_key||':1');
  elsif v_row.entity_type='SUBCATEGORY' then v_id:=private.catalog_baseline_uuid('catalog-subcategory',v_row.business_key);v_version_id:=private.catalog_baseline_uuid('catalog-subcategory-version',v_row.business_key||':1');
  elsif v_row.entity_type='SERVICE' then v_id:=private.catalog_baseline_uuid('catalog-service',v_row.business_key);v_version_id:=private.catalog_baseline_uuid('catalog-service-version',v_row.business_key||':1');
  else v_id:=private.catalog_baseline_uuid('catalog-link',(v_payload->>'service_code')||':'||(v_payload->>'subcategory_code'));v_version_id:=private.catalog_baseline_uuid('catalog-link-version',(v_payload->>'service_code')||':'||(v_payload->>'subcategory_code')||':1');end if;
  insert into public.catalog_release_items(release_id,library_id,object_type,object_id,version_id,content_hash,sort_order) values(v_release_id,v_library_id,v_row.entity_type,v_id,v_version_id,v_row.row_hash,v_sort);
 end loop;

 for v_row in select distinct payload->>'phase' phase,case when payload->>'phase'='RFQ' then payload->>'service_code' else null end service_code from public.catalog_import_rows where batch_id=p_batch_id and entity_type='QUESTION' order by phase,service_code nulls first loop
  v_phase:=v_row.phase;v_qcode:=case when v_phase='RFQ' then 'RFQ_'||v_row.service_code when v_phase='DIAGNOSTIC' then 'DIAGNOSTIC_'||v_batch.library_code else 'PROVIDER_'||v_batch.library_code end;
  v_questionnaire_id:=private.catalog_baseline_uuid('questionnaire',v_batch.library_code||':'||v_qcode);v_questionnaire_version_id:=private.catalog_baseline_uuid('questionnaire-version',v_batch.library_code||':'||v_qcode||':1');
  select encode(digest(convert_to(coalesce(jsonb_agg(q.row_hash order by (q.payload->>'order')::integer,q.business_key)::text,'[]'),'UTF8'),'sha256'),'hex') into v_snapshot from public.catalog_import_rows q where q.batch_id=p_batch_id and q.entity_type='QUESTION' and q.payload->>'phase'=v_phase and (v_phase<>'RFQ' or q.payload->>'service_code'=v_row.service_code);
  insert into public.questionnaires(id,library_id,code,status,created_by) values(v_questionnaire_id,v_library_id,v_qcode,'DRAFT',v_actor);
  insert into public.questionnaire_versions(id,questionnaire_id,library_id,catalog_release_id,version,status,title_fr,title_ar,description_fr,description_ar,audience,engine_version,policy_version,snapshot_hash,change_reason,created_by)
  values(v_questionnaire_version_id,v_questionnaire_id,v_library_id,v_release_id,1,'DRAFT',replace(v_qcode,'_',' '),replace(v_qcode,'_',' '),'Questionnaire baseline Gold Master','Questionnaire baseline Gold Master',case when v_phase='PROVIDER_QUALIFICATION'then 'PROVIDER' else 'CLIENT'end,'1.0.0','1.0.0',v_snapshot,'Import baseline Gold Master',v_actor);
  select snapshot_hash into v_existing_hash from public.questionnaire_versions where id=v_questionnaire_version_id and questionnaire_id=v_questionnaire_id;if v_existing_hash is distinct from v_snapshot then raise exception 'CATALOG_BASELINE_QUESTIONNAIRE_CONFLICT' using errcode='22000';end if;
  update public.questionnaires set current_draft_version_id=v_questionnaire_version_id where id=v_questionnaire_id and current_draft_version_id is null;
  v_sort:=0;
  for v_child in select payload->>'section' section,min((payload->>'order')::integer) first_order from public.catalog_import_rows where batch_id=p_batch_id and entity_type='QUESTION' and payload->>'phase'=v_phase and (v_phase<>'RFQ' or payload->>'service_code'=v_row.service_code) group by payload->>'section' order by first_order,section loop
   v_sort:=v_sort+1;v_section:=v_child.section;v_section_id:=private.catalog_baseline_uuid('questionnaire-section',v_questionnaire_version_id::text||':'||v_section);
   insert into public.questionnaire_sections(id,questionnaire_version_id,section_key,label_fr,label_ar,sort_order,content_hash)
   values(v_section_id,v_questionnaire_version_id,'SECTION_'||upper(substr(encode(digest(convert_to(v_section,'UTF8'),'sha256'),'hex'),1,16)),v_section,v_section,v_sort,encode(digest(convert_to(to_jsonb(v_section)::text,'UTF8'),'sha256'),'hex'));
  end loop;
  for v_child in select * from public.catalog_import_rows where batch_id=p_batch_id and entity_type='QUESTION' and payload->>'phase'=v_phase and (v_phase<>'RFQ' or payload->>'service_code'=v_row.service_code) order by (payload->>'order')::integer,business_key loop
   v_payload:=v_child.payload;v_question_id:=private.catalog_baseline_uuid('question',v_child.business_key);v_question_version_id:=private.catalog_baseline_uuid('question-version',v_child.business_key||':1');v_section_id:=private.catalog_baseline_uuid('questionnaire-section',v_questionnaire_version_id::text||':'||(v_payload->>'section'));
   insert into public.question_bank_questions(id,library_id,question_key,scope,status,created_by) values(v_question_id,v_library_id,v_child.business_key,case when v_phase='RFQ'then 'SERVICE'else 'LIBRARY'end,'DRAFT',v_actor);
   insert into public.question_versions(id,question_id,library_id,version,status,label_fr,label_ar,help_fr,help_ar,answer_type,data_key,required_by_default,required_for_quote,options,validation_schema,structured_schema,visibility_rule,sensitivity,nullable,weight,maximum_score,template_key,content_hash,change_reason,created_by,source_phase,source_service_id,source_import_batch_id,source_file,source_line_number,source_row_hash)
   values(v_question_version_id,v_question_id,v_library_id,1,'DRAFT',v_payload->>'label_fr',v_payload->>'label_fr',nullif(v_payload->>'help_fr',''),nullif(v_payload->>'help_fr',''),v_payload->>'answer_type',v_payload->>'data_key',(v_payload->>'required')::boolean,(v_payload->>'required_for_quote')::boolean,v_payload->'options',v_payload->'validation_schema',case when v_payload->>'answer_type'in('TABLE','REPEATER')then v_payload->'validation_schema'else null end,case when v_payload->'condition'='{}'::jsonb then null else v_payload->'condition'end,v_payload->>'sensitivity',false,(v_payload->>'weight')::numeric,(v_payload->>'max_score')::numeric,nullif(v_payload->>'template_key',''),v_child.row_hash,'Import baseline Gold Master',v_actor,v_phase,case when v_phase='RFQ'then private.catalog_baseline_uuid('catalog-service',v_payload->>'service_code')else null end,p_batch_id,v_child.source_file,v_child.line_number,v_child.row_hash);
   select content_hash into v_existing_hash from public.question_versions where id=v_question_version_id and question_id=v_question_id;if v_existing_hash is distinct from v_child.row_hash then raise exception 'CATALOG_BASELINE_QUESTION_CONFLICT' using errcode='22000';end if;
   update public.question_bank_questions set current_draft_version_id=v_question_version_id where id=v_question_id and current_draft_version_id is null;
   insert into public.questionnaire_version_questions(questionnaire_version_id,library_id,section_id,question_version_id,sort_order,required_override) values(v_questionnaire_version_id,v_library_id,v_section_id,v_question_version_id,(v_payload->>'order')::integer,null);
  end loop;
 end loop;

 if not exists(select 1 from public.catalog_import_rows r join public.catalog_libraries i on i.id=private.catalog_baseline_uuid('catalog-library',r.business_key) join public.catalog_library_versions v on v.id=private.catalog_baseline_uuid('catalog-library-version',r.business_key||':1') and v.library_id=i.id where r.batch_id=p_batch_id and r.entity_type='LIBRARY' and i.id=v_library_id and i.code=r.business_key and i.slug=private.catalog_baseline_slug(r.business_key) and i.status='DRAFT' and i.steward_organization_id=v_batch.steward_organization_id and i.current_draft_version_id=v.id and v.version=1 and v.status='DRAFT' and v.code=r.business_key and v.slug=private.catalog_baseline_slug(r.business_key) and v.name_fr=r.payload->>'name_fr' and v.name_ar=r.payload->>'name_fr' and v.description_fr=r.payload->>'description_fr' and v.description_ar=r.payload->>'description_fr' and v.icon_key='library-'||private.catalog_baseline_slug(r.business_key) and v.sort_order=(r.payload->>'order')::integer and not v.sensitive and v.content_hash=r.row_hash and v.translation_review_status='PENDING') then
  raise exception 'CATALOG_BASELINE_LIBRARY_MISMATCH' using errcode='22000';
 end if;
 if exists(select 1 from public.catalog_import_rows r left join public.catalog_categories i on i.id=private.catalog_baseline_uuid('catalog-category',r.business_key) left join public.catalog_category_versions v on v.id=private.catalog_baseline_uuid('catalog-category-version',r.business_key||':1') where r.batch_id=p_batch_id and r.entity_type='CATEGORY' and (i.id is null or i.library_id is distinct from v_library_id or i.code is distinct from r.business_key or i.slug is distinct from private.catalog_baseline_slug(r.business_key) or i.status is distinct from 'DRAFT' or i.current_draft_version_id is distinct from v.id or v.category_id is distinct from i.id or v.library_id is distinct from v_library_id or v.version is distinct from 1 or v.status is distinct from 'DRAFT' or v.code is distinct from r.business_key or v.slug is distinct from private.catalog_baseline_slug(r.business_key) or v.name_fr is distinct from r.payload->>'name_fr' or v.name_ar is distinct from r.payload->>'name_fr' or v.description_fr is distinct from r.payload->>'description_fr' or v.description_ar is distinct from r.payload->>'description_fr' or v.icon_key is not null or v.visibility_rules is distinct from '{}'::jsonb or v.sensitive or v.sort_order is distinct from (r.payload->>'order')::integer or v.content_hash is distinct from r.row_hash or v.translation_review_status is distinct from 'PENDING')) then raise exception 'CATALOG_BASELINE_CATEGORY_MISMATCH' using errcode='22000';end if;
 if exists(select 1 from public.catalog_import_rows r left join public.catalog_subcategories i on i.id=private.catalog_baseline_uuid('catalog-subcategory',r.business_key) left join public.catalog_subcategory_versions v on v.id=private.catalog_baseline_uuid('catalog-subcategory-version',r.business_key||':1') where r.batch_id=p_batch_id and r.entity_type='SUBCATEGORY' and (i.id is null or i.library_id is distinct from v_library_id or i.category_id is distinct from private.catalog_baseline_uuid('catalog-category',r.payload->>'macro_category_code') or i.code is distinct from r.business_key or i.slug is distinct from private.catalog_baseline_slug(r.business_key) or i.status is distinct from 'DRAFT' or i.current_draft_version_id is distinct from v.id or v.subcategory_id is distinct from i.id or v.library_id is distinct from v_library_id or v.category_id is distinct from i.category_id or v.version is distinct from 1 or v.status is distinct from 'DRAFT' or v.code is distinct from r.business_key or v.slug is distinct from private.catalog_baseline_slug(r.business_key) or v.name_fr is distinct from r.payload->>'name_fr' or v.name_ar is distinct from r.payload->>'name_fr' or v.description_fr is distinct from r.payload->>'description_fr' or v.description_ar is distinct from r.payload->>'description_fr' or v.icon_key is not null or v.visibility_rules is distinct from '{}'::jsonb or v.sensitive or v.sort_order is distinct from (r.payload->>'order')::integer or v.content_hash is distinct from r.row_hash or v.translation_review_status is distinct from 'PENDING')) then raise exception 'CATALOG_BASELINE_SUBCATEGORY_MISMATCH' using errcode='22000';end if;
 if exists(select 1 from public.catalog_import_rows r left join public.catalog_services i on i.id=private.catalog_baseline_uuid('catalog-service',r.business_key) left join public.catalog_service_versions v on v.id=private.catalog_baseline_uuid('catalog-service-version',r.business_key||':1') where r.batch_id=p_batch_id and r.entity_type='SERVICE' and (i.id is null or i.library_id is distinct from v_library_id or i.primary_subcategory_id is distinct from private.catalog_baseline_uuid('catalog-subcategory',r.payload->>'subcategory_code') or i.code is distinct from r.business_key or i.slug is distinct from private.catalog_baseline_slug(r.business_key) or i.status is distinct from 'DRAFT' or i.current_draft_version_id is distinct from v.id or v.service_id is distinct from i.id or v.library_id is distinct from v_library_id or v.primary_subcategory_id is distinct from i.primary_subcategory_id or v.version is distinct from 1 or v.status is distinct from 'DRAFT' or v.code is distinct from r.business_key or v.slug is distinct from private.catalog_baseline_slug(r.business_key) or v.name_fr is distinct from r.payload->>'name_fr' or v.name_ar is distinct from r.payload->>'name_fr' or v.short_description_fr is distinct from r.payload->>'description_fr' or v.short_description_ar is distinct from r.payload->>'description_fr' or v.long_description_fr is distinct from r.payload->>'description_fr' or v.long_description_ar is distinct from r.payload->>'description_fr' or v.service_type is distinct from r.payload->>'service_type' or v.unit_label_fr is distinct from r.payload->>'unit_label_fr' or v.unit_label_ar is distinct from r.payload->>'unit_label_fr' or v.credit_eligible is distinct from (r.payload->>'credit_eligible')::boolean or v.volume_eligible is distinct from (r.payload->>'volume_eligible')::boolean or v.recurring_eligible is distinct from (r.payload->>'recurring_eligible')::boolean or v.fulfillment_config is distinct from jsonb_build_object('standard_deliverables_fr',r.payload->>'standard_deliverables_fr','standard_proof_fr',r.payload->>'standard_proof_fr') or v.sensitive is distinct from (jsonb_array_length(r.payload->'central_approval_flags')>0) or v.sort_order is distinct from (r.payload->>'order')::integer or v.content_hash is distinct from r.row_hash or v.translation_review_status is distinct from 'PENDING')) then raise exception 'CATALOG_BASELINE_SERVICE_MISMATCH' using errcode='22000';end if;
 if exists(select 1 from public.catalog_import_rows r left join public.catalog_service_subcategory_links i on i.id=private.catalog_baseline_uuid('catalog-link',(r.payload->>'service_code')||':'||(r.payload->>'subcategory_code')) left join public.catalog_service_subcategory_link_versions v on v.id=private.catalog_baseline_uuid('catalog-link-version',(r.payload->>'service_code')||':'||(r.payload->>'subcategory_code')||':1') where r.batch_id=p_batch_id and r.entity_type='SERVICE_SUBCATEGORY_LINK' and (i.id is null or i.library_id is distinct from v_library_id or i.service_id is distinct from private.catalog_baseline_uuid('catalog-service',r.payload->>'service_code') or i.subcategory_id is distinct from private.catalog_baseline_uuid('catalog-subcategory',r.payload->>'subcategory_code') or i.link_type is distinct from r.payload->>'link_type' or i.status is distinct from 'DRAFT' or i.current_version_id is distinct from v.id or v.link_id is distinct from i.id or v.library_id is distinct from v_library_id or v.service_id is distinct from i.service_id or v.subcategory_id is distinct from i.subcategory_id or v.link_type is distinct from i.link_type or v.version is distinct from 1 or v.status is distinct from 'DRAFT' or v.content_hash is distinct from r.row_hash)) then raise exception 'CATALOG_BASELINE_LINK_MISMATCH' using errcode='22000';end if;
 if exists(with expected as(select r.*,row_number()over(order by case entity_type when 'LIBRARY'then 1 when 'CATEGORY'then 2 when 'SUBCATEGORY'then 3 when 'SERVICE'then 4 else 5 end,(payload->>'order')::integer nulls last,business_key)::integer expected_sort from public.catalog_import_rows r where batch_id=p_batch_id and entity_type<>'QUESTION') select 1 from expected r full join (select * from public.catalog_release_items where release_id=v_release_id) i on i.object_type=r.entity_type and i.object_id=case r.entity_type when 'LIBRARY'then private.catalog_baseline_uuid('catalog-library',r.business_key) when 'CATEGORY'then private.catalog_baseline_uuid('catalog-category',r.business_key) when 'SUBCATEGORY'then private.catalog_baseline_uuid('catalog-subcategory',r.business_key) when 'SERVICE'then private.catalog_baseline_uuid('catalog-service',r.business_key) else private.catalog_baseline_uuid('catalog-link',(r.payload->>'service_code')||':'||(r.payload->>'subcategory_code')) end where r.id is null or i.release_id is null or i.library_id is distinct from v_library_id or i.version_id is distinct from case r.entity_type when 'LIBRARY'then private.catalog_baseline_uuid('catalog-library-version',r.business_key||':1') when 'CATEGORY'then private.catalog_baseline_uuid('catalog-category-version',r.business_key||':1') when 'SUBCATEGORY'then private.catalog_baseline_uuid('catalog-subcategory-version',r.business_key||':1') when 'SERVICE'then private.catalog_baseline_uuid('catalog-service-version',r.business_key||':1') else private.catalog_baseline_uuid('catalog-link-version',(r.payload->>'service_code')||':'||(r.payload->>'subcategory_code')||':1') end or i.content_hash is distinct from r.row_hash or i.sort_order is distinct from r.expected_sort) then raise exception 'CATALOG_BASELINE_RELEASE_ITEMS_MISMATCH' using errcode='22000';end if;
 if exists(select 1 from public.catalog_import_rows r left join public.question_bank_questions q on q.id=private.catalog_baseline_uuid('question',r.business_key) left join public.question_versions v on v.id=private.catalog_baseline_uuid('question-version',r.business_key||':1') where r.batch_id=p_batch_id and r.entity_type='QUESTION' and (q.id is null or q.library_id is distinct from v_library_id or q.question_key is distinct from r.business_key or q.scope is distinct from case when r.payload->>'phase'='RFQ'then 'SERVICE'else 'LIBRARY'end or q.source_question_id is not null or q.status is distinct from 'DRAFT' or q.current_draft_version_id is distinct from v.id or q.current_published_version_id is not null or q.created_by is distinct from v_actor or q.archived_at is not null or q.row_version<>1 or v.question_id is distinct from q.id or v.library_id is distinct from v_library_id or v.version is distinct from 1 or v.status is distinct from 'DRAFT' or v.translation_review_status is distinct from 'PENDING' or v.translation_reviewer_user_id is not null or v.translation_reviewed_at is not null or v.translation_review_proof_hash is not null or v.translation_review_version<>0 or v.label_fr is distinct from r.payload->>'label_fr' or v.label_ar is distinct from r.payload->>'label_fr' or v.help_fr is distinct from nullif(r.payload->>'help_fr','') or v.help_ar is distinct from nullif(r.payload->>'help_fr','') or v.why_we_ask_fr is not null or v.why_we_ask_ar is not null or v.answer_type is distinct from r.payload->>'answer_type' or v.data_key is distinct from r.payload->>'data_key' or v.required_by_default is distinct from (r.payload->>'required')::boolean or v.required_for_quote is distinct from (r.payload->>'required_for_quote')::boolean or v.required_for_publication or v.options is distinct from r.payload->'options' or v.validation_schema is distinct from r.payload->'validation_schema' or v.structured_schema is distinct from case when r.payload->>'answer_type'in('TABLE','REPEATER')then r.payload->'validation_schema'else null end or v.visibility_rule is not null or v.default_value is not null or v.prefill_source is not null or v.sensitivity is distinct from r.payload->>'sensitivity' or v.nullable or v.weight is distinct from (r.payload->>'weight')::numeric or v.maximum_score is distinct from (r.payload->>'max_score')::numeric or v.template_key is distinct from nullif(r.payload->>'template_key','') or v.validity_interval is not null or v.content_hash is distinct from r.row_hash or v.change_reason<>'Import baseline Gold Master' or v.created_by is distinct from v_actor or v.published_at is not null or v.superseded_at is not null or v.row_version<>1 or v.source_phase is distinct from r.payload->>'phase' or v.source_service_id is distinct from case when r.payload->>'phase'='RFQ'then private.catalog_baseline_uuid('catalog-service',r.payload->>'service_code')else null end or v.source_import_batch_id is distinct from p_batch_id or v.source_file is distinct from r.source_file or v.source_line_number is distinct from r.line_number or v.source_row_hash is distinct from r.row_hash)) then raise exception 'CATALOG_BASELINE_QUESTION_MISMATCH' using errcode='22000';end if;
 if exists(with base as(select q.payload->>'phase' phase,case when q.payload->>'phase'='RFQ'then q.payload->>'service_code'else null end service_code,q.payload,q.business_key,q.row_hash from public.catalog_import_rows q where q.batch_id=p_batch_id and q.entity_type='QUESTION'),expected as(select phase,service_code,case when phase='RFQ'then 'RFQ_'||service_code when phase='DIAGNOSTIC'then 'DIAGNOSTIC_'||v_batch.library_code else 'PROVIDER_'||v_batch.library_code end qcode,encode(digest(convert_to(jsonb_agg(row_hash order by (payload->>'order')::integer,business_key)::text,'UTF8'),'sha256'),'hex') snapshot from base group by phase,service_code),resolved as(select e.*,private.catalog_baseline_uuid('questionnaire',v_batch.library_code||':'||e.qcode) qid,private.catalog_baseline_uuid('questionnaire-version',v_batch.library_code||':'||e.qcode||':1') qvid from expected e) select 1 from resolved e left join public.questionnaires q on q.id=e.qid left join public.questionnaire_versions v on v.id=e.qvid where q.id is null or q.library_id is distinct from v_library_id or q.code is distinct from e.qcode or q.status is distinct from 'DRAFT' or q.current_draft_version_id is distinct from e.qvid or q.current_published_version_id is not null or q.created_by is distinct from v_actor or q.archived_at is not null or q.row_version<>1 or v.questionnaire_id is distinct from e.qid or v.library_id is distinct from v_library_id or v.catalog_release_id is distinct from v_release_id or v.version is distinct from 1 or v.status is distinct from 'DRAFT' or v.title_fr is distinct from replace(e.qcode,'_',' ') or v.title_ar is distinct from replace(e.qcode,'_',' ') or v.description_fr<>'Questionnaire baseline Gold Master' or v.description_ar<>'Questionnaire baseline Gold Master' or v.audience is distinct from case when e.phase='PROVIDER_QUALIFICATION'then 'PROVIDER'else 'CLIENT'end or v.engine_version<>'1.0.0' or v.policy_version<>'1.0.0' or v.snapshot_hash is distinct from e.snapshot or v.sensitive or v.translation_review_status is distinct from 'PENDING' or v.translation_reviewer_user_id is not null or v.translation_reviewed_at is not null or v.translation_review_proof_hash is not null or v.translation_review_version<>0 or v.change_reason<>'Import baseline Gold Master' or v.created_by is distinct from v_actor or v.published_at is not null or v.superseded_at is not null or v.row_version<>1) then raise exception 'CATALOG_BASELINE_QUESTIONNAIRE_PAYLOAD_MISMATCH' using errcode='22000';end if;
 if exists(with grouped as(select payload->>'phase' phase,case when payload->>'phase'='RFQ'then payload->>'service_code'else null end service_code,payload->>'section' section,min((payload->>'order')::integer) first_order from public.catalog_import_rows where batch_id=p_batch_id and entity_type='QUESTION' group by payload->>'phase',case when payload->>'phase'='RFQ'then payload->>'service_code'else null end,payload->>'section'),expected as(select g.*,case when phase='RFQ'then 'RFQ_'||service_code when phase='DIAGNOSTIC'then 'DIAGNOSTIC_'||v_batch.library_code else 'PROVIDER_'||v_batch.library_code end qcode,row_number()over(partition by phase,service_code order by first_order,section)::integer sort_order from grouped g),resolved as(select e.*,private.catalog_baseline_uuid('questionnaire-version',v_batch.library_code||':'||qcode||':1') qvid from expected e) select 1 from resolved e left join public.questionnaire_sections s on s.id=private.catalog_baseline_uuid('questionnaire-section',e.qvid::text||':'||e.section) where s.id is null or s.questionnaire_version_id is distinct from e.qvid or s.label_fr is distinct from e.section or s.label_ar is distinct from e.section or s.sort_order is distinct from e.sort_order or s.content_hash is distinct from encode(digest(convert_to(to_jsonb(e.section)::text,'UTF8'),'sha256'),'hex')) then raise exception 'CATALOG_BASELINE_SECTION_MISMATCH' using errcode='22000';end if;
 if exists(select 1 from public.catalog_import_rows r left join public.questionnaire_version_questions x on x.questionnaire_version_id=private.catalog_baseline_uuid('questionnaire-version',v_batch.library_code||':'||(case when r.payload->>'phase'='RFQ'then 'RFQ_'||(r.payload->>'service_code') when r.payload->>'phase'='DIAGNOSTIC'then 'DIAGNOSTIC_'||v_batch.library_code else 'PROVIDER_'||v_batch.library_code end)||':1') and x.question_version_id=private.catalog_baseline_uuid('question-version',r.business_key||':1') where r.batch_id=p_batch_id and r.entity_type='QUESTION' and (x.questionnaire_version_id is null or x.library_id is distinct from v_library_id or x.section_id is distinct from private.catalog_baseline_uuid('questionnaire-section',x.questionnaire_version_id::text||':'||(r.payload->>'section')) or x.sort_order is distinct from (r.payload->>'order')::integer or x.required_override is not null)) then raise exception 'CATALOG_BASELINE_QUESTION_LINK_MISMATCH' using errcode='22000';end if;
 if (select count(*) from public.questionnaire_version_questions x join public.questionnaire_versions v on v.id=x.questionnaire_version_id where v.catalog_release_id=v_release_id) is distinct from (v_batch.expected_counts->>'total_questions')::bigint or exists(select 1 from public.questionnaire_versions v where v.catalog_release_id=v_release_id and (v.library_id is distinct from v_library_id or v.status is distinct from 'DRAFT' or v.translation_review_status is distinct from 'PENDING')) then raise exception 'CATALOG_BASELINE_QUESTIONNAIRE_MISMATCH' using errcode='22000';end if;

 update public.catalog_import_rows set validation_status='IMPORTED' where batch_id=p_batch_id;
 v_command:=extensions.gen_random_uuid();
 update public.catalog_import_batches set status='IMPORTED',library_id=v_library_id,candidate_release_id=v_release_id,imported_at=clock_timestamp(),
  import_report=coalesce(import_report,'{}'::jsonb)||jsonb_build_object('candidate_release_id',v_release_id,'translation_status','PENDING','published',false),row_version=row_version+2 where id=p_batch_id returning * into v_batch;
 v_response:=jsonb_build_object('outcome','CATALOG_IMPORT_COMMITTED','batch_id',p_batch_id,'library_id',v_library_id,'candidate_release_id',v_release_id,'status','IMPORTED','translation_status','PENDING','published',false,'actual_counts',v_batch.actual_counts,'row_version',v_batch.row_version,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_batch.steward_organization_id,v_actor,'USER','catalog.import.committed','catalog_import_batch',p_batch_id::text,p_correlation_id,jsonb_build_object('library_id',v_library_id,'candidate_release_id',v_release_id,'bundle_hash',v_batch.bundle_hash,'actual_counts',v_batch.actual_counts,'translation_status','PENDING','command_id',v_command),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id) values(v_batch.steward_organization_id,'catalog_import_batch',p_batch_id::text,'CatalogImportCommittedV1',p_correlation_id,jsonb_build_object('batch_id',p_batch_id,'library_id',v_library_id,'candidate_release_id',v_release_id,'bundle_hash',v_batch.bundle_hash,'actual_counts',v_batch.actual_counts,'translation_status','PENDING'),p_idempotency_key,v_command);
 insert into public.catalog_command_keys(actor_user_id,operation_scope,key,request_hash,response_body,completed_at) values(v_actor,'catalog.import.commit',p_idempotency_key,v_hash,v_response,clock_timestamp());return v_response;
end$$;

create function public.get_catalog_import_report(p_batch_id uuid) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog,private as $$
declare v_actor uuid:=private.assert_catalog_baseline_actor();v_result jsonb;
begin
 select jsonb_build_object('batch_id',b.id,'baseline_key',b.baseline_key,'bundle_hash',b.bundle_hash,'library_code',b.library_code,'status',b.status,'expected_counts',b.expected_counts,'actual_counts',b.actual_counts,'report',b.import_report,'candidate_release_id',b.candidate_release_id,'row_version',b.row_version,'sources',(select coalesce(jsonb_agg(jsonb_build_object('path',s.source_path,'sha256',s.sha256,'byte_size',s.byte_size,'data_rows',s.data_rows,'generator_version',s.generator_version)order by s.source_path),'[]'::jsonb)from public.catalog_source_files s where s.batch_id=b.id),'chunks',(select coalesce(jsonb_agg(jsonb_build_object('command_id',c.command_id,'source_file',c.source_file,'source_sha256',c.source_sha256,'entity_type',c.entity_type,'chunk_hash',c.chunk_hash,'row_count',c.row_count)order by c.created_at,c.command_id),'[]'::jsonb)from public.catalog_import_chunks c where c.batch_id=b.id),'errors',(select coalesce(jsonb_agg(jsonb_build_object('source_file',r.source_file,'line_number',r.line_number,'business_key',r.business_key,'error_code',e.error_code,'field_name',e.field_name,'public_message',e.public_message)order by coalesce(r.source_file,''),coalesce(r.line_number,0),e.error_code,e.id),'[]'::jsonb)from public.catalog_import_errors e left join public.catalog_import_rows r on r.id=e.import_row_id where e.batch_id=b.id)) into v_result from public.catalog_import_batches b where b.id=p_batch_id and b.created_by=v_actor;
 if v_result is null then raise exception 'CATALOG_IMPORT_NOT_FOUND' using errcode='P0002';end if;return v_result;
end$$;

revoke all on function public.commit_catalog_import(uuid,integer,text,uuid),public.get_catalog_import_report(uuid) from public,anon,authenticated,service_role;
grant execute on function public.commit_catalog_import(uuid,integer,text,uuid),public.get_catalog_import_report(uuid) to authenticated;
