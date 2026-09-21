begin;
set local search_path = public, extensions;
select plan(11);

select ok((
  select p.prosecdef and p.proconfig::text like '%search_path=%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private' and p.proname = 'provider_has_overdue_matricia_invoice'
), 'overdue helper is security definer with a fixed search_path');

select ok((
  select pg_get_functiondef(p.oid) like '%OVERDUE_INVOICE%'
     and pg_get_functiondef(p.oid) like '%provider_has_overdue_matricia_invoice%'
     and pg_get_functiondef(p.oid) not like '%update public.provider_match_profiles%'
     and pg_get_functiondef(p.oid) not like '%update public.missions%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private' and p.proname = 'provider_service_eligibility_snapshot'
), 'eligibility snapshot derives OVERDUE_INVOICE without mutating finance or missions');

select ok((
  select pg_get_functiondef(p.oid) like '%OVERDUE_INVOICE%'
     and pg_get_functiondef(p.oid) like '%provider_has_overdue_matricia_invoice%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'run_service_request_matching'
), 'matching excludes providers with an overdue Matricia invoice');

select ok((
  pg_get_functiondef('public.open_service_request_rfq(uuid,uuid,timestamptz,text,uuid)'::regprocedure)
    like '%provider_service_eligibility_snapshot%'
), 'RFQ opening still revalidates current eligibility');

select ok((
  select pg_get_functiondef(p.oid) like '%blocks_new_opportunities%'
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'list_admin_provider_closure_dashboard'
), 'closure dashboard flags overdue invoices as blocking new opportunities');

select ok(
  not has_function_privilege('anon', 'private.provider_has_overdue_matricia_invoice(uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'private.provider_has_overdue_matricia_invoice(uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'private.provider_service_eligibility_snapshot(uuid,uuid)', 'EXECUTE'),
  'overdue helper and snapshot stay private'
);

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
('a1674000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'overdue-167@example.invalid', '', now(), '{}', '{}', now(), now()),
('a1674000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'current-167@example.invalid', '', now(), '{}', '{}', now(), now()),
('a1674000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'paid-167@example.invalid', '', now(), '{}', '{}', now(), now());
insert into public.organizations(id, legal_name, display_name, status, created_by)
values
('b1674000-0000-4000-8000-000000000001', 'Overdue 167', 'Overdue 167', 'ACTIVE', 'a1674000-0000-4000-8000-000000000001'),
('b1674000-0000-4000-8000-000000000002', 'Current 167', 'Current 167', 'ACTIVE', 'a1674000-0000-4000-8000-000000000002'),
('b1674000-0000-4000-8000-000000000003', 'Paid 167', 'Paid 167', 'ACTIVE', 'a1674000-0000-4000-8000-000000000003');
insert into public.provider_match_profiles(provider_organization_id, company_verified, documents_valid, financial_status, quality_status, capacity_status, region_codes, partner_contract_signed)
values
('b1674000-0000-4000-8000-000000000001', true, true, 'OK', 'OK', 'AVAILABLE', array['CASABLANCA'], true),
('b1674000-0000-4000-8000-000000000003', true, true, 'OK', 'OK', 'AVAILABLE', array['CASABLANCA'], true);

select ok(
  not private.provider_has_overdue_matricia_invoice('b1674000-0000-4000-8000-000000000001'),
  'no invoice means no derived overdue hold'
);

set local session_replication_role = replica;
insert into public.provider_invoices(id, provider_organization_id, statement_id, invoice_number, currency, subtotal_minor, tax_minor, total_minor, issued_on, due_on, tax_rule_snapshot, document_hash, journal_id, correlation_id, created_by)
values
('c1674000-0000-4000-8000-000000000001', 'b1674000-0000-4000-8000-000000000001', 'd1674000-0000-4000-8000-000000000001', 'INV-OVERDUE-167', 'MAD', 1000, 200, 1200, current_date - 10, current_date - 1, '[]', repeat('a', 64), 'e1674000-0000-4000-8000-000000000001', 'f1674000-0000-4000-8000-000000000001', 'a1674000-0000-4000-8000-000000000001'),
('c1674000-0000-4000-8000-000000000002', 'b1674000-0000-4000-8000-000000000002', 'd1674000-0000-4000-8000-000000000002', 'INV-CURRENT-167', 'MAD', 1000, 200, 1200, current_date - 2, current_date + 5, '[]', repeat('b', 64), 'e1674000-0000-4000-8000-000000000002', 'f1674000-0000-4000-8000-000000000002', 'a1674000-0000-4000-8000-000000000002'),
('c1674000-0000-4000-8000-000000000003', 'b1674000-0000-4000-8000-000000000003', 'd1674000-0000-4000-8000-000000000003', 'INV-PAID-167', 'MAD', 1000, 200, 1200, current_date - 10, current_date - 1, '[]', repeat('c', 64), 'e1674000-0000-4000-8000-000000000003', 'f1674000-0000-4000-8000-000000000003', 'a1674000-0000-4000-8000-000000000003');
insert into public.provider_payment_allocations(provider_organization_id, reconciliation_batch_id, payment_id, invoice_id, amount_minor)
values ('b1674000-0000-4000-8000-000000000003', 'aa675000-0000-4000-8000-000000000001', 'aa676000-0000-4000-8000-000000000001', 'c1674000-0000-4000-8000-000000000003', 1200);
set local session_replication_role = origin;

select ok(
  private.provider_has_overdue_matricia_invoice('b1674000-0000-4000-8000-000000000001')
  and (private.provider_service_eligibility_snapshot('b1674000-0000-4000-8000-000000000001', 'aa677000-0000-4000-8000-000000000001')->'reasons') ? 'OVERDUE_INVOICE'
  and not coalesce((private.provider_service_eligibility_snapshot('b1674000-0000-4000-8000-000000000001', 'aa677000-0000-4000-8000-000000000001')->>'eligible')::boolean, true),
  'outstanding past-due invoice blocks new opportunities'
);

select ok(
  not private.provider_has_overdue_matricia_invoice('b1674000-0000-4000-8000-000000000002')
  and not ((private.provider_service_eligibility_snapshot('b1674000-0000-4000-8000-000000000002', 'aa677000-0000-4000-8000-000000000002')->'reasons') ? 'OVERDUE_INVOICE'),
  'a current due date does not invent an overdue hold'
);

select ok(
  not private.provider_has_overdue_matricia_invoice('b1674000-0000-4000-8000-000000000003')
  and not ((private.provider_service_eligibility_snapshot('b1674000-0000-4000-8000-000000000003', 'aa677000-0000-4000-8000-000000000003')->'reasons') ? 'OVERDUE_INVOICE'),
  'full allocation clears the hold without rewriting financial_status'
);

select is((select financial_status from public.provider_match_profiles where provider_organization_id = 'b1674000-0000-4000-8000-000000000001'), 'OK', 'imposed or derived overdue never mutates financial_status');

select * from finish();
rollback;
