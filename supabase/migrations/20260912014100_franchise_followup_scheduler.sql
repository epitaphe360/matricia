-- MAT-FUNC-038: bounded, consent-aware CRM follow-up scheduler.
-- Follow-ups only request a communication; they never change pipeline, access or economic rights.

alter table public.franchise_crm_prospects
  add constraint franchise_crm_prospects_id_franchise_key unique (id, franchise_id);

create table public.franchise_followup_policy_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  franchise_id uuid not null references public.franchises(id) on delete restrict,
  version integer not null check (version > 0),
  supersedes_policy_version_id uuid references public.franchise_followup_policy_versions(id) on delete restrict,
  status text not null check (status in ('PENDING_APPROVAL','ACTIVE','REJECTED','RETIRED')),
  eligible_stages text[] not null check (
    cardinality(eligible_stages) between 1 and 8
    and eligible_stages <@ array['SENT','OPENED','REGISTERED','PROFILE_STARTED','VERIFIED','DIAGNOSTIC_STARTED','OPPORTUNITY_CREATED','RFQ_STARTED']::text[]
  ),
  reminder_delays_minutes integer[] not null check (cardinality(reminder_delays_minutes) between 1 and 8),
  retry_delays_minutes integer[] not null check (cardinality(retry_delays_minutes) between 1 and 10),
  maximum_attempts integer not null check (maximum_attempts between 1 and 10),
  maximum_reminders_per_7_days integer not null check (maximum_reminders_per_7_days between 1 and 8),
  lease_seconds integer not null check (lease_seconds between 30 and 900),
  effective_from timestamptz not null,
  effective_until timestamptz,
  change_reason text not null check (length(btrim(change_reason)) between 10 and 1000),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  proposed_by uuid not null references auth.users(id),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  unique (franchise_id, version),
  unique (id, franchise_id),
  check (effective_until is null or effective_until > effective_from),
  check ((status in ('ACTIVE','RETIRED')) = (approved_by is not null and approved_at is not null)),
  check (approved_by is null or approved_by <> proposed_by)
);

create unique index franchise_followup_one_active_policy_uidx
  on public.franchise_followup_policy_versions(franchise_id) where status = 'ACTIVE';

create table public.franchise_followup_preference_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  franchise_id uuid not null references public.franchises(id) on delete restrict,
  prospect_id uuid not null references public.franchise_crm_prospects(id) on delete restrict,
  version integer not null check (version > 0),
  supersedes_preference_version_id uuid references public.franchise_followup_preference_versions(id) on delete restrict,
  contact_allowed boolean not null,
  email_allowed boolean not null,
  locale text not null check (locale in ('fr','ar')),
  time_zone text not null,
  quiet_hours_start time not null,
  quiet_hours_end time not null,
  maximum_reminders_per_7_days integer not null check (maximum_reminders_per_7_days between 0 and 8),
  effective_from timestamptz not null default clock_timestamp(),
  change_reason text not null check (length(btrim(change_reason)) between 10 and 1000),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (prospect_id, version),
  unique (id, franchise_id),
  foreign key (prospect_id, franchise_id) references public.franchise_crm_prospects(id, franchise_id) on delete restrict,
  check (contact_allowed or not email_allowed),
  check (quiet_hours_start <> quiet_hours_end)
);

create table public.franchise_followup_jobs (
  id uuid primary key default extensions.gen_random_uuid(),
  franchise_id uuid not null references public.franchises(id) on delete restrict,
  prospect_id uuid not null references public.franchise_crm_prospects(id) on delete restrict,
  policy_version_id uuid not null,
  preference_version_id uuid not null,
  followup_anchor_at timestamptz not null,
  reminder_ordinal integer not null check (reminder_ordinal between 1 and 8),
  channel text not null check (channel = 'EMAIL'),
  locale text not null check (locale in ('fr','ar')),
  status text not null default 'PENDING' check (status in ('PENDING','LEASED','RETRY','SUCCEEDED','CANCELLED','DEAD_LETTER')),
  next_attempt_at timestamptz not null,
  attempt_count integer not null default 0 check (attempt_count between 0 and 10),
  maximum_attempts_snapshot integer not null check (maximum_attempts_snapshot between 1 and 10),
  retry_delays_minutes_snapshot integer[] not null check (cardinality(retry_delays_minutes_snapshot) between 1 and 10),
  lease_seconds_snapshot integer not null check (lease_seconds_snapshot between 30 and 900),
  locked_by uuid,
  locked_at timestamptz,
  lease_until timestamptz,
  last_error_code text check (last_error_code is null or last_error_code ~ '^[A-Z][A-Z0-9_]{2,79}$'),
  correlation_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  dead_lettered_at timestamptz,
  unique (prospect_id, policy_version_id, followup_anchor_at, reminder_ordinal),
  foreign key (policy_version_id, franchise_id) references public.franchise_followup_policy_versions(id, franchise_id) on delete restrict,
  foreign key (preference_version_id, franchise_id) references public.franchise_followup_preference_versions(id, franchise_id) on delete restrict,
  foreign key (prospect_id, franchise_id) references public.franchise_crm_prospects(id, franchise_id) on delete restrict,
  check ((status = 'LEASED') = (locked_by is not null and locked_at is not null and lease_until is not null)),
  check ((status = 'SUCCEEDED') = (completed_at is not null)),
  check ((status = 'DEAD_LETTER') = (dead_lettered_at is not null))
);

create function private.guard_franchise_followup_policy_history() returns trigger
language plpgsql set search_path = pg_catalog, public, private as $$
begin
  if tg_op = 'DELETE' then raise exception 'FRANCHISE_FOLLOWUP_HISTORY_IMMUTABLE' using errcode = '55000'; end if;
  if old.status = 'PENDING_APPROVAL' and new.status in ('ACTIVE','REJECTED')
    and (to_jsonb(new) - array['status','approved_by','approved_at']) = (to_jsonb(old) - array['status','approved_by','approved_at']) then return new; end if;
  if old.status = 'ACTIVE' and new.status = 'RETIRED'
    and (to_jsonb(new) - 'status') = (to_jsonb(old) - 'status') then return new; end if;
  raise exception 'FRANCHISE_FOLLOWUP_HISTORY_IMMUTABLE' using errcode = '55000';
end
$$;

create function private.prevent_franchise_followup_history_change() returns trigger
language plpgsql set search_path = pg_catalog, public, private as $$
begin raise exception 'FRANCHISE_FOLLOWUP_HISTORY_IMMUTABLE' using errcode = '55000'; end
$$;

create trigger franchise_followup_policy_history_immutable before update or delete on public.franchise_followup_policy_versions
for each row execute function private.guard_franchise_followup_policy_history();
create trigger franchise_followup_preference_history_immutable before update or delete on public.franchise_followup_preference_versions
for each row execute function private.prevent_franchise_followup_history_change();

create function private.valid_positive_ascending_minutes(p_values integer[]) returns boolean
language sql immutable set search_path = pg_catalog as $$
  select cardinality(p_values) > 0
    and not exists(select 1 from unnest(p_values) with ordinality x(value, position) where value < 0 or value > 525600)
    and not exists(select 1 from unnest(p_values) with ordinality x(value, position) join unnest(p_values) with ordinality y(value, position) on y.position = x.position + 1 where y.value <= x.value)
$$;

create function private.franchise_followup_quiet(p_preference public.franchise_followup_preference_versions, p_at timestamptz) returns boolean
language sql stable set search_path = pg_catalog, public as $$
  select case
    when p_preference.quiet_hours_start < p_preference.quiet_hours_end
      then timezone(p_preference.time_zone, p_at)::time >= p_preference.quiet_hours_start
       and timezone(p_preference.time_zone, p_at)::time < p_preference.quiet_hours_end
    else timezone(p_preference.time_zone, p_at)::time >= p_preference.quiet_hours_start
      or timezone(p_preference.time_zone, p_at)::time < p_preference.quiet_hours_end
  end
$$;

create function public.propose_franchise_followup_policy(
  p_franchise_id uuid, p_eligible_stages text[], p_reminder_delays_minutes integer[],
  p_retry_delays_minutes integer[], p_maximum_attempts integer, p_maximum_reminders_per_7_days integer,
  p_lease_seconds integer, p_effective_from timestamptz, p_effective_until timestamptz,
  p_change_reason text, p_idempotency_key text, p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare a uuid := auth.uid(); f public.franchises%rowtype; v integer; previous uuid; h text; r jsonb; new_id uuid;
begin
  select * into f from public.franchises where id = p_franchise_id;
  if a is null or f.id is null or f.status <> 'ACTIVE' or not private.franchise_crm_write_access(f.id, a) then
    raise exception 'FRANCHISE_FOLLOWUP_POLICY_PROPOSE_DENIED' using errcode = '42501';
  end if;
  if not exists(select 1 from public.franchise_approval_requests q where q.franchise_id = f.id and q.status = 'APPROVED')
    or cardinality(p_eligible_stages) not between 1 and 8
    or not (p_eligible_stages <@ array['SENT','OPENED','REGISTERED','PROFILE_STARTED','VERIFIED','DIAGNOSTIC_STARTED','OPPORTUNITY_CREATED','RFQ_STARTED']::text[])
    or not private.valid_positive_ascending_minutes(p_reminder_delays_minutes)
    or not private.valid_positive_ascending_minutes(p_retry_delays_minutes) or p_retry_delays_minutes[1] < 1
    or cardinality(p_retry_delays_minutes) > 10 or p_maximum_attempts not between 1 and 10
    or p_maximum_attempts > cardinality(p_retry_delays_minutes) + 1
    or p_maximum_reminders_per_7_days not between 1 and 8 or p_lease_seconds not between 30 and 900
    or p_effective_from < clock_timestamp() - interval '5 minutes'
    or p_effective_until <= p_effective_from
    or length(btrim(coalesce(p_change_reason,''))) not between 10 and 1000 then
    raise exception 'INVALID_FRANCHISE_FOLLOWUP_POLICY' using errcode = '22023';
  end if;
  h := private.canonical_request_hash(jsonb_build_object('franchise_id',f.id,'eligible_stages',p_eligible_stages,'reminder_delays_minutes',p_reminder_delays_minutes,'retry_delays_minutes',p_retry_delays_minutes,'maximum_attempts',p_maximum_attempts,'maximum_reminders_per_7_days',p_maximum_reminders_per_7_days,'lease_seconds',p_lease_seconds,'effective_from',p_effective_from,'effective_until',p_effective_until,'change_reason',p_change_reason));
  r := private.begin_contract_command(f.operator_organization_id,'franchise.followup.policy.propose.'||f.id::text,p_idempotency_key,h,a);
  if r is not null then return r; end if;
  perform pg_advisory_xact_lock(hashtextextended('franchise-followup-policy:'||f.id::text,0));
  select coalesce(max(version),0)+1 into v from public.franchise_followup_policy_versions where franchise_id = f.id;
  select id into previous from public.franchise_followup_policy_versions where franchise_id = f.id order by version desc limit 1;
  insert into public.franchise_followup_policy_versions(franchise_id,version,supersedes_policy_version_id,status,eligible_stages,reminder_delays_minutes,retry_delays_minutes,maximum_attempts,maximum_reminders_per_7_days,lease_seconds,effective_from,effective_until,change_reason,content_hash,proposed_by)
  values(f.id,v,previous,'PENDING_APPROVAL',p_eligible_stages,p_reminder_delays_minutes,p_retry_delays_minutes,p_maximum_attempts,p_maximum_reminders_per_7_days,p_lease_seconds,p_effective_from,p_effective_until,p_change_reason,h,a) returning id into new_id;
  r := jsonb_build_object('outcome','FRANCHISE_FOLLOWUP_POLICY_APPROVAL_REQUIRED','policy_version_id',new_id,'version',v,'content_hash',h);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(f.operator_organization_id,a,'USER','franchise.followup.policy_proposed','franchise_followup_policy',new_id::text,p_correlation_id,jsonb_build_object('franchise_id',f.id,'version',v,'content_hash',h),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
  values(f.operator_organization_id,'franchise_followup_policy',new_id::text,'FranchiseFollowupPolicyProposedV1',p_correlation_id,jsonb_build_object('policy_version_id',new_id,'franchise_id',f.id,'version',v,'content_hash',h),p_idempotency_key);
  perform private.finish_contract_command(f.operator_organization_id,'franchise.followup.policy.propose.'||f.id::text,p_idempotency_key,r);
  return r;
end $$;

create function public.decide_franchise_followup_policy(
  p_policy_version_id uuid, p_decision text, p_reason text, p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare a uuid := auth.uid(); p public.franchise_followup_policy_versions%rowtype; f public.franchises%rowtype; h text; r jsonb;
begin
  select * into p from public.franchise_followup_policy_versions where id = p_policy_version_id for update;
  select * into f from public.franchises where id = p.franchise_id;
  if a is null or p.id is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],a)
    or auth.jwt()->>'aal' <> 'aal2' or a = p.proposed_by then
    raise exception 'FRANCHISE_FOLLOWUP_POLICY_DECIDE_DENIED' using errcode = '42501';
  end if;
  if p.status <> 'PENDING_APPROVAL' or p_decision not in ('APPROVE','REJECT')
    or length(btrim(coalesce(p_reason,''))) not between 10 and 1000 then
    raise exception 'INVALID_FRANCHISE_FOLLOWUP_POLICY_DECISION' using errcode = '22023';
  end if;
  h := private.canonical_request_hash(jsonb_build_object('policy_version_id',p.id,'decision',p_decision,'reason',p_reason,'content_hash',p.content_hash));
  r := private.begin_contract_command(f.operator_organization_id,'franchise.followup.policy.decide.'||p.id::text,p_idempotency_key,h,a);
  if r is not null then return r; end if;
  if p_decision = 'APPROVE' then
    update public.franchise_followup_policy_versions set status = 'RETIRED'
      where franchise_id = p.franchise_id and status = 'ACTIVE';
    update public.franchise_followup_policy_versions set status = 'ACTIVE', approved_by = a, approved_at = clock_timestamp()
      where id = p.id;
  else
    update public.franchise_followup_policy_versions set status = 'REJECTED' where id = p.id;
  end if;
  r := jsonb_build_object('outcome',case p_decision when 'APPROVE' then 'FRANCHISE_FOLLOWUP_POLICY_APPROVED' else 'FRANCHISE_FOLLOWUP_POLICY_REJECTED' end,'policy_version_id',p.id,'version',p.version,'content_hash',p.content_hash);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(f.operator_organization_id,a,'USER','franchise.followup.policy_decided','franchise_followup_policy',p.id::text,p_correlation_id,jsonb_build_object('franchise_id',p.franchise_id,'version',p.version,'decision',p_decision,'content_hash',p.content_hash),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
  values(f.operator_organization_id,'franchise_followup_policy',p.id::text,'FranchiseFollowupPolicyDecidedV1',p_correlation_id,jsonb_build_object('policy_version_id',p.id,'franchise_id',p.franchise_id,'version',p.version,'decision',p_decision,'content_hash',p.content_hash),p_idempotency_key);
  perform private.finish_contract_command(f.operator_organization_id,'franchise.followup.policy.decide.'||p.id::text,p_idempotency_key,r);
  return r;
end $$;

create function public.configure_franchise_followup_preference(
  p_prospect_id uuid, p_contact_allowed boolean, p_email_allowed boolean, p_locale text, p_time_zone text,
  p_quiet_hours_start time, p_quiet_hours_end time, p_maximum_reminders_per_7_days integer,
  p_change_reason text, p_idempotency_key text, p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare a uuid := auth.uid(); prospect public.franchise_crm_prospects%rowtype; f public.franchises%rowtype; v integer; previous uuid; h text; r jsonb; new_id uuid;
begin
  select * into prospect from public.franchise_crm_prospects where id = p_prospect_id;
  select * into f from public.franchises where id = prospect.franchise_id;
  if a is null or prospect.id is null or not private.franchise_crm_write_access(prospect.franchise_id,a) then
    raise exception 'FRANCHISE_FOLLOWUP_PREFERENCE_DENIED' using errcode = '42501';
  end if;
  if p_locale not in ('fr','ar') or not exists(select 1 from pg_timezone_names where name = p_time_zone)
    or p_quiet_hours_start = p_quiet_hours_end or p_maximum_reminders_per_7_days not between 0 and 8
    or (not p_contact_allowed and p_email_allowed) or length(btrim(coalesce(p_change_reason,''))) not between 10 and 1000 then
    raise exception 'INVALID_FRANCHISE_FOLLOWUP_PREFERENCE' using errcode = '22023';
  end if;
  h := private.canonical_request_hash(jsonb_build_object('prospect_id',prospect.id,'contact_allowed',p_contact_allowed,'email_allowed',p_email_allowed,'locale',p_locale,'time_zone',p_time_zone,'quiet_hours_start',p_quiet_hours_start,'quiet_hours_end',p_quiet_hours_end,'maximum_reminders_per_7_days',p_maximum_reminders_per_7_days,'change_reason',p_change_reason));
  r := private.begin_contract_command(f.operator_organization_id,'franchise.followup.preference.configure.'||prospect.id::text,p_idempotency_key,h,a);
  if r is not null then return r; end if;
  perform pg_advisory_xact_lock(hashtextextended('franchise-followup-preference:'||prospect.id::text,0));
  select coalesce(max(version),0)+1 into v from public.franchise_followup_preference_versions where prospect_id = prospect.id;
  select id into previous from public.franchise_followup_preference_versions where prospect_id = prospect.id order by version desc limit 1;
  insert into public.franchise_followup_preference_versions(franchise_id,prospect_id,version,supersedes_preference_version_id,contact_allowed,email_allowed,locale,time_zone,quiet_hours_start,quiet_hours_end,maximum_reminders_per_7_days,change_reason,content_hash,created_by)
  values(prospect.franchise_id,prospect.id,v,previous,p_contact_allowed,p_email_allowed,p_locale,p_time_zone,p_quiet_hours_start,p_quiet_hours_end,p_maximum_reminders_per_7_days,p_change_reason,h,a) returning id into new_id;
  r := jsonb_build_object('outcome','FRANCHISE_FOLLOWUP_PREFERENCE_CONFIGURED','preference_version_id',new_id,'prospect_id',prospect.id,'version',v,'contact_allowed',p_contact_allowed,'email_allowed',p_email_allowed,'content_hash',h);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(f.operator_organization_id,a,'USER','franchise.followup.preference_configured','franchise_followup_preference',new_id::text,p_correlation_id,jsonb_build_object('franchise_id',prospect.franchise_id,'prospect_id',prospect.id,'version',v,'contact_allowed',p_contact_allowed,'email_allowed',p_email_allowed,'content_hash',h),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
  values(f.operator_organization_id,'franchise_followup_preference',new_id::text,'FranchiseFollowupPreferenceConfiguredV1',p_correlation_id,jsonb_build_object('preference_version_id',new_id,'prospect_id',prospect.id,'franchise_id',prospect.franchise_id,'version',v,'contact_allowed',p_contact_allowed,'email_allowed',p_email_allowed,'content_hash',h),p_idempotency_key);
  perform private.finish_contract_command(f.operator_organization_id,'franchise.followup.preference.configure.'||prospect.id::text,p_idempotency_key,r);
  return r;
end $$;

create function public.schedule_franchise_followups(p_now timestamptz default clock_timestamp(), p_limit integer default 100)
returns setof jsonb language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare candidate record; delay_row record; job_id uuid; created_count integer := 0; recent_count integer; allowed_count integer; corr uuid;
begin
  if auth.role() <> 'service_role' then raise exception 'FRANCHISE_FOLLOWUP_SCHEDULER_ONLY' using errcode = '42501'; end if;
  if p_limit not between 1 and 500 then raise exception 'INVALID_FRANCHISE_FOLLOWUP_SCHEDULE_LIMIT' using errcode = '22023'; end if;
  for candidate in
    select prospect.*, policy.id policy_id, policy.reminder_delays_minutes, policy.retry_delays_minutes,
      policy.maximum_attempts, policy.maximum_reminders_per_7_days policy_weekly_limit, policy.lease_seconds,
      preference.id preference_id, preference.locale, preference.maximum_reminders_per_7_days preference_weekly_limit
    from public.franchise_crm_prospects prospect
    join public.franchises franchise on franchise.id = prospect.franchise_id and franchise.status = 'ACTIVE'
    join lateral (select p.* from public.franchise_followup_policy_versions p where p.franchise_id = prospect.franchise_id and p.status = 'ACTIVE' and p.effective_from <= p_now and (p.effective_until is null or p.effective_until > p_now) order by p.version desc limit 1) policy on prospect.pipeline_stage = any(policy.eligible_stages)
    join lateral (select preference.* from public.franchise_followup_preference_versions preference where preference.prospect_id = prospect.id and preference.effective_from <= p_now order by preference.version desc limit 1) preference on preference.contact_allowed and preference.email_allowed and preference.maximum_reminders_per_7_days > 0
    where prospect.next_followup_at is not null and prospect.next_followup_at <= p_now
    order by prospect.next_followup_at, prospect.id
    limit p_limit
  loop
    select count(*) into recent_count from public.franchise_followup_jobs j where j.prospect_id = candidate.id and j.created_at >= p_now - interval '7 days' and j.status not in ('CANCELLED','DEAD_LETTER');
    allowed_count := least(candidate.policy_weekly_limit,candidate.preference_weekly_limit) - recent_count;
    if allowed_count <= 0 then continue; end if;
    for delay_row in select value::integer delay_minutes, ordinality::integer ordinal from unnest(candidate.reminder_delays_minutes) with ordinality where candidate.next_followup_at + make_interval(mins => value) <= p_now order by ordinality limit allowed_count
    loop
      exit when created_count >= p_limit;
      corr := extensions.gen_random_uuid(); job_id := null;
      insert into public.franchise_followup_jobs(franchise_id,prospect_id,policy_version_id,preference_version_id,followup_anchor_at,reminder_ordinal,channel,locale,next_attempt_at,maximum_attempts_snapshot,retry_delays_minutes_snapshot,lease_seconds_snapshot,correlation_id)
      values(candidate.franchise_id,candidate.id,candidate.policy_id,candidate.preference_id,candidate.next_followup_at,delay_row.ordinal,'EMAIL',candidate.locale,greatest(p_now,candidate.next_followup_at + make_interval(mins => delay_row.delay_minutes)),candidate.maximum_attempts,candidate.retry_delays_minutes,candidate.lease_seconds,corr)
      on conflict(prospect_id,policy_version_id,followup_anchor_at,reminder_ordinal) do nothing returning id into job_id;
      if job_id is not null then
        created_count := created_count + 1;
        insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
        select f.operator_organization_id,null,'SYSTEM','franchise.followup.scheduled','franchise_followup_job',job_id::text,corr,jsonb_build_object('franchise_id',candidate.franchise_id,'prospect_id',candidate.id,'policy_version_id',candidate.policy_id,'preference_version_id',candidate.preference_id,'reminder_ordinal',delay_row.ordinal),repeat('0',64) from public.franchises f where f.id = candidate.franchise_id;
        return next jsonb_build_object('job_id',job_id,'franchise_id',candidate.franchise_id,'prospect_id',candidate.id,'reminder_ordinal',delay_row.ordinal);
      end if;
    end loop;
    exit when created_count >= p_limit;
  end loop;
  return;
end $$;

create function public.claim_franchise_followup_jobs(p_worker_id uuid, p_limit integer default 25, p_now timestamptz default clock_timestamp())
returns setof public.franchise_followup_jobs language plpgsql security definer set search_path = pg_catalog, public, private as $$
begin
  if auth.role() <> 'service_role' then raise exception 'FRANCHISE_FOLLOWUP_WORKER_ONLY' using errcode = '42501'; end if;
  if p_worker_id is null or p_limit not between 1 and 100 then raise exception 'INVALID_FRANCHISE_FOLLOWUP_CLAIM' using errcode = '22023'; end if;
  with stale as (select id from public.franchise_followup_jobs where status = 'LEASED' and lease_until <= p_now order by lease_until,id for update skip locked limit p_limit)
  update public.franchise_followup_jobs j set status = 'RETRY', locked_by = null, locked_at = null, lease_until = null,
    next_attempt_at = greatest(j.next_attempt_at,p_now) from stale where j.id = stale.id;
  with quiet as (
    select j.id from public.franchise_followup_jobs j join public.franchise_followup_preference_versions preference on preference.id = j.preference_version_id
    where j.status in ('PENDING','RETRY') and j.next_attempt_at <= p_now and private.franchise_followup_quiet(preference,p_now)
    order by j.next_attempt_at,j.id for update of j skip locked limit p_limit
  ) update public.franchise_followup_jobs j set next_attempt_at = p_now + interval '30 minutes' from quiet where j.id = quiet.id;
  return query
  with selected as (
    select j.id from public.franchise_followup_jobs j
    join public.franchise_followup_preference_versions preference on preference.id = j.preference_version_id
    where j.status in ('PENDING','RETRY') and j.next_attempt_at <= p_now
      and not private.franchise_followup_quiet(preference,p_now)
      and preference.contact_allowed and preference.email_allowed
      and not exists(select 1 from public.franchise_followup_preference_versions newer where newer.prospect_id = preference.prospect_id and newer.version > preference.version and (not newer.contact_allowed or not newer.email_allowed))
    order by j.next_attempt_at,j.id for update of j skip locked limit p_limit
  )
  update public.franchise_followup_jobs j set status = 'LEASED', locked_by = p_worker_id, locked_at = p_now,
    lease_until = p_now + make_interval(secs => j.lease_seconds_snapshot)
  from selected where j.id = selected.id returning j.*;
end $$;

create function public.complete_franchise_followup_job(p_job_id uuid, p_worker_id uuid, p_now timestamptz default clock_timestamp())
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, private as $$
declare j public.franchise_followup_jobs%rowtype; org uuid; payload jsonb;
begin
  if auth.role() <> 'service_role' then raise exception 'FRANCHISE_FOLLOWUP_WORKER_ONLY' using errcode = '42501'; end if;
  select * into j from public.franchise_followup_jobs where id = p_job_id for update;
  if j.id is null or j.status <> 'LEASED' or j.locked_by <> p_worker_id or j.lease_until <= p_now then raise exception 'FRANCHISE_FOLLOWUP_LEASE_INVALID' using errcode = '40001'; end if;
  select operator_organization_id into org from public.franchises where id = j.franchise_id;
  update public.franchise_followup_jobs set status = 'SUCCEEDED', attempt_count = attempt_count + 1, completed_at = p_now, locked_by = null, locked_at = null, lease_until = null where id = j.id;
  insert into public.franchise_crm_activities(franchise_id,prospect_id,activity_type,occurred_at,summary,evidence_refs,next_followup_at,actor_user_id,correlation_id)
  select j.franchise_id,j.prospect_id,'FOLLOW_UP',p_now,'Relance automatique demandée selon la règle versionnée.',jsonb_build_array(jsonb_build_object('followup_job_id',j.id,'policy_version_id',j.policy_version_id)),prospect.next_followup_at,prospect.owner_user_id,j.correlation_id from public.franchise_crm_prospects prospect where prospect.id = j.prospect_id;
  payload := jsonb_build_object('job_id',j.id,'franchise_id',j.franchise_id,'prospect_id',j.prospect_id,'policy_version_id',j.policy_version_id,'preference_version_id',j.preference_version_id,'channel',j.channel,'locale',j.locale,'reminder_ordinal',j.reminder_ordinal);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(org,null,'SYSTEM','franchise.followup.queued','franchise_followup_job',j.id::text,j.correlation_id,payload,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
  values(org,'franchise_followup_job',j.id::text,'FranchiseFollowupRequestedV1',j.correlation_id,payload,'franchise-followup:'||j.id::text);
  return jsonb_build_object('outcome','FRANCHISE_FOLLOWUP_QUEUED','job_id',j.id);
end $$;

create function public.fail_franchise_followup_job(p_job_id uuid, p_worker_id uuid, p_error_code text, p_now timestamptz default clock_timestamp())
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, private as $$
declare j public.franchise_followup_jobs%rowtype; next_attempt integer; terminal boolean; org uuid; payload jsonb;
begin
  if auth.role() <> 'service_role' then raise exception 'FRANCHISE_FOLLOWUP_WORKER_ONLY' using errcode = '42501'; end if;
  if p_error_code !~ '^[A-Z][A-Z0-9_]{2,79}$' then raise exception 'INVALID_FRANCHISE_FOLLOWUP_ERROR' using errcode = '22023'; end if;
  select * into j from public.franchise_followup_jobs where id = p_job_id for update;
  if j.id is null or j.status <> 'LEASED' or j.locked_by <> p_worker_id or j.lease_until <= p_now then raise exception 'FRANCHISE_FOLLOWUP_LEASE_INVALID' using errcode = '40001'; end if;
  terminal := j.attempt_count + 1 >= j.maximum_attempts_snapshot;
  next_attempt := coalesce(j.retry_delays_minutes_snapshot[least(j.attempt_count + 1,cardinality(j.retry_delays_minutes_snapshot))],60);
  update public.franchise_followup_jobs set status = case when terminal then 'DEAD_LETTER' else 'RETRY' end,
    attempt_count = attempt_count + 1, next_attempt_at = case when terminal then next_attempt_at else p_now + make_interval(mins => next_attempt) end,
    locked_by = null, locked_at = null, lease_until = null, last_error_code = p_error_code,
    dead_lettered_at = case when terminal then p_now else null end where id = j.id;
  select operator_organization_id into org from public.franchises where id = j.franchise_id;
  payload := jsonb_build_object('job_id',j.id,'franchise_id',j.franchise_id,'prospect_id',j.prospect_id,'policy_version_id',j.policy_version_id,'attempt_count',j.attempt_count + 1,'error_code',p_error_code,'terminal',terminal);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(org,null,'SYSTEM',case when terminal then 'franchise.followup.dead_lettered' else 'franchise.followup.retry_scheduled' end,'franchise_followup_job',j.id::text,j.correlation_id,payload,repeat('0',64));
  if terminal then
    insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
    values(org,'franchise_followup_job',j.id::text,'FranchiseFollowupDeadLetteredV1',j.correlation_id,payload,'franchise-followup-dead:'||j.id::text);
  end if;
  return jsonb_build_object('outcome',case when terminal then 'FRANCHISE_FOLLOWUP_DEAD_LETTERED' else 'FRANCHISE_FOLLOWUP_RETRY_SCHEDULED' end,'job_id',j.id,'attempt_count',j.attempt_count + 1);
end $$;

alter table public.franchise_followup_policy_versions enable row level security;
alter table public.franchise_followup_preference_versions enable row level security;
alter table public.franchise_followup_jobs enable row level security;
revoke all on public.franchise_followup_policy_versions,public.franchise_followup_preference_versions,public.franchise_followup_jobs from public,anon,authenticated,service_role;
grant select on public.franchise_followup_policy_versions,public.franchise_followup_preference_versions,public.franchise_followup_jobs to authenticated;
create policy franchise_followup_policy_scoped_read on public.franchise_followup_policy_versions for select to authenticated using (private.franchise_access(franchise_id));
create policy franchise_followup_preference_scoped_read on public.franchise_followup_preference_versions for select to authenticated using (private.franchise_access(franchise_id));
create policy franchise_followup_job_scoped_read on public.franchise_followup_jobs for select to authenticated using (private.franchise_access(franchise_id));

revoke all on function private.guard_franchise_followup_policy_history(),private.prevent_franchise_followup_history_change(),private.valid_positive_ascending_minutes(integer[]),private.franchise_followup_quiet(public.franchise_followup_preference_versions,timestamptz) from public,anon,authenticated,service_role;
revoke all on function public.propose_franchise_followup_policy(uuid,text[],integer[],integer[],integer,integer,integer,timestamptz,timestamptz,text,text,uuid),public.decide_franchise_followup_policy(uuid,text,text,text,uuid),public.configure_franchise_followup_preference(uuid,boolean,boolean,text,text,time,time,integer,text,text,uuid),public.schedule_franchise_followups(timestamptz,integer),public.claim_franchise_followup_jobs(uuid,integer,timestamptz),public.complete_franchise_followup_job(uuid,uuid,timestamptz),public.fail_franchise_followup_job(uuid,uuid,text,timestamptz) from public,anon,authenticated,service_role;
grant execute on function public.propose_franchise_followup_policy(uuid,text[],integer[],integer[],integer,integer,integer,timestamptz,timestamptz,text,text,uuid),public.decide_franchise_followup_policy(uuid,text,text,text,uuid),public.configure_franchise_followup_preference(uuid,boolean,boolean,text,text,time,time,integer,text,text,uuid) to authenticated;
grant execute on function public.schedule_franchise_followups(timestamptz,integer),public.claim_franchise_followup_jobs(uuid,integer,timestamptz),public.complete_franchise_followup_job(uuid,uuid,timestamptz),public.fail_franchise_followup_job(uuid,uuid,text,timestamptz) to service_role;

create index franchise_followup_policy_history_idx on public.franchise_followup_policy_versions(franchise_id,version desc);
create index franchise_followup_preference_history_idx on public.franchise_followup_preference_versions(prospect_id,version desc);
create index franchise_followup_jobs_claim_idx on public.franchise_followup_jobs(next_attempt_at,id) where status in ('PENDING','RETRY','LEASED');
create index franchise_followup_jobs_prospect_window_idx on public.franchise_followup_jobs(prospect_id,created_at desc) where status not in ('CANCELLED','DEAD_LETTER');

notify pgrst,'reload schema';
