-- Gold Master MARKETING-004: additive monthly calendar orchestration.
-- The scheduler only consumes already approved, policy-compliant content. It never
-- creates claims, approves content, spends money, or bypasses publication gates.

create function public.generate_due_marketing_calendars_v1(
  p_month_start date default null,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare
  target_month date:=coalesce(p_month_start,date_trunc('month',current_date+interval'1 month')::date);
  rule record;
  candidate record;
  calendar_id uuid;
  slot jsonb;
  scheduled_at timestamptz;
  slot_day integer;
  slot_time time;
  effective_timezone text;
  generated_count integer:=0;
  scheduled_count integer:=0;
  skipped_count integer:=0;
  post_count integer;
  reel_count integer;
  item_id uuid;
  event_key text;
  result jsonb;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception'MARKETING_CALENDAR_SCHEDULER_DENIED' using errcode='42501';
  end if;
  if target_month<>date_trunc('month',target_month)::date
    or target_month<date_trunc('month',current_date)::date
    or target_month>date_trunc('month',current_date+interval'13 months')::date then
    raise exception'INVALID_MARKETING_CALENDAR_MONTH' using errcode='22023';
  end if;

  for rule in
    select r.*,a.connection_id,c.provider
    from public.marketing_schedule_rule_heads h
    join public.marketing_schedule_rules r on r.id=h.current_rule_id
      and r.organization_id=h.organization_id and r.social_account_id=h.social_account_id
    join public.social_accounts a on a.id=r.social_account_id and a.organization_id=r.organization_id
    join public.social_connections c on c.id=a.connection_id and c.organization_id=a.organization_id
    where r.status='ACTIVE' and a.status='ACTIVE' and c.status='ACTIVE'
      and (p_month_start is not null or extract(day from current_date)::integer>=r.generation_day)
    order by r.organization_id,r.social_account_id
  loop
    calendar_id:=null;
    insert into public.marketing_calendars(
      organization_id,schedule_rule_id,month_start,status,generated_at
    ) values(rule.organization_id,rule.id,target_month,'GENERATED',clock_timestamp())
    on conflict(organization_id,schedule_rule_id,month_start) do nothing
    returning id into calendar_id;

    if calendar_id is null then
      skipped_count:=skipped_count+1;
      continue;
    end if;
    generated_count:=generated_count+1;
    post_count:=0;
    reel_count:=0;
    effective_timezone:=case when exists(select 1 from pg_catalog.pg_timezone_names z where z.name=rule.timezone) then rule.timezone else 'UTC' end;

    -- ASSISTED calendars deliberately stop at GENERATED for one-click human approval.
    -- AUTOPILOT may schedule only content that was already approved and passes every
    -- immutable compliance snapshot, consent, risk, expiry and exception gate.
    for candidate in
      with eligible as(
        select c.id campaign_id,c.approved_by,mc.id content_id,mc.channel,mc.service_id,
          mc.template_version_id,v.id content_version_id,
          row_number()over(partition by coalesce(mc.service_id::text,mc.id::text) order by mc.template_version_id,mc.id) service_rank
        from public.marketing_campaigns c
        join public.marketing_content mc on mc.campaign_id=c.id
        join public.marketing_content_versions v on v.id=mc.current_version_id
        where c.organization_id=rule.organization_id and c.mode='AUTOPILOT'
          and c.status in('APPROVED','SCHEDULED') and v.status='APPROVED'
          and v.risk_score<=c.risk_threshold
          and (v.expires_at is null or v.expires_at>target_month+interval'1 month')
          and not exists(select 1 from jsonb_each_text(v.compliance_checks) q where q.value<>'PASS')
          and not exists(select 1 from public.marketing_exceptions e where e.campaign_id=c.id and e.severity='BLOCKING' and e.status='OPEN')
          and private.marketing_consent_active(c.organization_id,'SOCIAL_PUBLISHING')
          and ((rule.provider='LINKEDIN' and mc.channel='LINKEDIN')or(rule.provider='META' and mc.channel in('FACEBOOK','INSTAGRAM','REEL')))
      )
      select * from eligible where service_rank<=rule.max_service_repetition
      order by case when channel='REEL'then 1 else 0 end,template_version_id,content_id
    loop
      if candidate.channel='REEL' then
        if reel_count>=rule.reels_per_month then continue;end if;
        reel_count:=reel_count+1;
        slot_day:=1+floor((reel_count::numeric*27)/(rule.reels_per_month+1))::integer;
      else
        if post_count>=rule.posts_per_month then continue;end if;
        post_count:=post_count+1;
        slot_day:=1+floor((post_count::numeric*27)/(rule.posts_per_month+1))::integer;
      end if;

      if jsonb_array_length(rule.allowed_slots)>0 then
        slot:=rule.allowed_slots->((post_count+reel_count-1)%jsonb_array_length(rule.allowed_slots));
        if coalesce(slot->>'dayOfMonth','')~'^[0-9]{1,2}$' then
          slot_day:=least(extract(day from(target_month+interval'1 month-1 day'))::integer,greatest(1,(slot->>'dayOfMonth')::integer));
        end if;
        slot_time:=case when coalesce(slot->>'time','')~'^([01][0-9]|2[0-3]):[0-5][0-9]$' then (slot->>'time')::time else time'09:00' end;
      else
        slot_time:=time'09:00';
      end if;
      scheduled_at:=((target_month+(slot_day-1))::date+slot_time)at time zone effective_timezone;

      insert into public.marketing_calendar_items(
        campaign_id,content_version_id,social_connection_id,scheduled_at,status,calendar_id
      ) values(candidate.campaign_id,candidate.content_version_id,rule.connection_id,scheduled_at,'SCHEDULED',calendar_id)
      on conflict(content_version_id,social_connection_id,scheduled_at) do nothing
      returning id into item_id;
      if item_id is null then continue;end if;

      event_key:='marketing-calendar:'||calendar_id::text||':'||item_id::text;
      insert into public.social_publication_jobs(
        organization_id,calendar_item_id,provider,status,idempotency_key,available_at
      ) values(rule.organization_id,item_id,rule.provider,'QUEUED',event_key,scheduled_at);
      insert into public.event_outbox(
        organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key
      ) values(rule.organization_id,'marketing_calendar_item',item_id::text,'SocialPublicationScheduledV1',p_correlation_id,
        jsonb_build_object('calendar_id',calendar_id,'calendar_item_id',item_id,'campaign_id',candidate.campaign_id,'content_version_id',candidate.content_version_id,'provider',rule.provider),event_key);
      update public.marketing_campaigns set status='SCHEDULED',row_version=row_version+1
        where id=candidate.campaign_id and status='APPROVED';
      scheduled_count:=scheduled_count+1;
    end loop;

    if post_count+reel_count>0 then
      update public.marketing_calendars set status='SCHEDULED',approved_by=rule.created_by,
        approved_at=clock_timestamp(),row_version=row_version+1 where id=calendar_id;
    end if;
    event_key:='marketing-calendar:'||rule.id::text||':'||target_month::text;
    result:=jsonb_build_object('calendar_id',calendar_id,'month_start',target_month,
      'scheduled_posts',post_count,'scheduled_reels',reel_count,
      'requested_posts',rule.posts_per_month,'requested_reels',rule.reels_per_month);
    insert into public.audit_events(
      organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash
    ) values(rule.organization_id,null,'SERVICE','marketing.calendar.generated','marketing_calendar',calendar_id::text,p_correlation_id,result,repeat('0',64));
    insert into public.event_outbox(
      organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key
    ) values(rule.organization_id,'marketing_calendar',calendar_id::text,'MarketingCalendarGeneratedV1',p_correlation_id,result,event_key);
  end loop;

  return jsonb_build_object('outcome','MARKETING_CALENDARS_PROCESSED','monthStart',target_month,
    'generatedCalendars',generated_count,'scheduledItems',scheduled_count,'skippedRules',skipped_count);
end$$;

revoke all on function public.generate_due_marketing_calendars_v1(date,uuid) from public,anon,authenticated,service_role;
grant execute on function public.generate_due_marketing_calendars_v1(date,uuid) to service_role;
notify pgrst,'reload schema';
