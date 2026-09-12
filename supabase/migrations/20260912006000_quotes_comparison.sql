-- P07: immutable quote revisions and explainable normalized comparison.

create table public.quotes (
  id uuid primary key default extensions.gen_random_uuid(),
  rfq_id uuid not null references public.rfqs(id),
  rfq_provider_id uuid not null,
  provider_organization_id uuid not null references public.organizations(id),
  status text not null default 'DRAFT' check (status in ('DRAFT','SUBMITTED','REVISION_REQUESTED','REVISED','SELECTED','NOT_SELECTED','WITHDRAWN','EXPIRED')),
  current_version_id uuid,
  selected_version_id uuid,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version integer not null default 1 check (row_version > 0),
  unique (rfq_id, provider_organization_id),
  unique (id, rfq_id, provider_organization_id),
  foreign key (rfq_provider_id, rfq_id, provider_organization_id)
    references public.rfq_providers(id, rfq_id, provider_organization_id)
);

create table public.quote_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  quote_id uuid not null references public.quotes(id),
  rfq_id uuid not null,
  provider_organization_id uuid not null,
  version_number integer not null check (version_number > 0),
  supersedes_id uuid references public.quote_versions(id),
  lifecycle_status text not null check (lifecycle_status in ('DRAFT','SUBMITTED','REVISED','WITHDRAWN','EXPIRED')),
  change_reason text not null check (length(btrim(change_reason)) between 3 and 1000),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  solution_fr text not null check (length(btrim(solution_fr)) between 3 and 12000),
  solution_ar text,
  deliverables jsonb not null check (jsonb_typeof(deliverables)='array' and jsonb_array_length(deliverables)>0),
  inclusions jsonb not null default '[]'::jsonb check (jsonb_typeof(inclusions)='array'),
  exclusions jsonb not null default '[]'::jsonb check (jsonb_typeof(exclusions)='array'),
  prerequisites jsonb not null default '[]'::jsonb check (jsonb_typeof(prerequisites)='array'),
  warranty_fr text not null check (length(btrim(warranty_fr)) between 3 and 2000),
  warranty_ar text,
  correction_terms_fr text not null check (length(btrim(correction_terms_fr)) between 3 and 2000),
  correction_terms_ar text,
  sla jsonb not null default '{}'::jsonb check (jsonb_typeof(sla)='object'),
  proposed_start_date date not null,
  duration_days integer not null check (duration_days > 0 and duration_days <= 3650),
  valid_until timestamptz not null,
  subtotal_minor bigint not null check (subtotal_minor >= 0),
  tax_minor bigint not null check (tax_minor >= 0),
  total_minor bigint not null check (total_minor = subtotal_minor + tax_minor),
  recurring_subtotal_minor bigint not null check (recurring_subtotal_minor >= 0),
  calculation_basis jsonb not null check (jsonb_typeof(calculation_basis)='object'),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  submitted_at timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (quote_id, version_number),
  unique (id, quote_id),
  foreign key (quote_id, rfq_id, provider_organization_id)
    references public.quotes(id, rfq_id, provider_organization_id),
  check ((lifecycle_status in ('SUBMITTED','REVISED')) = (submitted_at is not null)),
  check (valid_until > created_at)
);

alter table public.quotes
  add constraint quotes_current_version_fk foreign key (current_version_id, id) references public.quote_versions(id, quote_id),
  add constraint quotes_selected_version_fk foreign key (selected_version_id, id) references public.quote_versions(id, quote_id),
  add constraint quotes_selected_consistency check ((status='SELECTED')=(selected_version_id is not null));

create table public.quote_items (
  id uuid primary key default extensions.gen_random_uuid(),
  quote_version_id uuid not null references public.quote_versions(id),
  line_number integer not null check (line_number > 0),
  item_kind text not null check (item_kind in ('ONE_TIME','RECURRING')),
  label_fr text not null check (length(btrim(label_fr)) between 2 and 500),
  label_ar text,
  quantity numeric(18,4) not null check (quantity > 0),
  unit_code text not null check (unit_code ~ '^[A-Z][A-Z0-9_]{0,31}$'),
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  subtotal_minor bigint not null check (subtotal_minor >= 0),
  tax_rule_version_id uuid not null references public.tax_rule_versions(id),
  tax_rate_basis_points integer not null check (tax_rate_basis_points between 0 and 10000),
  tax_minor bigint not null check (tax_minor >= 0),
  total_minor bigint not null check (total_minor = subtotal_minor + tax_minor),
  recurrence_interval text check (recurrence_interval in ('MONTH','QUARTER','YEAR')),
  created_at timestamptz not null default now(),
  unique (quote_version_id, line_number),
  check ((item_kind='RECURRING')=(recurrence_interval is not null))
);

create table public.quote_options (
  id uuid primary key default extensions.gen_random_uuid(),
  quote_version_id uuid not null references public.quote_versions(id),
  option_key text not null check (option_key ~ '^[A-Z][A-Z0-9_]{1,63}$'),
  label_fr text not null check (length(btrim(label_fr)) between 2 and 500),
  label_ar text,
  amount_minor bigint not null check (amount_minor >= 0),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  included_by_default boolean not null default false,
  created_at timestamptz not null default now(),
  unique (quote_version_id, option_key)
);

create table public.quote_revision_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  quote_id uuid not null references public.quotes(id),
  requested_from_version_id uuid not null references public.quote_versions(id),
  requested_by uuid not null references auth.users(id),
  reason text not null check (length(btrim(reason)) between 3 and 2000),
  status text not null default 'OPEN' check (status in ('OPEN','FULFILLED','DECLINED')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.quote_comparison_snapshots (
  id uuid primary key default extensions.gen_random_uuid(),
  rfq_id uuid not null references public.rfqs(id),
  client_organization_id uuid not null references public.organizations(id),
  normalization_version text not null check (normalization_version ~ '^[A-Z0-9][A-Z0-9._-]{1,31}$'),
  quote_version_ids uuid[] not null check (cardinality(quote_version_ids) >= 1),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  comparison jsonb not null check (jsonb_typeof(comparison)='object'),
  input_hash text not null check (input_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create unique index quotes_one_selected_per_rfq_idx on public.quotes(rfq_id) where status='SELECTED';
create index quotes_provider_idx on public.quotes(provider_organization_id,status,updated_at desc);
create index quote_versions_quote_idx on public.quote_versions(quote_id,version_number desc);
create index quote_items_version_idx on public.quote_items(quote_version_id,line_number);
create index quote_comparisons_rfq_idx on public.quote_comparison_snapshots(rfq_id,created_at desc);
create unique index quote_revision_requests_one_open_idx on public.quote_revision_requests(quote_id) where status='OPEN';

create or replace function private.can_read_quote(p_quote_id uuid,p_user_id uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=pg_catalog,public,private as $$
 select exists(select 1 from public.quotes q join public.rfqs r on r.id=q.rfq_id join public.service_requests sr on sr.id=r.request_id
 where q.id=p_quote_id and (
  private.has_org_role(q.provider_organization_id,array['PROVIDER_OWNER','PROVIDER_MANAGER','PROVIDER_SALES','PROVIDER_VIEWER'],p_user_id)
  or (q.status in('SUBMITTED','REVISION_REQUESTED','SELECTED','NOT_SELECTED','WITHDRAWN','EXPIRED')and private.has_org_role(sr.client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER','CLIENT_VIEWER'],p_user_id))
  or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'],p_user_id)
 ));
$$;

create or replace function private.assert_quote_payload(p_payload jsonb) returns void
language plpgsql immutable set search_path=pg_catalog as $$
declare v_line jsonb; v_allowed text[]:=array['currency','solution_fr','solution_ar','deliverables','inclusions','exclusions','prerequisites','warranty_fr','warranty_ar','correction_terms_fr','correction_terms_ar','sla','proposed_start_date','duration_days','valid_until','items','options'];
begin
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or exists(select 1 from jsonb_object_keys(p_payload)k where not(k=any(v_allowed)))
  or coalesce(p_payload->>'currency','')!~'^[A-Z]{3}$'
  or length(btrim(coalesce(p_payload->>'solution_fr',''))) not between 3 and 12000
  or jsonb_typeof(p_payload->'deliverables')<>'array' or jsonb_array_length(p_payload->'deliverables')=0
  or jsonb_typeof(coalesce(p_payload->'items','null'::jsonb))<>'array' or jsonb_array_length(p_payload->'items')=0
  or coalesce(p_payload->>'duration_days','')!~'^[1-9][0-9]{0,3}$'
  or length(btrim(coalesce(p_payload->>'warranty_fr',''))) not between 3 and 2000
  or length(btrim(coalesce(p_payload->>'correction_terms_fr',''))) not between 3 and 2000
 then raise exception 'QUOTE_PAYLOAD_INVALID' using errcode='22023'; end if;
 for v_line in select value from jsonb_array_elements(p_payload->'items') loop
  if jsonb_typeof(v_line)<>'object' or coalesce(v_line->>'line_number','')!~'^[1-9][0-9]{0,5}$'
   or coalesce(v_line->>'item_kind','') not in('ONE_TIME','RECURRING')
   or length(btrim(coalesce(v_line->>'label_fr',''))) not between 2 and 500
   or coalesce(v_line->>'quantity','')!~'^[0-9]{1,14}([.][0-9]{1,4})?$' or (v_line->>'quantity')::numeric<=0
   or coalesce(v_line->>'unit_price_minor','')!~'^[0-9]{1,18}$'
   or coalesce(v_line->>'tax_rule_version_id','')!~'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
   or coalesce(v_line->>'unit_code','')!~'^[A-Z][A-Z0-9_]{0,31}$'
   or ((v_line->>'item_kind'='RECURRING')<>(coalesce(v_line->>'recurrence_interval','') in('MONTH','QUARTER','YEAR')))
  then raise exception 'QUOTE_LINE_INVALID' using errcode='22023'; end if;
 end loop;
end;$$;

create or replace function public.create_quote_revision(p_rfq_provider_id uuid,p_payload jsonb,p_change_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_rp record;v_quote public.quotes%rowtype;v_version uuid;v_number int;v_line jsonb;v_tax public.tax_rule_versions%rowtype;v_sub bigint;v_tax_minor bigint;v_total_sub bigint:=0;v_total_tax bigint:=0;v_recurring bigint:=0;v_hash text;v_existing public.idempotency_keys%rowtype;v_response jsonb;v_basis jsonb:='[]'::jsonb;v_now timestamptz:=clock_timestamp();
begin
 if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode='42501';end if;
 perform private.assert_quote_payload(p_payload);
 if length(coalesce(p_idempotency_key,''))not between 8 and 200 or length(btrim(coalesce(p_change_reason,'')))not between 3 and 1000 then raise exception 'QUOTE_COMMAND_INVALID' using errcode='22023';end if;
 select rp.id,rp.rfq_id,rp.provider_organization_id,rp.status provider_status,r.status rfq_status,r.deadline into v_rp from public.rfq_providers rp join public.rfqs r on r.id=rp.rfq_id where rp.id=p_rfq_provider_id for update of rp,r;
 if not found then raise exception 'RFQ_INVITATION_NOT_FOUND' using errcode='P0002';end if;
 if not private.has_org_role(v_rp.provider_organization_id,array['PROVIDER_OWNER','PROVIDER_MANAGER','PROVIDER_SALES'],v_actor) then raise exception 'QUOTE_PROVIDER_SCOPE_DENIED' using errcode='42501';end if;
 if v_rp.provider_status<>'ACCEPTED' or v_rp.rfq_status<>'OPEN' or v_rp.deadline<=v_now then raise exception 'QUOTE_RFQ_NOT_OPEN' using errcode='55000';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','quote.revision.create.v1','rfq_provider_id',p_rfq_provider_id,'payload',p_payload,'change_reason',btrim(p_change_reason)));
 perform pg_advisory_xact_lock(hashtextextended(v_rp.provider_organization_id::text||':quote.revision.create:'||p_idempotency_key,0));
 select * into v_existing from public.idempotency_keys where organization_id=v_rp.provider_organization_id and operation_scope='quote.revision.create' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000';end if;if v_existing.status='COMPLETED'then return v_existing.response_body;end if;raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000';end if;
 insert into public.idempotency_keys(organization_id,operation_scope,key,request_hash,created_by,expires_at)values(v_rp.provider_organization_id,'quote.revision.create',p_idempotency_key,v_hash,v_actor,v_now+interval'7 days');
 select * into v_quote from public.quotes where rfq_id=v_rp.rfq_id and provider_organization_id=v_rp.provider_organization_id for update;
 if not found then insert into public.quotes(rfq_id,rfq_provider_id,provider_organization_id,created_by)values(v_rp.rfq_id,p_rfq_provider_id,v_rp.provider_organization_id,v_actor)returning * into v_quote;
 elsif v_quote.status not in('DRAFT','REVISION_REQUESTED','REVISED') then raise exception 'QUOTE_REVISION_NOT_ALLOWED' using errcode='55000';end if;
 select coalesce(max(version_number),0)+1 into v_number from public.quote_versions where quote_id=v_quote.id;
 for v_line in select value from jsonb_array_elements(p_payload->'items') order by (value->>'line_number')::int loop
  select * into strict v_tax from public.tax_rule_versions where id=(v_line->>'tax_rule_version_id')::uuid and jurisdiction_code='MA';
  v_sub:=round((v_line->>'quantity')::numeric*(v_line->>'unit_price_minor')::bigint)::bigint;
  v_tax_minor:=round(v_sub::numeric*v_tax.rate_basis_points::numeric/10000)::bigint;
  v_total_sub:=v_total_sub+v_sub;v_total_tax:=v_total_tax+v_tax_minor;
  if v_line->>'item_kind'='RECURRING'then v_recurring:=v_recurring+v_sub;end if;
  v_basis:=v_basis||jsonb_build_array(jsonb_build_object('line_number',(v_line->>'line_number')::int,'tax_rule_version_id',v_tax.id,'tax_rate_basis_points',v_tax.rate_basis_points,'rounding','HALF_AWAY_FROM_ZERO_TO_MINOR_UNIT'));
 end loop;
 insert into public.quote_versions(quote_id,rfq_id,provider_organization_id,version_number,supersedes_id,lifecycle_status,change_reason,currency,solution_fr,solution_ar,deliverables,inclusions,exclusions,prerequisites,warranty_fr,warranty_ar,correction_terms_fr,correction_terms_ar,sla,proposed_start_date,duration_days,valid_until,subtotal_minor,tax_minor,total_minor,recurring_subtotal_minor,calculation_basis,content_hash,created_by)
 values(v_quote.id,v_rp.rfq_id,v_rp.provider_organization_id,v_number,v_quote.current_version_id,case when v_number=1 then'DRAFT'else'DRAFT'end,btrim(p_change_reason),p_payload->>'currency',btrim(p_payload->>'solution_fr'),nullif(btrim(p_payload->>'solution_ar'),''),p_payload->'deliverables',coalesce(p_payload->'inclusions','[]'::jsonb),coalesce(p_payload->'exclusions','[]'::jsonb),coalesce(p_payload->'prerequisites','[]'::jsonb),btrim(p_payload->>'warranty_fr'),nullif(btrim(p_payload->>'warranty_ar'),''),btrim(p_payload->>'correction_terms_fr'),nullif(btrim(p_payload->>'correction_terms_ar'),''),coalesce(p_payload->'sla','{}'::jsonb),(p_payload->>'proposed_start_date')::date,(p_payload->>'duration_days')::int,(p_payload->>'valid_until')::timestamptz,v_total_sub,v_total_tax,v_total_sub+v_total_tax,v_recurring,jsonb_build_object('money','MINOR_UNITS','quantity','NUMERIC_18_4','tax_lines',v_basis),v_hash,v_actor)returning id into v_version;
 for v_line in select value from jsonb_array_elements(p_payload->'items') order by (value->>'line_number')::int loop
  select * into strict v_tax from public.tax_rule_versions where id=(v_line->>'tax_rule_version_id')::uuid;
  v_sub:=round((v_line->>'quantity')::numeric*(v_line->>'unit_price_minor')::bigint)::bigint;v_tax_minor:=round(v_sub::numeric*v_tax.rate_basis_points::numeric/10000)::bigint;
  insert into public.quote_items(quote_version_id,line_number,item_kind,label_fr,label_ar,quantity,unit_code,unit_price_minor,subtotal_minor,tax_rule_version_id,tax_rate_basis_points,tax_minor,total_minor,recurrence_interval)
  values(v_version,(v_line->>'line_number')::int,v_line->>'item_kind',btrim(v_line->>'label_fr'),nullif(btrim(v_line->>'label_ar'),''),(v_line->>'quantity')::numeric,v_line->>'unit_code',(v_line->>'unit_price_minor')::bigint,v_sub,v_tax.id,v_tax.rate_basis_points,v_tax_minor,v_sub+v_tax_minor,nullif(v_line->>'recurrence_interval',''));
 end loop;
 update public.quotes set current_version_id=v_version,status=case when v_number=1 then'DRAFT'else'REVISED'end where id=v_quote.id;
 update public.quote_revision_requests set status='FULFILLED',resolved_at=v_now where quote_id=v_quote.id and status='OPEN';
 v_response:=jsonb_build_object('outcome','QUOTE_REVISION_CREATED','quote_id',v_quote.id,'quote_version_id',v_version,'version_number',v_number,'currency',p_payload->>'currency','subtotal_minor',v_total_sub,'tax_minor',v_total_tax,'total_minor',v_total_sub+v_total_tax);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_rp.provider_organization_id,v_actor,'USER','quote.revision.created','quote_version',v_version::text,p_correlation_id,jsonb_build_object('quote_id',v_quote.id,'version_number',v_number,'content_hash',v_hash),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(v_rp.provider_organization_id,'quote',v_quote.id::text,'QuoteRevisionCreatedV1',p_correlation_id,jsonb_build_object('quote_id',v_quote.id,'quote_version_id',v_version,'rfq_id',v_rp.rfq_id,'version_number',v_number));
 update public.idempotency_keys set status='COMPLETED',response_code=201,response_body=v_response,completed_at=clock_timestamp()where organization_id=v_rp.provider_organization_id and operation_scope='quote.revision.create'and key=p_idempotency_key;
 return v_response;
exception when no_data_found then raise exception 'QUOTE_TAX_RULE_INVALID' using errcode='22023';end;$$;

create or replace function public.submit_quote(p_quote_id uuid,p_expected_version_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_q public.quotes%rowtype;v_v public.quote_versions%rowtype;v_hash text;v_existing public.idempotency_keys%rowtype;v_response jsonb;v_now timestamptz:=clock_timestamp();
begin
 if v_actor is null then raise exception'UNAUTHENTICATED'using errcode='42501';end if;
 select q.* into v_q from public.quotes q join public.rfqs r on r.id=q.rfq_id where q.id=p_quote_id and r.status='OPEN'and r.deadline>v_now for update of q;
 if not found then raise exception'QUOTE_NOT_SUBMITTABLE'using errcode='55000';end if;
 if not private.has_org_role(v_q.provider_organization_id,array['PROVIDER_OWNER','PROVIDER_MANAGER','PROVIDER_SALES'],v_actor)then raise exception'QUOTE_PROVIDER_SCOPE_DENIED'using errcode='42501';end if;
 select * into strict v_v from public.quote_versions where id=p_expected_version_id and quote_id=v_q.id for update;
 if v_q.current_version_id<>p_expected_version_id or v_v.lifecycle_status<>'DRAFT' then raise exception'QUOTE_VERSION_STALE'using errcode='40001';end if;
 if v_v.valid_until<=v_now or not exists(select 1 from public.quote_items where quote_version_id=v_v.id)then raise exception'QUOTE_INCOMPLETE_OR_EXPIRED'using errcode='55000';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','quote.submit.v1','quote_id',p_quote_id,'version_id',p_expected_version_id));perform pg_advisory_xact_lock(hashtextextended(v_q.provider_organization_id::text||':quote.submit:'||p_idempotency_key,0));
 select * into v_existing from public.idempotency_keys where organization_id=v_q.provider_organization_id and operation_scope='quote.submit'and key=p_idempotency_key;if found then if v_existing.request_hash<>v_hash then raise exception'IDEMPOTENCY_PAYLOAD_MISMATCH'using errcode='22000';end if;if v_existing.status='COMPLETED'then return v_existing.response_body;end if;raise exception'IDEMPOTENCY_IN_PROGRESS'using errcode='55000';end if;
 insert into public.idempotency_keys(organization_id,operation_scope,key,request_hash,created_by,expires_at)values(v_q.provider_organization_id,'quote.submit',p_idempotency_key,v_hash,v_actor,v_now+interval'7 days');
 update public.quote_versions set lifecycle_status=case when version_number=1 then'SUBMITTED'else'REVISED'end,submitted_at=v_now where id=v_v.id;
 update public.quotes set status='SUBMITTED'where id=v_q.id;
 v_response:=jsonb_build_object('outcome','QUOTE_SUBMITTED','quote_id',v_q.id,'quote_version_id',v_v.id,'version_number',v_v.version_number);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_q.provider_organization_id,v_actor,'USER','quote.submitted','quote',v_q.id::text,p_correlation_id,jsonb_build_object('quote_version_id',v_v.id,'version_number',v_v.version_number),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(v_q.provider_organization_id,'quote',v_q.id::text,'QuoteSubmittedV1',p_correlation_id,jsonb_build_object('quote_id',v_q.id,'quote_version_id',v_v.id,'rfq_id',v_q.rfq_id));
 update public.idempotency_keys set status='COMPLETED',response_code=200,response_body=v_response,completed_at=clock_timestamp()where organization_id=v_q.provider_organization_id and operation_scope='quote.submit'and key=p_idempotency_key;return v_response;
exception when no_data_found then raise exception'QUOTE_VERSION_NOT_FOUND'using errcode='P0002';end;$$;

create or replace function public.request_quote_revision(p_quote_id uuid,p_expected_version_id uuid,p_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_q public.quotes%rowtype;v_client uuid;v_hash text;v_existing public.idempotency_keys%rowtype;v_request uuid;v_response jsonb;v_now timestamptz:=clock_timestamp();
begin
 if v_actor is null then raise exception'UNAUTHENTICATED'using errcode='42501';end if;
 select q.* into v_q from public.quotes q where q.id=p_quote_id for update;
 if not found then raise exception'QUOTE_NOT_FOUND'using errcode='P0002';end if;
 select sr.client_organization_id into strict v_client from public.rfqs r join public.service_requests sr on sr.id=r.request_id where r.id=v_q.rfq_id;
 if not private.has_org_role(v_client,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],v_actor)then raise exception'QUOTE_CLIENT_SCOPE_DENIED'using errcode='42501';end if;
 if v_q.status<>'SUBMITTED'or v_q.current_version_id<>p_expected_version_id or length(btrim(coalesce(p_reason,'')))not between 3 and 2000 or length(coalesce(p_idempotency_key,''))not between 8 and 200 then raise exception'QUOTE_REVISION_REQUEST_INVALID'using errcode='55000';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','quote.revision.request.v1','quote_id',p_quote_id,'version_id',p_expected_version_id,'reason',btrim(p_reason)));perform pg_advisory_xact_lock(hashtextextended(v_client::text||':quote.revision.request:'||p_idempotency_key,0));
 select * into v_existing from public.idempotency_keys where organization_id=v_client and operation_scope='quote.revision.request'and key=p_idempotency_key;if found then if v_existing.request_hash<>v_hash then raise exception'IDEMPOTENCY_PAYLOAD_MISMATCH'using errcode='22000';end if;if v_existing.status='COMPLETED'then return v_existing.response_body;end if;raise exception'IDEMPOTENCY_IN_PROGRESS'using errcode='55000';end if;
 insert into public.idempotency_keys(organization_id,operation_scope,key,request_hash,created_by,expires_at)values(v_client,'quote.revision.request',p_idempotency_key,v_hash,v_actor,v_now+interval'7 days');
 insert into public.quote_revision_requests(quote_id,requested_from_version_id,requested_by,reason)values(v_q.id,p_expected_version_id,v_actor,btrim(p_reason))returning id into v_request;
 update public.quotes set status='REVISION_REQUESTED'where id=v_q.id;
 v_response:=jsonb_build_object('outcome','QUOTE_REVISION_REQUESTED','quote_id',v_q.id,'quote_version_id',p_expected_version_id,'revision_request_id',v_request);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_client,v_actor,'USER','quote.revision.requested','quote',v_q.id::text,p_correlation_id,jsonb_build_object('quote_version_id',p_expected_version_id,'revision_request_id',v_request),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(v_client,'quote',v_q.id::text,'QuoteRevisionRequestedV1',p_correlation_id,jsonb_build_object('quote_id',v_q.id,'quote_version_id',p_expected_version_id,'revision_request_id',v_request,'provider_organization_id',v_q.provider_organization_id));
 update public.idempotency_keys set status='COMPLETED',response_code=200,response_body=v_response,completed_at=clock_timestamp()where organization_id=v_client and operation_scope='quote.revision.request'and key=p_idempotency_key;return v_response;
end;$$;

create or replace function public.compare_quotes(p_rfq_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_client uuid;v_hash text;v_existing public.idempotency_keys%rowtype;v_currency text;v_count int;v_rows jsonb;v_snapshot uuid;v_response jsonb;v_now timestamptz:=clock_timestamp();
begin
 if v_actor is null then raise exception'UNAUTHENTICATED'using errcode='42501';end if;
 select sr.client_organization_id into v_client from public.rfqs r join public.service_requests sr on sr.id=r.request_id where r.id=p_rfq_id for update of r;
 if not found then raise exception'RFQ_NOT_FOUND'using errcode='P0002';end if;
 if not private.has_org_role(v_client,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],v_actor)then raise exception'QUOTE_CLIENT_SCOPE_DENIED'using errcode='42501';end if;
 if length(coalesce(p_idempotency_key,''))not between 8 and 200 then raise exception'QUOTE_COMMAND_INVALID'using errcode='22023';end if;
 select count(*),min(v.currency)into v_count,v_currency from public.quotes q join public.quote_versions v on v.id=q.current_version_id where q.rfq_id=p_rfq_id and q.status='SUBMITTED'and v.lifecycle_status in('SUBMITTED','REVISED');
 if v_count=0 then raise exception'NO_COMPARABLE_QUOTES'using errcode='55000';end if;
 if (select count(distinct v.currency)from public.quotes q join public.quote_versions v on v.id=q.current_version_id where q.rfq_id=p_rfq_id and q.status='SUBMITTED')<>1 then raise exception'QUOTE_CURRENCY_MISMATCH'using errcode='22000';end if;
 select jsonb_agg(jsonb_build_object('quote_id',x.quote_id,'quote_version_id',x.version_id,'version_number',x.version_number,'provider_organization_id',x.provider_organization_id,'currency',x.currency,'subtotal_minor',x.subtotal_minor,'tax_minor',x.tax_minor,'total_minor',x.total_minor,'recurring_subtotal_minor',x.recurring_subtotal_minor,'duration_days',x.duration_days,'deliverables_count',x.deliverables_count,'valid_until',x.valid_until,'price_rank',x.price_rank,'explanation',jsonb_build_array('Totals are server-computed from exact quantities and minor-unit prices','Tax uses the persisted Moroccan tax rule version on every line','Rank compares equal currency and frozen current submitted revisions'))order by x.price_rank,x.total_minor,x.version_id)
 into v_rows from(select q.id quote_id,v.id version_id,v.version_number,q.provider_organization_id,v.currency,v.subtotal_minor,v.tax_minor,v.total_minor,v.recurring_subtotal_minor,v.duration_days,jsonb_array_length(v.deliverables)deliverables_count,v.valid_until,dense_rank()over(order by v.total_minor,v.id)price_rank from public.quotes q join public.quote_versions v on v.id=q.current_version_id where q.rfq_id=p_rfq_id and q.status='SUBMITTED'and v.lifecycle_status in('SUBMITTED','REVISED'))x;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','quote.compare.v1','rfq_id',p_rfq_id,'normalization_version','QUOTE_COMPARE_V1','rows',v_rows));perform pg_advisory_xact_lock(hashtextextended(v_client::text||':quote.compare:'||p_idempotency_key,0));
 select * into v_existing from public.idempotency_keys where organization_id=v_client and operation_scope='quote.compare'and key=p_idempotency_key;if found then if v_existing.request_hash<>v_hash then raise exception'IDEMPOTENCY_PAYLOAD_MISMATCH'using errcode='22000';end if;if v_existing.status='COMPLETED'then return v_existing.response_body;end if;raise exception'IDEMPOTENCY_IN_PROGRESS'using errcode='55000';end if;
 insert into public.idempotency_keys(organization_id,operation_scope,key,request_hash,created_by,expires_at)values(v_client,'quote.compare',p_idempotency_key,v_hash,v_actor,v_now+interval'7 days');
 insert into public.quote_comparison_snapshots(rfq_id,client_organization_id,normalization_version,quote_version_ids,currency,comparison,input_hash,created_by)values(p_rfq_id,v_client,'QUOTE_COMPARE_V1',array(select (e->>'quote_version_id')::uuid from jsonb_array_elements(v_rows)e),v_currency,jsonb_build_object('criteria',jsonb_build_array('TOTAL_MINOR','RECURRING_SUBTOTAL_MINOR','DURATION_DAYS','DELIVERABLES_COUNT','VALID_UNTIL'),'tax_basis','VERSIONED_MA_RULE_PER_LINE','rows',v_rows),v_hash,v_actor)returning id into v_snapshot;
 v_response:=jsonb_build_object('outcome','QUOTE_COMPARISON_CREATED','comparison_snapshot_id',v_snapshot,'rfq_id',p_rfq_id,'normalization_version','QUOTE_COMPARE_V1','currency',v_currency,'quote_count',v_count,'rows',v_rows);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_client,v_actor,'USER','quote.comparison.created','quote_comparison_snapshot',v_snapshot::text,p_correlation_id,jsonb_build_object('rfq_id',p_rfq_id,'input_hash',v_hash,'quote_count',v_count),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(v_client,'rfq',p_rfq_id::text,'QuoteComparisonCreatedV1',p_correlation_id,jsonb_build_object('rfq_id',p_rfq_id,'comparison_snapshot_id',v_snapshot,'normalization_version','QUOTE_COMPARE_V1','quote_count',v_count));
 update public.idempotency_keys set status='COMPLETED',response_code=201,response_body=v_response,completed_at=clock_timestamp()where organization_id=v_client and operation_scope='quote.compare'and key=p_idempotency_key;return v_response;
end;$$;

create or replace function public.select_quote(p_quote_id uuid,p_expected_version_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_q public.quotes%rowtype;v_client uuid;v_v public.quote_versions%rowtype;v_hash text;v_existing public.idempotency_keys%rowtype;v_response jsonb;v_now timestamptz:=clock_timestamp();
begin
 if v_actor is null then raise exception'UNAUTHENTICATED'using errcode='42501';end if;
 select q.* into v_q from public.quotes q where q.id=p_quote_id for update;
 if not found then raise exception'QUOTE_NOT_FOUND'using errcode='P0002';end if;
 select sr.client_organization_id into strict v_client from public.rfqs r join public.service_requests sr on sr.id=r.request_id where r.id=v_q.rfq_id;
 if not private.has_org_role(v_client,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],v_actor)then raise exception'QUOTE_CLIENT_SCOPE_DENIED'using errcode='42501';end if;
 select * into strict v_v from public.quote_versions where id=p_expected_version_id and quote_id=v_q.id;
 if v_q.status<>'SUBMITTED'or v_q.current_version_id<>p_expected_version_id or v_v.lifecycle_status not in('SUBMITTED','REVISED')or v_v.valid_until<=v_now then raise exception'QUOTE_SELECTION_STALE_OR_INVALID'using errcode='40001';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','quote.select.v1','quote_id',p_quote_id,'version_id',p_expected_version_id));perform pg_advisory_xact_lock(hashtextextended(v_client::text||':quote.select:'||p_idempotency_key,0));
 select * into v_existing from public.idempotency_keys where organization_id=v_client and operation_scope='quote.select'and key=p_idempotency_key;if found then if v_existing.request_hash<>v_hash then raise exception'IDEMPOTENCY_PAYLOAD_MISMATCH'using errcode='22000';end if;if v_existing.status='COMPLETED'then return v_existing.response_body;end if;raise exception'IDEMPOTENCY_IN_PROGRESS'using errcode='55000';end if;
 insert into public.idempotency_keys(organization_id,operation_scope,key,request_hash,created_by,expires_at)values(v_client,'quote.select',p_idempotency_key,v_hash,v_actor,v_now+interval'7 days');
 perform 1 from public.quotes where rfq_id=v_q.rfq_id for update;
 update public.quotes set status='NOT_SELECTED'where rfq_id=v_q.rfq_id and id<>v_q.id and status='SUBMITTED';
 update public.quotes set status='SELECTED',selected_version_id=p_expected_version_id where id=v_q.id;
 v_response:=jsonb_build_object('outcome','QUOTE_SELECTED','quote_id',v_q.id,'quote_version_id',p_expected_version_id,'rfq_id',v_q.rfq_id);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(v_client,v_actor,'USER','quote.selected','quote',v_q.id::text,p_correlation_id,jsonb_build_object('quote_version_id',p_expected_version_id,'rfq_id',v_q.rfq_id,'total_minor',v_v.total_minor,'currency',v_v.currency),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(v_client,'quote',v_q.id::text,'QuoteSelectedV1',p_correlation_id,jsonb_build_object('quote_id',v_q.id,'quote_version_id',p_expected_version_id,'rfq_id',v_q.rfq_id,'provider_organization_id',v_q.provider_organization_id));
 update public.idempotency_keys set status='COMPLETED',response_code=200,response_body=v_response,completed_at=clock_timestamp()where organization_id=v_client and operation_scope='quote.select'and key=p_idempotency_key;return v_response;
exception when no_data_found then raise exception'QUOTE_VERSION_NOT_FOUND'using errcode='P0002';end;$$;

create or replace function private.prevent_submitted_quote_version_mutation()returns trigger language plpgsql set search_path=pg_catalog as $$begin if old.lifecycle_status<>'DRAFT'or new.lifecycle_status not in('SUBMITTED','REVISED')or (to_jsonb(new)-'lifecycle_status'-'submitted_at')is distinct from(to_jsonb(old)-'lifecycle_status'-'submitted_at')or new.submitted_at is null then raise exception'IMMUTABLE_QUOTE_VERSION'using errcode='55000';end if;return new;end;$$;
create or replace function private.guard_quote_revision_request_update()returns trigger language plpgsql set search_path=pg_catalog as $$begin if old.status<>'OPEN'or new.status<>'FULFILLED'or new.resolved_at is null or(to_jsonb(new)-'status'-'resolved_at')is distinct from(to_jsonb(old)-'status'-'resolved_at')then raise exception'IMMUTABLE_QUOTE_REVISION_REQUEST'using errcode='55000';end if;return new;end;$$;
create trigger quote_versions_guard before update on public.quote_versions for each row execute function private.prevent_submitted_quote_version_mutation();
create trigger quote_versions_no_delete before delete on public.quote_versions for each row execute function private.prevent_update_delete();
create trigger quote_items_immutable before update or delete on public.quote_items for each row execute function private.prevent_update_delete();
create trigger quote_options_immutable before update or delete on public.quote_options for each row execute function private.prevent_update_delete();
create trigger quote_revision_requests_guard before update on public.quote_revision_requests for each row execute function private.guard_quote_revision_request_update();
create trigger quote_revision_requests_no_delete before delete on public.quote_revision_requests for each row execute function private.prevent_update_delete();
create trigger quote_comparisons_immutable before update or delete on public.quote_comparison_snapshots for each row execute function private.prevent_update_delete();
create trigger quotes_updated_at before update on public.quotes for each row execute function private.set_updated_at();

alter table public.quotes enable row level security;alter table public.quote_versions enable row level security;alter table public.quote_items enable row level security;alter table public.quote_options enable row level security;alter table public.quote_revision_requests enable row level security;alter table public.quote_comparison_snapshots enable row level security;
revoke all on public.quotes,public.quote_versions,public.quote_items,public.quote_options,public.quote_revision_requests,public.quote_comparison_snapshots from public,anon,authenticated,service_role;
grant select on public.quotes,public.quote_versions,public.quote_items,public.quote_options,public.quote_revision_requests,public.quote_comparison_snapshots to authenticated;
create policy quotes_read on public.quotes for select to authenticated using(private.can_read_quote(id));
create policy quote_versions_read on public.quote_versions for select to authenticated using(private.can_read_quote(quote_id));
create policy quote_items_read on public.quote_items for select to authenticated using(exists(select 1 from public.quote_versions v where v.id=quote_version_id and private.can_read_quote(v.quote_id)));
create policy quote_options_read on public.quote_options for select to authenticated using(exists(select 1 from public.quote_versions v where v.id=quote_version_id and private.can_read_quote(v.quote_id)));
create policy quote_revision_requests_read on public.quote_revision_requests for select to authenticated using(private.can_read_quote(quote_id));
create policy quote_comparisons_client_read on public.quote_comparison_snapshots for select to authenticated using(private.has_org_role(client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER','CLIENT_VIEWER'])or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
revoke all on function private.can_read_quote(uuid,uuid),private.assert_quote_payload(jsonb),private.prevent_submitted_quote_version_mutation(),private.guard_quote_revision_request_update()from public,anon;
grant execute on function private.can_read_quote(uuid,uuid)to authenticated;
revoke all on function public.create_quote_revision(uuid,jsonb,text,text,uuid),public.submit_quote(uuid,uuid,text,uuid),public.request_quote_revision(uuid,uuid,text,text,uuid),public.compare_quotes(uuid,text,uuid),public.select_quote(uuid,uuid,text,uuid)from public,anon,service_role;
grant execute on function public.create_quote_revision(uuid,jsonb,text,text,uuid),public.submit_quote(uuid,uuid,text,uuid),public.request_quote_revision(uuid,uuid,text,text,uuid),public.compare_quotes(uuid,text,uuid),public.select_quote(uuid,uuid,text,uuid)to authenticated;
