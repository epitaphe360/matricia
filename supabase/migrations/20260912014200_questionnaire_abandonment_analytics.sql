-- MAT-FUNC-044: privacy-preserving questionnaire abandonment analytics.
-- Only finalized, thresholded aggregates are exposed. No answer value, user id or organization id is persisted here.

create table public.questionnaire_abandonment_policy_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  version integer not null unique check (version > 0),
  status text not null check (status in ('ACTIVE','RETIRED')),
  minimum_group_size integer not null check (minimum_group_size >= 5),
  aggregation_period_days integer not null check (aggregation_period_days between 7 and 31),
  retention_days integer not null check (retention_days between 90 and 1095),
  effective_from timestamptz not null,
  effective_to timestamptz,
  decision_reason text not null check (length(btrim(decision_reason)) between 10 and 500),
  content_hash text not null unique check (content_hash ~ '^[0-9a-f]{64}$'),
  activation_source text not null check (activation_source in ('SYSTEM_BASELINE','HUMAN_DECISION')),
  created_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  correlation_id uuid not null,
  check (effective_to is null or effective_to > effective_from),
  check ((activation_source='SYSTEM_BASELINE')=(created_by is null))
);
create unique index questionnaire_abandonment_one_active_policy_uidx
  on public.questionnaire_abandonment_policy_versions((status)) where status='ACTIVE';

create table private.questionnaire_abandonment_snapshots (
  id uuid primary key default extensions.gen_random_uuid(),
  policy_version_id uuid not null references public.questionnaire_abandonment_policy_versions(id) on delete restrict,
  policy_version integer not null check (policy_version > 0),
  questionnaire_id uuid not null references public.questionnaires(id) on delete restrict,
  questionnaire_version_id uuid not null references public.questionnaire_versions(id) on delete restrict,
  questionnaire_version integer not null check (questionnaire_version > 0),
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  dimension_type text not null check (dimension_type in ('QUESTIONNAIRE','SECTION','QUESTION')),
  section_id uuid references public.questionnaire_sections(id) on delete restrict,
  question_version_id uuid references public.question_versions(id) on delete restrict,
  dimension_order integer not null check (dimension_order >= 0),
  label_fr text not null check (length(btrim(label_fr)) between 1 and 1000),
  label_ar text not null check (length(btrim(label_ar)) between 1 and 1000),
  period_start date not null,
  period_end date not null,
  sample_count integer not null check (sample_count >= 5),
  abandonment_count integer not null check (abandonment_count between 0 and sample_count),
  abandonment_rate_bps integer not null check (abandonment_rate_bps between 0 and 10000),
  source_fingerprint text not null check (source_fingerprint ~ '^[0-9a-f]{64}$'),
  computed_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null,
  correlation_id uuid not null,
  check (period_end >= period_start),
  check (expires_at > computed_at),
  check (
    (dimension_type='QUESTIONNAIRE' and section_id is null and question_version_id is null and dimension_order=0)
    or (dimension_type='SECTION' and section_id is not null and question_version_id is null and dimension_order>0)
    or (dimension_type='QUESTION' and section_id is not null and question_version_id is not null and dimension_order>0)
  ),
  unique nulls not distinct (policy_version_id,questionnaire_version_id,dimension_type,section_id,question_version_id,period_start,period_end)
);

create table private.questionnaire_analytics_command_keys (
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key text not null check (length(idempotency_key) between 8 and 200),
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  response_body jsonb not null check (jsonb_typeof(response_body)='object'),
  completed_at timestamptz not null default clock_timestamp(),
  primary key (actor_user_id,idempotency_key)
);

create function private.protect_questionnaire_abandonment_policy_history() returns trigger
language plpgsql set search_path=pg_catalog as $$
begin
  if tg_op='DELETE' or old.status<>'ACTIVE' or new.status<>'RETIRED' or new.effective_to is null
     or (to_jsonb(new)-array['status','effective_to']) is distinct from (to_jsonb(old)-array['status','effective_to']) then
    raise exception 'QUESTIONNAIRE_ANALYTICS_POLICY_IMMUTABLE' using errcode='55000';
  end if;
  return new;
end $$;

create function private.protect_questionnaire_abandonment_snapshot() returns trigger
language plpgsql set search_path=pg_catalog as $$
begin
  if tg_op='DELETE' and old.expires_at <= statement_timestamp() then return old; end if;
  raise exception 'QUESTIONNAIRE_ANALYTICS_SNAPSHOT_IMMUTABLE' using errcode='55000';
end $$;

create trigger questionnaire_abandonment_policy_history_guard before update or delete
  on public.questionnaire_abandonment_policy_versions for each row execute function private.protect_questionnaire_abandonment_policy_history();
create trigger questionnaire_abandonment_snapshot_guard before update or delete
  on private.questionnaire_abandonment_snapshots for each row execute function private.protect_questionnaire_abandonment_snapshot();

insert into public.questionnaire_abandonment_policy_versions(
  version,status,minimum_group_size,aggregation_period_days,retention_days,effective_from,decision_reason,content_hash,activation_source,created_by,correlation_id
) values (
  1,'ACTIVE',10,7,365,'2026-09-12T00:00:00Z','Baseline de confidentialité MAT-FUNC-044 : cohortes hebdomadaires de dix sessions minimum.',
  encode(extensions.digest(convert_to('{"version":1,"minimum_group_size":10,"aggregation_period_days":7,"retention_days":365}'::text,'UTF8'),'sha256'),'hex'),
  'SYSTEM_BASELINE',null,extensions.gen_random_uuid()
);

create function public.publish_questionnaire_abandonment_policy(
  p_minimum_group_size integer,
  p_aggregation_period_days integer,
  p_retention_days integer,
  p_decision_reason text,
  p_idempotency_key text,
  p_correlation_id uuid
) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare
  v_actor uuid:=auth.uid(); v_hash text; v_existing private.questionnaire_analytics_command_keys%rowtype;
  v_version integer; v_id uuid; v_response jsonb; v_now timestamptz:=clock_timestamp();
begin
  if v_actor is null or auth.jwt()->>'aal' is distinct from 'aal2'
     or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],v_actor) then
    raise exception 'QUESTIONNAIRE_ANALYTICS_POLICY_MFA_REQUIRED' using errcode='42501';
  end if;
  if p_minimum_group_size<5 or p_aggregation_period_days not between 7 and 31
     or p_retention_days not between 90 and 1095
     or length(btrim(coalesce(p_decision_reason,''))) not between 10 and 500
     or length(coalesce(p_idempotency_key,'')) not between 8 and 200 or p_correlation_id is null then
    raise exception 'INVALID_QUESTIONNAIRE_ANALYTICS_POLICY' using errcode='22023';
  end if;
  v_hash:=encode(extensions.digest(convert_to(jsonb_build_object(
    'minimum_group_size',p_minimum_group_size,'aggregation_period_days',p_aggregation_period_days,
    'retention_days',p_retention_days,'decision_reason',btrim(p_decision_reason))::text,'UTF8'),'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended('questionnaire-abandonment-policy:'||p_idempotency_key,0));
  select * into v_existing from private.questionnaire_analytics_command_keys
    where actor_user_id=v_actor and idempotency_key=p_idempotency_key;
  if found then
    if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_KEY_REUSED' using errcode='23505'; end if;
    return v_existing.response_body;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('questionnaire-abandonment-policy-version',0));
  select coalesce(max(version),0)+1 into v_version from public.questionnaire_abandonment_policy_versions;
  update public.questionnaire_abandonment_policy_versions set status='RETIRED',effective_to=v_now where status='ACTIVE';
  insert into public.questionnaire_abandonment_policy_versions(
    version,status,minimum_group_size,aggregation_period_days,retention_days,effective_from,decision_reason,content_hash,activation_source,created_by,correlation_id
  ) values (v_version,'ACTIVE',p_minimum_group_size,p_aggregation_period_days,p_retention_days,v_now,btrim(p_decision_reason),v_hash,'HUMAN_DECISION',v_actor,p_correlation_id)
  returning id into v_id;
  v_response:=jsonb_build_object('outcome','QUESTIONNAIRE_ABANDONMENT_POLICY_PUBLISHED','policy_version_id',v_id,'version',v_version,'content_hash',v_hash);
  insert into private.questionnaire_analytics_command_keys(actor_user_id,idempotency_key,request_hash,response_body)
    values(v_actor,p_idempotency_key,v_hash,v_response);
  insert into public.audit_events(actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
    values(v_actor,'USER','questionnaire.analytics.policy.published','questionnaire_abandonment_policy',v_id::text,p_correlation_id,
      jsonb_build_object('version',v_version,'minimum_group_size',p_minimum_group_size,'aggregation_period_days',p_aggregation_period_days,'retention_days',p_retention_days,'decision_reason',btrim(p_decision_reason),'content_hash',v_hash),repeat('0',64));
  insert into public.event_outbox(aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
    values('questionnaire_abandonment_policy',v_id::text,'QuestionnaireAbandonmentPolicyPublishedV1',p_correlation_id,v_response,p_idempotency_key);
  return v_response;
end $$;

create function private.refresh_questionnaire_abandonment_analytics(
  p_period_start date, p_period_end date, p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare v_policy public.questionnaire_abandonment_policy_versions%rowtype; v_inserted integer:=0; v_count integer;
begin
  select * into v_policy from public.questionnaire_abandonment_policy_versions where status='ACTIVE';
  if not found then raise exception 'QUESTIONNAIRE_ANALYTICS_POLICY_NOT_FOUND' using errcode='P0002'; end if;
  if p_period_start is null or p_period_end is null or p_period_end>=current_date
     or p_period_end-p_period_start+1<>v_policy.aggregation_period_days or p_correlation_id is null then
    raise exception 'INVALID_QUESTIONNAIRE_ANALYTICS_PERIOD' using errcode='22023';
  end if;

  with cohort as (
    select s.id,s.questionnaire_version_id,s.status
    from public.questionnaire_sessions s
    where not s.is_simulation and s.started_at>=p_period_start::timestamptz and s.started_at<(p_period_end+1)::timestamptz
  ), grouped as (
    select v.questionnaire_id,c.questionnaire_version_id,v.library_id,v.version,v.title_fr,v.title_ar,
      count(*)::integer sample_count,count(*)filter(where c.status in('ABANDONED','EXPIRED'))::integer abandonment_count
    from cohort c join public.questionnaire_versions v on v.id=c.questionnaire_version_id
    group by v.questionnaire_id,c.questionnaire_version_id,v.library_id,v.version,v.title_fr,v.title_ar
    having count(*)>=v_policy.minimum_group_size
  )
  insert into private.questionnaire_abandonment_snapshots(policy_version_id,policy_version,questionnaire_id,questionnaire_version_id,questionnaire_version,library_id,dimension_type,dimension_order,label_fr,label_ar,period_start,period_end,sample_count,abandonment_count,abandonment_rate_bps,source_fingerprint,expires_at,correlation_id)
  select v_policy.id,v_policy.version,g.questionnaire_id,g.questionnaire_version_id,g.version,g.library_id,'QUESTIONNAIRE',0,g.title_fr,g.title_ar,p_period_start,p_period_end,g.sample_count,g.abandonment_count,(g.abandonment_count::bigint*10000/g.sample_count)::integer,
    encode(extensions.digest(convert_to(jsonb_build_object('policy',v_policy.content_hash,'period_start',p_period_start,'period_end',p_period_end,'questionnaire_version_id',g.questionnaire_version_id,'sample_count',g.sample_count,'abandonment_count',g.abandonment_count)::text,'UTF8'),'sha256'),'hex'),
    clock_timestamp()+make_interval(days=>v_policy.retention_days),p_correlation_id
  from grouped g on conflict do nothing;
  get diagnostics v_count=row_count; v_inserted:=v_inserted+v_count;

  with cohort as (
    select s.id,s.questionnaire_version_id,s.status
    from public.questionnaire_sessions s
    where not s.is_simulation and s.started_at>=p_period_start::timestamptz and s.started_at<(p_period_end+1)::timestamptz
  ), answered as (
    select distinct c.id,c.questionnaire_version_id,c.status,x.section_id
    from cohort c join public.questionnaire_answers a on a.session_id=c.id
    join public.questionnaire_answer_revisions r on r.id=a.current_revision_id and r.value<>'null'::jsonb
    join public.questionnaire_version_questions x on x.questionnaire_version_id=c.questionnaire_version_id and x.question_version_id=a.question_version_id
  ), latest as (
    select distinct on(c.id) c.id,x.section_id
    from cohort c join public.questionnaire_answers a on a.session_id=c.id
    join public.questionnaire_answer_revisions r on r.id=a.current_revision_id and r.value<>'null'::jsonb
    join public.questionnaire_version_questions x on x.questionnaire_version_id=c.questionnaire_version_id and x.question_version_id=a.question_version_id
    order by c.id,r.answered_at desc,x.sort_order desc
  ), grouped as (
    select v.questionnaire_id,a.questionnaire_version_id,v.library_id,v.version,a.section_id,s.sort_order,s.label_fr,s.label_ar,
      count(*)::integer sample_count,count(*)filter(where a.status in('ABANDONED','EXPIRED')and l.section_id=a.section_id)::integer abandonment_count
    from answered a join latest l on l.id=a.id join public.questionnaire_versions v on v.id=a.questionnaire_version_id
    join public.questionnaire_sections s on s.id=a.section_id
    group by v.questionnaire_id,a.questionnaire_version_id,v.library_id,v.version,a.section_id,s.sort_order,s.label_fr,s.label_ar
    having count(*)>=v_policy.minimum_group_size
  )
  insert into private.questionnaire_abandonment_snapshots(policy_version_id,policy_version,questionnaire_id,questionnaire_version_id,questionnaire_version,library_id,dimension_type,section_id,dimension_order,label_fr,label_ar,period_start,period_end,sample_count,abandonment_count,abandonment_rate_bps,source_fingerprint,expires_at,correlation_id)
  select v_policy.id,v_policy.version,g.questionnaire_id,g.questionnaire_version_id,g.version,g.library_id,'SECTION',g.section_id,g.sort_order,g.label_fr,g.label_ar,p_period_start,p_period_end,g.sample_count,g.abandonment_count,(g.abandonment_count::bigint*10000/g.sample_count)::integer,
    encode(extensions.digest(convert_to(jsonb_build_object('policy',v_policy.content_hash,'period_start',p_period_start,'period_end',p_period_end,'section_id',g.section_id,'sample_count',g.sample_count,'abandonment_count',g.abandonment_count)::text,'UTF8'),'sha256'),'hex'),
    clock_timestamp()+make_interval(days=>v_policy.retention_days),p_correlation_id
  from grouped g on conflict do nothing;
  get diagnostics v_count=row_count; v_inserted:=v_inserted+v_count;

  with cohort as (
    select s.id,s.questionnaire_version_id,s.status
    from public.questionnaire_sessions s
    where not s.is_simulation and s.started_at>=p_period_start::timestamptz and s.started_at<(p_period_end+1)::timestamptz
  ), answered as (
    select distinct c.id,c.questionnaire_version_id,c.status,x.section_id,x.question_version_id,x.sort_order
    from cohort c join public.questionnaire_answers a on a.session_id=c.id
    join public.questionnaire_answer_revisions r on r.id=a.current_revision_id and r.value<>'null'::jsonb
    join public.questionnaire_version_questions x on x.questionnaire_version_id=c.questionnaire_version_id and x.question_version_id=a.question_version_id
  ), latest as (
    select distinct on(c.id) c.id,x.question_version_id
    from cohort c join public.questionnaire_answers a on a.session_id=c.id
    join public.questionnaire_answer_revisions r on r.id=a.current_revision_id and r.value<>'null'::jsonb
    join public.questionnaire_version_questions x on x.questionnaire_version_id=c.questionnaire_version_id and x.question_version_id=a.question_version_id
    order by c.id,r.answered_at desc,x.sort_order desc
  ), grouped as (
    select v.questionnaire_id,a.questionnaire_version_id,v.library_id,v.version,a.section_id,a.question_version_id,a.sort_order,q.label_fr,q.label_ar,
      count(*)::integer sample_count,count(*)filter(where a.status in('ABANDONED','EXPIRED')and l.question_version_id=a.question_version_id)::integer abandonment_count
    from answered a join latest l on l.id=a.id join public.questionnaire_versions v on v.id=a.questionnaire_version_id
    join public.question_versions q on q.id=a.question_version_id
    group by v.questionnaire_id,a.questionnaire_version_id,v.library_id,v.version,a.section_id,a.question_version_id,a.sort_order,q.label_fr,q.label_ar
    having count(*)>=v_policy.minimum_group_size
  )
  insert into private.questionnaire_abandonment_snapshots(policy_version_id,policy_version,questionnaire_id,questionnaire_version_id,questionnaire_version,library_id,dimension_type,section_id,question_version_id,dimension_order,label_fr,label_ar,period_start,period_end,sample_count,abandonment_count,abandonment_rate_bps,source_fingerprint,expires_at,correlation_id)
  select v_policy.id,v_policy.version,g.questionnaire_id,g.questionnaire_version_id,g.version,g.library_id,'QUESTION',g.section_id,g.question_version_id,g.sort_order,g.label_fr,g.label_ar,p_period_start,p_period_end,g.sample_count,g.abandonment_count,(g.abandonment_count::bigint*10000/g.sample_count)::integer,
    encode(extensions.digest(convert_to(jsonb_build_object('policy',v_policy.content_hash,'period_start',p_period_start,'period_end',p_period_end,'question_version_id',g.question_version_id,'sample_count',g.sample_count,'abandonment_count',g.abandonment_count)::text,'UTF8'),'sha256'),'hex'),
    clock_timestamp()+make_interval(days=>v_policy.retention_days),p_correlation_id
  from grouped g on conflict do nothing;
  get diagnostics v_count=row_count; v_inserted:=v_inserted+v_count;

  insert into public.audit_events(actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
    values('SERVICE','questionnaire.analytics.snapshot.refreshed','questionnaire_abandonment_snapshot',p_period_start::text||'/'||p_period_end::text,p_correlation_id,
      jsonb_build_object('policy_version',v_policy.version,'period_start',p_period_start,'period_end',p_period_end,'aggregate_count',v_inserted),repeat('0',64));
  return jsonb_build_object('outcome','QUESTIONNAIRE_ABANDONMENT_SNAPSHOT_REFRESHED','policy_version',v_policy.version,'aggregate_count',v_inserted,'period_start',p_period_start,'period_end',p_period_end);
end $$;

create function private.purge_expired_questionnaire_abandonment_analytics(p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare v_deleted integer;
begin
  if p_correlation_id is null then raise exception 'INVALID_CORRELATION_ID' using errcode='22023'; end if;
  delete from private.questionnaire_abandonment_snapshots where expires_at<=statement_timestamp();
  get diagnostics v_deleted=row_count;
  insert into public.audit_events(actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
    values('SERVICE','questionnaire.analytics.retention.purged','questionnaire_abandonment_snapshot','expired',p_correlation_id,jsonb_build_object('deleted_aggregate_count',v_deleted),repeat('0',64));
  return jsonb_build_object('outcome','QUESTIONNAIRE_ABANDONMENT_RETENTION_APPLIED','deleted_aggregate_count',v_deleted);
end $$;

create function public.get_questionnaire_abandonment_policy()
returns table(policy_version integer,minimum_group_size integer,aggregation_period_days integer,retention_days integer,effective_from timestamptz)
language plpgsql stable security definer set search_path=pg_catalog as $$
begin
  if auth.uid() is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','LIBRARY_MANAGER','READ_ONLY_AUDITOR'],auth.uid()) then
    raise exception 'QUESTIONNAIRE_ANALYTICS_READ_DENIED' using errcode='42501';
  end if;
  return query select p.version,p.minimum_group_size,p.aggregation_period_days,p.retention_days,p.effective_from
    from public.questionnaire_abandonment_policy_versions p where p.status='ACTIVE' limit 1;
end $$;

create function public.get_questionnaire_abandonment_analytics(
  p_from date, p_to date, p_questionnaire_version_id uuid default null, p_limit integer default 300
) returns table(
  policy_version integer,minimum_group_size integer,questionnaire_id uuid,questionnaire_version_id uuid,questionnaire_version integer,
  dimension_type text,section_id uuid,question_version_id uuid,dimension_order integer,label_fr text,label_ar text,
  period_start date,period_end date,sample_count integer,abandonment_count integer,abandonment_rate_bps integer
) language plpgsql stable security definer set search_path=pg_catalog as $$
begin
  if auth.uid() is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','LIBRARY_MANAGER','READ_ONLY_AUDITOR'],auth.uid()) then
    raise exception 'QUESTIONNAIRE_ANALYTICS_READ_DENIED' using errcode='42501';
  end if;
  if p_from is null or p_to is null or p_from>p_to or p_to>current_date or p_to-p_from>366 or p_limit not between 1 and 500 then
    raise exception 'INVALID_QUESTIONNAIRE_ANALYTICS_QUERY' using errcode='22023';
  end if;
  return query
    select s.policy_version,p.minimum_group_size,s.questionnaire_id,s.questionnaire_version_id,s.questionnaire_version,
      s.dimension_type,s.section_id,s.question_version_id,s.dimension_order,s.label_fr,s.label_ar,s.period_start,s.period_end,
      s.sample_count,s.abandonment_count,s.abandonment_rate_bps
    from private.questionnaire_abandonment_snapshots s
    join public.questionnaire_abandonment_policy_versions p on p.id=s.policy_version_id
    where s.period_start>=p_from and s.period_end<=p_to and s.expires_at>statement_timestamp()
      and (p_questionnaire_version_id is null or s.questionnaire_version_id=p_questionnaire_version_id)
    order by s.period_end desc,s.questionnaire_version_id,s.dimension_type,s.dimension_order
    limit p_limit;
end $$;

alter table public.questionnaire_abandonment_policy_versions enable row level security;
alter table private.questionnaire_abandonment_snapshots enable row level security;
alter table private.questionnaire_analytics_command_keys enable row level security;

revoke all on public.questionnaire_abandonment_policy_versions from public,anon,authenticated,service_role;
revoke all on private.questionnaire_abandonment_snapshots,private.questionnaire_analytics_command_keys from public,anon,authenticated,service_role;
revoke all on function private.protect_questionnaire_abandonment_policy_history(),private.protect_questionnaire_abandonment_snapshot(),
  private.refresh_questionnaire_abandonment_analytics(date,date,uuid),private.purge_expired_questionnaire_abandonment_analytics(uuid),
  public.publish_questionnaire_abandonment_policy(integer,integer,integer,text,text,uuid),public.get_questionnaire_abandonment_policy(),
  public.get_questionnaire_abandonment_analytics(date,date,uuid,integer) from public,anon,authenticated,service_role;
grant execute on function private.refresh_questionnaire_abandonment_analytics(date,date,uuid),private.purge_expired_questionnaire_abandonment_analytics(uuid) to service_role;
grant execute on function public.publish_questionnaire_abandonment_policy(integer,integer,integer,text,text,uuid),public.get_questionnaire_abandonment_policy(),
  public.get_questionnaire_abandonment_analytics(date,date,uuid,integer) to authenticated;

create index questionnaire_abandonment_snapshot_query_idx on private.questionnaire_abandonment_snapshots(period_end desc,questionnaire_version_id,dimension_type,dimension_order) where expires_at is not null;
create index questionnaire_abandonment_snapshot_retention_idx on private.questionnaire_abandonment_snapshots(expires_at);

notify pgrst,'reload schema';
