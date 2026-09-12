-- MAT-FUNC-064: configurable, bilingual and non-PII daily franchise digest.

create table public.franchise_daily_digest_policy_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  version integer not null unique check(version>0),
  status text not null check(status in('ACTIVE','RETIRED')),
  max_attempts integer not null check(max_attempts between 1 and 12),
  base_backoff_seconds integer not null check(base_backoff_seconds between 30 and 86400),
  max_backoff_seconds integer not null check(max_backoff_seconds between base_backoff_seconds and 604800),
  max_pipeline_stages integer not null check(max_pipeline_stages between 1 and 20),
  effective_from timestamptz not null,
  effective_until timestamptz,
  content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),
  change_reason text not null check(length(btrim(change_reason))between 3 and 1000),
  created_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  check(effective_until is null or effective_until>effective_from)
);
create unique index franchise_digest_one_active_policy_uidx on public.franchise_daily_digest_policy_versions(status)where status='ACTIVE';

create table public.franchise_daily_digest_config_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  franchise_id uuid not null references public.franchises(id)on delete restrict,
  recipient_user_id uuid not null references auth.users(id)on delete restrict,
  version integer not null check(version>0),
  policy_version_id uuid not null references public.franchise_daily_digest_policy_versions(id)on delete restrict,
  enabled boolean not null,
  frequency text not null check(frequency in('DAILY','WEEKDAYS')),
  local_send_time time without time zone not null,
  time_zone text not null check(length(time_zone)between 1 and 100),
  locale text not null check(locale in('fr-MA','ar-MA')),
  supersedes_config_id uuid references public.franchise_daily_digest_config_versions(id)on delete restrict,
  change_reason text not null check(length(btrim(change_reason))between 3 and 1000),
  content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id)on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  unique(franchise_id,recipient_user_id,version),
  unique(id,franchise_id),
  foreign key(supersedes_config_id,franchise_id)references public.franchise_daily_digest_config_versions(id,franchise_id)on delete restrict,
  check(supersedes_config_id is null or version>1)
);

create table public.franchise_daily_digests (
  id uuid primary key default extensions.gen_random_uuid(),
  franchise_id uuid not null references public.franchises(id)on delete restrict,
  organization_id uuid not null references public.organizations(id)on delete restrict,
  digest_date date not null,
  locale text not null check(locale in('fr-MA','ar-MA')),
  policy_version_id uuid not null references public.franchise_daily_digest_policy_versions(id)on delete restrict,
  metrics_snapshot jsonb not null check(jsonb_typeof(metrics_snapshot)='object'),
  snapshot_hash text not null check(snapshot_hash~'^[0-9a-f]{64}$'),
  generated_at timestamptz not null default clock_timestamp(),
  correlation_id uuid not null,
  unique(franchise_id,digest_date,locale),
  unique(id,franchise_id)
);

create table public.franchise_daily_digest_jobs (
  id uuid primary key default extensions.gen_random_uuid(),
  digest_id uuid not null references public.franchise_daily_digests(id)on delete restrict,
  franchise_id uuid not null references public.franchises(id)on delete restrict,
  recipient_user_id uuid not null references auth.users(id)on delete restrict,
  config_version_id uuid not null,
  status text not null default'QUEUED'check(status in('QUEUED','CLAIMED','NOTIFIED','FAILED','DEAD_LETTER')),
  attempt_count integer not null default 0 check(attempt_count>=0),
  next_attempt_at timestamptz,
  lease_token uuid,
  worker_id uuid,
  leased_until timestamptz,
  notification_id uuid references public.notification_instances(id)on delete restrict,
  last_error_code text,
  row_version integer not null default 1 check(row_version>0),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  foreign key(digest_id,franchise_id)references public.franchise_daily_digests(id,franchise_id)on delete restrict,
  foreign key(config_version_id,franchise_id)references public.franchise_daily_digest_config_versions(id,franchise_id)on delete restrict,
  unique(digest_id,recipient_user_id),
  check((status in('QUEUED','FAILED'))=(next_attempt_at is not null)),
  check((status='CLAIMED')=(lease_token is not null and worker_id is not null and leased_until is not null)),
  check((status='NOTIFIED')=(notification_id is not null))
);

create table public.franchise_daily_digest_job_attempts (
  id bigint generated always as identity primary key,
  job_id uuid not null references public.franchise_daily_digest_jobs(id)on delete restrict,
  attempt_number integer not null check(attempt_number>0),
  outcome text not null check(outcome in('NOTIFIED','FAILED','DEAD_LETTER')),
  worker_id uuid not null,
  notification_id uuid references public.notification_instances(id)on delete restrict,
  error_code text,
  result_snapshot jsonb not null check(jsonb_typeof(result_snapshot)='object'),
  idempotency_key text not null check(length(idempotency_key)between 8 and 200),
  correlation_id uuid not null,
  attempted_at timestamptz not null default clock_timestamp(),
  unique(job_id,attempt_number),
  unique(job_id,idempotency_key),
  check((outcome in('FAILED','DEAD_LETTER'))=(error_code is not null))
);

create function private.prevent_franchise_digest_history_change()returns trigger language plpgsql set search_path=pg_catalog as $$begin raise exception'IMMUTABLE_FRANCHISE_DIGEST_HISTORY'using errcode='55000';end$$;
create trigger franchise_digest_policies_immutable before update or delete on public.franchise_daily_digest_policy_versions for each row execute function private.prevent_franchise_digest_history_change();
create trigger franchise_digest_configs_immutable before update or delete on public.franchise_daily_digest_config_versions for each row execute function private.prevent_franchise_digest_history_change();
create trigger franchise_digests_immutable before update or delete on public.franchise_daily_digests for each row execute function private.prevent_franchise_digest_history_change();
create trigger franchise_digest_attempts_immutable before update or delete on public.franchise_daily_digest_job_attempts for each row execute function private.prevent_franchise_digest_history_change();

create function private.valid_franchise_digest_snapshot(p_snapshot jsonb)returns boolean language sql immutable set search_path=pg_catalog as $$
 select jsonb_typeof(p_snapshot)='object'
  and(select array_agg(k order by k)from jsonb_object_keys(p_snapshot)k)=array['alerts','crm','followups','objectives','performance','policy_version']::text[]
  and jsonb_typeof(p_snapshot->'crm')='object'
  and jsonb_typeof(p_snapshot->'alerts')='object'
  and jsonb_typeof(p_snapshot->'followups')='object'
  and jsonb_typeof(p_snapshot->'objectives')='object'
  and jsonb_typeof(p_snapshot->'performance')='object'
  and p_snapshot::text!~*'(name|email|phone|address|contact|secret|token|api.?key|password)'
  and length(p_snapshot::text)<=12000
$$;
create function private.guard_franchise_digest_snapshot()returns trigger language plpgsql set search_path=pg_catalog,private as $$begin if not private.valid_franchise_digest_snapshot(new.metrics_snapshot)then raise exception'INVALID_FRANCHISE_DIGEST_SNAPSHOT'using errcode='23514';end if;return new;end$$;
create trigger franchise_digest_snapshot_guard before insert on public.franchise_daily_digests for each row execute function private.guard_franchise_digest_snapshot();

create function public.configure_franchise_daily_digest(
 p_franchise_id uuid,p_recipient_user_id uuid,p_enabled boolean,p_frequency text,p_local_send_time time without time zone,p_time_zone text,p_locale text,p_change_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();org uuid;pol public.franchise_daily_digest_policy_versions%rowtype;prior public.franchise_daily_digest_config_versions%rowtype;n integer;h text;r jsonb;cid uuid;
begin
 if a is null or not private.franchise_crm_write_access(p_franchise_id,a)then raise exception'FRANCHISE_DIGEST_CONFIG_DENIED'using errcode='42501';end if;
 select operator_organization_id into org from public.franchises where id=p_franchise_id;
 if org is null or p_frequency not in('DAILY','WEEKDAYS')or p_locale not in('fr-MA','ar-MA')or p_local_send_time is null or length(btrim(coalesce(p_change_reason,'')))not between 3 and 1000
  or not exists(select 1 from pg_timezone_names where name=p_time_zone)
  or not exists(select 1 from public.organization_memberships m join public.organization_member_roles mr on mr.membership_id=m.id and mr.revoked_at is null where m.organization_id=org and m.user_id=p_recipient_user_id and m.status='ACTIVE'and mr.role_code in('FRANCHISE_OWNER','FRANCHISE_MANAGER','FRANCHISE_VIEWER'))
 then raise exception'INVALID_FRANCHISE_DIGEST_CONFIG'using errcode='22023';end if;
 select*into pol from public.franchise_daily_digest_policy_versions where status='ACTIVE'and effective_from<=clock_timestamp()and(effective_until is null or effective_until>clock_timestamp())order by version desc limit 1;
 if not found then raise exception'FRANCHISE_DIGEST_POLICY_MISSING'using errcode='55000';end if;
 h:=private.canonical_request_hash(jsonb_build_object('franchise_id',p_franchise_id,'recipient_user_id',p_recipient_user_id,'enabled',p_enabled,'frequency',p_frequency,'local_send_time',p_local_send_time,'time_zone',p_time_zone,'locale',p_locale,'policy_version_id',pol.id,'change_reason',p_change_reason));
 r:=private.begin_contract_command(org,'franchise.daily_digest.configure.'||p_franchise_id::text||'.'||p_recipient_user_id::text,p_idempotency_key,h,a);if r is not null then return r;end if;
 perform pg_advisory_xact_lock(hashtextextended('franchise-digest-config:'||p_franchise_id::text||':'||p_recipient_user_id::text,0));
 select*into prior from public.franchise_daily_digest_config_versions where franchise_id=p_franchise_id and recipient_user_id=p_recipient_user_id order by version desc limit 1;
 n:=coalesce(prior.version,0)+1;
 insert into public.franchise_daily_digest_config_versions(franchise_id,recipient_user_id,version,policy_version_id,enabled,frequency,local_send_time,time_zone,locale,supersedes_config_id,change_reason,content_hash,created_by)
 values(p_franchise_id,p_recipient_user_id,n,pol.id,p_enabled,p_frequency,p_local_send_time,p_time_zone,p_locale,prior.id,p_change_reason,h,a)returning id into cid;
 r:=jsonb_build_object('outcome','FRANCHISE_DAILY_DIGEST_CONFIGURED','config_version_id',cid,'version',n,'enabled',p_enabled,'frequency',p_frequency,'local_send_time',p_local_send_time,'time_zone',p_time_zone,'locale',p_locale);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(org,a,'USER','franchise.daily_digest.configured','franchise_daily_digest_config',cid::text,p_correlation_id,jsonb_build_object('franchise_id',p_franchise_id,'recipient_user_id',p_recipient_user_id,'version',n,'enabled',p_enabled,'frequency',p_frequency,'time_zone',p_time_zone,'policy_version_id',pol.id),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(org,'franchise_daily_digest_config',cid::text,'FranchiseDailyDigestConfiguredV1',p_correlation_id,r,p_idempotency_key);
 perform private.finish_contract_command(org,'franchise.daily_digest.configure.'||p_franchise_id::text||'.'||p_recipient_user_id::text,p_idempotency_key,r);return r;
end$$;

create function public.schedule_franchise_daily_digests(p_now timestamptz default clock_timestamp(),p_limit integer default 100)returns setof jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare c record;d uuid;j uuid;s jsonb;org uuid;corr uuid;local_date date;pipeline jsonb;perf jsonb;
begin
 if auth.role()<>'service_role'then raise exception'FRANCHISE_DIGEST_SCHEDULER_ONLY'using errcode='42501';end if;
 if p_limit not between 1 and 500 then raise exception'INVALID_FRANCHISE_DIGEST_SCHEDULE_LIMIT'using errcode='22023';end if;
 for c in select distinct on(v.franchise_id,v.recipient_user_id)v.* from public.franchise_daily_digest_config_versions v join public.franchises f on f.id=v.franchise_id where f.status not in('TERMINATED')order by v.franchise_id,v.recipient_user_id,v.version desc loop
  exit when p_limit<=0;
  if not c.enabled or timezone(c.time_zone,p_now)::time<c.local_send_time or(c.frequency='WEEKDAYS'and extract(isodow from timezone(c.time_zone,p_now))not between 1 and 5)then continue;end if;
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
   p_limit:=p_limit-1;return next jsonb_build_object('job_id',j,'digest_id',d,'digest_date',local_date,'locale',c.locale);
  end if;
 end loop;return;
end$$;

create function public.claim_franchise_daily_digest_jobs(p_worker_id uuid,p_limit integer default 20,p_lease_seconds integer default 300)returns setof jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare j record;token uuid;corr uuid;
begin
 if auth.role()<>'service_role'then raise exception'FRANCHISE_DIGEST_WORKER_ONLY'using errcode='42501';end if;
 if p_worker_id is null or p_limit not between 1 and 100 or p_lease_seconds not between 30 and 900 then raise exception'INVALID_FRANCHISE_DIGEST_CLAIM'using errcode='22023';end if;
 for j in select x.id,q.organization_id from public.franchise_daily_digest_jobs x join public.franchise_daily_digests q on q.id=x.digest_id where((x.status in('QUEUED','FAILED')and x.next_attempt_at<=clock_timestamp())or(x.status='CLAIMED'and x.leased_until<=clock_timestamp()))order by coalesce(x.next_attempt_at,x.leased_until),x.id for update of x skip locked limit p_limit loop
  token:=extensions.gen_random_uuid();corr:=extensions.gen_random_uuid();
  update public.franchise_daily_digest_jobs set status='CLAIMED',attempt_count=attempt_count+1,next_attempt_at=null,lease_token=token,worker_id=p_worker_id,leased_until=clock_timestamp()+make_interval(secs=>p_lease_seconds),row_version=row_version+1,updated_at=clock_timestamp()where id=j.id;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(j.organization_id,null,'SYSTEM','franchise.daily_digest.claimed','franchise_daily_digest_job',j.id::text,corr,jsonb_build_object('worker_id',p_worker_id,'lease_seconds',p_lease_seconds),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(j.organization_id,'franchise_daily_digest_job',j.id::text,'FranchiseDailyDigestClaimedV1',corr,jsonb_build_object('job_id',j.id,'worker_id',p_worker_id));
  return next jsonb_build_object('job_id',j.id,'lease_token',token,'worker_id',p_worker_id);
 end loop;return;
end$$;

create function public.complete_franchise_daily_digest_job(p_job_id uuid,p_lease_token uuid,p_worker_id uuid,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare j public.franchise_daily_digest_jobs%rowtype;d public.franchise_daily_digests%rowtype;prior public.franchise_daily_digest_job_attempts%rowtype;notice jsonb;nid uuid;r jsonb;vars jsonb;
begin
 if auth.role()<>'service_role'then raise exception'FRANCHISE_DIGEST_WORKER_ONLY'using errcode='42501';end if;
 select*into prior from public.franchise_daily_digest_job_attempts where job_id=p_job_id and idempotency_key=p_idempotency_key;if found then return prior.result_snapshot;end if;
 select*into j from public.franchise_daily_digest_jobs where id=p_job_id for update;select*into d from public.franchise_daily_digests where id=j.digest_id;
 if j.id is null or j.status<>'CLAIMED'or j.lease_token<>p_lease_token or j.worker_id<>p_worker_id or j.leased_until<=clock_timestamp()then raise exception'INVALID_FRANCHISE_DIGEST_LEASE'using errcode='55000';end if;
 if j.row_version<>p_expected_row_version then raise exception'STALE_FRANCHISE_DIGEST_JOB'using errcode='40001';end if;
 vars:=jsonb_build_object('digest_date',d.digest_date::text,'total_prospects',d.metrics_snapshot#>>'{crm,total_prospects}','overdue_followups',d.metrics_snapshot#>>'{followups,overdue}','open_alerts',d.metrics_snapshot#>>'{alerts,open_total}','critical_alerts',d.metrics_snapshot#>>'{alerts,critical}','global_score_basis_points',coalesce(d.metrics_snapshot#>>'{performance,global_score_basis_points}','—'),'active_objectives',d.metrics_snapshot#>>'{objectives,active}');
 notice:=public.enqueue_notification(j.recipient_user_id,d.organization_id,'FRANCHISE_DAILY_DIGEST','FranchiseDailyDigestReadyV1',d.locale,vars,'franchise-digest:'||d.id::text||':'||j.recipient_user_id::text,'franchise_daily_digest',d.id::text,p_correlation_id);nid:=(notice->>'notification_id')::uuid;
 r:=jsonb_build_object('outcome','FRANCHISE_DAILY_DIGEST_NOTIFIED','job_id',j.id,'digest_id',d.id,'notification_id',nid);
 insert into public.franchise_daily_digest_job_attempts(job_id,attempt_number,outcome,worker_id,notification_id,result_snapshot,idempotency_key,correlation_id)values(j.id,j.attempt_count,'NOTIFIED',p_worker_id,nid,r,p_idempotency_key,p_correlation_id);
 update public.franchise_daily_digest_jobs set status='NOTIFIED',notification_id=nid,lease_token=null,worker_id=null,leased_until=null,last_error_code=null,row_version=row_version+1,updated_at=clock_timestamp()where id=j.id;
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(d.organization_id,null,'SYSTEM','franchise.daily_digest.notified','franchise_daily_digest_job',j.id::text,p_correlation_id,jsonb_build_object('digest_id',d.id,'notification_id',nid,'attempt',j.attempt_count),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(d.organization_id,'franchise_daily_digest_job',j.id::text,'FranchiseDailyDigestNotifiedV1',p_correlation_id,r,p_idempotency_key);return r;
end$$;

create function public.fail_franchise_daily_digest_job(p_job_id uuid,p_lease_token uuid,p_worker_id uuid,p_error_code text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare j public.franchise_daily_digest_jobs%rowtype;d public.franchise_daily_digests%rowtype;pol public.franchise_daily_digest_policy_versions%rowtype;prior public.franchise_daily_digest_job_attempts%rowtype;terminal boolean;delay_seconds integer;nextat timestamptz;r jsonb;outcome text;
begin
 if auth.role()<>'service_role'then raise exception'FRANCHISE_DIGEST_WORKER_ONLY'using errcode='42501';end if;
 select*into prior from public.franchise_daily_digest_job_attempts where job_id=p_job_id and idempotency_key=p_idempotency_key;if found then return prior.result_snapshot;end if;
 select*into j from public.franchise_daily_digest_jobs where id=p_job_id for update;select*into d from public.franchise_daily_digests where id=j.digest_id;select*into pol from public.franchise_daily_digest_policy_versions where id=d.policy_version_id;
 if j.id is null or j.status<>'CLAIMED'or j.lease_token<>p_lease_token or j.worker_id<>p_worker_id or j.leased_until<=clock_timestamp()or p_error_code!~'^[A-Z][A-Z0-9_]{2,79}$'then raise exception'INVALID_FRANCHISE_DIGEST_FAILURE'using errcode='55000';end if;
 terminal:=j.attempt_count>=pol.max_attempts;delay_seconds:=least(pol.max_backoff_seconds,(pol.base_backoff_seconds*power(2,greatest(j.attempt_count-1,0)))::integer);nextat:=case when terminal then null else clock_timestamp()+make_interval(secs=>delay_seconds)end;outcome:=case when terminal then'DEAD_LETTER'else'FAILED'end;
 r:=jsonb_build_object('outcome','FRANCHISE_DAILY_DIGEST_'||outcome,'job_id',j.id,'attempt_count',j.attempt_count,'next_attempt_at',nextat,'error_code',p_error_code);
 insert into public.franchise_daily_digest_job_attempts(job_id,attempt_number,outcome,worker_id,error_code,result_snapshot,idempotency_key,correlation_id)values(j.id,j.attempt_count,outcome,p_worker_id,p_error_code,r,p_idempotency_key,p_correlation_id);
 update public.franchise_daily_digest_jobs set status=outcome,next_attempt_at=nextat,lease_token=null,worker_id=null,leased_until=null,last_error_code=p_error_code,row_version=row_version+1,updated_at=clock_timestamp()where id=j.id;
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(d.organization_id,null,'SYSTEM',case when terminal then'franchise.daily_digest.dead_lettered'else'franchise.daily_digest.failed'end,'franchise_daily_digest_job',j.id::text,p_correlation_id,jsonb_build_object('attempt',j.attempt_count,'error_code',p_error_code,'next_attempt_at',nextat),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(d.organization_id,'franchise_daily_digest_job',j.id::text,case when terminal then'FranchiseDailyDigestDeadLetteredV1'else'FranchiseDailyDigestFailedV1'end,p_correlation_id,r,p_idempotency_key);return r;
end$$;

alter table public.franchise_daily_digest_policy_versions enable row level security;
alter table public.franchise_daily_digest_config_versions enable row level security;
alter table public.franchise_daily_digests enable row level security;
alter table public.franchise_daily_digest_jobs enable row level security;
alter table public.franchise_daily_digest_job_attempts enable row level security;
create policy franchise_digest_active_policy_read on public.franchise_daily_digest_policy_versions for select to authenticated using(status='ACTIVE'or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy franchise_digest_configs_scoped_read on public.franchise_daily_digest_config_versions for select to authenticated using(private.franchise_access(franchise_id));
create policy franchise_digests_scoped_read on public.franchise_daily_digests for select to authenticated using(private.franchise_access(franchise_id));
create policy franchise_digest_jobs_scoped_read on public.franchise_daily_digest_jobs for select to authenticated using(private.franchise_access(franchise_id));
create policy franchise_digest_attempts_scoped_read on public.franchise_daily_digest_job_attempts for select to authenticated using(exists(select 1 from public.franchise_daily_digest_jobs j where j.id=job_id and private.franchise_access(j.franchise_id)));

revoke all on public.franchise_daily_digest_policy_versions,public.franchise_daily_digest_config_versions,public.franchise_daily_digests,public.franchise_daily_digest_jobs,public.franchise_daily_digest_job_attempts from public,anon,authenticated,service_role;
grant select on public.franchise_daily_digest_policy_versions,public.franchise_daily_digest_config_versions,public.franchise_daily_digests,public.franchise_daily_digest_jobs,public.franchise_daily_digest_job_attempts to authenticated;
revoke all on function private.prevent_franchise_digest_history_change(),private.valid_franchise_digest_snapshot(jsonb),private.guard_franchise_digest_snapshot()from public,anon,authenticated,service_role;
revoke all on function public.configure_franchise_daily_digest(uuid,uuid,boolean,text,time without time zone,text,text,text,text,uuid),public.schedule_franchise_daily_digests(timestamptz,integer),public.claim_franchise_daily_digest_jobs(uuid,integer,integer),public.complete_franchise_daily_digest_job(uuid,uuid,uuid,integer,text,uuid),public.fail_franchise_daily_digest_job(uuid,uuid,uuid,text,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.configure_franchise_daily_digest(uuid,uuid,boolean,text,time without time zone,text,text,text,text,uuid)to authenticated;
grant execute on function public.schedule_franchise_daily_digests(timestamptz,integer),public.claim_franchise_daily_digest_jobs(uuid,integer,integer),public.complete_franchise_daily_digest_job(uuid,uuid,uuid,integer,text,uuid),public.fail_franchise_daily_digest_job(uuid,uuid,uuid,text,text,uuid)to service_role;

create index franchise_digest_config_latest_idx on public.franchise_daily_digest_config_versions(franchise_id,recipient_user_id,version desc);
create index franchise_digest_history_idx on public.franchise_daily_digests(franchise_id,digest_date desc,locale);
create index franchise_digest_job_dispatch_idx on public.franchise_daily_digest_jobs(next_attempt_at,leased_until,id)where status in('QUEUED','FAILED','CLAIMED');
create index franchise_digest_attempt_history_idx on public.franchise_daily_digest_job_attempts(job_id,attempt_number desc);

insert into public.franchise_daily_digest_policy_versions(version,status,max_attempts,base_backoff_seconds,max_backoff_seconds,max_pipeline_stages,effective_from,content_hash,change_reason)
values(1,'ACTIVE',5,60,86400,20,'2026-09-10',private.canonical_request_hash('{"franchise_daily_digest_policy":"v1","max_attempts":5,"base_backoff_seconds":60,"max_backoff_seconds":86400,"max_pipeline_stages":20}'::jsonb),'Politique initiale du résumé franchisé V1');

insert into public.notification_template_versions(template_code,version,event_type,category_code,locale,subject_template,body_template,cta_path_template,priority,mandatory,channels,variable_keys,status,effective_from,content_hash)values
('FRANCHISE_DAILY_DIGEST',1,'FranchiseDailyDigestReadyV1','FRANCHISE','fr-MA','Résumé franchisé du {{digest_date}}','Prospects : {{total_prospects}}. Relances en retard : {{overdue_followups}}. Alertes ouvertes : {{open_alerts}}, dont critiques : {{critical_alerts}}. Score global : {{global_score_basis_points}} points de base. Objectifs actifs : {{active_objectives}}. Ce résumé est informatif et ne déclenche aucune sanction automatique.','/fr/franchise/gouvernance','NORMAL',false,array['IN_APP','EMAIL'],array['digest_date','total_prospects','overdue_followups','open_alerts','critical_alerts','global_score_basis_points','active_objectives'],'ACTIVE','2026-09-10',private.canonical_request_hash('{"template":"FRANCHISE_DAILY_DIGEST","version":1,"locale":"fr-MA"}'::jsonb)),
('FRANCHISE_DAILY_DIGEST',1,'FranchiseDailyDigestReadyV1','FRANCHISE','ar-MA','ملخص الامتياز ليوم {{digest_date}}','العملاء المحتملون: {{total_prospects}}. المتابعات المتأخرة: {{overdue_followups}}. التنبيهات المفتوحة: {{open_alerts}}، منها الحرجة: {{critical_alerts}}. النتيجة الإجمالية: {{global_score_basis_points}} نقطة أساس. الأهداف النشطة: {{active_objectives}}. هذا الملخص للمعلومات فقط ولا يفرض أي عقوبة تلقائية.','/ar/franchise/gouvernance','NORMAL',false,array['IN_APP','EMAIL'],array['digest_date','total_prospects','overdue_followups','open_alerts','critical_alerts','global_score_basis_points','active_objectives'],'ACTIVE','2026-09-10',private.canonical_request_hash('{"template":"FRANCHISE_DAILY_DIGEST","version":1,"locale":"ar-MA"}'::jsonb));
