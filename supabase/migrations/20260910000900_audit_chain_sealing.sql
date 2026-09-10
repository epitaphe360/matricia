create or replace function private.seal_audit_event()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_previous_hash text;
begin
  if new.organization_id is not null then
    perform 1 from public.organizations where id=new.organization_id for update;
    if not found then raise exception 'AUDIT_ORGANIZATION_NOT_FOUND' using errcode='23503'; end if;
    select event_hash into v_previous_hash
    from public.audit_events
    where organization_id=new.organization_id
    order by id desc limit 1;
  end if;
  new.previous_hash := v_previous_hash;
  new.event_hash := encode(extensions.digest(concat_ws('|',
    coalesce(v_previous_hash,''),coalesce(new.organization_id::text,''),coalesce(new.actor_user_id::text,''),
    new.actor_type,new.action,new.resource_type,coalesce(new.resource_id,''),new.correlation_id::text,new.metadata::text
  ),'sha256'),'hex');
  return new;
end;
$$;

revoke all on function private.seal_audit_event() from public, anon, authenticated;
create trigger audit_events_seal before insert on public.audit_events
for each row execute function private.seal_audit_event();
