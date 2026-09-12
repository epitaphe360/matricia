-- P11 incidents, contradictory procedure, mediation, immutable evidence and controlled reassignment.

create table public.dispute_cases (
  id uuid primary key default extensions.gen_random_uuid(),
  mission_id uuid not null references public.missions(id) on delete restrict,
  contract_id uuid not null references public.contracts(id) on delete restrict,
  contract_version_id uuid not null references public.contract_versions(id) on delete restrict,
  client_organization_id uuid not null references public.organizations(id) on delete restrict,
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  obligation_key text not null check(obligation_key~'^[A-Z][A-Z0-9_.-]{1,119}$'),
  description text not null check(length(btrim(description)) between 10 and 4000),
  urgency text not null check(urgency in('STANDARD','URGENT')),
  status text not null default 'WARNING_LEVEL_1' check(status in('WARNING_LEVEL_1','PROVIDER_RESPONDED','MEDIATION_REVIEW','DECIDED','APPEALED','CLOSED')),
  policy_snapshot jsonb not null check(jsonb_typeof(policy_snapshot)='object' and policy_snapshot?&array['version','content_hash','response_hours','urgent_response_hours','correction_business_days','review_business_days','appeal_hours'] and policy_snapshot->>'content_hash'~'^[0-9a-f]{64}$'),
  response_due_at timestamptz not null,
  review_due_at timestamptz,
  appeal_due_at timestamptz,
  opened_by uuid not null references auth.users(id),
  opened_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check(row_version>0),
  check(client_organization_id<>provider_organization_id),
  unique(id,client_organization_id),
  foreign key(contract_version_id,contract_id) references public.contract_versions(id,contract_id) on delete restrict
);

create table public.dispute_evidence (
  id uuid primary key default extensions.gen_random_uuid(),
  dispute_case_id uuid not null references public.dispute_cases(id) on delete restrict,
  submitted_by_user_id uuid not null references auth.users(id),
  submitted_by_organization_id uuid references public.organizations(id) on delete restrict,
  evidence_type text not null check(evidence_type in('DOCUMENT','IMAGE','URL','MESSAGE','DELIVERY_PROOF','OTHER')),
  storage_path text,
  url text,
  statement text,
  evidence_hash text not null check(evidence_hash~'^[0-9a-f]{64}$'),
  visibility text not null check(visibility in('BOTH_PARTIES','CLIENT_ONLY','PROVIDER_ONLY','MEDIATOR_ONLY')),
  metadata jsonb not null default '{}' check(jsonb_typeof(metadata)='object'),
  created_at timestamptz not null default clock_timestamp(),
  check(num_nonnulls(storage_path,url,statement)>=1)
);

create table public.dispute_responses (
  id uuid primary key default extensions.gen_random_uuid(),
  dispute_case_id uuid not null references public.dispute_cases(id) on delete restrict,
  response_type text not null check(response_type in('ACKNOWLEDGE_AND_CORRECT','CONTEST','OUT_OF_SCOPE')),
  statement text not null check(length(btrim(statement)) between 10 and 4000),
  submitted_by uuid not null references auth.users(id),
  submitted_at timestamptz not null default clock_timestamp(),
  unique(dispute_case_id)
);

create table public.dispute_decisions (
  id uuid primary key default extensions.gen_random_uuid(),
  dispute_case_id uuid not null references public.dispute_cases(id) on delete restrict,
  decision_number integer not null check(decision_number>0),
  outcome text not null check(outcome in('COMPLIANT','MINOR_CORRECTION','OUT_OF_SCOPE','CLIENT_ABUSE','MUTUAL_AGREEMENT','NON_COMPLIANT_CONFIRMED')),
  reason text not null check(length(btrim(reason)) between 10 and 4000),
  evidence_ids uuid[] not null check(cardinality(evidence_ids)>0),
  rule_snapshot jsonb not null check(jsonb_typeof(rule_snapshot)='object' and rule_snapshot?&array['version','content_hash'] and rule_snapshot->>'content_hash'~'^[0-9a-f]{64}$'),
  supersedes_decision_id uuid references public.dispute_decisions(id) on delete restrict,
  decided_by uuid not null references auth.users(id),
  decided_at timestamptz not null default clock_timestamp(),
  unique(dispute_case_id,decision_number)
);

create table public.dispute_financial_consequences (
  id uuid primary key default extensions.gen_random_uuid(),
  dispute_case_id uuid not null references public.dispute_cases(id) on delete restrict,
  decision_id uuid not null references public.dispute_decisions(id) on delete restrict,
  consequence_type text not null check(consequence_type in('CONTRACTUAL_PENALTY','MATRICIA_COMMISSION')),
  direction text not null check(direction in('ACCRUAL','REVERSAL')),
  amount_minor bigint not null check(amount_minor>0),
  currency char(3) not null check(currency~'^[A-Z]{3}$'),
  payable_organization_id uuid not null references public.organizations(id) on delete restrict,
  beneficiary_organization_id uuid references public.organizations(id) on delete restrict,
  rule_snapshot jsonb not null check(jsonb_typeof(rule_snapshot)='object'),
  reverses_consequence_id uuid references public.dispute_financial_consequences(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  unique(dispute_case_id,consequence_type,direction),
  check((direction='ACCRUAL' and reverses_consequence_id is null)or(direction='REVERSAL' and reverses_consequence_id is not null))
);

create table public.provider_performance_events (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  mission_id uuid not null references public.missions(id) on delete restrict,
  dispute_case_id uuid not null references public.dispute_cases(id) on delete restrict,
  event_type text not null check(event_type in('NON_COMPLIANCE_CONFIRMED','NON_COMPLIANCE_REVERSED')),
  rule_snapshot jsonb not null check(jsonb_typeof(rule_snapshot)='object'),
  created_at timestamptz not null default clock_timestamp(),
  unique(dispute_case_id,event_type)
);

create table public.mission_reassignments (
  id uuid primary key default extensions.gen_random_uuid(),
  root_mission_id uuid not null references public.missions(id) on delete restrict,
  source_mission_id uuid not null references public.missions(id) on delete restrict,
  dispute_case_id uuid not null unique references public.dispute_cases(id) on delete restrict,
  reassignment_number integer not null check(reassignment_number>0),
  reassignment_key text generated always as('R'||reassignment_number::text) stored,
  status text not null default 'OPEN' check(status in('OPEN','PROPOSED','AWAITING_CLIENT_APPROVAL','APPROVED','CONTRACT_PENDING','ACTIVATED','CANCELLED')),
  proposed_provider_organization_id uuid references public.organizations(id) on delete restrict,
  pricing_mode text check(pricing_mode in('FRAMEWORK_RATE','NEW_QUOTE')),
  proposed_quote_version_id uuid references public.quote_versions(id) on delete restrict,
  original_cost_minor bigint not null check(original_cost_minor>=0),
  proposed_cost_minor bigint check(proposed_cost_minor>=0),
  cost_delta_minor bigint,
  currency char(3) not null check(currency~'^[A-Z]{3}$'),
  client_cost_approved_by uuid references auth.users(id),
  client_cost_approved_at timestamptz,
  replacement_contract_id uuid references public.contracts(id) on delete restrict,
  replacement_mission_id uuid unique references public.missions(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check(row_version>0),
  unique(root_mission_id,reassignment_number),
  check(cost_delta_minor is null or cost_delta_minor=proposed_cost_minor-original_cost_minor)
);

create table public.dispute_appeals (
  id uuid primary key default extensions.gen_random_uuid(),
  dispute_case_id uuid not null unique references public.dispute_cases(id) on delete restrict,
  appealed_decision_id uuid not null references public.dispute_decisions(id) on delete restrict,
  grounds text not null check(length(btrim(grounds)) between 10 and 4000),
  submitted_by uuid not null references auth.users(id),
  submitted_at timestamptz not null default clock_timestamp()
);

create table public.dispute_case_events (
  id bigint generated always as identity primary key,
  dispute_case_id uuid not null references public.dispute_cases(id) on delete restrict,
  event_type text not null,
  from_status text,
  to_status text not null,
  actor_user_id uuid not null references auth.users(id),
  correlation_id uuid not null,
  metadata jsonb not null default '{}' check(jsonb_typeof(metadata)='object'),
  created_at timestamptz not null default clock_timestamp()
);

create function private.dispute_case_access(p_case_id uuid,p_actor uuid default auth.uid()) returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
 select exists(select 1 from public.dispute_cases d where d.id=p_case_id and(private.is_active_org_member(d.client_organization_id,p_actor)or private.is_active_org_member(d.provider_organization_id,p_actor)))or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','DISPUTE_MANAGER','READ_ONLY_AUDITOR'],p_actor)
$$;
create function private.dispute_evidence_access(p_evidence_id uuid,p_actor uuid default auth.uid()) returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
 select exists(select 1 from public.dispute_evidence e join public.dispute_cases d on d.id=e.dispute_case_id where e.id=p_evidence_id and(private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','DISPUTE_MANAGER','READ_ONLY_AUDITOR'],p_actor)or(e.visibility='BOTH_PARTIES'and(private.is_active_org_member(d.client_organization_id,p_actor)or private.is_active_org_member(d.provider_organization_id,p_actor)))or(e.visibility='CLIENT_ONLY'and private.is_active_org_member(d.client_organization_id,p_actor))or(e.visibility='PROVIDER_ONLY'and private.is_active_org_member(d.provider_organization_id,p_actor))))
$$;
create function private.dispute_financial_access(p_case_id uuid,p_actor uuid default auth.uid()) returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
 select exists(select 1 from public.dispute_cases d where d.id=p_case_id and(private.has_org_role(d.client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_ACCOUNTING'],p_actor)or private.has_org_role(d.provider_organization_id,array['PROVIDER_OWNER','PROVIDER_ACCOUNTING'],p_actor)))or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','DISPUTE_MANAGER','FINANCE_MANAGER','READ_ONLY_AUDITOR'],p_actor)
$$;
create function private.dispute_reassignment_access(p_case_id uuid,p_actor uuid default auth.uid()) returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
 select exists(select 1 from public.dispute_cases d where d.id=p_case_id and private.has_org_role(d.client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],p_actor))or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','DISPUTE_MANAGER','READ_ONLY_AUDITOR'],p_actor)
$$;
create function private.prevent_dispute_immutable_change() returns trigger language plpgsql set search_path=pg_catalog as $$begin raise exception 'IMMUTABLE_DISPUTE_RECORD' using errcode='55000';end$$;

create function private.append_dispute_evidence(p_case_id uuid,p_items jsonb,p_actor uuid,p_actor_org uuid) returns integer language plpgsql security definer set search_path=pg_catalog,public as $$
declare x jsonb;n integer:=0;begin
 if jsonb_typeof(p_items)<>'array'then raise exception 'INVALID_EVIDENCE' using errcode='22023';end if;
 for x in select * from jsonb_array_elements(p_items)loop
  if coalesce(x->>'type','')not in('DOCUMENT','IMAGE','URL','MESSAGE','DELIVERY_PROOF','OTHER')or coalesce(x->>'hash','')!~'^[0-9a-f]{64}$'or coalesce(x->>'visibility','')not in('BOTH_PARTIES','CLIENT_ONLY','PROVIDER_ONLY','MEDIATOR_ONLY')or num_nonnulls(nullif(x->>'storage_path',''),nullif(x->>'url',''),nullif(x->>'statement',''))<1 then raise exception 'INVALID_EVIDENCE' using errcode='22023';end if;
  insert into public.dispute_evidence(dispute_case_id,submitted_by_user_id,submitted_by_organization_id,evidence_type,storage_path,url,statement,evidence_hash,visibility,metadata)values(p_case_id,p_actor,p_actor_org,x->>'type',nullif(x->>'storage_path',''),nullif(x->>'url',''),nullif(x->>'statement',''),x->>'hash',x->>'visibility',coalesce(x->'metadata','{}'));
  n:=n+1;
 end loop;return n;
end$$;

create function public.open_mission_dispute(p_mission_id uuid,p_obligation_key text,p_description text,p_urgency text,p_policy_snapshot jsonb,p_evidence jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();m public.missions%rowtype;c public.contracts%rowtype;h text;r jsonb;d uuid;hours integer;begin
 select * into m from public.missions where id=p_mission_id;select * into c from public.contracts where id=m.contract_id;
 if a is null or not found or not private.has_org_role(m.client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a)then raise exception 'DISPUTE_OPEN_DENIED' using errcode='42501';end if;
 if m.status not in('ACTIVE','DELIVERY_SUBMITTED','ACCEPTANCE_IN_PROGRESS')or coalesce(p_obligation_key,'')!~'^[A-Z][A-Z0-9_.-]{1,119}$'or length(btrim(coalesce(p_description,'')))not between 10 and 4000 or p_urgency not in('STANDARD','URGENT')or jsonb_typeof(p_evidence)<>'array'or jsonb_array_length(p_evidence)=0 or jsonb_typeof(p_policy_snapshot)<>'object'or not(p_policy_snapshot?&array['version','content_hash','response_hours','urgent_response_hours','correction_business_days','review_business_days','appeal_hours'])or p_policy_snapshot->>'content_hash'!~'^[0-9a-f]{64}$'then raise exception 'INVALID_DISPUTE' using errcode='22023';end if;
 hours:=case when p_urgency='URGENT'then(p_policy_snapshot->>'urgent_response_hours')::integer else(p_policy_snapshot->>'response_hours')::integer end;if hours<=0 or(p_policy_snapshot->>'review_business_days')::integer<=0 or(p_policy_snapshot->>'appeal_hours')::integer<=0 then raise exception 'INVALID_DISPUTE_POLICY' using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('mission',p_mission_id,'obligation',p_obligation_key,'description',p_description,'urgency',p_urgency,'policy',p_policy_snapshot,'evidence',p_evidence));r:=private.begin_contract_command(m.client_organization_id,'dispute.open.'||m.id::text,p_idempotency_key,h,a);if r is not null then return r;end if;
 insert into public.dispute_cases(mission_id,contract_id,contract_version_id,client_organization_id,provider_organization_id,obligation_key,description,urgency,policy_snapshot,response_due_at,opened_by)values(m.id,m.contract_id,m.contract_version_id,m.client_organization_id,m.provider_organization_id,p_obligation_key,p_description,p_urgency,p_policy_snapshot,clock_timestamp()+make_interval(hours=>hours),a)returning id into d;
 perform private.append_dispute_evidence(d,p_evidence,a,m.client_organization_id);insert into public.dispute_case_events(dispute_case_id,event_type,to_status,actor_user_id,correlation_id,metadata)values(d,'DISPUTE_OPENED','WARNING_LEVEL_1',a,p_correlation_id,jsonb_build_object('obligation_key',p_obligation_key));
 r:=jsonb_build_object('outcome','WARNING_LEVEL_1','dispute_case_id',d,'response_due_at',(select response_due_at from public.dispute_cases where id=d));insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(m.client_organization_id,a,'USER','dispute.opened','dispute_case',d::text,p_correlation_id,jsonb_build_object('mission_id',m.id,'provider_organization_id',m.provider_organization_id),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(m.client_organization_id,'dispute_case',d::text,'DisputeWarningIssuedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(m.client_organization_id,'dispute.open.'||m.id::text,p_idempotency_key,r);return r;
end$$;

create function public.respond_to_mission_dispute(p_dispute_case_id uuid,p_response_type text,p_statement text,p_evidence jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();d public.dispute_cases%rowtype;h text;r jsonb;begin select * into d from public.dispute_cases where id=p_dispute_case_id;if a is null or not found or not private.has_org_role(d.provider_organization_id,array['PROVIDER_OWNER','PROVIDER_MANAGER'],a)then raise exception 'DISPUTE_RESPONSE_DENIED' using errcode='42501';end if;if d.status<>'WARNING_LEVEL_1'or p_response_type not in('ACKNOWLEDGE_AND_CORRECT','CONTEST','OUT_OF_SCOPE')or length(btrim(coalesce(p_statement,'')))not between 10 and 4000 or jsonb_typeof(p_evidence)<>'array'then raise exception 'INVALID_DISPUTE_RESPONSE' using errcode='22023';end if;h:=private.canonical_request_hash(jsonb_build_object('case',d.id,'type',p_response_type,'statement',p_statement,'evidence',p_evidence));r:=private.begin_contract_command(d.client_organization_id,'dispute.respond.'||d.id::text,p_idempotency_key,h,a);if r is not null then return r;end if;select * into d from public.dispute_cases where id=d.id for update;if d.status<>'WARNING_LEVEL_1'then raise exception 'STALE_DISPUTE_STATE' using errcode='40001';end if;insert into public.dispute_responses(dispute_case_id,response_type,statement,submitted_by)values(d.id,p_response_type,p_statement,a);perform private.append_dispute_evidence(d.id,p_evidence,a,d.provider_organization_id);update public.dispute_cases set status='MEDIATION_REVIEW',review_due_at=clock_timestamp()+make_interval(days=>(policy_snapshot->>'review_business_days')::integer),row_version=row_version+1 where id=d.id;insert into public.dispute_case_events(dispute_case_id,event_type,from_status,to_status,actor_user_id,correlation_id,metadata)values(d.id,'PROVIDER_RESPONSE','WARNING_LEVEL_1','MEDIATION_REVIEW',a,p_correlation_id,jsonb_build_object('response_type',p_response_type));r:=jsonb_build_object('outcome','MEDIATION_REVIEW','dispute_case_id',d.id);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(d.client_organization_id,a,'USER','dispute.responded','dispute_case',d.id::text,p_correlation_id,jsonb_build_object('response_type',p_response_type),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(d.client_organization_id,'dispute_case',d.id::text,'DisputeResponseSubmittedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(d.client_organization_id,'dispute.respond.'||d.id::text,p_idempotency_key,r);return r;end$$;

create function public.decide_mission_dispute(p_dispute_case_id uuid,p_outcome text,p_reason text,p_evidence_ids uuid[],p_rule_snapshot jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();d public.dispute_cases%rowtype;m public.missions%rowtype;v public.contract_versions%rowtype;h text;r jsonb;dec uuid;n integer;rn integer;prior public.dispute_decisions%rowtype;pen bigint;com bigint;cur text;ra uuid;begin
 select * into d from public.dispute_cases where id=p_dispute_case_id;if a is null or not found or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','DISPUTE_MANAGER'],a)then raise exception 'DISPUTE_DECISION_DENIED' using errcode='42501';end if;if not(d.status in('MEDIATION_REVIEW','APPEALED')or(d.status='WARNING_LEVEL_1'and clock_timestamp()>d.response_due_at))or p_outcome not in('COMPLIANT','MINOR_CORRECTION','OUT_OF_SCOPE','CLIENT_ABUSE','MUTUAL_AGREEMENT','NON_COMPLIANT_CONFIRMED')or length(btrim(coalesce(p_reason,'')))not between 10 and 4000 or coalesce(cardinality(p_evidence_ids),0)=0 or jsonb_typeof(p_rule_snapshot)<>'object'or not(p_rule_snapshot?&array['version','content_hash'])or p_rule_snapshot->>'content_hash'!~'^[0-9a-f]{64}$'or exists(select 1 from unnest(p_evidence_ids)e where not exists(select 1 from public.dispute_evidence de where de.id=e and de.dispute_case_id=d.id))then raise exception 'INVALID_DISPUTE_DECISION' using errcode='22023';end if;
 if p_outcome='NON_COMPLIANT_CONFIRMED'then if not(p_rule_snapshot?&array['currency','penalty_minor','commission_minor','validated_clause'])or p_rule_snapshot->>'currency'!~'^[A-Z]{3}$'or coalesce((p_rule_snapshot->>'penalty_minor')::bigint,0)<=0 or coalesce((p_rule_snapshot->>'commission_minor')::bigint,0)<=0 or coalesce((p_rule_snapshot->>'validated_clause')::boolean,false)is not true then raise exception 'VALIDATED_CONTRACT_RULE_REQUIRED' using errcode='22023';end if;end if;
 h:=private.canonical_request_hash(jsonb_build_object('case',d.id,'outcome',p_outcome,'reason',p_reason,'evidence_ids',to_jsonb(p_evidence_ids),'rule',p_rule_snapshot));r:=private.begin_contract_command(d.client_organization_id,'dispute.decide.'||d.id::text,p_idempotency_key,h,a);if r is not null then return r;end if;select * into d from public.dispute_cases where id=d.id for update;if not(d.status in('MEDIATION_REVIEW','APPEALED')or(d.status='WARNING_LEVEL_1'and clock_timestamp()>d.response_due_at))then raise exception 'STALE_DISPUTE_STATE' using errcode='40001';end if;select * into prior from public.dispute_decisions where dispute_case_id=d.id order by decision_number desc limit 1;n:=coalesce(prior.decision_number,0)+1;insert into public.dispute_decisions(dispute_case_id,decision_number,outcome,reason,evidence_ids,rule_snapshot,supersedes_decision_id,decided_by)values(d.id,n,p_outcome,p_reason,p_evidence_ids,p_rule_snapshot,prior.id,a)returning id into dec;
 if p_outcome='NON_COMPLIANT_CONFIRMED'and prior.id is null then pen:=(p_rule_snapshot->>'penalty_minor')::bigint;com:=(p_rule_snapshot->>'commission_minor')::bigint;cur:=p_rule_snapshot->>'currency';insert into public.dispute_financial_consequences(dispute_case_id,decision_id,consequence_type,direction,amount_minor,currency,payable_organization_id,beneficiary_organization_id,rule_snapshot)values(d.id,dec,'CONTRACTUAL_PENALTY','ACCRUAL',pen,cur,d.provider_organization_id,d.client_organization_id,p_rule_snapshot),(d.id,dec,'MATRICIA_COMMISSION','ACCRUAL',com,cur,d.provider_organization_id,null,p_rule_snapshot);select * into m from public.missions where id=d.mission_id for update;select * into v from public.contract_versions where id=d.contract_version_id;update public.missions set status='CANCELLED',row_version=row_version+1,updated_at=now()where id=m.id and status<>'CANCELLED';insert into public.provider_performance_events(provider_organization_id,mission_id,dispute_case_id,event_type,rule_snapshot)values(d.provider_organization_id,d.mission_id,d.id,'NON_COMPLIANCE_CONFIRMED',p_rule_snapshot);select coalesce(max(mr.reassignment_number),0)+1 into rn from public.mission_reassignments mr where mr.root_mission_id=d.mission_id;insert into public.mission_reassignments(root_mission_id,source_mission_id,dispute_case_id,reassignment_number,original_cost_minor,currency)values(d.mission_id,d.mission_id,d.id,rn,v.price_minor,v.currency)returning id into ra;
 elsif prior.outcome='NON_COMPLIANT_CONFIRMED'and p_outcome<>'NON_COMPLIANT_CONFIRMED'then insert into public.dispute_financial_consequences(dispute_case_id,decision_id,consequence_type,direction,amount_minor,currency,payable_organization_id,beneficiary_organization_id,rule_snapshot,reverses_consequence_id)select d.id,dec,x.consequence_type,'REVERSAL',x.amount_minor,x.currency,x.payable_organization_id,x.beneficiary_organization_id,p_rule_snapshot,x.id from public.dispute_financial_consequences x where x.dispute_case_id=d.id and x.direction='ACCRUAL';insert into public.provider_performance_events(provider_organization_id,mission_id,dispute_case_id,event_type,rule_snapshot)values(d.provider_organization_id,d.mission_id,d.id,'NON_COMPLIANCE_REVERSED',p_rule_snapshot);update public.mission_reassignments set status='CANCELLED',updated_at=clock_timestamp(),row_version=row_version+1 where dispute_case_id=d.id and status<>'ACTIVATED';update public.missions set status='ACTIVE',row_version=row_version+1,updated_at=now()where id=d.mission_id and status='CANCELLED'and not exists(select 1 from public.mission_reassignments where dispute_case_id=d.id and status='ACTIVATED');end if;
 update public.dispute_cases set status=case when d.status='APPEALED'then'CLOSED'else'DECIDED'end,appeal_due_at=case when d.status='APPEALED'then appeal_due_at else clock_timestamp()+make_interval(hours=>(policy_snapshot->>'appeal_hours')::integer)end,row_version=row_version+1 where id=d.id;insert into public.dispute_case_events(dispute_case_id,event_type,from_status,to_status,actor_user_id,correlation_id,metadata)values(d.id,'HUMAN_DECISION',d.status,case when d.status='APPEALED'then'CLOSED'else'DECIDED'end,a,p_correlation_id,jsonb_build_object('decision_id',dec,'outcome',p_outcome,'decision_number',n));r:=jsonb_build_object('outcome',p_outcome,'dispute_case_id',d.id,'decision_id',dec,'decision_number',n,'reassignment_id',ra);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(d.client_organization_id,a,'USER','dispute.decided','dispute_case',d.id::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(d.client_organization_id,'dispute_case',d.id::text,case when p_outcome='NON_COMPLIANT_CONFIRMED'then'DisputeNonComplianceConfirmedV1'else'DisputeDecisionRecordedV1'end,p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(d.client_organization_id,'dispute.decide.'||d.id::text,p_idempotency_key,r);return r;end$$;

create function public.appeal_mission_dispute(p_dispute_case_id uuid,p_grounds text,p_evidence jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();d public.dispute_cases%rowtype;dec uuid;org uuid;h text;r jsonb;begin select * into d from public.dispute_cases where id=p_dispute_case_id;if a is null or not found or not(private.is_active_org_member(d.client_organization_id,a)or private.is_active_org_member(d.provider_organization_id,a))then raise exception 'DISPUTE_APPEAL_DENIED' using errcode='42501';end if;if d.status<>'DECIDED'or clock_timestamp()>d.appeal_due_at or length(btrim(coalesce(p_grounds,'')))not between 10 and 4000 or jsonb_typeof(p_evidence)<>'array'then raise exception 'INVALID_DISPUTE_APPEAL' using errcode='22023';end if;org:=case when private.is_active_org_member(d.client_organization_id,a)then d.client_organization_id else d.provider_organization_id end;h:=private.canonical_request_hash(jsonb_build_object('case',d.id,'grounds',p_grounds,'evidence',p_evidence));r:=private.begin_contract_command(d.client_organization_id,'dispute.appeal.'||d.id::text,p_idempotency_key,h,a);if r is not null then return r;end if;select id into dec from public.dispute_decisions where dispute_case_id=d.id order by decision_number desc limit 1;insert into public.dispute_appeals(dispute_case_id,appealed_decision_id,grounds,submitted_by)values(d.id,dec,p_grounds,a);perform private.append_dispute_evidence(d.id,p_evidence,a,org);update public.dispute_cases set status='APPEALED',row_version=row_version+1 where id=d.id and status='DECIDED';if not found then raise exception 'STALE_DISPUTE_STATE' using errcode='40001';end if;insert into public.dispute_case_events(dispute_case_id,event_type,from_status,to_status,actor_user_id,correlation_id)values(d.id,'APPEAL_SUBMITTED','DECIDED','APPEALED',a,p_correlation_id);r:=jsonb_build_object('outcome','APPEALED','dispute_case_id',d.id,'appealed_decision_id',dec);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(d.client_organization_id,a,'USER','dispute.appealed','dispute_case',d.id::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(d.client_organization_id,'dispute_case',d.id::text,'DisputeAppealedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(d.client_organization_id,'dispute.appeal.'||d.id::text,p_idempotency_key,r);return r;end$$;

create function public.propose_mission_reassignment(p_reassignment_id uuid,p_provider_organization_id uuid,p_pricing_mode text,p_quote_version_id uuid,p_proposed_cost_minor bigint,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();x public.mission_reassignments%rowtype;d public.dispute_cases%rowtype;h text;r jsonb;delta bigint;begin select * into x from public.mission_reassignments where id=p_reassignment_id;select * into d from public.dispute_cases where id=x.dispute_case_id;if a is null or not found or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','DISPUTE_MANAGER'],a)then raise exception 'REASSIGNMENT_PROPOSE_DENIED' using errcode='42501';end if;if x.status<>'OPEN'or x.row_version<>p_expected_row_version or p_provider_organization_id in(d.client_organization_id,d.provider_organization_id)or p_pricing_mode not in('FRAMEWORK_RATE','NEW_QUOTE')or p_proposed_cost_minor<0 or(p_pricing_mode='NEW_QUOTE'and p_quote_version_id is null)then raise exception 'INVALID_REASSIGNMENT_PROPOSAL' using errcode='22023';end if;delta:=p_proposed_cost_minor-x.original_cost_minor;h:=private.canonical_request_hash(jsonb_build_object('reassignment',x.id,'provider',p_provider_organization_id,'mode',p_pricing_mode,'quote',p_quote_version_id,'cost',p_proposed_cost_minor,'expected',p_expected_row_version));r:=private.begin_contract_command(d.client_organization_id,'reassignment.propose.'||x.id::text,p_idempotency_key,h,a);if r is not null then return r;end if;update public.mission_reassignments set proposed_provider_organization_id=p_provider_organization_id,pricing_mode=p_pricing_mode,proposed_quote_version_id=p_quote_version_id,proposed_cost_minor=p_proposed_cost_minor,cost_delta_minor=delta,status=case when delta>0 then'AWAITING_CLIENT_APPROVAL'else'APPROVED'end,updated_at=clock_timestamp(),row_version=row_version+1 where id=x.id and row_version=p_expected_row_version;if not found then raise exception 'STALE_REASSIGNMENT' using errcode='40001';end if;r:=jsonb_build_object('outcome',case when delta>0 then'CLIENT_APPROVAL_REQUIRED'else'REASSIGNMENT_APPROVED'end,'reassignment_id',x.id,'cost_delta_minor',delta);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(d.client_organization_id,a,'USER','reassignment.proposed','mission_reassignment',x.id::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(d.client_organization_id,'mission_reassignment',x.id::text,case when delta>0 then'ReassignmentClientApprovalRequiredV1'else'ReassignmentApprovedV1'end,p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(d.client_organization_id,'reassignment.propose.'||x.id::text,p_idempotency_key,r);return r;end$$;

create function public.approve_reassignment_cost(p_reassignment_id uuid,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();x public.mission_reassignments%rowtype;d public.dispute_cases%rowtype;h text;r jsonb;begin select * into x from public.mission_reassignments where id=p_reassignment_id;select * into d from public.dispute_cases where id=x.dispute_case_id;if a is null or not found or not private.has_org_role(d.client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a)then raise exception 'REASSIGNMENT_APPROVAL_DENIED' using errcode='42501';end if;if x.status<>'AWAITING_CLIENT_APPROVAL'or x.row_version<>p_expected_row_version or coalesce(x.cost_delta_minor,0)<=0 then raise exception 'INVALID_REASSIGNMENT_APPROVAL' using errcode='22023';end if;h:=private.canonical_request_hash(jsonb_build_object('reassignment',x.id,'expected',p_expected_row_version));r:=private.begin_contract_command(d.client_organization_id,'reassignment.approve.'||x.id::text,p_idempotency_key,h,a);if r is not null then return r;end if;update public.mission_reassignments set status='APPROVED',client_cost_approved_by=a,client_cost_approved_at=clock_timestamp(),updated_at=clock_timestamp(),row_version=row_version+1 where id=x.id and row_version=p_expected_row_version;if not found then raise exception 'STALE_REASSIGNMENT' using errcode='40001';end if;r:=jsonb_build_object('outcome','REASSIGNMENT_APPROVED','reassignment_id',x.id,'cost_delta_minor',x.cost_delta_minor);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(d.client_organization_id,a,'USER','reassignment.cost_approved','mission_reassignment',x.id::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(d.client_organization_id,'mission_reassignment',x.id::text,'ReassignmentCostApprovedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(d.client_organization_id,'reassignment.approve.'||x.id::text,p_idempotency_key,r);return r;end$$;

create function public.activate_mission_reassignment(p_reassignment_id uuid,p_replacement_contract_id uuid,p_replacement_mission_id uuid,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();x public.mission_reassignments%rowtype;d public.dispute_cases%rowtype;c public.contracts%rowtype;m public.missions%rowtype;h text;r jsonb;begin select * into x from public.mission_reassignments where id=p_reassignment_id;select * into d from public.dispute_cases where id=x.dispute_case_id;if a is null or not found or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','DISPUTE_MANAGER'],a)then raise exception 'REASSIGNMENT_ACTIVATE_DENIED' using errcode='42501';end if;select * into c from public.contracts where id=p_replacement_contract_id;select * into m from public.missions where id=p_replacement_mission_id;if c.id is null or m.id is null or x.status<>'APPROVED'or x.row_version<>p_expected_row_version or d.status='APPEALED'or(d.status='DECIDED'and clock_timestamp()<=d.appeal_due_at)or c.status not in('ACTIVE','AMENDED')or m.contract_id<>c.id or m.client_organization_id<>d.client_organization_id or m.provider_organization_id<>x.proposed_provider_organization_id then raise exception 'INVALID_REASSIGNMENT_ACTIVATION' using errcode='22023';end if;h:=private.canonical_request_hash(jsonb_build_object('reassignment',x.id,'contract',c.id,'mission',m.id,'expected',p_expected_row_version));r:=private.begin_contract_command(d.client_organization_id,'reassignment.activate.'||x.id::text,p_idempotency_key,h,a);if r is not null then return r;end if;update public.mission_reassignments set status='ACTIVATED',replacement_contract_id=c.id,replacement_mission_id=m.id,updated_at=clock_timestamp(),row_version=row_version+1 where id=x.id and row_version=p_expected_row_version;if not found then raise exception 'STALE_REASSIGNMENT' using errcode='40001';end if;r:=jsonb_build_object('outcome','REASSIGNMENT_ACTIVATED','reassignment_id',x.id,'reassignment_key',x.reassignment_key,'replacement_mission_id',m.id);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(d.client_organization_id,a,'USER','reassignment.activated','mission_reassignment',x.id::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(d.client_organization_id,'mission_reassignment',x.id::text,'MissionReassignedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(d.client_organization_id,'reassignment.activate.'||x.id::text,p_idempotency_key,r);return r;end$$;

create trigger dispute_evidence_immutable before update or delete on public.dispute_evidence for each row execute function private.prevent_dispute_immutable_change();
create trigger dispute_responses_immutable before update or delete on public.dispute_responses for each row execute function private.prevent_dispute_immutable_change();
create trigger dispute_decisions_immutable before update or delete on public.dispute_decisions for each row execute function private.prevent_dispute_immutable_change();
create trigger dispute_consequences_immutable before update or delete on public.dispute_financial_consequences for each row execute function private.prevent_dispute_immutable_change();
create trigger provider_performance_events_immutable before update or delete on public.provider_performance_events for each row execute function private.prevent_dispute_immutable_change();
create trigger dispute_appeals_immutable before update or delete on public.dispute_appeals for each row execute function private.prevent_dispute_immutable_change();
create trigger dispute_case_events_immutable before update or delete on public.dispute_case_events for each row execute function private.prevent_dispute_immutable_change();

alter table public.dispute_cases enable row level security;alter table public.dispute_evidence enable row level security;alter table public.dispute_responses enable row level security;alter table public.dispute_decisions enable row level security;alter table public.dispute_financial_consequences enable row level security;alter table public.provider_performance_events enable row level security;alter table public.mission_reassignments enable row level security;alter table public.dispute_appeals enable row level security;alter table public.dispute_case_events enable row level security;
create policy dispute_cases_scoped_read on public.dispute_cases for select to authenticated using(private.dispute_case_access(id));
create policy dispute_evidence_scoped_read on public.dispute_evidence for select to authenticated using(private.dispute_evidence_access(id));
create policy dispute_responses_scoped_read on public.dispute_responses for select to authenticated using(private.dispute_case_access(dispute_case_id));
create policy dispute_decisions_scoped_read on public.dispute_decisions for select to authenticated using(private.dispute_case_access(dispute_case_id));
create policy dispute_consequences_scoped_read on public.dispute_financial_consequences for select to authenticated using(private.dispute_financial_access(dispute_case_id));
create policy provider_performance_scoped_read on public.provider_performance_events for select to authenticated using(private.dispute_financial_access(dispute_case_id));
create policy mission_reassignments_scoped_read on public.mission_reassignments for select to authenticated using(private.dispute_reassignment_access(dispute_case_id));
create policy dispute_appeals_scoped_read on public.dispute_appeals for select to authenticated using(private.dispute_case_access(dispute_case_id));
create policy dispute_events_scoped_read on public.dispute_case_events for select to authenticated using(private.dispute_case_access(dispute_case_id));

revoke all on public.dispute_cases,public.dispute_evidence,public.dispute_responses,public.dispute_decisions,public.dispute_financial_consequences,public.provider_performance_events,public.mission_reassignments,public.dispute_appeals,public.dispute_case_events from public,anon,authenticated;
grant select on public.dispute_cases,public.dispute_evidence,public.dispute_responses,public.dispute_decisions,public.dispute_financial_consequences,public.provider_performance_events,public.mission_reassignments,public.dispute_appeals,public.dispute_case_events to authenticated;
revoke all on function private.dispute_case_access(uuid,uuid),private.dispute_evidence_access(uuid,uuid),private.dispute_financial_access(uuid,uuid),private.dispute_reassignment_access(uuid,uuid),private.append_dispute_evidence(uuid,jsonb,uuid,uuid),private.prevent_dispute_immutable_change()from public,anon,authenticated,service_role;
grant execute on function private.dispute_case_access(uuid,uuid),private.dispute_evidence_access(uuid,uuid),private.dispute_financial_access(uuid,uuid),private.dispute_reassignment_access(uuid,uuid)to authenticated;
revoke all on function public.open_mission_dispute(uuid,text,text,text,jsonb,jsonb,text,uuid),public.respond_to_mission_dispute(uuid,text,text,jsonb,text,uuid),public.decide_mission_dispute(uuid,text,text,uuid[],jsonb,text,uuid),public.appeal_mission_dispute(uuid,text,jsonb,text,uuid),public.propose_mission_reassignment(uuid,uuid,text,uuid,bigint,integer,text,uuid),public.approve_reassignment_cost(uuid,integer,text,uuid),public.activate_mission_reassignment(uuid,uuid,uuid,integer,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.open_mission_dispute(uuid,text,text,text,jsonb,jsonb,text,uuid),public.respond_to_mission_dispute(uuid,text,text,jsonb,text,uuid),public.decide_mission_dispute(uuid,text,text,uuid[],jsonb,text,uuid),public.appeal_mission_dispute(uuid,text,jsonb,text,uuid),public.propose_mission_reassignment(uuid,uuid,text,uuid,bigint,integer,text,uuid),public.approve_reassignment_cost(uuid,integer,text,uuid),public.activate_mission_reassignment(uuid,uuid,uuid,integer,text,uuid)to authenticated;

create index dispute_cases_client_status_idx on public.dispute_cases(client_organization_id,status,opened_at desc);create index dispute_cases_provider_status_idx on public.dispute_cases(provider_organization_id,status,opened_at desc);create index dispute_cases_deadline_idx on public.dispute_cases(status,response_due_at,review_due_at,appeal_due_at);create index dispute_evidence_case_time_idx on public.dispute_evidence(dispute_case_id,created_at,id);create index dispute_decisions_case_version_idx on public.dispute_decisions(dispute_case_id,decision_number desc);create index dispute_events_case_time_idx on public.dispute_case_events(dispute_case_id,created_at,id);create index reassignments_source_idx on public.mission_reassignments(source_mission_id,status);
