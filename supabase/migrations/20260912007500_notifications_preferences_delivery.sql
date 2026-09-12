-- P17 notifications V1: bilingual versioned templates, category preferences, inbox and idempotent delivery lifecycle.

create table public.notification_preference_categories (
  code text primary key check (code ~ '^[A-Z][A-Z0-9_]{2,63}$'),
  label_fr text not null check (length(btrim(label_fr)) between 2 and 160),
  label_ar text not null check (length(btrim(label_ar)) between 2 and 160),
  mandatory boolean not null default false,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','RETIRED')),
  created_at timestamptz not null default clock_timestamp()
);

create table public.notification_template_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  template_code text not null check (template_code ~ '^[A-Z][A-Z0-9_.-]{2,99}$'),
  version integer not null check (version > 0),
  event_type text not null check (event_type ~ '^[A-Za-z][A-Za-z0-9_.-]{2,159}$'),
  category_code text not null references public.notification_preference_categories(code) on delete restrict,
  locale text not null check (locale in ('fr-MA','ar-MA')),
  subject_template text not null check (length(btrim(subject_template)) between 2 and 240),
  body_template text not null check (length(btrim(body_template)) between 2 and 4000),
  cta_path_template text check (cta_path_template is null or (cta_path_template like '/%' and cta_path_template not like '//%')),
  priority text not null check (priority in ('INFO','NORMAL','IMPORTANT','CRITICAL')),
  mandatory boolean not null,
  channels text[] not null check (cardinality(channels) between 1 and 2 and channels <@ array['IN_APP','EMAIL']::text[]),
  variable_keys text[] not null default '{}',
  status text not null check (status in ('DRAFT','ACTIVE','RETIRED')),
  effective_from timestamptz not null,
  effective_until timestamptz,
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default clock_timestamp(),
  unique (template_code,version,locale),
  unique (id,locale),
  check (effective_until is null or effective_until > effective_from),
  check (priority <> 'CRITICAL' or mandatory)
);
create unique index notification_template_one_active_locale_uidx on public.notification_template_versions(template_code,locale) where status='ACTIVE';

create table public.notification_retry_policy_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  version integer not null unique check (version > 0),
  max_attempts integer not null check (max_attempts between 1 and 20),
  base_backoff_seconds integer not null check (base_backoff_seconds between 1 and 86400),
  max_backoff_seconds integer not null check (max_backoff_seconds between base_backoff_seconds and 604800),
  status text not null check (status in ('ACTIVE','RETIRED')),
  effective_from timestamptz not null,
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default clock_timestamp()
);
create unique index notification_retry_one_active_uidx on public.notification_retry_policy_versions(status) where status='ACTIVE';

create table public.user_notification_preferences (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  category_code text not null references public.notification_preference_categories(code) on delete restrict,
  channel text not null check (channel in ('IN_APP','EMAIL')),
  delivery_mode text not null check (delivery_mode in ('IMMEDIATE','DIGEST','DISABLED')),
  digest_frequency text check (digest_frequency in ('DAILY','WEEKLY')),
  locale text not null check (locale in ('fr-MA','ar-MA')),
  row_version integer not null default 1 check (row_version > 0),
  updated_at timestamptz not null default clock_timestamp(),
  unique (user_id,organization_id,category_code,channel),
  check ((delivery_mode='DIGEST') = (digest_frequency is not null))
);

create table public.notification_instances (
  id uuid primary key default extensions.gen_random_uuid(),
  recipient_user_id uuid not null references auth.users(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  template_version_id uuid not null references public.notification_template_versions(id) on delete restrict,
  category_code text not null references public.notification_preference_categories(code) on delete restrict,
  event_type text not null,
  locale text not null check (locale in ('fr-MA','ar-MA')),
  subject text not null check (length(btrim(subject)) between 2 and 240),
  body text not null check (length(btrim(body)) between 2 and 4000),
  cta_path text check (cta_path is null or (cta_path like '/%' and cta_path not like '//%')),
  priority text not null check (priority in ('INFO','NORMAL','IMPORTANT','CRITICAL')),
  mandatory boolean not null,
  deduplication_key text not null check (length(deduplication_key) between 8 and 200),
  source_aggregate_type text not null check (length(source_aggregate_type) between 2 and 100),
  source_aggregate_id text not null check (length(source_aggregate_id) between 1 and 200),
  variables_snapshot jsonb not null check (jsonb_typeof(variables_snapshot)='object'),
  read_at timestamptz,
  row_version integer not null default 1 check (row_version > 0),
  correlation_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  unique (recipient_user_id,organization_id,deduplication_key)
);

create table public.notification_deliveries (
  id uuid primary key default extensions.gen_random_uuid(),
  notification_id uuid not null references public.notification_instances(id) on delete restrict,
  channel text not null check (channel in ('IN_APP','EMAIL')),
  delivery_mode text not null check (delivery_mode in ('IMMEDIATE','DIGEST','DISABLED')),
  status text not null check (status in ('PENDING','QUEUED_DIGEST','SENT','DELIVERED','FAILED','DEAD_LETTER','SKIPPED')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz,
  last_error_code text,
  provider_message_id text,
  row_version integer not null default 1 check (row_version > 0),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (notification_id,channel),
  check ((status in ('PENDING','QUEUED_DIGEST','FAILED')) = (next_attempt_at is not null))
);

create table public.notification_delivery_attempts (
  id bigint generated always as identity primary key,
  delivery_id uuid not null references public.notification_deliveries(id) on delete restrict,
  attempt_number integer not null check (attempt_number > 0),
  status text not null check (status in ('SENT','DELIVERED','FAILED')),
  scheduled_at timestamptz,
  attempted_at timestamptz not null default clock_timestamp(),
  next_retry_at timestamptz,
  provider_message_id text,
  error_code text,
  result_snapshot jsonb not null default '{}' check (jsonb_typeof(result_snapshot)='object'),
  idempotency_key text not null check (length(idempotency_key) between 8 and 200),
  correlation_id uuid not null,
  unique (delivery_id,attempt_number),
  unique (delivery_id,idempotency_key),
  check ((status='FAILED') = (error_code is not null))
);

create function private.prevent_notification_history_change() returns trigger language plpgsql set search_path=pg_catalog as $$begin raise exception 'IMMUTABLE_NOTIFICATION_HISTORY' using errcode='55000';end$$;
create function private.guard_notification_template_version() returns trigger language plpgsql set search_path=pg_catalog as $$begin if tg_op='DELETE'or row(old.template_code,old.version,old.event_type,old.category_code,old.locale,old.subject_template,old.body_template,old.cta_path_template,old.priority,old.mandatory,old.channels,old.variable_keys,old.effective_from,old.content_hash)is distinct from row(new.template_code,new.version,new.event_type,new.category_code,new.locale,new.subject_template,new.body_template,new.cta_path_template,new.priority,new.mandatory,new.channels,new.variable_keys,new.effective_from,new.content_hash)or(old.status='RETIRED'and new.status<>'RETIRED')or(new.status='RETIRED'and new.effective_until is null)then raise exception 'IMMUTABLE_NOTIFICATION_TEMPLATE_CONTENT'using errcode='55000';end if;return new;end$$;
create function private.guard_notification_retry_policy_version() returns trigger language plpgsql set search_path=pg_catalog as $$begin if tg_op='DELETE'or row(old.version,old.max_attempts,old.base_backoff_seconds,old.max_backoff_seconds,old.effective_from,old.content_hash)is distinct from row(new.version,new.max_attempts,new.base_backoff_seconds,new.max_backoff_seconds,new.effective_from,new.content_hash)or(old.status='RETIRED'and new.status<>'RETIRED')then raise exception 'IMMUTABLE_NOTIFICATION_RETRY_POLICY_CONTENT'using errcode='55000';end if;return new;end$$;
create trigger notification_templates_immutable before update or delete on public.notification_template_versions for each row execute function private.guard_notification_template_version();
create trigger notification_retry_policies_immutable before update or delete on public.notification_retry_policy_versions for each row execute function private.guard_notification_retry_policy_version();
create trigger notification_attempts_immutable before update or delete on public.notification_delivery_attempts for each row execute function private.prevent_notification_history_change();

create function private.notification_recipient_access(p_user uuid,p_org uuid,p_actor uuid default auth.uid()) returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
 select p_actor is not null and p_user=p_actor and private.is_active_org_member(p_org,p_actor)
$$;
create function private.render_notification_text(p_template text,p_variables jsonb) returns text language plpgsql immutable set search_path=pg_catalog as $$declare k text;v text;r text:=p_template;begin for k,v in select key,value from jsonb_each_text(p_variables) loop r:=replace(r,'{{'||k||'}}',v);end loop;return r;end$$;
create function private.assert_notification_preference() returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$declare c public.notification_preference_categories%rowtype;begin select * into c from public.notification_preference_categories where code=new.category_code and status='ACTIVE';if not found then raise exception 'NOTIFICATION_CATEGORY_INACTIVE' using errcode='22023';end if;if c.mandatory and new.delivery_mode<>'IMMEDIATE'then raise exception 'MANDATORY_NOTIFICATION_MUST_BE_IMMEDIATE' using errcode='23514';end if;return new;end$$;
create trigger notification_preferences_guard before insert or update on public.user_notification_preferences for each row execute function private.assert_notification_preference();
create function private.assert_notification_template_category() returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$declare required boolean;begin select mandatory into required from public.notification_preference_categories where code=new.category_code and status='ACTIVE';if not found or new.mandatory is distinct from required then raise exception 'NOTIFICATION_TEMPLATE_CATEGORY_MISMATCH'using errcode='23514';end if;return new;end$$;
create trigger notification_template_category_guard before insert or update on public.notification_template_versions for each row execute function private.assert_notification_template_category();

create function public.set_notification_preference(p_organization_id uuid,p_category_code text,p_channel text,p_delivery_mode text,p_digest_frequency text,p_locale text,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();c public.notification_preference_categories%rowtype;x public.user_notification_preferences%rowtype;h text;r jsonb;newv integer;
begin
 if a is null or not private.is_active_org_member(p_organization_id,a)then raise exception 'NOTIFICATION_PREFERENCE_DENIED' using errcode='42501';end if;
 select * into c from public.notification_preference_categories where code=p_category_code and status='ACTIVE';
 if not found or p_channel not in('IN_APP','EMAIL')or p_delivery_mode not in('IMMEDIATE','DIGEST','DISABLED')or p_locale not in('fr-MA','ar-MA')or(p_delivery_mode='DIGEST'and p_digest_frequency not in('DAILY','WEEKLY'))or(p_delivery_mode<>'DIGEST'and p_digest_frequency is not null)or(c.mandatory and p_delivery_mode<>'IMMEDIATE')then raise exception 'INVALID_NOTIFICATION_PREFERENCE'using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('organization_id',p_organization_id,'category',p_category_code,'channel',p_channel,'mode',p_delivery_mode,'digest',p_digest_frequency,'locale',p_locale,'expected',p_expected_row_version));r:=private.begin_contract_command(p_organization_id,'notification.preference.set.'||p_category_code||'.'||lower(p_channel),p_idempotency_key,h,a);if r is not null then return r;end if;
 select * into x from public.user_notification_preferences where user_id=a and organization_id=p_organization_id and category_code=p_category_code and channel=p_channel for update;
 if found then if p_expected_row_version<>x.row_version then raise exception 'STALE_NOTIFICATION_PREFERENCE'using errcode='40001';end if;update public.user_notification_preferences set delivery_mode=p_delivery_mode,digest_frequency=case when p_delivery_mode='DIGEST'then p_digest_frequency end,locale=p_locale,row_version=row_version+1,updated_at=clock_timestamp()where id=x.id returning row_version into newv;
 else if p_expected_row_version<>0 then raise exception 'STALE_NOTIFICATION_PREFERENCE'using errcode='40001';end if;insert into public.user_notification_preferences(user_id,organization_id,category_code,channel,delivery_mode,digest_frequency,locale)values(a,p_organization_id,p_category_code,p_channel,p_delivery_mode,case when p_delivery_mode='DIGEST'then p_digest_frequency end,p_locale)returning row_version into newv;end if;
 r:=jsonb_build_object('outcome','NOTIFICATION_PREFERENCE_SAVED','category_code',p_category_code,'channel',p_channel,'delivery_mode',p_delivery_mode,'row_version',newv);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,a,'USER','notification.preference.saved','notification_preference',p_category_code||':'||p_channel,p_correlation_id,jsonb_build_object('delivery_mode',p_delivery_mode,'row_version',newv),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_organization_id,'notification_preference',a::text||':'||p_category_code||':'||p_channel,'NotificationPreferenceSavedV1',p_correlation_id,r,p_idempotency_key);
 perform private.finish_contract_command(p_organization_id,'notification.preference.set.'||p_category_code||'.'||lower(p_channel),p_idempotency_key,r);return r;
end$$;

create function public.list_notification_center(p_organization_id uuid,p_limit integer default 100) returns jsonb language plpgsql stable security definer set search_path=pg_catalog,public,private as $$
declare a uuid:=auth.uid();begin if a is null or not private.is_active_org_member(p_organization_id,a)then raise exception 'NOTIFICATION_CENTER_DENIED'using errcode='42501';end if;if p_limit not between 1 and 200 then raise exception 'INVALID_NOTIFICATION_LIMIT'using errcode='22023';end if;return jsonb_build_object(
 'preferences',coalesce((select jsonb_agg(to_jsonb(p)-array['user_id','organization_id']order by p.category_code,p.channel)from public.user_notification_preferences p where p.user_id=a and p.organization_id=p_organization_id),'[]'::jsonb),
 'notifications',coalesce((select jsonb_agg(to_jsonb(x)order by x.created_at desc,x.id desc)from(select n.id,n.category_code,n.event_type,n.locale,n.subject,n.body,n.cta_path,n.priority,n.mandatory,n.read_at,n.row_version,n.created_at,coalesce(jsonb_agg(jsonb_build_object('id',d.id,'channel',d.channel,'delivery_mode',d.delivery_mode,'status',d.status,'attempt_count',d.attempt_count,'next_attempt_at',d.next_attempt_at,'last_error_code',d.last_error_code)order by d.channel)filter(where d.id is not null),'[]'::jsonb)deliveries from public.notification_instances n join public.notification_deliveries d on d.notification_id=n.id where n.recipient_user_id=a and n.organization_id=p_organization_id and exists(select 1 from public.notification_deliveries i where i.notification_id=n.id and i.channel='IN_APP'and i.status<>'SKIPPED')group by n.id order by n.created_at desc,n.id desc limit p_limit)x),'[]'::jsonb));end$$;

create function public.mark_notification_read(p_notification_id uuid,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();n public.notification_instances%rowtype;h text;r jsonb;begin select * into n from public.notification_instances where id=p_notification_id for update;if a is null or not found or not private.notification_recipient_access(n.recipient_user_id,n.organization_id,a)then raise exception 'NOTIFICATION_READ_DENIED'using errcode='42501';end if;h:=private.canonical_request_hash(jsonb_build_object('notification_id',n.id,'expected',p_expected_row_version));r:=private.begin_contract_command(n.organization_id,'notification.read.'||n.id::text,p_idempotency_key,h,a);if r is not null then return r;end if;if n.row_version<>p_expected_row_version then raise exception 'STALE_NOTIFICATION'using errcode='40001';end if;if n.read_at is null then update public.notification_instances set read_at=clock_timestamp(),row_version=row_version+1 where id=n.id;end if;r:=jsonb_build_object('outcome','NOTIFICATION_READ','notification_id',n.id,'row_version',n.row_version+case when n.read_at is null then 1 else 0 end);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(n.organization_id,a,'USER','notification.read','notification',n.id::text,p_correlation_id,'{}',repeat('0',64));perform private.finish_contract_command(n.organization_id,'notification.read.'||n.id::text,p_idempotency_key,r);return r;end$$;

create function public.retry_notification_delivery(p_delivery_id uuid,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();d public.notification_deliveries%rowtype;n public.notification_instances%rowtype;h text;r jsonb;begin select * into d from public.notification_deliveries where id=p_delivery_id for update;select * into n from public.notification_instances where id=d.notification_id;if a is null or not found or not private.notification_recipient_access(n.recipient_user_id,n.organization_id,a)then raise exception 'NOTIFICATION_RETRY_DENIED'using errcode='42501';end if;h:=private.canonical_request_hash(jsonb_build_object('delivery_id',d.id,'expected',p_expected_row_version));r:=private.begin_contract_command(n.organization_id,'notification.delivery.retry.'||d.id::text,p_idempotency_key,h,a);if r is not null then return r;end if;if d.row_version<>p_expected_row_version or d.status<>'FAILED'then raise exception 'NOTIFICATION_DELIVERY_NOT_RETRYABLE'using errcode='55000';end if;update public.notification_deliveries set status='PENDING',next_attempt_at=clock_timestamp(),last_error_code=null,row_version=row_version+1,updated_at=clock_timestamp()where id=d.id;r:=jsonb_build_object('outcome','NOTIFICATION_DELIVERY_REQUEUED','delivery_id',d.id,'row_version',d.row_version+1);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(n.organization_id,a,'USER','notification.delivery.retried','notification_delivery',d.id::text,p_correlation_id,jsonb_build_object('channel',d.channel),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(n.organization_id,'notification_delivery',d.id::text,'NotificationDeliveryRequeuedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(n.organization_id,'notification.delivery.retry.'||d.id::text,p_idempotency_key,r);return r;end$$;

create function public.enqueue_notification(p_recipient_user_id uuid,p_organization_id uuid,p_template_code text,p_event_type text,p_locale text,p_variables jsonb,p_deduplication_key text,p_source_aggregate_type text,p_source_aggregate_id text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare t public.notification_template_versions%rowtype;nid uuid;ch text;mode text;nextat timestamptz;r jsonb;begin if auth.role()is distinct from'service_role'then raise exception 'NOTIFICATION_ENQUEUE_DENIED'using errcode='42501';end if;if not private.is_active_org_member(p_organization_id,p_recipient_user_id)or jsonb_typeof(p_variables)<>'object'or length(coalesce(p_deduplication_key,''))not between 8 and 200 or length(coalesce(p_source_aggregate_type,''))not between 2 and 100 or length(coalesce(p_source_aggregate_id,''))not between 1 and 200 or exists(select 1 from jsonb_object_keys(p_variables)k where k~*'(password|secret|token|api.?key)')then raise exception 'INVALID_NOTIFICATION_REQUEST'using errcode='22023';end if;select * into t from public.notification_template_versions where template_code=p_template_code and event_type=p_event_type and locale=p_locale and status='ACTIVE'and effective_from<=clock_timestamp()and(effective_until is null or effective_until>clock_timestamp())order by version desc limit 1;if not found then raise exception 'NOTIFICATION_TEMPLATE_NOT_FOUND'using errcode='P0002';end if;if exists(select 1 from jsonb_object_keys(p_variables)k where not(k=any(t.variable_keys)))then raise exception 'UNKNOWN_NOTIFICATION_VARIABLE'using errcode='22023';end if;
 insert into public.notification_instances(recipient_user_id,organization_id,template_version_id,category_code,event_type,locale,subject,body,cta_path,priority,mandatory,deduplication_key,source_aggregate_type,source_aggregate_id,variables_snapshot,correlation_id)values(p_recipient_user_id,p_organization_id,t.id,t.category_code,t.event_type,t.locale,private.render_notification_text(t.subject_template,p_variables),private.render_notification_text(t.body_template,p_variables),case when t.cta_path_template is null then null else private.render_notification_text(t.cta_path_template,p_variables)end,t.priority,t.mandatory,p_deduplication_key,p_source_aggregate_type,p_source_aggregate_id,p_variables,p_correlation_id)on conflict(recipient_user_id,organization_id,deduplication_key)do nothing returning id into nid;
 if nid is null then select id into nid from public.notification_instances where recipient_user_id=p_recipient_user_id and organization_id=p_organization_id and deduplication_key=p_deduplication_key;return jsonb_build_object('outcome','NOTIFICATION_DEDUPLICATED','notification_id',nid);end if;
 foreach ch in array t.channels loop select delivery_mode into mode from public.user_notification_preferences where user_id=p_recipient_user_id and organization_id=p_organization_id and category_code=t.category_code and channel=ch;if mode is null then mode:='IMMEDIATE';end if;if t.mandatory then mode:='IMMEDIATE';end if;nextat:=case mode when'DISABLED'then null when'DIGEST'then date_trunc('day',clock_timestamp())+interval'1 day 8 hours'else clock_timestamp()end;insert into public.notification_deliveries(notification_id,channel,delivery_mode,status,next_attempt_at)values(nid,ch,mode,case mode when'DISABLED'then'SKIPPED'when'DIGEST'then'QUEUED_DIGEST'else'PENDING'end,nextat);end loop;
 r:=jsonb_build_object('outcome','NOTIFICATION_ENQUEUED','notification_id',nid,'template_version_id',t.id);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,null,'SERVICE','notification.enqueued','notification',nid::text,p_correlation_id,jsonb_build_object('template_code',t.template_code,'template_version',t.version,'recipient_user_id',p_recipient_user_id),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(p_organization_id,'notification',nid::text,'NotificationPreparedV1',p_correlation_id,r);return r;end$$;

create function public.record_notification_delivery_attempt(p_delivery_id uuid,p_status text,p_provider_message_id text,p_error_code text,p_result_snapshot jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare d public.notification_deliveries%rowtype;n public.notification_instances%rowtype;pol public.notification_retry_policy_versions%rowtype;prior public.notification_delivery_attempts%rowtype;attempt integer;nextat timestamptz;newstatus text;r jsonb;delay_seconds integer;begin if auth.role()is distinct from'service_role'then raise exception 'NOTIFICATION_ATTEMPT_DENIED'using errcode='42501';end if;select * into prior from public.notification_delivery_attempts where delivery_id=p_delivery_id and idempotency_key=p_idempotency_key;if found then return jsonb_build_object('outcome','NOTIFICATION_ATTEMPT_REPLAYED','attempt_id',prior.id,'status',prior.status);end if;select * into d from public.notification_deliveries where id=p_delivery_id for update;select * into prior from public.notification_delivery_attempts where delivery_id=p_delivery_id and idempotency_key=p_idempotency_key;if found then return jsonb_build_object('outcome','NOTIFICATION_ATTEMPT_REPLAYED','attempt_id',prior.id,'status',prior.status);end if;select * into n from public.notification_instances where id=d.notification_id;select * into pol from public.notification_retry_policy_versions where status='ACTIVE'order by version desc limit 1;if d.id is null or pol.id is null or p_status not in('SENT','DELIVERED','FAILED')or jsonb_typeof(p_result_snapshot)<>'object'or length(coalesce(p_idempotency_key,''))not between 8 and 200 or d.status in('SKIPPED','DELIVERED','DEAD_LETTER')or(p_status='FAILED'and length(coalesce(p_error_code,''))<2)or(p_status<>'FAILED'and p_error_code is not null)then raise exception 'INVALID_NOTIFICATION_ATTEMPT'using errcode='22023';end if;attempt:=d.attempt_count+1;if p_status='FAILED'then if attempt>=pol.max_attempts then newstatus:='DEAD_LETTER';nextat:=null;else delay_seconds:=least(pol.max_backoff_seconds,(pol.base_backoff_seconds*power(2,attempt-1))::integer);newstatus:='FAILED';nextat:=clock_timestamp()+make_interval(secs=>delay_seconds);end if;else newstatus:=p_status;nextat:=null;end if;insert into public.notification_delivery_attempts(delivery_id,attempt_number,status,scheduled_at,next_retry_at,provider_message_id,error_code,result_snapshot,idempotency_key,correlation_id)values(d.id,attempt,p_status,d.next_attempt_at,nextat,p_provider_message_id,p_error_code,p_result_snapshot,p_idempotency_key,p_correlation_id);update public.notification_deliveries set status=newstatus,attempt_count=attempt,next_attempt_at=nextat,last_error_code=p_error_code,provider_message_id=coalesce(p_provider_message_id,provider_message_id),row_version=row_version+1,updated_at=clock_timestamp()where id=d.id;r:=jsonb_build_object('outcome','NOTIFICATION_DELIVERY_RECORDED','delivery_id',d.id,'status',newstatus,'attempt_count',attempt,'next_retry_at',nextat);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(n.organization_id,null,'SERVICE','notification.delivery.recorded','notification_delivery',d.id::text,p_correlation_id,jsonb_build_object('channel',d.channel,'status',newstatus,'attempt_count',attempt,'error_code',p_error_code),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(n.organization_id,'notification_delivery',d.id::text,case newstatus when'DELIVERED'then'NotificationDeliveredV1'when'DEAD_LETTER'then'NotificationDeadLetteredV1'when'FAILED'then'NotificationDeliveryFailedV1'else'NotificationSentV1'end,p_correlation_id,r);return r;end$$;

alter table public.notification_preference_categories enable row level security;alter table public.notification_template_versions enable row level security;alter table public.notification_retry_policy_versions enable row level security;alter table public.user_notification_preferences enable row level security;alter table public.notification_instances enable row level security;alter table public.notification_deliveries enable row level security;alter table public.notification_delivery_attempts enable row level security;
create policy notification_categories_active_read on public.notification_preference_categories for select to authenticated using(status='ACTIVE');
create policy notification_templates_active_read on public.notification_template_versions for select to authenticated using(status='ACTIVE');
create policy notification_preferences_recipient_read on public.user_notification_preferences for select to authenticated using(private.notification_recipient_access(user_id,organization_id));
create policy notification_instances_recipient_read on public.notification_instances for select to authenticated using(private.notification_recipient_access(recipient_user_id,organization_id));
create policy notification_deliveries_recipient_read on public.notification_deliveries for select to authenticated using(exists(select 1 from public.notification_instances n where n.id=notification_id and private.notification_recipient_access(n.recipient_user_id,n.organization_id)));
create policy notification_attempts_recipient_read on public.notification_delivery_attempts for select to authenticated using(exists(select 1 from public.notification_deliveries d join public.notification_instances n on n.id=d.notification_id where d.id=delivery_id and private.notification_recipient_access(n.recipient_user_id,n.organization_id)));

revoke all on public.notification_preference_categories,public.notification_template_versions,public.notification_retry_policy_versions,public.user_notification_preferences,public.notification_instances,public.notification_deliveries,public.notification_delivery_attempts from public,anon,authenticated,service_role;
grant select on public.notification_preference_categories,public.notification_template_versions,public.user_notification_preferences,public.notification_instances,public.notification_deliveries,public.notification_delivery_attempts to authenticated;
revoke all on function private.prevent_notification_history_change(),private.guard_notification_template_version(),private.guard_notification_retry_policy_version(),private.notification_recipient_access(uuid,uuid,uuid),private.render_notification_text(text,jsonb),private.assert_notification_preference(),private.assert_notification_template_category()from public,anon,authenticated,service_role;
grant execute on function private.notification_recipient_access(uuid,uuid,uuid)to authenticated;
revoke all on function public.set_notification_preference(uuid,text,text,text,text,text,integer,text,uuid),public.list_notification_center(uuid,integer),public.mark_notification_read(uuid,integer,text,uuid),public.retry_notification_delivery(uuid,integer,text,uuid),public.enqueue_notification(uuid,uuid,text,text,text,jsonb,text,text,text,uuid),public.record_notification_delivery_attempt(uuid,text,text,text,jsonb,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.set_notification_preference(uuid,text,text,text,text,text,integer,text,uuid),public.list_notification_center(uuid,integer),public.mark_notification_read(uuid,integer,text,uuid),public.retry_notification_delivery(uuid,integer,text,uuid)to authenticated;
grant execute on function public.enqueue_notification(uuid,uuid,text,text,text,jsonb,text,text,text,uuid),public.record_notification_delivery_attempt(uuid,text,text,text,jsonb,text,uuid)to service_role;

create index notification_preferences_user_org_idx on public.user_notification_preferences(user_id,organization_id,category_code);
create index notification_inbox_unread_idx on public.notification_instances(recipient_user_id,organization_id,created_at desc)where read_at is null;
create index notification_delivery_dispatch_idx on public.notification_deliveries(next_attempt_at,id)where status in('PENDING','QUEUED_DIGEST','FAILED');
create index notification_attempt_history_idx on public.notification_delivery_attempts(delivery_id,attempt_number desc);

insert into public.notification_preference_categories(code,label_fr,label_ar,mandatory)values
('SECURITY_CRITICAL','Sécurité critique','الأمن الحرج',true),('BILLING_CRITICAL','Facturation critique','الفوترة الحرجة',true),('TRIAL','Essai','الفترة التجريبية',false),('DOCUMENTS','Documents','الوثائق',false),('RFQ','Demandes et devis','الطلبات والعروض',false),('MISSION','Missions et livraisons','المهام والتسليمات',false),('INCIDENT','Incidents','الحوادث',false),('PROVIDER_BILLING','Facturation fournisseur','فوترة المورد',false),('CREDITS','Crédits','الأرصدة',false),('FRANCHISE','Franchise','الامتياز',false),('ADMIN_DIGEST','Résumé administrateur','ملخص الإدارة',false);
insert into public.notification_retry_policy_versions(version,max_attempts,base_backoff_seconds,max_backoff_seconds,status,effective_from,content_hash)values(1,5,60,86400,'ACTIVE','2026-09-10',private.canonical_request_hash('{"notification_retry":"v1"}'::jsonb));
insert into public.notification_template_versions(template_code,version,event_type,category_code,locale,subject_template,body_template,cta_path_template,priority,mandatory,channels,variable_keys,status,effective_from,content_hash)values
('SYSTEM_ALERT',1,'SystemAlertRaisedV1','SECURITY_CRITICAL','fr-MA','Alerte de sécurité : {{title}}','{{message}}','/fr/securite/compte','CRITICAL',true,array['IN_APP','EMAIL'],array['title','message'],'ACTIVE','2026-09-10',private.canonical_request_hash('{"template":"SYSTEM_ALERT","version":1,"locale":"fr-MA"}'::jsonb)),
('SYSTEM_ALERT',1,'SystemAlertRaisedV1','SECURITY_CRITICAL','ar-MA','تنبيه أمني: {{title}}','{{message}}','/ar/securite/compte','CRITICAL',true,array['IN_APP','EMAIL'],array['title','message'],'ACTIVE','2026-09-10',private.canonical_request_hash('{"template":"SYSTEM_ALERT","version":1,"locale":"ar-MA"}'::jsonb)),
('MISSION_REMINDER',1,'MissionReminderDueV1','MISSION','fr-MA','Rappel de mission : {{title}}','Échéance : {{due_at}}','/fr/client/missions','IMPORTANT',false,array['IN_APP','EMAIL'],array['title','due_at'],'ACTIVE','2026-09-10',private.canonical_request_hash('{"template":"MISSION_REMINDER","version":1,"locale":"fr-MA"}'::jsonb)),
('MISSION_REMINDER',1,'MissionReminderDueV1','MISSION','ar-MA','تذكير بالمهمة: {{title}}','موعد الاستحقاق: {{due_at}}','/ar/client/missions','IMPORTANT',false,array['IN_APP','EMAIL'],array['title','due_at'],'ACTIVE','2026-09-10',private.canonical_request_hash('{"template":"MISSION_REMINDER","version":1,"locale":"ar-MA"}'::jsonb));
