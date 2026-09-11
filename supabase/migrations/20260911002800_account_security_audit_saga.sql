-- Durable, idempotent audit saga around external Supabase Auth mutations.

create table private.account_security_change_operations (
  id uuid primary key,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  requested_action text not null,
  success_action text not null,
  resource_id text not null check (length(resource_id) between 1 and 160),
  status text not null default 'PENDING' check (status in ('PENDING','COMPLETED')),
  requested_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  check ((status = 'COMPLETED') = (completed_at is not null))
);
revoke all on private.account_security_change_operations
  from public, anon, authenticated, service_role;

create function public.begin_account_security_change(
  p_operation_id uuid,
  p_actor_user_id uuid,
  p_requested_action text,
  p_success_action text,
  p_resource_id text
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if auth.role() <> 'service_role' then raise exception 'FORBIDDEN' using errcode = '42501'; end if;
  if (p_requested_action, p_success_action) not in (
    ('identity.mfa.verification.requested','identity.mfa.enrolled'),
    ('identity.password.change.requested','identity.password.updated'),
    ('identity.mfa.unenrollment.requested','identity.mfa.unenrolled')
  ) then raise exception 'INVALID_SECURITY_CHANGE' using errcode = '22023'; end if;
  insert into private.account_security_change_operations (
    id, actor_user_id, requested_action, success_action, resource_id
  ) values (
    p_operation_id, p_actor_user_id, p_requested_action, p_success_action, p_resource_id
  );
  perform public.record_account_security_event(
    p_actor_user_id, p_requested_action, p_resource_id, p_operation_id
  );
  return p_operation_id;
end;
$$;

create function public.complete_account_security_change(p_operation_id uuid)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_operation private.account_security_change_operations%rowtype;
begin
  if auth.role() <> 'service_role' then raise exception 'FORBIDDEN' using errcode = '42501'; end if;
  select * into v_operation
  from private.account_security_change_operations
  where id = p_operation_id
  for update;
  if not found then raise exception 'SECURITY_CHANGE_NOT_FOUND' using errcode = 'P0002'; end if;
  if v_operation.status = 'COMPLETED' then return false; end if;
  perform public.record_account_security_event(
    v_operation.actor_user_id, v_operation.success_action,
    v_operation.resource_id, v_operation.id
  );
  update private.account_security_change_operations
  set status = 'COMPLETED', completed_at = clock_timestamp()
  where id = v_operation.id;
  return true;
end;
$$;

revoke all on function public.begin_account_security_change(uuid,uuid,text,text,text)
  from public, anon, authenticated, service_role;
revoke all on function public.complete_account_security_change(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.begin_account_security_change(uuid,uuid,text,text,text)
  to service_role;
grant execute on function public.complete_account_security_change(uuid)
  to service_role;

notify pgrst, 'reload schema';
