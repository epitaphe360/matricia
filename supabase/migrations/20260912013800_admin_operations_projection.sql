begin;

create or replace function public.list_admin_operations_projection(
  p_limit integer default 50
) returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  outbox_counts jsonb;
  delivery_counts jsonb;
  outbox_rows jsonb;
  delivery_rows jsonb;
begin
  if actor is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'],actor) then
    raise exception 'ADMIN_OPERATIONS_PROJECTION_DENIED' using errcode='42501';
  end if;
  if p_limit is null or p_limit not between 1 and 200 then
    raise exception 'INVALID_ADMIN_OPERATIONS_LIMIT' using errcode='22023';
  end if;

  select jsonb_build_object(
    'total',count(*),
    'pending',count(*) filter(where operation.published_at is null and operation.last_error_code is null),
    'failed',count(*) filter(where operation.published_at is null and operation.last_error_code is not null),
    'published',count(*) filter(where operation.published_at is not null)
  ) into outbox_counts
  from public.event_outbox operation;

  select jsonb_build_object(
    'total',count(*),
    'pending',count(*) filter(where delivery.status='PENDING'),
    'queued_digest',count(*) filter(where delivery.status='QUEUED_DIGEST'),
    'sent',count(*) filter(where delivery.status='SENT'),
    'delivered',count(*) filter(where delivery.status='DELIVERED'),
    'failed',count(*) filter(where delivery.status='FAILED'),
    'dead_letter',count(*) filter(where delivery.status='DEAD_LETTER'),
    'skipped',count(*) filter(where delivery.status='SKIPPED')
  ) into delivery_counts
  from public.notification_deliveries delivery;

  select coalesce(jsonb_agg(to_jsonb(bounded_operation) order by bounded_operation.occurred_at desc,bounded_operation.sequence desc),'[]'::jsonb)
  into outbox_rows
  from (
    select operation.id as sequence,operation.event_type,
      case when operation.published_at is not null then 'PUBLISHED'
           when operation.last_error_code is not null then 'FAILED' else 'PENDING' end as status,
      operation.attempt_count,operation.occurred_at,operation.available_at,operation.published_at,
      case when operation.last_error_code is null then null else 'REDACTED' end as error_code
    from public.event_outbox operation
    order by operation.occurred_at desc,operation.id desc
    limit p_limit
  ) bounded_operation;

  select coalesce(jsonb_agg(to_jsonb(bounded_delivery) order by bounded_delivery.created_at desc,bounded_delivery.sequence desc),'[]'::jsonb)
  into delivery_rows
  from (
    select delivery.id as sequence,delivery.channel,delivery.delivery_mode,delivery.status,
      delivery.attempt_count,delivery.next_attempt_at,delivery.created_at,delivery.updated_at,
      case when delivery.last_error_code is null then null else 'REDACTED' end as error_code
    from public.notification_deliveries delivery
    order by delivery.created_at desc,delivery.id desc
    limit p_limit
  ) bounded_delivery;

  return jsonb_build_object(
    'as_of',statement_timestamp(),
    'outbox_counts',outbox_counts,
    'delivery_counts',delivery_counts,
    'outbox',outbox_rows,
    'deliveries',delivery_rows
  );
end
$$;

revoke all on function public.list_admin_operations_projection(integer)
  from public, anon, authenticated, service_role;
grant execute on function public.list_admin_operations_projection(integer)
  to authenticated;

commit;
