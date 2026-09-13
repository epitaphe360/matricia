-- Preserve calendar integrity after the V1 calendar relation became mandatory,
-- and ensure sandbox executions can never be recorded as real publications.

alter table public.social_publication_results
  drop constraint if exists social_publication_results_outcome_check;
alter table public.social_publication_results
  add constraint social_publication_results_outcome_check
  check(outcome in('PUBLISHED','SANDBOXED','RETRYABLE_FAILURE','PERMANENT_FAILURE','SKIPPED_CONSENT'));

create or replace function public.schedule_marketing_campaign(
  p_campaign_id uuid,p_items jsonb,p_expected_row_version integer,
  p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare
  a uuid:=auth.uid();
  c public.marketing_campaigns%rowtype;
  h text;cached jsonb;r jsonb;x jsonb;
  v public.marketing_content_versions%rowtype;
  conn public.social_connections%rowtype;
  rule_id uuid;calendar_id uuid;i uuid;n integer:=0;week_count integer;
  schedule_at timestamptz;month_start date;week_start timestamptz;
begin
  select * into c from public.marketing_campaigns where id=p_campaign_id for update;
  if a is null or not found or not private.marketing_manage_access(c.organization_id,a) then
    raise exception'MARKETING_SCHEDULE_DENIED' using errcode='42501';
  end if;
  if c.status<>'APPROVED' or c.row_version<>p_expected_row_version
    or not private.marketing_consent_active(c.organization_id,'SOCIAL_PUBLISHING')
    or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items) not between 1 and 100 then
    raise exception'MARKETING_CAMPAIGN_NOT_SCHEDULABLE' using errcode='55000';
  end if;
  h:=private.canonical_request_hash(jsonb_build_object('campaign',c.id,'items',p_items,'expected',p_expected_row_version));
  cached:=private.begin_contract_command(c.organization_id,'marketing.campaign.schedule.'||c.id,p_idempotency_key,h,a);
  if cached is not null then return cached;end if;

  for x in select value from jsonb_array_elements(p_items) loop
    schedule_at:=(x->>'scheduled_at')::timestamptz;
    if schedule_at<=clock_timestamp() then
      raise exception'INVALID_MARKETING_SCHEDULE' using errcode='22023';
    end if;
    select v.* into v from public.marketing_content_versions v
      join public.marketing_content mc on mc.id=v.content_id
      where v.id=(x->>'content_version_id')::uuid and mc.campaign_id=c.id;
    select * into conn from public.social_connections
      where id=(x->>'social_connection_id')::uuid and organization_id=c.organization_id and status='ACTIVE';
    if v.id is null or conn.id is null or v.status<>'APPROVED'
      or v.risk_score>c.risk_threshold
      or(v.expires_at is not null and v.expires_at<=schedule_at)
      or exists(select 1 from jsonb_each_text(v.compliance_checks)q where q.value<>'PASS')
      or exists(select 1 from public.marketing_exceptions e where e.campaign_id=c.id and e.severity='BLOCKING'and e.status='OPEN')
      or not private.marketing_publication_ready_v41(c.organization_id,conn.provider,conn.id,v.id) then
      raise exception'MARKETING_CONTENT_BLOCKED' using errcode='23514';
    end if;

    select head.current_rule_id into rule_id
      from public.social_accounts account
      join public.marketing_schedule_rule_heads head
        on head.organization_id=account.organization_id and head.social_account_id=account.id
      join public.marketing_schedule_rules rule on rule.id=head.current_rule_id and rule.status='ACTIVE'
      where account.organization_id=c.organization_id and account.connection_id=conn.id and account.status='ACTIVE'
      order by account.id limit 1;
    if rule_id is null then
      raise exception'MARKETING_ACTIVE_SCHEDULE_RULE_REQUIRED' using errcode='55000';
    end if;

    month_start:=date_trunc('month',schedule_at)::date;
    insert into public.marketing_calendars(
      organization_id,schedule_rule_id,month_start,status,generated_at,approved_by,approved_at
    ) values(c.organization_id,rule_id,month_start,'SCHEDULED',clock_timestamp(),c.approved_by,c.approved_at)
    on conflict(organization_id,schedule_rule_id,month_start)
    do update set status=case when marketing_calendars.status in('DRAFT','GENERATED','VALIDATED_BY_RULES','APPROVED')
      then'SCHEDULED'else marketing_calendars.status end,row_version=marketing_calendars.row_version+1
    returning id into calendar_id;

    week_start:=date_trunc('week',schedule_at);
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(c.organization_id::text||':'||week_start::text,0));
    select count(*) into week_count from public.marketing_calendar_items ci
      join public.marketing_campaigns mc on mc.id=ci.campaign_id
      where mc.organization_id=c.organization_id
        and ci.scheduled_at>=week_start and ci.scheduled_at<week_start+interval'7 days'
        and ci.status in('SCHEDULED','PUBLISHED');
    if week_count>=c.frequency_max_weekly then
      raise exception'MARKETING_FREQUENCY_LIMIT' using errcode='23514';
    end if;

    insert into public.marketing_calendar_items(
      campaign_id,content_version_id,social_connection_id,scheduled_at,status,calendar_id
    ) values(c.id,v.id,conn.id,schedule_at,'SCHEDULED',calendar_id) returning id into i;
    insert into public.social_publication_jobs(
      organization_id,calendar_item_id,provider,status,idempotency_key,available_at
    ) values(c.organization_id,i,conn.provider,'QUEUED',p_idempotency_key||':'||n,schedule_at);
    insert into public.event_outbox(
      organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key
    ) values(c.organization_id,'marketing_calendar_item',i::text,'SocialPublicationScheduledV1',
      p_correlation_id,jsonb_build_object('calendar_id',calendar_id,'calendar_item_id',i,
      'content_version_id',v.id,'provider',conn.provider),p_idempotency_key||':'||n);
    n:=n+1;
  end loop;
  update public.marketing_campaigns set status='SCHEDULED',row_version=row_version+1 where id=c.id;
  r:=jsonb_build_object('outcome','MARKETING_CAMPAIGN_SCHEDULED','campaign_id',c.id,'scheduled_count',n);
  insert into public.audit_events(
    organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash
  ) values(c.organization_id,a,'USER','marketing.campaign.scheduled','marketing_campaign',c.id::text,
    p_correlation_id,r,repeat('0',64));
  perform private.finish_contract_command(c.organization_id,'marketing.campaign.schedule.'||c.id,p_idempotency_key,r);
  return r;
exception when invalid_text_representation then
  raise exception'INVALID_MARKETING_SCHEDULE' using errcode='22023';
end$$;

create or replace function public.record_social_publication_worker_result_v41(
  p_job_id uuid,p_outcome text,p_provider_publication_id text,p_error_code text,
  p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare j public.social_publication_jobs%rowtype;i public.marketing_calendar_items%rowtype;
v public.marketing_content_versions%rowtype;prior public.social_publication_results%rowtype;
auth_hash text;consent_hash text;r jsonb;
begin
  if auth.role() is distinct from 'service_role' then raise exception'MARKETING_WORKER_RESULT_DENIED'using errcode='42501';end if;
  if p_outcome not in('PUBLISHED','SANDBOXED','RETRYABLE_FAILURE','PERMANENT_FAILURE')
    or length(coalesce(p_idempotency_key,''))not between 8 and 200
    or(p_outcome='PUBLISHED')<>(p_provider_publication_id is not null)
    or(p_outcome in('PUBLISHED','SANDBOXED')and p_error_code is not null) then
    raise exception'INVALID_MARKETING_WORKER_RESULT'using errcode='22023';
  end if;
  select * into j from public.social_publication_jobs where id=p_job_id for update;
  if not found then raise exception'MARKETING_JOB_NOT_FOUND'using errcode='P0002';end if;
  select * into prior from public.social_publication_results where job_id=j.id and attempt=j.attempt_count;
  if found then
    if prior.outcome<>p_outcome or prior.provider_publication_id is distinct from p_provider_publication_id
      or prior.error_code is distinct from p_error_code then
      raise exception'IDEMPOTENCY_PAYLOAD_MISMATCH'using errcode='22000';
    end if;
    return jsonb_build_object('outcome',prior.outcome,'job_id',j.id,'attempt',prior.attempt);
  end if;
  if j.status<>'CLAIMED'then raise exception'MARKETING_JOB_NOT_CLAIMED'using errcode='55000';end if;
  select * into i from public.marketing_calendar_items where id=j.calendar_item_id;
  select * into v from public.marketing_content_versions where id=i.content_version_id;
  if p_outcome='PUBLISHED'and not private.marketing_publication_ready_v41(
    j.organization_id,j.provider,i.social_connection_id,i.content_version_id
  )then raise exception'MARKETING_PUBLICATION_BLOCKED'using errcode='55000';end if;
  insert into public.social_publication_results(job_id,attempt,outcome,provider_publication_id,error_code)
    values(j.id,j.attempt_count,p_outcome,p_provider_publication_id,p_error_code);
  if p_outcome='PUBLISHED'then
    select evidence_hash into auth_hash from public.marketing_brand_authorizations
      where organization_id=j.organization_id and decision='GRANTED'order by decided_at desc,id desc limit 1;
    select evidence_hash into consent_hash from public.marketing_consents
      where organization_id=j.organization_id and purpose='SOCIAL_PUBLISHING'and decision='GRANTED'
      order by decided_at desc,id desc limit 1;
    insert into public.marketing_publication_journal(
      organization_id,job_id,content_version_id,provider,provider_publication_id,content_snapshot,
      content_hash,authorization_evidence_hash,consent_evidence_hash,published_at
    ) values(j.organization_id,j.id,v.id,j.provider,p_provider_publication_id,
      jsonb_build_object('language',v.language,'hook',v.hook,'body',v.body,'cta',v.cta,
      'hashtags',v.hashtags,'landing_url',v.landing_url,'media_url',v.media_url),
      v.content_hash,auth_hash,consent_hash,clock_timestamp());
    update public.social_publication_jobs set status='PUBLISHED'where id=j.id;
    update public.marketing_calendar_items set status='PUBLISHED'where id=i.id;
    r:=jsonb_build_object('outcome','PUBLISHED','job_id',j.id,'provider_publication_id',p_provider_publication_id);
  elsif p_outcome='SANDBOXED'then
    update public.social_publication_jobs set status='SKIPPED'where id=j.id;
    update public.marketing_calendar_items set status='SKIPPED'where id=i.id;
    r:=jsonb_build_object('outcome','SANDBOXED','job_id',j.id);
  elsif p_outcome='RETRYABLE_FAILURE'and j.attempt_count<20 then
    update public.social_publication_jobs set status='QUEUED',
      available_at=clock_timestamp()+make_interval(secs=>least(3600,30*(2^least(j.attempt_count,7))::integer))
      where id=j.id;
    update public.marketing_calendar_items set status='SCHEDULED'where id=i.id;
    r:=jsonb_build_object('outcome','RETRY_SCHEDULED','job_id',j.id,'attempt',j.attempt_count);
  else
    update public.social_publication_jobs set status='FAILED'where id=j.id;
    update public.marketing_calendar_items set status='FAILED'where id=i.id;
    r:=jsonb_build_object('outcome','PERMANENT_FAILURE','job_id',j.id,'error_code',p_error_code);
  end if;
  insert into public.audit_events(
    organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash
  ) values(j.organization_id,null,'SERVICE','marketing.publication.worker_result','social_publication_job',
    j.id::text,p_correlation_id,jsonb_build_object('outcome',p_outcome,'attempt',j.attempt_count,'error_code',p_error_code),repeat('0',64));
  insert into public.event_outbox(
    organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key
  ) values(j.organization_id,'social_publication_job',j.id::text,
    case when p_outcome='PUBLISHED'then'SocialPublicationRecordedV1'
      when p_outcome='SANDBOXED'then'SocialPublicationSandboxedV1'
      when p_outcome='RETRYABLE_FAILURE'then'SocialPublicationRetryScheduledV1'
      else'SocialPublicationFailedV1'end,p_correlation_id,r,p_idempotency_key);
  return r;
end$$;

revoke all on function private.marketing_publication_ready_v41(uuid,text,uuid,uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.schedule_marketing_campaign(uuid,jsonb,integer,text,uuid),
  public.record_social_publication_worker_result_v41(uuid,text,text,text,text,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.schedule_marketing_campaign(uuid,jsonb,integer,text,uuid) to authenticated;
grant execute on function public.record_social_publication_worker_result_v41(uuid,text,text,text,text,uuid) to service_role;
notify pgrst,'reload schema';
