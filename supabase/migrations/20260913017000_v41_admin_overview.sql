-- V4.1 A01: bounded central supervision across the new operational domains.

create function public.list_admin_v41_overview(p_limit integer default 50)returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private as $$
declare a uuid:=auth.uid();result jsonb;
begin
 if a is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','COMPLIANCE_MANAGER','DISPUTE_MANAGER','READ_ONLY_AUDITOR'],a)then raise exception'ADMIN_V41_OVERVIEW_DENIED'using errcode='42501';end if;
 if p_limit not between 1 and 100 then raise exception'ADMIN_V41_LIMIT_INVALID'using errcode='22023';end if;
 select jsonb_build_object(
  'generated_at',clock_timestamp(),'limit',p_limit,
  'financial_flows',jsonb_build_object(
   'client_to_provider_declared',(select count(*) from public.direct_client_provider_payments),
   'matricia_own_revenue',(select count(*) from public.matricia_own_revenue_payments),
   'provider_commission_receipts',(select count(*) from public.provider_commission_receipts)
  ),
  'modules',jsonb_build_array(
   jsonb_build_object('key','procurement','open',(select count(*) from public.purchase_requests where status not in('CLOSED','REJECTED')),'exceptions',(select count(*) from public.accounts_payable where status in('OPEN','DISPUTED'))),
   jsonb_build_object('key','supplier_ap','open',(select count(*) from public.supplier_invoices where status in('REGISTERED','DISPUTED')),'exceptions',(select count(*) from public.outbound_payments where status='FAILED')),
   jsonb_build_object('key','own_payments','open',(select count(*) from public.payment_disputes where status='OPEN'),'exceptions',(select count(*) from public.payment_reconciliation_items where result<>'MATCHED')),
   jsonb_build_object('key','treasury','open',(select count(*) from public.treasury_cashflow_snapshots),'exceptions',(select count(*) from public.treasury_cashflow_snapshots where projected_cash_minor<0)),
   jsonb_build_object('key','finops','open',(select count(*) from public.ai_usage_events),'exceptions',(select count(*) from public.ai_usage_events where alert_level>=90)+(select count(*) from public.ai_provider_invoice_reconciliations where status='VARIANCE')),
   jsonb_build_object('key','margins','open',(select count(*) from public.benefit_margin_snapshots where snapshot_type='ACTUAL'),'exceptions',(select count(*) from public.benefit_margin_snapshots where snapshot_type='ACTUAL'and margin_minor<0)),
   jsonb_build_object('key','signature','open',(select count(*) from public.signature_envelopes where status not in('SIGNED','DECLINED','EXPIRED','FAILED','VOIDED')),'exceptions',(select count(*) from public.signature_envelopes where status in('DECLINED','EXPIRED','FAILED'))),
   jsonb_build_object('key','privacy','open',(select count(*) from public.data_subject_requests where status<>'COMPLETED'),'exceptions',(select count(*) from public.international_transfers where compliance_status='REQUIRED_NOT_COMPLETED')),
   jsonb_build_object('key','third_parties','open',(select count(*) from public.third_party_service_alerts where status<>'RESOLVED'),'exceptions',(select count(*) from public.third_party_services where status='ACTIVE'and(dpa_status='REQUIRED_NOT_COMPLETED'or security_review_status='REQUIRED_NOT_COMPLETED'))),
   jsonb_build_object('key','incidents','open',(select count(*) from public.security_incidents where status<>'CLOSED'),'exceptions',(select count(*) from public.security_incidents where status<>'CLOSED'and severity in('HIGH','CRITICAL'))),
   jsonb_build_object('key','operations','open',(select count(*) from public.operational_jobs where status in('READY','RUNNING','RETRY_WAIT')),'exceptions',(select count(*) from public.operational_jobs where status='DEAD_LETTER')+(select count(*) from public.dead_letter_reprocess_requests where status='PENDING_APPROVAL')),
   jsonb_build_object('key','contracts_disputes','open',(select count(*) from public.contract_obligation_definitions),'exceptions',(select count(*) from public.dispute_conflict_disclosures where decision in('CONFLICT_DECLARED','RECUSED'))),
   jsonb_build_object('key','catalog_marketing','open',(select count(*) from public.catalog_content_review_findings where review_status='CONTENT_REVIEW_REQUIRED'),'exceptions',(select count(*) from public.marketing_kill_switch_versions where enabled))
  )
 )into result;
 return result;
end$$;

revoke all on function public.list_admin_v41_overview(integer)from public,anon,authenticated,service_role;
grant execute on function public.list_admin_v41_overview(integer)to authenticated;
