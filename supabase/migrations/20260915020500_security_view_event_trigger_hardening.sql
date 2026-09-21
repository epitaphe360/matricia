-- Defense-in-depth for the tenant audit projection and the Supabase-managed
-- RLS event trigger. Additive and semantics-preserving.

create or replace function private.organization_audit_activity_rows()
returns table (
  organization_id uuid,
  id bigint,
  action text,
  resource_type text,
  resource_id text,
  correlation_id uuid,
  occurred_at timestamptz
)
language sql
stable
security definer
set search_path = pg_catalog, private, public
as $$
  select
    audit.organization_id,
    audit.id,
    audit.action,
    audit.resource_type,
    audit.resource_id,
    audit.correlation_id,
    audit.occurred_at
  from public.audit_events audit
  where audit.organization_id is not null
    and private.is_active_org_member(audit.organization_id)
$$;

revoke all on function private.organization_audit_activity_rows()
from public, anon, authenticated, service_role;
grant execute on function private.organization_audit_activity_rows()
to authenticated;

create or replace view public.organization_audit_activity
with (security_barrier = true, security_invoker = true)
as
select
  organization_id,
  id,
  action,
  resource_type,
  resource_id,
  correlation_id,
  occurred_at
from private.organization_audit_activity_rows();

revoke all on public.organization_audit_activity from public, anon, service_role;
grant select on public.organization_audit_activity to authenticated;

-- Event triggers execute as their owner and do not require callers to have
-- EXECUTE on the trigger function. Remove the inherited API-facing grants
-- without disabling or replacing the platform event trigger.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null
     and exists (
       select 1
       from pg_event_trigger event_trigger
       join pg_proc trigger_function on trigger_function.oid = event_trigger.evtfoid
       join pg_namespace function_schema on function_schema.oid = trigger_function.pronamespace
       where event_trigger.evtname = 'ensure_rls'
         and event_trigger.evtenabled <> 'D'
         and function_schema.nspname = 'public'
         and trigger_function.proname = 'rls_auto_enable'
         and pg_get_userbyid(trigger_function.proowner) = current_user
     )
  then
    execute
      'revoke execute on function public.rls_auto_enable() from public, anon, authenticated';
  end if;
end
$$;

notify pgrst, 'reload schema';
