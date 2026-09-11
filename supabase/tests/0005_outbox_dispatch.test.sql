begin;
set local search_path = public, extensions;
select plan(10);

-- Keep this transactional test hermetic on a long-lived development database:
-- older unpublished events must not be claimed in place of the fixture below.
update public.event_outbox
set available_at = greatest(available_at, clock_timestamp() + interval '1 hour'),
    locked_at = null,
    locked_by = null
where published_at is null
  and dead_lettered_at is null;

insert into public.event_outbox (aggregate_type,aggregate_id,event_type,correlation_id,payload)
values ('test','one','TestEventV1','e0000000-0000-0000-0000-000000000001','{"safe":true}');

select is((select count(*) from public.claim_outbox_events('e1000000-0000-0000-0000-000000000001',10)),1::bigint,'worker claims available event');
select is((select count(*) from public.claim_outbox_events('e2000000-0000-0000-0000-000000000002',10)),0::bigint,'second worker cannot double claim');
select throws_ok($$update public.event_outbox set payload='{"changed":true}' where aggregate_id='one'$$,'55000','OUTBOX_EVENT_IMMUTABLE','payload cannot be changed');
select public.record_outbox_failure((select id from public.event_outbox where aggregate_id='one'),'e1000000-0000-0000-0000-000000000001','DELIVERY_TIMEOUT');
select is((select attempt_count from public.event_outbox where aggregate_id='one'),1,'failure increments attempt count');
select is((select last_error_code from public.event_outbox where aggregate_id='one'),'DELIVERY_TIMEOUT','failure stores a safe code');
update public.event_outbox set available_at=clock_timestamp() where aggregate_id='one';
select is((select count(*) from public.claim_outbox_events('e1000000-0000-0000-0000-000000000001',10)),1::bigint,'event is reclaimable after backoff');
select public.mark_outbox_published((select id from public.event_outbox where aggregate_id='one'),'e1000000-0000-0000-0000-000000000001');
select ok((select published_at is not null and locked_by is null from public.event_outbox where aggregate_id='one'),'publish atomically clears the claim');
select ok(has_function_privilege('service_role','public.claim_outbox_events(uuid,integer)','EXECUTE'),'service role can claim through the RPC');
select ok(not has_function_privilege('authenticated','public.claim_outbox_events(uuid,integer)','EXECUTE'),'authenticated cannot claim Outbox events');
select ok(not has_table_privilege('service_role','public.event_outbox','UPDATE'),'service role cannot mutate Outbox rows directly');

select * from finish();
rollback;
