-- MAT-FUNC-031/052: exact commission forecasts and configurable multi-user approvals.
-- Forecasts and decisions are append-only; reconciliation never rewrites financial history.

create table public.business_approval_policy_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  policy_key text not null check (policy_key ~ '^[A-Z][A-Z0-9_]{2,79}$'),
  resource_type text not null check (resource_type ~ '^[A-Z][A-Z0-9_]{2,79}$'),
  version integer not null check (version > 0),
  status text not null default 'DRAFT' check (status in ('DRAFT','ACTIVE','RETIRED')),
  minimum_approvals integer not null check (minimum_approvals between 1 and 5),
  required_role_codes text[] not null check (cardinality(required_role_codes) between 1 and 12),
  requester_cannot_approve boolean not null default true,
  effective_from timestamptz not null,
  change_reason text not null check (length(btrim(change_reason)) between 10 and 1000),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  activated_by uuid references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  activated_at timestamptz,
  unique (organization_id, policy_key, version),
  unique (id, organization_id),
  check ((status = 'DRAFT' and activated_by is null and activated_at is null) or (status in ('ACTIVE','RETIRED') and activated_by is not null and activated_at is not null)),
  check (activated_by is null or activated_by <> created_by)
);

create unique index business_approval_policy_active_uidx
  on public.business_approval_policy_versions(organization_id, policy_key)
  where status = 'ACTIVE';

create table public.business_approval_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  policy_version_id uuid not null,
  resource_type text not null check (resource_type ~ '^[A-Z][A-Z0-9_]{2,79}$'),
  resource_id text not null check (length(btrim(resource_id)) between 1 and 200),
  status text not null default 'PENDING' check (status in ('PENDING','APPROVED','REJECTED','CANCELLED')),
  amount_minor bigint,
  currency char(3),
  payload_hash text not null check (payload_hash ~ '^[0-9a-f]{64}$'),
  requested_by uuid not null references auth.users(id),
  requested_at timestamptz not null default clock_timestamp(),
  decided_at timestamptz,
  consumed_at timestamptz,
  consumed_by uuid references auth.users(id),
  consumed_action text,
  row_version integer not null default 1 check (row_version > 0),
  foreign key (policy_version_id, organization_id) references public.business_approval_policy_versions(id, organization_id) on delete restrict,
  unique (organization_id, policy_version_id, resource_type, resource_id, payload_hash),
  unique (id, organization_id),
  check ((amount_minor is null and currency is null) or (amount_minor >= 0 and currency ~ '^[A-Z]{3}$')),
  check ((consumed_at is null and consumed_by is null and consumed_action is null) or (status='APPROVED' and consumed_at is not null and consumed_by is not null and length(consumed_action) between 3 and 100))
);

create table public.business_approval_decisions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  approval_request_id uuid not null,
  decision text not null check (decision in ('APPROVE','REJECT')),
  reason text not null check (length(btrim(reason)) between 3 and 1000),
  payload_hash text not null check (payload_hash ~ '^[0-9a-f]{64}$'),
  decided_by uuid not null references auth.users(id),
  correlation_id uuid not null,
  decided_at timestamptz not null default clock_timestamp(),
  foreign key (approval_request_id, organization_id) references public.business_approval_requests(id, organization_id) on delete restrict,
  unique (approval_request_id, decided_by)
);

create table public.provider_commission_forecasts (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  client_organization_id uuid not null references public.organizations(id) on delete restrict,
  mission_id uuid not null references public.missions(id) on delete restrict,
  contract_version_id uuid not null references public.contract_versions(id) on delete restrict,
  forecast_period_start date not null,
  forecast_period_end date not null,
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  estimated_gross_minor bigint not null check (estimated_gross_minor >= 0),
  commission_basis_points integer not null check (commission_basis_points between 0 and 10000),
  estimated_commission_minor bigint not null check (estimated_commission_minor >= 0 and estimated_commission_minor <= estimated_gross_minor),
  commission_rule_snapshot jsonb not null check (jsonb_typeof(commission_rule_snapshot) = 'object'),
  source_hash text not null check (source_hash ~ '^[0-9a-f]{64}$'),
  correlation_id uuid not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (provider_organization_id, mission_id, contract_version_id, forecast_period_start, forecast_period_end, source_hash),
  unique (id, provider_organization_id),
  check (provider_organization_id <> client_organization_id and forecast_period_end >= forecast_period_start)
);

create table public.provider_commission_forecast_reconciliations (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null,
  forecast_id uuid not null,
  payable_event_id uuid not null,
  forecast_amount_minor bigint not null check (forecast_amount_minor >= 0),
  official_amount_minor bigint not null check (official_amount_minor >= 0),
  variance_minor bigint not null,
  reason text not null check (length(btrim(reason)) between 3 and 1000),
  correlation_id uuid not null,
  reconciled_by uuid not null references auth.users(id),
  reconciled_at timestamptz not null default clock_timestamp(),
  foreign key (forecast_id, provider_organization_id) references public.provider_commission_forecasts(id, provider_organization_id) on delete restrict,
  foreign key (provider_organization_id, payable_event_id) references public.provider_payable_events(provider_organization_id, id) on delete restrict,
  unique (forecast_id),
  unique (payable_event_id)
);

create function private.prevent_transversal_completion_history_change() returns trigger
language plpgsql set search_path = pg_catalog as $$
begin raise exception 'IMMUTABLE_TRANSVERSAL_HISTORY' using errcode = '55000'; end $$;

create function private.guard_business_approval_policy_lifecycle() returns trigger
language plpgsql set search_path = pg_catalog as $$
begin
  if tg_op='DELETE' then raise exception 'IMMUTABLE_BUSINESS_APPROVAL_POLICY' using errcode='55000'; end if;
  if old.id<>new.id or old.organization_id<>new.organization_id or old.policy_key<>new.policy_key or old.resource_type<>new.resource_type or old.version<>new.version or old.minimum_approvals<>new.minimum_approvals or old.required_role_codes<>new.required_role_codes or old.requester_cannot_approve<>new.requester_cannot_approve or old.effective_from<>new.effective_from or old.change_reason<>new.change_reason or old.content_hash<>new.content_hash or old.created_by<>new.created_by or old.created_at<>new.created_at then raise exception 'IMMUTABLE_BUSINESS_APPROVAL_POLICY_CONTENT' using errcode='55000'; end if;
  if not ((old.status='DRAFT' and new.status='ACTIVE' and new.activated_by is not null and new.activated_at is not null) or (old.status='ACTIVE' and new.status='RETIRED' and new.activated_by=old.activated_by and new.activated_at=old.activated_at)) then raise exception 'INVALID_BUSINESS_APPROVAL_POLICY_LIFECYCLE' using errcode='55000'; end if;
  return new;
end $$;

create trigger business_approval_policy_lifecycle_guard before update or delete on public.business_approval_policy_versions for each row execute function private.guard_business_approval_policy_lifecycle();
create trigger business_approval_decisions_immutable before update or delete on public.business_approval_decisions for each row execute function private.prevent_transversal_completion_history_change();
create trigger provider_commission_forecasts_immutable before update or delete on public.provider_commission_forecasts for each row execute function private.prevent_transversal_completion_history_change();
create trigger provider_commission_forecast_reconciliations_immutable before update or delete on public.provider_commission_forecast_reconciliations for each row execute function private.prevent_transversal_completion_history_change();

create function public.propose_business_approval_policy(
  p_organization_id uuid, p_policy_key text, p_resource_type text, p_minimum_approvals integer,
  p_required_role_codes text[], p_requester_cannot_approve boolean, p_effective_from timestamptz,
  p_change_reason text, p_idempotency_key text, p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare a uuid := auth.uid(); v integer; x uuid; h text; cached jsonb; result jsonb;
begin
  if a is null or auth.jwt()->>'aal' is distinct from 'aal2' or not private.has_org_role(p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a) then raise exception 'BUSINESS_APPROVAL_POLICY_DENIED' using errcode='42501'; end if;
  if p_policy_key !~ '^[A-Z][A-Z0-9_]{2,79}$' or p_resource_type !~ '^[A-Z][A-Z0-9_]{2,79}$' or p_minimum_approvals not between 1 and 5 or cardinality(p_required_role_codes) not between p_minimum_approvals and 12 or exists(select 1 from unnest(p_required_role_codes) r where r !~ '^[A-Z][A-Z0-9_]{2,79}$') or length(btrim(coalesce(p_change_reason,''))) not between 10 and 1000 then raise exception 'INVALID_BUSINESS_APPROVAL_POLICY' using errcode='22023'; end if;
  h := private.canonical_request_hash(jsonb_build_object('organization',p_organization_id,'policy',p_policy_key,'resource_type',p_resource_type,'minimum',p_minimum_approvals,'roles',to_jsonb(p_required_role_codes),'separation',p_requester_cannot_approve,'effective_from',p_effective_from,'reason',p_change_reason));
  cached := private.begin_contract_command(p_organization_id,'business.approval.policy.propose.'||lower(p_policy_key),p_idempotency_key,h,a); if cached is not null then return cached; end if;
  perform pg_advisory_xact_lock(hashtextextended('business-approval-policy:'||p_organization_id::text||':'||p_policy_key,0));
  select coalesce(max(version),0)+1 into v from public.business_approval_policy_versions where organization_id=p_organization_id and policy_key=p_policy_key;
  insert into public.business_approval_policy_versions(organization_id,policy_key,resource_type,version,minimum_approvals,required_role_codes,requester_cannot_approve,effective_from,change_reason,content_hash,created_by)
  values(p_organization_id,p_policy_key,p_resource_type,v,p_minimum_approvals,p_required_role_codes,p_requester_cannot_approve,p_effective_from,btrim(p_change_reason),h,a) returning id into x;
  result := jsonb_build_object('outcome','BUSINESS_APPROVAL_POLICY_PROPOSED','policy_version_id',x,'version',v,'content_hash',h);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash) values(p_organization_id,a,'USER','business.approval.policy_proposed','business_approval_policy',x::text,p_correlation_id,result,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key) values(p_organization_id,'business_approval_policy',x::text,'BusinessApprovalPolicyProposedV1',p_correlation_id,result,p_idempotency_key);
  perform private.finish_contract_command(p_organization_id,'business.approval.policy.propose.'||lower(p_policy_key),p_idempotency_key,result); return result;
end $$;

create function public.activate_business_approval_policy(p_policy_version_id uuid,p_expected_hash text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare a uuid:=auth.uid(); p public.business_approval_policy_versions%rowtype; h text; cached jsonb; result jsonb;
begin
  select * into p from public.business_approval_policy_versions where id=p_policy_version_id for update;
  if a is null or p.id is null or auth.jwt()->>'aal' is distinct from 'aal2' or a=p.created_by or not private.has_org_role(p.organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a) then raise exception 'BUSINESS_APPROVAL_POLICY_ACTIVATION_DENIED' using errcode='42501'; end if;
  h:=private.canonical_request_hash(jsonb_build_object('policy_version',p.id,'content_hash',p_expected_hash)); cached:=private.begin_contract_command(p.organization_id,'business.approval.policy.activate.'||lower(p.policy_key),p_idempotency_key,h,a); if cached is not null then return cached; end if;
  if p.status<>'DRAFT' or p.content_hash<>p_expected_hash then raise exception 'STALE_BUSINESS_APPROVAL_POLICY' using errcode='40001'; end if;
  update public.business_approval_policy_versions set status='RETIRED' where organization_id=p.organization_id and policy_key=p.policy_key and status='ACTIVE';
  update public.business_approval_policy_versions set status='ACTIVE',activated_by=a,activated_at=clock_timestamp() where id=p.id;
  result:=jsonb_build_object('outcome','BUSINESS_APPROVAL_POLICY_ACTIVATED','policy_version_id',p.id,'version',p.version);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash) values(p.organization_id,a,'USER','business.approval.policy_activated','business_approval_policy',p.id::text,p_correlation_id,result,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key) values(p.organization_id,'business_approval_policy',p.id::text,'BusinessApprovalPolicyActivatedV1',p_correlation_id,result,p_idempotency_key);
  perform private.finish_contract_command(p.organization_id,'business.approval.policy.activate.'||lower(p.policy_key),p_idempotency_key,result); return result;
end $$;

create function public.request_business_approval(p_organization_id uuid,p_policy_key text,p_resource_type text,p_resource_id text,p_amount_minor bigint,p_currency text,p_payload_hash text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare a uuid:=auth.uid(); p public.business_approval_policy_versions%rowtype; x uuid; h text; cached jsonb; result jsonb;
begin
  if a is null or not private.is_active_org_member(p_organization_id,a) then raise exception 'BUSINESS_APPROVAL_REQUEST_DENIED' using errcode='42501'; end if;
  select * into p from public.business_approval_policy_versions where organization_id=p_organization_id and policy_key=p_policy_key and status='ACTIVE' and effective_from<=clock_timestamp() order by version desc limit 1;
  if p.id is null or p.resource_type<>p_resource_type or p_payload_hash!~'^[0-9a-f]{64}$' or length(btrim(coalesce(p_resource_id,''))) not between 1 and 200 or ((p_amount_minor is null)<>(p_currency is null)) or p_amount_minor<0 or (p_currency is not null and p_currency!~'^[A-Z]{3}$') then raise exception 'INVALID_BUSINESS_APPROVAL_REQUEST' using errcode='22023'; end if;
  h:=private.canonical_request_hash(jsonb_build_object('policy_version',p.id,'resource_type',p_resource_type,'resource_id',p_resource_id,'amount_minor',p_amount_minor,'currency',p_currency,'payload_hash',p_payload_hash)); cached:=private.begin_contract_command(p_organization_id,'business.approval.request.'||lower(p_policy_key),p_idempotency_key,h,a); if cached is not null then return cached; end if;
  insert into public.business_approval_requests(organization_id,policy_version_id,resource_type,resource_id,amount_minor,currency,payload_hash,requested_by) values(p_organization_id,p.id,p_resource_type,btrim(p_resource_id),p_amount_minor,p_currency,p_payload_hash,a) returning id into x;
  result:=jsonb_build_object('outcome','BUSINESS_APPROVAL_REQUESTED','approval_request_id',x,'policy_version_id',p.id,'minimum_approvals',p.minimum_approvals);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash) values(p_organization_id,a,'USER','business.approval.requested','business_approval_request',x::text,p_correlation_id,result,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key) values(p_organization_id,'business_approval_request',x::text,'BusinessApprovalRequestedV1',p_correlation_id,result,p_idempotency_key);
  perform private.finish_contract_command(p_organization_id,'business.approval.request.'||lower(p_policy_key),p_idempotency_key,result); return result;
end $$;

create function public.decide_business_approval(p_approval_request_id uuid,p_expected_row_version integer,p_decision text,p_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare a uuid:=auth.uid(); q public.business_approval_requests%rowtype; p public.business_approval_policy_versions%rowtype; approvals integer; x uuid; h text; cached jsonb; result jsonb; final_status text;
begin
  select * into q from public.business_approval_requests where id=p_approval_request_id for update; select * into p from public.business_approval_policy_versions where id=q.policy_version_id;
  if a is null or q.id is null or auth.jwt()->>'aal' is distinct from 'aal2' or not private.has_org_role(q.organization_id,p.required_role_codes,a) or (p.requester_cannot_approve and q.requested_by=a) then raise exception 'BUSINESS_APPROVAL_DECISION_DENIED' using errcode='42501'; end if;
  if p_decision not in('APPROVE','REJECT') or length(btrim(coalesce(p_reason,''))) not between 3 and 1000 then raise exception 'INVALID_BUSINESS_APPROVAL_DECISION' using errcode='22023'; end if;
  h:=private.canonical_request_hash(jsonb_build_object('request',q.id,'row_version',p_expected_row_version,'decision',p_decision,'reason',p_reason,'payload_hash',q.payload_hash)); cached:=private.begin_contract_command(q.organization_id,'business.approval.decide.'||q.id::text,p_idempotency_key,h,a); if cached is not null then return cached; end if;
  if q.status<>'PENDING' or q.row_version<>p_expected_row_version then raise exception 'STALE_BUSINESS_APPROVAL_REQUEST' using errcode='40001'; end if;
  insert into public.business_approval_decisions(organization_id,approval_request_id,decision,reason,payload_hash,decided_by,correlation_id) values(q.organization_id,q.id,p_decision,btrim(p_reason),q.payload_hash,a,p_correlation_id) returning id into x;
  select count(*) into approvals from public.business_approval_decisions where approval_request_id=q.id and decision='APPROVE';
  final_status:=case when p_decision='REJECT' then 'REJECTED' when approvals>=p.minimum_approvals then 'APPROVED' else 'PENDING' end;
  update public.business_approval_requests set status=final_status,decided_at=case when final_status='PENDING' then null else clock_timestamp() end,row_version=row_version+1 where id=q.id;
  result:=jsonb_build_object('outcome',case when final_status='PENDING' then 'BUSINESS_APPROVAL_PARTIALLY_APPROVED' else 'BUSINESS_APPROVAL_'||final_status end,'approval_request_id',q.id,'decision_id',x,'approval_count',approvals,'required_count',p.minimum_approvals,'row_version',q.row_version+1);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash) values(q.organization_id,a,'USER','business.approval.decided','business_approval_request',q.id::text,p_correlation_id,result,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key) values(q.organization_id,'business_approval_request',q.id::text,case when final_status='PENDING' then 'BusinessApprovalPartiallyApprovedV1' else 'BusinessApproval'||initcap(lower(final_status))||'V1' end,p_correlation_id,result,p_idempotency_key);
  perform private.finish_contract_command(q.organization_id,'business.approval.decide.'||q.id::text,p_idempotency_key,result); return result;
end $$;

create function public.record_provider_commission_forecast(p_mission_id uuid,p_forecast_period_start date,p_forecast_period_end date,p_estimated_gross_minor bigint,p_commission_basis_points integer,p_commission_rule_snapshot jsonb,p_source_hash text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare a uuid:=auth.uid(); m public.missions%rowtype; cv public.contract_versions%rowtype; authoritative_basis_points integer; amount bigint; x uuid; h text; cached jsonb; result jsonb;
begin
  select * into m from public.missions where id=p_mission_id; select * into cv from public.contract_versions where id=m.contract_version_id;
  if a is null or m.id is null or auth.jwt()->>'aal' is distinct from 'aal2' or not (private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a) or private.has_org_role(m.provider_organization_id,array['PROVIDER_OWNER','PROVIDER_ACCOUNTING'],a)) then raise exception 'COMMISSION_FORECAST_DENIED' using errcode='42501'; end if;
  authoritative_basis_points:=coalesce((cv.commission_rule_snapshot->>'commission_basis_points')::integer,(cv.commission_rule_snapshot->>'basis_points')::integer);
  if p_forecast_period_end<p_forecast_period_start or p_estimated_gross_minor<0 or authoritative_basis_points is null or authoritative_basis_points not between 0 and 10000 or p_commission_basis_points is distinct from authoritative_basis_points or p_commission_rule_snapshot is distinct from cv.commission_rule_snapshot or p_source_hash!~'^[0-9a-f]{64}$' then raise exception 'INVALID_COMMISSION_FORECAST' using errcode='22023'; end if;
  amount:=floor((p_estimated_gross_minor::numeric*authoritative_basis_points+5000)/10000)::bigint;
  h:=private.canonical_request_hash(jsonb_build_object('mission',m.id,'contract_version',cv.id,'start',p_forecast_period_start,'end',p_forecast_period_end,'gross_minor',p_estimated_gross_minor,'basis_points',authoritative_basis_points,'rule',cv.commission_rule_snapshot,'source_hash',p_source_hash)); cached:=private.begin_provider_billing_command(m.provider_organization_id,'provider.commission.forecast',p_idempotency_key,h,a); if cached is not null then return cached; end if;
  insert into public.provider_commission_forecasts(provider_organization_id,client_organization_id,mission_id,contract_version_id,forecast_period_start,forecast_period_end,currency,estimated_gross_minor,commission_basis_points,estimated_commission_minor,commission_rule_snapshot,source_hash,correlation_id,created_by) values(m.provider_organization_id,m.client_organization_id,m.id,cv.id,p_forecast_period_start,p_forecast_period_end,cv.currency,p_estimated_gross_minor,authoritative_basis_points,amount,cv.commission_rule_snapshot,p_source_hash,p_correlation_id,a) returning id into x;
  result:=jsonb_build_object('outcome','PROVIDER_COMMISSION_FORECAST_RECORDED','forecast_id',x,'estimated_commission_minor',amount,'currency',cv.currency);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash) values(m.provider_organization_id,a,'USER','provider.commission.forecast_recorded','provider_commission_forecast',x::text,p_correlation_id,result,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key) values(m.provider_organization_id,'provider_commission_forecast',x::text,'ProviderCommissionForecastRecordedV1',p_correlation_id,result,p_idempotency_key);
  perform private.finish_provider_billing_command(m.provider_organization_id,'provider.commission.forecast',p_idempotency_key,result); return result;
end $$;

create function public.reconcile_provider_commission_forecast(p_forecast_id uuid,p_payable_event_id uuid,p_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare a uuid:=auth.uid(); f public.provider_commission_forecasts%rowtype; e public.provider_payable_events%rowtype; x uuid; h text; cached jsonb; result jsonb;
begin
  select * into f from public.provider_commission_forecasts where id=p_forecast_id; select * into e from public.provider_payable_events where id=p_payable_event_id;
  if a is null or f.id is null or e.id is null or auth.jwt()->>'aal' is distinct from 'aal2' or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a) then raise exception 'COMMISSION_FORECAST_RECONCILIATION_DENIED' using errcode='42501'; end if;
  if e.provider_organization_id<>f.provider_organization_id or e.mission_id<>f.mission_id or e.contract_version_id<>f.contract_version_id or e.currency<>f.currency or length(btrim(coalesce(p_reason,''))) not between 3 and 1000 then raise exception 'COMMISSION_FORECAST_PAYABLE_MISMATCH' using errcode='23514'; end if;
  h:=private.canonical_request_hash(jsonb_build_object('forecast',f.id,'payable_event',e.id,'reason',p_reason)); cached:=private.begin_provider_billing_command(f.provider_organization_id,'provider.commission.forecast.reconcile',p_idempotency_key,h,a); if cached is not null then return cached; end if;
  insert into public.provider_commission_forecast_reconciliations(provider_organization_id,forecast_id,payable_event_id,forecast_amount_minor,official_amount_minor,variance_minor,reason,correlation_id,reconciled_by) values(f.provider_organization_id,f.id,e.id,f.estimated_commission_minor,e.commission_amount_minor,e.commission_amount_minor-f.estimated_commission_minor,btrim(p_reason),p_correlation_id,a) returning id into x;
  result:=jsonb_build_object('outcome','PROVIDER_COMMISSION_FORECAST_RECONCILED','reconciliation_id',x,'forecast_id',f.id,'payable_event_id',e.id,'forecast_minor',f.estimated_commission_minor,'official_minor',e.commission_amount_minor,'variance_minor',e.commission_amount_minor-f.estimated_commission_minor);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash) values(f.provider_organization_id,a,'USER','provider.commission.forecast_reconciled','provider_commission_forecast',f.id::text,p_correlation_id,result,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key) values(f.provider_organization_id,'provider_commission_forecast',f.id::text,'ProviderCommissionForecastReconciledV1',p_correlation_id,result,p_idempotency_key);
  perform private.finish_provider_billing_command(f.provider_organization_id,'provider.commission.forecast.reconcile',p_idempotency_key,result); return result;
end $$;

alter table public.business_approval_policy_versions enable row level security;
alter table public.business_approval_requests enable row level security;
alter table public.business_approval_decisions enable row level security;
alter table public.provider_commission_forecasts enable row level security;
alter table public.provider_commission_forecast_reconciliations enable row level security;
revoke all on public.business_approval_policy_versions,public.business_approval_requests,public.business_approval_decisions,public.provider_commission_forecasts,public.provider_commission_forecast_reconciliations from public,anon,authenticated,service_role;
grant select on public.business_approval_policy_versions,public.business_approval_requests,public.business_approval_decisions,public.provider_commission_forecasts,public.provider_commission_forecast_reconciliations to authenticated;
create policy business_approval_policy_tenant_read on public.business_approval_policy_versions for select to authenticated using(private.is_active_org_member(organization_id) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'],auth.uid()));
create policy business_approval_request_tenant_read on public.business_approval_requests for select to authenticated using(private.is_active_org_member(organization_id) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'],auth.uid()));
create policy business_approval_decision_tenant_read on public.business_approval_decisions for select to authenticated using(private.is_active_org_member(organization_id) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'],auth.uid()));
create policy provider_commission_forecast_party_read on public.provider_commission_forecasts for select to authenticated using(private.is_active_org_member(provider_organization_id) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','READ_ONLY_AUDITOR'],auth.uid()));
create policy provider_commission_forecast_reconciliation_party_read on public.provider_commission_forecast_reconciliations for select to authenticated using(exists(select 1 from public.provider_commission_forecasts f where f.id=forecast_id and (private.is_active_org_member(f.provider_organization_id) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','READ_ONLY_AUDITOR'],auth.uid()))));

create index business_approval_requests_queue_idx on public.business_approval_requests(organization_id,status,requested_at,id);
create index business_approval_decisions_request_idx on public.business_approval_decisions(approval_request_id,decided_at,id);
create index provider_commission_forecasts_period_idx on public.provider_commission_forecasts(provider_organization_id,forecast_period_start,forecast_period_end,id);

-- MAT-FUNC-064: the worker must receive the post-claim row version required by completion.
create or replace function public.claim_franchise_daily_digest_jobs(p_worker_id uuid,p_limit integer default 20,p_lease_seconds integer default 300)returns setof jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare j record;token uuid;corr uuid;claimed_row_version integer;
begin
 if auth.role()<>'service_role'then raise exception'FRANCHISE_DIGEST_WORKER_ONLY'using errcode='42501';end if;
 if p_worker_id is null or p_limit not between 1 and 100 or p_lease_seconds not between 30 and 900 then raise exception'INVALID_FRANCHISE_DIGEST_CLAIM'using errcode='22023';end if;
 for j in select x.id,q.organization_id from public.franchise_daily_digest_jobs x join public.franchise_daily_digests q on q.id=x.digest_id where((x.status in('QUEUED','FAILED')and x.next_attempt_at<=clock_timestamp())or(x.status='CLAIMED'and x.leased_until<=clock_timestamp())) and private.franchise_digest_role_access(x.franchise_id,false,x.recipient_user_id) order by coalesce(x.next_attempt_at,x.leased_until),x.id for update of x skip locked limit p_limit loop
  token:=extensions.gen_random_uuid();corr:=extensions.gen_random_uuid();
  update public.franchise_daily_digest_jobs set status='CLAIMED',attempt_count=attempt_count+1,next_attempt_at=null,lease_token=token,worker_id=p_worker_id,leased_until=clock_timestamp()+make_interval(secs=>p_lease_seconds),row_version=row_version+1,updated_at=clock_timestamp()where id=j.id returning row_version into claimed_row_version;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(j.organization_id,null,'SYSTEM','franchise.daily_digest.claimed','franchise_daily_digest_job',j.id::text,corr,jsonb_build_object('worker_id',p_worker_id,'lease_seconds',p_lease_seconds,'row_version',claimed_row_version),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(j.organization_id,'franchise_daily_digest_job',j.id::text,'FranchiseDailyDigestClaimedV1',corr,jsonb_build_object('job_id',j.id,'worker_id',p_worker_id,'row_version',claimed_row_version),'franchise-digest-claim:'||j.id::text||':'||token::text);
  return next jsonb_build_object('job_id',j.id,'lease_token',token,'worker_id',p_worker_id,'row_version',claimed_row_version);
 end loop;return;
end $$;

create function public.request_marketing_campaign_approval_v1(p_campaign_id uuid,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();c public.marketing_campaigns%rowtype;payload_hash text;
begin
 select*into c from public.marketing_campaigns where id=p_campaign_id;
 if a is null or c.id is null or not private.marketing_manage_access(c.organization_id,a)then raise exception'MARKETING_APPROVAL_REQUEST_DENIED'using errcode='42501';end if;
 if c.status<>'VALIDATED_BY_RULES'or c.row_version<>p_expected_row_version then raise exception'MARKETING_CAMPAIGN_NOT_APPROVABLE'using errcode='55000';end if;
 payload_hash:=private.canonical_request_hash(jsonb_build_object('campaign',c.id,'expected',p_expected_row_version));
 return public.request_business_approval(c.organization_id,'MARKETING_CAMPAIGN_APPROVAL','MARKETING_CAMPAIGN',c.id::text,null,null,payload_hash,p_idempotency_key,p_correlation_id);
end$$;

create or replace function public.approve_marketing_campaign(p_campaign_id uuid,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();c public.marketing_campaigns%rowtype;h text;cached jsonb;r jsonb;approval_id uuid;payload_hash text;policy_exists boolean;
begin
 select*into c from public.marketing_campaigns where id=p_campaign_id;
 if a is null or c.id is null or not private.marketing_manage_access(c.organization_id,a)then raise exception'MARKETING_APPROVAL_DENIED'using errcode='42501';end if;
 h:=private.canonical_request_hash(jsonb_build_object('campaign',c.id,'expected',p_expected_row_version));cached:=private.begin_contract_command(c.organization_id,'marketing.campaign.approve.'||c.id,p_idempotency_key,h,a);if cached is not null then return cached;end if;
 select*into c from public.marketing_campaigns where id=p_campaign_id for update;
 if c.status<>'VALIDATED_BY_RULES'or c.row_version<>p_expected_row_version or exists(select 1 from public.marketing_exceptions where campaign_id=c.id and severity='BLOCKING'and status='OPEN')or not exists(select 1 from public.marketing_content x join public.marketing_content_versions v on v.id=x.current_version_id where x.campaign_id=c.id and v.status='VALIDATED_BY_RULES')then raise exception'MARKETING_CAMPAIGN_NOT_APPROVABLE'using errcode='55000';end if;
 payload_hash:=private.canonical_request_hash(jsonb_build_object('campaign',c.id,'expected',p_expected_row_version));
 select exists(select 1 from public.business_approval_policy_versions where organization_id=c.organization_id and policy_key='MARKETING_CAMPAIGN_APPROVAL'and resource_type='MARKETING_CAMPAIGN'and status='ACTIVE'and effective_from<=clock_timestamp())into policy_exists;
 if policy_exists then
  select q.id into approval_id from public.business_approval_requests q join public.business_approval_policy_versions p on p.id=q.policy_version_id where q.organization_id=c.organization_id and p.policy_key='MARKETING_CAMPAIGN_APPROVAL'and q.resource_type='MARKETING_CAMPAIGN'and q.resource_id=c.id::text and q.payload_hash=payload_hash and q.status='APPROVED'and q.consumed_at is null order by q.decided_at,q.id limit 1 for update of q;
  if approval_id is null then raise exception'APPROVED_BUSINESS_REQUEST_REQUIRED'using errcode='42501';end if;
  update public.business_approval_requests set consumed_at=clock_timestamp(),consumed_by=a,consumed_action='MARKETING_CAMPAIGN_APPROVE',row_version=row_version+1 where id=approval_id and consumed_at is null;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(c.organization_id,a,'USER','business.approval.consumed','business_approval_request',approval_id::text,p_correlation_id,jsonb_build_object('campaign_id',c.id,'payload_hash',payload_hash),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(c.organization_id,'business_approval_request',approval_id::text,'BusinessApprovalConsumedV1',p_correlation_id,jsonb_build_object('approval_request_id',approval_id,'campaign_id',c.id),p_idempotency_key||':approval');
 end if;
 update public.marketing_campaigns set status='APPROVED',approved_by=a,approved_at=clock_timestamp(),row_version=row_version+1 where id=c.id and row_version=p_expected_row_version;if not found then raise exception'STALE_MARKETING_CAMPAIGN'using errcode='40001';end if;
 update public.marketing_content_versions v set status='APPROVED'from public.marketing_content x where x.current_version_id=v.id and x.campaign_id=c.id and v.status='VALIDATED_BY_RULES';
 r:=jsonb_build_object('outcome','MARKETING_CAMPAIGN_APPROVED','campaign_id',c.id,'approved_by',a,'approval_request_id',approval_id);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(c.organization_id,a,'USER','marketing.campaign.approved','marketing_campaign',c.id::text,p_correlation_id,r,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(c.organization_id,'marketing_campaign',c.id::text,'MarketingCampaignApprovedV1',p_correlation_id,r,p_idempotency_key);
 perform private.finish_contract_command(c.organization_id,'marketing.campaign.approve.'||c.id,p_idempotency_key,r);return r;
end$$;

create function private.enforce_marketing_governance_aal2_v1()returns trigger language plpgsql set search_path=pg_catalog as $$begin
  -- Human governance mutations require phishing-resistant re-authentication.
  -- Trusted backend maintenance continues to run as service_role/postgres and is
  -- still constrained by the command ACLs and immutable audit/outbox contracts.
  if auth.role() in ('anon','authenticated') and auth.jwt()->>'aal'is distinct from'aal2'then
    raise exception'MARKETING_GOVERNANCE_AAL2_REQUIRED'using errcode='42501';
  end if;
  return new;
end$$;
create trigger marketing_brand_authorization_aal2_v1 before insert on public.marketing_brand_authorizations for each row execute function private.enforce_marketing_governance_aal2_v1();
create trigger social_connection_security_aal2_v1 before insert on public.social_connection_security_versions for each row execute function private.enforce_marketing_governance_aal2_v1();
create trigger marketing_kill_switch_aal2_v1 before insert on public.marketing_kill_switch_versions for each row execute function private.enforce_marketing_governance_aal2_v1();

revoke all on function private.prevent_transversal_completion_history_change(),private.guard_business_approval_policy_lifecycle(),private.enforce_marketing_governance_aal2_v1() from public,anon,authenticated,service_role;
revoke all on function public.propose_business_approval_policy(uuid,text,text,integer,text[],boolean,timestamptz,text,text,uuid),public.activate_business_approval_policy(uuid,text,text,uuid),public.request_business_approval(uuid,text,text,text,bigint,text,text,text,uuid),public.decide_business_approval(uuid,integer,text,text,text,uuid),public.record_provider_commission_forecast(uuid,date,date,bigint,integer,jsonb,text,text,uuid),public.reconcile_provider_commission_forecast(uuid,uuid,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.propose_business_approval_policy(uuid,text,text,integer,text[],boolean,timestamptz,text,text,uuid),public.activate_business_approval_policy(uuid,text,text,uuid),public.request_business_approval(uuid,text,text,text,bigint,text,text,text,uuid),public.decide_business_approval(uuid,integer,text,text,text,uuid),public.record_provider_commission_forecast(uuid,date,date,bigint,integer,jsonb,text,text,uuid),public.reconcile_provider_commission_forecast(uuid,uuid,text,text,uuid) to authenticated;
revoke all on function public.request_marketing_campaign_approval_v1(uuid,integer,text,uuid)from public,anon,service_role;
grant execute on function public.request_marketing_campaign_approval_v1(uuid,integer,text,uuid)to authenticated;
revoke all on function public.claim_franchise_daily_digest_jobs(uuid,integer,integer) from public,anon,authenticated,service_role;
grant execute on function public.claim_franchise_daily_digest_jobs(uuid,integer,integer) to service_role;

notify pgrst,'reload schema';
