create table public.idempotency_keys (
  organization_id uuid not null references public.organizations(id),
  operation_scope text not null check (operation_scope ~ '^[a-z][a-z0-9_.-]{2,99}$'),
  key text not null check (length(key) between 8 and 200),
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  status text not null default 'PROCESSING' check (status in ('PROCESSING','COMPLETED','FAILED')),
  response_code integer,
  response_body jsonb,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  expires_at timestamptz not null,
  primary key (organization_id, operation_scope, key),
  check (expires_at > created_at),
  check ((status = 'COMPLETED') = (completed_at is not null))
);

create table public.audit_events (
  id bigint generated always as identity primary key,
  organization_id uuid references public.organizations(id),
  actor_user_id uuid references auth.users(id),
  actor_type text not null check (actor_type in ('USER','SERVICE','SYSTEM')),
  action text not null check (length(action) between 3 and 160),
  resource_type text not null check (length(resource_type) between 2 and 100),
  resource_id text,
  correlation_id uuid not null,
  occurred_at timestamptz not null default clock_timestamp(),
  request_ip inet,
  user_agent text,
  metadata jsonb not null default '{}'::jsonb,
  previous_hash text,
  event_hash text not null check (event_hash ~ '^[0-9a-f]{64}$')
);

create table public.event_outbox (
  id bigint generated always as identity primary key,
  organization_id uuid references public.organizations(id),
  aggregate_type text not null,
  aggregate_id text not null,
  event_type text not null,
  event_version integer not null default 1 check (event_version > 0),
  correlation_id uuid not null,
  payload jsonb not null,
  occurred_at timestamptz not null default clock_timestamp(),
  available_at timestamptz not null default now(),
  published_at timestamptz,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  last_error_code text,
  unique (aggregate_type, aggregate_id, event_type, event_version, correlation_id)
);

create trigger audit_events_immutable before update or delete on public.audit_events
for each row execute function private.prevent_update_delete();
create trigger event_outbox_no_delete before delete on public.event_outbox
for each row execute function private.prevent_update_delete();

alter table public.idempotency_keys enable row level security;
alter table public.audit_events enable row level security;
alter table public.event_outbox enable row level security;

revoke all on public.idempotency_keys, public.audit_events, public.event_outbox from anon, authenticated;
grant select on public.audit_events to authenticated;
grant select on public.event_outbox to authenticated;

create policy audit_events_tenant_read on public.audit_events for select to authenticated
using ((organization_id is not null and private.is_active_org_member(organization_id)) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));

create policy event_outbox_tenant_read on public.event_outbox for select to authenticated
using ((organization_id is not null and private.has_org_role(organization_id, array['CLIENT_OWNER','CLIENT_ADMIN','PROVIDER_OWNER','FRANCHISE_OWNER'])) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));

create index idempotency_expiry_idx on public.idempotency_keys (expires_at);
create index audit_events_tenant_time_idx on public.audit_events (organization_id, occurred_at desc, id desc);
create index event_outbox_dispatch_idx on public.event_outbox (available_at, id) where published_at is null;
