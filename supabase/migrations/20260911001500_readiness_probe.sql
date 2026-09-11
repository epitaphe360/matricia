-- Least-privilege readiness probe for Web/worker supervision.
create or replace function public.readiness_status()
returns table(database_ok boolean,outbox_ok boolean,pending_events bigint,oldest_pending_seconds bigint)
language plpgsql stable security definer set search_path=pg_catalog,public
as $$
begin
  if auth.role()<>'service_role' then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  return query
    select true,
      coalesce(max(o.created_at) filter(where o.status in ('PENDING','PROCESSING','FAILED')) > statement_timestamp()-interval '24 hours',true),
      count(*) filter(where o.status in ('PENDING','PROCESSING','FAILED')),
      coalesce(extract(epoch from statement_timestamp()-min(o.created_at) filter(where o.status in ('PENDING','PROCESSING','FAILED')))::bigint,0)
    from public.event_outbox o;
end;
$$;

revoke all on function public.readiness_status() from public,anon,authenticated;
grant execute on function public.readiness_status() to service_role;
