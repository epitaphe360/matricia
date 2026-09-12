-- P2 MAT-FUNC-064: bound scheduler selection before any digest composition work.
create index franchise_digest_config_scheduler_cover_idx on public.franchise_daily_digest_config_versions(franchise_id,recipient_user_id,version desc)include(id,policy_version_id,enabled,frequency,local_send_time,time_zone,locale);

create or replace function public.schedule_franchise_daily_digests(p_now timestamptz default clock_timestamp(),p_limit integer default 100)returns setof jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare c record;d uuid;j uuid;s jsonb;org uuid;corr uuid;local_date date;pipeline jsonb;perf jsonb;
begin
 if auth.role()<>'service_role'then raise exception'FRANCHISE_DIGEST_SCHEDULER_ONLY'using errcode='42501';end if;
 if p_limit not between 1 and 500 then raise exception'INVALID_FRANCHISE_DIGEST_SCHEDULE_LIMIT'using errcode='22023';end if;
 for c in
  select v.*
  from public.franchise_daily_digest_config_versions v
  join public.franchises f on f.id=v.franchise_id and f.status='ACTIVE'
  where not exists(select 1 from public.franchise_daily_digest_config_versions newer where newer.franchise_id=v.franchise_id and newer.recipient_user_id=v.recipient_user_id and newer.version>v.version)
   and v.enabled
   and timezone(v.time_zone,p_now)::time>=v.local_send_time
   and(v.frequency='DAILY'or(v.frequency='WEEKDAYS'and extract(isodow from timezone(v.time_zone,p_now))between 1 and 5))
   and private.franchise_digest_role_access(v.franchise_id,false,v.recipient_user_id)
   and not exists(
    select 1 from public.franchise_daily_digests prior_digest
    join public.franchise_daily_digest_jobs prior_job on prior_job.digest_id=prior_digest.id and prior_job.recipient_user_id=v.recipient_user_id
    where prior_digest.franchise_id=v.franchise_id and prior_digest.digest_date=timezone(v.time_zone,p_now)::date and prior_digest.locale=v.locale
   )
  order by v.franchise_id,v.recipient_user_id
  limit p_limit
 loop
  local_date:=timezone(c.time_zone,p_now)::date;corr:=extensions.gen_random_uuid();select operator_organization_id into org from public.franchises where id=c.franchise_id;
  select coalesce(jsonb_object_agg(x.pipeline_stage,x.stage_count),'{}'::jsonb)into pipeline from(select pipeline_stage,count(*)::bigint stage_count from public.franchise_crm_prospects where franchise_id=c.franchise_id group by pipeline_stage order by pipeline_stage limit(select max_pipeline_stages from public.franchise_daily_digest_policy_versions where id=c.policy_version_id))x;
  select coalesce((select jsonb_build_object('global_score_basis_points',q.global_score_basis_points,'library_quality_score_basis_points',q.library_quality_score_basis_points,'health_suggestion',q.health_suggestion,'period_end',q.period_end)from public.franchise_performance_score_snapshots q where q.franchise_id=c.franchise_id order by q.period_end desc,q.created_at desc limit 1),jsonb_build_object('global_score_basis_points',null,'library_quality_score_basis_points',null,'health_suggestion','NOT_MEASURED','period_end',null))into perf;
  s:=jsonb_build_object(
   'policy_version',(select version from public.franchise_daily_digest_policy_versions where id=c.policy_version_id),
   'crm',jsonb_build_object('total_prospects',(select count(*) from public.franchise_crm_prospects where franchise_id=c.franchise_id),'client_prospects',(select count(*) from public.franchise_crm_prospects where franchise_id=c.franchise_id and prospect_type='CLIENT'),'provider_prospects',(select count(*) from public.franchise_crm_prospects where franchise_id=c.franchise_id and prospect_type='PROVIDER'),'pipeline',pipeline),
   'followups',jsonb_build_object('overdue',(select count(*) from public.franchise_crm_prospects where franchise_id=c.franchise_id and next_followup_at<p_now),'next_24_hours',(select count(*) from public.franchise_crm_prospects where franchise_id=c.franchise_id and next_followup_at>=p_now and next_followup_at<p_now+interval'24 hours')),
   'performance',perf,
   'alerts',jsonb_build_object('open_total',(select count(*) from public.franchise_performance_alerts where franchise_id=c.franchise_id and status='OPEN'),'critical',(select count(*) from public.franchise_performance_alerts where franchise_id=c.franchise_id and status='OPEN'and severity='CRITICAL'),'warning',(select count(*) from public.franchise_performance_alerts where franchise_id=c.franchise_id and status='OPEN'and severity='WARNING')),
   'objectives',jsonb_build_object('active',(select count(*) from public.franchise_performance_objective_versions where franchise_id=c.franchise_id and status='ACTIVE'),'overdue',(select count(*) from public.franchise_performance_objective_versions where franchise_id=c.franchise_id and status='ACTIVE'and due_on<local_date),'due_today',(select count(*) from public.franchise_performance_objective_versions where franchise_id=c.franchise_id and status='ACTIVE'and due_on=local_date)));
  insert into public.franchise_daily_digests(franchise_id,organization_id,digest_date,locale,policy_version_id,metrics_snapshot,snapshot_hash,generated_at,correlation_id)
  values(c.franchise_id,org,local_date,c.locale,c.policy_version_id,s,private.canonical_request_hash(s),p_now,corr)on conflict(franchise_id,digest_date,locale)do nothing returning id into d;
  if d is null then select id into d from public.franchise_daily_digests where franchise_id=c.franchise_id and digest_date=local_date and locale=c.locale;end if;
  insert into public.franchise_daily_digest_jobs(digest_id,franchise_id,recipient_user_id,config_version_id,next_attempt_at)values(d,c.franchise_id,c.recipient_user_id,c.id,p_now)on conflict(digest_id,recipient_user_id)do nothing returning id into j;
  if j is not null then
   insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(org,null,'SYSTEM','franchise.daily_digest.scheduled','franchise_daily_digest_job',j::text,corr,jsonb_build_object('franchise_id',c.franchise_id,'digest_id',d,'digest_date',local_date,'locale',c.locale,'policy_version_id',c.policy_version_id),repeat('0',64));
   insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(org,'franchise_daily_digest_job',j::text,'FranchiseDailyDigestScheduledV1',corr,jsonb_build_object('job_id',j,'digest_id',d,'franchise_id',c.franchise_id,'digest_date',local_date,'locale',c.locale),'schedule:'||d::text||':'||c.recipient_user_id::text);
   return next jsonb_build_object('job_id',j,'digest_id',d,'digest_date',local_date,'locale',c.locale);
  end if;
 end loop;return;
end$$;

revoke all on function public.schedule_franchise_daily_digests(timestamptz,integer)from public,anon,authenticated,service_role;
grant execute on function public.schedule_franchise_daily_digests(timestamptz,integer)to service_role;
