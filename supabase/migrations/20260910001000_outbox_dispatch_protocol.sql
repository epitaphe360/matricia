alter table public.event_outbox
  add column locked_at timestamptz,
  add column locked_by uuid,
  add column dead_lettered_at timestamptz;

create or replace function private.protect_outbox_update()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog
as $$
begin
  if new.organization_id is distinct from old.organization_id
     or new.aggregate_type is distinct from old.aggregate_type
     or new.aggregate_id is distinct from old.aggregate_id
     or new.event_type is distinct from old.event_type
     or new.event_version is distinct from old.event_version
     or new.correlation_id is distinct from old.correlation_id
     or new.payload is distinct from old.payload
     or new.occurred_at is distinct from old.occurred_at then
    raise exception 'OUTBOX_EVENT_IMMUTABLE' using errcode='55000';
  end if;
  return new;
end;
$$;

create trigger event_outbox_payload_immutable before update on public.event_outbox
for each row execute function private.protect_outbox_update();

create or replace function public.claim_outbox_events(p_worker_id uuid, p_limit integer default 100)
returns setof public.event_outbox
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
begin
  if p_worker_id is null or p_limit not between 1 and 500 then raise exception 'INVALID_CLAIM_REQUEST' using errcode='22023'; end if;
  return query
  with candidates as (
    select id from public.event_outbox
    where published_at is null
      and dead_lettered_at is null
      and available_at <= clock_timestamp()
      and (locked_at is null or locked_at < clock_timestamp()-interval '5 minutes')
    order by available_at,id
    for update skip locked
    limit p_limit
  )
  update public.event_outbox event
  set locked_at=clock_timestamp(),locked_by=p_worker_id
  from candidates where event.id=candidates.id
  returning event.*;
end;
$$;

create or replace function public.mark_outbox_published(p_event_id bigint, p_worker_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
begin
  update public.event_outbox set published_at=clock_timestamp(),locked_at=null,locked_by=null,last_error_code=null
  where id=p_event_id and locked_by=p_worker_id and published_at is null and dead_lettered_at is null;
  if not found then raise exception 'OUTBOX_CLAIM_NOT_OWNED' using errcode='55000'; end if;
end;
$$;

create or replace function public.record_outbox_failure(p_event_id bigint, p_worker_id uuid, p_error_code text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
begin
  if p_error_code !~ '^[A-Z][A-Z0-9_]{2,63}$' then raise exception 'INVALID_ERROR_CODE' using errcode='22023'; end if;
  update public.event_outbox
  set attempt_count=attempt_count+1,
      last_error_code=p_error_code,
      available_at=clock_timestamp()+least(interval '1 hour',interval '5 seconds'*power(2,least(attempt_count,10))),
      dead_lettered_at=case when attempt_count+1>=10 then clock_timestamp() else null end,
      locked_at=null,locked_by=null
  where id=p_event_id and locked_by=p_worker_id and published_at is null and dead_lettered_at is null
  ;
  if not found then raise exception 'OUTBOX_CLAIM_NOT_OWNED' using errcode='55000'; end if;
end;
$$;

revoke all on function public.claim_outbox_events(uuid,integer), public.mark_outbox_published(bigint,uuid), public.record_outbox_failure(bigint,uuid,text) from public, anon, authenticated;
grant execute on function public.claim_outbox_events(uuid,integer), public.mark_outbox_published(bigint,uuid), public.record_outbox_failure(bigint,uuid,text) to service_role;

create index event_outbox_claim_idx on public.event_outbox (available_at,id)
where published_at is null and dead_lettered_at is null;
