begin;
set local search_path = public, extensions;
select plan(17);

insert into auth.users (
  id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values ('80000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p03-audit@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations (id,legal_name,display_name,status,created_by)
values ('81000000-0000-0000-0000-000000000001','P03 Audit SARL','P03 Audit','ACTIVE','80000000-0000-0000-0000-000000000001');

insert into public.audit_events (
  organization_id,actor_user_id,actor_type,action,resource_type,resource_id,
  correlation_id,occurred_at,request_ip,user_agent,metadata,previous_hash,event_hash
) values
('81000000-0000-0000-0000-000000000001','80000000-0000-0000-0000-000000000001','USER','p03.audit.first','test_resource','first','82000000-0000-0000-0000-000000000001','2026-09-11T10:00:00Z','192.0.2.1','p03-test',jsonb_build_object('ordinal',1),repeat('f',64),repeat('f',64)),
('81000000-0000-0000-0000-000000000001','80000000-0000-0000-0000-000000000001','USER','p03.audit.second','test_resource','second','82000000-0000-0000-0000-000000000002','2026-09-11T10:00:01Z','192.0.2.2','p03-test',jsonb_build_object('ordinal',2),repeat('f',64),repeat('f',64));

select is(
  (select previous_hash from public.audit_events where correlation_id='82000000-0000-0000-0000-000000000001'),
  null::text,
  'audit trigger replaces a forged first previous hash'
);
select is(
  (select previous_hash from public.audit_events where correlation_id='82000000-0000-0000-0000-000000000002'),
  (select event_hash from public.audit_events where correlation_id='82000000-0000-0000-0000-000000000001'),
  'audit chain links the second event to the sealed first event'
);
select ok((
  select bool_and(event_hash=encode(extensions.digest(convert_to(jsonb_build_object(
    'previous_hash',coalesce(previous_hash,''),'organization_id',organization_id,'actor_user_id',actor_user_id,
    'actor_type',actor_type,'action',action,'resource_type',resource_type,'resource_id',resource_id,
    'correlation_id',correlation_id,'occurred_at',occurred_at,'request_ip',request_ip,
    'user_agent',user_agent,'metadata',metadata
  )::text,'UTF8'),'sha256'),'hex'))
  from public.audit_events
  where correlation_id in ('82000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000002')
),'stored audit hashes recompute from every sealed field');
select throws_ok(
  $$update public.audit_events set metadata='{"tampered":true}' where correlation_id='82000000-0000-0000-0000-000000000001'$$,
  '55000','IMMUTABLE_RECORD','audit events reject UPDATE'
);
select throws_ok(
  $$delete from public.audit_events where correlation_id='82000000-0000-0000-0000-000000000001'$$,
  '55000','IMMUTABLE_RECORD','audit events reject DELETE'
);

-- A persistent development queue can contain legitimate unpublished events from
-- other phase fixtures. Delay them transactionally so this test claims only its
-- own event; ROLLBACK restores their dispatch state.
update public.event_outbox
set available_at = greatest(available_at, clock_timestamp() + interval '1 hour'),
    locked_at = null,
    locked_by = null
where published_at is null
  and dead_lettered_at is null;

insert into public.event_outbox (
  aggregate_type,aggregate_id,event_type,correlation_id,payload,attempt_count
) values ('p03-test','dead-letter','P03DeadLetterTestV1','83000000-0000-0000-0000-000000000001','{"safe":true}',9);
select is((select count(*) from public.claim_outbox_events('84000000-0000-0000-0000-000000000001',1)),1::bigint,'worker claims the pending Outbox event');
select throws_ok(
  $$select public.mark_outbox_published((select id from public.event_outbox where correlation_id='83000000-0000-0000-0000-000000000001'),'84000000-0000-0000-0000-000000000002')$$,
  '55000','OUTBOX_CLAIM_NOT_OWNED','a different worker cannot publish the claim'
);
select throws_ok(
  $$select public.record_outbox_failure((select id from public.event_outbox where correlation_id='83000000-0000-0000-0000-000000000001'),'84000000-0000-0000-0000-000000000002','DELIVERY_TIMEOUT')$$,
  '55000','OUTBOX_CLAIM_NOT_OWNED','a different worker cannot fail the claim'
);
select public.record_outbox_failure(
  (select id from public.event_outbox where correlation_id='83000000-0000-0000-0000-000000000001'),
  '84000000-0000-0000-0000-000000000001','DELIVERY_TIMEOUT'
);
select is((select attempt_count from public.event_outbox where correlation_id='83000000-0000-0000-0000-000000000001'),10,'tenth failure records the terminal attempt count');
select ok((select dead_lettered_at is not null and published_at is null and locked_at is null and locked_by is null from public.event_outbox where correlation_id='83000000-0000-0000-0000-000000000001'),'dead-lettering records one terminal state and clears the claim');
select is((select count(*) from public.claim_outbox_events('84000000-0000-0000-0000-000000000001',1)),0::bigint,'dead-lettered event cannot be claimed again');
select throws_ok(
  $$select public.mark_outbox_published((select id from public.event_outbox where correlation_id='83000000-0000-0000-0000-000000000001'),'84000000-0000-0000-0000-000000000001')$$,
  '55000','OUTBOX_CLAIM_NOT_OWNED','dead-lettered event cannot transition to published'
);
select throws_ok(
  $$update public.event_outbox set payload='{"tampered":true}' where correlation_id='83000000-0000-0000-0000-000000000001'$$,
  '55000','OUTBOX_EVENT_IMMUTABLE','Outbox payload remains immutable after dead-lettering'
);
select throws_ok(
  $$update public.event_outbox set published_at=now() where correlation_id='83000000-0000-0000-0000-000000000001'$$,
  '23514',null,'database constraint forbids simultaneous terminal states'
);
select throws_ok(
  $$delete from public.event_outbox where correlation_id='83000000-0000-0000-0000-000000000001'$$,
  '55000','IMMUTABLE_RECORD','Outbox events reject DELETE'
);
select ok(not has_function_privilege('authenticated','public.record_outbox_failure(bigint,uuid,text)','EXECUTE'),'authenticated cannot drive Outbox failure transitions');
select ok(not has_function_privilege('authenticated','public.mark_outbox_published(bigint,uuid)','EXECUTE'),'authenticated cannot drive Outbox publish transitions');

select * from finish();
rollback;
