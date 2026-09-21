-- ADM-036/037 / ST-032: immutable credit notes, approved payment plans and collection cases.
-- Invoices stay immutable. Outstanding is derived. No late-interest invention.

create table public.provider_credit_notes (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  invoice_id uuid not null,
  credit_number text not null check (length(btrim(credit_number)) between 3 and 80),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  subtotal_minor bigint not null check (subtotal_minor >= 0),
  tax_minor bigint not null check (tax_minor >= 0),
  total_minor bigint not null check (total_minor = subtotal_minor + tax_minor and total_minor > 0),
  reason text not null check (length(btrim(reason)) between 10 and 2000),
  issued_on date not null,
  journal_id uuid not null,
  document_hash text not null check (document_hash ~ '^[0-9a-f]{64}$'),
  correlation_id uuid not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (provider_organization_id, credit_number),
  unique (provider_organization_id, id),
  foreign key (provider_organization_id, invoice_id) references public.provider_invoices(provider_organization_id, id) on delete restrict,
  foreign key (provider_organization_id, journal_id) references public.financial_journals(organization_id, id) on delete restrict
);

create table public.provider_payment_plans (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  invoice_id uuid not null,
  reason text not null check (length(btrim(reason)) between 10 and 2000),
  requested_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (provider_organization_id, id),
  foreign key (provider_organization_id, invoice_id) references public.provider_invoices(provider_organization_id, id) on delete restrict
);

create table public.provider_payment_plan_decisions (
  id uuid primary key default extensions.gen_random_uuid(),
  plan_id uuid not null,
  provider_organization_id uuid not null,
  decision_version integer not null check (decision_version > 0),
  status text not null check (status in ('REQUESTED','APPROVED','REJECTED','DEFAULTED')),
  reason text not null check (length(btrim(reason)) between 10 and 2000),
  decided_by uuid not null references auth.users(id),
  decided_at timestamptz not null default clock_timestamp(),
  unique (plan_id, decision_version),
  unique (provider_organization_id, id),
  foreign key (provider_organization_id, plan_id) references public.provider_payment_plans(provider_organization_id, id) on delete restrict
);

create table public.provider_payment_plan_installments (
  id bigint generated always as identity primary key,
  plan_id uuid not null,
  provider_organization_id uuid not null,
  sequence integer not null check (sequence > 0),
  due_on date not null,
  amount_minor bigint not null check (amount_minor > 0),
  unique (plan_id, sequence),
  foreign key (provider_organization_id, plan_id) references public.provider_payment_plans(provider_organization_id, id) on delete restrict
);

create table public.provider_collection_cases (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  invoice_id uuid not null,
  reason text not null check (length(btrim(reason)) between 10 and 2000),
  opened_by uuid not null references auth.users(id),
  opened_at timestamptz not null default clock_timestamp(),
  unique (provider_organization_id, id),
  unique (invoice_id),
  foreign key (provider_organization_id, invoice_id) references public.provider_invoices(provider_organization_id, id) on delete restrict
);

create table public.provider_collection_case_decisions (
  id uuid primary key default extensions.gen_random_uuid(),
  case_id uuid not null,
  provider_organization_id uuid not null,
  decision_version integer not null check (decision_version > 0),
  status text not null check (status in ('OPEN','FORMAL_NOTICE','COLLECTION','CLOSED')),
  reason text not null check (length(btrim(reason)) between 10 and 2000),
  decided_by uuid not null references auth.users(id),
  decided_at timestamptz not null default clock_timestamp(),
  unique (case_id, decision_version),
  unique (provider_organization_id, id),
  foreign key (provider_organization_id, case_id) references public.provider_collection_cases(provider_organization_id, id) on delete restrict
);

do $$
declare t text;
begin
  foreach t in array array['provider_credit_notes','provider_payment_plans','provider_payment_plan_decisions','provider_payment_plan_installments','provider_collection_cases','provider_collection_case_decisions']
  loop
    execute format('create trigger %I_immutable before update or delete on public.%I for each row execute function private.prevent_update_delete()', t, t);
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    execute format('grant select on public.%I to authenticated', t);
    execute format('create policy %I_tenant_read on public.%I for select to authenticated using (private.provider_billing_access(provider_organization_id))', t, t);
  end loop;
end$$;

create index provider_credit_notes_invoice_idx on public.provider_credit_notes (invoice_id, id);
create index provider_payment_plans_invoice_idx on public.provider_payment_plans (invoice_id, id);
create index provider_payment_plan_decisions_plan_idx on public.provider_payment_plan_decisions (plan_id, decision_version desc);
create index provider_payment_plan_installments_plan_idx on public.provider_payment_plan_installments (plan_id, sequence);
create index provider_collection_case_decisions_case_idx on public.provider_collection_case_decisions (case_id, decision_version desc);

create or replace function private.provider_invoice_credited_minor(p_invoice_id uuid)
returns bigint language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce(sum(credit.total_minor), 0)::bigint
  from public.provider_credit_notes credit
  where credit.invoice_id = p_invoice_id
$$;

create or replace function private.provider_invoice_paid_minor(p_invoice_id uuid)
returns bigint language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce(sum(allocation.amount_minor), 0)::bigint
  from public.provider_payment_allocations allocation
  where allocation.invoice_id = p_invoice_id
$$;

create or replace function private.provider_invoice_outstanding_minor(p_invoice_id uuid)
returns bigint language sql stable security definer set search_path = pg_catalog, public, private as $$
  select i.total_minor
    - private.provider_invoice_paid_minor(i.id)
    - private.provider_invoice_credited_minor(i.id)
  from public.provider_invoices i
  where i.id = p_invoice_id
$$;

create or replace function private.provider_payment_plan_status(p_plan_id uuid)
returns text language sql stable security definer set search_path = pg_catalog, public as $$
  select d.status
  from public.provider_payment_plan_decisions d
  where d.plan_id = p_plan_id
  order by d.decision_version desc
  limit 1
$$;

create or replace function private.provider_invoice_has_approved_plan(p_invoice_id uuid)
returns boolean language sql stable security definer set search_path = pg_catalog, public, private as $$
  select exists (
    select 1
    from public.provider_payment_plans plan
    where plan.invoice_id = p_invoice_id
      and private.provider_payment_plan_status(plan.id) = 'APPROVED'
  )
$$;

create or replace function private.provider_collection_case_status(p_case_id uuid)
returns text language sql stable security definer set search_path = pg_catalog, public as $$
  select d.status
  from public.provider_collection_case_decisions d
  where d.case_id = p_case_id
  order by d.decision_version desc
  limit 1
$$;

revoke all on function private.provider_invoice_credited_minor(uuid), private.provider_invoice_paid_minor(uuid), private.provider_invoice_outstanding_minor(uuid), private.provider_payment_plan_status(uuid), private.provider_invoice_has_approved_plan(uuid), private.provider_collection_case_status(uuid)
  from public, anon, authenticated, service_role;

create or replace view public.provider_invoice_balances with (security_invoker = true) as
select
  i.*,
  coalesce(paid.paid_minor, 0)::bigint as paid_minor,
  greatest(i.total_minor - coalesce(paid.paid_minor, 0) - coalesce(credited.credited_minor, 0), 0)::bigint as outstanding_minor,
  case
    when i.total_minor - coalesce(paid.paid_minor, 0) - coalesce(credited.credited_minor, 0) <= 0 then 'PAID'
    when exists (
      select 1
      from public.provider_payment_plans plan
      join lateral (
        select d.status
        from public.provider_payment_plan_decisions d
        where d.plan_id = plan.id
        order by d.decision_version desc
        limit 1
      ) latest on true
      where plan.invoice_id = i.id and latest.status = 'APPROVED'
    ) then 'PAYMENT_PLAN'
    when i.due_on < current_date then 'OVERDUE'
    when coalesce(paid.paid_minor, 0) + coalesce(credited.credited_minor, 0) > 0 then 'PARTIALLY_PAID'
    else 'ISSUED'
  end as payment_status,
  coalesce(credited.credited_minor, 0)::bigint as credited_minor
from public.provider_invoices i
left join (
  select allocation.invoice_id, sum(allocation.amount_minor)::bigint as paid_minor
  from public.provider_payment_allocations allocation
  group by allocation.invoice_id
) paid on paid.invoice_id = i.id
left join (
  select credit.invoice_id, sum(credit.total_minor)::bigint as credited_minor
  from public.provider_credit_notes credit
  group by credit.invoice_id
) credited on credited.invoice_id = i.id;

revoke all on public.provider_invoice_balances from anon, authenticated;
grant select on public.provider_invoice_balances to authenticated;

create or replace function private.provider_has_overdue_matricia_invoice(p_provider_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.provider_invoice_balances balance
    where balance.provider_organization_id = p_provider_organization_id
      and balance.payment_status = 'OVERDUE'
  );
$$;

revoke all on function private.provider_has_overdue_matricia_invoice(uuid)
  from public, anon, authenticated, service_role;

create or replace function public.reconcile_provider_payment(p_payment_id uuid,p_allocations jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();p public.provider_payments%rowtype;h text;r jsonb;b uuid;x jsonb;requested bigint;already bigint;outstanding bigint;
begin
  select * into p from public.provider_payments where id=p_payment_id for update;
  if a is null or not found or not(private.has_org_role(p.provider_organization_id,array['PROVIDER_OWNER','PROVIDER_ACCOUNTING'],a)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a))then raise exception'PROVIDER_RECONCILIATION_DENIED'using errcode='42501';end if;
  if jsonb_typeof(p_allocations)<>'array'or jsonb_array_length(p_allocations)=0 or exists(select 1 from jsonb_array_elements(p_allocations)e where coalesce((e->>'amount_minor')::bigint,0)<=0)then raise exception'INVALID_PAYMENT_ALLOCATIONS'using errcode='22023';end if;
  select sum((e->>'amount_minor')::bigint)into requested from jsonb_array_elements(p_allocations)e;select coalesce(sum(amount_minor),0)into already from public.provider_payment_allocations where payment_id=p.id;
  if requested+already>p.amount_minor then raise exception'PAYMENT_OVERALLOCATED'using errcode='23514';end if;
  for x in select * from jsonb_array_elements(p_allocations)loop
    select private.provider_invoice_outstanding_minor(i.id) into outstanding
    from public.provider_invoices i
    where i.id=(x->>'invoice_id')::uuid and i.provider_organization_id=p.provider_organization_id and i.currency=p.currency;
    if outstanding is null or outstanding <= 0 or (x->>'amount_minor')::bigint>outstanding then raise exception'INVOICE_OVERALLOCATED_OR_NOT_FOUND'using errcode='23514';end if;
  end loop;
  h:=private.canonical_request_hash(jsonb_build_object('payment',p.id,'allocations',p_allocations));r:=private.begin_provider_billing_command(p.provider_organization_id,'provider.billing.payment.reconcile',p_idempotency_key,h,a);if r is not null then return r;end if;
  insert into public.provider_reconciliation_batches(provider_organization_id,payment_id,allocated_minor,correlation_id,reconciled_by)values(p.provider_organization_id,p.id,requested,p_correlation_id,a)returning id into b;
  insert into public.provider_payment_allocations(provider_organization_id,reconciliation_batch_id,payment_id,invoice_id,amount_minor)select p.provider_organization_id,b,p.id,(e->>'invoice_id')::uuid,(e->>'amount_minor')::bigint from jsonb_array_elements(p_allocations)e;
  r:=jsonb_build_object('outcome','PROVIDER_PAYMENT_RECONCILED','payment_id',p.id,'reconciliation_batch_id',b,'allocated_minor',requested,'unallocated_minor',p.amount_minor-already-requested);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p.provider_organization_id,a,'USER','provider.payment.reconciled','provider_reconciliation_batch',b::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p.provider_organization_id,'provider_payment',p.id::text,'ProviderPaymentReconciledV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(p.provider_organization_id,'provider.billing.payment.reconcile',p_idempotency_key,r);return r;
end$$;

create or replace function public.issue_provider_credit_note(
  p_invoice_id uuid,
  p_credit_number text,
  p_issued_on date,
  p_subtotal_minor bigint,
  p_tax_minor bigint,
  p_reason text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare
  actor uuid := auth.uid();
  invoice public.provider_invoices%rowtype;
  hashed text;
  cached jsonb;
  note uuid;
  journal uuid := extensions.gen_random_uuid();
  receivable uuid;
  revenue uuid;
  tax_account uuid;
  already bigint;
begin
  select * into invoice from public.provider_invoices where id = p_invoice_id;
  if actor is null or not found or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'], actor) then
    raise exception 'PROVIDER_CREDIT_NOTE_DENIED' using errcode = '42501';
  end if;
  if p_subtotal_minor < 0 or p_tax_minor < 0 or p_subtotal_minor + p_tax_minor <= 0 or p_subtotal_minor > invoice.subtotal_minor or p_tax_minor > invoice.tax_minor or p_issued_on < invoice.issued_on or length(btrim(p_reason)) < 10 then
    raise exception 'INVALID_CREDIT_NOTE' using errcode = '22023';
  end if;
  already := private.provider_invoice_credited_minor(invoice.id);
  if already + p_subtotal_minor + p_tax_minor > invoice.total_minor then
    raise exception 'CREDIT_NOTE_EXCEEDS_INVOICE' using errcode = '23514';
  end if;
  select e.account_id into receivable from public.financial_entries e where e.journal_id = invoice.journal_id and e.direction = 'DEBIT' and e.amount_minor = invoice.total_minor limit 1;
  select e.account_id into revenue from public.financial_entries e where e.journal_id = invoice.journal_id and e.direction = 'CREDIT' and e.amount_minor = invoice.subtotal_minor limit 1;
  if invoice.tax_minor > 0 then
    select e.account_id into tax_account from public.financial_entries e where e.journal_id = invoice.journal_id and e.direction = 'CREDIT' and e.amount_minor = invoice.tax_minor limit 1;
  end if;
  if receivable is null or (p_subtotal_minor > 0 and revenue is null) or (p_tax_minor > 0 and tax_account is null) then
    raise exception 'INVALID_PROVIDER_LEDGER_ACCOUNT' using errcode = '23514';
  end if;
  hashed := private.canonical_request_hash(jsonb_build_object('invoice', invoice.id, 'number', p_credit_number, 'issued', p_issued_on, 'subtotal', p_subtotal_minor, 'tax', p_tax_minor, 'reason', btrim(p_reason)));
  cached := private.begin_provider_billing_command(invoice.provider_organization_id, 'provider.billing.credit_note.issue', p_idempotency_key, hashed, actor);
  if cached is not null then return cached; end if;
  insert into public.financial_journals(id, organization_id, journal_type, currency, idempotency_scope, idempotency_key, correlation_id, effective_at, description, created_by)
  values (journal, invoice.provider_organization_id, 'PROVIDER_CREDIT_NOTE', invoice.currency, 'provider.billing.credit_note.issue', p_idempotency_key, p_correlation_id, p_issued_on::timestamptz, 'Provider credit note '||p_credit_number, actor);
  insert into public.financial_entries(organization_id, journal_id, account_id, direction, amount_minor, currency)
  values (invoice.provider_organization_id, journal, receivable, 'CREDIT', p_subtotal_minor + p_tax_minor, invoice.currency);
  if p_subtotal_minor > 0 then
    insert into public.financial_entries(organization_id, journal_id, account_id, direction, amount_minor, currency)
    values (invoice.provider_organization_id, journal, revenue, 'DEBIT', p_subtotal_minor, invoice.currency);
  end if;
  if p_tax_minor > 0 then
    insert into public.financial_entries(organization_id, journal_id, account_id, direction, amount_minor, currency)
    values (invoice.provider_organization_id, journal, tax_account, 'DEBIT', p_tax_minor, invoice.currency);
  end if;
  insert into public.provider_credit_notes(provider_organization_id, invoice_id, credit_number, currency, subtotal_minor, tax_minor, total_minor, reason, issued_on, journal_id, document_hash, correlation_id, created_by)
  values (invoice.provider_organization_id, invoice.id, p_credit_number, invoice.currency, p_subtotal_minor, p_tax_minor, p_subtotal_minor + p_tax_minor, btrim(p_reason), p_issued_on, journal, hashed, p_correlation_id, actor)
  returning id into note;
  cached := jsonb_build_object('outcome', 'PROVIDER_CREDIT_NOTE_ISSUED', 'credit_note_id', note, 'invoice_id', invoice.id, 'journal_id', journal, 'total_minor', p_subtotal_minor + p_tax_minor);
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (invoice.provider_organization_id, actor, 'USER', 'provider.credit_note.issued', 'provider_credit_note', note::text, p_correlation_id, cached, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (invoice.provider_organization_id, 'provider_credit_note', note::text, 'ProviderCreditNoteIssuedV1', p_correlation_id, cached, p_idempotency_key);
  perform private.finish_provider_billing_command(invoice.provider_organization_id, 'provider.billing.credit_note.issue', p_idempotency_key, cached);
  return cached;
end$$;

create or replace function public.request_provider_payment_plan(
  p_invoice_id uuid,
  p_installments jsonb,
  p_reason text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare
  actor uuid := auth.uid();
  invoice public.provider_invoices%rowtype;
  hashed text;
  cached jsonb;
  plan uuid;
  outstanding bigint;
  installment_sum bigint;
begin
  select * into invoice from public.provider_invoices where id = p_invoice_id;
  if actor is null or not found or not (
    private.has_org_role(invoice.provider_organization_id, array['PROVIDER_OWNER','PROVIDER_ACCOUNTING'], actor)
    or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'], actor)
  ) then
    raise exception 'PROVIDER_PAYMENT_PLAN_DENIED' using errcode = '42501';
  end if;
  outstanding := private.provider_invoice_outstanding_minor(invoice.id);
  if outstanding <= 0 or jsonb_typeof(p_installments) <> 'array' or jsonb_array_length(p_installments) not between 2 and 12 or length(btrim(p_reason)) < 10 then
    raise exception 'INVALID_PAYMENT_PLAN' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_installments) item
    where coalesce((item->>'amount_minor')::bigint, 0) <= 0
      or coalesce((item->>'due_on')::date, current_date) <= current_date
  ) then
    raise exception 'INVALID_PAYMENT_PLAN' using errcode = '22023';
  end if;
  select sum((item->>'amount_minor')::bigint) into installment_sum from jsonb_array_elements(p_installments) item;
  if installment_sum is distinct from outstanding then
    raise exception 'PAYMENT_PLAN_AMOUNT_MISMATCH' using errcode = '23514';
  end if;
  if exists (
    select 1 from public.provider_payment_plans existing
    where existing.invoice_id = invoice.id
      and private.provider_payment_plan_status(existing.id) in ('REQUESTED','APPROVED')
  ) then
    raise exception 'PAYMENT_PLAN_ALREADY_OPEN' using errcode = '23505';
  end if;
  hashed := private.canonical_request_hash(jsonb_build_object('invoice', invoice.id, 'installments', p_installments, 'reason', btrim(p_reason)));
  cached := private.begin_provider_billing_command(invoice.provider_organization_id, 'provider.billing.payment_plan.request', p_idempotency_key, hashed, actor);
  if cached is not null then return cached; end if;
  insert into public.provider_payment_plans(provider_organization_id, invoice_id, reason, requested_by)
  values (invoice.provider_organization_id, invoice.id, btrim(p_reason), actor) returning id into plan;
  insert into public.provider_payment_plan_decisions(plan_id, provider_organization_id, decision_version, status, reason, decided_by)
  values (plan, invoice.provider_organization_id, 1, 'REQUESTED', btrim(p_reason), actor);
  insert into public.provider_payment_plan_installments(plan_id, provider_organization_id, sequence, due_on, amount_minor)
  select plan, invoice.provider_organization_id, t.ordinality::integer, (t.item->>'due_on')::date, (t.item->>'amount_minor')::bigint
  from jsonb_array_elements(p_installments) with ordinality as t(item, ordinality);
  cached := jsonb_build_object('outcome', 'PROVIDER_PAYMENT_PLAN_REQUESTED', 'plan_id', plan, 'invoice_id', invoice.id);
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (invoice.provider_organization_id, actor, 'USER', 'provider.payment_plan.requested', 'provider_payment_plan', plan::text, p_correlation_id, cached, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (invoice.provider_organization_id, 'provider_payment_plan', plan::text, 'ProviderPaymentPlanRequestedV1', p_correlation_id, cached, p_idempotency_key);
  perform private.finish_provider_billing_command(invoice.provider_organization_id, 'provider.billing.payment_plan.request', p_idempotency_key, cached);
  return cached;
end$$;

create or replace function public.decide_provider_payment_plan(
  p_plan_id uuid,
  p_status text,
  p_reason text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare
  actor uuid := auth.uid();
  plan public.provider_payment_plans%rowtype;
  hashed text;
  cached jsonb;
  current_status text;
  next_version integer;
begin
  select * into plan from public.provider_payment_plans where id = p_plan_id;
  if actor is null or not found or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'], actor) then
    raise exception 'PROVIDER_PAYMENT_PLAN_DECISION_DENIED' using errcode = '42501';
  end if;
  if p_status not in ('APPROVED','REJECTED') or length(btrim(p_reason)) < 10 then
    raise exception 'INVALID_PAYMENT_PLAN_DECISION' using errcode = '22023';
  end if;
  current_status := private.provider_payment_plan_status(plan.id);
  if current_status is distinct from 'REQUESTED' then
    raise exception 'PAYMENT_PLAN_NOT_DECIDABLE' using errcode = '55000';
  end if;
  hashed := private.canonical_request_hash(jsonb_build_object('plan', plan.id, 'status', p_status, 'reason', btrim(p_reason)));
  cached := private.begin_provider_billing_command(plan.provider_organization_id, 'provider.billing.payment_plan.decide', p_idempotency_key, hashed, actor);
  if cached is not null then return cached; end if;
  select coalesce(max(decision_version), 0) + 1 into next_version from public.provider_payment_plan_decisions where plan_id = plan.id;
  insert into public.provider_payment_plan_decisions(plan_id, provider_organization_id, decision_version, status, reason, decided_by)
  values (plan.id, plan.provider_organization_id, next_version, p_status, btrim(p_reason), actor);
  cached := jsonb_build_object('outcome', case when p_status = 'APPROVED' then 'PROVIDER_PAYMENT_PLAN_APPROVED' else 'PROVIDER_PAYMENT_PLAN_REJECTED' end, 'plan_id', plan.id, 'invoice_id', plan.invoice_id, 'status', p_status);
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (plan.provider_organization_id, actor, 'USER', 'provider.payment_plan.decided', 'provider_payment_plan', plan.id::text, p_correlation_id, cached, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (plan.provider_organization_id, 'provider_payment_plan', plan.id::text, 'ProviderPaymentPlanDecidedV1', p_correlation_id, cached, p_idempotency_key);
  perform private.finish_provider_billing_command(plan.provider_organization_id, 'provider.billing.payment_plan.decide', p_idempotency_key, cached);
  return cached;
end$$;

create or replace function public.open_provider_collection_case(
  p_invoice_id uuid,
  p_reason text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare
  actor uuid := auth.uid();
  invoice public.provider_invoices%rowtype;
  hashed text;
  cached jsonb;
  opened uuid;
  plan uuid;
  next_version integer;
begin
  select * into invoice from public.provider_invoices where id = p_invoice_id;
  if actor is null or not found or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'], actor) then
    raise exception 'PROVIDER_COLLECTION_DENIED' using errcode = '42501';
  end if;
  if length(btrim(p_reason)) < 10 or private.provider_invoice_outstanding_minor(invoice.id) <= 0 or invoice.due_on >= current_date then
    raise exception 'INVALID_COLLECTION_CASE' using errcode = '22023';
  end if;
  hashed := private.canonical_request_hash(jsonb_build_object('invoice', invoice.id, 'reason', btrim(p_reason)));
  cached := private.begin_provider_billing_command(invoice.provider_organization_id, 'provider.billing.collection.open', p_idempotency_key, hashed, actor);
  if cached is not null then return cached; end if;
  insert into public.provider_collection_cases(provider_organization_id, invoice_id, reason, opened_by)
  values (invoice.provider_organization_id, invoice.id, btrim(p_reason), actor)
  returning id into opened;
  insert into public.provider_collection_case_decisions(case_id, provider_organization_id, decision_version, status, reason, decided_by)
  values (opened, invoice.provider_organization_id, 1, 'OPEN', btrim(p_reason), actor);
  select existing.id into plan
  from public.provider_payment_plans existing
  where existing.invoice_id = invoice.id and private.provider_payment_plan_status(existing.id) = 'APPROVED'
  limit 1;
  if plan is not null then
    select coalesce(max(decision_version), 0) + 1 into next_version from public.provider_payment_plan_decisions where plan_id = plan;
    insert into public.provider_payment_plan_decisions(plan_id, provider_organization_id, decision_version, status, reason, decided_by)
    values (plan, invoice.provider_organization_id, next_version, 'DEFAULTED', btrim(p_reason), actor);
  end if;
  cached := jsonb_build_object('outcome', 'PROVIDER_COLLECTION_OPENED', 'collection_case_id', opened, 'invoice_id', invoice.id);
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (invoice.provider_organization_id, actor, 'USER', 'provider.collection.opened', 'provider_collection_case', opened::text, p_correlation_id, cached, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (invoice.provider_organization_id, 'provider_collection_case', opened::text, 'ProviderCollectionOpenedV1', p_correlation_id, cached, p_idempotency_key);
  perform private.finish_provider_billing_command(invoice.provider_organization_id, 'provider.billing.collection.open', p_idempotency_key, cached);
  return cached;
end$$;

create or replace function public.advance_provider_collection_case(
  p_case_id uuid,
  p_status text,
  p_reason text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare
  actor uuid := auth.uid();
  opened public.provider_collection_cases%rowtype;
  hashed text;
  cached jsonb;
  current_status text;
  next_version integer;
begin
  select * into opened from public.provider_collection_cases where id = p_case_id;
  if actor is null or not found or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'], actor) then
    raise exception 'PROVIDER_COLLECTION_DENIED' using errcode = '42501';
  end if;
  if p_status not in ('FORMAL_NOTICE','COLLECTION','CLOSED') or length(btrim(p_reason)) < 10 then
    raise exception 'INVALID_COLLECTION_ADVANCE' using errcode = '22023';
  end if;
  current_status := private.provider_collection_case_status(opened.id);
  if current_status = 'CLOSED' or (current_status = 'OPEN' and p_status not in ('FORMAL_NOTICE','CLOSED'))
     or (current_status = 'FORMAL_NOTICE' and p_status not in ('COLLECTION','CLOSED'))
     or (current_status = 'COLLECTION' and p_status <> 'CLOSED') then
    raise exception 'COLLECTION_TRANSITION_DENIED' using errcode = '55000';
  end if;
  hashed := private.canonical_request_hash(jsonb_build_object('case', opened.id, 'from', current_status, 'to', p_status, 'reason', btrim(p_reason)));
  cached := private.begin_provider_billing_command(opened.provider_organization_id, 'provider.billing.collection.advance', p_idempotency_key, hashed, actor);
  if cached is not null then return cached; end if;
  select coalesce(max(decision_version), 0) + 1 into next_version from public.provider_collection_case_decisions where case_id = opened.id;
  insert into public.provider_collection_case_decisions(case_id, provider_organization_id, decision_version, status, reason, decided_by)
  values (opened.id, opened.provider_organization_id, next_version, p_status, btrim(p_reason), actor);
  cached := jsonb_build_object('outcome', 'PROVIDER_COLLECTION_ADVANCED', 'collection_case_id', opened.id, 'status', p_status, 'prior_status', current_status);
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (opened.provider_organization_id, actor, 'USER', 'provider.collection.advanced', 'provider_collection_case', opened.id::text, p_correlation_id, cached, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (opened.provider_organization_id, 'provider_collection_case', opened.id::text, 'ProviderCollectionAdvancedV1', p_correlation_id, cached, p_idempotency_key);
  perform private.finish_provider_billing_command(opened.provider_organization_id, 'provider.billing.collection.advance', p_idempotency_key, cached);
  return cached;
end$$;

create or replace function public.list_admin_provider_closure_dashboard(p_limit integer default 100)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  lim integer := greatest(1, least(coalesce(p_limit, 100), 200));
begin
  if actor is null or not private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'FINANCE_MANAGER', 'READ_ONLY_AUDITOR'], actor) then
    raise exception 'ADMIN_CLOSURE_DENIED' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'generated_at', clock_timestamp(),
    'capabilities', jsonb_build_object(
      'can_issue_statement', private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'FINANCE_MANAGER'], actor)
    ),
    'unstatemented', coalesce((
      select jsonb_agg(jsonb_build_object(
        'provider_organization_id', x.provider_organization_id,
        'organization_name', o.display_name,
        'currency', x.currency,
        'event_count', x.event_count,
        'subtotal_minor', x.subtotal_minor::text,
        'tax_minor', x.tax_minor::text,
        'total_minor', (x.subtotal_minor + x.tax_minor)::text
      ) order by o.display_name)
      from (
        select e.provider_organization_id, e.currency, count(*)::integer as event_count,
               coalesce(sum(e.commission_amount_minor), 0)::bigint as subtotal_minor,
               coalesce(sum(e.tax_amount_minor), 0)::bigint as tax_minor
        from public.provider_payable_events e
        where not exists (select 1 from public.provider_statement_lines l where l.payable_event_id = e.id)
        group by e.provider_organization_id, e.currency
        having coalesce(sum(e.commission_amount_minor), 0) + coalesce(sum(e.tax_amount_minor), 0) > 0
        limit lim
      ) x
      join public.organizations o on o.id = x.provider_organization_id
    ), '[]'::jsonb),
    'statements', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'provider_organization_id', s.provider_organization_id, 'organization_name', o.display_name,
        'statement_number', s.statement_number, 'period_start', s.period_start, 'period_end', s.period_end,
        'currency', s.currency, 'total_minor', s.total_minor::text, 'invoiced', exists(select 1 from public.provider_invoices i where i.statement_id = s.id)
      ) order by s.issued_at desc)
      from (
        select * from public.provider_statements order by issued_at desc limit lim
      ) s
      join public.organizations o on o.id = s.provider_organization_id
    ), '[]'::jsonb),
    'overdue_invoices', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', b.id, 'provider_organization_id', b.provider_organization_id, 'organization_name', o.display_name,
        'invoice_number', b.invoice_number, 'due_on', b.due_on, 'currency', b.currency,
        'outstanding_minor', b.outstanding_minor::text,
        'blocks_new_opportunities', true
      ) order by b.due_on)
      from public.provider_invoice_balances b
      join public.organizations o on o.id = b.provider_organization_id
      where b.payment_status = 'OVERDUE'
      limit lim
    ), '[]'::jsonb)
  );
end
$$;

create or replace function public.sweep_admin_exceptions()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  actor uuid := auth.uid();
  rec record;
  opened integer := 0;
  skipped integer := 0;
  due timestamptz := clock_timestamp() + interval '4 hours';
  key text;
  existing uuid;
begin
  if actor is null or not private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'COMPLIANCE_MANAGER', 'SUPPORT_AGENT'], actor) then
    raise exception 'ADMIN_SWEEP_DENIED' using errcode = '42501';
  end if;

  for rec in
    select 'FINANCE'::text as source_kind, 'BILLING_EXCEPTION'::text as resource_type, b.id::text as resource_id,
           b.provider_organization_id as organization_id, 'HIGH'::text as priority,
           'Facture prestataire échue'::text as title_fr, 'فاتورة مقدم خدمة متأخرة'::text as title_ar,
           jsonb_build_object('kind', 'OVERDUE_INVOICE', 'due_on', b.due_on) as context
    from public.provider_invoice_balances b
    where b.payment_status = 'OVERDUE'
    union all
    select 'FINANCE', 'UNSTATMENTED_PAYABLE', e.id::text, e.provider_organization_id, 'MEDIUM',
           'Événement payable non relevé', 'حدث مستحق غير مدرج في كشف',
           jsonb_build_object('kind', 'UNSTATMENTED_PAYABLE', 'occurred_on', e.occurred_on)
    from public.provider_payable_events e
    where not exists (select 1 from public.provider_statement_lines l where l.payable_event_id = e.id)
    union all
    select 'EXCEPTION', 'MATCHING_RUN', m.id::text, r.client_organization_id,
           case when m.status = 'FAILED' then 'HIGH' else 'MEDIUM' end,
           'Matching sans candidat ou en échec', 'مطابقة دون مرشح أو فاشلة',
           jsonb_build_object('kind', 'MATCHING_EXCEPTION', 'status', m.status)
    from public.matching_runs m
    join public.service_requests r on r.id = m.request_id
    where m.status in ('FAILED', 'NO_CANDIDATE')
    union all
    select 'POOL', 'INVENTORY_POOL', p.id::text, p.owner_organization_id, 'MEDIUM',
           'Pool volume en stock faible', 'مجمع حجم بمخزون منخفض',
           jsonb_build_object('kind', 'LOW_STOCK', 'status', p.status)
    from public.service_inventory_pools p
    where p.status = 'LOW_STOCK'
    union all
    select 'FINANCE', 'SUBSCRIPTION', s.id::text, s.organization_id, 'HIGH',
           'Abonnement échu', 'اشتراك متأخر',
           jsonb_build_object('kind', 'PAST_DUE_SUBSCRIPTION', 'status', s.status)
    from public.subscriptions s
    where s.status = 'PAST_DUE'
  loop
    select w.id into existing
    from public.admin_work_items w
    join public.admin_queue_versions q on q.id = w.queue_version_id
    where q.queue_key = 'EXCEPTIONS' and q.status = 'ACTIVE'
      and w.source_kind = rec.source_kind
      and w.resource_type = rec.resource_type
      and w.resource_id = rec.resource_id;
    if existing is not null then
      skipped := skipped + 1;
      continue;
    end if;
    key := left('sweep:' || rec.resource_type || ':' || rec.resource_id, 200);
    begin
      perform public.open_admin_work_item(
        'EXCEPTIONS', rec.organization_id, rec.source_kind, rec.resource_type, rec.resource_id,
        rec.title_fr, rec.title_ar, rec.priority, due, rec.context, rec.title_fr, key, extensions.gen_random_uuid()
      );
      opened := opened + 1;
    exception
      when unique_violation then
        skipped := skipped + 1;
    end;
  end loop;

  return jsonb_build_object('outcome', 'ADMIN_EXCEPTIONS_SWEPT', 'opened', opened, 'skipped', skipped);
end
$$;

revoke all on function public.issue_provider_credit_note(uuid, text, date, bigint, bigint, text, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.request_provider_payment_plan(uuid, jsonb, text, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.decide_provider_payment_plan(uuid, text, text, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.open_provider_collection_case(uuid, text, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.advance_provider_collection_case(uuid, text, text, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.reconcile_provider_payment(uuid, jsonb, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.list_admin_provider_closure_dashboard(integer) from public, anon, authenticated, service_role;
revoke all on function public.sweep_admin_exceptions() from public, anon, authenticated, service_role;

grant execute on function public.issue_provider_credit_note(uuid, text, date, bigint, bigint, text, text, uuid) to authenticated;
grant execute on function public.request_provider_payment_plan(uuid, jsonb, text, text, uuid) to authenticated;
grant execute on function public.decide_provider_payment_plan(uuid, text, text, text, uuid) to authenticated;
grant execute on function public.open_provider_collection_case(uuid, text, text, uuid) to authenticated;
grant execute on function public.advance_provider_collection_case(uuid, text, text, text, uuid) to authenticated;
grant execute on function public.reconcile_provider_payment(uuid, jsonb, text, uuid) to authenticated;
grant execute on function public.list_admin_provider_closure_dashboard(integer) to authenticated;
grant execute on function public.sweep_admin_exceptions() to authenticated;

notify pgrst, 'reload schema';
