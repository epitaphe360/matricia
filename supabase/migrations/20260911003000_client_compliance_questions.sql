-- P05 administrative anomalies, compliance questions and versioned responses.

create table public.client_administrative_anomalies (
  id uuid primary key default extensions.gen_random_uuid(),
  compliance_case_id uuid not null,
  organization_id uuid not null,
  anomaly_code text not null check (anomaly_code ~ '^[A-Z][A-Z0-9_]{2,79}$'),
  field_path text not null check (length(field_path) between 2 and 160),
  severity text not null check (severity in ('INFO','WARNING','CRITICAL')),
  blocking boolean not null,
  status text not null default 'OPEN' check (status in ('OPEN','QUESTIONED','RESOLVED','ACCEPTED_EXCEPTION')),
  client_message_fr text not null check (length(btrim(client_message_fr)) between 3 and 500),
  client_message_ar text not null check (length(btrim(client_message_ar)) between 3 and 500),
  entered_value_digest text check (entered_value_digest is null or entered_value_digest ~ '^[0-9a-f]{64}$'),
  observed_value_digest text check (observed_value_digest is null or observed_value_digest ~ '^[0-9a-f]{64}$'),
  detected_by text not null check (detected_by in ('RULE_ENGINE','COMPLIANCE_REVIEWER')),
  resolved_by uuid references auth.users(id),
  resolved_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check (row_version > 0),
  unique (compliance_case_id, anomaly_code),
  foreign key (compliance_case_id, organization_id)
    references public.client_compliance_cases(id, organization_id) on delete restrict,
  check ((status in ('RESOLVED','ACCEPTED_EXCEPTION')) = (resolved_by is not null and resolved_at is not null))
);

create table public.client_compliance_questions (
  id uuid primary key default extensions.gen_random_uuid(),
  compliance_case_id uuid not null,
  organization_id uuid not null,
  anomaly_id uuid,
  question_text_fr text not null check (length(btrim(question_text_fr)) between 3 and 1000),
  question_text_ar text not null check (length(btrim(question_text_ar)) between 3 and 1000),
  expected_document_type text check (expected_document_type is null or expected_document_type ~ '^[A-Z][A-Z0-9_]{2,79}$'),
  due_at timestamptz not null,
  status text not null default 'OPEN' check (status in ('OPEN','ANSWERED','ACCEPTED','CLOSED')),
  created_by uuid not null references auth.users(id),
  accepted_by uuid references auth.users(id),
  accepted_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check (row_version > 0),
  unique (id, organization_id),
  foreign key (compliance_case_id, organization_id)
    references public.client_compliance_cases(id, organization_id) on delete restrict,
  foreign key (anomaly_id) references public.client_administrative_anomalies(id) on delete restrict,
  check (due_at > created_at),
  check ((status = 'ACCEPTED') = (accepted_by is not null and accepted_at is not null))
);

create table public.client_compliance_response_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  question_id uuid not null,
  organization_id uuid not null,
  version integer not null check (version > 0),
  response_text text not null check (length(btrim(response_text)) between 3 and 4000),
  submitted_by uuid not null references auth.users(id),
  submitted_at timestamptz not null default clock_timestamp(),
  unique (question_id, version),
  foreign key (question_id, organization_id)
    references public.client_compliance_questions(id, organization_id) on delete restrict
);

create or replace function private.prevent_compliance_history_mutation()
returns trigger language plpgsql security definer set search_path = pg_catalog
as $$ begin raise exception 'IMMUTABLE_RECORD' using errcode = '55000'; end; $$;
revoke all on function private.prevent_compliance_history_mutation() from public, anon, authenticated, service_role;
create trigger client_compliance_responses_immutable
before update or delete on public.client_compliance_response_versions
for each row execute function private.prevent_compliance_history_mutation();

alter table public.client_administrative_anomalies enable row level security;
alter table public.client_compliance_questions enable row level security;
alter table public.client_compliance_response_versions enable row level security;
revoke all on public.client_administrative_anomalies, public.client_compliance_questions,
  public.client_compliance_response_versions from public, anon, authenticated, service_role;
grant select on public.client_administrative_anomalies, public.client_compliance_questions,
  public.client_compliance_response_versions to authenticated;

create policy client_administrative_anomalies_read on public.client_administrative_anomalies
for select to authenticated using (
  private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],auth.uid())
  or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],auth.uid())
);
create policy client_compliance_questions_read on public.client_compliance_questions
for select to authenticated using (
  private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],auth.uid())
  or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],auth.uid())
);
create policy client_compliance_responses_read on public.client_compliance_response_versions
for select to authenticated using (
  private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],auth.uid())
  or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],auth.uid())
);

create index client_anomalies_case_status_idx on public.client_administrative_anomalies(compliance_case_id,status,blocking);
create index client_questions_case_status_due_idx on public.client_compliance_questions(compliance_case_id,status,due_at);
create unique index client_questions_one_active_per_anomaly_uidx
  on public.client_compliance_questions(anomaly_id)
  where anomaly_id is not null and status in ('OPEN','ANSWERED');
create index client_responses_question_version_idx on public.client_compliance_response_versions(question_id,version desc);

create function public.evaluate_client_compliance(
  p_compliance_case_id uuid,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer set search_path = pg_catalog, private
as $$
declare
  v_actor uuid := auth.uid();
  v_case public.client_compliance_cases%rowtype;
  v_code text;
  v_missing boolean;
  v_open integer;
  v_hash text;
  v_existing public.idempotency_keys%rowtype;
  v_response jsonb;
begin
  if v_actor is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],v_actor) then
    raise exception 'CENTRAL_COMPLIANCE_REVIEW_REQUIRED' using errcode='42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('client-compliance-case:'||p_compliance_case_id::text,0));
  select * into v_case from public.client_compliance_cases where id=p_compliance_case_id for update;
  if not found then raise exception 'COMPLIANCE_CASE_NOT_FOUND' using errcode='P0002'; end if;
  if length(coalesce(p_idempotency_key,'')) not between 8 and 200 then raise exception 'INVALID_IDEMPOTENCY_KEY' using errcode='22023'; end if;
  v_hash := private.canonical_request_hash(jsonb_build_object('operation','client.compliance.evaluate.v1','case_id',p_compliance_case_id,'profile_version',v_case.current_profile_version));
  perform pg_advisory_xact_lock(hashtextextended(v_case.organization_id::text||':client.compliance.evaluate:'||p_idempotency_key,0));
  select * into v_existing from public.idempotency_keys where organization_id=v_case.organization_id and operation_scope='client.compliance.evaluate' and key=p_idempotency_key;
  if found then
    if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if;
    if v_existing.status='COMPLETED' then return v_existing.response_body; end if;
    raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000';
  end if;
  insert into public.idempotency_keys(organization_id,operation_scope,key,request_hash,created_by,expires_at)
  values(v_case.organization_id,'client.compliance.evaluate',p_idempotency_key,v_hash,v_actor,clock_timestamp()+interval '7 days');

  foreach v_code in array array['ICE','IF','RC'] loop
    v_missing := not exists(select 1 from public.organization_identifiers i where i.organization_id=v_case.organization_id and i.identifier_type=v_code and i.is_active and i.verification_status='VERIFIED');
    if v_missing then
      insert into public.client_administrative_anomalies(compliance_case_id,organization_id,anomaly_code,field_path,severity,blocking,status,client_message_fr,client_message_ar,detected_by)
      values(v_case.id,v_case.organization_id,v_code||'_NOT_VERIFIED','identifiers.'||lower(v_code),'CRITICAL',true,'OPEN','L’identifiant '||v_code||' doit être vérifié.','يجب التحقق من المعرّف '||v_code||'.','RULE_ENGINE')
      on conflict(compliance_case_id,anomaly_code) do update set status='OPEN',resolved_by=null,resolved_at=null,updated_at=clock_timestamp(),row_version=public.client_administrative_anomalies.row_version+1;
    else
      update public.client_administrative_anomalies set status='RESOLVED',resolved_by=v_actor,resolved_at=clock_timestamp(),updated_at=clock_timestamp(),row_version=row_version+1
      where compliance_case_id=v_case.id and anomaly_code=v_code||'_NOT_VERIFIED' and status not in ('RESOLVED','ACCEPTED_EXCEPTION');
    end if;
  end loop;
  foreach v_code in array array['REGISTRATION_DOCUMENT','REPRESENTATIVE_AUTHORITY'] loop
    v_missing := not exists(select 1 from public.client_compliance_evidence e where e.compliance_case_id=v_case.id and e.evidence_type=v_code and e.review_status='VERIFIED');
    if v_missing then
      insert into public.client_administrative_anomalies(compliance_case_id,organization_id,anomaly_code,field_path,severity,blocking,status,client_message_fr,client_message_ar,detected_by)
      values(v_case.id,v_case.organization_id,v_code||'_MISSING','documents.'||lower(v_code),'CRITICAL',true,'OPEN','Le document requis doit être validé.','يجب اعتماد الوثيقة المطلوبة.','RULE_ENGINE')
      on conflict(compliance_case_id,anomaly_code) do update set status='OPEN',resolved_by=null,resolved_at=null,updated_at=clock_timestamp(),row_version=public.client_administrative_anomalies.row_version+1;
    else
      update public.client_administrative_anomalies set status='RESOLVED',resolved_by=v_actor,resolved_at=clock_timestamp(),updated_at=clock_timestamp(),row_version=row_version+1
      where compliance_case_id=v_case.id and anomaly_code=v_code||'_MISSING' and status not in ('RESOLVED','ACCEPTED_EXCEPTION');
    end if;
  end loop;
  select count(*) into v_open from public.client_administrative_anomalies where compliance_case_id=v_case.id and blocking and status in ('OPEN','QUESTIONED');
  if v_case.status in ('PROFILE_IN_PROGRESS','DOCUMENTS_REQUIRED') then
    update public.client_compliance_cases set status=case when v_open>0 then 'DOCUMENTS_REQUIRED' else 'PROFILE_IN_PROGRESS' end where id=v_case.id;
  end if;
  v_response:=jsonb_build_object('outcome','CLIENT_COMPLIANCE_EVALUATED','compliance_case_id',v_case.id,'blocking_anomalies',v_open);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
  values(v_case.organization_id,v_actor,'USER','client.compliance.evaluated','client_compliance_case',v_case.id::text,p_correlation_id,jsonb_build_object('blocking_anomalies',v_open),null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)
  values(v_case.organization_id,'client_compliance_case',v_case.id::text,'ClientComplianceEvaluatedV1',p_correlation_id,jsonb_build_object('compliance_case_id',v_case.id,'blocking_anomalies',v_open));
  update public.idempotency_keys set status='COMPLETED',response_code=200,response_body=v_response,completed_at=clock_timestamp()
  where organization_id=v_case.organization_id and operation_scope='client.compliance.evaluate' and key=p_idempotency_key;
  return v_response;
end;
$$;

create function public.create_client_compliance_question(
  p_anomaly_id uuid,
  p_question_text_fr text,
  p_question_text_ar text,
  p_expected_document_type text,
  p_due_at timestamptz,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns uuid
language plpgsql security definer set search_path = pg_catalog, private
as $$
declare v_actor uuid:=auth.uid(); v_anomaly public.client_administrative_anomalies%rowtype; v_id uuid; v_hash text; v_existing public.idempotency_keys%rowtype;
begin
  if v_actor is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],v_actor) then raise exception 'CENTRAL_COMPLIANCE_REVIEW_REQUIRED' using errcode='42501'; end if;
  select * into v_anomaly from public.client_administrative_anomalies where id=p_anomaly_id;
  if not found then raise exception 'ANOMALY_NOT_FOUND' using errcode='P0002'; end if;
  perform pg_advisory_xact_lock(hashtextextended('client-compliance-case:'||v_anomaly.compliance_case_id::text,0));
  perform 1 from public.client_compliance_cases where id=v_anomaly.compliance_case_id for update;
  select * into v_anomaly from public.client_administrative_anomalies where id=p_anomaly_id for update;
  if v_anomaly.status not in ('OPEN','QUESTIONED') or length(btrim(coalesce(p_question_text_fr,''))) not between 3 and 1000 or length(btrim(coalesce(p_question_text_ar,''))) not between 3 and 1000 or p_due_at<=clock_timestamp() or length(coalesce(p_idempotency_key,'')) not between 8 and 200 then raise exception 'INVALID_COMPLIANCE_QUESTION' using errcode='22023'; end if;
  v_hash:=private.canonical_request_hash(jsonb_build_object('operation','client.compliance.question.create.v1','anomaly_id',p_anomaly_id,'question_fr',btrim(p_question_text_fr),'question_ar',btrim(p_question_text_ar),'expected_document_type',p_expected_document_type,'due_at',p_due_at));
  select * into v_existing from public.idempotency_keys where organization_id=v_anomaly.organization_id and operation_scope='client.compliance.question.create' and key=p_idempotency_key;
  if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.status='COMPLETED' then return (v_existing.response_body->>'question_id')::uuid; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
  if exists(select 1 from public.client_compliance_questions question where question.anomaly_id=v_anomaly.id and question.status in ('OPEN','ANSWERED')) then raise exception 'ACTIVE_COMPLIANCE_QUESTION_EXISTS' using errcode='55000'; end if;
  insert into public.idempotency_keys(organization_id,operation_scope,key,request_hash,created_by,expires_at) values(v_anomaly.organization_id,'client.compliance.question.create',p_idempotency_key,v_hash,v_actor,clock_timestamp()+interval '7 days');
  insert into public.client_compliance_questions(compliance_case_id,organization_id,anomaly_id,question_text_fr,question_text_ar,expected_document_type,due_at,created_by)
  values(v_anomaly.compliance_case_id,v_anomaly.organization_id,v_anomaly.id,btrim(p_question_text_fr),btrim(p_question_text_ar),p_expected_document_type,p_due_at,v_actor) returning id into v_id;
  update public.client_administrative_anomalies set status='QUESTIONED',updated_at=clock_timestamp(),row_version=row_version+1 where id=v_anomaly.id;
  update public.client_compliance_cases set status='QUESTION_REQUIRED',decided_by=v_actor,decided_at=clock_timestamp() where id=v_anomaly.compliance_case_id;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
  values(v_anomaly.organization_id,v_actor,'USER','client.compliance.question.created','client_compliance_question',v_id::text,p_correlation_id,jsonb_build_object('anomaly_id',v_anomaly.id,'due_at',p_due_at),null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)
  values(v_anomaly.organization_id,'client_compliance_question',v_id::text,'ClientComplianceQuestionCreatedV1',p_correlation_id,jsonb_build_object('question_id',v_id,'organization_id',v_anomaly.organization_id));
  update public.idempotency_keys set status='COMPLETED',response_code=201,response_body=jsonb_build_object('question_id',v_id),completed_at=clock_timestamp() where organization_id=v_anomaly.organization_id and operation_scope='client.compliance.question.create' and key=p_idempotency_key;
  return v_id;
end;
$$;

create function public.respond_client_compliance_question(
  p_question_id uuid,
  p_response_text text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer set search_path = pg_catalog, private
as $$
declare v_actor uuid:=auth.uid(); v_question public.client_compliance_questions%rowtype; v_version integer; v_response jsonb; v_hash text; v_existing public.idempotency_keys%rowtype;
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode='42501'; end if;
  select * into v_question from public.client_compliance_questions q where q.id=p_question_id and private.has_org_role(q.organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],v_actor);
  if not found then raise exception 'QUESTION_NOT_FOUND' using errcode='P0002'; end if;
  perform pg_advisory_xact_lock(hashtextextended('client-compliance-case:'||v_question.compliance_case_id::text,0));
  perform 1 from public.client_compliance_cases where id=v_question.compliance_case_id for update;
  select * into v_question from public.client_compliance_questions where id=p_question_id for update;
  if v_question.status not in ('OPEN','ANSWERED') or length(btrim(coalesce(p_response_text,''))) not between 3 and 4000 or length(coalesce(p_idempotency_key,'')) not between 8 and 200 then raise exception 'INVALID_COMPLIANCE_RESPONSE' using errcode='22023'; end if;
  v_hash:=private.canonical_request_hash(jsonb_build_object('operation','client.compliance.response.v1','question_id',p_question_id,'response',btrim(p_response_text)));
  perform pg_advisory_xact_lock(hashtextextended(v_question.organization_id::text||':client.compliance.response:'||p_idempotency_key,0));
  select * into v_existing from public.idempotency_keys where organization_id=v_question.organization_id and operation_scope='client.compliance.response' and key=p_idempotency_key;
  if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.status='COMPLETED' then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
  insert into public.idempotency_keys(organization_id,operation_scope,key,request_hash,created_by,expires_at) values(v_question.organization_id,'client.compliance.response',p_idempotency_key,v_hash,v_actor,clock_timestamp()+interval '7 days');
  select coalesce(max(version),0)+1 into v_version from public.client_compliance_response_versions where question_id=p_question_id;
  insert into public.client_compliance_response_versions(question_id,organization_id,version,response_text,submitted_by) values(p_question_id,v_question.organization_id,v_version,btrim(p_response_text),v_actor);
  update public.client_compliance_questions set status='ANSWERED',updated_at=clock_timestamp(),row_version=row_version+1 where id=p_question_id;
  update public.client_compliance_cases set status='RESPONSE_RECEIVED' where id=v_question.compliance_case_id;
  v_response:=jsonb_build_object('outcome','COMPLIANCE_RESPONSE_RECEIVED','question_id',p_question_id,'version',v_version);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
  values(v_question.organization_id,v_actor,'USER','client.compliance.response.received','client_compliance_question',p_question_id::text,p_correlation_id,jsonb_build_object('version',v_version),null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)
  values(v_question.organization_id,'client_compliance_question',p_question_id::text,'ClientComplianceResponseReceivedV1',p_correlation_id,jsonb_build_object('question_id',p_question_id,'version',v_version));
  update public.idempotency_keys set status='COMPLETED',response_code=200,response_body=v_response,completed_at=clock_timestamp() where organization_id=v_question.organization_id and operation_scope='client.compliance.response' and key=p_idempotency_key;
  return v_response;
end;
$$;

create function public.accept_client_compliance_response(
  p_question_id uuid,
  p_accepted boolean,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns boolean
language plpgsql security definer set search_path = pg_catalog, private
as $$
declare v_actor uuid:=auth.uid(); v_question public.client_compliance_questions%rowtype; v_hash text; v_existing public.idempotency_keys%rowtype;
begin
  if v_actor is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],v_actor) then raise exception 'CENTRAL_COMPLIANCE_REVIEW_REQUIRED' using errcode='42501'; end if;
  if p_accepted is null then raise exception 'INVALID_COMPLIANCE_DECISION' using errcode='22023'; end if;
  select * into v_question from public.client_compliance_questions where id=p_question_id;
  if not found then raise exception 'QUESTION_NOT_FOUND' using errcode='P0002'; end if;
  perform pg_advisory_xact_lock(hashtextextended('client-compliance-case:'||v_question.compliance_case_id::text,0));
  perform 1 from public.client_compliance_cases where id=v_question.compliance_case_id for update;
  perform 1 from public.client_administrative_anomalies where id=v_question.anomaly_id for update;
  select * into v_question from public.client_compliance_questions where id=p_question_id for update;
  if length(coalesce(p_idempotency_key,'')) not between 8 and 200 then raise exception 'INVALID_IDEMPOTENCY_KEY' using errcode='22023'; end if;
  v_hash:=private.canonical_request_hash(jsonb_build_object('operation','client.compliance.response.decide.v1','question_id',p_question_id,'accepted',p_accepted));
  perform pg_advisory_xact_lock(hashtextextended(v_question.organization_id::text||':client.compliance.response.decide:'||p_idempotency_key,0));
  select * into v_existing from public.idempotency_keys where organization_id=v_question.organization_id and operation_scope='client.compliance.response.decide' and key=p_idempotency_key;
  if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.status='COMPLETED' then return (v_existing.response_body #>> '{}')::boolean; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
  if v_question.status<>'ANSWERED' then raise exception 'QUESTION_NOT_ANSWERED' using errcode='55000'; end if;
  insert into public.idempotency_keys(organization_id,operation_scope,key,request_hash,created_by,expires_at) values(v_question.organization_id,'client.compliance.response.decide',p_idempotency_key,v_hash,v_actor,clock_timestamp()+interval '7 days');
  if p_accepted then
    update public.client_compliance_questions set status='ACCEPTED',accepted_by=v_actor,accepted_at=clock_timestamp(),updated_at=clock_timestamp(),row_version=row_version+1 where id=p_question_id;
    update public.client_administrative_anomalies set status='RESOLVED',resolved_by=v_actor,resolved_at=clock_timestamp(),updated_at=clock_timestamp(),row_version=row_version+1 where id=v_question.anomaly_id;
    update public.client_compliance_cases set status=case
      when exists(select 1 from public.client_compliance_questions other where other.compliance_case_id=v_question.compliance_case_id and other.id<>p_question_id and other.status='ANSWERED') then 'RESPONSE_RECEIVED'
      when exists(select 1 from public.client_compliance_questions other where other.compliance_case_id=v_question.compliance_case_id and other.id<>p_question_id and other.status='OPEN') then 'QUESTION_REQUIRED'
      else 'UNDER_REVIEW' end,
      decided_by=v_actor,decided_at=clock_timestamp()
    where id=v_question.compliance_case_id;
  else
    update public.client_compliance_questions set status='OPEN',updated_at=clock_timestamp(),row_version=row_version+1 where id=p_question_id;
    update public.client_compliance_cases set status='QUESTION_REQUIRED',decided_by=v_actor,decided_at=clock_timestamp() where id=v_question.compliance_case_id;
  end if;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
  values(v_question.organization_id,v_actor,'USER','client.compliance.response.decided','client_compliance_question',p_question_id::text,p_correlation_id,jsonb_build_object('accepted',p_accepted),null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)
  values(v_question.organization_id,'client_compliance_question',p_question_id::text,case when p_accepted then 'ClientComplianceResponseAcceptedV1' else 'ClientComplianceResponseRejectedV1' end,p_correlation_id,jsonb_build_object('question_id',p_question_id,'accepted',p_accepted));
  update public.idempotency_keys set status='COMPLETED',response_code=200,response_body=to_jsonb(p_accepted),completed_at=clock_timestamp() where organization_id=v_question.organization_id and operation_scope='client.compliance.response.decide' and key=p_idempotency_key;
  return p_accepted;
end;
$$;

create or replace function private.require_verified_client_compliance()
returns trigger language plpgsql security definer set search_path = pg_catalog
as $$
begin
  if new.status='VERIFIED' and old.status is distinct from 'VERIFIED' then
    if exists(select 1 from public.client_administrative_anomalies anomaly where anomaly.compliance_case_id=new.id and anomaly.blocking and anomaly.status in ('OPEN','QUESTIONED')) then raise exception 'BLOCKING_COMPLIANCE_ANOMALY' using errcode='55000'; end if;
    if exists(select 1 from public.client_compliance_questions question where question.compliance_case_id=new.id and question.status in ('OPEN','ANSWERED')) then raise exception 'OPEN_COMPLIANCE_QUESTION' using errcode='55000'; end if;
    if not exists(select 1 from public.organization_identifiers i where i.organization_id=new.organization_id and i.identifier_type='ICE' and i.is_active and i.verification_status='VERIFIED')
       or not exists(select 1 from public.organization_identifiers i where i.organization_id=new.organization_id and i.identifier_type='IF' and i.is_active and i.verification_status='VERIFIED')
       or not exists(select 1 from public.organization_identifiers i where i.organization_id=new.organization_id and i.identifier_type='RC' and i.is_active and i.verification_status='VERIFIED') then raise exception 'VERIFIED_IDENTIFIERS_REQUIRED' using errcode='55000'; end if;
    if not exists(select 1 from public.client_compliance_evidence e where e.compliance_case_id=new.id and e.evidence_type='REGISTRATION_DOCUMENT' and e.review_status='VERIFIED')
       or not exists(select 1 from public.client_compliance_evidence e where e.compliance_case_id=new.id and e.evidence_type='REPRESENTATIVE_AUTHORITY' and e.review_status='VERIFIED') then raise exception 'VERIFIED_COMPLIANCE_EVIDENCE_REQUIRED' using errcode='55000'; end if;
  end if;
  return new;
end;
$$;

revoke all on function public.evaluate_client_compliance(uuid,text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.create_client_compliance_question(uuid,text,text,text,timestamptz,text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.respond_client_compliance_question(uuid,text,text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.accept_client_compliance_response(uuid,boolean,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.evaluate_client_compliance(uuid,text,uuid) to authenticated;
grant execute on function public.create_client_compliance_question(uuid,text,text,text,timestamptz,text,uuid) to authenticated;
grant execute on function public.respond_client_compliance_question(uuid,text,text,uuid) to authenticated;
grant execute on function public.accept_client_compliance_response(uuid,boolean,text,uuid) to authenticated;

notify pgrst, 'reload schema';
