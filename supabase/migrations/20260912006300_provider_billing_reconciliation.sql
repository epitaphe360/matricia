-- Provider billing: immutable payable events, statements, invoices, payments and reconciliation.
-- All money is stored in minor units; fiscal and commission inputs are versioned snapshots.

create table public.provider_payable_events (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  client_organization_id uuid not null references public.organizations(id) on delete restrict,
  mission_id uuid not null references public.missions(id) on delete restrict,
  contract_version_id uuid not null references public.contract_versions(id) on delete restrict,
  event_type text not null check (event_type in ('CLIENT_RECEIPT_CONFIRMED','COMMISSION_ACCRUAL','PENALTY_ACCRUAL','ADJUSTMENT')),
  occurred_on date not null,
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  gross_amount_minor bigint not null check (gross_amount_minor > 0),
  commission_basis_points integer not null check (commission_basis_points between 0 and 10000),
  commission_amount_minor bigint not null check (commission_amount_minor >= 0 and commission_amount_minor <= gross_amount_minor),
  tax_rule_version_id uuid not null references public.tax_rule_versions(id) on delete restrict,
  tax_rate_basis_points integer not null check (tax_rate_basis_points between 0 and 10000),
  tax_amount_minor bigint not null check (tax_amount_minor >= 0),
  total_due_minor bigint generated always as (commission_amount_minor + tax_amount_minor) stored,
  commission_rule_snapshot jsonb not null check (jsonb_typeof(commission_rule_snapshot) = 'object'),
  client_receipt_reference text not null check (length(btrim(client_receipt_reference)) between 3 and 200),
  proof_hash text not null check (proof_hash ~ '^[0-9a-f]{64}$'),
  correlation_id uuid not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (provider_organization_id, client_receipt_reference),
  unique (provider_organization_id, id),
  check (provider_organization_id <> client_organization_id)
);

create table public.provider_statements (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  statement_number text not null check (length(btrim(statement_number)) between 3 and 80),
  period_start date not null,
  period_end date not null,
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  subtotal_minor bigint not null check (subtotal_minor >= 0),
  tax_minor bigint not null check (tax_minor >= 0),
  total_minor bigint not null check (total_minor = subtotal_minor + tax_minor and total_minor > 0),
  status text not null default 'ISSUED' check (status = 'ISSUED'),
  document_hash text not null check (document_hash ~ '^[0-9a-f]{64}$'),
  issued_at timestamptz not null default clock_timestamp(),
  correlation_id uuid not null,
  created_by uuid not null references auth.users(id),
  unique (provider_organization_id, statement_number),
  unique (provider_organization_id, id),
  check (period_end >= period_start)
);

create table public.provider_statement_lines (
  id bigint generated always as identity primary key,
  provider_organization_id uuid not null,
  statement_id uuid not null,
  payable_event_id uuid not null,
  subtotal_minor bigint not null check (subtotal_minor >= 0),
  tax_minor bigint not null check (tax_minor >= 0),
  total_minor bigint not null check (total_minor = subtotal_minor + tax_minor and total_minor > 0),
  created_at timestamptz not null default clock_timestamp(),
  foreign key (provider_organization_id, statement_id) references public.provider_statements(provider_organization_id, id) on delete restrict,
  foreign key (provider_organization_id, payable_event_id) references public.provider_payable_events(provider_organization_id, id) on delete restrict,
  unique (payable_event_id)
);

create table public.provider_invoices (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  statement_id uuid not null unique,
  invoice_number text not null check (length(btrim(invoice_number)) between 3 and 80),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  subtotal_minor bigint not null check (subtotal_minor >= 0),
  tax_minor bigint not null check (tax_minor >= 0),
  total_minor bigint not null check (total_minor = subtotal_minor + tax_minor and total_minor > 0),
  issued_on date not null,
  due_on date not null,
  tax_rule_snapshot jsonb not null check (jsonb_typeof(tax_rule_snapshot) = 'array'),
  document_hash text not null check (document_hash ~ '^[0-9a-f]{64}$'),
  journal_id uuid not null,
  correlation_id uuid not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (provider_organization_id, invoice_number),
  unique (provider_organization_id, id),
  foreign key (provider_organization_id, statement_id) references public.provider_statements(provider_organization_id, id) on delete restrict,
  foreign key (provider_organization_id, journal_id) references public.financial_journals(organization_id, id) on delete restrict,
  check (due_on >= issued_on)
);

create table public.provider_payments (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  payment_reference text not null check (length(btrim(payment_reference)) between 3 and 200),
  paid_on date not null,
  payment_method text not null check (payment_method in ('BANK_TRANSFER','CARD','CHECK','CASH','OTHER')),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  amount_minor bigint not null check (amount_minor > 0),
  proof_hash text not null check (proof_hash ~ '^[0-9a-f]{64}$'),
  journal_id uuid not null,
  correlation_id uuid not null,
  recorded_by uuid not null references auth.users(id),
  recorded_at timestamptz not null default clock_timestamp(),
  unique (provider_organization_id, payment_reference),
  unique (provider_organization_id, id),
  foreign key (provider_organization_id, journal_id) references public.financial_journals(organization_id, id) on delete restrict
);

create table public.provider_reconciliation_batches (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  payment_id uuid not null,
  allocated_minor bigint not null check (allocated_minor > 0),
  correlation_id uuid not null,
  reconciled_by uuid not null references auth.users(id),
  reconciled_at timestamptz not null default clock_timestamp(),
  foreign key (provider_organization_id, payment_id) references public.provider_payments(provider_organization_id, id) on delete restrict,
  unique (provider_organization_id, id)
);

create table public.provider_payment_allocations (
  id bigint generated always as identity primary key,
  provider_organization_id uuid not null,
  reconciliation_batch_id uuid not null,
  payment_id uuid not null,
  invoice_id uuid not null,
  amount_minor bigint not null check (amount_minor > 0),
  created_at timestamptz not null default clock_timestamp(),
  foreign key (provider_organization_id, reconciliation_batch_id) references public.provider_reconciliation_batches(provider_organization_id, id) on delete restrict,
  foreign key (provider_organization_id, payment_id) references public.provider_payments(provider_organization_id, id) on delete restrict,
  foreign key (provider_organization_id, invoice_id) references public.provider_invoices(provider_organization_id, id) on delete restrict,
  unique (payment_id, invoice_id)
);

create or replace function private.provider_billing_access(p_provider_organization_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path = pg_catalog, private as $$
  select private.has_org_role(p_provider_organization_id,array['PROVIDER_OWNER','PROVIDER_ACCOUNTING'],p_user_id)
    or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','READ_ONLY_AUDITOR'],p_user_id)
$$;

create or replace function private.begin_provider_billing_command(p_organization_id uuid,p_scope text,p_key text,p_hash text,p_actor uuid)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare v public.idempotency_keys%rowtype; n integer;
begin
  if length(p_key) not between 8 and 200 or p_hash !~ '^[0-9a-f]{64}$' then raise exception 'INVALID_IDEMPOTENCY' using errcode='22023'; end if;
  insert into public.idempotency_keys(organization_id,operation_scope,key,request_hash,created_by,expires_at)
  values(p_organization_id,p_scope,p_key,p_hash,p_actor,now()+interval '30 days') on conflict do nothing;
  get diagnostics n=row_count;
  if n=1 then return null; end if;
  select * into v from public.idempotency_keys where organization_id=p_organization_id and operation_scope=p_scope and key=p_key for update;
  if v.request_hash<>p_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if;
  if v.status='COMPLETED' then return v.response_body; end if;
  raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000';
end$$;

create or replace function private.finish_provider_billing_command(p_organization_id uuid,p_scope text,p_key text,p_response jsonb)
returns void language sql security definer set search_path=pg_catalog,public as $$
  update public.idempotency_keys set status='COMPLETED',response_code=201,response_body=p_response,completed_at=clock_timestamp()
  where organization_id=p_organization_id and operation_scope=p_scope and key=p_key and status='PROCESSING'
$$;

create or replace function public.record_provider_payable_event(
  p_mission_id uuid,p_event_type text,p_occurred_on date,p_currency char(3),p_gross_amount_minor bigint,
  p_client_receipt_reference text,p_proof_hash text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid(); m public.missions%rowtype; cv public.contract_versions%rowtype; tr public.tax_rule_versions%rowtype;
  bps integer; commission bigint; tax bigint; h text; r jsonb; e uuid;
begin
  select * into m from public.missions where id=p_mission_id;
  if a is null or not found or not (private.has_org_role(m.provider_organization_id,array['PROVIDER_OWNER','PROVIDER_ACCOUNTING'],a) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a)) then raise exception 'PROVIDER_PAYABLE_DENIED' using errcode='42501'; end if;
  if p_event_type not in('CLIENT_RECEIPT_CONFIRMED','COMMISSION_ACCRUAL','PENALTY_ACCRUAL','ADJUSTMENT') or p_gross_amount_minor<=0 or p_currency!~'^[A-Z]{3}$' or p_proof_hash!~'^[0-9a-f]{64}$' then raise exception 'INVALID_PAYABLE_EVENT' using errcode='22023'; end if;
  select * into cv from public.contract_versions where id=m.contract_version_id;
  bps:=coalesce((cv.commission_rule_snapshot->>'commission_basis_points')::integer,(cv.commission_rule_snapshot->>'basis_points')::integer);
  if bps is null or bps not between 0 and 10000 then raise exception 'INVALID_COMMISSION_RULE_SNAPSHOT' using errcode='23514'; end if;
  select * into tr from public.tax_rule_versions where jurisdiction_code='MA' and status='ACTIVE' and effective_from<=p_occurred_on and (effective_to is null or effective_to>=p_occurred_on) order by effective_from desc,version desc limit 1;
  if not found then raise exception 'ACTIVE_MOROCCO_TAX_RULE_REQUIRED' using errcode='23514'; end if;
  commission:=floor((p_gross_amount_minor::numeric*bps+5000)/10000)::bigint;
  tax:=floor((commission::numeric*tr.rate_basis_points+5000)/10000)::bigint;
  h:=private.canonical_request_hash(jsonb_build_object('mission',m.id,'type',p_event_type,'date',p_occurred_on,'currency',p_currency,'gross',p_gross_amount_minor,'receipt',p_client_receipt_reference,'proof_hash',p_proof_hash));
  r:=private.begin_provider_billing_command(m.provider_organization_id,'provider.billing.payable.record',p_idempotency_key,h,a); if r is not null then return r; end if;
  insert into public.provider_payable_events(provider_organization_id,client_organization_id,mission_id,contract_version_id,event_type,occurred_on,currency,gross_amount_minor,commission_basis_points,commission_amount_minor,tax_rule_version_id,tax_rate_basis_points,tax_amount_minor,commission_rule_snapshot,client_receipt_reference,proof_hash,correlation_id,created_by)
  values(m.provider_organization_id,m.client_organization_id,m.id,m.contract_version_id,p_event_type,p_occurred_on,p_currency,p_gross_amount_minor,bps,commission,tr.id,tr.rate_basis_points,tax,cv.commission_rule_snapshot,p_client_receipt_reference,p_proof_hash,p_correlation_id,a) returning id into e;
  r:=jsonb_build_object('outcome','PROVIDER_PAYABLE_RECORDED','payable_event_id',e,'commission_minor',commission,'tax_minor',tax,'total_due_minor',commission+tax);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(m.provider_organization_id,a,'USER','provider.payable.recorded','provider_payable_event',e::text,p_correlation_id,jsonb_build_object('mission_id',m.id,'tax_rule_version_id',tr.id),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(m.provider_organization_id,'provider_payable_event',e::text,'ProviderPayableRecordedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(m.provider_organization_id,'provider.billing.payable.record',p_idempotency_key,r); return r;
end$$;

create or replace function public.issue_provider_statement(p_provider_organization_id uuid,p_statement_number text,p_period_start date,p_period_end date,p_currency char(3),p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid(); h text;r jsonb;s uuid;sub bigint;tax bigint;
begin
  if a is null or not(private.has_org_role(p_provider_organization_id,array['PROVIDER_OWNER','PROVIDER_ACCOUNTING'],a)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a))then raise exception'PROVIDER_STATEMENT_DENIED'using errcode='42501';end if;
  if p_period_end<p_period_start or p_currency!~'^[A-Z]{3}$'then raise exception'INVALID_STATEMENT_PERIOD'using errcode='22023';end if;
  h:=private.canonical_request_hash(jsonb_build_object('provider',p_provider_organization_id,'number',p_statement_number,'start',p_period_start,'end',p_period_end,'currency',p_currency));
  r:=private.begin_provider_billing_command(p_provider_organization_id,'provider.billing.statement.issue',p_idempotency_key,h,a);if r is not null then return r;end if;
  perform pg_advisory_xact_lock(hashtextextended(p_provider_organization_id::text||':'||p_currency::text||':provider-statement',0));
  select coalesce(sum(e.commission_amount_minor),0),coalesce(sum(e.tax_amount_minor),0)into sub,tax from public.provider_payable_events e where e.provider_organization_id=p_provider_organization_id and e.currency=p_currency and e.occurred_on between p_period_start and p_period_end and not exists(select 1 from public.provider_statement_lines l where l.payable_event_id=e.id);
  if sub+tax<=0 then raise exception'NO_UNSTATEMENTED_PAYABLES'using errcode='P0002';end if;
  insert into public.provider_statements(provider_organization_id,statement_number,period_start,period_end,currency,subtotal_minor,tax_minor,total_minor,document_hash,correlation_id,created_by)values(p_provider_organization_id,p_statement_number,p_period_start,p_period_end,p_currency,sub,tax,sub+tax,h,p_correlation_id,a)returning id into s;
  insert into public.provider_statement_lines(provider_organization_id,statement_id,payable_event_id,subtotal_minor,tax_minor,total_minor)select p_provider_organization_id,s,e.id,e.commission_amount_minor,e.tax_amount_minor,e.total_due_minor from public.provider_payable_events e where e.provider_organization_id=p_provider_organization_id and e.currency=p_currency and e.occurred_on between p_period_start and p_period_end and not exists(select 1 from public.provider_statement_lines l where l.payable_event_id=e.id);
  r:=jsonb_build_object('outcome','PROVIDER_STATEMENT_ISSUED','statement_id',s,'subtotal_minor',sub,'tax_minor',tax,'total_minor',sub+tax);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_provider_organization_id,a,'USER','provider.statement.issued','provider_statement',s::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_provider_organization_id,'provider_statement',s::text,'ProviderStatementIssuedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(p_provider_organization_id,'provider.billing.statement.issue',p_idempotency_key,r);return r;
end$$;

create or replace function public.issue_provider_invoice(p_statement_id uuid,p_invoice_number text,p_issued_on date,p_due_on date,p_receivable_account_id uuid,p_revenue_account_id uuid,p_tax_liability_account_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();s public.provider_statements%rowtype;h text;r jsonb;i uuid;j uuid:=extensions.gen_random_uuid();tax_snapshot jsonb;
begin
  select * into s from public.provider_statements where id=p_statement_id;
  if a is null or not found or not(private.has_org_role(s.provider_organization_id,array['PROVIDER_OWNER','PROVIDER_ACCOUNTING'],a)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a))then raise exception'PROVIDER_INVOICE_DENIED'using errcode='42501';end if;
  if p_due_on<p_issued_on then raise exception'INVALID_INVOICE_DUE_DATE'using errcode='22023';end if;
  if not exists(select 1 from public.financial_accounts where id=p_receivable_account_id and organization_id=s.provider_organization_id and currency=s.currency)or not exists(select 1 from public.financial_accounts where id=p_revenue_account_id and organization_id=s.provider_organization_id and currency=s.currency)or(s.tax_minor>0 and not exists(select 1 from public.financial_accounts where id=p_tax_liability_account_id and organization_id=s.provider_organization_id and currency=s.currency))then raise exception'INVALID_PROVIDER_LEDGER_ACCOUNT'using errcode='23514';end if;
  select coalesce(jsonb_agg(distinct jsonb_build_object('tax_rule_version_id',e.tax_rule_version_id,'rate_basis_points',e.tax_rate_basis_points)),'[]')into tax_snapshot from public.provider_statement_lines l join public.provider_payable_events e on e.id=l.payable_event_id where l.statement_id=s.id;
  h:=private.canonical_request_hash(jsonb_build_object('statement',s.id,'number',p_invoice_number,'issued',p_issued_on,'due',p_due_on,'receivable_account',p_receivable_account_id,'revenue_account',p_revenue_account_id,'tax_account',p_tax_liability_account_id));
  r:=private.begin_provider_billing_command(s.provider_organization_id,'provider.billing.invoice.issue',p_idempotency_key,h,a);if r is not null then return r;end if;
  insert into public.financial_journals(id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,correlation_id,effective_at,description,created_by)values(j,s.provider_organization_id,'PROVIDER_COMMISSION_INVOICE',s.currency,'provider.billing.invoice.issue',p_idempotency_key,p_correlation_id,p_issued_on::timestamptz,'Provider commission invoice '||p_invoice_number,a);
  insert into public.financial_entries(organization_id,journal_id,account_id,direction,amount_minor,currency)values(s.provider_organization_id,j,p_receivable_account_id,'DEBIT',s.total_minor,s.currency),(s.provider_organization_id,j,p_revenue_account_id,'CREDIT',s.subtotal_minor,s.currency);
  if s.tax_minor>0 then insert into public.financial_entries(organization_id,journal_id,account_id,direction,amount_minor,currency)values(s.provider_organization_id,j,p_tax_liability_account_id,'CREDIT',s.tax_minor,s.currency);end if;
  insert into public.provider_invoices(provider_organization_id,statement_id,invoice_number,currency,subtotal_minor,tax_minor,total_minor,issued_on,due_on,tax_rule_snapshot,document_hash,journal_id,correlation_id,created_by)values(s.provider_organization_id,s.id,p_invoice_number,s.currency,s.subtotal_minor,s.tax_minor,s.total_minor,p_issued_on,p_due_on,tax_snapshot,h,j,p_correlation_id,a)returning id into i;
  r:=jsonb_build_object('outcome','PROVIDER_INVOICE_ISSUED','invoice_id',i,'statement_id',s.id,'journal_id',j,'total_minor',s.total_minor);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(s.provider_organization_id,a,'USER','provider.invoice.issued','provider_invoice',i::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(s.provider_organization_id,'provider_invoice',i::text,'ProviderInvoiceIssuedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(s.provider_organization_id,'provider.billing.invoice.issue',p_idempotency_key,r);return r;
end$$;

create or replace function public.record_provider_payment(p_provider_organization_id uuid,p_payment_reference text,p_paid_on date,p_payment_method text,p_currency char(3),p_amount_minor bigint,p_proof_hash text,p_cash_account_id uuid,p_receivable_account_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();h text;r jsonb;p uuid;j uuid:=extensions.gen_random_uuid();
begin
  if a is null or not(private.has_org_role(p_provider_organization_id,array['PROVIDER_OWNER','PROVIDER_ACCOUNTING'],a)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a))then raise exception'PROVIDER_PAYMENT_DENIED'using errcode='42501';end if;
  if p_amount_minor<=0 or p_currency!~'^[A-Z]{3}$'or p_payment_method not in('BANK_TRANSFER','CARD','CHECK','CASH','OTHER')or p_proof_hash!~'^[0-9a-f]{64}$'then raise exception'INVALID_PROVIDER_PAYMENT'using errcode='22023';end if;
  if not exists(select 1 from public.financial_accounts where id=p_cash_account_id and organization_id=p_provider_organization_id and currency=p_currency)or not exists(select 1 from public.financial_accounts where id=p_receivable_account_id and organization_id=p_provider_organization_id and currency=p_currency)then raise exception'INVALID_PROVIDER_LEDGER_ACCOUNT'using errcode='23514';end if;
  h:=private.canonical_request_hash(jsonb_build_object('provider',p_provider_organization_id,'reference',p_payment_reference,'paid_on',p_paid_on,'method',p_payment_method,'currency',p_currency,'amount',p_amount_minor,'proof_hash',p_proof_hash,'cash_account',p_cash_account_id,'receivable_account',p_receivable_account_id));
  r:=private.begin_provider_billing_command(p_provider_organization_id,'provider.billing.payment.record',p_idempotency_key,h,a);if r is not null then return r;end if;
  insert into public.financial_journals(id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,correlation_id,effective_at,description,created_by)values(j,p_provider_organization_id,'PROVIDER_PAYMENT',p_currency,'provider.billing.payment.record',p_idempotency_key,p_correlation_id,p_paid_on::timestamptz,'Provider payment '||p_payment_reference,a);
  insert into public.financial_entries(organization_id,journal_id,account_id,direction,amount_minor,currency)values(p_provider_organization_id,j,p_cash_account_id,'DEBIT',p_amount_minor,p_currency),(p_provider_organization_id,j,p_receivable_account_id,'CREDIT',p_amount_minor,p_currency);
  insert into public.provider_payments(provider_organization_id,payment_reference,paid_on,payment_method,currency,amount_minor,proof_hash,journal_id,correlation_id,recorded_by)values(p_provider_organization_id,p_payment_reference,p_paid_on,p_payment_method,p_currency,p_amount_minor,p_proof_hash,j,p_correlation_id,a)returning id into p;
  r:=jsonb_build_object('outcome','PROVIDER_PAYMENT_RECORDED','payment_id',p,'journal_id',j,'amount_minor',p_amount_minor);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_provider_organization_id,a,'USER','provider.payment.recorded','provider_payment',p::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_provider_organization_id,'provider_payment',p::text,'ProviderPaymentRecordedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(p_provider_organization_id,'provider.billing.payment.record',p_idempotency_key,r);return r;
end$$;

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
    select i.total_minor-coalesce(sum(pa.amount_minor),0)into outstanding from public.provider_invoices i left join public.provider_payment_allocations pa on pa.invoice_id=i.id where i.id=(x->>'invoice_id')::uuid and i.provider_organization_id=p.provider_organization_id and i.currency=p.currency group by i.total_minor;
    if outstanding is null or (x->>'amount_minor')::bigint>outstanding then raise exception'INVOICE_OVERALLOCATED_OR_NOT_FOUND'using errcode='23514';end if;
  end loop;
  h:=private.canonical_request_hash(jsonb_build_object('payment',p.id,'allocations',p_allocations));r:=private.begin_provider_billing_command(p.provider_organization_id,'provider.billing.payment.reconcile',p_idempotency_key,h,a);if r is not null then return r;end if;
  insert into public.provider_reconciliation_batches(provider_organization_id,payment_id,allocated_minor,correlation_id,reconciled_by)values(p.provider_organization_id,p.id,requested,p_correlation_id,a)returning id into b;
  insert into public.provider_payment_allocations(provider_organization_id,reconciliation_batch_id,payment_id,invoice_id,amount_minor)select p.provider_organization_id,b,p.id,(e->>'invoice_id')::uuid,(e->>'amount_minor')::bigint from jsonb_array_elements(p_allocations)e;
  r:=jsonb_build_object('outcome','PROVIDER_PAYMENT_RECONCILED','payment_id',p.id,'reconciliation_batch_id',b,'allocated_minor',requested,'unallocated_minor',p.amount_minor-already-requested);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p.provider_organization_id,a,'USER','provider.payment.reconciled','provider_reconciliation_batch',b::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p.provider_organization_id,'provider_payment',p.id::text,'ProviderPaymentReconciledV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(p.provider_organization_id,'provider.billing.payment.reconcile',p_idempotency_key,r);return r;
end$$;

create view public.provider_invoice_balances with(security_invoker=true) as
select i.*,coalesce(sum(a.amount_minor),0)::bigint as paid_minor,(i.total_minor-coalesce(sum(a.amount_minor),0))::bigint as outstanding_minor,
case when coalesce(sum(a.amount_minor),0)>=i.total_minor then'PAID'when coalesce(sum(a.amount_minor),0)>0 then'PARTIALLY_PAID'when i.due_on<current_date then'OVERDUE'else'ISSUED'end as payment_status
from public.provider_invoices i left join public.provider_payment_allocations a on a.invoice_id=i.id group by i.id;

do $$declare t text;begin foreach t in array array['provider_payable_events','provider_statements','provider_statement_lines','provider_invoices','provider_payments','provider_reconciliation_batches','provider_payment_allocations']loop execute format('create trigger %I_immutable before update or delete on public.%I for each row execute function private.prevent_update_delete()',t,t);execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from anon, authenticated',t);execute format('grant select on public.%I to authenticated',t);execute format('create policy %I_tenant_read on public.%I for select to authenticated using (private.provider_billing_access(provider_organization_id))',t,t);end loop;end$$;
revoke all on public.provider_invoice_balances from anon,authenticated;grant select on public.provider_invoice_balances to authenticated;

revoke all on function private.provider_billing_access(uuid,uuid),private.begin_provider_billing_command(uuid,text,text,text,uuid),private.finish_provider_billing_command(uuid,text,text,jsonb) from public,anon,authenticated,service_role;
grant execute on function private.provider_billing_access(uuid,uuid) to authenticated;
revoke all on function public.record_provider_payable_event(uuid,text,date,char,bigint,text,text,text,uuid),public.issue_provider_statement(uuid,text,date,date,char,text,uuid),public.issue_provider_invoice(uuid,text,date,date,uuid,uuid,uuid,text,uuid),public.record_provider_payment(uuid,text,date,text,char,bigint,text,uuid,uuid,text,uuid),public.reconcile_provider_payment(uuid,jsonb,text,uuid) from public,anon,service_role;
grant execute on function public.record_provider_payable_event(uuid,text,date,char,bigint,text,text,text,uuid),public.issue_provider_statement(uuid,text,date,date,char,text,uuid),public.issue_provider_invoice(uuid,text,date,date,uuid,uuid,uuid,text,uuid),public.record_provider_payment(uuid,text,date,text,char,bigint,text,uuid,uuid,text,uuid),public.reconcile_provider_payment(uuid,jsonb,text,uuid) to authenticated;

create index provider_payables_unstatemented_idx on public.provider_payable_events(provider_organization_id,currency,occurred_on,id);
create index provider_statement_lines_statement_idx on public.provider_statement_lines(provider_organization_id,statement_id,id);
create index provider_invoices_due_idx on public.provider_invoices(provider_organization_id,due_on,id);
create index provider_payments_date_idx on public.provider_payments(provider_organization_id,paid_on,id);
create index provider_allocations_invoice_idx on public.provider_payment_allocations(provider_organization_id,invoice_id,id);
