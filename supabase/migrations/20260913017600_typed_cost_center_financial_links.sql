-- Additive closure: typed, tenant-safe cost-center links for expenses and invoices.

alter table public.client_cost_allocations
  drop constraint client_cost_allocations_reference_type_check,
  add constraint client_cost_allocations_reference_type_check check(reference_type in(
    'PROJECT','PROJECT_TASK','CONTRACT','MISSION','MISSION_MILESTONE','INVOICE','DOCUMENT','RFQ','MANUAL'
  ));

create or replace function public.record_client_typed_cost_allocation(
  p_organization_id uuid,p_cost_center_id uuid,p_budget_id uuid,p_project_id uuid,
  p_allocation_type text,p_amount_minor bigint,p_reference_type text,p_reference_id uuid,
  p_evidence_hash text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare
  a uuid:=auth.uid(); h text; r jsonb; b public.client_annual_budgets%rowtype;
  bv public.client_annual_budget_versions%rowtype; allocated bigint; x uuid;
  invoice_total bigint; invoice_allocated bigint;
begin
  if a is null or not private.client_budget_manage(p_organization_id,a) then
    raise exception 'CLIENT_COST_ALLOCATION_DENIED' using errcode='42501';
  end if;
  select * into b from public.client_annual_budgets
   where id=p_budget_id and organization_id=p_organization_id and status='APPROVED' for update;
  select * into bv from public.client_annual_budget_versions where budget_id=b.id and version=b.current_version;
  if not found
    or not exists(select 1 from public.client_cost_centers where id=p_cost_center_id and organization_id=p_organization_id and status='ACTIVE')
    or (p_project_id is not null and not exists(select 1 from public.client_projects where id=p_project_id and organization_id=p_organization_id))
    or p_allocation_type not in('COMMITMENT','ACTUAL','RELEASE') or p_amount_minor<=0
    or p_reference_type not in('PROJECT','PROJECT_TASK','CONTRACT','MISSION','MISSION_MILESTONE','INVOICE','DOCUMENT','RFQ','MANUAL')
    or not private.client_typed_reference_valid(p_organization_id,p_reference_type,p_reference_id,p_project_id)
    or p_evidence_hash!~'^[0-9a-f]{64}$' then
    raise exception 'INVALID_CLIENT_COST_ALLOCATION' using errcode='22023';
  end if;
  h:=private.canonical_request_hash(jsonb_build_object('org',p_organization_id,'cost_center',p_cost_center_id,'budget',p_budget_id,'budget_version',bv.id,'project',p_project_id,'type',p_allocation_type,'amount_minor',p_amount_minor,'reference_type',p_reference_type,'reference_id',p_reference_id,'evidence_hash',p_evidence_hash));
  r:=private.begin_contract_command(p_organization_id,'client.cost.allocate.typed',p_idempotency_key,h,a);
  if r is not null then return r; end if;
  select coalesce(sum(case when allocation_type='RELEASE' then -amount_minor else amount_minor end),0)
    into allocated from public.client_cost_allocations where budget_id=b.id and budget_version_id=bv.id;
  if p_allocation_type<>'RELEASE' and allocated+p_amount_minor>bv.approved_amount_minor then
    raise exception 'CLIENT_BUDGET_EXCEEDED' using errcode='23514';
  elsif p_allocation_type='RELEASE' and p_amount_minor>allocated then
    raise exception 'CLIENT_ALLOCATION_RELEASE_EXCEEDED' using errcode='23514';
  end if;
  if p_reference_type='INVOICE' and p_allocation_type='ACTUAL' then
    select i.total_minor into invoice_total from public.provider_invoices i where i.id=p_reference_id;
    select coalesce(sum(case when allocation_type='RELEASE' then -amount_minor else amount_minor end),0)
      into invoice_allocated from public.client_cost_allocations
      where organization_id=p_organization_id and reference_type='INVOICE' and reference_id=p_reference_id;
    if invoice_allocated+p_amount_minor>invoice_total then raise exception 'CLIENT_INVOICE_ALLOCATION_EXCEEDED' using errcode='23514'; end if;
  end if;
  insert into public.client_cost_allocations(organization_id,cost_center_id,budget_id,budget_version_id,project_id,allocation_type,amount_minor,currency,reference_type,reference_id,evidence_hash,idempotency_key,correlation_id,created_by)
  values(p_organization_id,p_cost_center_id,b.id,bv.id,p_project_id,p_allocation_type,p_amount_minor,b.currency,p_reference_type,p_reference_id,p_evidence_hash,p_idempotency_key,p_correlation_id,a) returning id into x;
  r:=jsonb_build_object('outcome','CLIENT_TYPED_COST_ALLOCATED','allocation_id',x,'budget_id',b.id,'budget_version_id',bv.id,'amount_minor',p_amount_minor,'allocation_type',p_allocation_type,'reference_type',p_reference_type,'reference_id',p_reference_id,'remaining_minor',bv.approved_amount_minor-(allocated+case when p_allocation_type='RELEASE' then -p_amount_minor else p_amount_minor end));
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(p_organization_id,a,'USER','client.cost.typed_allocated','client_cost_allocation',x::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
  values(p_organization_id,'client_cost_allocation',x::text,'ClientTypedCostAllocatedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_contract_command(p_organization_id,'client.cost.allocate.typed',p_idempotency_key,r);
  return r;
end$$;

revoke all on function public.record_client_typed_cost_allocation(uuid,uuid,uuid,uuid,text,bigint,text,uuid,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.record_client_typed_cost_allocation(uuid,uuid,uuid,uuid,text,bigint,text,uuid,text,text,uuid) to authenticated;

create index client_cost_allocations_reference_idx on public.client_cost_allocations(organization_id,reference_type,reference_id,created_at desc) where reference_id is not null;

