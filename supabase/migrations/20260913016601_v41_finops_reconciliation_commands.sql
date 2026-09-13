-- V4.1 F04 completion: actual margin snapshots and AI invoice reconciliation.

alter table public.benefit_margin_snapshots add column idempotency_key text;
alter table public.benefit_margin_snapshots add constraint benefit_margin_snapshots_idempotency_key_check check(idempotency_key is null or length(idempotency_key) between 8 and 200);
alter table public.benefit_margin_snapshots add constraint benefit_margin_snapshots_org_idempotency_unique unique(organization_id,idempotency_key);

create table public.ai_provider_invoice_reconciliations(
 id uuid primary key default extensions.gen_random_uuid(),provider_config_id uuid not null references public.ai_provider_configs(id) on delete restrict,
 provider_invoice_reference text not null check(length(btrim(provider_invoice_reference))between 3 and 200),period_start timestamptz not null,period_end timestamptz not null,
 invoiced_minor bigint not null check(invoiced_minor>=0),computed_minor bigint not null check(computed_minor>=0),variance_minor bigint generated always as(invoiced_minor-computed_minor) stored,
 currency char(3) not null check(currency~'^[A-Z]{3}$'),status text not null check(status in('MATCHED','VARIANCE','RESOLVED')),
 evidence_hash text not null check(evidence_hash~'^[0-9a-f]{64}$'),idempotency_key text not null check(length(idempotency_key)between 8 and 200),correlation_id uuid not null,
 reconciled_at timestamptz not null default clock_timestamp(),unique(provider_config_id,provider_invoice_reference),unique(provider_config_id,idempotency_key),check(period_end>period_start),check((status='MATCHED')=(invoiced_minor=computed_minor))
);

create function public.capture_benefit_margin_snapshot(p_organization_id uuid,p_redemption_id uuid,p_snapshot_type text,p_revenue_minor bigint,p_currency char(3),p_rule_version text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare r public.benefit_redemptions%rowtype;existing public.benefit_margin_snapshots%rowtype;cost bigint;sid bigint;result jsonb;
begin
 if p_snapshot_type not in('FORECAST','ACTUAL')or p_revenue_minor<0 or p_currency!~'^[A-Z]{3}$'or length(btrim(coalesce(p_rule_version,'')))<1 or length(p_idempotency_key)not between 8 and 200 then raise exception'INVALID_MARGIN_SNAPSHOT'using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('benefit.margin.'||p_idempotency_key,0));
 select*into existing from public.benefit_margin_snapshots where organization_id=p_organization_id and idempotency_key=p_idempotency_key;
 if found then if existing.redemption_id<>p_redemption_id or existing.snapshot_type<>p_snapshot_type or existing.revenue_minor<>p_revenue_minor or existing.currency<>p_currency or existing.rule_version<>p_rule_version then raise exception'MARGIN_SNAPSHOT_REPLAY_MISMATCH'using errcode='22000';end if;return jsonb_build_object('outcome','MARGIN_SNAPSHOT_REPLAYED','snapshot_id',existing.id,'margin_minor',existing.margin_minor,'replayed',true);end if;
 select*into r from public.benefit_redemptions where id=p_redemption_id and organization_id=p_organization_id;if not found then raise exception'REDEMPTION_SCOPE_MISMATCH'using errcode='23503';end if;
 if p_snapshot_type='ACTUAL'then select sum(amount_minor)into cost from public.benefit_actual_costs where organization_id=p_organization_id and redemption_id=p_redemption_id and currency=p_currency;if cost is null then raise exception'ACTUAL_COST_EVIDENCE_REQUIRED'using errcode='23514';end if;else select v.internal_cost_minor*r.units into cost from public.benefit_versions v where v.id=r.benefit_version_id and v.currency=p_currency;if cost is null then raise exception'FORECAST_COST_VERSION_REQUIRED'using errcode='23514';end if;end if;
 insert into public.benefit_margin_snapshots(organization_id,redemption_id,snapshot_type,revenue_minor,cost_minor,currency,rule_version,correlation_id,idempotency_key)values(p_organization_id,p_redemption_id,p_snapshot_type,p_revenue_minor,cost,p_currency,p_rule_version,p_correlation_id,p_idempotency_key)returning id into sid;
 result:=jsonb_build_object('outcome','BENEFIT_MARGIN_CAPTURED','snapshot_id',sid,'snapshot_type',p_snapshot_type,'revenue_minor',p_revenue_minor,'cost_minor',cost,'margin_minor',p_revenue_minor-cost,'currency',p_currency,'replayed',false);
 insert into public.audit_events(organization_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,'SERVICE','benefit.margin_captured','benefit_margin_snapshot',sid::text,p_correlation_id,result-'outcome'-'replayed',repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_organization_id,'benefit_redemption',p_redemption_id::text,'BenefitMarginCapturedV1',p_correlation_id,result,p_idempotency_key);
 return result;
end$$;

create function public.reconcile_ai_provider_invoice(p_provider_config_id uuid,p_provider_invoice_reference text,p_period_start timestamptz,p_period_end timestamptz,p_invoiced_minor bigint,p_currency char(3),p_evidence_hash text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare existing public.ai_provider_invoice_reconciliations%rowtype;computed bigint;rid uuid;state text;result jsonb;
begin
 if p_period_end<=p_period_start or p_invoiced_minor<0 or p_currency!~'^[A-Z]{3}$'or p_evidence_hash!~'^[0-9a-f]{64}$'or length(p_idempotency_key)not between 8 and 200 then raise exception'INVALID_AI_INVOICE'using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('ai.invoice.'||p_provider_config_id::text||'.'||p_idempotency_key,0));
 select*into existing from public.ai_provider_invoice_reconciliations where provider_config_id=p_provider_config_id and idempotency_key=p_idempotency_key;
 if found then if existing.provider_invoice_reference<>p_provider_invoice_reference or existing.period_start<>p_period_start or existing.period_end<>p_period_end or existing.invoiced_minor<>p_invoiced_minor or existing.currency<>p_currency or existing.evidence_hash<>p_evidence_hash then raise exception'AI_INVOICE_REPLAY_MISMATCH'using errcode='22000';end if;return jsonb_build_object('outcome','AI_INVOICE_REPLAYED','reconciliation_id',existing.id,'computed_minor',existing.computed_minor,'variance_minor',existing.variance_minor,'replayed',true);end if;
 perform 1 from public.ai_provider_configs where id=p_provider_config_id;if not found then raise exception'AI_PROVIDER_CONFIG_NOT_FOUND'using errcode='P0002';end if;
 if exists(select 1 from public.ai_usage_events where provider_config_id=p_provider_config_id and occurred_at>=p_period_start and occurred_at<p_period_end and currency<>p_currency)then raise exception'AI_INVOICE_CURRENCY_MISMATCH'using errcode='23514';end if;
 select coalesce(sum(cost_minor),0)into computed from public.ai_usage_events where provider_config_id=p_provider_config_id and occurred_at>=p_period_start and occurred_at<p_period_end and currency=p_currency;
 state:=case when computed=p_invoiced_minor then'MATCHED'else'VARIANCE'end;
 insert into public.ai_provider_invoice_reconciliations(provider_config_id,provider_invoice_reference,period_start,period_end,invoiced_minor,computed_minor,currency,status,evidence_hash,idempotency_key,correlation_id)values(p_provider_config_id,p_provider_invoice_reference,p_period_start,p_period_end,p_invoiced_minor,computed,p_currency,state,p_evidence_hash,p_idempotency_key,p_correlation_id)returning id into rid;
 result:=jsonb_build_object('outcome','AI_PROVIDER_INVOICE_RECONCILED','reconciliation_id',rid,'status',state,'invoiced_minor',p_invoiced_minor,'computed_minor',computed,'variance_minor',p_invoiced_minor-computed,'currency',p_currency,'replayed',false);
 insert into public.audit_events(actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values('SERVICE','ai.provider_invoice_reconciled','ai_provider_invoice_reconciliation',rid::text,p_correlation_id,result-'outcome'-'replayed',repeat('0',64));
 insert into public.event_outbox(aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values('ai_provider_invoice_reconciliation',rid::text,'AiProviderInvoiceReconciledV1',p_correlation_id,result,p_idempotency_key);
 return result;
end$$;

alter table public.ai_provider_invoice_reconciliations enable row level security;
revoke all on public.ai_provider_invoice_reconciliations from public,anon,authenticated;
grant select on public.ai_provider_invoice_reconciliations to authenticated;
create policy ai_provider_invoice_reconciliations_admin_read on public.ai_provider_invoice_reconciliations for select to authenticated using(private.v41_finops_admin_access());
create trigger ai_provider_invoice_reconciliations_immutable before update or delete on public.ai_provider_invoice_reconciliations for each row execute function private.prevent_update_delete();
create index ai_provider_invoice_period_idx on public.ai_provider_invoice_reconciliations(provider_config_id,period_start,period_end,reconciled_at desc);

revoke all on function public.capture_benefit_margin_snapshot(uuid,uuid,text,bigint,character,text,text,uuid),public.reconcile_ai_provider_invoice(uuid,text,timestamptz,timestamptz,bigint,character,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.capture_benefit_margin_snapshot(uuid,uuid,text,bigint,character,text,text,uuid),public.reconcile_ai_provider_invoice(uuid,text,timestamptz,timestamptz,bigint,character,text,text,uuid) to service_role;
