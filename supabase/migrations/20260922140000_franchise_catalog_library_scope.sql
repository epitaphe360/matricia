-- Allow mandated franchise operators to read their assigned catalog library
-- (draft + published scope) via existing has_catalog_library_scope helper used
-- by catalog_* SELECT policies. Without this, franchisee space loads FORBIDDEN
-- after resolving the franchise row because catalog_libraries is invisible.

create or replace function private.has_catalog_library_scope(
  p_library_id uuid,
  p_actor_id uuid default auth.uid()
) returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select private.has_library_permission(p_library_id, 'CATALOG_VIEW_DRAFT', p_actor_id)
      or private.franchise_mandated_library(p_library_id, p_actor_id);
$$;

revoke all on function private.has_catalog_library_scope(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function private.has_catalog_library_scope(uuid, uuid) to authenticated;
