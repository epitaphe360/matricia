-- V4.1 F04: immutable AI FinOps, actual Box/benefit margins and versioned treasury forecasts.

create function private.v41_finops_admin_access(p_actor uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=pg_catalog,private as $$
  select private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','READ_ONLY_AUDITOR'],p_actor)
$$;

create function private.v41_finops_tenant_access(p_org uuid,p_actor uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=pg_catalog,private as $$
  select private.is_active_org_member(p_org,p_actor) or private.v41_finops_admin_access(p_actor)
$$;

create table public.ai_provider_configs(
 id uuid primary key default extensions.gen_random_uuid(),
 provider_code text not null check(provider_code~'^[A-Z][A-Z0-9_]{1,39}$'),
 version integer not null check(version>0),status text not null check(status in('DRAFT','ACTIVE','PAUSED','RETIRED')),
 region_code text not null check(length(btrim(region_code))between 2 and 40),endpoint_class text not null check(endpoint_class in('PUBLIC_API','PRIVATE_ENDPOINT','PROXY')),
 secret_reference text not null check(secret_reference~'^[A-Za-z][A-Za-z0-9_./:-]{2,199}$'),
 routing_priority integer not null default 100 check(routing_priority between 1 and 10000),config_snapshot jsonb not null default'{}' check(jsonb_typeof(config_snapshot)='object'),
 effective_from timestamptz not null,effective_to timestamptz,content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(provider_code,version),check(effective_to is null or effective_to>effective_from),
 check(config_snapshot ?& array['stores_prompts','training_opt_out'])
);
create unique index ai_provider_one_active_idx on public.ai_provider_configs(provider_code) where status='ACTIVE';

create table public.ai_price_versions(
 id uuid primary key default extensions.gen_random_uuid(),provider_config_id uuid not null references public.ai_provider_configs(id) on delete restrict,
 version integer not null check(version>0),model_code text not null check(length(btrim(model_code))between 1 and 100),meter_code text not null check(meter_code in('INPUT_TOKEN','OUTPUT_TOKEN','CACHED_INPUT_TOKEN','REQUEST','IMAGE','AUDIO_SECOND','TOOL_CALL')),
 unit_size bigint not null check(unit_size>0),unit_cost_micro_minor bigint not null check(unit_cost_micro_minor>=0),currency char(3) not null check(currency~'^[A-Z]{3}$'),
 effective_from timestamptz not null,effective_to timestamptz,content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(provider_config_id,model_code,meter_code,version),check(effective_to is null or effective_to>effective_from)
);

create table public.ai_budgets(
 id uuid primary key default extensions.gen_random_uuid(),organization_id uuid references public.organizations(id) on delete restrict,
 scope_type text not null check(scope_type in('PLATFORM','ORGANIZATION','PROJECT','USER')),scope_id uuid,
 period_start timestamptz not null,period_end timestamptz not null,currency char(3) not null check(currency~'^[A-Z]{3}$'),limit_minor bigint not null check(limit_minor>=0),
 alert_50 boolean not null default true,alert_75 boolean not null default true,alert_90 boolean not null default true,hard_stop_at_100 boolean not null default true,
 routing_policy jsonb not null default'{}' check(jsonb_typeof(routing_policy)='object'),status text not null default'ACTIVE' check(status in('DRAFT','ACTIVE','EXHAUSTED','RETIRED')),
 version integer not null check(version>0),created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 check(period_end>period_start),check((scope_type='PLATFORM'and organization_id is null and scope_id is null)or(scope_type='ORGANIZATION'and organization_id is not null and scope_id=organization_id)or(scope_type in('PROJECT','USER')and organization_id is not null and scope_id is not null)),
 unique(scope_type,scope_id,period_start,version)
);

create table public.ai_usage_events(
 id bigint generated always as identity primary key,organization_id uuid references public.organizations(id) on delete restrict,project_id uuid,user_id uuid references auth.users(id),
 provider_config_id uuid not null references public.ai_provider_configs(id) on delete restrict,price_version_id uuid not null references public.ai_price_versions(id) on delete restrict,
 provider_event_id text not null check(length(btrim(provider_event_id))between 3 and 200),model_code text not null,meter_code text not null,quantity bigint not null check(quantity>=0),
 cost_minor bigint not null check(cost_minor>=0),currency char(3) not null check(currency~'^[A-Z]{3}$'),budget_id uuid references public.ai_budgets(id) on delete restrict,
 alert_level integer not null default 0 check(alert_level in(0,50,75,90,100)),request_hash text not null check(request_hash~'^[0-9a-f]{64}$'),correlation_id uuid not null,
 occurred_at timestamptz not null,recorded_at timestamptz not null default clock_timestamp(),
 unique(provider_config_id,provider_event_id)
);

create table public.ai_cost_allocations(
 id bigint generated always as identity primary key,organization_id uuid references public.organizations(id) on delete restrict,usage_event_id bigint not null references public.ai_usage_events(id) on delete restrict,
 allocation_scope text not null check(allocation_scope in('PLATFORM','ORGANIZATION','PROJECT','USER','BOX','BENEFIT')),allocation_reference text not null check(length(btrim(allocation_reference))between 1 and 200),
 amount_minor bigint not null check(amount_minor>=0),currency char(3) not null check(currency~'^[A-Z]{3}$'),rule_version text not null,created_at timestamptz not null default clock_timestamp(),
 unique(usage_event_id,allocation_scope,allocation_reference)
);

create table public.cost_allocation_rules(
 id uuid primary key default extensions.gen_random_uuid(),organization_id uuid references public.organizations(id) on delete restrict,
 rule_code text not null,version integer not null check(version>0),status text not null check(status in('DRAFT','ACTIVE','RETIRED')),
 cost_source text not null check(cost_source in('AI','PROVIDER','SIGNATURE','PAYMENT','INTERNAL','SUPPLIER')),allocation_basis text not null check(allocation_basis in('DIRECT','UNITS','REVENUE_BPS','EQUAL','CUSTOM')),
 rule_snapshot jsonb not null check(jsonb_typeof(rule_snapshot)='object'),effective_from timestamptz not null,effective_to timestamptz,content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(organization_id,rule_code,version),check(effective_to is null or effective_to>effective_from)
);

create table public.benefit_actual_costs(
 id bigint generated always as identity primary key,organization_id uuid not null references public.organizations(id) on delete restrict,redemption_id uuid not null references public.benefit_redemptions(id) on delete restrict,
 cost_type text not null check(cost_type in('PROVIDER','AI','SIGNATURE','PAYMENT','INTERNAL','SUPPLIER')),amount_minor bigint not null check(amount_minor>=0),currency char(3) not null check(currency~'^[A-Z]{3}$'),
 source_reference text not null check(length(btrim(source_reference))between 3 and 200),evidence_hash text not null check(evidence_hash~'^[0-9a-f]{64}$'),allocation_rule_id uuid references public.cost_allocation_rules(id) on delete restrict,
 idempotency_key text not null check(length(idempotency_key)between 8 and 200),correlation_id uuid not null,recorded_at timestamptz not null default clock_timestamp(),unique(organization_id,idempotency_key)
);

create table public.benefit_margin_snapshots(
 id bigint generated always as identity primary key,organization_id uuid not null references public.organizations(id) on delete restrict,redemption_id uuid not null references public.benefit_redemptions(id) on delete restrict,
 snapshot_type text not null check(snapshot_type in('FORECAST','ACTUAL')),revenue_minor bigint not null check(revenue_minor>=0),cost_minor bigint not null check(cost_minor>=0),margin_minor bigint generated always as(revenue_minor-cost_minor) stored,
 currency char(3) not null check(currency~'^[A-Z]{3}$'),rule_version text not null,correlation_id uuid not null,captured_at timestamptz not null default clock_timestamp(),unique(redemption_id,snapshot_type,captured_at)
);

create table public.treasury_budget_versions(
 id uuid primary key default extensions.gen_random_uuid(),budget_code text not null,version integer not null check(version>0),status text not null check(status in('DRAFT','ACTIVE','RETIRED')),
 period_start date not null,period_end date not null,currency char(3) not null check(currency~'^[A-Z]{3}$'),revenue_budget_minor bigint not null check(revenue_budget_minor>=0),expense_budget_minor bigint not null check(expense_budget_minor>=0),tax_reserve_minor bigint not null check(tax_reserve_minor>=0),
 assumptions jsonb not null check(jsonb_typeof(assumptions)='object'),content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),unique(budget_code,version),check(period_end>=period_start)
);

create table public.treasury_cashflow_snapshots(
 id bigint generated always as identity primary key,budget_version_id uuid not null references public.treasury_budget_versions(id) on delete restrict,as_of_date date not null,
 forecast_horizon_days integer not null check(forecast_horizon_days in(30,60,90)),opening_cash_minor bigint not null,expected_inflows_minor bigint not null check(expected_inflows_minor>=0),expected_outflows_minor bigint not null check(expected_outflows_minor>=0),tax_reserve_minor bigint not null check(tax_reserve_minor>=0),
 projected_cash_minor bigint generated always as(opening_cash_minor+expected_inflows_minor-expected_outflows_minor-tax_reserve_minor) stored,currency char(3) not null check(currency~'^[A-Z]{3}$'),
 source_cutoff timestamptz not null,source_hash text not null check(source_hash~'^[0-9a-f]{64}$'),correlation_id uuid not null,created_at timestamptz not null default clock_timestamp(),unique(budget_version_id,as_of_date,forecast_horizon_days)
);

create function public.record_ai_usage(p_organization_id uuid,p_project_id uuid,p_user_id uuid,p_provider_code text,p_provider_event_id text,p_meter_code text,p_quantity bigint,p_model_code text,p_request_hash text,p_allocation_reference text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare c public.ai_provider_configs%rowtype;pr public.ai_price_versions%rowtype;b public.ai_budgets%rowtype;existing public.ai_usage_events%rowtype;cost bigint;spent bigint;level integer:=0;eid bigint;result jsonb;
begin
 if p_quantity<0 or p_request_hash!~'^[0-9a-f]{64}$' or length(btrim(coalesce(p_allocation_reference,'')))<1 then raise exception'INVALID_AI_USAGE' using errcode='22023';end if;
 select*into c from public.ai_provider_configs where provider_code=p_provider_code and status='ACTIVE'and effective_from<=clock_timestamp()and(effective_to is null or effective_to>clock_timestamp()) order by version desc limit 1;
 if not found then raise exception'AI_PROVIDER_NOT_ACTIVE' using errcode='23514';end if;
 select*into existing from public.ai_usage_events where provider_config_id=c.id and provider_event_id=p_provider_event_id;
 if found then if existing.request_hash<>p_request_hash then raise exception'AI_USAGE_REPLAY_MISMATCH' using errcode='22000';end if;return jsonb_build_object('outcome','AI_USAGE_REPLAYED','usage_event_id',existing.id,'cost_minor',existing.cost_minor,'replayed',true);end if;
 select*into pr from public.ai_price_versions where provider_config_id=c.id and model_code=p_model_code and meter_code=p_meter_code and effective_from<=clock_timestamp()and(effective_to is null or effective_to>clock_timestamp()) order by version desc limit 1;
 if not found then raise exception'AI_PRICE_VERSION_REQUIRED' using errcode='23514';end if;
 cost:=ceil((p_quantity::numeric*pr.unit_cost_micro_minor::numeric)/(pr.unit_size::numeric*1000000::numeric))::bigint;
 select*into b from public.ai_budgets where status='ACTIVE'and period_start<=clock_timestamp()and period_end>clock_timestamp()and((scope_type='ORGANIZATION'and organization_id=p_organization_id)or(scope_type='PLATFORM'and p_organization_id is null)) order by case scope_type when'ORGANIZATION'then 1 else 2 end,version desc limit 1 for update;
 if found then select coalesce(sum(cost_minor),0)into spent from public.ai_usage_events where budget_id=b.id;if b.hard_stop_at_100 and spent+cost>b.limit_minor then raise exception'AI_BUDGET_EXHAUSTED' using errcode='23514';end if;if b.limit_minor=0 then level:=100;elsif(spent+cost)*100>=b.limit_minor*100 then level:=100;elsif(spent+cost)*100>=b.limit_minor*90 then level:=90;elsif(spent+cost)*100>=b.limit_minor*75 then level:=75;elsif(spent+cost)*100>=b.limit_minor*50 then level:=50;end if;end if;
 insert into public.ai_usage_events(organization_id,project_id,user_id,provider_config_id,price_version_id,provider_event_id,model_code,meter_code,quantity,cost_minor,currency,budget_id,alert_level,request_hash,correlation_id,occurred_at)values(p_organization_id,p_project_id,p_user_id,c.id,pr.id,p_provider_event_id,p_model_code,p_meter_code,p_quantity,cost,pr.currency,b.id,level,p_request_hash,p_correlation_id,clock_timestamp())returning id into eid;
 insert into public.ai_cost_allocations(organization_id,usage_event_id,allocation_scope,allocation_reference,amount_minor,currency,rule_version)values(p_organization_id,eid,case when p_project_id is not null then'PROJECT'when p_organization_id is not null then'ORGANIZATION'else'PLATFORM'end,p_allocation_reference,cost,pr.currency,'AI_PRICE:'||pr.version);
 result:=jsonb_build_object('outcome','AI_USAGE_RECORDED','usage_event_id',eid,'cost_minor',cost,'currency',pr.currency,'alert_level',level,'replayed',false);
 insert into public.audit_events(organization_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,'SERVICE','ai.usage_recorded','ai_usage_event',eid::text,p_correlation_id,jsonb_build_object('provider_code',p_provider_code,'model_code',p_model_code,'meter_code',p_meter_code,'quantity',p_quantity,'cost_minor',cost,'alert_level',level),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_organization_id,'ai_usage_event',eid::text,case when level>0 then'AiBudgetThresholdReachedV1'else'AiUsageRecordedV1'end,p_correlation_id,result,p_provider_event_id);
 return result;
end$$;

create function public.record_benefit_actual_cost(p_organization_id uuid,p_redemption_id uuid,p_cost_type text,p_amount_minor bigint,p_currency char(3),p_evidence_hash text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare x public.benefit_actual_costs%rowtype;result jsonb;
begin
 if p_amount_minor<0 or p_evidence_hash!~'^[0-9a-f]{64}$' then raise exception'INVALID_ACTUAL_COST' using errcode='22023';end if;
 select*into x from public.benefit_actual_costs where organization_id=p_organization_id and idempotency_key=p_idempotency_key;
 if found then if x.redemption_id<>p_redemption_id or x.cost_type<>p_cost_type or x.amount_minor<>p_amount_minor or x.currency<>p_currency or x.evidence_hash<>p_evidence_hash then raise exception'ACTUAL_COST_REPLAY_MISMATCH' using errcode='22000';end if;return jsonb_build_object('outcome','ACTUAL_COST_REPLAYED','actual_cost_id',x.id,'replayed',true);end if;
 perform 1 from public.benefit_redemptions where id=p_redemption_id and organization_id=p_organization_id;if not found then raise exception'REDEMPTION_SCOPE_MISMATCH' using errcode='23503';end if;
 insert into public.benefit_actual_costs(organization_id,redemption_id,cost_type,amount_minor,currency,source_reference,evidence_hash,idempotency_key,correlation_id)values(p_organization_id,p_redemption_id,p_cost_type,p_amount_minor,p_currency,'BENEFIT_REDEMPTION:'||p_redemption_id,p_evidence_hash,p_idempotency_key,p_correlation_id)returning*into x;
 result:=jsonb_build_object('outcome','ACTUAL_COST_RECORDED','actual_cost_id',x.id,'amount_minor',x.amount_minor,'currency',x.currency,'replayed',false);
 insert into public.audit_events(organization_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,'SERVICE','benefit.actual_cost_recorded','benefit_actual_cost',x.id::text,p_correlation_id,jsonb_build_object('cost_type',p_cost_type,'amount_minor',p_amount_minor),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_organization_id,'benefit_redemption',p_redemption_id::text,'BenefitActualCostRecordedV1',p_correlation_id,result,p_idempotency_key);
 return result;
end$$;

do $$declare t text;begin foreach t in array array['ai_provider_configs','ai_price_versions','ai_budgets','ai_usage_events','ai_cost_allocations','cost_allocation_rules','benefit_actual_costs','benefit_margin_snapshots','treasury_budget_versions','treasury_cashflow_snapshots']loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);end loop;end$$;
grant select on public.ai_provider_configs,public.ai_price_versions,public.ai_budgets,public.ai_usage_events,public.ai_cost_allocations,public.cost_allocation_rules,public.benefit_actual_costs,public.benefit_margin_snapshots,public.treasury_budget_versions,public.treasury_cashflow_snapshots to authenticated;

create policy ai_provider_configs_admin_read on public.ai_provider_configs for select to authenticated using(private.v41_finops_admin_access());
create policy ai_price_versions_admin_read on public.ai_price_versions for select to authenticated using(private.v41_finops_admin_access());
create policy ai_budgets_scoped_read on public.ai_budgets for select to authenticated using((organization_id is not null and private.v41_finops_tenant_access(organization_id))or private.v41_finops_admin_access());
create policy ai_usage_events_scoped_read on public.ai_usage_events for select to authenticated using((organization_id is not null and private.v41_finops_tenant_access(organization_id))or private.v41_finops_admin_access());
create policy ai_cost_allocations_scoped_read on public.ai_cost_allocations for select to authenticated using((organization_id is not null and private.v41_finops_tenant_access(organization_id))or private.v41_finops_admin_access());
create policy cost_allocation_rules_scoped_read on public.cost_allocation_rules for select to authenticated using((organization_id is not null and private.v41_finops_tenant_access(organization_id))or private.v41_finops_admin_access());
create policy benefit_actual_costs_scoped_read on public.benefit_actual_costs for select to authenticated using(private.v41_finops_tenant_access(organization_id));
create policy benefit_margin_snapshots_scoped_read on public.benefit_margin_snapshots for select to authenticated using(private.v41_finops_tenant_access(organization_id));
create policy treasury_budget_versions_admin_read on public.treasury_budget_versions for select to authenticated using(private.v41_finops_admin_access());
create policy treasury_cashflow_snapshots_admin_read on public.treasury_cashflow_snapshots for select to authenticated using(private.v41_finops_admin_access());

do $$declare t text;begin foreach t in array array['ai_provider_configs','ai_price_versions','ai_budgets','ai_usage_events','ai_cost_allocations','cost_allocation_rules','benefit_actual_costs','benefit_margin_snapshots','treasury_budget_versions','treasury_cashflow_snapshots']loop execute format('create trigger %I_immutable before update or delete on public.%I for each row execute function private.prevent_update_delete()',t,t);end loop;end$$;

create index ai_usage_events_scope_time_idx on public.ai_usage_events(organization_id,occurred_at desc,id desc);
create index ai_budgets_scope_period_idx on public.ai_budgets(organization_id,scope_type,scope_id,period_start,period_end) where status='ACTIVE';
create index benefit_actual_costs_redemption_idx on public.benefit_actual_costs(organization_id,redemption_id,recorded_at desc);
create index treasury_cashflow_horizon_idx on public.treasury_cashflow_snapshots(as_of_date desc,forecast_horizon_days);

revoke all on function private.v41_finops_admin_access(uuid),private.v41_finops_tenant_access(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function private.v41_finops_admin_access(uuid),private.v41_finops_tenant_access(uuid,uuid) to authenticated;
revoke all on function public.record_ai_usage(uuid,uuid,uuid,text,text,text,bigint,text,text,text,uuid),public.record_benefit_actual_cost(uuid,uuid,text,bigint,character,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.record_ai_usage(uuid,uuid,uuid,text,text,text,bigint,text,text,text,uuid),public.record_benefit_actual_cost(uuid,uuid,text,bigint,character,text,text,uuid) to service_role;
