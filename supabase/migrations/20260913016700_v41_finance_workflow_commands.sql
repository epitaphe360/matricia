-- V4.1 additive command surface for Matricia Procurement/AP and separated cash flows.
-- No transaction wrapper: the migration runner owns transactionality.

create table public.outbound_payment_schedules (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  outbound_payment_id uuid not null,
  accounts_payable_id uuid not null,
  scheduled_amount_minor bigint not null check (scheduled_amount_minor > 0),
  scheduled_by uuid not null references auth.users(id) on delete restrict,
  scheduled_at timestamptz not null default clock_timestamp(),
  unique (outbound_payment_id),
  unique (id, organization_id),
  foreign key (outbound_payment_id, organization_id) references public.outbound_payments(id, organization_id) on delete restrict,
  foreign key (accounts_payable_id, organization_id) references public.accounts_payable(id, organization_id) on delete restrict
);

create table public.outbound_payment_state_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  outbound_payment_id uuid not null,
  event_type text not null check (event_type in ('PAID','FAILED','CANCELLED','RECONCILED')),
  provider_reference text,
  evidence_hash text check (evidence_hash is null or evidence_hash ~ '^[0-9a-f]{64}$'),
  journal_id uuid,
  idempotency_key text not null,
  correlation_id uuid not null,
  occurred_at timestamptz not null,
  recorded_by uuid not null references auth.users(id) on delete restrict,
  recorded_at timestamptz not null default clock_timestamp(),
  unique (organization_id, idempotency_key),
  unique (id, organization_id),
  foreign key (outbound_payment_id, organization_id) references public.outbound_payments(id, organization_id) on delete restrict,
  foreign key (journal_id, organization_id) references public.financial_journals(id, organization_id) on delete restrict,
  check ((event_type = 'PAID' and provider_reference is not null and evidence_hash is not null and journal_id is not null)
      or (event_type = 'RECONCILED')
      or (event_type in ('FAILED','CANCELLED') and journal_id is null))
);

alter table public.payment_disputes add constraint payment_disputes_id_org_v41_uq unique (id, organization_id);

alter table public.purchase_order_lines add constraint purchase_order_lines_id_org_v41_uq unique (id, organization_id);
alter table public.supplier_invoice_lines
  add column purchase_order_line_id uuid,
  add column quantity_milli bigint check (quantity_milli is null or quantity_milli > 0),
  add constraint supplier_invoice_lines_po_line_v41_fk foreign key (purchase_order_line_id, organization_id)
    references public.purchase_order_lines(id, organization_id) on delete restrict,
  add constraint supplier_invoice_lines_match_fields_v41_ck check (
    (purchase_order_line_id is null and quantity_milli is null)
    or (purchase_order_line_id is not null and quantity_milli is not null)
  );

create table public.goods_service_receipt_lines (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  goods_service_receipt_id uuid not null,
  purchase_order_line_id uuid not null,
  quantity_milli bigint not null check (quantity_milli > 0),
  created_at timestamptz not null default clock_timestamp(),
  unique (goods_service_receipt_id, purchase_order_line_id),
  foreign key (goods_service_receipt_id, organization_id) references public.goods_service_receipts(id, organization_id) on delete restrict,
  foreign key (purchase_order_line_id, organization_id) references public.purchase_order_lines(id, organization_id) on delete restrict
);

create table public.payment_dispute_state_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  payment_dispute_id uuid not null,
  provider_event_id uuid not null,
  state text not null check (state in ('OPEN','WON','LOST','CHARGEBACK')),
  occurred_at timestamptz not null,
  correlation_id uuid not null,
  unique (provider_event_id),
  foreign key (payment_dispute_id, organization_id) references public.payment_disputes(id, organization_id) on delete restrict,
  foreign key (provider_event_id, organization_id) references public.payment_provider_events(id, organization_id) on delete restrict
);

create view public.outbound_payment_status_v41 with (security_invoker=true) as
select p.*,
  coalesce((select e.event_type from public.outbound_payment_state_events e where e.outbound_payment_id=p.id order by e.occurred_at desc,e.recorded_at desc limit 1),p.status) as current_status,
  coalesce((select sum(a.amount_minor) from public.outbound_payment_allocations a where a.outbound_payment_id=p.id),0)::bigint as reconciled_minor
from public.outbound_payments p;

create or replace function public.create_vendor(
  p_organization_id uuid,p_legal_name text,p_registration_identifier text,p_category text,p_risk_level text,
  p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();h text;r jsonb;x uuid;
begin
  if a is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a) then raise exception'VENDOR_CREATE_DENIED'using errcode='42501';end if;
  if length(btrim(coalesce(p_legal_name,''))) not between 2 and 200 or length(btrim(coalesce(p_category,''))) not between 2 and 80 or p_risk_level not in('LOW','STANDARD','HIGH') then raise exception'INVALID_VENDOR'using errcode='22023';end if;
  h:=private.canonical_request_hash(jsonb_build_object('organization',p_organization_id,'legal_name',p_legal_name,'registration',p_registration_identifier,'category',p_category,'risk',p_risk_level));
  r:=private.begin_provider_billing_command(p_organization_id,'v41.vendor.create',p_idempotency_key,h,a);if r is not null then return r;end if;
  insert into public.vendors(organization_id,legal_name,registration_identifier,category,risk_level,created_by)values(p_organization_id,btrim(p_legal_name),nullif(btrim(p_registration_identifier),''),btrim(p_category),p_risk_level,a)returning id into x;
  r:=jsonb_build_object('outcome','VENDOR_CREATED','vendor_id',x);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,a,'USER','vendor.created','vendor',x::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_organization_id,'vendor',x::text,'VendorCreatedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(p_organization_id,'v41.vendor.create',p_idempotency_key,r);return r;
end$$;

create or replace function public.reconcile_paid_outbound_payment(
  p_outbound_payment_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();p public.outbound_payments%rowtype;s public.outbound_payment_schedules%rowtype;ap public.accounts_payable%rowtype;h text;r jsonb;e uuid;allocated bigint;outstanding bigint;
begin
  select*into p from public.outbound_payments where id=p_outbound_payment_id for update;select*into s from public.outbound_payment_schedules where outbound_payment_id=p.id;
  if a is null or not found or not private.has_platform_role(array['SUPER_ADMIN','FINANCE_MANAGER'],a)or coalesce(auth.jwt()->>'aal','')<>'aal2'then raise exception'OUTBOUND_RECONCILIATION_DENIED'using errcode='42501';end if;
  if not exists(select 1 from public.outbound_payment_state_events where outbound_payment_id=p.id and event_type='PAID')then raise exception'PAID_PAYMENT_REQUIRED'using errcode='55000';end if;
  select*into ap from public.accounts_payable where id=s.accounts_payable_id and organization_id=p.organization_id and currency=p.currency for update;
  if not found then raise exception'PAYABLE_OVERALLOCATED_OR_NOT_FOUND'using errcode='23514';end if;
  select coalesce(sum(amount_minor),0)into allocated from public.outbound_payment_allocations where accounts_payable_id=ap.id;outstanding:=ap.amount_due_minor-allocated;
  if p.amount_minor>outstanding then raise exception'PAYABLE_OVERALLOCATED_OR_NOT_FOUND'using errcode='23514';end if;
  h:=private.canonical_request_hash(jsonb_build_object('payment',p.id,'payable',s.accounts_payable_id,'amount',p.amount_minor));r:=private.begin_provider_billing_command(p.organization_id,'v41.outbound.reconcile_paid',p_idempotency_key,h,a);if r is not null then return r;end if;
  insert into public.outbound_payment_allocations(organization_id,outbound_payment_id,accounts_payable_id,amount_minor)values(p.organization_id,p.id,s.accounts_payable_id,p.amount_minor);
  insert into public.outbound_payment_state_events(organization_id,outbound_payment_id,event_type,idempotency_key,correlation_id,occurred_at,recorded_by)values(p.organization_id,p.id,'RECONCILED',p_idempotency_key,p_correlation_id,clock_timestamp(),a)returning id into e;
  r:=jsonb_build_object('outcome','OUTBOUND_PAYMENT_RECONCILED','outbound_payment_id',p.id,'state_event_id',e,'accounts_payable_id',s.accounts_payable_id,'allocated_minor',p.amount_minor);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p.organization_id,a,'USER','outbound_payment.reconciled','outbound_payment',p.id::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p.organization_id,'outbound_payment',p.id::text,'OutboundPaymentReconciledV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(p.organization_id,'v41.outbound.reconcile_paid',p_idempotency_key,r);return r;
end$$;

create or replace function public.register_supplier_invoice_payable(
  p_purchase_order_id uuid,p_invoice_reference text,p_invoice_date date,p_due_date date,p_currency char(3),
  p_tax_rule_version_id uuid,p_original_document_hash text,p_lines jsonb,p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();o public.purchase_orders%rowtype;pol public.purchase_order_lines%rowtype;h text;r jsonb;i uuid;ap uuid;sub bigint;tax bigint;total bigint;already_subtotal bigint;received_qty bigint;invoiced_qty bigint;e jsonb;fiscal text;state text;
begin
  select*into o from public.purchase_orders where id=p_purchase_order_id for update;
  if a is null or not found or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a)then raise exception'SUPPLIER_INVOICE_REGISTER_DENIED'using errcode='42501';end if;
  if o.status not in('PARTIALLY_RECEIVED','RECEIVED','CLOSED')or p_due_date<p_invoice_date or p_currency<>o.currency or p_original_document_hash!~'^[0-9a-f]{64}$'or jsonb_typeof(p_lines)<>'array'or jsonb_array_length(p_lines)=0 then raise exception'INVALID_SUPPLIER_INVOICE'using errcode='22023';end if;
  if exists(select 1 from jsonb_array_elements(p_lines)e where coalesce((e->>'quantity_milli')::bigint,0)<=0 or coalesce((e->>'subtotal_minor')::bigint,-1)<0 or coalesce((e->>'tax_minor')::bigint,-1)<0 or length(btrim(coalesce(e->>'description','')))<2)or exists(select 1 from jsonb_array_elements(p_lines)e group by e->>'purchase_order_line_id'having count(*)>1)then raise exception'INVALID_SUPPLIER_INVOICE_LINE'using errcode='22023';end if;
  for e in select*from jsonb_array_elements(p_lines)loop
    select*into pol from public.purchase_order_lines where id=(e->>'purchase_order_line_id')::uuid and purchase_order_id=o.id and organization_id=o.organization_id;
    if not found or(pol.unit_price_minor*(e->>'quantity_milli')::bigint)%1000<>0 or(e->>'subtotal_minor')::bigint<>(pol.unit_price_minor*(e->>'quantity_milli')::bigint)/1000 then raise exception'INVOICE_LINE_PRICE_DOES_NOT_MATCH_PO'using errcode='23514';end if;
    select coalesce(sum(quantity_milli),0)into received_qty from public.goods_service_receipt_lines where purchase_order_line_id=pol.id;select coalesce(sum(quantity_milli),0)into invoiced_qty from public.supplier_invoice_lines where purchase_order_line_id=pol.id;
    if invoiced_qty+(e->>'quantity_milli')::bigint>received_qty then raise exception'INVOICE_QUANTITY_EXCEEDS_RECEIPT'using errcode='23514';end if;
  end loop;
  select sum((e->>'subtotal_minor')::bigint),sum((e->>'tax_minor')::bigint)into sub,tax from jsonb_array_elements(p_lines)e;total:=sub+tax;if total<=0 then raise exception'INVALID_SUPPLIER_INVOICE_TOTAL'using errcode='22023';end if;
  select coalesce(sum(subtotal_minor),0)into already_subtotal from public.supplier_invoices where purchase_order_id=o.id;
  if already_subtotal+sub>o.total_minor then raise exception'SUPPLIER_INVOICE_EXCEEDS_PURCHASE_ORDER'using errcode='23514';end if;
  if p_tax_rule_version_id is not null and not exists(select 1 from public.tax_rule_versions where id=p_tax_rule_version_id and jurisdiction_code='MA'and status='ACTIVE'and effective_from<=p_invoice_date and(effective_to is null or effective_to>=p_invoice_date))then raise exception'ACTIVE_MOROCCO_TAX_RULE_REQUIRED'using errcode='23514';end if;
  fiscal:=case when p_tax_rule_version_id is null then'ACCOUNTANT_REVIEW_REQUIRED'else'VALIDATED'end;state:=case when p_tax_rule_version_id is null then'REGISTERED'else'VALIDATED'end;
  h:=private.canonical_request_hash(jsonb_build_object('order',o.id,'reference',p_invoice_reference,'invoice_date',p_invoice_date,'due_date',p_due_date,'currency',p_currency,'tax_rule',p_tax_rule_version_id,'document_hash',p_original_document_hash,'lines',p_lines));r:=private.begin_provider_billing_command(o.organization_id,'v41.supplier_invoice.register',p_idempotency_key,h,a);if r is not null then return r;end if;
  insert into public.supplier_invoices(organization_id,vendor_id,purchase_order_id,invoice_reference,invoice_date,due_date,currency,subtotal_minor,tax_minor,total_minor,fiscal_status,tax_rule_version_id,original_document_hash,status,created_by)values(o.organization_id,o.vendor_id,o.id,btrim(p_invoice_reference),p_invoice_date,p_due_date,p_currency,sub,tax,total,fiscal,p_tax_rule_version_id,p_original_document_hash,state,a)returning id into i;
  insert into public.supplier_invoice_lines(organization_id,supplier_invoice_id,line_no,description,subtotal_minor,tax_minor,total_minor,tax_rule_version_id,expense_category_id,purchase_order_line_id,quantity_milli)select o.organization_id,i,row_number()over()::integer,btrim(e->>'description'),(e->>'subtotal_minor')::bigint,(e->>'tax_minor')::bigint,(e->>'subtotal_minor')::bigint+(e->>'tax_minor')::bigint,p_tax_rule_version_id,nullif(e->>'expense_category_id','')::uuid,(e->>'purchase_order_line_id')::uuid,(e->>'quantity_milli')::bigint from jsonb_array_elements(p_lines)e;
  if fiscal='VALIDATED'then insert into public.accounts_payable(organization_id,supplier_invoice_id,currency,amount_due_minor,due_on,status,created_by)values(o.organization_id,i,p_currency,total,p_due_date,'OPEN',a)returning id into ap;end if;
  r:=jsonb_build_object('outcome',case when fiscal='VALIDATED'then'SUPPLIER_INVOICE_PAYABLE_REGISTERED'else'ACCOUNTANT_REVIEW_REQUIRED'end,'supplier_invoice_id',i,'accounts_payable_id',ap,'total_minor',total,'currency',p_currency,'fiscal_status',fiscal);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(o.organization_id,a,'USER','supplier.invoice.registered','supplier_invoice',i::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(o.organization_id,'supplier_invoice',i::text,'SupplierInvoiceRegisteredV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(o.organization_id,'v41.supplier_invoice.register',p_idempotency_key,r);return r;
end$$;

-- P0 workflow continuation.

create or replace function public.record_provider_commission_receipt(
  p_provider_invoice_id uuid,p_payment_reference text,p_paid_on date,p_payment_method text,
  p_commission_amount_minor bigint,p_tax_amount_minor bigint,p_proof_hash text,p_confirmation_verified boolean,
  p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,auth,extensions as $$
declare i public.provider_invoices%rowtype;org public.organizations%rowtype;h text;r jsonb;p uuid;receipt uuid;batch uuid;j uuid:=extensions.gen_random_uuid();cash_id uuid;receivable_id uuid;prior_commission bigint;prior_tax bigint;total bigint;
begin
  if coalesce(auth.role(),'')<>'service_role'or p_confirmation_verified is distinct from true then raise exception'PROVIDER_COMMISSION_RECEIPT_DENIED'using errcode='42501';end if;
  select*into i from public.provider_invoices where id=p_provider_invoice_id for update;if not found then raise exception'PROVIDER_INVOICE_NOT_FOUND'using errcode='P0002';end if;select*into org from public.organizations where id=i.provider_organization_id;
  total:=p_commission_amount_minor+p_tax_amount_minor;select coalesce(sum(commission_amount_minor),0),coalesce(sum(tax_amount_minor),0)into prior_commission,prior_tax from public.provider_commission_receipts where provider_invoice_id=i.id;
  if p_commission_amount_minor<0 or p_tax_amount_minor<0 or total<=0 or prior_commission+p_commission_amount_minor>i.subtotal_minor or prior_tax+p_tax_amount_minor>i.tax_minor or p_payment_method not in('BANK_TRANSFER','CARD','CHECK','CASH','OTHER')or p_proof_hash!~'^[0-9a-f]{64}$'or length(btrim(coalesce(p_payment_reference,'')))not between 3 and 200 then raise exception'INVALID_PROVIDER_COMMISSION_RECEIPT'using errcode='22023';end if;
  h:=private.canonical_request_hash(jsonb_build_object('invoice',i.id,'reference',p_payment_reference,'paid_on',p_paid_on,'method',p_payment_method,'commission',p_commission_amount_minor,'tax',p_tax_amount_minor,'proof',p_proof_hash,'confirmed',p_confirmation_verified));r:=private.begin_provider_billing_command(i.provider_organization_id,'v41.provider.commission_receipt',p_idempotency_key,h,org.created_by);if r is not null then return r;end if;
  insert into public.financial_accounts(organization_id,code,name,account_type,currency)values(i.provider_organization_id,'MATRICIA_COMMISSION_CASH_'||btrim(i.currency::text),'Verified Matricia commission cash','ASSET',i.currency),(i.provider_organization_id,'MATRICIA_COMMISSION_RECEIVABLE_'||btrim(i.currency::text),'Matricia commission receivable','ASSET',i.currency)on conflict(organization_id,code)do nothing;
  select id into cash_id from public.financial_accounts where organization_id=i.provider_organization_id and code='MATRICIA_COMMISSION_CASH_'||btrim(i.currency::text);select id into receivable_id from public.financial_accounts where organization_id=i.provider_organization_id and code='MATRICIA_COMMISSION_RECEIVABLE_'||btrim(i.currency::text);
  insert into public.financial_journals(id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,correlation_id,effective_at,description,created_by)values(j,i.provider_organization_id,'PROVIDER_COMMISSION_RECEIPT',i.currency,'v41.provider.commission_receipt',p_idempotency_key,p_correlation_id,p_paid_on::timestamptz,'Verified provider commission receipt',org.created_by);insert into public.financial_entries(organization_id,journal_id,account_id,direction,amount_minor,currency)values(i.provider_organization_id,j,cash_id,'DEBIT',total,i.currency),(i.provider_organization_id,j,receivable_id,'CREDIT',total,i.currency);
  insert into public.provider_payments(provider_organization_id,payment_reference,paid_on,payment_method,currency,amount_minor,proof_hash,journal_id,correlation_id,recorded_by)values(i.provider_organization_id,btrim(p_payment_reference),p_paid_on,p_payment_method,i.currency,total,p_proof_hash,j,p_correlation_id,org.created_by)returning id into p;
  insert into public.provider_reconciliation_batches(provider_organization_id,payment_id,allocated_minor,correlation_id,reconciled_by)values(i.provider_organization_id,p,total,p_correlation_id,org.created_by)returning id into batch;
  insert into public.provider_payment_allocations(provider_organization_id,reconciliation_batch_id,payment_id,invoice_id,amount_minor)values(i.provider_organization_id,batch,p,i.id,total);
  insert into public.provider_commission_receipts(provider_organization_id,provider_payment_id,provider_invoice_id,commission_amount_minor,tax_amount_minor,currency,matricia_receipt_reference,correlation_id)values(i.provider_organization_id,p,i.id,p_commission_amount_minor,p_tax_amount_minor,i.currency,btrim(p_payment_reference),p_correlation_id)returning id into receipt;
  r:=jsonb_build_object('outcome','PROVIDER_COMMISSION_RECEIPT_RECORDED','provider_payment_id',p,'provider_commission_receipt_id',receipt,'provider_invoice_id',i.id,'reconciliation_batch_id',batch,'journal_id',j,'total_minor',total);
  insert into public.audit_events(organization_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(i.provider_organization_id,'SERVICE','provider.commission.receipt.recorded','provider_commission_receipt',receipt::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(i.provider_organization_id,'provider_commission_receipt',receipt::text,'ProviderCommissionReceiptRecordedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(i.provider_organization_id,'v41.provider.commission_receipt',p_idempotency_key,r);return r;
end$$;

create or replace function public.ingest_verified_own_payment_event(
  p_organization_id uuid,p_revenue_type text,p_source_reference text,p_provider text,p_provider_event_id text,
  p_event_type text,p_provider_payment_id text,p_amount_minor bigint,p_currency char(3),p_occurred_at timestamptz,
  p_payload_hash text,p_signature_fingerprint text,p_reason text,p_provider_dispute_id text,p_evidence_hash text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,auth,extensions as $$
declare pe public.payment_provider_events%rowtype;ownp public.matricia_own_revenue_payments%rowtype;org public.organizations%rowtype;d public.payment_disputes%rowtype;event_id uuid;d_id uuid;j uuid;cash_id uuid;counter_id uuid;refunded bigint;charged_back bigint;last_state text;r jsonb;
begin
  if coalesce(auth.role(),'')<>'service_role'then raise exception'PAYMENT_EVENT_PROCESS_DENIED'using errcode='42501';end if;
  if p_event_type not in('PAYMENT_SUCCEEDED','PAYMENT_FAILED','REFUND_SUCCEEDED','REFUND_FAILED','DISPUTE_OPENED','DISPUTE_WON','DISPUTE_LOST','CHARGEBACK')or p_amount_minor<0 or p_currency!~'^[A-Z]{3}$'or p_payload_hash!~'^[0-9a-f]{64}$'or p_signature_fingerprint!~'^[0-9a-f]{64}$'or length(btrim(coalesce(p_provider_event_id,'')))not between 3 and 200 or length(btrim(coalesce(p_provider_payment_id,'')))not between 3 and 200 or p_occurred_at>clock_timestamp()+interval'5 minutes'then raise exception'INVALID_VERIFIED_PAYMENT_EVENT'using errcode='22023';end if;
  select*into org from public.organizations where id=p_organization_id and status='ACTIVE';if not found then raise exception'ORGANIZATION_NOT_ACTIVE'using errcode='23514';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_provider||':'||p_provider_event_id,0));
  select*into pe from public.payment_provider_events where provider=p_provider and provider_event_id=p_provider_event_id;
  if found then
    if pe.organization_id<>p_organization_id or pe.provider_payment_id<>p_provider_payment_id or pe.event_type<>p_event_type or pe.amount_minor<>p_amount_minor or pe.currency<>p_currency or pe.payload_hash<>p_payload_hash or pe.signature_fingerprint<>p_signature_fingerprint then raise exception'PAYMENT_EVENT_REPLAY_MISMATCH'using errcode='22000';end if;
    return jsonb_build_object('outcome','OWN_PAYMENT_EVENT_ALREADY_PROCESSED','payment_provider_event_id',pe.id,'replayed',true);
  end if;
  insert into public.payment_provider_events(organization_id,provider,provider_event_id,event_type,provider_payment_id,amount_minor,currency,payload_hash,signature_fingerprint,occurred_at,correlation_id)values(p_organization_id,p_provider,p_provider_event_id,p_event_type,p_provider_payment_id,p_amount_minor,p_currency,p_payload_hash,p_signature_fingerprint,p_occurred_at,p_correlation_id)returning id into event_id;

  if p_event_type='PAYMENT_SUCCEEDED'then
    if p_amount_minor<=0 or p_revenue_type not in('SUBSCRIPTION','CREDITS','BOX','BENEFIT','MATRICIA_PRODUCT','MATRICIA_SERVICE')or length(btrim(coalesce(p_source_reference,'')))not between 3 and 200 then raise exception'INVALID_OWN_REVENUE_PAYMENT'using errcode='22023';end if;
    insert into public.financial_accounts(organization_id,code,name,account_type,currency)values(p_organization_id,'MATRICIA_CASH_'||btrim(p_currency::text),'Matricia own cash '||btrim(p_currency::text),'ASSET',p_currency),(p_organization_id,'MATRICIA_OWN_REVENUE_'||p_revenue_type||'_'||btrim(p_currency::text),'Matricia own revenue '||p_revenue_type,'REVENUE',p_currency)on conflict(organization_id,code)do nothing;
    select id into cash_id from public.financial_accounts where organization_id=p_organization_id and code='MATRICIA_CASH_'||btrim(p_currency::text);select id into counter_id from public.financial_accounts where organization_id=p_organization_id and code='MATRICIA_OWN_REVENUE_'||p_revenue_type||'_'||btrim(p_currency::text);
    j:=extensions.gen_random_uuid();insert into public.financial_journals(id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,correlation_id,effective_at,description,created_by)values(j,p_organization_id,'MATRICIA_OWN_REVENUE',p_currency,'v41.own_payment.event',p_provider||':'||p_provider_event_id,p_correlation_id,p_occurred_at,'Verified Matricia own revenue payment',org.created_by);
    insert into public.financial_entries(organization_id,journal_id,account_id,direction,amount_minor,currency)values(p_organization_id,j,cash_id,'DEBIT',p_amount_minor,p_currency),(p_organization_id,j,counter_id,'CREDIT',p_amount_minor,p_currency);
    insert into public.matricia_own_revenue_payments(organization_id,revenue_type,source_reference,amount_minor,currency,provider,provider_payment_id,financial_journal_id,paid_at,correlation_id)values(p_organization_id,p_revenue_type,btrim(p_source_reference),p_amount_minor,p_currency,p_provider,p_provider_payment_id,j,p_occurred_at,p_correlation_id);
    r:=jsonb_build_object('outcome','MATRICIA_OWN_PAYMENT_RECORDED','payment_provider_event_id',event_id,'journal_id',j,'amount_minor',p_amount_minor,'replayed',false);
  elsif p_event_type in('REFUND_SUCCEEDED','REFUND_FAILED')then
    select*into ownp from public.matricia_own_revenue_payments where organization_id=p_organization_id and provider=p_provider and provider_payment_id=p_provider_payment_id;
    if not found or p_amount_minor<=0 then raise exception'OWN_REVENUE_PAYMENT_NOT_FOUND'using errcode='P0002';end if;if p_currency<>ownp.currency then raise exception'OWN_PAYMENT_CURRENCY_MISMATCH'using errcode='23514';end if;
    select coalesce(sum(refund_amount_minor),0)into refunded from public.payment_refunds where own_revenue_payment_id=ownp.id and status='SUCCEEDED';if p_event_type='REFUND_SUCCEEDED'and refunded+p_amount_minor>ownp.amount_minor then raise exception'REFUND_EXCEEDS_PAYMENT'using errcode='23514';end if;
    insert into public.payment_refunds(organization_id,own_revenue_payment_id,provider_event_id,refund_amount_minor,currency,reason,status,idempotency_key)values(p_organization_id,ownp.id,event_id,p_amount_minor,p_currency,coalesce(nullif(btrim(p_reason),''),'PROVIDER_REFUND'),case when p_event_type='REFUND_SUCCEEDED'then'SUCCEEDED'else'FAILED'end,p_provider||':'||p_provider_event_id);
    if p_event_type='REFUND_SUCCEEDED'then
      insert into public.financial_accounts(organization_id,code,name,account_type,currency)values(p_organization_id,'MATRICIA_CASH_'||btrim(p_currency::text),'Matricia own cash '||btrim(p_currency::text),'ASSET',p_currency),(p_organization_id,'MATRICIA_OWN_REFUND_'||btrim(p_currency::text),'Matricia own revenue refunds','EXPENSE',p_currency)on conflict(organization_id,code)do nothing;
      select id into cash_id from public.financial_accounts where organization_id=p_organization_id and code='MATRICIA_CASH_'||btrim(p_currency::text);select id into counter_id from public.financial_accounts where organization_id=p_organization_id and code='MATRICIA_OWN_REFUND_'||btrim(p_currency::text);
      j:=extensions.gen_random_uuid();insert into public.financial_journals(id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,correlation_id,effective_at,description,created_by)values(j,p_organization_id,'MATRICIA_OWN_REFUND',p_currency,'v41.own_payment.event',p_provider||':'||p_provider_event_id,p_correlation_id,p_occurred_at,'Verified Matricia own payment refund',org.created_by);insert into public.financial_entries(organization_id,journal_id,account_id,direction,amount_minor,currency)values(p_organization_id,j,counter_id,'DEBIT',p_amount_minor,p_currency),(p_organization_id,j,cash_id,'CREDIT',p_amount_minor,p_currency);
    end if;
    r:=jsonb_build_object('outcome',p_event_type,'payment_provider_event_id',event_id,'journal_id',j,'amount_minor',p_amount_minor,'replayed',false);
  elsif p_event_type in('DISPUTE_OPENED','DISPUTE_WON','DISPUTE_LOST','CHARGEBACK')then
    select*into ownp from public.matricia_own_revenue_payments where organization_id=p_organization_id and provider=p_provider and provider_payment_id=p_provider_payment_id;if not found or length(btrim(coalesce(p_provider_dispute_id,'')))<3 or p_amount_minor<=0 or p_amount_minor>ownp.amount_minor then raise exception'INVALID_PAYMENT_DISPUTE'using errcode='22023';end if;if p_currency<>ownp.currency then raise exception'OWN_PAYMENT_CURRENCY_MISMATCH'using errcode='23514';end if;
    select*into d from public.payment_disputes where organization_id=p_organization_id and provider_dispute_id=p_provider_dispute_id;
    if not found then insert into public.payment_disputes(organization_id,own_revenue_payment_id,provider_dispute_id,disputed_amount_minor,currency,status,evidence_hash,opened_at,closed_at)values(p_organization_id,ownp.id,p_provider_dispute_id,p_amount_minor,p_currency,case p_event_type when'DISPUTE_OPENED'then'OPEN'when'DISPUTE_WON'then'WON'when'DISPUTE_LOST'then'LOST'else'CHARGEBACK'end,p_evidence_hash,p_occurred_at,case when p_event_type='DISPUTE_OPENED'then null else p_occurred_at end)returning id into d_id;else d_id:=d.id;if d.own_revenue_payment_id<>ownp.id or d.disputed_amount_minor<>p_amount_minor or d.currency<>p_currency then raise exception'PAYMENT_DISPUTE_REPLAY_MISMATCH'using errcode='22000';end if;select state into last_state from public.payment_dispute_state_events where payment_dispute_id=d.id order by occurred_at desc,id desc limit 1;if last_state in('WON','CHARGEBACK')or(last_state='LOST'and p_event_type<>'CHARGEBACK')then raise exception'PAYMENT_DISPUTE_TERMINAL'using errcode='55000';end if;end if;
    if p_event_type='CHARGEBACK'then select coalesce(sum(pe2.amount_minor),0)into charged_back from public.payment_dispute_state_events se join public.payment_disputes pd on pd.id=se.payment_dispute_id join public.payment_provider_events pe2 on pe2.id=se.provider_event_id where pd.own_revenue_payment_id=ownp.id and se.state='CHARGEBACK';if charged_back+p_amount_minor>ownp.amount_minor then raise exception'CHARGEBACK_EXCEEDS_PAYMENT'using errcode='23514';end if;end if;
    insert into public.payment_dispute_state_events(organization_id,payment_dispute_id,provider_event_id,state,occurred_at,correlation_id)values(p_organization_id,d_id,event_id,case p_event_type when'DISPUTE_OPENED'then'OPEN'when'DISPUTE_WON'then'WON'when'DISPUTE_LOST'then'LOST'else'CHARGEBACK'end,p_occurred_at,p_correlation_id);
    if p_event_type='CHARGEBACK'then
      insert into public.financial_accounts(organization_id,code,name,account_type,currency)values(p_organization_id,'MATRICIA_CASH_'||btrim(p_currency::text),'Matricia own cash '||btrim(p_currency::text),'ASSET',p_currency),(p_organization_id,'MATRICIA_OWN_CHARGEBACK_'||btrim(p_currency::text),'Matricia own payment chargebacks','EXPENSE',p_currency)on conflict(organization_id,code)do nothing;select id into cash_id from public.financial_accounts where organization_id=p_organization_id and code='MATRICIA_CASH_'||btrim(p_currency::text);select id into counter_id from public.financial_accounts where organization_id=p_organization_id and code='MATRICIA_OWN_CHARGEBACK_'||btrim(p_currency::text);
      j:=extensions.gen_random_uuid();insert into public.financial_journals(id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,correlation_id,effective_at,description,created_by)values(j,p_organization_id,'MATRICIA_OWN_CHARGEBACK',p_currency,'v41.own_payment.event',p_provider||':'||p_provider_event_id,p_correlation_id,p_occurred_at,'Verified Matricia own payment chargeback',org.created_by);insert into public.financial_entries(organization_id,journal_id,account_id,direction,amount_minor,currency)values(p_organization_id,j,counter_id,'DEBIT',p_amount_minor,p_currency),(p_organization_id,j,cash_id,'CREDIT',p_amount_minor,p_currency);
    end if;
    r:=jsonb_build_object('outcome',p_event_type,'payment_provider_event_id',event_id,'payment_dispute_id',d_id,'journal_id',j,'replayed',false);
  else r:=jsonb_build_object('outcome',p_event_type,'payment_provider_event_id',event_id,'replayed',false);
  end if;
  insert into public.audit_events(organization_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,'SERVICE','own_payment.event.processed','payment_provider_event',event_id::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_organization_id,'payment_provider_event',event_id::text,'OwnPaymentProviderEventProcessedV1',p_correlation_id,r,p_provider||':'||p_provider_event_id);
  return r;
end$$;

create or replace function public.schedule_outbound_payment(
  p_accounts_payable_id uuid,p_bank_account_version_id uuid,p_payment_reference text,p_amount_minor bigint,
  p_scheduled_on date,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();ap public.accounts_payable%rowtype;si public.supplier_invoices%rowtype;v public.vendor_bank_account_versions%rowtype;h text;r jsonb;p uuid;s uuid;planned bigint;paid bigint;
begin
  select*into ap from public.accounts_payable where id=p_accounts_payable_id for update;
  if a is null or not found or not private.has_platform_role(array['SUPER_ADMIN','FINANCE_MANAGER'],a)or coalesce(auth.jwt()->>'aal','')<>'aal2'then raise exception'OUTBOUND_PAYMENT_SCHEDULE_DENIED'using errcode='42501';end if;
  select*into si from public.supplier_invoices where id=ap.supplier_invoice_id;select*into v from public.vendor_bank_account_versions where id=p_bank_account_version_id and organization_id=ap.organization_id;
  if not found or v.status<>'ACTIVE'then raise exception'BANK_ACCOUNT_NOT_ACTIVE'using errcode='23514';end if;if clock_timestamp()<v.cooling_until then raise exception'BANK_ACCOUNT_COOLING_PERIOD_ACTIVE'using errcode='55000';end if;
  if not exists(select 1 from public.vendor_bank_accounts b where b.id=v.bank_account_id and b.vendor_id=si.vendor_id and b.organization_id=ap.organization_id)then raise exception'PAYMENT_BENEFICIARY_VENDOR_MISMATCH'using errcode='23514';end if;
  if exists(select 1 from public.purchase_orders o join public.purchase_requests q on q.id=o.purchase_request_id left join public.purchase_approvals pa on pa.purchase_request_id=q.id where o.id=si.purchase_order_id and(q.requested_by=a or pa.decided_by=a))then raise exception'REQUESTER_OR_APPROVER_CANNOT_SCHEDULE_PAYMENT'using errcode='42501';end if;
  select coalesce(sum(scheduled_amount_minor),0)into planned from public.outbound_payment_schedules where accounts_payable_id=ap.id;select coalesce(sum(amount_minor),0)into paid from public.outbound_payment_allocations where accounts_payable_id=ap.id;
  if p_amount_minor<=0 or p_amount_minor+greatest(planned,paid)>ap.amount_due_minor or length(btrim(coalesce(p_payment_reference,'')))not between 3 and 200 then raise exception'PAYMENT_OVERALLOCATED'using errcode='23514';end if;
  h:=private.canonical_request_hash(jsonb_build_object('payable',ap.id,'bank_version',v.id,'reference',p_payment_reference,'amount',p_amount_minor,'scheduled_on',p_scheduled_on));r:=private.begin_provider_billing_command(ap.organization_id,'v41.outbound.schedule',p_idempotency_key,h,a);if r is not null then return r;end if;
  insert into public.outbound_payments(organization_id,vendor_id,bank_account_version_id,payment_reference,amount_minor,currency,status,correlation_id,created_by)values(ap.organization_id,si.vendor_id,v.id,btrim(p_payment_reference),p_amount_minor,ap.currency,'SCHEDULED',p_correlation_id,a)returning id into p;
  insert into public.outbound_payment_schedules(organization_id,outbound_payment_id,accounts_payable_id,scheduled_amount_minor,scheduled_by,scheduled_at)values(ap.organization_id,p,ap.id,p_amount_minor,a,p_scheduled_on::timestamptz)returning id into s;
  r:=jsonb_build_object('outcome','OUTBOUND_PAYMENT_SCHEDULED','outbound_payment_id',p,'schedule_id',s,'amount_minor',p_amount_minor,'currency',ap.currency);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(ap.organization_id,a,'USER','outbound_payment.scheduled','outbound_payment',p::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(ap.organization_id,'outbound_payment',p::text,'OutboundPaymentScheduledV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(ap.organization_id,'v41.outbound.schedule',p_idempotency_key,r);return r;
end$$;

create or replace function public.mark_outbound_payment_paid(
  p_outbound_payment_id uuid,p_provider_reference text,p_paid_at timestamptz,p_evidence_hash text,
  p_payable_account_id uuid,p_cash_account_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();p public.outbound_payments%rowtype;s public.outbound_payment_schedules%rowtype;h text;r jsonb;j uuid:=extensions.gen_random_uuid();e uuid;
begin
  select*into p from public.outbound_payments where id=p_outbound_payment_id for update;select*into s from public.outbound_payment_schedules where outbound_payment_id=p.id;
  if a is null or not found or not private.has_platform_role(array['SUPER_ADMIN','FINANCE_MANAGER'],a)or coalesce(auth.jwt()->>'aal','')<>'aal2'then raise exception'OUTBOUND_PAYMENT_EXECUTION_DENIED'using errcode='42501';end if;
  if s.scheduled_by=a then raise exception'SCHEDULER_CANNOT_PAY'using errcode='42501';end if;if exists(select 1 from public.outbound_payment_state_events where outbound_payment_id=p.id and event_type in('PAID','RECONCILED'))then raise exception'OUTBOUND_PAYMENT_ALREADY_PAID'using errcode='55000';end if;
  if p_evidence_hash!~'^[0-9a-f]{64}$'or length(btrim(coalesce(p_provider_reference,'')))not between 3 and 200 then raise exception'INVALID_OUTBOUND_PAYMENT_EVIDENCE'using errcode='22023';end if;
  if not exists(select 1 from public.vendor_bank_account_versions where id=p.bank_account_version_id and organization_id=p.organization_id and status='ACTIVE'and cooling_until<=p_paid_at)then raise exception'BANK_ACCOUNT_NOT_ACTIVE_OR_COOLING'using errcode='23514';end if;
  if not exists(select 1 from public.financial_accounts where id=p_payable_account_id and organization_id=p.organization_id and currency=p.currency and account_type='LIABILITY')or not exists(select 1 from public.financial_accounts where id=p_cash_account_id and organization_id=p.organization_id and currency=p.currency and account_type='ASSET')then raise exception'INVALID_SUPPLIER_PAYMENT_LEDGER_ACCOUNTS'using errcode='23514';end if;
  h:=private.canonical_request_hash(jsonb_build_object('payment',p.id,'provider_reference',p_provider_reference,'paid_at',p_paid_at,'evidence',p_evidence_hash,'payable_account',p_payable_account_id,'cash_account',p_cash_account_id));r:=private.begin_provider_billing_command(p.organization_id,'v41.outbound.paid',p_idempotency_key,h,a);if r is not null then return r;end if;
  insert into public.financial_journals(id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,correlation_id,effective_at,description,created_by)values(j,p.organization_id,'SUPPLIER_PAYMENT',p.currency,'v41.outbound.paid',p_idempotency_key,p_correlation_id,p_paid_at,'Supplier payment '||p.payment_reference,a);
  insert into public.financial_entries(organization_id,journal_id,account_id,direction,amount_minor,currency)values(p.organization_id,j,p_payable_account_id,'DEBIT',p.amount_minor,p.currency),(p.organization_id,j,p_cash_account_id,'CREDIT',p.amount_minor,p.currency);
  insert into public.outbound_payment_state_events(organization_id,outbound_payment_id,event_type,provider_reference,evidence_hash,journal_id,idempotency_key,correlation_id,occurred_at,recorded_by)values(p.organization_id,p.id,'PAID',btrim(p_provider_reference),p_evidence_hash,j,p_idempotency_key,p_correlation_id,p_paid_at,a)returning id into e;
  r:=jsonb_build_object('outcome','OUTBOUND_PAYMENT_PAID','outbound_payment_id',p.id,'state_event_id',e,'journal_id',j,'amount_minor',p.amount_minor);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p.organization_id,a,'USER','outbound_payment.paid','outbound_payment',p.id::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p.organization_id,'outbound_payment',p.id::text,'OutboundPaymentPaidV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(p.organization_id,'v41.outbound.paid',p_idempotency_key,r);return r;
end$$;

create or replace function public.issue_purchase_order(
  p_purchase_request_id uuid,p_order_number text,p_contract_hash text,p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();q public.purchase_requests%rowtype;h text;r jsonb;x uuid;
begin
  select*into q from public.purchase_requests where id=p_purchase_request_id for update;
  if a is null or not found or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a)then raise exception'PURCHASE_ORDER_ISSUE_DENIED'using errcode='42501';end if;
  if q.status<>'APPROVED'or q.vendor_id is null then raise exception'APPROVED_REQUEST_WITH_VENDOR_REQUIRED'using errcode='55000';end if;
  if q.requested_by=a then raise exception'REQUESTER_CANNOT_APPROVE_OR_ISSUE'using errcode='42501';end if;
  if not exists(select 1 from public.purchase_approvals where purchase_request_id=q.id and decision='APPROVED'and decided_by<>q.requested_by)then raise exception'FOUR_EYES_APPROVAL_REQUIRED'using errcode='23514';end if;
  if length(btrim(coalesce(p_order_number,'')))not between 3 and 80 or(p_contract_hash is not null and p_contract_hash!~'^[0-9a-f]{64}$')then raise exception'INVALID_PURCHASE_ORDER'using errcode='22023';end if;
  h:=private.canonical_request_hash(jsonb_build_object('request',q.id,'number',p_order_number,'contract_hash',p_contract_hash));r:=private.begin_provider_billing_command(q.organization_id,'v41.purchase.order.issue',p_idempotency_key,h,a);if r is not null then return r;end if;
  insert into public.purchase_orders(organization_id,purchase_request_id,vendor_id,order_number,currency,total_minor,contract_hash,issued_by)values(q.organization_id,q.id,q.vendor_id,btrim(p_order_number),q.currency,q.total_minor,p_contract_hash,a)returning id into x;
  insert into public.purchase_order_lines(organization_id,purchase_order_id,line_no,description,quantity_milli,unit_price_minor,line_total_minor)select q.organization_id,x,line_no,description,quantity_milli,unit_price_minor,line_total_minor from public.purchase_request_lines where purchase_request_id=q.id;
  update public.purchase_requests set status='ORDERED'where id=q.id;
  r:=jsonb_build_object('outcome','PURCHASE_ORDER_ISSUED','purchase_order_id',x,'purchase_request_id',q.id,'total_minor',q.total_minor);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(q.organization_id,a,'USER','purchase.order.issued','purchase_order',x::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(q.organization_id,'purchase_order',x::text,'PurchaseOrderIssuedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(q.organization_id,'v41.purchase.order.issue',p_idempotency_key,r);return r;
end$$;

create or replace function public.confirm_goods_service_receipt(
  p_purchase_order_id uuid,p_receipt_number text,p_receipt_type text,p_received_on date,p_evidence_hash text,
  p_lines jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();o public.purchase_orders%rowtype;h text;r jsonb;x uuid;e jsonb;ordered bigint;received bigint;state text;
begin
  select*into o from public.purchase_orders where id=p_purchase_order_id for update;
  if a is null or not found or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a)then raise exception'PURCHASE_RECEIPT_DENIED'using errcode='42501';end if;
  if o.status not in('ISSUED','PARTIALLY_RECEIVED')or p_receipt_type not in('GOODS','SERVICE')or p_evidence_hash!~'^[0-9a-f]{64}$'or length(btrim(coalesce(p_receipt_number,'')))not between 3 and 80 or jsonb_typeof(p_lines)<>'array'or jsonb_array_length(p_lines)=0 then raise exception'INVALID_PURCHASE_RECEIPT'using errcode='22023';end if;
  for e in select*from jsonb_array_elements(p_lines)loop
    select pol.quantity_milli,coalesce(sum(grl.quantity_milli),0)into ordered,received from public.purchase_order_lines pol left join public.goods_service_receipt_lines grl on grl.purchase_order_line_id=pol.id where pol.id=(e->>'purchase_order_line_id')::uuid and pol.purchase_order_id=o.id and pol.organization_id=o.organization_id group by pol.quantity_milli;
    if ordered is null or coalesce((e->>'quantity_milli')::bigint,0)<=0 or received+(e->>'quantity_milli')::bigint>ordered then raise exception'RECEIPT_EXCEEDS_PURCHASE_ORDER_LINE'using errcode='23514';end if;
  end loop;
  h:=private.canonical_request_hash(jsonb_build_object('order',o.id,'number',p_receipt_number,'type',p_receipt_type,'date',p_received_on,'evidence',p_evidence_hash,'lines',p_lines));r:=private.begin_provider_billing_command(o.organization_id,'v41.purchase.receipt.confirm',p_idempotency_key,h,a);if r is not null then return r;end if;
  insert into public.goods_service_receipts(organization_id,purchase_order_id,receipt_number,receipt_type,received_on,evidence_hash,confirmed_by)values(o.organization_id,o.id,btrim(p_receipt_number),p_receipt_type,p_received_on,p_evidence_hash,a)returning id into x;
  insert into public.goods_service_receipt_lines(organization_id,goods_service_receipt_id,purchase_order_line_id,quantity_milli)select o.organization_id,x,(e->>'purchase_order_line_id')::uuid,(e->>'quantity_milli')::bigint from jsonb_array_elements(p_lines)e;
  state:=case when exists(select 1 from public.purchase_order_lines pol where pol.purchase_order_id=o.id and pol.quantity_milli>(select coalesce(sum(grl.quantity_milli),0)from public.goods_service_receipt_lines grl where grl.purchase_order_line_id=pol.id))then'PARTIALLY_RECEIVED'else'RECEIVED'end;
  update public.purchase_orders set status=state where id=o.id;
  r:=jsonb_build_object('outcome','GOODS_SERVICE_RECEIPT_CONFIRMED','receipt_id',x,'purchase_order_id',o.id,'order_status',state);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(o.organization_id,a,'USER','purchase.receipt.confirmed','goods_service_receipt',x::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(o.organization_id,'goods_service_receipt',x::text,'GoodsServiceReceiptConfirmedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(o.organization_id,'v41.purchase.receipt.confirm',p_idempotency_key,r);return r;
end$$;

create or replace function public.submit_purchase_request(
  p_organization_id uuid,p_vendor_id uuid,p_request_number text,p_need_description text,p_currency char(3),
  p_approval_threshold_minor bigint,p_lines jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();h text;r jsonb;x uuid;total bigint;
begin
  if a is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a) then raise exception'PURCHASE_REQUEST_CREATE_DENIED'using errcode='42501';end if;
  if p_currency!~'^[A-Z]{3}$'or p_approval_threshold_minor<0 or jsonb_typeof(p_lines)<>'array'or jsonb_array_length(p_lines)=0 or length(btrim(coalesce(p_request_number,'')))not between 3 and 80 or length(btrim(coalesce(p_need_description,'')))<3 then raise exception'INVALID_PURCHASE_REQUEST'using errcode='22023';end if;
  if p_vendor_id is not null and not exists(select 1 from public.vendors where id=p_vendor_id and organization_id=p_organization_id and status='ACTIVE')then raise exception'VENDOR_NOT_ACTIVE'using errcode='23514';end if;
  if exists(select 1 from jsonb_array_elements(p_lines)e where coalesce((e->>'quantity_milli')::bigint,0)<=0 or coalesce((e->>'unit_price_minor')::bigint,-1)<0 or ((e->>'quantity_milli')::bigint*(e->>'unit_price_minor')::bigint)%1000<>0 or length(btrim(coalesce(e->>'description','')))<2)then raise exception'INVALID_PURCHASE_REQUEST_LINE'using errcode='22023';end if;
  select sum(((e->>'quantity_milli')::bigint*(e->>'unit_price_minor')::bigint)/1000)into total from jsonb_array_elements(p_lines)e;if total<=0 then raise exception'INVALID_PURCHASE_REQUEST_TOTAL'using errcode='22023';end if;
  h:=private.canonical_request_hash(jsonb_build_object('organization',p_organization_id,'vendor',p_vendor_id,'number',p_request_number,'need',p_need_description,'currency',p_currency,'threshold',p_approval_threshold_minor,'lines',p_lines));
  r:=private.begin_provider_billing_command(p_organization_id,'v41.purchase.submit',p_idempotency_key,h,a);if r is not null then return r;end if;
  insert into public.purchase_requests(organization_id,vendor_id,request_number,need_description,status,currency,total_minor,approval_threshold_minor,requested_by)values(p_organization_id,p_vendor_id,btrim(p_request_number),btrim(p_need_description),'PURCHASE_REQUEST',p_currency,total,p_approval_threshold_minor,a)returning id into x;
  insert into public.purchase_request_lines(organization_id,purchase_request_id,line_no,description,quantity_milli,unit_price_minor,line_total_minor,expense_category_id)
  select p_organization_id,x,row_number()over()::integer,btrim(e->>'description'),(e->>'quantity_milli')::bigint,(e->>'unit_price_minor')::bigint,((e->>'quantity_milli')::bigint*(e->>'unit_price_minor')::bigint)/1000,nullif(e->>'expense_category_id','')::uuid from jsonb_array_elements(p_lines)e;
  r:=jsonb_build_object('outcome','PURCHASE_REQUEST_SUBMITTED','purchase_request_id',x,'total_minor',total,'currency',p_currency);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,a,'USER','purchase.request.submitted','purchase_request',x::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_organization_id,'purchase_request',x::text,'PurchaseRequestSubmittedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(p_organization_id,'v41.purchase.submit',p_idempotency_key,r);return r;
end$$;

create or replace function public.record_direct_client_provider_payment(p_client_organization_id uuid,p_provider_organization_id uuid,p_mission_id uuid,p_contract_version_id uuid,p_contractual_amount_minor bigint,p_declared_paid_minor bigint,p_currency char(3),p_paid_at timestamptz,p_payment_method text,p_provider_reference text,p_proof_hash text,p_confirmation_status text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();h text;r jsonb;x uuid;
begin
 if a is null or not(private.has_org_role(p_client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a)or private.has_org_role(p_provider_organization_id,array['PROVIDER_OWNER','PROVIDER_ACCOUNTING'],a)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a))then raise exception'DIRECT_PAYMENT_RECORD_DENIED'using errcode='42501';end if;
 if p_mission_id is null or p_contract_version_id is null or not exists(select 1 from public.missions m join public.contract_versions cv on cv.id=m.contract_version_id and cv.contract_id=m.contract_id join public.contracts c on c.id=m.contract_id where m.id=p_mission_id and m.contract_version_id=p_contract_version_id and m.client_organization_id=p_client_organization_id and m.provider_organization_id=p_provider_organization_id and c.client_organization_id=p_client_organization_id and c.provider_organization_id=p_provider_organization_id and cv.price_minor=p_contractual_amount_minor and cv.currency=p_currency)then raise exception'INVALID_DIRECT_PAYMENT_MISSION_CONTRACT_BINDING'using errcode='23514';end if;
 if p_client_organization_id=p_provider_organization_id or p_contractual_amount_minor<=0 or p_declared_paid_minor<=0 or p_declared_paid_minor>p_contractual_amount_minor or p_currency!~'^[A-Z]{3}$'or p_payment_method not in('BANK_TRANSFER','CARD','CHECK','CASH','OTHER')or p_confirmation_status not in('DECLARED','CONFIRMED','DISPUTED')or(p_proof_hash is not null and p_proof_hash!~'^[0-9a-f]{64}$')then raise exception'INVALID_DIRECT_PAYMENT_EVIDENCE'using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('client',p_client_organization_id,'provider',p_provider_organization_id,'mission',p_mission_id,'contract_version',p_contract_version_id,'contractual_minor',p_contractual_amount_minor,'paid_minor',p_declared_paid_minor,'currency',p_currency,'paid_at',p_paid_at,'method',p_payment_method,'reference',p_provider_reference,'proof_hash',p_proof_hash,'status',p_confirmation_status));
 r:=private.begin_provider_billing_command(p_provider_organization_id,'v41.direct.client_provider_payment',p_idempotency_key,h,a);if r is not null then return r;end if;
 insert into public.direct_client_provider_payments(client_organization_id,provider_organization_id,mission_id,contract_version_id,contractual_amount_minor,declared_paid_minor,currency,paid_at,payment_method,provider_reference,proof_hash,confirmation_status,correlation_id,recorded_by)values(p_client_organization_id,p_provider_organization_id,p_mission_id,p_contract_version_id,p_contractual_amount_minor,p_declared_paid_minor,p_currency,p_paid_at,p_payment_method,p_provider_reference,p_proof_hash,p_confirmation_status,p_correlation_id,a)returning id into x;
 r:=jsonb_build_object('outcome','DIRECT_CLIENT_PROVIDER_PAYMENT_RECORDED','payment_evidence_id',x,'cash_boundary','MATRICIA_NEVER_HOLDS_PRINCIPAL','amount_minor',p_declared_paid_minor,'currency',p_currency);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_provider_organization_id,a,'USER','direct.payment.recorded','direct_client_provider_payment',x::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_provider_organization_id,'direct_client_provider_payment',x::text,'DirectClientProviderPaymentRecordedV1',p_correlation_id,r,p_idempotency_key);
 perform private.finish_provider_billing_command(p_provider_organization_id,'v41.direct.client_provider_payment',p_idempotency_key,r);return r;
end$$;

create or replace function public.create_vendor_bank_account(
  p_vendor_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();v public.vendors%rowtype;h text;r jsonb;x uuid;
begin
  select*into v from public.vendors where id=p_vendor_id and status='ACTIVE'for update;
  if a is null or not found or not private.has_platform_role(array['SUPER_ADMIN','FINANCE_MANAGER'],a)or coalesce(auth.jwt()->>'aal','')<>'aal2'then raise exception'VENDOR_BANK_ACCOUNT_CREATE_DENIED'using errcode='42501';end if;
  h:=private.canonical_request_hash(jsonb_build_object('vendor',v.id,'organization',v.organization_id));r:=private.begin_provider_billing_command(v.organization_id,'v41.vendor_bank_account.create',p_idempotency_key,h,a);if r is not null then return r;end if;
  insert into public.vendor_bank_accounts(organization_id,vendor_id,created_by)values(v.organization_id,v.id,a)returning id into x;
  r:=jsonb_build_object('outcome','VENDOR_BANK_ACCOUNT_CREATED','vendor_bank_account_id',x,'vendor_id',v.id);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v.organization_id,a,'USER','vendor_bank_account.created','vendor_bank_account',x::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(v.organization_id,'vendor_bank_account',x::text,'VendorBankAccountCreatedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(v.organization_id,'v41.vendor_bank_account.create',p_idempotency_key,r);return r;
end$$;

do $$declare t text;begin foreach t in array array['outbound_payment_schedules','outbound_payment_state_events','payment_dispute_state_events','goods_service_receipt_lines']loop execute format('create trigger %I_immutable before update or delete on public.%I for each row execute function private.prevent_update_delete()',t,t);execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);end loop;end$$;
create policy outbound_payment_schedules_finance_read on public.outbound_payment_schedules for select to authenticated using(private.v41_finance_access(organization_id));
create policy outbound_payment_state_events_finance_read on public.outbound_payment_state_events for select to authenticated using(private.v41_finance_access(organization_id));
create policy payment_dispute_state_events_finance_read on public.payment_dispute_state_events for select to authenticated using(private.v41_finance_access(organization_id));
create policy goods_service_receipt_lines_finance_read on public.goods_service_receipt_lines for select to authenticated using(private.v41_finance_access(organization_id));
grant select on public.outbound_payment_schedules,public.outbound_payment_state_events,public.payment_dispute_state_events,public.goods_service_receipt_lines to authenticated;
revoke all on public.outbound_payment_status_v41 from public,anon,authenticated,service_role;grant select on public.outbound_payment_status_v41 to authenticated;

revoke all on function public.create_vendor(uuid,text,text,text,text,text,uuid),public.create_vendor_bank_account(uuid,text,uuid),public.submit_purchase_request(uuid,uuid,text,text,character,bigint,jsonb,text,uuid),public.issue_purchase_order(uuid,text,text,text,uuid),public.confirm_goods_service_receipt(uuid,text,text,date,text,jsonb,text,uuid),public.register_supplier_invoice_payable(uuid,text,date,date,character,uuid,text,jsonb,text,uuid),public.schedule_outbound_payment(uuid,uuid,text,bigint,date,text,uuid),public.mark_outbound_payment_paid(uuid,text,timestamp with time zone,text,uuid,uuid,text,uuid),public.reconcile_paid_outbound_payment(uuid,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.create_vendor(uuid,text,text,text,text,text,uuid),public.create_vendor_bank_account(uuid,text,uuid),public.submit_purchase_request(uuid,uuid,text,text,character,bigint,jsonb,text,uuid),public.issue_purchase_order(uuid,text,text,text,uuid),public.confirm_goods_service_receipt(uuid,text,text,date,text,jsonb,text,uuid),public.register_supplier_invoice_payable(uuid,text,date,date,character,uuid,text,jsonb,text,uuid),public.schedule_outbound_payment(uuid,uuid,text,bigint,date,text,uuid),public.mark_outbound_payment_paid(uuid,text,timestamp with time zone,text,uuid,uuid,text,uuid),public.reconcile_paid_outbound_payment(uuid,text,uuid)to authenticated;
revoke all on function public.record_provider_commission_receipt(uuid,text,date,text,bigint,bigint,text,boolean,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.record_provider_commission_receipt(uuid,text,date,text,bigint,bigint,text,boolean,text,uuid)to service_role;
revoke all on function public.ingest_verified_own_payment_event(uuid,text,text,text,text,text,text,bigint,character,timestamp with time zone,text,text,text,text,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.ingest_verified_own_payment_event(uuid,text,text,text,text,text,text,bigint,character,timestamp with time zone,text,text,text,text,text,uuid)to service_role;

create index outbound_payment_schedules_payable_idx on public.outbound_payment_schedules(organization_id,accounts_payable_id,scheduled_at);
create index outbound_payment_state_latest_idx on public.outbound_payment_state_events(organization_id,outbound_payment_id,occurred_at desc,recorded_at desc);
create index payment_dispute_state_latest_idx on public.payment_dispute_state_events(organization_id,payment_dispute_id,occurred_at desc);
