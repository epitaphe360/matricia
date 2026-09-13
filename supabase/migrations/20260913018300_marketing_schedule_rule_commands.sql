-- Versioned marketing schedule commands and CLIENT_OWNER-only ASSISTED approval.

create function private.valid_marketing_allowed_slots_v1(p_slots jsonb) returns boolean
language plpgsql immutable strict set search_path=pg_catalog
as $$
declare s jsonb;
begin
  if jsonb_typeof(p_slots)<>'array'or jsonb_array_length(p_slots)not between 1 and 31 then return false;end if;
  for s in select value from jsonb_array_elements(p_slots)loop
    if jsonb_typeof(s)<>'object'or not(s?&array['dayOfMonth','time'])
      or exists(select 1 from jsonb_object_keys(s)k where k<>all(array['dayOfMonth','time']))
      or coalesce(s->>'dayOfMonth','')!~'^[0-9]{1,2}$'
      or(s->>'dayOfMonth')::integer not between 1 and 31
      or coalesce(s->>'time','')!~'^([01][0-9]|2[0-3]):[0-5][0-9]$'then return false;end if;
  end loop;
  return jsonb_array_length(p_slots)=(select count(distinct value::text)from jsonb_array_elements(p_slots));
end$$;

create function public.create_marketing_schedule_rule_version_v1(
  p_organization_id uuid,p_social_account_id uuid,p_timezone text,
  p_posts_per_month integer,p_reels_per_month integer,p_generation_day integer,
  p_allowed_slots jsonb,p_max_service_repetition integer,p_privacy_minimum_aggregate integer,
  p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare a uuid:=auth.uid();account public.social_accounts%rowtype;h text;cached jsonb;r jsonb;
  rule_id uuid;next_version integer;
begin
  select * into account from public.social_accounts where id=p_social_account_id;
  if a is null or not found or account.organization_id<>p_organization_id
    or not private.marketing_manage_access(p_organization_id,a) then
    raise exception'MARKETING_SCHEDULE_RULE_CREATE_DENIED'using errcode='42501';
  end if;
  if account.status<>'ACTIVE' or not exists(select 1 from public.social_connections c where c.id=account.connection_id and c.organization_id=p_organization_id and c.status='ACTIVE')
    or not exists(select 1 from pg_catalog.pg_timezone_names z where z.name=p_timezone)
    or coalesce(p_posts_per_month,-1) not between 0 and 100 or coalesce(p_reels_per_month,-1) not between 0 and 100
    or coalesce(p_posts_per_month,0)+coalesce(p_reels_per_month,0)<1 or coalesce(p_generation_day,0) not between 1 and 28
    or not coalesce(private.valid_marketing_allowed_slots_v1(p_allowed_slots),false)
    or coalesce(p_max_service_repetition,0) not between 1 and 20
    or coalesce(p_privacy_minimum_aggregate,0) not between 3 and 1000 then
    raise exception'INVALID_MARKETING_SCHEDULE_RULE'using errcode='22023';
  end if;
  h:=private.canonical_request_hash(jsonb_build_object('organization',p_organization_id,'social_account',p_social_account_id,
    'timezone',p_timezone,'posts',p_posts_per_month,'reels',p_reels_per_month,'generation_day',p_generation_day,
    'allowed_slots',p_allowed_slots,'max_service_repetition',p_max_service_repetition,'privacy_minimum_aggregate',p_privacy_minimum_aggregate));
  cached:=private.begin_contract_command(p_organization_id,'marketing.schedule_rule.create.'||p_social_account_id::text,p_idempotency_key,h,a);
  if cached is not null then return cached;end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('marketing-schedule-rule:'||p_organization_id::text||':'||p_social_account_id::text,0));
  select coalesce(max(version),0)+1 into next_version from public.marketing_schedule_rules
    where organization_id=p_organization_id and social_account_id=p_social_account_id;
  -- Rules are immutable records. ACTIVE means eligible; the head pointer determines the effective version.
  insert into public.marketing_schedule_rules(organization_id,social_account_id,version,status,timezone,
    posts_per_month,reels_per_month,generation_day,allowed_slots,max_service_repetition,
    privacy_minimum_aggregate,content_hash,created_by)
  values(p_organization_id,p_social_account_id,next_version,'ACTIVE',p_timezone,p_posts_per_month,
    p_reels_per_month,p_generation_day,p_allowed_slots,p_max_service_repetition,p_privacy_minimum_aggregate,h,a)
  returning id into rule_id;
  r:=jsonb_build_object('outcome','MARKETING_SCHEDULE_RULE_VERSION_CREATED','ruleId',rule_id,
    'version',next_version,'effective',false);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
    values(p_organization_id,a,'USER','marketing.schedule_rule.version_created','marketing_schedule_rule',rule_id::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
    values(p_organization_id,'marketing_schedule_rule',rule_id::text,'MarketingScheduleRuleVersionCreatedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_contract_command(p_organization_id,'marketing.schedule_rule.create.'||p_social_account_id::text,p_idempotency_key,r);
  return r;
end$$;

create function public.activate_marketing_schedule_rule_version_v1(
  p_rule_id uuid,p_expected_head_row_version integer,p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare a uuid:=auth.uid();rule public.marketing_schedule_rules%rowtype;head public.marketing_schedule_rule_heads%rowtype;
  h text;cached jsonb;r jsonb;new_row_version integer;
begin
  select * into rule from public.marketing_schedule_rules where id=p_rule_id;
  if a is null or not found or not private.marketing_manage_access(rule.organization_id,a) then
    raise exception'MARKETING_SCHEDULE_RULE_ACTIVATE_DENIED'using errcode='42501';
  end if;
  if rule.status<>'ACTIVE' or p_expected_head_row_version<0 then raise exception'INVALID_MARKETING_SCHEDULE_RULE_ACTIVATION'using errcode='22023';end if;
  h:=private.canonical_request_hash(jsonb_build_object('rule',rule.id,'expected',p_expected_head_row_version));
  cached:=private.begin_contract_command(rule.organization_id,'marketing.schedule_rule.activate.'||rule.social_account_id::text,p_idempotency_key,h,a);
  if cached is not null then return cached;end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('marketing-schedule-rule:'||rule.organization_id::text||':'||rule.social_account_id::text,0));
  select * into head from public.marketing_schedule_rule_heads where organization_id=rule.organization_id and social_account_id=rule.social_account_id for update;
  if found then
    if head.row_version<>p_expected_head_row_version then raise exception'STALE_MARKETING_SCHEDULE_RULE_HEAD'using errcode='40001';end if;
    update public.marketing_schedule_rule_heads set current_rule_id=rule.id,row_version=row_version+1,
      updated_by=a,updated_at=clock_timestamp() where organization_id=rule.organization_id and social_account_id=rule.social_account_id;
    new_row_version:=head.row_version+1;
  else
    if p_expected_head_row_version<>0 then raise exception'STALE_MARKETING_SCHEDULE_RULE_HEAD'using errcode='40001';end if;
    insert into public.marketing_schedule_rule_heads(organization_id,social_account_id,current_rule_id,updated_by)
      values(rule.organization_id,rule.social_account_id,rule.id,a);
    new_row_version:=1;
  end if;
  r:=jsonb_build_object('outcome','MARKETING_SCHEDULE_RULE_VERSION_ACTIVATED','ruleId',rule.id,
    'version',rule.version,'headRowVersion',new_row_version);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
    values(rule.organization_id,a,'USER','marketing.schedule_rule.version_activated','marketing_schedule_rule',rule.id::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
    values(rule.organization_id,'marketing_schedule_rule',rule.id::text,'MarketingScheduleRuleVersionActivatedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_contract_command(rule.organization_id,'marketing.schedule_rule.activate.'||rule.social_account_id::text,p_idempotency_key,r);
  return r;
end$$;

create function public.approve_assisted_marketing_calendar_v1(
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
  if a is null or not found or not private.has_org_role(cal.organization_id,array['CLIENT_OWNER'],a) then
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

revoke all on function private.valid_marketing_allowed_slots_v1(jsonb),
  public.create_marketing_schedule_rule_version_v1(uuid,uuid,text,integer,integer,integer,jsonb,integer,integer,text,uuid),
  public.activate_marketing_schedule_rule_version_v1(uuid,integer,text,uuid),
  public.approve_assisted_marketing_calendar_v1(uuid,integer,text,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.create_marketing_schedule_rule_version_v1(uuid,uuid,text,integer,integer,integer,jsonb,integer,integer,text,uuid),
  public.activate_marketing_schedule_rule_version_v1(uuid,integer,text,uuid),
  public.approve_assisted_marketing_calendar_v1(uuid,integer,text,uuid) to authenticated;
notify pgrst,'reload schema';
