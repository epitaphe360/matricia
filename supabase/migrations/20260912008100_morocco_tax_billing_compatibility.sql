-- Keep provider billing compatible with the versioned Morocco tax engine.
-- The resolved identifier is revalidated against jurisdiction, lifecycle and effective dates.

create or replace function public.record_provider_payable_event(
  p_mission_id uuid,
  p_event_type text,
  p_occurred_on date,
  p_currency char(3),
  p_gross_amount_minor bigint,
  p_client_receipt_reference text,
  p_proof_hash text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare
  a uuid:=auth.uid();
  m public.missions%rowtype;
  cv public.contract_versions%rowtype;
  resolved jsonb;
  tr public.tax_rule_versions%rowtype;
  bps integer;
  commission bigint;
  tax bigint;
  h text;
  r jsonb;
  e uuid;
  category text;
begin
  select * into m from public.missions where id=p_mission_id;
  if a is null or not found or not(
    private.has_org_role(m.provider_organization_id,array['PROVIDER_OWNER','PROVIDER_ACCOUNTING'],a)
    or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a)
  )then
    raise exception 'PROVIDER_PAYABLE_DENIED' using errcode='42501';
  end if;
  if p_event_type not in('CLIENT_RECEIPT_CONFIRMED','COMMISSION_ACCRUAL','PENALTY_ACCRUAL','ADJUSTMENT')
    or p_gross_amount_minor<=0 or p_currency!~'^[A-Z]{3}$'or p_proof_hash!~'^[0-9a-f]{64}$'then
    raise exception 'INVALID_PAYABLE_EVENT' using errcode='22023';
  end if;
  select * into cv from public.contract_versions where id=m.contract_version_id;
  bps:=coalesce(
    (cv.commission_rule_snapshot->>'commission_basis_points')::integer,
    (cv.commission_rule_snapshot->>'basis_points')::integer
  );
  if bps is null or bps not between 0 and 10000 then
    raise exception 'INVALID_COMMISSION_RULE_SNAPSHOT' using errcode='23514';
  end if;
  commission:=floor((p_gross_amount_minor::numeric*bps+5000)/10000)::bigint;
  category:=case when p_event_type='PENALTY_ACCRUAL'then'PENALTY'else'PROVIDER_COMMISSION'end;
  h:=private.canonical_request_hash(jsonb_build_object(
    'mission',m.id,'type',p_event_type,'date',p_occurred_on,'currency',p_currency,
    'gross',p_gross_amount_minor,'receipt',p_client_receipt_reference,
    'proof_hash',p_proof_hash,'tax_category',category
  ));
  r:=private.begin_provider_billing_command(
    m.provider_organization_id,'provider.billing.payable.record',p_idempotency_key,h,a
  );
  if r is not null then return r;end if;

  resolved:=private.resolve_morocco_tax(category,p_occurred_on,commission,null);
  select * into tr
  from public.tax_rule_versions
  where id=(resolved->>'tax_rule_version_id')::uuid
    and jurisdiction_code='MA'
    and status='ACTIVE'
    and effective_from<=p_occurred_on
    and(effective_to is null or effective_to>=p_occurred_on);
  if not found then
    raise exception 'MOROCCO_TAX_RULE_NOT_ACTIVE' using errcode='55000';
  end if;
  tax:=(resolved->>'tax_amount_minor')::bigint;

  insert into public.provider_payable_events(
    provider_organization_id,client_organization_id,mission_id,contract_version_id,event_type,
    occurred_on,currency,gross_amount_minor,commission_basis_points,commission_amount_minor,
    tax_rule_version_id,tax_rate_basis_points,tax_amount_minor,commission_rule_snapshot,
    client_receipt_reference,proof_hash,correlation_id,created_by
  )values(
    m.provider_organization_id,m.client_organization_id,m.id,m.contract_version_id,p_event_type,
    p_occurred_on,p_currency,p_gross_amount_minor,bps,commission,tr.id,tr.rate_basis_points,tax,
    cv.commission_rule_snapshot,p_client_receipt_reference,p_proof_hash,p_correlation_id,a
  )returning id into e;
  r:=jsonb_build_object(
    'outcome','PROVIDER_PAYABLE_RECORDED','payable_event_id',e,'commission_minor',commission,
    'tax_minor',tax,'total_due_minor',commission+tax,'tax_category_code',category,
    'tax_rule_version_id',tr.id
  );
  insert into public.audit_events(
    organization_id,actor_user_id,actor_type,action,resource_type,resource_id,
    correlation_id,metadata,event_hash
  )values(
    m.provider_organization_id,a,'USER','provider.payable.recorded','provider_payable_event',e::text,
    p_correlation_id,jsonb_build_object('mission_id',m.id,'tax_category_code',category,
    'tax_rule_version_id',tr.id),repeat('0',64)
  );
  insert into public.event_outbox(
    organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key
  )values(
    m.provider_organization_id,'provider_payable_event',e::text,'ProviderPayableRecordedV1',
    p_correlation_id,r,p_idempotency_key
  );
  perform private.finish_provider_billing_command(
    m.provider_organization_id,'provider.billing.payable.record',p_idempotency_key,r
  );
  return r;
end
$$;

revoke all on function public.record_provider_payable_event(
  uuid,text,date,char,bigint,text,text,text,uuid
) from public,anon,authenticated,service_role;
grant execute on function public.record_provider_payable_event(
  uuid,text,date,char,bigint,text,text,text,uuid
) to authenticated;
