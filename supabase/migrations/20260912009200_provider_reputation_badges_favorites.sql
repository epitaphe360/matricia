-- V1 MAT-FUNC-015/016/017/048: confidential feedback, explainable provider reputation,
-- governed badges and client favourites that are always revalidated before reuse.

create table public.provider_feedback_snapshots (
  id uuid primary key default extensions.gen_random_uuid(),
  quote_id uuid not null references public.quotes(id) on delete restrict,
  rfq_id uuid not null references public.rfqs(id) on delete restrict,
  client_organization_id uuid not null references public.organizations(id) on delete restrict,
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  ranking_position integer not null check(ranking_position>0),
  ranked_quote_count integer not null check(ranked_quote_count>1 and ranking_position<=ranked_quote_count),
  improvement_axes jsonb not null check(jsonb_typeof(improvement_axes)='array' and jsonb_array_length(improvement_axes)>0),
  methodology_version text not null check(methodology_version~'^[A-Z0-9][A-Z0-9._-]{2,79}$'),
  source_comparison_snapshot_id uuid references public.quote_comparison_snapshots(id) on delete restrict,
  published_by uuid not null references auth.users(id),
  correlation_id uuid not null,
  published_at timestamptz not null default clock_timestamp(),
  unique(quote_id),
  unique(id,provider_organization_id),
  check(client_organization_id<>provider_organization_id)
);
create index provider_feedback_recipient_idx on public.provider_feedback_snapshots(provider_organization_id,published_at desc);

create table public.provider_reputation_policy_versions (
  policy_version text primary key check(policy_version~'^[A-Z0-9][A-Z0-9._-]{2,79}$'),
  weights jsonb not null check(weights='{"quality":20,"delivery":20,"compliance":20,"responsiveness":15,"satisfaction":15,"finance":10}'::jsonb),
  minimum_evidence_count integer not null check(minimum_evidence_count between 1 and 10000),
  effective_from timestamptz not null,
  effective_until timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  check(effective_until is null or effective_until>effective_from)
);
insert into public.provider_reputation_policy_versions(policy_version,weights,minimum_evidence_count,effective_from)
values('PROVIDER-REPUTATION-V1','{"quality":20,"delivery":20,"compliance":20,"responsiveness":15,"satisfaction":15,"finance":10}'::jsonb,1,clock_timestamp());

create table public.provider_reputation_snapshots (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.provider_profiles(provider_organization_id) on delete restrict,
  service_id uuid references public.catalog_services(id) on delete restrict,
  version_number integer not null check(version_number>0),
  policy_version text not null references public.provider_reputation_policy_versions(policy_version) on delete restrict,
  quality_basis_points integer not null check(quality_basis_points between 0 and 10000),
  delivery_basis_points integer not null check(delivery_basis_points between 0 and 10000),
  compliance_basis_points integer not null check(compliance_basis_points between 0 and 10000),
  responsiveness_basis_points integer not null check(responsiveness_basis_points between 0 and 10000),
  satisfaction_basis_points integer not null check(satisfaction_basis_points between 0 and 10000),
  finance_basis_points integer not null check(finance_basis_points between 0 and 10000),
  overall_basis_points integer not null check(overall_basis_points between 0 and 10000),
  evidence_count integer not null check(evidence_count>0),
  explanation jsonb not null check(jsonb_typeof(explanation)='object'),
  evidence_refs jsonb not null check(jsonb_typeof(evidence_refs)='array' and jsonb_array_length(evidence_refs)>0),
  input_hash text not null check(input_hash~'^[0-9a-f]{64}$'),
  calculated_by uuid not null references auth.users(id),
  correlation_id uuid not null,
  calculated_at timestamptz not null default clock_timestamp(),
  unique(provider_organization_id,service_id,version_number),
  unique(id,provider_organization_id)
);
create unique index provider_reputation_global_version_uidx on public.provider_reputation_snapshots(provider_organization_id,version_number) where service_id is null;
create index provider_reputation_latest_idx on public.provider_reputation_snapshots(provider_organization_id,service_id,version_number desc);

create table public.provider_badge_policy_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  badge_code text not null check(badge_code~'^[A-Z][A-Z0-9_]{2,63}$'),
  version_number integer not null check(version_number>0),
  label_fr text not null check(length(btrim(label_fr)) between 3 and 160),
  label_ar text not null check(length(btrim(label_ar)) between 3 and 160),
  dimension text not null check(dimension in('OVERALL','QUALITY','DELIVERY','COMPLIANCE','RESPONSIVENESS','SATISFACTION','FINANCE')),
  minimum_basis_points integer not null check(minimum_basis_points between 0 and 10000),
  minimum_evidence_count integer not null check(minimum_evidence_count>0),
  effective_from timestamptz not null,
  effective_until timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique(badge_code,version_number),
  unique(id,badge_code),
  check(effective_until is null or effective_until>effective_from)
);
insert into public.provider_badge_policy_versions(badge_code,version_number,label_fr,label_ar,dimension,minimum_basis_points,minimum_evidence_count,effective_from)
values
 ('TRUSTED_PROVIDER',1,'Fournisseur de confiance','مزود موثوق','OVERALL',8000,5,clock_timestamp()),
 ('QUALITY_EXCELLENCE',1,'Excellence qualité','التميز في الجودة','QUALITY',9000,5,clock_timestamp()),
 ('DELIVERY_RELIABILITY',1,'Fiabilité des délais','موثوقية التسليم','DELIVERY',9000,5,clock_timestamp());

create table public.provider_badge_evaluations (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.provider_profiles(provider_organization_id) on delete restrict,
  service_id uuid references public.catalog_services(id) on delete restrict,
  badge_policy_id uuid not null references public.provider_badge_policy_versions(id) on delete restrict,
  reputation_snapshot_id uuid not null,
  evaluation_version integer not null check(evaluation_version>0),
  eligible boolean not null,
  evaluated_basis_points integer not null check(evaluated_basis_points between 0 and 10000),
  explanation jsonb not null check(jsonb_typeof(explanation)='object'),
  evaluated_by uuid not null references auth.users(id),
  correlation_id uuid not null,
  evaluated_at timestamptz not null default clock_timestamp(),
  unique(provider_organization_id,service_id,badge_policy_id,evaluation_version),
  unique(id,provider_organization_id),
  foreign key(reputation_snapshot_id,provider_organization_id) references public.provider_reputation_snapshots(id,provider_organization_id) on delete restrict
);
create unique index provider_badge_eval_global_uidx on public.provider_badge_evaluations(provider_organization_id,badge_policy_id,evaluation_version) where service_id is null;

create table public.provider_badge_decisions (
  id uuid primary key default extensions.gen_random_uuid(),
  evaluation_id uuid not null,
  provider_organization_id uuid not null,
  decision_version integer not null check(decision_version>0),
  action text not null check(action in('PUBLISHED','REVOKED')),
  rationale text not null check(length(btrim(rationale)) between 3 and 1000),
  decided_by uuid not null references auth.users(id),
  correlation_id uuid not null,
  decided_at timestamptz not null default clock_timestamp(),
  unique(evaluation_id,decision_version),
  foreign key(evaluation_id,provider_organization_id) references public.provider_badge_evaluations(id,provider_organization_id) on delete restrict
);
create index provider_badge_decision_latest_idx on public.provider_badge_decisions(evaluation_id,decision_version desc);

create table public.client_provider_favorites (
  id uuid primary key default extensions.gen_random_uuid(),
  client_organization_id uuid not null references public.organizations(id) on delete restrict,
  provider_organization_id uuid not null references public.provider_profiles(provider_organization_id) on delete restrict,
  service_id uuid references public.catalog_services(id) on delete restrict,
  status text not null default 'ACTIVE' check(status in('ACTIVE','REMOVED')),
  note text check(note is null or length(btrim(note)) between 1 and 500),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  removed_by uuid references auth.users(id),
  removed_at timestamptz,
  row_version integer not null default 1 check(row_version>0),
  unique(client_organization_id,provider_organization_id,service_id),
  unique(id,client_organization_id),
  check(client_organization_id<>provider_organization_id),
  check((status='REMOVED')=(removed_by is not null and removed_at is not null))
);
create unique index client_provider_favorite_global_uidx on public.client_provider_favorites(client_organization_id,provider_organization_id) where service_id is null;
create index client_provider_favorites_client_idx on public.client_provider_favorites(client_organization_id,status,created_at desc);

create table public.favorite_eligibility_revalidations (
  id uuid primary key default extensions.gen_random_uuid(),
  favorite_id uuid not null,
  client_organization_id uuid not null,
  request_id uuid not null references public.service_requests(id) on delete restrict,
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  service_id uuid not null references public.catalog_services(id) on delete restrict,
  eligible boolean not null,
  exclusion_reasons text[] not null default '{}',
  eligibility_explanation jsonb not null check(jsonb_typeof(eligibility_explanation)='object'),
  checked_by uuid not null references auth.users(id),
  correlation_id uuid not null,
  checked_at timestamptz not null default clock_timestamp(),
  unique(favorite_id,request_id,correlation_id),
  foreign key(favorite_id,client_organization_id) references public.client_provider_favorites(id,client_organization_id) on delete restrict,
  foreign key(request_id,client_organization_id) references public.service_requests(id,client_organization_id) on delete restrict,
  check((eligible and cardinality(exclusion_reasons)=0) or (not eligible and cardinality(exclusion_reasons)>0))
);
create index favorite_revalidations_request_idx on public.favorite_eligibility_revalidations(request_id,checked_at desc);

create or replace function private.prevent_provider_reputation_snapshot_mutation() returns trigger language plpgsql security definer set search_path=pg_catalog as $$begin raise exception 'IMMUTABLE_PROVIDER_REPUTATION_RECORD' using errcode='55000';end$$;
revoke all on function private.prevent_provider_reputation_snapshot_mutation() from public,anon,authenticated,service_role;
create trigger provider_feedback_immutable before update or delete on public.provider_feedback_snapshots for each row execute function private.prevent_provider_reputation_snapshot_mutation();
create trigger provider_reputation_policy_immutable before update or delete on public.provider_reputation_policy_versions for each row execute function private.prevent_provider_reputation_snapshot_mutation();
create trigger provider_reputation_snapshots_immutable before update or delete on public.provider_reputation_snapshots for each row execute function private.prevent_provider_reputation_snapshot_mutation();
create trigger provider_badge_policy_immutable before update or delete on public.provider_badge_policy_versions for each row execute function private.prevent_provider_reputation_snapshot_mutation();
create trigger provider_badge_evaluations_immutable before update or delete on public.provider_badge_evaluations for each row execute function private.prevent_provider_reputation_snapshot_mutation();
create trigger provider_badge_decisions_immutable before update or delete on public.provider_badge_decisions for each row execute function private.prevent_provider_reputation_snapshot_mutation();
create trigger favorite_revalidations_immutable before update or delete on public.favorite_eligibility_revalidations for each row execute function private.prevent_provider_reputation_snapshot_mutation();

create or replace function private.begin_provider_reputation_command(p_organization_id uuid,p_actor uuid,p_scope text,p_key text,p_hash text) returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare v public.idempotency_keys%rowtype;
begin
 if p_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
 if length(coalesce(p_key,'')) not between 8 and 200 or p_hash!~'^[0-9a-f]{64}$' then raise exception 'INVALID_COMMAND_IDENTITY' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_organization_id::text||':'||p_scope||':'||p_key,0));
 select * into v from public.idempotency_keys where organization_id=p_organization_id and operation_scope=p_scope and key=p_key for update;
 if found then
  if v.request_hash<>p_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if;
  if v.status='COMPLETED' then return v.response_body; end if;
  raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000';
 end if;
 insert into public.idempotency_keys(organization_id,operation_scope,key,request_hash,created_by,expires_at) values(p_organization_id,p_scope,p_key,p_hash,p_actor,clock_timestamp()+interval '7 days');
 return null;
end$$;
create or replace function private.finish_provider_reputation_command(p_organization_id uuid,p_scope text,p_key text,p_response jsonb) returns void language sql security definer set search_path=pg_catalog,public as $$
 update public.idempotency_keys set status='COMPLETED',response_code=200,response_body=p_response,completed_at=clock_timestamp() where organization_id=p_organization_id and operation_scope=p_scope and key=p_key
$$;
revoke all on function private.begin_provider_reputation_command(uuid,uuid,text,text,text),private.finish_provider_reputation_command(uuid,text,text,jsonb) from public,anon,authenticated,service_role;

create or replace function private.assert_improvement_axes(p_axes jsonb) returns void language plpgsql immutable set search_path=pg_catalog as $$
declare v jsonb;
begin
 if p_axes is null or jsonb_typeof(p_axes)<>'array' or jsonb_array_length(p_axes)=0 or jsonb_array_length(p_axes)>6 then raise exception 'INVALID_ANONYMISED_FEEDBACK' using errcode='22023'; end if;
 for v in select value from jsonb_array_elements(p_axes) loop
  if jsonb_typeof(v)<>'object' or exists(select 1 from jsonb_object_keys(v) k where k not in('dimension','message_fr','message_ar')) or v->>'dimension' not in('QUALITY','DELIVERY','COMPLIANCE','RESPONSIVENESS','SATISFACTION','FINANCE') or length(btrim(coalesce(v->>'message_fr',''))) not between 3 and 500 or length(btrim(coalesce(v->>'message_ar',''))) not between 3 and 500 then raise exception 'INVALID_ANONYMISED_FEEDBACK' using errcode='22023'; end if;
  if lower(v::text)~'(winner|gagnant|concurrent|email|phone|telephone|prix exact|exact price)' then raise exception 'CONFIDENTIAL_FEEDBACK_CONTENT' using errcode='22023'; end if;
 end loop;
end$$;

create or replace function public.publish_not_selected_feedback(p_quote_id uuid,p_improvement_axes jsonb,p_methodology_version text,p_comparison_snapshot_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare v_actor uuid:=auth.uid();v_q public.quotes%rowtype;v_client uuid;v_rank integer;v_count integer;v_hash text;v_replay jsonb;v_id uuid;v_response jsonb;
begin
 select q.* into v_q from public.quotes q where q.id=p_quote_id for update;
 if not found then raise exception 'QUOTE_NOT_FOUND' using errcode='P0002'; end if;
 select sr.client_organization_id into strict v_client from public.rfqs r join public.service_requests sr on sr.id=r.request_id where r.id=v_q.rfq_id;
 if not private.has_org_role(v_client,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],v_actor) and not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],v_actor) then raise exception 'FEEDBACK_PUBLISH_DENIED' using errcode='42501'; end if;
 if v_q.status<>'NOT_SELECTED' or not exists(select 1 from public.quotes w where w.rfq_id=v_q.rfq_id and w.status='SELECTED') then raise exception 'FEEDBACK_REQUIRES_COMPLETED_SELECTION' using errcode='55000'; end if;
 perform private.assert_improvement_axes(p_improvement_axes);
 if p_methodology_version!~'^[A-Z0-9][A-Z0-9._-]{2,79}$' then raise exception 'INVALID_FEEDBACK_METHOD' using errcode='22023'; end if;
 if p_comparison_snapshot_id is not null and not exists(select 1 from public.quote_comparison_snapshots c where c.id=p_comparison_snapshot_id and c.rfq_id=v_q.rfq_id and c.client_organization_id=v_client) then raise exception 'COMPARISON_SCOPE_DENIED' using errcode='42501'; end if;
 select x.rank,x.total into v_rank,v_count from(select q.id,dense_rank()over(order by v.total_minor,v.id)::integer rank,count(*)over()::integer total from public.quotes q join public.quote_versions v on v.id=q.current_version_id where q.rfq_id=v_q.rfq_id and q.status in('SELECTED','NOT_SELECTED'))x where x.id=v_q.id;
 if v_count<2 then raise exception 'INSUFFICIENT_RANKING_PANEL' using errcode='55000'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','provider.feedback.publish.v1','quote_id',p_quote_id,'axes',p_improvement_axes,'methodology',p_methodology_version,'comparison',p_comparison_snapshot_id));
 v_replay:=private.begin_provider_reputation_command(v_client,v_actor,'provider.feedback.publish',p_idempotency_key,v_hash);if v_replay is not null then return v_replay;end if;
 insert into public.provider_feedback_snapshots(quote_id,rfq_id,client_organization_id,provider_organization_id,ranking_position,ranked_quote_count,improvement_axes,methodology_version,source_comparison_snapshot_id,published_by,correlation_id) values(v_q.id,v_q.rfq_id,v_client,v_q.provider_organization_id,v_rank,v_count,p_improvement_axes,p_methodology_version,p_comparison_snapshot_id,v_actor,p_correlation_id) returning id into v_id;
 v_response:=jsonb_build_object('outcome','ANONYMISED_FEEDBACK_PUBLISHED','feedback_id',v_id,'quote_id',v_q.id,'ranking_position',v_rank,'ranked_quote_count',v_count);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash) values(v_client,v_actor,'USER','provider.feedback.published','provider_feedback',v_id::text,p_correlation_id,jsonb_build_object('quote_id',v_q.id,'provider_organization_id',v_q.provider_organization_id,'methodology_version',p_methodology_version),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values(v_q.provider_organization_id,'provider_feedback',v_id::text,'ProviderFeedbackPublishedV1',p_correlation_id,jsonb_build_object('feedback_id',v_id,'quote_id',v_q.id,'ranking_position',v_rank,'ranked_quote_count',v_count));
 perform private.finish_provider_reputation_command(v_client,'provider.feedback.publish',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.calculate_provider_reputation(p_provider_organization_id uuid,p_service_id uuid,p_dimensions jsonb,p_evidence_refs jsonb,p_policy_version text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare v_actor uuid:=auth.uid();v_policy public.provider_reputation_policy_versions%rowtype;v_dimension text;v_value integer;v_count integer;v_overall integer;v_version integer;v_hash text;v_replay jsonb;v_id uuid;v_response jsonb;
begin
 if not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],v_actor) then raise exception 'HUMAN_REPUTATION_REVIEW_REQUIRED' using errcode='42501'; end if;
 select * into v_policy from public.provider_reputation_policy_versions where policy_version=p_policy_version and effective_from<=clock_timestamp() and(effective_until is null or effective_until>clock_timestamp());if not found then raise exception 'REPUTATION_POLICY_NOT_ACTIVE' using errcode='22023';end if;
 if p_service_id is not null and not exists(select 1 from public.provider_services where provider_organization_id=p_provider_organization_id and service_id=p_service_id) then raise exception 'PROVIDER_SERVICE_SCOPE_DENIED' using errcode='42501'; end if;
 if p_dimensions is null or jsonb_typeof(p_dimensions)<>'object' or exists(select 1 from jsonb_object_keys(p_dimensions)k where k not in('quality','delivery','compliance','responsiveness','satisfaction','finance')) or (select count(*) from jsonb_object_keys(p_dimensions))<>6 then raise exception 'SIX_REPUTATION_DIMENSIONS_REQUIRED' using errcode='22023'; end if;
 foreach v_dimension in array array['quality','delivery','compliance','responsiveness','satisfaction','finance'] loop v_value:=(p_dimensions->>v_dimension)::integer;if v_value not between 0 and 10000 then raise exception 'INVALID_REPUTATION_BASIS_POINTS' using errcode='22023';end if;end loop;
 if p_evidence_refs is null or jsonb_typeof(p_evidence_refs)<>'array' then raise exception 'REPUTATION_EVIDENCE_REQUIRED' using errcode='22023';end if;v_count:=jsonb_array_length(p_evidence_refs);if v_count<v_policy.minimum_evidence_count then raise exception 'INSUFFICIENT_REPUTATION_EVIDENCE' using errcode='22023';end if;
 v_overall:=((p_dimensions->>'quality')::integer*20+(p_dimensions->>'delivery')::integer*20+(p_dimensions->>'compliance')::integer*20+(p_dimensions->>'responsiveness')::integer*15+(p_dimensions->>'satisfaction')::integer*15+(p_dimensions->>'finance')::integer*10)/100;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','provider.reputation.calculate.v1','provider',p_provider_organization_id,'service',p_service_id,'dimensions',p_dimensions,'evidence',p_evidence_refs,'policy',p_policy_version));v_replay:=private.begin_provider_reputation_command(p_provider_organization_id,v_actor,'provider.reputation.calculate',p_idempotency_key,v_hash);if v_replay is not null then return v_replay;end if;
 perform pg_advisory_xact_lock(hashtextextended('provider-reputation:'||p_provider_organization_id::text||':'||coalesce(p_service_id::text,'GLOBAL'),0));select coalesce(max(version_number),0)+1 into v_version from public.provider_reputation_snapshots where provider_organization_id=p_provider_organization_id and service_id is not distinct from p_service_id;
 insert into public.provider_reputation_snapshots(provider_organization_id,service_id,version_number,policy_version,quality_basis_points,delivery_basis_points,compliance_basis_points,responsiveness_basis_points,satisfaction_basis_points,finance_basis_points,overall_basis_points,evidence_count,explanation,evidence_refs,input_hash,calculated_by,correlation_id) values(p_provider_organization_id,p_service_id,v_version,p_policy_version,(p_dimensions->>'quality')::integer,(p_dimensions->>'delivery')::integer,(p_dimensions->>'compliance')::integer,(p_dimensions->>'responsiveness')::integer,(p_dimensions->>'satisfaction')::integer,(p_dimensions->>'finance')::integer,v_overall,v_count,jsonb_build_object('policy_version',p_policy_version,'weights',v_policy.weights,'formula','INTEGER_WEIGHTED_AVERAGE_BASIS_POINTS','dimensions',p_dimensions),p_evidence_refs,v_hash,v_actor,p_correlation_id) returning id into v_id;
 v_response:=jsonb_build_object('outcome','PROVIDER_REPUTATION_CALCULATED','snapshot_id',v_id,'version_number',v_version,'overall_basis_points',v_overall,'explanation',jsonb_build_object('weights',v_policy.weights,'dimensions',p_dimensions));
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash) values(p_provider_organization_id,v_actor,'USER','provider.reputation.calculated','provider_reputation_snapshot',v_id::text,p_correlation_id,jsonb_build_object('policy_version',p_policy_version,'service_id',p_service_id,'evidence_count',v_count),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values(p_provider_organization_id,'provider_reputation',p_provider_organization_id::text,'ProviderReputationCalculatedV1',p_correlation_id,jsonb_build_object('snapshot_id',v_id,'service_id',p_service_id,'version_number',v_version,'overall_basis_points',v_overall));perform private.finish_provider_reputation_command(p_provider_organization_id,'provider.reputation.calculate',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.evaluate_provider_badge(p_provider_organization_id uuid,p_service_id uuid,p_badge_policy_id uuid,p_reputation_snapshot_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare v_actor uuid:=auth.uid();v_policy public.provider_badge_policy_versions%rowtype;v_rep public.provider_reputation_snapshots%rowtype;v_score integer;v_eligible boolean;v_version integer;v_hash text;v_replay jsonb;v_id uuid;v_response jsonb;
begin
 if not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],v_actor) then raise exception 'BADGE_EVALUATION_DENIED' using errcode='42501'; end if;
 select * into v_policy from public.provider_badge_policy_versions where id=p_badge_policy_id and effective_from<=clock_timestamp() and(effective_until is null or effective_until>clock_timestamp());if not found then raise exception 'BADGE_POLICY_NOT_ACTIVE' using errcode='22023';end if;
 select * into v_rep from public.provider_reputation_snapshots where id=p_reputation_snapshot_id and provider_organization_id=p_provider_organization_id and service_id is not distinct from p_service_id;if not found then raise exception 'REPUTATION_SCOPE_DENIED' using errcode='42501';end if;
 v_score:=case v_policy.dimension when'OVERALL'then v_rep.overall_basis_points when'QUALITY'then v_rep.quality_basis_points when'DELIVERY'then v_rep.delivery_basis_points when'COMPLIANCE'then v_rep.compliance_basis_points when'RESPONSIVENESS'then v_rep.responsiveness_basis_points when'SATISFACTION'then v_rep.satisfaction_basis_points else v_rep.finance_basis_points end;v_eligible:=v_score>=v_policy.minimum_basis_points and v_rep.evidence_count>=v_policy.minimum_evidence_count;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','provider.badge.evaluate.v1','provider',p_provider_organization_id,'service',p_service_id,'policy',p_badge_policy_id,'reputation',p_reputation_snapshot_id));v_replay:=private.begin_provider_reputation_command(p_provider_organization_id,v_actor,'provider.badge.evaluate',p_idempotency_key,v_hash);if v_replay is not null then return v_replay;end if;
 perform pg_advisory_xact_lock(hashtextextended('provider-badge:'||p_provider_organization_id::text||':'||p_badge_policy_id::text||':'||coalesce(p_service_id::text,'GLOBAL'),0));select coalesce(max(evaluation_version),0)+1 into v_version from public.provider_badge_evaluations where provider_organization_id=p_provider_organization_id and service_id is not distinct from p_service_id and badge_policy_id=p_badge_policy_id;
 insert into public.provider_badge_evaluations(provider_organization_id,service_id,badge_policy_id,reputation_snapshot_id,evaluation_version,eligible,evaluated_basis_points,explanation,evaluated_by,correlation_id)values(p_provider_organization_id,p_service_id,p_badge_policy_id,p_reputation_snapshot_id,v_version,v_eligible,v_score,jsonb_build_object('dimension',v_policy.dimension,'actual_basis_points',v_score,'required_basis_points',v_policy.minimum_basis_points,'evidence_count',v_rep.evidence_count,'required_evidence_count',v_policy.minimum_evidence_count),v_actor,p_correlation_id)returning id into v_id;
 v_response:=jsonb_build_object('outcome','PROVIDER_BADGE_EVALUATED','evaluation_id',v_id,'eligible',v_eligible,'evaluation_version',v_version,'explanation',jsonb_build_object('actual_basis_points',v_score,'required_basis_points',v_policy.minimum_basis_points));
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_provider_organization_id,v_actor,'USER','provider.badge.evaluated','provider_badge_evaluation',v_id::text,p_correlation_id,jsonb_build_object('eligible',v_eligible,'policy_id',p_badge_policy_id),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(p_provider_organization_id,'provider_badge',v_id::text,'ProviderBadgeEvaluatedV1',p_correlation_id,jsonb_build_object('evaluation_id',v_id,'eligible',v_eligible,'policy_id',p_badge_policy_id));perform private.finish_provider_reputation_command(p_provider_organization_id,'provider.badge.evaluate',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.decide_provider_badge(p_evaluation_id uuid,p_action text,p_rationale text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare v_actor uuid:=auth.uid();v_eval public.provider_badge_evaluations%rowtype;v_version integer;v_last text;v_hash text;v_replay jsonb;v_id uuid;v_response jsonb;
begin
 if not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],v_actor) then raise exception 'HUMAN_BADGE_DECISION_REQUIRED' using errcode='42501';end if;
 select * into v_eval from public.provider_badge_evaluations where id=p_evaluation_id for update;if not found then raise exception 'BADGE_EVALUATION_NOT_FOUND' using errcode='P0002';end if;
 if p_action not in('PUBLISHED','REVOKED') or length(btrim(coalesce(p_rationale,'')))not between 3 and 1000 then raise exception 'INVALID_BADGE_DECISION' using errcode='22023';end if;if p_action='PUBLISHED'and not v_eval.eligible then raise exception 'INELIGIBLE_BADGE_CANNOT_BE_PUBLISHED' using errcode='55000';end if;
 select action into v_last from public.provider_badge_decisions where evaluation_id=p_evaluation_id order by decision_version desc limit 1;if(v_last is null and p_action<>'PUBLISHED')or(v_last=p_action)then raise exception 'INVALID_BADGE_DECISION_TRANSITION' using errcode='55000';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','provider.badge.decide.v1','evaluation',p_evaluation_id,'action',p_action,'rationale',btrim(p_rationale)));v_replay:=private.begin_provider_reputation_command(v_eval.provider_organization_id,v_actor,'provider.badge.decide',p_idempotency_key,v_hash);if v_replay is not null then return v_replay;end if;
 select coalesce(max(decision_version),0)+1 into v_version from public.provider_badge_decisions where evaluation_id=p_evaluation_id;insert into public.provider_badge_decisions(evaluation_id,provider_organization_id,decision_version,action,rationale,decided_by,correlation_id)values(p_evaluation_id,v_eval.provider_organization_id,v_version,p_action,btrim(p_rationale),v_actor,p_correlation_id)returning id into v_id;
 v_response:=jsonb_build_object('outcome','PROVIDER_BADGE_DECIDED','decision_id',v_id,'decision_version',v_version,'action',p_action);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_eval.provider_organization_id,v_actor,'USER','provider.badge.'||lower(p_action),'provider_badge_decision',v_id::text,p_correlation_id,jsonb_build_object('evaluation_id',p_evaluation_id,'rationale',btrim(p_rationale)),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(v_eval.provider_organization_id,'provider_badge',p_evaluation_id::text,case p_action when'PUBLISHED'then'ProviderBadgePublishedV1'else'ProviderBadgeRevokedV1'end,p_correlation_id,jsonb_build_object('evaluation_id',p_evaluation_id,'decision_id',v_id,'decision_version',v_version));perform private.finish_provider_reputation_command(v_eval.provider_organization_id,'provider.badge.decide',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.set_provider_favorite(p_client_organization_id uuid,p_provider_organization_id uuid,p_service_id uuid,p_active boolean,p_note text,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare v_actor uuid:=auth.uid();v_f public.client_provider_favorites%rowtype;v_hash text;v_replay jsonb;v_response jsonb;
begin
 if not private.has_org_role(p_client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],v_actor) then raise exception 'FAVORITE_CLIENT_SCOPE_DENIED' using errcode='42501';end if;if p_active is null then raise exception 'INVALID_FAVORITE_STATE' using errcode='22023';end if;if p_client_organization_id=p_provider_organization_id then raise exception 'SELF_PROVIDER_FAVORITE_FORBIDDEN' using errcode='22023';end if;
 if p_service_id is not null and not exists(select 1 from public.provider_services where provider_organization_id=p_provider_organization_id and service_id=p_service_id)then raise exception 'FAVORITE_PROVIDER_SERVICE_UNKNOWN' using errcode='22023';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','provider.favorite.set.v1','client',p_client_organization_id,'provider',p_provider_organization_id,'service',p_service_id,'active',p_active,'note',p_note,'expected',p_expected_row_version));v_replay:=private.begin_provider_reputation_command(p_client_organization_id,v_actor,'provider.favorite.set',p_idempotency_key,v_hash);if v_replay is not null then return v_replay;end if;
 select * into v_f from public.client_provider_favorites where client_organization_id=p_client_organization_id and provider_organization_id=p_provider_organization_id and service_id is not distinct from p_service_id for update;
 if found then if v_f.row_version<>p_expected_row_version then raise exception 'STALE_PROVIDER_FAVORITE' using errcode='40001';end if;update public.client_provider_favorites set status=case when p_active then'ACTIVE'else'REMOVED'end,note=p_note,removed_by=case when p_active then null else v_actor end,removed_at=case when p_active then null else clock_timestamp()end,row_version=row_version+1 where id=v_f.id returning * into v_f;
 else if p_expected_row_version<>0 or not p_active then raise exception 'STALE_PROVIDER_FAVORITE' using errcode='40001';end if;insert into public.client_provider_favorites(client_organization_id,provider_organization_id,service_id,note,created_by)values(p_client_organization_id,p_provider_organization_id,p_service_id,p_note,v_actor)returning * into v_f;end if;
 v_response:=jsonb_build_object('outcome','PROVIDER_FAVORITE_SET','favorite_id',v_f.id,'status',v_f.status,'row_version',v_f.row_version);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_client_organization_id,v_actor,'USER','provider.favorite.'||case when p_active then'activated'else'removed'end,'client_provider_favorite',v_f.id::text,p_correlation_id,jsonb_build_object('provider_organization_id',p_provider_organization_id,'service_id',p_service_id),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(p_client_organization_id,'provider_favorite',v_f.id::text,case when p_active then'ProviderFavoriteActivatedV1'else'ProviderFavoriteRemovedV1'end,p_correlation_id,jsonb_build_object('favorite_id',v_f.id,'provider_organization_id',p_provider_organization_id,'service_id',p_service_id));perform private.finish_provider_reputation_command(p_client_organization_id,'provider.favorite.set',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function private.current_provider_service_eligibility(p_provider_organization_id uuid,p_service_id uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog,public as $$
declare v_profile public.provider_profiles%rowtype;v_service public.provider_services%rowtype;v_decision public.provider_qualification_decisions%rowtype;v_capacity text;v_reasons text[]:='{}';
begin
 select * into v_profile from public.provider_profiles where provider_organization_id=p_provider_organization_id;
 select * into v_service from public.provider_services where provider_organization_id=p_provider_organization_id and service_id=p_service_id;
 select d.* into v_decision from public.provider_qualifications q join public.provider_qualification_decisions d on d.id=q.current_decision_id where q.provider_organization_id=p_provider_organization_id and q.service_id=p_service_id;
 select c.capacity_status into v_capacity from public.provider_capacity_versions c where c.provider_organization_id=p_provider_organization_id and(c.service_id=p_service_id or c.service_id is null)and c.effective_from<=statement_timestamp()and(c.effective_until is null or c.effective_until>statement_timestamp())order by(c.service_id is not null)desc,c.version_number desc limit 1;
 if v_profile.provider_organization_id is null then v_reasons:=array_append(v_reasons,'PROFILE_MISSING');else
  if v_profile.company_status<>'VERIFIED'then v_reasons:=array_append(v_reasons,'COMPANY_NOT_VERIFIED');end if;
  if(select count(distinct f.document_kind)<3 from public.provider_document_families f where f.provider_organization_id=p_provider_organization_id and f.document_kind in('LEGAL','FISCAL','INSURANCE'))or exists(select 1 from public.provider_document_families f join lateral(select d.* from public.provider_document_versions d where d.family_id=f.id order by d.version_number desc limit 1)d on true where f.provider_organization_id=p_provider_organization_id and f.document_kind in('LEGAL','FISCAL','INSURANCE')and(d.status<>'VERIFIED'or(d.expires_on is not null and d.expires_on<=current_date)))then v_reasons:=array_append(v_reasons,'COMPANY_DOCUMENTS_INVALID');end if;
  if v_profile.partner_contract_status<>'SIGNED'or(v_profile.partner_contract_expires_at is not null and v_profile.partner_contract_expires_at<=statement_timestamp())then v_reasons:=array_append(v_reasons,'PARTNER_CONTRACT_INVALID');end if;
  if v_profile.overall_status in('FINANCIAL_RESTRICTED','QUALITY_RESTRICTED','COMPLIANCE_RESTRICTED','SUSPENDED','TERMINATED')then v_reasons:=array_append(v_reasons,v_profile.overall_status);end if;
 end if;
 if v_service.id is null then v_reasons:=array_append(v_reasons,'SERVICE_NOT_REQUESTED');end if;
 if v_decision.id is null then v_reasons:=array_append(v_reasons,'QUALIFICATION_NOT_DECIDED');elsif v_decision.status<>'APPROVED'then v_reasons:=array_append(v_reasons,'QUALIFICATION_'||v_decision.status);elsif v_decision.expires_at is not null and v_decision.expires_at<=statement_timestamp()then v_reasons:=array_append(v_reasons,'QUALIFICATION_EXPIRED');end if;
 if exists(select 1 from public.provider_document_families f join lateral(select d.* from public.provider_document_versions d where d.family_id=f.id order by d.version_number desc limit 1)d on true join public.provider_document_service_links l on l.document_version_id=d.id where l.provider_service_id=v_service.id and l.is_mandatory and(d.status<>'VERIFIED'or(d.expires_on is not null and d.expires_on<=current_date)))then v_reasons:=array_append(v_reasons,'MANDATORY_DOCUMENT_INVALID');end if;
 if v_capacity is null then v_reasons:=array_append(v_reasons,'CAPACITY_NOT_DECLARED');elsif v_capacity in('FULL','PAUSED')then v_reasons:=array_append(v_reasons,'CAPACITY_'||v_capacity);end if;
 if exists(select 1 from public.provider_restriction_decisions r where r.provider_organization_id=p_provider_organization_id and(r.service_id is null or r.service_id=p_service_id)and r.action='IMPOSED'and not exists(select 1 from public.provider_restriction_decisions newer where newer.provider_organization_id=r.provider_organization_id and newer.service_id is not distinct from r.service_id and newer.restriction_type=r.restriction_type and newer.decision_version>r.decision_version))then v_reasons:=array_append(v_reasons,'ACTIVE_HUMAN_RESTRICTION');end if;
 return jsonb_build_object('eligible',cardinality(v_reasons)=0,'provider_organization_id',p_provider_organization_id,'service_id',p_service_id,'reasons',to_jsonb(v_reasons),'qualification_status',coalesce(v_decision.status,'NOT_REQUESTED'),'capacity_status',coalesce(v_capacity,'NOT_DECLARED'),'decision_version',v_decision.decision_version,'rule_version',v_decision.rule_version,'checked_at',statement_timestamp());
end$$;
revoke all on function private.current_provider_service_eligibility(uuid,uuid) from public,anon,authenticated,service_role;

create or replace function public.revalidate_provider_favorite(p_favorite_id uuid,p_request_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare v_actor uuid:=auth.uid();v_f public.client_provider_favorites%rowtype;v_r public.service_requests%rowtype;v_explain jsonb;v_eligible boolean;v_reasons text[];v_hash text;v_replay jsonb;v_id uuid;v_response jsonb;
begin
 select * into v_f from public.client_provider_favorites where id=p_favorite_id;if not found then raise exception 'PROVIDER_FAVORITE_NOT_FOUND' using errcode='P0002';end if;if not private.has_org_role(v_f.client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],v_actor)then raise exception 'FAVORITE_CLIENT_SCOPE_DENIED' using errcode='42501';end if;if v_f.status<>'ACTIVE'then raise exception 'INACTIVE_PROVIDER_FAVORITE' using errcode='55000';end if;
 select * into v_r from public.service_requests where id=p_request_id and client_organization_id=v_f.client_organization_id;if not found then raise exception 'FAVORITE_REQUEST_SCOPE_DENIED' using errcode='42501';end if;if v_f.service_id is not null and v_f.service_id<>v_r.service_id then raise exception 'FAVORITE_SERVICE_MISMATCH' using errcode='22023';end if;
 v_explain:=private.current_provider_service_eligibility(v_f.provider_organization_id,v_r.service_id);v_eligible:=coalesce((v_explain->>'eligible')::boolean,false);select coalesce(array_agg(value),array[]::text[])into v_reasons from jsonb_array_elements_text(coalesce(v_explain->'reasons','[]'::jsonb));if not v_eligible and cardinality(v_reasons)=0 then v_reasons:=array['ELIGIBILITY_NOT_CONFIRMED'];end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','provider.favorite.revalidate.v1','favorite',p_favorite_id,'request',p_request_id,'eligibility',v_explain));v_replay:=private.begin_provider_reputation_command(v_f.client_organization_id,v_actor,'provider.favorite.revalidate',p_idempotency_key,v_hash);if v_replay is not null then return v_replay;end if;
 insert into public.favorite_eligibility_revalidations(favorite_id,client_organization_id,request_id,provider_organization_id,service_id,eligible,exclusion_reasons,eligibility_explanation,checked_by,correlation_id)values(v_f.id,v_f.client_organization_id,v_r.id,v_f.provider_organization_id,v_r.service_id,v_eligible,v_reasons,v_explain,v_actor,p_correlation_id)returning id into v_id;
 v_response:=jsonb_build_object('outcome','PROVIDER_FAVORITE_REVALIDATED','revalidation_id',v_id,'favorite_id',v_f.id,'request_id',v_r.id,'eligible',v_eligible,'exclusion_reasons',to_jsonb(v_reasons),'explanation',v_explain);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_f.client_organization_id,v_actor,'USER','provider.favorite.revalidated','favorite_eligibility_revalidation',v_id::text,p_correlation_id,jsonb_build_object('favorite_id',v_f.id,'request_id',v_r.id,'provider_organization_id',v_f.provider_organization_id,'eligible',v_eligible,'exclusion_reasons',to_jsonb(v_reasons)),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(v_f.client_organization_id,'provider_favorite',v_f.id::text,'ProviderFavoriteRevalidatedV1',p_correlation_id,jsonb_build_object('revalidation_id',v_id,'request_id',v_r.id,'provider_organization_id',v_f.provider_organization_id,'eligible',v_eligible,'exclusion_reasons',to_jsonb(v_reasons)));perform private.finish_provider_reputation_command(v_f.client_organization_id,'provider.favorite.revalidate',p_idempotency_key,v_response);return v_response;
end$$;

alter table public.provider_feedback_snapshots enable row level security;alter table public.provider_reputation_policy_versions enable row level security;alter table public.provider_reputation_snapshots enable row level security;alter table public.provider_badge_policy_versions enable row level security;alter table public.provider_badge_evaluations enable row level security;alter table public.provider_badge_decisions enable row level security;alter table public.client_provider_favorites enable row level security;alter table public.favorite_eligibility_revalidations enable row level security;
revoke all on public.provider_feedback_snapshots,public.provider_reputation_policy_versions,public.provider_reputation_snapshots,public.provider_badge_policy_versions,public.provider_badge_evaluations,public.provider_badge_decisions,public.client_provider_favorites,public.favorite_eligibility_revalidations from public,anon,authenticated,service_role;
grant select on public.provider_feedback_snapshots,public.provider_reputation_policy_versions,public.provider_reputation_snapshots,public.provider_badge_policy_versions,public.provider_badge_evaluations,public.provider_badge_decisions,public.client_provider_favorites,public.favorite_eligibility_revalidations to authenticated;
create policy provider_feedback_recipient_read on public.provider_feedback_snapshots for select to authenticated using(private.has_org_role(provider_organization_id,array['PROVIDER_OWNER','PROVIDER_MANAGER','PROVIDER_SALES','PROVIDER_VIEWER'])or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy provider_reputation_policy_read on public.provider_reputation_policy_versions for select to authenticated using(true);
create policy provider_reputation_read on public.provider_reputation_snapshots for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy provider_badge_policy_read on public.provider_badge_policy_versions for select to authenticated using(true);
create policy provider_badge_evaluation_read on public.provider_badge_evaluations for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy provider_badge_decision_read on public.provider_badge_decisions for select to authenticated using(private.is_active_org_member(provider_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy client_provider_favorites_read on public.client_provider_favorites for select to authenticated using(private.is_active_org_member(client_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy favorite_revalidations_client_read on public.favorite_eligibility_revalidations for select to authenticated using(private.is_active_org_member(client_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));

revoke all on function private.assert_improvement_axes(jsonb) from public,anon,authenticated,service_role;
revoke all on function public.publish_not_selected_feedback(uuid,jsonb,text,uuid,text,uuid),public.calculate_provider_reputation(uuid,uuid,jsonb,jsonb,text,text,uuid),public.evaluate_provider_badge(uuid,uuid,uuid,uuid,text,uuid),public.decide_provider_badge(uuid,text,text,text,uuid),public.set_provider_favorite(uuid,uuid,uuid,boolean,text,integer,text,uuid),public.revalidate_provider_favorite(uuid,uuid,text,uuid) from public,anon,service_role;
grant execute on function public.publish_not_selected_feedback(uuid,jsonb,text,uuid,text,uuid),public.calculate_provider_reputation(uuid,uuid,jsonb,jsonb,text,text,uuid),public.evaluate_provider_badge(uuid,uuid,uuid,uuid,text,uuid),public.decide_provider_badge(uuid,text,text,text,uuid),public.set_provider_favorite(uuid,uuid,uuid,boolean,text,integer,text,uuid),public.revalidate_provider_favorite(uuid,uuid,text,uuid) to authenticated;
