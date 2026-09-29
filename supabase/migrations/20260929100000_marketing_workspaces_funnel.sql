-- Marketing workspaces: account owners (Client, Provider, Franchise) approve their ASSISTED calendar globally.
-- Funnel attribution: a signed first-party CTA touch links registration, diagnostic, opportunity, RFQ and contract events to the clicked content.
-- Weekly recommendations: low-risk frequency adjustments are applied to AUTOPILOT campaigns and audited.
-- Additive only: no existing data is modified by this migration.
-- Rollback: re-apply approve_assisted_marketing_calendar_v1 from 20260913018300, then
--   drop function public.apply_marketing_weekly_frequency_v1(date,text,uuid);
--   and keep public.marketing_frequency_adjustments as history (or drop it only if empty).

create or replace function public.approve_assisted_marketing_calendar_v1(
  p_calendar_id uuid,p_expected_row_version integer,p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare a uuid:=auth.uid();cal public.marketing_calendars%rowtype;rule public.marketing_schedule_rules%rowtype;
  account public.social_accounts%rowtype;conn public.social_connections%rowtype;candidate record;
  h text;cached jsonb;r jsonb;slot jsonb;slot_day integer;slot_time time;scheduled_at timestamptz;
  effective_timezone text;post_count integer:=0;reel_count integer:=0;item_id uuid;event_key text;
begin
  select * into cal from public.marketing_calendars where id=p_calendar_id;
  if a is null or not found or not private.has_org_role(cal.organization_id,array['CLIENT_OWNER','PROVIDER_OWNER','FRANCHISE_OWNER'],a) then
    raise exception'MARKETING_ASSISTED_APPROVAL_DENIED'using errcode='42501';
  end if;
  h:=private.canonical_request_hash(jsonb_build_object('calendar',cal.id,'expected',p_expected_row_version));
  cached:=private.begin_contract_command(cal.organization_id,'marketing.calendar.assisted_approve.'||cal.id::text,p_idempotency_key,h,a);
  if cached is not null then return cached;end if;
  select * into cal from public.marketing_calendars where id=p_calendar_id for update;
  if cal.row_version<>p_expected_row_version then raise exception'STALE_MARKETING_CALENDAR'using errcode='40001';end if;
  if cal.status not in('GENERATED','VALIDATED_BY_RULES') then raise exception'MARKETING_CALENDAR_NOT_ASSISTED_APPROVABLE'using errcode='55000';end if;
  select * into rule from public.marketing_schedule_rules where id=cal.schedule_rule_id and organization_id=cal.organization_id and status='ACTIVE';
  select * into account from public.social_accounts where id=rule.social_account_id and organization_id=cal.organization_id and status='ACTIVE';
  select * into conn from public.social_connections where id=account.connection_id and organization_id=cal.organization_id and status='ACTIVE';
  if rule.id is null or account.id is null or conn.id is null or not private.marketing_consent_active(cal.organization_id,'SOCIAL_PUBLISHING') then
    raise exception'MARKETING_CALENDAR_NOT_ASSISTED_APPROVABLE'using errcode='55000';
  end if;
  if exists(select 1 from public.marketing_campaigns c join public.marketing_content mc on mc.campaign_id=c.id
    join public.marketing_content_versions v on v.id=mc.current_version_id where c.organization_id=cal.organization_id
    and c.mode='ASSISTED'and c.status='VALIDATED_BY_RULES'
    and ((conn.provider='LINKEDIN'and mc.channel='LINKEDIN')or(conn.provider='META'and mc.channel in('FACEBOOK','INSTAGRAM','REEL')))
    and(v.status<>'VALIDATED_BY_RULES'or v.risk_score>c.risk_threshold
      or exists(select 1 from jsonb_each_text(v.compliance_checks)q where q.value<>'PASS')
      or exists(select 1 from public.marketing_exceptions e where e.campaign_id=c.id and e.severity='BLOCKING'and e.status='OPEN'))) then
    raise exception'MARKETING_ASSISTED_CONTENT_BLOCKED'using errcode='23514';
  end if;
  if not exists(select 1 from public.marketing_campaigns c join public.marketing_content mc on mc.campaign_id=c.id
    join public.marketing_content_versions v on v.id=mc.current_version_id where c.organization_id=cal.organization_id
    and c.mode='ASSISTED'and c.status='VALIDATED_BY_RULES'and v.status='VALIDATED_BY_RULES'
    and ((conn.provider='LINKEDIN'and mc.channel='LINKEDIN')or(conn.provider='META'and mc.channel in('FACEBOOK','INSTAGRAM','REEL')))) then
    raise exception'MARKETING_ASSISTED_CONTENT_REQUIRED'using errcode='55000';
  end if;

  update public.marketing_campaigns c set status='APPROVED',approved_by=a,approved_at=clock_timestamp(),row_version=row_version+1
    where c.organization_id=cal.organization_id and c.mode='ASSISTED'and c.status='VALIDATED_BY_RULES'
      and exists(select 1 from public.marketing_content mc where mc.campaign_id=c.id
        and ((conn.provider='LINKEDIN'and mc.channel='LINKEDIN')or(conn.provider='META'and mc.channel in('FACEBOOK','INSTAGRAM','REEL'))));
  update public.marketing_content_versions v set status='APPROVED' from public.marketing_content mc,public.marketing_campaigns c
    where v.id=mc.current_version_id and mc.campaign_id=c.id and c.organization_id=cal.organization_id
      and c.mode='ASSISTED'and c.status='APPROVED'and v.status='VALIDATED_BY_RULES';
  effective_timezone:=case when exists(select 1 from pg_catalog.pg_timezone_names z where z.name=rule.timezone)then rule.timezone else'UTC'end;

  for candidate in
    with eligible as(select c.id campaign_id,mc.id content_id,mc.channel,mc.service_id,mc.template_version_id,v.id content_version_id,
      row_number()over(partition by coalesce(mc.service_id::text,mc.id::text)order by mc.template_version_id,mc.id)service_rank
      from public.marketing_campaigns c join public.marketing_content mc on mc.campaign_id=c.id
      join public.marketing_content_versions v on v.id=mc.current_version_id
      where c.organization_id=cal.organization_id and c.mode='ASSISTED'and c.status='APPROVED'and c.approved_by=a
      and v.status='APPROVED'and ((conn.provider='LINKEDIN'and mc.channel='LINKEDIN')or(conn.provider='META'and mc.channel in('FACEBOOK','INSTAGRAM','REEL'))))
    select * from eligible where service_rank<=rule.max_service_repetition order by case when channel='REEL'then 1 else 0 end,template_version_id,content_id
  loop
    if not private.marketing_publication_ready_v41(cal.organization_id,conn.provider,conn.id,candidate.content_version_id)then
      raise exception'MARKETING_ASSISTED_CONTENT_BLOCKED'using errcode='23514';
    end if;
    if candidate.channel='REEL'then if reel_count>=rule.reels_per_month then continue;end if;reel_count:=reel_count+1;slot_day:=1+floor((reel_count::numeric*27)/(rule.reels_per_month+1))::integer;
    else if post_count>=rule.posts_per_month then continue;end if;post_count:=post_count+1;slot_day:=1+floor((post_count::numeric*27)/(rule.posts_per_month+1))::integer;end if;
    slot:=rule.allowed_slots->((post_count+reel_count-1)%jsonb_array_length(rule.allowed_slots));
    slot_day:=least(extract(day from(cal.month_start+interval'1 month-1 day'))::integer,greatest(1,(slot->>'dayOfMonth')::integer));
    slot_time:=(slot->>'time')::time;
    scheduled_at:=((cal.month_start+(slot_day-1))::date+slot_time)at time zone effective_timezone;
    item_id:=null;
    insert into public.marketing_calendar_items(campaign_id,content_version_id,social_connection_id,scheduled_at,status,calendar_id)
      values(candidate.campaign_id,candidate.content_version_id,conn.id,scheduled_at,'SCHEDULED',cal.id)
      on conflict(content_version_id,social_connection_id,scheduled_at)do nothing returning id into item_id;
    if item_id is null then continue;end if;
    event_key:='marketing-assisted:'||cal.id::text||':'||item_id::text;
    insert into public.social_publication_jobs(organization_id,calendar_item_id,provider,status,idempotency_key,available_at)
      values(cal.organization_id,item_id,conn.provider,'QUEUED',event_key,scheduled_at);
    insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
      values(cal.organization_id,'marketing_calendar_item',item_id::text,'SocialPublicationScheduledV1',p_correlation_id,
        jsonb_build_object('calendar_id',cal.id,'calendar_item_id',item_id,'content_version_id',candidate.content_version_id,'provider',conn.provider),event_key);
  end loop;
  if post_count+reel_count=0 then raise exception'MARKETING_ASSISTED_CONTENT_REQUIRED'using errcode='55000';end if;
  update public.marketing_calendars set status='SCHEDULED',approved_by=a,approved_at=clock_timestamp(),row_version=row_version+1 where id=cal.id;
  r:=jsonb_build_object('outcome','MARKETING_ASSISTED_CALENDAR_APPROVED','calendarId',cal.id,
    'rowVersion',cal.row_version+1,'scheduledPosts',post_count,'scheduledReels',reel_count);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
    values(cal.organization_id,a,'USER','marketing.calendar.assisted_approved','marketing_calendar',cal.id::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
    values(cal.organization_id,'marketing_calendar',cal.id::text,'MarketingAssistedCalendarApprovedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_contract_command(cal.organization_id,'marketing.calendar.assisted_approve.'||cal.id::text,p_idempotency_key,r);
  return r;
end$$;

revoke all on function public.approve_assisted_marketing_calendar_v1(uuid,integer,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.approve_assisted_marketing_calendar_v1(uuid,integer,text,uuid) to authenticated;

create table public.marketing_frequency_adjustments(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  campaign_id uuid not null references public.marketing_campaigns(id) on delete restrict,
  week_start date not null check(extract(isodow from week_start)=1),
  feedback text not null check(feedback in('INCREASE_FREQUENCY','REDUCE_FREQUENCY','CHANGE_TEMPLATE','CHANGE_SERVICE_FOCUS','PAUSE_CAMPAIGN')),
  decision text not null check(decision in('APPLIED','HUMAN_REVIEW_REQUIRED','AT_LIMIT')),
  previous_frequency integer not null check(previous_frequency between 1 and 50),
  new_frequency integer not null check(new_frequency between 1 and 50),
  correlation_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  unique(campaign_id,week_start),
  check((decision='APPLIED')=(new_frequency<>previous_frequency)),
  check(abs(new_frequency-previous_frequency)<=1)
);
alter table public.marketing_frequency_adjustments enable row level security;
alter table public.marketing_frequency_adjustments force row level security;
revoke all on public.marketing_frequency_adjustments from public,anon,authenticated,service_role;
create policy marketing_frequency_adjustments_scoped_read on public.marketing_frequency_adjustments
  for select to authenticated
  using(private.marketing_manage_access(organization_id) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
grant select on public.marketing_frequency_adjustments to authenticated;
create trigger marketing_frequency_adjustments_immutable before update or delete
  on public.marketing_frequency_adjustments for each row execute function private.prevent_marketing_history_change();
create index marketing_frequency_adjustments_org_week_idx on public.marketing_frequency_adjustments(organization_id,week_start desc);

-- Only AUTOPILOT campaigns are adjusted, by one step per week; other recommendations wait for a human decision.
create function public.apply_marketing_weekly_frequency_v1(
  p_week_start date,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions
as $$
declare h text;cached jsonb;r jsonb;c record;next_frequency integer;decision text;applied integer:=0;review integer:=0;at_limit integer:=0;
begin
  if auth.role() is distinct from 'service_role' then raise exception'MARKETING_FREQUENCY_WORKER_DENIED'using errcode='42501';end if;
  if p_week_start is null or extract(isodow from p_week_start)<>1 or p_week_start>current_date then
    raise exception'INVALID_MARKETING_FREQUENCY_WEEK'using errcode='22023';
  end if;
  h:=private.canonical_request_hash(jsonb_build_object('week_start',p_week_start));
  cached:=private.begin_marketing_worker_command('marketing.frequency.weekly',p_idempotency_key,h);
  if cached is not null then return cached;end if;
  for c in
    select mc.id,mc.organization_id,mc.frequency_max_weekly,mc.row_version,p.feedback
    from public.marketing_campaigns mc
    join public.marketing_campaign_performance p on p.campaign_id=mc.id
    where mc.mode='AUTOPILOT' and mc.status in('APPROVED','SCHEDULED','PUBLISHED') and p.feedback<>'KEEP'
      and not exists(select 1 from public.marketing_frequency_adjustments a where a.campaign_id=mc.id and a.week_start=p_week_start)
    order by mc.id
    for update of mc
  loop
    next_frequency:=c.frequency_max_weekly;
    if c.feedback='INCREASE_FREQUENCY' then next_frequency:=least(c.frequency_max_weekly+1,50);
    elsif c.feedback='REDUCE_FREQUENCY' then next_frequency:=greatest(c.frequency_max_weekly-1,1);
    end if;
    decision:=case when c.feedback not in('INCREASE_FREQUENCY','REDUCE_FREQUENCY') then 'HUMAN_REVIEW_REQUIRED'
      when next_frequency=c.frequency_max_weekly then 'AT_LIMIT' else 'APPLIED' end;
    insert into public.marketing_frequency_adjustments(organization_id,campaign_id,week_start,feedback,decision,previous_frequency,new_frequency,correlation_id)
      values(c.organization_id,c.id,p_week_start,c.feedback,decision,c.frequency_max_weekly,next_frequency,p_correlation_id);
    if decision='APPLIED' then
      update public.marketing_campaigns set frequency_max_weekly=next_frequency,row_version=row_version+1 where id=c.id;
      applied:=applied+1;
    elsif decision='AT_LIMIT' then at_limit:=at_limit+1;
    else review:=review+1;
    end if;
    r:=jsonb_build_object('campaign_id',c.id,'week_start',p_week_start,'feedback',c.feedback,'decision',decision,'previous_frequency',c.frequency_max_weekly,'new_frequency',next_frequency);
    insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
      values(c.organization_id,null,'SERVICE','marketing.campaign.weekly_frequency_'||lower(decision),'marketing_campaign',c.id::text,p_correlation_id,r,repeat('0',64));
    insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
      values(c.organization_id,'marketing_campaign',c.id::text,'MarketingWeeklyFrequencyReviewedV1',p_correlation_id,r,'marketing-frequency:'||c.id::text||':'||p_week_start::text);
  end loop;
  r:=jsonb_build_object('outcome','MARKETING_WEEKLY_FREQUENCY_APPLIED','week_start',p_week_start,'applied',applied,'human_review_required',review,'at_limit',at_limit);
  perform private.finish_marketing_worker_command('marketing.frequency.weekly',p_idempotency_key,r);
  return r;
end$$;
revoke all on function public.apply_marketing_weekly_frequency_v1(date,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.apply_marketing_weekly_frequency_v1(date,text,uuid) to service_role;
notify pgrst,'reload schema';
