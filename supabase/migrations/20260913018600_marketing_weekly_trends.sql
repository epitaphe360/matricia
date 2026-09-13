-- MARKETING-007: privacy-thresholded weekly trends generated from real diagnostics.

create table public.marketing_trend_policy_versions(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete restrict,
  version integer not null check(version>0),
  status text not null check(status in('ACTIVE','RETIRED')),
  privacy_policy_version text not null check(length(btrim(privacy_policy_version))between 1 and 100),
  minimum_aggregate_size integer not null check(minimum_aggregate_size between 10 and 1000),
  minimum_anomaly_count integer not null check(minimum_anomaly_count between 1 and 1000000),
  minimum_growth_basis_points integer not null check(minimum_growth_basis_points between 1 and 1000000),
  effective_from timestamptz not null,
  effective_until timestamptz,
  policy_hash text not null check(policy_hash~'^[0-9a-f]{64}$'),
  created_at timestamptz not null default clock_timestamp(),
  unique nulls not distinct(organization_id,version),
  check(effective_until is null or effective_until>effective_from)
);

insert into public.marketing_trend_policy_versions(
  id,organization_id,version,status,privacy_policy_version,minimum_aggregate_size,minimum_anomaly_count,
  minimum_growth_basis_points,effective_from,policy_hash
)values(
  '00000000-0000-4000-8000-000000000186',null,1,'ACTIVE','MARKETING-PRIVACY-V1',10,10,1000,
  '2026-01-01 00:00:00+00',encode(extensions.digest('MARKETING-PRIVACY-V1|10|10|1000','sha256'),'hex')
);

alter table public.marketing_trend_policy_versions enable row level security;
alter table public.marketing_trend_policy_versions force row level security;
revoke all on public.marketing_trend_policy_versions from public,anon,authenticated,service_role;
create policy marketing_trend_policy_scoped_read on public.marketing_trend_policy_versions
  for select to authenticated
  using(
    private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'])
    or(organization_id is not null and private.marketing_manage_access(organization_id))
  );
grant select on public.marketing_trend_policy_versions to authenticated;
create trigger marketing_trend_policy_versions_immutable before update or delete
  on public.marketing_trend_policy_versions for each row execute function private.prevent_marketing_history_change();

-- The original nullable UNIQUE constraint does not deduplicate NULL dimensions.
create unique index marketing_trend_snapshots_weekly_source_uidx
  on public.marketing_trend_snapshots(organization_id,library_id,service_id,period_start,period_end,source_hash)
  nulls not distinct;

create index marketing_trend_policy_effective_idx
  on public.marketing_trend_policy_versions(organization_id,effective_from desc,version desc)
  where status='ACTIVE';
create index diagnostic_anomalies_weekly_trends_idx
  on public.diagnostic_anomalies(organization_id,created_at,diagnostic_run_id);
create index diagnostic_recommendations_weekly_trends_idx
  on public.diagnostic_recommendations(organization_id,diagnostic_run_id,service_id,anomaly_id);

create table private.marketing_trend_generation_checkpoints(
  week_start date primary key,
  resume_cursor text,
  completed boolean not null default false,
  updated_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  check(resume_cursor is null or resume_cursor~'^[0-9a-f-]{36}\|[0-9a-f-]{36}\|[0-9a-f-]{36}$'),
  check((not completed and completed_at is null)or(completed and completed_at is not null))
);
revoke all on private.marketing_trend_generation_checkpoints from public,anon,authenticated,service_role;

create function public.generate_weekly_marketing_trends_v1(
  p_idempotency_key text,
  p_week_start date default null,
  p_limit integer default 100,
  p_correlation_id uuid default extensions.gen_random_uuid(),
  p_cursor text default null
)returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare
  target_week date:=coalesce(p_week_start,date_trunc('week',current_date)::date-7);
  week_end date;
  command_scope text;
  request_hash text;
  cached jsonb;
  response jsonb;
  group_row record;
  snapshot_id uuid;
  suggestion_id uuid;
  previous_count bigint;
  growth_bps integer;
  generated_count integer:=0;
  suggestion_count integer:=0;
  skipped_count integer:=0;
  eligible_count integer:=0;
  last_cursor text;
  cursor_org uuid;
  cursor_library uuid;
  cursor_service uuid;
  effective_cursor text;
  checkpoint_completed boolean;
begin
  if auth.role()is distinct from'service_role'then
    raise exception'MARKETING_TREND_GENERATION_DENIED'using errcode='42501';
  end if;
  if length(coalesce(p_idempotency_key,''))not between 8 and 200
    or p_correlation_id is null or p_limit not between 1 and 500
    or extract(isodow from target_week)<>1
    or target_week>=date_trunc('week',current_date)::date then
    raise exception'INVALID_MARKETING_TREND_GENERATION'using errcode='22023';
  end if;
  week_end:=target_week+6;
  if p_cursor is not null and p_cursor!~'^[0-9a-f-]{36}\|[0-9a-f-]{36}\|[0-9a-f-]{36}$'then
      raise exception'INVALID_MARKETING_TREND_CURSOR'using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('marketing-trends-week:'||target_week::text,0));
  insert into private.marketing_trend_generation_checkpoints(week_start)values(target_week)on conflict do nothing;
  select resume_cursor,completed into effective_cursor,checkpoint_completed
  from private.marketing_trend_generation_checkpoints where week_start=target_week for update;
  effective_cursor:=coalesce(p_cursor,effective_cursor);
  if effective_cursor is not null then
    begin
      cursor_org:=split_part(effective_cursor,'|',1)::uuid;
      cursor_library:=split_part(effective_cursor,'|',2)::uuid;
      cursor_service:=split_part(effective_cursor,'|',3)::uuid;
    exception when invalid_text_representation then
      raise exception'INVALID_MARKETING_TREND_CURSOR'using errcode='22023';
    end;
  end if;
  command_scope:='marketing.trends.generate.'||target_week::text||'.'||coalesce(effective_cursor,'START');
  request_hash:=private.canonical_request_hash(jsonb_build_object(
    'operation','GENERATE_WEEKLY_MARKETING_TRENDS_V1','week_start',target_week,'limit',p_limit,'cursor',effective_cursor
  ));
  cached:=private.begin_marketing_worker_command(command_scope,p_idempotency_key,request_hash);
  if cached is not null then return cached;end if;
  if checkpoint_completed then
    response:=jsonb_build_object('outcome','MARKETING_WEEKLY_TRENDS_GENERATED','weekStart',target_week,
      'generatedSnapshots',0,'proposedSuggestions',0,'skippedSuggestions',0,'hasMore',false,'nextCursor',null);
    perform private.finish_marketing_worker_command(command_scope,p_idempotency_key,response);
    return response;
  end if;
  if p_cursor is not null and p_cursor is distinct from(
    select resume_cursor from private.marketing_trend_generation_checkpoints where week_start=target_week
  )then raise exception'MARKETING_TREND_CURSOR_STALE'using errcode='55000';end if;

  for group_row in
    with aggregates as(
      select a.organization_id,r.library_id,s.id service_id,
        count(distinct r.id)::integer aggregate_size,
        count(distinct a.id)::bigint anomaly_count,
        count(distinct a.id)filter(where a.severity in('HIGH','CRITICAL'))::bigint severe_count
      from public.diagnostic_anomalies a
      join public.diagnostic_runs r on r.id=a.diagnostic_run_id and r.organization_id=a.organization_id
      join public.diagnostic_recommendations d on d.diagnostic_run_id=r.id and d.anomaly_id=a.id and d.organization_id=a.organization_id
      join public.catalog_services s on s.id=d.service_id and s.library_id=r.library_id
      where a.created_at>=target_week::timestamptz and a.created_at<(target_week+7)::timestamptz
        and private.marketing_consent_active(a.organization_id,'MARKETING_ANALYTICS')
      group by a.organization_id,r.library_id,s.id
    )
    select x.*,p.privacy_policy_version,p.minimum_aggregate_size,p.minimum_anomaly_count,
      p.minimum_growth_basis_points,p.version policy_version,count(*)over() eligible_count
    from aggregates x
    cross join lateral(
      select v.privacy_policy_version,v.minimum_aggregate_size,v.minimum_anomaly_count,
        v.minimum_growth_basis_points,v.version
      from public.marketing_trend_policy_versions v
      where v.status='ACTIVE'and(v.organization_id=x.organization_id or v.organization_id is null)
        and v.effective_from<(target_week+7)::timestamptz
        and(v.effective_until is null or v.effective_until>=target_week::timestamptz)
      order by(v.organization_id is not null)desc,v.effective_from desc,v.version desc limit 1
    )p
    where x.aggregate_size>=p.minimum_aggregate_size
      and(effective_cursor is null or(x.organization_id::text,x.library_id::text,x.service_id::text)>(cursor_org::text,cursor_library::text,cursor_service::text))
    order by x.organization_id,x.library_id,x.service_id limit p_limit
  loop
    eligible_count:=group_row.eligible_count;
    last_cursor:=group_row.organization_id::text||'|'||group_row.library_id::text||'|'||group_row.service_id::text;
    select count(distinct a.id)::bigint into previous_count
    from public.diagnostic_anomalies a
    join public.diagnostic_runs r on r.id=a.diagnostic_run_id and r.organization_id=a.organization_id
    join public.diagnostic_recommendations d on d.diagnostic_run_id=r.id and d.anomaly_id=a.id and d.organization_id=a.organization_id
    join public.catalog_services s on s.id=d.service_id and s.library_id=r.library_id
    where a.organization_id=group_row.organization_id and r.library_id=group_row.library_id
      and s.id=group_row.service_id and a.created_at>=(target_week-7)::timestamptz
      and a.created_at<target_week::timestamptz;
    growth_bps:=case when previous_count=0 then null else
      greatest(-2147483648,least(2147483647,round(
        ((group_row.anomaly_count-previous_count)::numeric*10000::numeric)/previous_count::numeric
      )))::integer end;

    snapshot_id:=null;
    insert into public.marketing_trend_snapshots(
      organization_id,library_id,service_id,period_start,period_end,segment,
      privacy_policy_version,minimum_aggregate_size,aggregate_size,anomaly_count,growth_basis_points,source_hash
    )values(
      group_row.organization_id,group_row.library_id,group_row.service_id,target_week,week_end,'{}'::jsonb,
      group_row.privacy_policy_version,group_row.minimum_aggregate_size,group_row.aggregate_size,
      group_row.anomaly_count,growth_bps,
      private.canonical_request_hash(jsonb_build_object(
        'week_start',target_week,'week_end',week_end,'organization',group_row.organization_id,
        'library',group_row.library_id,'service',group_row.service_id,'aggregate_size',group_row.aggregate_size,
        'anomaly_count',group_row.anomaly_count,'severe_count',group_row.severe_count,
        'privacy_policy',group_row.privacy_policy_version,'policy_version',group_row.policy_version,
        'minimum_aggregate_size',group_row.minimum_aggregate_size
      ))
    )on conflict do nothing returning id into snapshot_id;
    if snapshot_id is null then
      select id into snapshot_id from public.marketing_trend_snapshots
      where organization_id=group_row.organization_id and library_id=group_row.library_id
        and service_id=group_row.service_id and period_start=target_week and period_end=week_end
      order by created_at desc,id desc limit 1;
      continue;
    end if;
    generated_count:=generated_count+1;

    insert into public.audit_events(
      organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash
    )values(
      group_row.organization_id,null,'SERVICE','marketing.trend.snapshot_generated','marketing_trend_snapshot',snapshot_id::text,
      p_correlation_id,jsonb_build_object('week_start',target_week,'aggregate_size',group_row.aggregate_size,
        'anomaly_count',group_row.anomaly_count,'privacy_policy_version',group_row.privacy_policy_version),repeat('0',64)
    );
    insert into public.event_outbox(
      organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key
    )values(
      group_row.organization_id,'marketing_trend_snapshot',snapshot_id::text,'MarketingTrendSnapshotGeneratedV1',p_correlation_id,
      jsonb_build_object('snapshot_id',snapshot_id,'week_start',target_week,'week_end',week_end,
        'library_id',group_row.library_id,'service_id',group_row.service_id,'aggregate_size',group_row.aggregate_size,
        'anomaly_count',group_row.anomaly_count,'growth_basis_points',growth_bps),
      p_idempotency_key||':snapshot:'||snapshot_id::text
    );

    suggestion_id:=null;
    if group_row.anomaly_count>=group_row.minimum_anomaly_count
      and growth_bps is not null and growth_bps>=group_row.minimum_growth_basis_points
      and private.marketing_consent_active(group_row.organization_id,'MARKETING_ANALYTICS')
      and exists(select 1 from public.brand_kits b where b.organization_id=group_row.organization_id and b.status='READY'and b.current_version_id is not null)
      and coalesce((select ba.decision='GRANTED'and ba.effective_from<=clock_timestamp()
          and(ba.effective_until is null or ba.effective_until>clock_timestamp())
          and ba.authorization_scope&&array['MARKETING_AUTOPILOT','CONTENT_GENERATION']
        from public.marketing_brand_authorizations ba where ba.organization_id=group_row.organization_id
        order by ba.decided_at desc,ba.id desc limit 1),false)
      and not coalesce((select ks.enabled from public.marketing_kill_switch_versions ks
        where ks.organization_id is null and ks.scope='GLOBAL'order by ks.version desc,ks.decided_at desc limit 1),false)
      and not coalesce((select ks.enabled from public.marketing_kill_switch_versions ks
        where ks.organization_id=group_row.organization_id and ks.scope='GLOBAL'order by ks.version desc,ks.decided_at desc limit 1),false)
    then
      insert into public.campaign_suggestions(
        organization_id,trend_snapshot_id,title_fr,title_ar,rationale_fr,rationale_ar,status,risk_score
      )values(
        group_row.organization_id,snapshot_id,'Tendance de service détectée','تم رصد اتجاه للخدمة',
        format('Agrégat hebdomadaire anonyme de %s diagnostics, seuil de confidentialité %s.',group_row.aggregate_size,group_row.minimum_aggregate_size),
        format('تجميع أسبوعي مجهول لـ %s تشخيصات، بحد خصوصية %s.',group_row.aggregate_size,group_row.minimum_aggregate_size),
        'PROPOSED',least(100,greatest(0,round(group_row.severe_count::numeric*100/greatest(group_row.anomaly_count,1))::integer))
      )on conflict(organization_id,trend_snapshot_id)do nothing returning id into suggestion_id;
      if suggestion_id is not null then
        suggestion_count:=suggestion_count+1;
        insert into public.audit_events(
          organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash
        )values(group_row.organization_id,null,'SERVICE','marketing.campaign_suggestion.proposed','campaign_suggestion',suggestion_id::text,
          p_correlation_id,jsonb_build_object('trend_snapshot_id',snapshot_id,'service_id',group_row.service_id),repeat('0',64));
        insert into public.event_outbox(
          organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key
        )values(group_row.organization_id,'campaign_suggestion',suggestion_id::text,'MarketingCampaignSuggestionProposedV1',p_correlation_id,
          jsonb_build_object('suggestion_id',suggestion_id,'trend_snapshot_id',snapshot_id,'service_id',group_row.service_id,'status','PROPOSED'),
          p_idempotency_key||':suggestion:'||suggestion_id::text);
      end if;
    else skipped_count:=skipped_count+1;
    end if;
  end loop;

  response:=jsonb_build_object('outcome','MARKETING_WEEKLY_TRENDS_GENERATED','weekStart',target_week,
    'generatedSnapshots',generated_count,'proposedSuggestions',suggestion_count,'skippedSuggestions',skipped_count,
    'hasMore',eligible_count>p_limit,'nextCursor',case when eligible_count>p_limit then last_cursor else null end);
  update private.marketing_trend_generation_checkpoints set
    resume_cursor=case when eligible_count>p_limit then last_cursor else resume_cursor end,
    completed=not(eligible_count>p_limit),updated_at=clock_timestamp(),
    completed_at=case when eligible_count>p_limit then null else clock_timestamp()end
  where week_start=target_week;
  perform private.finish_marketing_worker_command(command_scope,p_idempotency_key,response);
  return response;
end$$;

revoke all on function public.generate_weekly_marketing_trends_v1(text,date,integer,uuid,text)
  from public,anon,authenticated,service_role;
grant execute on function public.generate_weekly_marketing_trends_v1(text,date,integer,uuid,text) to service_role;
notify pgrst,'reload schema';
