-- Append-only publication attempts, lease-bound results and fail-closed timeout reconciliation.

alter table public.social_publication_jobs drop constraint if exists social_publication_jobs_status_check;
alter table public.social_publication_jobs add constraint social_publication_jobs_status_check
  check(status in('QUEUED','CLAIMED','PUBLISHED','FAILED','SKIPPED','UNKNOWN','RECONCILIATION_REQUIRED'));
alter table public.social_publication_jobs add column lease_token uuid;
-- Fail closed on legacy in-flight jobs whose pre-V42 claim did not persist the
-- complete lease metadata. They require explicit reconciliation and cannot be
-- completed through either legacy result RPC (both are closed below).
update public.social_publication_jobs
set status='FAILED',
    lease_token=coalesce(lease_token,extensions.gen_random_uuid()),
    claimed_by=coalesce(claimed_by,'migration-reconciliation'),
    attempt_count=greatest(attempt_count,1),
    claimed_at=coalesce(claimed_at,clock_timestamp()),
    lease_expires_at=coalesce(lease_expires_at,clock_timestamp())
where status='CLAIMED'
  and(lease_token is null or claimed_by is null or claimed_at is null or lease_expires_at is null);
update public.social_publication_jobs
set lease_token=extensions.gen_random_uuid()
where status='CLAIMED'and lease_token is null;
alter table public.social_publication_jobs add constraint social_publication_jobs_claim_lease_check
  check(status<>'CLAIMED'or(lease_token is not null and claimed_by is not null and claimed_at is not null and lease_expires_at is not null));

create table public.marketing_publication_quota_versions(
  id uuid primary key default extensions.gen_random_uuid(),organization_id uuid references public.organizations(id)on delete restrict,
  provider text not null check(provider in('LINKEDIN','META')),version integer not null check(version>0),
  max_claims integer not null check(max_claims between 1 and 10000),window_seconds integer not null check(window_seconds between 60 and 86400),
  status text not null check(status in('ACTIVE','RETIRED')),content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),
  created_by uuid references auth.users(id),created_at timestamptz not null default clock_timestamp(),
  unique nulls not distinct(organization_id,provider,version)
);
insert into public.marketing_publication_quota_versions(organization_id,provider,version,max_claims,window_seconds,status,content_hash)
values(null,'LINKEDIN',1,100,3600,'ACTIVE',encode(extensions.digest('LINKEDIN:100:3600','sha256'),'hex')),
  (null,'META',1,200,3600,'ACTIVE',encode(extensions.digest('META:200:3600','sha256'),'hex'));

create table public.social_publication_attempt_events(
  id bigint generated always as identity primary key,organization_id uuid not null references public.organizations(id)on delete restrict,
  job_id uuid not null references public.social_publication_jobs(id)on delete restrict,attempt integer not null check(attempt>0),
  lease_token uuid not null,worker_id text not null check(length(btrim(worker_id))between 3 and 100),
  state text not null check(state in('CLAIMED','SUCCEEDED','FAILED','UNKNOWN','RECONCILIATION_REQUIRED','REQUEUED')),
  request_hash text not null check(request_hash~'^[0-9a-f]{64}$'),provider_publication_id text,
  provider text check(provider is null or provider in('LINKEDIN','META')),
  provider_request_key text check(provider_request_key is null or length(provider_request_key)between 8 and 200),
  error_code text,occurred_at timestamptz not null default clock_timestamp(),correlation_id uuid not null,
  evidence_snapshot jsonb not null default'{}'::jsonb check(jsonb_typeof(evidence_snapshot)='object'),
  unique(job_id,attempt,state),
  check(provider_publication_id is null or(length(provider_publication_id)between 3 and 300 and provider_publication_id!~'[[:cntrl:]]')),
  check(error_code is null or(error_code~'^[A-Z0-9][A-Z0-9_.:-]{1,99}$'))
  ,check(state<>'CLAIMED'or(provider is not null and provider_request_key is not null))
);
create index social_publication_attempt_events_quota_idx on public.social_publication_attempt_events(organization_id,occurred_at desc)where state='CLAIMED';
create unique index social_publication_attempt_events_provider_request_uidx on public.social_publication_attempt_events(provider,provider_request_key)where state='CLAIMED';

-- Every pre-V42 claim that could not have carried the complete lease contract is
-- failed closed with immutable evidence, audit and Outbox; no token is emitted.
insert into public.social_publication_attempt_events(organization_id,job_id,attempt,lease_token,worker_id,state,request_hash,error_code,correlation_id,evidence_snapshot)
select j.organization_id,j.id,j.attempt_count,j.lease_token,j.claimed_by,'FAILED',private.canonical_request_hash(jsonb_build_object('job_id',j.id,'reason','LEGACY_LEASE_INCOMPLETE')),'LEGACY_LEASE_INCOMPLETE',extensions.gen_random_uuid(),jsonb_build_object('migration','V42','disposition','FAILED_CLOSED')
from public.social_publication_jobs j where j.status='FAILED'and j.claimed_by='migration-reconciliation';
insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
select j.organization_id,null,'SERVICE','marketing.publication.legacy_claim_failed_closed','social_publication_job',j.id::text,e.correlation_id,jsonb_build_object('attempt',j.attempt_count,'reason','LEGACY_LEASE_INCOMPLETE'),repeat('0',64)from public.social_publication_jobs j join public.social_publication_attempt_events e on e.job_id=j.id and e.attempt=j.attempt_count and e.state='FAILED'where j.claimed_by='migration-reconciliation';
insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
select j.organization_id,'social_publication_job',j.id::text,'SocialPublicationLegacyClaimFailedClosedV1',e.correlation_id,jsonb_build_object('job_id',j.id,'attempt',j.attempt_count,'reason','LEGACY_LEASE_INCOMPLETE'),'marketing-legacy-failed:'||j.id::text||':'||j.attempt_count::text from public.social_publication_jobs j join public.social_publication_attempt_events e on e.job_id=j.id and e.attempt=j.attempt_count and e.state='FAILED'where j.claimed_by='migration-reconciliation';

create table private.marketing_worker_command_keys(
  command_scope text not null,idempotency_key text not null,request_hash text not null check(request_hash~'^[0-9a-f]{64}$'),
  response_body jsonb,created_at timestamptz not null default clock_timestamp(),primary key(command_scope,idempotency_key)
);

create function private.prevent_social_publication_attempt_change()returns trigger language plpgsql set search_path=pg_catalog
as $$begin raise exception'SOCIAL_PUBLICATION_ATTEMPT_IMMUTABLE'using errcode='55000';end$$;
create trigger social_publication_attempt_events_immutable before update or delete on public.social_publication_attempt_events
for each row execute function private.prevent_social_publication_attempt_change();
create trigger marketing_publication_quota_versions_immutable before update or delete on public.marketing_publication_quota_versions
for each row execute function private.prevent_marketing_history_change();

create or replace function public.claim_next_social_publication_job_v41(
  p_worker_id text,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions
as $$
declare j public.social_publication_jobs%rowtype;i public.marketing_calendar_items%rowtype;v public.marketing_content_versions%rowtype;
  c public.social_connections%rowtype;s public.social_connection_security_versions%rowtype;channel text;r jsonb;
  v_campaign_id uuid;token uuid:=extensions.gen_random_uuid();quota_max integer;quota_window integer;used integer;request_hash text;evidence jsonb;provider_key text;
begin
  if auth.role()is distinct from'service_role'or length(btrim(coalesce(p_worker_id,'')))not between 3 and 100 then raise exception'MARKETING_WORKER_CLAIM_DENIED'using errcode='42501';end if;
  select * into j from public.social_publication_jobs where status='QUEUED'and available_at<=clock_timestamp()
    order by available_at,id for update skip locked limit 1;
  if not found then return jsonb_build_object('outcome','NO_JOB');end if;
  select q.max_claims,q.window_seconds into quota_max,quota_window from public.marketing_publication_quota_versions q
    where q.provider=j.provider and q.status='ACTIVE'and(q.organization_id=j.organization_id or q.organization_id is null)
    order by(q.organization_id is not null)desc,q.version desc limit 1;
  if quota_max is null then raise exception'MARKETING_PROVIDER_QUOTA_MISSING'using errcode='55000';end if;
  perform pg_advisory_xact_lock(hashtextextended('marketing-quota:'||j.organization_id::text||':'||j.provider,0));
  select count(*)into used from public.social_publication_attempt_events e join public.social_publication_jobs q on q.id=e.job_id
    where e.organization_id=j.organization_id and q.provider=j.provider and e.state='CLAIMED'
      and e.occurred_at>=clock_timestamp()-make_interval(secs=>quota_window);
  if used>=quota_max then
    update public.social_publication_jobs set available_at=clock_timestamp()+make_interval(secs=>quota_window)where id=j.id;
    select mc.campaign_id into v_campaign_id from public.marketing_calendar_items mi join public.marketing_content_versions mv on mv.id=mi.content_version_id join public.marketing_content mc on mc.id=mv.content_id where mi.id=j.calendar_item_id;
    if v_campaign_id is not null then perform pg_advisory_xact_lock(hashtextextended('marketing-exception:'||v_campaign_id::text||':PROVIDER_QUOTA_EXHAUSTED',0));end if;
    if v_campaign_id is not null and not exists(select 1 from public.marketing_exceptions e where e.campaign_id=v_campaign_id and e.exception_type='PROVIDER_QUOTA_EXHAUSTED'and e.status='OPEN')then insert into public.marketing_exceptions(organization_id,campaign_id,exception_type,severity,reason,automatic_resolution_possible,status)values(j.organization_id,v_campaign_id,'PROVIDER_QUOTA_EXHAUSTED','WARNING','Provider publication quota exhausted; job deferred to the next quota window.',true,'OPEN');end if;
    r:=jsonb_build_object('outcome','PROVIDER_QUOTA_EXHAUSTED','job_id',j.id,'provider',j.provider,'retry_after_seconds',quota_window);
    insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(j.organization_id,null,'SERVICE','marketing.publication.quota_exhausted','social_publication_job',j.id::text,p_correlation_id,r,repeat('0',64));
    insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(j.organization_id,'social_publication_job',j.id::text,'SocialPublicationQuotaExhaustedV1',p_correlation_id,r,'marketing-quota:'||j.id::text||':'||j.attempt_count::text);
    return r;end if;
  select * into i from public.marketing_calendar_items where id=j.calendar_item_id;
  select * into v from public.marketing_content_versions where id=i.content_version_id;
  select mc.channel,mc.campaign_id into channel,v_campaign_id from public.marketing_content mc where mc.id=v.content_id;
  select * into c from public.social_connections where id=i.social_connection_id;
  select * into s from public.social_connection_security_versions where social_connection_id=c.id order by version desc limit 1;
  evidence:=jsonb_build_object('consent_evidence_hash',(select evidence_hash from public.marketing_consents where organization_id=j.organization_id and purpose='SOCIAL_PUBLISHING'and decision='GRANTED'order by decided_at desc,id desc limit 1),'authorization_evidence_hash',(select evidence_hash from public.marketing_brand_authorizations where organization_id=j.organization_id and decision='GRANTED'order by decided_at desc,id desc limit 1),'compliance_checks',v.compliance_checks,'content_hash',v.content_hash,'security_version_id',s.id);
  if not private.marketing_publication_ready_v41(j.organization_id,j.provider,c.id,v.id)then
    update public.social_publication_jobs set status='SKIPPED',claimed_by=null,claimed_at=null,lease_expires_at=null,lease_token=null where id=j.id;
    update public.marketing_calendar_items set status='SKIPPED'where id=i.id;
    perform pg_advisory_xact_lock(hashtextextended('marketing-exception:'||v_campaign_id::text||':PUBLICATION_POLICY_BLOCKED:'||v.id::text,0));
    if not exists(select 1 from public.marketing_exceptions e where e.campaign_id=v_campaign_id and e.content_version_id=v.id and e.exception_type='PUBLICATION_POLICY_BLOCKED'and e.status='OPEN')then
      insert into public.marketing_exceptions(organization_id,campaign_id,content_version_id,exception_type,severity,reason,automatic_resolution_possible,status)
      values(j.organization_id,v_campaign_id,v.id,'PUBLICATION_POLICY_BLOCKED','BLOCKING','Publication blocked by current consent, authorization, security, compliance or kill-switch policy.',false,'OPEN');end if;
    r:=jsonb_build_object('outcome','SKIPPED_POLICY','job_id',j.id,'campaign_id',v_campaign_id);
    insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
      values(j.organization_id,null,'SERVICE','marketing.publication.policy_blocked','social_publication_job',j.id::text,p_correlation_id,r,repeat('0',64));
    insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
      values(j.organization_id,'social_publication_job',j.id::text,'SocialPublicationPolicyBlockedV1',p_correlation_id,r,'marketing-policy-blocked:'||j.id::text);
    return r;
  end if;
  update public.social_publication_jobs set status='CLAIMED',attempt_count=attempt_count+1,claimed_by=p_worker_id,
    claimed_at=clock_timestamp(),lease_expires_at=clock_timestamp()+interval'5 minutes',lease_token=token where id=j.id returning * into j;
  provider_key:=encode(extensions.digest(j.provider||':'||j.idempotency_key||':attempt:'||j.attempt_count::text,'sha256'),'hex');
  request_hash:=private.canonical_request_hash(jsonb_build_object('job',j.id,'attempt',j.attempt_count,'lease_token',token,'worker',p_worker_id,'provider_request_key',provider_key,'content_hash',v.content_hash,'security_version_id',s.id,'evidence_snapshot_hash',private.canonical_request_hash(evidence)));
  insert into public.social_publication_attempt_events(organization_id,job_id,attempt,lease_token,worker_id,state,request_hash,provider,provider_request_key,correlation_id,evidence_snapshot)
    values(j.organization_id,j.id,j.attempt_count,token,p_worker_id,'CLAIMED',request_hash,j.provider,provider_key,p_correlation_id,evidence);
  r:=jsonb_build_object('outcome','JOB_CLAIMED','job_id',j.id,'attempt',j.attempt_count,'provider',j.provider,'channel',channel,
    'credential_reference',s.vault_credential_reference,'lease_token',token,'lease_expires_at',j.lease_expires_at,
    'provider_idempotency_key',provider_key,'content',jsonb_build_object('language',v.language,'hook',v.hook,'body',v.body,'cta',v.cta,'hashtags',v.hashtags,'landing_url',v.landing_url,'media_url',v.media_url));
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
    values(j.organization_id,null,'SERVICE','marketing.publication.worker_claimed','social_publication_job',j.id::text,p_correlation_id,
      jsonb_build_object('worker_id',p_worker_id,'provider',j.provider,'attempt',j.attempt_count,'lease_token_hash',encode(extensions.digest(token::text,'sha256'),'hex')),repeat('0',64));
  return r;
end$$;

create function public.mark_timed_out_social_publication_attempts_v1(p_limit integer,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions
as $$declare j record;n integer:=0;h text;r jsonb;begin
  if auth.role()is distinct from'service_role'then raise exception'MARKETING_TIMEOUT_WORKER_DENIED'using errcode='42501';end if;
  if p_limit not between 1 and 500 then raise exception'INVALID_MARKETING_TIMEOUT_LIMIT'using errcode='22023';end if;
  for j in select * from public.social_publication_jobs where status='CLAIMED'and lease_expires_at<=clock_timestamp()
    order by lease_expires_at,id for update skip locked limit p_limit loop
    h:=private.canonical_request_hash(jsonb_build_object('job',j.id,'attempt',j.attempt_count,'lease_token',j.lease_token,'timeout',j.lease_expires_at));
    insert into public.social_publication_attempt_events(organization_id,job_id,attempt,lease_token,worker_id,state,request_hash,error_code,correlation_id)
      values(j.organization_id,j.id,j.attempt_count,j.lease_token,j.claimed_by,'UNKNOWN',h,'PROVIDER_TIMEOUT',p_correlation_id),
      (j.organization_id,j.id,j.attempt_count,j.lease_token,j.claimed_by,'RECONCILIATION_REQUIRED',h,'PROVIDER_TIMEOUT',p_correlation_id);
    update public.social_publication_jobs set status='RECONCILIATION_REQUIRED'where id=j.id;
    r:=jsonb_build_object('job_id',j.id,'attempt',j.attempt_count,'outcome','RECONCILIATION_REQUIRED');
    insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
      values(j.organization_id,null,'SERVICE','marketing.publication.timeout_reconciliation_required','social_publication_job',j.id::text,p_correlation_id,r,repeat('0',64));
    insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
      values(j.organization_id,'social_publication_job',j.id::text,'SocialPublicationReconciliationRequiredV1',p_correlation_id,r,'marketing-timeout:'||j.id::text||':'||j.attempt_count::text);
    n:=n+1;
  end loop;return jsonb_build_object('outcome','MARKETING_TIMEOUTS_PROCESSED','marked',n);end$$;

create function private.begin_marketing_worker_command(p_scope text,p_key text,p_hash text)returns jsonb language plpgsql security definer
set search_path=pg_catalog,private as $$declare prior private.marketing_worker_command_keys%rowtype;begin
  if length(coalesce(p_key,''))not between 8 and 200 then raise exception'INVALID_IDEMPOTENCY_KEY'using errcode='22023';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_scope||':'||p_key,0));select * into prior from private.marketing_worker_command_keys where command_scope=p_scope and idempotency_key=p_key;
  if found then if prior.request_hash<>p_hash then raise exception'IDEMPOTENCY_PAYLOAD_MISMATCH'using errcode='22000';end if;return prior.response_body;end if;
  insert into private.marketing_worker_command_keys(command_scope,idempotency_key,request_hash)values(p_scope,p_key,p_hash);return null;end$$;

create function private.finish_marketing_worker_command(p_scope text,p_key text,p_response jsonb)returns void language sql security definer
set search_path=pg_catalog,private as $$update private.marketing_worker_command_keys set response_body=p_response where command_scope=p_scope and idempotency_key=p_key$$;

create function public.record_social_publication_worker_result_v42(
  p_job_id uuid,p_lease_token uuid,p_outcome text,p_provider_publication_id text,p_error_code text,
  p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions
as $$declare j public.social_publication_jobs%rowtype;i public.marketing_calendar_items%rowtype;v public.marketing_content_versions%rowtype;
  h text;cached jsonb;r jsonb;auth_hash text;consent_hash text;event_state text;begin
  if auth.role()is distinct from'service_role'then raise exception'MARKETING_WORKER_RESULT_DENIED'using errcode='42501';end if;
  if p_lease_token is null or p_outcome not in('PUBLISHED','SANDBOXED','RETRYABLE_FAILURE','PERMANENT_FAILURE')
    or(p_outcome='PUBLISHED'and(coalesce(length(p_provider_publication_id),0)not between 3 and 300
      or coalesce(p_provider_publication_id,'')~'[[:cntrl:]]'or p_error_code is not null))
    or(p_outcome<>'PUBLISHED'and p_provider_publication_id is not null)
    or(p_error_code is not null and p_error_code!~'^[A-Z0-9][A-Z0-9_.:-]{1,99}$')then raise exception'INVALID_MARKETING_WORKER_RESULT'using errcode='22023';end if;
  select * into j from public.social_publication_jobs where id=p_job_id for update;if not found then raise exception'MARKETING_JOB_NOT_FOUND'using errcode='P0002';end if;
  h:=private.canonical_request_hash(jsonb_build_object('job',j.id,'lease_token',p_lease_token,'outcome',p_outcome,'provider_publication_id',p_provider_publication_id,'error_code',p_error_code));
  cached:=private.begin_marketing_worker_command('marketing.result.'||j.id::text,p_idempotency_key,h);if cached is not null then return cached;end if;
  if j.status<>'CLAIMED'or j.lease_token<>p_lease_token or j.lease_expires_at<=clock_timestamp()then raise exception'MARKETING_RESULT_LEASE_INVALID'using errcode='55000';end if;
  select * into i from public.marketing_calendar_items where id=j.calendar_item_id;select * into v from public.marketing_content_versions where id=i.content_version_id;
  if p_outcome='PUBLISHED'and not private.marketing_publication_ready_v41(j.organization_id,j.provider,i.social_connection_id,i.content_version_id)then raise exception'MARKETING_PUBLICATION_BLOCKED'using errcode='55000';end if;
  insert into public.social_publication_results(job_id,attempt,outcome,provider_publication_id,error_code)
    values(j.id,j.attempt_count,p_outcome,p_provider_publication_id,p_error_code);
  event_state:=case when p_outcome in('PUBLISHED','SANDBOXED')then'SUCCEEDED'else'FAILED'end;
  insert into public.social_publication_attempt_events(organization_id,job_id,attempt,lease_token,worker_id,state,request_hash,provider_publication_id,error_code,correlation_id)
    values(j.organization_id,j.id,j.attempt_count,p_lease_token,j.claimed_by,event_state,h,p_provider_publication_id,p_error_code,p_correlation_id);
  if p_outcome='PUBLISHED'then
    select evidence_hash into auth_hash from public.marketing_brand_authorizations where organization_id=j.organization_id and decision='GRANTED'order by decided_at desc,id desc limit 1;
    select evidence_hash into consent_hash from public.marketing_consents where organization_id=j.organization_id and purpose='SOCIAL_PUBLISHING'and decision='GRANTED'order by decided_at desc,id desc limit 1;
    insert into public.marketing_publication_journal(organization_id,job_id,content_version_id,provider,provider_publication_id,content_snapshot,content_hash,authorization_evidence_hash,consent_evidence_hash,published_at)
      values(j.organization_id,j.id,v.id,j.provider,p_provider_publication_id,jsonb_build_object('language',v.language,'hook',v.hook,'body',v.body,'cta',v.cta,'hashtags',v.hashtags,'landing_url',v.landing_url,'media_url',v.media_url),v.content_hash,auth_hash,consent_hash,clock_timestamp());
    update public.social_publication_jobs set status='PUBLISHED',lease_token=null,lease_expires_at=null where id=j.id;update public.marketing_calendar_items set status='PUBLISHED'where id=i.id;r:=jsonb_build_object('outcome','PUBLISHED','job_id',j.id,'provider_publication_id',p_provider_publication_id);
  elsif p_outcome='RETRYABLE_FAILURE'and p_error_code='PROVIDER_HTTP_429'and j.attempt_count<20 then update public.social_publication_jobs set status='QUEUED',available_at=clock_timestamp()+make_interval(secs=>least(3600,30*(2^least(j.attempt_count,7))::integer)),lease_token=null,lease_expires_at=null where id=j.id;update public.marketing_calendar_items set status='SCHEDULED'where id=i.id;r:=jsonb_build_object('outcome','RETRY_SCHEDULED','job_id',j.id,'attempt',j.attempt_count);
  elsif p_outcome='RETRYABLE_FAILURE'then
    update public.social_publication_jobs set status='RECONCILIATION_REQUIRED'where id=j.id;
    insert into public.social_publication_attempt_events(organization_id,job_id,attempt,lease_token,worker_id,state,request_hash,error_code,correlation_id)values(j.organization_id,j.id,j.attempt_count,p_lease_token,j.claimed_by,'UNKNOWN',h,coalesce(p_error_code,'NETWORK_UNKNOWN'),p_correlation_id),(j.organization_id,j.id,j.attempt_count,p_lease_token,j.claimed_by,'RECONCILIATION_REQUIRED',h,coalesce(p_error_code,'NETWORK_UNKNOWN'),p_correlation_id);
    r:=jsonb_build_object('outcome','RECONCILIATION_REQUIRED','job_id',j.id,'attempt',j.attempt_count);
  else update public.social_publication_jobs set status=case when p_outcome='SANDBOXED'then'SKIPPED'else'FAILED'end,lease_token=null,lease_expires_at=null where id=j.id;update public.marketing_calendar_items set status=case when p_outcome='SANDBOXED'then'SKIPPED'else'FAILED'end where id=i.id;r:=jsonb_build_object('outcome',p_outcome,'job_id',j.id,'error_code',p_error_code);end if;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
    values(j.organization_id,null,'SERVICE','marketing.publication.worker_result','social_publication_job',j.id::text,p_correlation_id,jsonb_build_object('outcome',p_outcome,'attempt',j.attempt_count),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
    values(j.organization_id,'social_publication_job',j.id::text,case when p_outcome='PUBLISHED'then'SocialPublicationRecordedV1'when p_outcome='SANDBOXED'then'SocialPublicationSandboxedV1'when r->>'outcome'='RETRY_SCHEDULED'then'SocialPublicationRetryScheduledV1'when r->>'outcome'='RECONCILIATION_REQUIRED'then'SocialPublicationReconciliationRequiredV1'else'SocialPublicationFailedV1'end,p_correlation_id,r,p_idempotency_key);
  perform private.finish_marketing_worker_command('marketing.result.'||j.id::text,p_idempotency_key,r);return r;end$$;

create or replace function public.record_social_publication_worker_result_v41(
  p_job_id uuid,p_outcome text,p_provider_publication_id text,p_error_code text,
  p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$begin raise exception'LEASE_TOKEN_REQUIRED'using errcode='42501';end$$;

create or replace function public.claim_social_publication_job_v41(
  p_job_id uuid,p_worker_id text,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql security definer set search_path=pg_catalog
as $$begin raise exception'LEASE_TOKEN_REQUIRED'using errcode='42501';end$$;

create or replace function public.record_social_publication_result_v41(
  p_job_id uuid,p_outcome text,p_provider_publication_id text,p_error_code text,
  p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql security definer set search_path=pg_catalog
as $$begin raise exception'LEASE_TOKEN_REQUIRED'using errcode='42501';end$$;

create function public.reconcile_social_publication_attempt_v1(
  p_job_id uuid,p_lease_token uuid,p_resolution text,p_provider_publication_id text,p_error_code text,
  p_provider_evidence jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions
as $$declare j public.social_publication_jobs%rowtype;i public.marketing_calendar_items%rowtype;v public.marketing_content_versions%rowtype;h text;cached jsonb;r jsonb;auth_hash text;consent_hash text;checked timestamptz;expected_evidence_hash text;claim_evidence jsonb;claim_provider_key text;begin
  if auth.role()is distinct from'service_role'then raise exception'MARKETING_RECONCILIATION_DENIED'using errcode='42501';end if;
  if p_lease_token is null or p_resolution not in('PUBLISHED','REQUEUE','FAILED')
    or(p_resolution='PUBLISHED')<>(p_provider_publication_id is not null)
    or(p_provider_publication_id is not null and(length(p_provider_publication_id)not between 3 and 300
      or p_provider_publication_id~'[[:cntrl:]]'))
    or jsonb_typeof(p_provider_evidence)<>'object'or not(p_provider_evidence?'provider_state')or not(p_provider_evidence?'checked_at')or not(p_provider_evidence?'evidence_hash')
    or coalesce(p_provider_evidence->>'evidence_hash','')!~'^[0-9a-f]{64}$'
    or(p_resolution='PUBLISHED'and p_provider_evidence->>'provider_state'<>'PUBLISHED')
    or(p_resolution='REQUEUE'and p_provider_evidence->>'provider_state'<>'NOT_SENT')
    or(p_resolution='FAILED'and p_provider_evidence->>'provider_state'not in('FAILED','UNKNOWN'))
    or(p_error_code is not null and p_error_code!~'^[A-Z0-9][A-Z0-9_.:-]{1,99}$')then raise exception'INVALID_MARKETING_RECONCILIATION'using errcode='22023';end if;
  select * into j from public.social_publication_jobs where id=p_job_id for update;if not found then raise exception'MARKETING_JOB_NOT_FOUND'using errcode='P0002';end if;
  select evidence_snapshot,provider_request_key into claim_evidence,claim_provider_key from public.social_publication_attempt_events where job_id=j.id and attempt=j.attempt_count and state='CLAIMED'and lease_token=p_lease_token;
  if claim_evidence is null or claim_provider_key is null then raise exception'MARKETING_CLAIM_EVIDENCE_MISSING'using errcode='55000';end if;
  begin checked:=(p_provider_evidence->>'checked_at')::timestamptz;exception when others then raise exception'INVALID_MARKETING_RECONCILIATION_EVIDENCE_TIME'using errcode='22023';end;
  if checked>clock_timestamp()or checked<clock_timestamp()-interval'24 hours'then raise exception'STALE_MARKETING_RECONCILIATION_EVIDENCE'using errcode='22023';end if;
  expected_evidence_hash:=private.canonical_request_hash(jsonb_build_object('job_id',j.id,'provider',j.provider,'provider_request_key',claim_provider_key,'provider_state',p_provider_evidence->>'provider_state','checked_at',p_provider_evidence->>'checked_at','payload',coalesce(p_provider_evidence->'payload','{}'::jsonb)));
  if p_provider_evidence->>'evidence_hash'<>expected_evidence_hash then raise exception'MARKETING_RECONCILIATION_EVIDENCE_HASH_MISMATCH'using errcode='22000';end if;
  h:=private.canonical_request_hash(jsonb_build_object('job',j.id,'lease_token',p_lease_token,'resolution',p_resolution,'provider_publication_id',p_provider_publication_id,'error_code',p_error_code,'provider_evidence',p_provider_evidence));
  cached:=private.begin_marketing_worker_command('marketing.reconcile.'||j.id::text,p_idempotency_key,h);if cached is not null then return cached;end if;
  if j.status<>'RECONCILIATION_REQUIRED'or j.lease_token<>p_lease_token then raise exception'MARKETING_RECONCILIATION_LEASE_INVALID'using errcode='55000';end if;
  select * into i from public.marketing_calendar_items where id=j.calendar_item_id;select * into v from public.marketing_content_versions where id=i.content_version_id;
  if p_resolution='PUBLISHED'then
    insert into public.social_publication_results(job_id,attempt,outcome,provider_publication_id)values(j.id,j.attempt_count,'PUBLISHED',p_provider_publication_id);
    auth_hash:=claim_evidence->>'authorization_evidence_hash';consent_hash:=claim_evidence->>'consent_evidence_hash';
    insert into public.marketing_publication_journal(organization_id,job_id,content_version_id,provider,provider_publication_id,content_snapshot,content_hash,authorization_evidence_hash,consent_evidence_hash,published_at)
      values(j.organization_id,j.id,v.id,j.provider,p_provider_publication_id,jsonb_build_object('language',v.language,'hook',v.hook,'body',v.body,'cta',v.cta,'hashtags',v.hashtags,'landing_url',v.landing_url,'media_url',v.media_url),v.content_hash,auth_hash,consent_hash,clock_timestamp());
    update public.social_publication_jobs set status='PUBLISHED',lease_token=null,lease_expires_at=null where id=j.id;update public.marketing_calendar_items set status='PUBLISHED'where id=i.id;
  elsif p_resolution='REQUEUE'then update public.social_publication_jobs set status='QUEUED',available_at=clock_timestamp(),lease_token=null,lease_expires_at=null where id=j.id;update public.marketing_calendar_items set status='SCHEDULED'where id=i.id;
  else insert into public.social_publication_results(job_id,attempt,outcome,error_code)values(j.id,j.attempt_count,'PERMANENT_FAILURE',coalesce(p_error_code,'RECONCILIATION_FAILED'));update public.social_publication_jobs set status='FAILED',lease_token=null,lease_expires_at=null where id=j.id;update public.marketing_calendar_items set status='FAILED'where id=i.id;end if;
  insert into public.social_publication_attempt_events(organization_id,job_id,attempt,lease_token,worker_id,state,request_hash,provider_publication_id,error_code,correlation_id)
    values(j.organization_id,j.id,j.attempt_count,p_lease_token,j.claimed_by,case when p_resolution='PUBLISHED'then'SUCCEEDED'when p_resolution='REQUEUE'then'REQUEUED'else'FAILED'end,h,p_provider_publication_id,p_error_code,p_correlation_id);
  r:=jsonb_build_object('outcome','MARKETING_PUBLICATION_RECONCILED','job_id',j.id,'resolution',p_resolution,'provider_evidence_hash',p_provider_evidence->>'evidence_hash');
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(j.organization_id,null,'SERVICE','marketing.publication.reconciled','social_publication_job',j.id::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(j.organization_id,'social_publication_job',j.id::text,'SocialPublicationReconciledV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_marketing_worker_command('marketing.reconcile.'||j.id::text,p_idempotency_key,r);return r;end$$;

create function public.detect_marketing_calendar_shortages_v1(p_month_start date,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions
as $$declare x record;campaign uuid;n integer:=0;r jsonb;begin if auth.role()is distinct from'service_role'then raise exception'MARKETING_SHORTAGE_WORKER_DENIED'using errcode='42501';end if;
  if p_month_start<>date_trunc('month',p_month_start)::date then raise exception'INVALID_MARKETING_CALENDAR_MONTH'using errcode='22023';end if;
  for x in select cal.id,cal.organization_id,r.posts_per_month,r.reels_per_month,count(*)filter(where mc.channel<>'REEL')posts,count(*)filter(where mc.channel='REEL')reels
    from public.marketing_calendars cal join public.marketing_schedule_rules r on r.id=cal.schedule_rule_id left join public.marketing_calendar_items i on i.calendar_id=cal.id left join public.marketing_content_versions v on v.id=i.content_version_id left join public.marketing_content mc on mc.id=v.content_id where cal.month_start=p_month_start group by cal.id,cal.organization_id,r.posts_per_month,r.reels_per_month
    having count(*)filter(where mc.channel<>'REEL')<r.posts_per_month or count(*)filter(where mc.channel='REEL')<r.reels_per_month loop
    select id into campaign from public.marketing_campaigns where organization_id=x.organization_id and mode in('ASSISTED','AUTOPILOT')order by created_at desc limit 1;
    if campaign is not null then perform pg_advisory_xact_lock(hashtextextended('marketing-exception:'||campaign::text||':CALENDAR_CONTENT_SHORTAGE',0));end if;
    if campaign is not null and not exists(select 1 from public.marketing_exceptions where campaign_id=campaign and exception_type='CALENDAR_CONTENT_SHORTAGE'and status='OPEN')then
      insert into public.marketing_exceptions(organization_id,campaign_id,exception_type,severity,reason,automatic_resolution_possible,status)
        values(x.organization_id,campaign,'CALENDAR_CONTENT_SHORTAGE','WARNING','Monthly calendar has fewer eligible posts or reels than its versioned schedule rule.',true,'OPEN');
      r:=jsonb_build_object('calendar_id',x.id,'posts',x.posts,'requested_posts',x.posts_per_month,'reels',x.reels,'requested_reels',x.reels_per_month);
      insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(x.organization_id,null,'SERVICE','marketing.calendar.shortage_detected','marketing_calendar',x.id::text,p_correlation_id,r,repeat('0',64));
      insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(x.organization_id,'marketing_calendar',x.id::text,'MarketingCalendarShortageDetectedV1',p_correlation_id,r,'marketing-shortage:'||x.id::text);n:=n+1;end if;end loop;
  return jsonb_build_object('outcome','MARKETING_CALENDAR_SHORTAGES_CHECKED','detected',n);end$$;

alter table public.marketing_publication_quota_versions enable row level security;alter table public.social_publication_attempt_events enable row level security;
revoke all on public.marketing_publication_quota_versions,public.social_publication_attempt_events,private.marketing_worker_command_keys from public,anon,authenticated,service_role;
create policy marketing_publication_quota_versions_scoped_read on public.marketing_publication_quota_versions for select to authenticated using(organization_id is not null and(private.marketing_manage_access(organization_id)or private.has_platform_role(array['READ_ONLY_AUDITOR']))or organization_id is null and private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy social_publication_attempt_events_scoped_read on public.social_publication_attempt_events for select to authenticated using(private.marketing_manage_access(organization_id)or private.has_platform_role(array['READ_ONLY_AUDITOR']));
grant select on public.marketing_publication_quota_versions,public.social_publication_attempt_events to authenticated;
revoke all on function private.prevent_social_publication_attempt_change(),private.begin_marketing_worker_command(text,text,text),private.finish_marketing_worker_command(text,text,jsonb),public.claim_social_publication_job_v41(uuid,text,uuid),public.record_social_publication_result_v41(uuid,text,text,text,text,uuid),public.record_social_publication_worker_result_v41(uuid,text,text,text,text,uuid),public.record_social_publication_worker_result_v42(uuid,uuid,text,text,text,text,uuid),public.mark_timed_out_social_publication_attempts_v1(integer,uuid),public.reconcile_social_publication_attempt_v1(uuid,uuid,text,text,text,jsonb,text,uuid),public.detect_marketing_calendar_shortages_v1(date,uuid)from public,anon,authenticated,service_role;
grant execute on function public.claim_next_social_publication_job_v41(text,uuid),public.claim_social_publication_job_v41(uuid,text,uuid),public.record_social_publication_result_v41(uuid,text,text,text,text,uuid),public.record_social_publication_worker_result_v41(uuid,text,text,text,text,uuid),public.record_social_publication_worker_result_v42(uuid,uuid,text,text,text,text,uuid),public.mark_timed_out_social_publication_attempts_v1(integer,uuid),public.reconcile_social_publication_attempt_v1(uuid,uuid,text,text,text,jsonb,text,uuid),public.detect_marketing_calendar_shortages_v1(date,uuid)to service_role;
notify pgrst,'reload schema';
