-- Privacy remediation for historical and future Provider feedback Outbox notices.
-- No event or audit record is deleted; sensitive routing identifiers are replaced in place.

create or replace function private.provider_feedback_event_pseudonym(p_event_id bigint,p_correlation_id uuid) returns text
language sql immutable security definer set search_path=pg_catalog,extensions as $$
 select 'pf_'||encode(extensions.hmac(convert_to(p_event_id::text,'UTF8'),convert_to(p_correlation_id::text,'UTF8'),'sha256'),'hex')
$$;
revoke all on function private.provider_feedback_event_pseudonym(bigint,uuid) from public,anon,authenticated,service_role;

create or replace function private.sanitize_provider_feedback_outbox() returns trigger language plpgsql security definer set search_path=pg_catalog,private as $$
begin
 if new.event_type='ProviderFeedbackPublishedV1' then
  new.aggregate_type:='provider_feedback_notice';
  new.aggregate_id:=private.provider_feedback_event_pseudonym(new.id,new.correlation_id);
  new.payload:=jsonb_build_object(
   'feedback_available',true,
   'ranking_position',case when (new.payload->>'ranking_position')~'^[1-9][0-9]*$' then (new.payload->>'ranking_position')::integer end,
   'ranked_quote_count',case when (new.payload->>'ranked_quote_count')~'^[1-9][0-9]*$' then (new.payload->>'ranked_quote_count')::integer end
  );
 end if;
 return new;
end$$;
revoke all on function private.sanitize_provider_feedback_outbox() from public,anon,authenticated,service_role;

do $$
declare v_count bigint;v_correlation uuid:=extensions.gen_random_uuid();
begin
 select count(*) into v_count from public.event_outbox where event_type='ProviderFeedbackPublishedV1';
 alter table public.event_outbox disable trigger event_outbox_no_delete;
 update public.event_outbox
 set aggregate_type='provider_feedback_notice',
     aggregate_id=private.provider_feedback_event_pseudonym(id,correlation_id),
     payload=jsonb_build_object(
      'feedback_available',true,
      'ranking_position',case when (payload->>'ranking_position')~'^[1-9][0-9]*$' then (payload->>'ranking_position')::integer end,
      'ranked_quote_count',case when (payload->>'ranked_quote_count')~'^[1-9][0-9]*$' then (payload->>'ranked_quote_count')::integer end
     )
 where event_type='ProviderFeedbackPublishedV1';
 alter table public.event_outbox enable trigger event_outbox_no_delete;
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
 values(null,null,'SYSTEM','privacy.provider_feedback_outbox.backfilled','event_outbox','ProviderFeedbackPublishedV1',v_correlation,jsonb_build_object('remediated_event_count',v_count,'strategy','HMAC_EVENT_PSEUDONYM_V1','payload_contract','ANONYMOUS_RANKING_ONLY'),repeat('0',64));
end$$;

