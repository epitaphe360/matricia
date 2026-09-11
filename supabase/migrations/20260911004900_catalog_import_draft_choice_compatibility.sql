-- The signed baseline contains draft choice questions whose options are completed
-- later in Builder. Import may preserve them as DRAFT/PENDING; publication remains
-- responsible for rejecting an incomplete choice contract.

create or replace function private.suppress_catalog_import_library_scope_reference_error()
returns trigger language plpgsql security definer set search_path=pg_catalog as $$
begin
 if new.import_row_id is null then return new;end if;
 if new.error_code='MISSING_REFERENCE' and exists(
  select 1 from public.catalog_import_rows r where r.id=new.import_row_id and r.batch_id=new.batch_id
   and r.entity_type='QUESTION' and r.payload->>'phase' in('DIAGNOSTIC','PROVIDER_QUALIFICATION')
   and coalesce(r.payload->>'category_code','')='' and coalesce(r.payload->>'service_code','')=''
 ) then return null;end if;
 if new.error_code='QUESTION_SCHEMA_INVALID' and exists(
  select 1 from public.catalog_import_rows r where r.id=new.import_row_id and r.batch_id=new.batch_id
   and r.entity_type='QUESTION' and jsonb_typeof(r.payload->'options')='array'
   and jsonb_typeof(r.payload->'validation_schema')='object' and jsonb_typeof(r.payload->'condition')='object'
   and (
    (r.payload->>'answer_type' in('SINGLE_CHOICE','MULTIPLE_CHOICE') and jsonb_array_length(r.payload->'options')=0)
    or (r.payload->>'answer_type'='YES_NO' and not exists(
      select 1 from jsonb_array_elements_text(r.payload->'options') option(value)
      where option.value not in('YES','NO','PARTIAL','UNKNOWN')
    ))
   )
 ) then return null;end if;
 return new;
end$$;

revoke all on function private.suppress_catalog_import_library_scope_reference_error() from public,anon,authenticated,service_role;

