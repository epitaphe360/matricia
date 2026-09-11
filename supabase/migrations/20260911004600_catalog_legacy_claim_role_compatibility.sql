-- Keep pre-hierarchy authenticated clients compatible when a pooled session still
-- carries a stale scalar role claim. The wrapper ACL remains the trust boundary;
-- modern command implementations and their authorization checks stay unchanged.

alter function public.decide_catalog_change(uuid,boolean,text,integer,text,uuid)
 rename to decide_catalog_change_legacy_core;

alter function public.revoke_catalog_library_mandate(uuid,integer,text,text,uuid)
 rename to revoke_catalog_library_mandate_core_v2;

revoke all on function
 public.decide_catalog_change_legacy_core(uuid,boolean,text,integer,text,uuid),
 public.revoke_catalog_library_mandate_core_v2(uuid,integer,text,text,uuid)
from public,anon,authenticated,service_role;

create function public.decide_catalog_change(
 p_change_request_id uuid,p_approved boolean,p_comment text,p_expected_row_version integer,
 p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare v_actor uuid:=auth.uid();
begin
 if v_actor is null or auth.jwt()->>'role' is distinct from 'authenticated'
    or auth.jwt()->>'aal' is distinct from 'aal2' then
  raise exception 'CENTRAL_MFA_REQUIRED' using errcode='42501';
 end if;
 perform set_config('request.jwt.claim.role','authenticated',true);
 return public.decide_catalog_change_legacy_core(
  p_change_request_id,p_approved,p_comment,p_expected_row_version,
  p_idempotency_key,p_correlation_id
 );
end$$;

create function public.revoke_catalog_library_mandate(
 p_mandate_id uuid,p_expected_row_version integer,p_reason text,p_idempotency_key text,
 p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare v_actor uuid:=auth.uid();
begin
 if v_actor is null or auth.jwt()->>'role' is distinct from 'authenticated'
    or auth.jwt()->>'aal' is distinct from 'aal2' then
  raise exception 'CATALOG_MANDATE_REVOKE_DENIED' using errcode='42501';
 end if;
 perform set_config('request.jwt.claim.role','authenticated',true);
 return public.revoke_catalog_library_mandate_core_v2(
  p_mandate_id,p_expected_row_version,p_reason,p_idempotency_key,p_correlation_id
 );
end$$;

revoke all on function
 public.decide_catalog_change(uuid,boolean,text,integer,text,uuid),
 public.revoke_catalog_library_mandate(uuid,integer,text,text,uuid)
from public,anon,service_role;
grant execute on function
 public.decide_catalog_change(uuid,boolean,text,integer,text,uuid),
 public.revoke_catalog_library_mandate(uuid,integer,text,text,uuid)
to authenticated;

notify pgrst,'reload schema';
