-- Correct the P02 readiness projection to the immutable Outbox v1 schema.
create or replace function public.readiness_status()
returns table(database_ok boolean,outbox_ok boolean,pending_events bigint,oldest_pending_seconds bigint)
language plpgsql stable security definer set search_path=pg_catalog,public
as $$
begin
  if auth.role()<>'service_role' then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  return query
    select true,
      coalesce(min(o.occurred_at) filter(where o.published_at is null) > statement_timestamp()-interval '24 hours',true),
      count(*) filter(where o.published_at is null),
      coalesce(extract(epoch from statement_timestamp()-min(o.occurred_at) filter(where o.published_at is null))::bigint,0)
    from public.event_outbox o;
end;
$$;

revoke all on function public.readiness_status() from public,anon,authenticated;
grant execute on function public.readiness_status() to service_role;
notify pgrst,'reload schema';
