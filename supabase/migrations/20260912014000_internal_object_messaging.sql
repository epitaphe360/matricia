-- MAT-FUNC-007 / MAT-FUNC-067: tenant-bound object messaging with pre-selection contact protection.

create table public.internal_message_threads (
  id uuid primary key default extensions.gen_random_uuid(),
  object_type text not null check (object_type in ('RFQ')),
  object_id uuid not null references public.rfqs(id) on delete restrict,
  service_request_id uuid not null references public.service_requests(id) on delete restrict,
  client_organization_id uuid not null references public.organizations(id) on delete restrict,
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  subject text not null check (length(btrim(subject)) between 3 and 160),
  status text not null default 'OPEN' check (status in ('OPEN','LOCKED')),
  contact_policy_version text not null default 'CONTACT-MASK-V1' check (contact_policy_version ~ '^[A-Z0-9][A-Z0-9._-]{2,39}$'),
  version integer not null default 1 check (version > 0),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (object_type, object_id, provider_organization_id),
  check (client_organization_id <> provider_organization_id)
);

create table public.internal_message_participants (
  id uuid primary key default extensions.gen_random_uuid(),
  thread_id uuid not null references public.internal_message_threads(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  participant_kind text not null check (participant_kind in ('CLIENT','PROVIDER')),
  display_alias text not null check (display_alias in ('CLIENT','PROVIDER')),
  joined_at timestamptz not null default clock_timestamp(),
  unique (thread_id, organization_id),
  unique (thread_id, participant_kind)
);

create table public.internal_messages (
  id uuid primary key default extensions.gen_random_uuid(),
  thread_id uuid not null references public.internal_message_threads(id) on delete restrict,
  sender_participant_id uuid not null references public.internal_message_participants(id) on delete restrict,
  sender_organization_id uuid not null references public.organizations(id) on delete restrict,
  sender_user_id uuid not null references auth.users(id),
  message_kind text not null default 'CLARIFICATION' check (message_kind in ('CLARIFICATION')),
  body text not null check (length(btrim(body)) between 1 and 4000),
  body_format text not null default 'PLAIN_TEXT' check (body_format in ('PLAIN_TEXT')),
  version integer not null default 1 check (version = 1),
  idempotency_key text not null check (length(idempotency_key) between 8 and 200),
  created_at timestamptz not null default clock_timestamp(),
  unique (thread_id, idempotency_key)
);

create table public.internal_message_attachments (
  id uuid primary key default extensions.gen_random_uuid(),
  message_id uuid not null references public.internal_messages(id) on delete restrict,
  storage_bucket text not null check (storage_bucket = 'private-message-attachments'),
  storage_object_path text not null check (length(storage_object_path) between 10 and 800),
  original_file_name text not null check (length(btrim(original_file_name)) between 1 and 255),
  mime_type text not null check (mime_type in ('application/pdf','image/jpeg','image/png','text/plain')),
  size_bytes bigint not null check (size_bytes between 1 and 10485760),
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  scan_status text not null default 'PENDING' check (scan_status in ('PENDING','CLEAN','REJECTED','ERROR')),
  scanned_at timestamptz,
  scan_result_code text check (scan_result_code is null or scan_result_code ~ '^[A-Z0-9_]{2,80}$'),
  created_at timestamptz not null default clock_timestamp(),
  unique (storage_bucket, storage_object_path),
  check ((scan_status = 'PENDING' and scanned_at is null and scan_result_code is null) or (scan_status <> 'PENDING' and scanned_at is not null and scan_result_code is not null))
);

create table private.internal_message_command_keys (
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  operation_scope text not null check (operation_scope in ('messaging.thread.open','messaging.message.send')),
  key text not null check (length(key) between 8 and 200),
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  response_body jsonb,
  command_id uuid not null default extensions.gen_random_uuid() unique,
  created_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  primary key (actor_user_id, operation_scope, key),
  check ((response_body is null) = (completed_at is null))
);

create index internal_message_threads_request_idx on public.internal_message_threads(service_request_id, created_at desc);
create index internal_message_participants_org_idx on public.internal_message_participants(organization_id, thread_id);
create index internal_messages_thread_time_idx on public.internal_messages(thread_id, created_at, id);
create index internal_message_attachments_message_idx on public.internal_message_attachments(message_id);

create or replace function private.prevent_internal_message_mutation() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
begin
  raise exception 'IMMUTABLE_INTERNAL_MESSAGE' using errcode='55000';
end
$$;

create or replace function private.protect_internal_attachment_reference() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
begin
  if tg_op = 'DELETE' then raise exception 'IMMUTABLE_INTERNAL_ATTACHMENT' using errcode='55000'; end if;
  if new.message_id <> old.message_id or new.storage_bucket <> old.storage_bucket or new.storage_object_path <> old.storage_object_path
     or new.original_file_name <> old.original_file_name or new.mime_type <> old.mime_type or new.size_bytes <> old.size_bytes
     or new.sha256 <> old.sha256 or new.created_at <> old.created_at then
    raise exception 'IMMUTABLE_INTERNAL_ATTACHMENT_REFERENCE' using errcode='55000';
  end if;
  if old.scan_status <> 'PENDING' or new.scan_status = 'PENDING' then
    raise exception 'INVALID_ATTACHMENT_SCAN_TRANSITION' using errcode='55000';
  end if;
  return new;
end
$$;

create trigger internal_messages_immutable before update or delete on public.internal_messages
for each row execute function private.prevent_internal_message_mutation();
create trigger internal_message_participants_immutable before update or delete on public.internal_message_participants
for each row execute function private.prevent_internal_message_mutation();
create trigger internal_message_attachments_protected before update or delete on public.internal_message_attachments
for each row execute function private.protect_internal_attachment_reference();

create or replace function private.begin_internal_message_command(p_actor uuid,p_scope text,p_key text,p_hash text)
returns table(command_id uuid,response_body jsonb) language plpgsql security definer set search_path=pg_catalog as $$
declare v private.internal_message_command_keys%rowtype;
begin
  if p_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if length(coalesce(p_key,'')) < 8 or p_hash !~ '^[0-9a-f]{64}$' then raise exception 'INVALID_COMMAND_IDENTITY' using errcode='22023'; end if;
  insert into private.internal_message_command_keys(actor_user_id,operation_scope,key,request_hash)
  values(p_actor,p_scope,p_key,p_hash) on conflict do nothing;
  select * into v from private.internal_message_command_keys k
  where k.actor_user_id=p_actor and k.operation_scope=p_scope and k.key=p_key for update;
  if v.request_hash <> p_hash then raise exception 'IDEMPOTENCY_KEY_REUSED' using errcode='22000'; end if;
  return query select v.command_id,v.response_body;
end
$$;

create or replace function private.finish_internal_message_command(p_actor uuid,p_scope text,p_key text,p_response jsonb)
returns void language plpgsql security definer set search_path=pg_catalog as $$
begin
  update private.internal_message_command_keys set response_body=p_response,completed_at=clock_timestamp()
  where actor_user_id=p_actor and operation_scope=p_scope and key=p_key;
end
$$;

create or replace function private.can_access_internal_message_thread(p_thread_id uuid,p_actor uuid default auth.uid())
returns boolean language sql stable security definer set search_path=pg_catalog as $$
  select exists(
    select 1 from public.internal_message_participants p
    where p.thread_id=p_thread_id and private.is_active_org_member(p.organization_id,p_actor)
  ) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'],p_actor)
$$;

create or replace function private.contains_direct_contact(p_value text)
returns boolean language sql immutable security invoker set search_path=pg_catalog as $$
  select coalesce(p_value,'') ~* '([[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}|https?://|www\.|(\+?[0-9][0-9 ()_.-]{6,}[0-9]))'
$$;

revoke all on function private.prevent_internal_message_mutation(),private.protect_internal_attachment_reference(),private.begin_internal_message_command(uuid,text,text,text),private.finish_internal_message_command(uuid,text,text,jsonb),private.can_access_internal_message_thread(uuid,uuid),private.contains_direct_contact(text) from public,anon,authenticated,service_role;
grant execute on function private.can_access_internal_message_thread(uuid,uuid) to authenticated;

create or replace function public.open_rfq_message_thread(
  p_rfq_id uuid,p_provider_organization_id uuid,p_subject text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare v_actor uuid:=auth.uid();v_rfq public.rfqs%rowtype;v_request public.service_requests%rowtype;v_hash text;v_command uuid;v_replay jsonb;v_thread uuid;v_response jsonb;
begin
  select * into v_rfq from public.rfqs where id=p_rfq_id;
  if not found then raise exception 'RFQ_NOT_FOUND' using errcode='22023'; end if;
  select * into v_request from public.service_requests where id=v_rfq.request_id;
  if v_rfq.status <> 'OPEN' or v_request.status not in ('RFQ_OPEN','QUOTES_RECEIVED','CLIENT_REVIEW') then raise exception 'RFQ_MESSAGING_NOT_OPEN' using errcode='55000'; end if;
  if not exists(select 1 from public.rfq_providers rp where rp.rfq_id=p_rfq_id and rp.provider_organization_id=p_provider_organization_id and rp.status not in ('WITHDRAWN','SUSPENDED')) then
    raise exception 'RFQ_PROVIDER_NOT_INVITED' using errcode='42501';
  end if;
  if not (private.can_manage_client_request(v_request.client_organization_id,v_actor) or private.is_provider_actor(p_provider_organization_id,v_actor)) then
    raise exception 'MESSAGE_THREAD_SCOPE_DENIED' using errcode='42501';
  end if;
  if length(btrim(coalesce(p_subject,''))) not between 3 and 160 or private.contains_direct_contact(p_subject) then raise exception 'INVALID_MESSAGE_SUBJECT' using errcode='22023'; end if;
  v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','messaging.thread.open.v1','rfq_id',p_rfq_id,'provider_organization_id',p_provider_organization_id,'subject',btrim(p_subject))::text,'UTF8'),'sha256'),'hex');
  select b.command_id,b.response_body into v_command,v_replay from private.begin_internal_message_command(v_actor,'messaging.thread.open',p_idempotency_key,v_hash)b;
  if v_replay is not null then return v_replay; end if;
  insert into public.internal_message_threads(object_type,object_id,service_request_id,client_organization_id,provider_organization_id,subject,created_by)
  values('RFQ',p_rfq_id,v_rfq.request_id,v_request.client_organization_id,p_provider_organization_id,btrim(p_subject),v_actor)
  on conflict(object_type,object_id,provider_organization_id) do nothing returning id into v_thread;
  if v_thread is null then select id into v_thread from public.internal_message_threads where object_type='RFQ' and object_id=p_rfq_id and provider_organization_id=p_provider_organization_id; end if;
  insert into public.internal_message_participants(thread_id,organization_id,participant_kind,display_alias)
  values(v_thread,v_request.client_organization_id,'CLIENT','CLIENT'),(v_thread,p_provider_organization_id,'PROVIDER','PROVIDER') on conflict do nothing;
  v_response:=jsonb_build_object('outcome','MESSAGE_THREAD_OPENED','thread_id',v_thread,'command_id',v_command);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(v_request.client_organization_id,v_actor,'USER','messaging.thread.opened','internal_message_thread',v_thread::text,p_correlation_id,jsonb_build_object('rfq_id',p_rfq_id,'command_id',v_command,'contact_policy_version','CONTACT-MASK-V1'),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)
  values(v_request.client_organization_id,'internal_message_thread',v_thread::text,'InternalMessageThreadOpenedV1',p_correlation_id,jsonb_build_object('thread_id',v_thread,'rfq_id',p_rfq_id,'service_request_id',v_rfq.request_id),p_idempotency_key,v_command);
  perform private.finish_internal_message_command(v_actor,'messaging.thread.open',p_idempotency_key,v_response);
  return v_response;
end
$$;

create or replace function public.send_internal_message(
  p_thread_id uuid,p_sender_organization_id uuid,p_body text,p_attachments jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare v_actor uuid:=auth.uid();v_thread public.internal_message_threads%rowtype;v_participant uuid;v_request_status text;v_hash text;v_command uuid;v_replay jsonb;v_message uuid:=extensions.gen_random_uuid();v_response jsonb;v_attachment jsonb;
begin
  select * into v_thread from public.internal_message_threads where id=p_thread_id;
  if not found or v_thread.status <> 'OPEN' then raise exception 'MESSAGE_THREAD_NOT_OPEN' using errcode='55000'; end if;
  select p.id into v_participant from public.internal_message_participants p where p.thread_id=p_thread_id and p.organization_id=p_sender_organization_id;
  if v_participant is null or not private.is_active_org_member(p_sender_organization_id,v_actor) then raise exception 'MESSAGE_THREAD_SCOPE_DENIED' using errcode='42501'; end if;
  if length(btrim(coalesce(p_body,''))) not between 1 and 4000 then raise exception 'INVALID_MESSAGE_BODY' using errcode='22023'; end if;
  select status into v_request_status from public.service_requests where id=v_thread.service_request_id;
  if v_request_status not in ('PROVIDER_SELECTED','CONTRACT_PENDING','CONTRACTED') and private.contains_direct_contact(p_body) then raise exception 'DIRECT_CONTACT_BLOCKED' using errcode='22023'; end if;
  if p_attachments is null then p_attachments:='[]'::jsonb; end if;
  if jsonb_typeof(p_attachments)<>'array' or jsonb_array_length(p_attachments)>5 then raise exception 'INVALID_MESSAGE_ATTACHMENTS' using errcode='22023'; end if;
  for v_attachment in select value from jsonb_array_elements(p_attachments) loop
    if coalesce(v_attachment->>'bucket','')<>'private-message-attachments'
       or coalesce(v_attachment->>'path','') not like ('internal-messages/'||p_thread_id::text||'/%')
       or length(btrim(coalesce(v_attachment->>'name',''))) not between 1 and 255
       or coalesce(v_attachment->>'mime_type','') not in ('application/pdf','image/jpeg','image/png','text/plain')
       or coalesce(v_attachment->>'size_bytes','') !~ '^[0-9]+$' or (v_attachment->>'size_bytes')::bigint not between 1 and 10485760
       or coalesce(v_attachment->>'sha256','') !~ '^[0-9a-f]{64}$' then raise exception 'INVALID_MESSAGE_ATTACHMENT' using errcode='22023';
    end if;
  end loop;
  v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('operation','messaging.message.send.v1','thread_id',p_thread_id,'sender_organization_id',p_sender_organization_id,'body',btrim(p_body),'attachments',p_attachments)::text,'UTF8'),'sha256'),'hex');
  select b.command_id,b.response_body into v_command,v_replay from private.begin_internal_message_command(v_actor,'messaging.message.send',p_idempotency_key,v_hash)b;
  if v_replay is not null then return v_replay; end if;
  insert into public.internal_messages(id,thread_id,sender_participant_id,sender_organization_id,sender_user_id,body,idempotency_key)
  values(v_message,p_thread_id,v_participant,p_sender_organization_id,v_actor,btrim(p_body),p_idempotency_key);
  insert into public.internal_message_attachments(message_id,storage_bucket,storage_object_path,original_file_name,mime_type,size_bytes,sha256)
  select v_message,value->>'bucket',value->>'path',btrim(value->>'name'),value->>'mime_type',(value->>'size_bytes')::bigint,value->>'sha256' from jsonb_array_elements(p_attachments);
  v_response:=jsonb_build_object('outcome','INTERNAL_MESSAGE_SENT','message_id',v_message,'thread_id',p_thread_id,'command_id',v_command);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(p_sender_organization_id,v_actor,'USER','messaging.message.sent','internal_message',v_message::text,p_correlation_id,jsonb_build_object('thread_id',p_thread_id,'attachment_count',jsonb_array_length(p_attachments),'command_id',v_command),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)
  values(p_sender_organization_id,'internal_message',v_message::text,'InternalMessageSentV1',p_correlation_id,jsonb_build_object('message_id',v_message,'thread_id',p_thread_id,'attachment_count',jsonb_array_length(p_attachments)),p_idempotency_key,v_command);
  perform private.finish_internal_message_command(v_actor,'messaging.message.send',p_idempotency_key,v_response);
  return v_response;
end
$$;

create or replace function public.list_internal_message_inbox(p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_actor uuid:=auth.uid();v_result jsonb;
begin
  if v_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if p_limit not between 1 and 200 then raise exception 'INVALID_PAGE_LIMIT' using errcode='22023'; end if;
  select coalesce(jsonb_agg(row_value order by row_value->>'last_message_at' desc),'[]'::jsonb) into v_result from (
    select jsonb_build_object('id',t.id,'object_type',t.object_type,'object_id',t.object_id,'service_request_id',t.service_request_id,'subject',t.subject,'status',t.status,'contact_policy_version',t.contact_policy_version,'participant_organization_id',p.organization_id,'participant_kind',p.participant_kind,'counterparty_alias',case p.participant_kind when 'CLIENT' then 'PROVIDER' else 'CLIENT' end,'created_at',t.created_at,'last_message_at',coalesce(max(m.created_at),t.created_at),'message_count',count(m.id)) row_value
    from public.internal_message_threads t join public.internal_message_participants p on p.thread_id=t.id and private.is_active_org_member(p.organization_id,v_actor)
    left join public.internal_messages m on m.thread_id=t.id
    group by t.id,p.organization_id,p.participant_kind order by coalesce(max(m.created_at),t.created_at) desc limit p_limit
  ) q;
  return v_result;
end
$$;

create or replace function public.get_internal_message_thread(p_thread_id uuid,p_limit integer default 200)
returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_actor uuid:=auth.uid();v_thread public.internal_message_threads%rowtype;v_organization uuid;v_kind text;v_messages jsonb;
begin
  if v_actor is null or not private.can_access_internal_message_thread(p_thread_id,v_actor) then raise exception 'MESSAGE_THREAD_SCOPE_DENIED' using errcode='42501'; end if;
  if p_limit not between 1 and 500 then raise exception 'INVALID_PAGE_LIMIT' using errcode='22023'; end if;
  select * into v_thread from public.internal_message_threads where id=p_thread_id;
  select p.organization_id,p.participant_kind into v_organization,v_kind from public.internal_message_participants p where p.thread_id=p_thread_id and private.is_active_org_member(p.organization_id,v_actor) order by p.joined_at limit 1;
  select coalesce(jsonb_agg(x.row_value order by x.created_at,x.id),'[]'::jsonb) into v_messages from (
    select m.id,m.created_at,jsonb_build_object('id',m.id,'sender_alias',p.display_alias,'mine',m.sender_organization_id=v_organization,'body',m.body,'created_at',m.created_at,'attachments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.original_file_name,'mime_type',a.mime_type,'size_bytes',a.size_bytes,'scan_status',a.scan_status,'download_ready',a.scan_status='CLEAN') order by a.created_at,a.id) from public.internal_message_attachments a where a.message_id=m.id),'[]'::jsonb)) row_value
    from public.internal_messages m join public.internal_message_participants p on p.id=m.sender_participant_id where m.thread_id=p_thread_id order by m.created_at desc,m.id desc limit p_limit
  ) x;
  return jsonb_build_object('thread',jsonb_build_object('id',v_thread.id,'object_type',v_thread.object_type,'object_id',v_thread.object_id,'service_request_id',v_thread.service_request_id,'subject',v_thread.subject,'status',v_thread.status,'contact_policy_version',v_thread.contact_policy_version,'participant_organization_id',v_organization,'participant_kind',v_kind,'counterparty_alias',case v_kind when 'CLIENT' then 'PROVIDER' else 'CLIENT' end,'created_at',v_thread.created_at),'messages',v_messages);
end
$$;

alter table public.internal_message_threads enable row level security;
alter table public.internal_message_participants enable row level security;
alter table public.internal_messages enable row level security;
alter table public.internal_message_attachments enable row level security;

create policy internal_message_threads_participant_read on public.internal_message_threads for select to authenticated using(private.can_access_internal_message_thread(id));
create policy internal_message_participants_thread_read on public.internal_message_participants for select to authenticated using(private.can_access_internal_message_thread(thread_id));
create policy internal_messages_thread_read on public.internal_messages for select to authenticated using(private.can_access_internal_message_thread(thread_id));
create policy internal_message_attachments_thread_read on public.internal_message_attachments for select to authenticated using(exists(select 1 from public.internal_messages m where m.id=message_id and private.can_access_internal_message_thread(m.thread_id)));

revoke all on public.internal_message_threads,public.internal_message_participants,public.internal_messages,public.internal_message_attachments from anon,authenticated,service_role;
grant select on public.internal_message_threads,public.internal_message_participants,public.internal_messages,public.internal_message_attachments to authenticated;
revoke all on function public.open_rfq_message_thread(uuid,uuid,text,text,uuid),public.send_internal_message(uuid,uuid,text,jsonb,text,uuid),public.list_internal_message_inbox(integer),public.get_internal_message_thread(uuid,integer) from public,anon,service_role;
grant execute on function public.open_rfq_message_thread(uuid,uuid,text,text,uuid),public.send_internal_message(uuid,uuid,text,jsonb,text,uuid),public.list_internal_message_inbox(integer),public.get_internal_message_thread(uuid,integer) to authenticated;
