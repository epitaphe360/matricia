-- P06: reproducible questionnaire sessions pinned to immutable releases and rule-engine snapshots.

alter table public.questionnaire_sessions
  add column last_resumed_at timestamptz,
  add column abandoned_at timestamptz,
  add column expired_at timestamptz;

update public.questionnaire_sessions set abandoned_at=coalesce(abandoned_at,updated_at)where status='ABANDONED';
update public.questionnaire_sessions set expired_at=coalesce(expired_at,updated_at)where status='EXPIRED';

alter table public.questionnaire_sessions
  add constraint questionnaire_sessions_terminal_timestamps_check check (
    (status='ABANDONED')=(abandoned_at is not null)
    and (status='EXPIRED')=(expired_at is not null)
    and not (abandoned_at is not null and expired_at is not null)
  );

create table public.questionnaire_session_snapshots (
  id uuid primary key default extensions.gen_random_uuid(),
  session_id uuid not null unique references public.questionnaire_sessions(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  questionnaire_version_id uuid not null references public.questionnaire_versions(id) on delete restrict,
  catalog_release_id uuid not null references public.catalog_releases(id) on delete restrict,
  questionnaire_snapshot_hash text not null check(questionnaire_snapshot_hash~'^[0-9a-f]{64}$'),
  release_source_bundle_hash text not null check(release_source_bundle_hash~'^[0-9a-f]{64}$'),
  engine_version text not null check(length(btrim(engine_version))between 1 and 80),
  policy_version text not null check(length(btrim(policy_version))between 1 and 80),
  questions_manifest jsonb not null check(jsonb_typeof(questions_manifest)='array'),
  rules_manifest jsonb not null check(jsonb_typeof(rules_manifest)='array'),
  snapshot_hash text not null unique check(snapshot_hash~'^[0-9a-f]{64}$'),
  created_at timestamptz not null default clock_timestamp(),
  unique(organization_id,session_id),
  foreign key(organization_id,session_id) references public.questionnaire_sessions(organization_id,id) on delete restrict
);

create table public.questionnaire_session_evaluations (
  id uuid primary key default extensions.gen_random_uuid(),
  session_id uuid not null unique references public.questionnaire_sessions(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  session_snapshot_id uuid not null references public.questionnaire_session_snapshots(id) on delete restrict,
  questionnaire_version_id uuid not null references public.questionnaire_versions(id) on delete restrict,
  engine_version text not null check(length(btrim(engine_version))between 1 and 80),
  policy_version text not null check(length(btrim(policy_version))between 1 and 80),
  score_basis_points integer not null check(score_basis_points between 0 and 10000),
  triggered_actions jsonb not null check(jsonb_typeof(triggered_actions)='array'),
  answer_manifest_hash text not null check(answer_manifest_hash~'^[0-9a-f]{64}$'),
  result_payload jsonb not null check(jsonb_typeof(result_payload)='object'),
  reproducibility_hash text not null check(reproducibility_hash~'^[0-9a-f]{64}$'),
  evaluated_by uuid not null references auth.users(id),
  evaluated_at timestamptz not null default clock_timestamp(),
  unique(organization_id,session_id),
  unique(session_snapshot_id,answer_manifest_hash),
  foreign key(organization_id,session_id) references public.questionnaire_sessions(organization_id,id) on delete restrict
);

create table public.questionnaire_session_state_events (
  id uuid primary key default extensions.gen_random_uuid(),
  session_id uuid not null references public.questionnaire_sessions(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  from_status text,
  to_status text not null check(to_status in('DRAFT','IN_PROGRESS','READY','SUBMITTED','ABANDONED','EXPIRED')),
  reason_code text not null check(reason_code~'^[A-Z][A-Z0-9_.-]{2,79}$'),
  actor_user_id uuid not null references auth.users(id),
  correlation_id uuid not null,
  idempotency_key text not null check(length(idempotency_key)between 8 and 200),
  occurred_at timestamptz not null default clock_timestamp(),
  unique(session_id,idempotency_key),
  foreign key(organization_id,session_id) references public.questionnaire_sessions(organization_id,id) on delete restrict,
  check(from_status is null or from_status in('DRAFT','IN_PROGRESS','READY','SUBMITTED','ABANDONED','EXPIRED'))
);

do $$declare c text;begin
  select conname into c from pg_constraint where conrelid='private.questionnaire_command_keys'::regclass and contype='c' and pg_get_constraintdef(oid)like'%operation_scope%';
  if c is null then raise exception 'QUESTIONNAIRE_COMMAND_SCOPE_CONSTRAINT_NOT_FOUND';end if;
  execute format('alter table private.questionnaire_command_keys drop constraint %I',c);
end$$;
alter table private.questionnaire_command_keys add constraint questionnaire_command_keys_operation_scope_check check(operation_scope in(
  'questionnaire.version.publish','questionnaire.session.start','questionnaire.session.autosave','questionnaire.session.submit','questionnaire.session.resume','questionnaire.session.terminate'
));

create function private.questionnaire_session_snapshot_payload(p_session_id uuid)returns jsonb
language sql stable security definer set search_path=pg_catalog as $$
select jsonb_build_object(
  'session_id',s.id,'organization_id',s.organization_id,'questionnaire_version_id',v.id,
  'questionnaire_snapshot_hash',v.snapshot_hash,'catalog_release_id',r.id,
  'release_source_bundle_hash',r.source_bundle_hash,'engine_version',v.engine_version,'policy_version',v.policy_version,
  'questions',coalesce((select jsonb_agg(jsonb_build_object('question_version_id',x.question_version_id,'section_id',x.section_id,'sort_order',x.sort_order,'required',coalesce(x.required_override,q.required_by_default),'content_hash',q.content_hash)order by x.sort_order,x.question_version_id)from public.questionnaire_version_questions x join public.question_versions q on q.id=x.question_version_id where x.questionnaire_version_id=v.id),'[]'::jsonb),
  'rules',coalesce((select jsonb_agg(jsonb_build_object('rule_version_id',x.rule_version_id,'evaluation_order',x.evaluation_order,'compiled_hash',q.compiled_hash)order by x.evaluation_order,x.rule_version_id)from public.questionnaire_version_rules x join public.question_rule_versions q on q.id=x.rule_version_id where x.questionnaire_version_id=v.id),'[]'::jsonb)
)from public.questionnaire_sessions s join public.questionnaire_versions v on v.id=s.questionnaire_version_id join public.catalog_releases r on r.id=s.catalog_release_id where s.id=p_session_id
$$;
revoke all on function private.questionnaire_session_snapshot_payload(uuid)from public,anon,authenticated,service_role;

create function private.create_questionnaire_session_snapshot(p_session_id uuid)returns uuid
language plpgsql security definer set search_path=pg_catalog as $$
declare p jsonb;sid uuid;begin
  p:=private.questionnaire_session_snapshot_payload(p_session_id);
  if p is null then raise exception 'QUESTIONNAIRE_SESSION_SNAPSHOT_SOURCE_MISSING'using errcode='23503';end if;
  insert into public.questionnaire_session_snapshots(session_id,organization_id,questionnaire_version_id,catalog_release_id,questionnaire_snapshot_hash,release_source_bundle_hash,engine_version,policy_version,questions_manifest,rules_manifest,snapshot_hash)
  select p_session_id,(p->>'organization_id')::uuid,(p->>'questionnaire_version_id')::uuid,(p->>'catalog_release_id')::uuid,p->>'questionnaire_snapshot_hash',p->>'release_source_bundle_hash',p->>'engine_version',p->>'policy_version',p->'questions',p->'rules',encode(extensions.digest(convert_to(p::text,'UTF8'),'sha256'),'hex')returning id into sid;
  return sid;
end$$;
revoke all on function private.create_questionnaire_session_snapshot(uuid)from public,anon,authenticated,service_role;

create function private.questionnaire_session_answers_object(p_session_id uuid)returns jsonb
language sql stable security definer set search_path=pg_catalog as $$
select coalesce(jsonb_object_agg(a.question_version_id::text,r.value order by a.question_version_id::text),'{}'::jsonb)
from public.questionnaire_answers a join public.questionnaire_answer_revisions r on r.id=a.current_revision_id
where a.session_id=p_session_id and(r.expires_at is null or r.expires_at>statement_timestamp())
$$;
revoke all on function private.questionnaire_session_answers_object(uuid)from public,anon,authenticated,service_role;

create function private.questionnaire_session_progress(p_session_id uuid)returns jsonb
language sql stable security definer set search_path=pg_catalog as $$
with s as(select questionnaire_version_id from public.questionnaire_sessions where id=p_session_id),q as(select count(*)::integer total from public.questionnaire_version_questions x join s on s.questionnaire_version_id=x.questionnaire_version_id),a as(select count(*)::integer answered from public.questionnaire_answers x join public.questionnaire_answer_revisions r on r.id=x.current_revision_id where x.session_id=p_session_id and r.value<>'null'::jsonb and(r.expires_at is null or r.expires_at>statement_timestamp()))
select jsonb_build_object('answered_count',a.answered,'question_count',q.total,'progress_basis_points',case when q.total=0 then 0 else(a.answered::bigint*10000/q.total)::integer end)from q,a
$$;
revoke all on function private.questionnaire_session_progress(uuid)from public,anon,authenticated,service_role;

insert into public.questionnaire_session_snapshots(session_id,organization_id,questionnaire_version_id,catalog_release_id,questionnaire_snapshot_hash,release_source_bundle_hash,engine_version,policy_version,questions_manifest,rules_manifest,snapshot_hash)
select s.id,s.organization_id,s.questionnaire_version_id,s.catalog_release_id,x.payload->>'questionnaire_snapshot_hash',x.payload->>'release_source_bundle_hash',x.payload->>'engine_version',x.payload->>'policy_version',x.payload->'questions',x.payload->'rules',encode(extensions.digest(convert_to(x.payload::text,'UTF8'),'sha256'),'hex')
from public.questionnaire_sessions s cross join lateral(select private.questionnaire_session_snapshot_payload(s.id)payload)x
on conflict(session_id)do nothing;

create trigger questionnaire_session_snapshots_immutable before update or delete on public.questionnaire_session_snapshots for each row execute function private.prevent_questionnaire_history_mutation();
create trigger questionnaire_session_evaluations_immutable before update or delete on public.questionnaire_session_evaluations for each row execute function private.prevent_questionnaire_history_mutation();
create trigger questionnaire_session_state_events_immutable before update or delete on public.questionnaire_session_state_events for each row execute function private.prevent_questionnaire_history_mutation();

create or replace function private.protect_submitted_questionnaire_history()returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare sid uuid;st text;begin
  if tg_table_name='questionnaire_sessions'then
    if tg_op='DELETE'or old.status='SUBMITTED'then raise exception 'IMMUTABLE_SUBMITTED_QUESTIONNAIRE'using errcode='55000';end if;
    if old.status in('ABANDONED','EXPIRED')then raise exception 'IMMUTABLE_TERMINAL_QUESTIONNAIRE'using errcode='55000';end if;return new;
  end if;
  sid:=case when tg_op='DELETE'then old.session_id else new.session_id end;select status into st from public.questionnaire_sessions where id=sid;
  if tg_op='DELETE'or st='SUBMITTED'then raise exception 'IMMUTABLE_SUBMITTED_QUESTIONNAIRE'using errcode='55000';end if;
  if st in('ABANDONED','EXPIRED')then raise exception 'IMMUTABLE_TERMINAL_QUESTIONNAIRE'using errcode='55000';end if;return new;
end$$;
revoke all on function private.protect_submitted_questionnaire_history()from public,anon,authenticated,service_role;

create or replace function public.start_questionnaire_session(p_organization_id uuid,p_questionnaire_version_id uuid,p_locale text,p_due_at timestamptz,p_idempotency_key text,p_correlation_id uuid)returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$
declare a uuid:=auth.uid();v public.questionnaire_versions%rowtype;k private.questionnaire_command_keys%rowtype;h text;s uuid;ss uuid;r jsonb;cmd uuid;begin
  if a is null then raise exception 'AUTHENTICATION_REQUIRED'using errcode='42501';end if;
  if p_correlation_id is null or length(p_idempotency_key)not between 8 and 200 or p_locale not in('fr-MA','ar-MA')then raise exception 'INVALID_SESSION_REQUEST'using errcode='22023';end if;
  perform pg_advisory_xact_lock(hashtextextended(a::text||':questionnaire.session.start:'||p_idempotency_key,0));
  select*into v from public.questionnaire_versions where id=p_questionnaire_version_id;
  if not found or v.status<>'PUBLISHED'or not private.can_read_catalog_release(v.catalog_release_id,a)or not exists(select 1 from public.questionnaires q where q.id=v.questionnaire_id and q.status='PUBLISHED'and q.current_published_version_id=v.id)or not exists(select 1 from public.catalog_releases x where x.id=v.catalog_release_id and x.status='PUBLISHED'and statement_timestamp()>=x.effective_from and(x.effective_until is null or statement_timestamp()<x.effective_until)and(x.audience->>'kind'='PUBLIC'or(x.audience->>'kind'='ORGANIZATIONS'and coalesce(x.audience->'organization_ids','[]')?p_organization_id::text)))then raise exception 'QUESTIONNAIRE_NOT_AVAILABLE'using errcode='42501';end if;
  if not private.has_questionnaire_audience_access(p_organization_id,v.library_id,v.audience,'START',a)then raise exception 'ORGANIZATION_SCOPE_DENIED'using errcode='42501';end if;
  if p_due_at is not null and p_due_at<=statement_timestamp()then raise exception 'INVALID_SESSION_DUE_AT'using errcode='22023';end if;
  h:=encode(extensions.digest(convert_to(jsonb_build_object('organization_id',p_organization_id,'questionnaire_version_id',p_questionnaire_version_id,'locale',p_locale,'due_at',p_due_at)::text,'UTF8'),'sha256'),'hex');
  select*into k from private.questionnaire_command_keys where actor_user_id=a and operation_scope='questionnaire.session.start'and key=p_idempotency_key for update;
  if found then if k.request_hash<>h then raise exception 'IDEMPOTENCY_KEY_REUSED'using errcode='23505';end if;return k.response_body;end if;
  insert into private.questionnaire_command_keys values(a,'questionnaire.session.start',p_idempotency_key,h,null,clock_timestamp(),null,default)returning command_id into cmd;
  insert into public.questionnaire_sessions(organization_id,actor_user_id,library_id,catalog_release_id,questionnaire_version_id,audience,locale,status,due_at)values(p_organization_id,a,v.library_id,v.catalog_release_id,v.id,v.audience,p_locale,'DRAFT',p_due_at)returning id into s;
  ss:=private.create_questionnaire_session_snapshot(s);
  insert into public.questionnaire_session_state_events(session_id,organization_id,from_status,to_status,reason_code,actor_user_id,correlation_id,idempotency_key)values(s,p_organization_id,null,'DRAFT','SESSION_STARTED',a,p_correlation_id,p_idempotency_key);
  r:=jsonb_build_object('outcome','QUESTIONNAIRE_SESSION_STARTED','session_id',s,'row_version',1,'questionnaire_version_id',v.id,'session_snapshot_id',ss,'session_snapshot_hash',(select snapshot_hash from public.questionnaire_session_snapshots where id=ss));
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,a,'USER','questionnaire.session.started','questionnaire_session',s::text,p_correlation_id,jsonb_build_object('questionnaire_version_id',v.id,'session_snapshot_id',ss),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(p_organization_id,'questionnaire_session',s::text,'QuestionnaireSessionStartedV1',p_correlation_id,r,p_idempotency_key,cmd);
  update private.questionnaire_command_keys set response_body=r,completed_at=clock_timestamp()where actor_user_id=a and operation_scope='questionnaire.session.start'and key=p_idempotency_key;return r;
end$$;

create function public.resume_questionnaire_session(p_session_id uuid,p_idempotency_key text,p_correlation_id uuid)returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$
declare a uuid:=auth.uid();s public.questionnaire_sessions%rowtype;k private.questionnaire_command_keys%rowtype;h text;r jsonb;cmd uuid;begin
  if a is null then raise exception 'AUTHENTICATION_REQUIRED'using errcode='42501';end if;if p_correlation_id is null or length(p_idempotency_key)not between 8 and 200 then raise exception 'INVALID_RESUME_REQUEST'using errcode='22023';end if;
  perform pg_advisory_xact_lock(hashtextextended(a::text||':questionnaire.session.resume:'||p_idempotency_key,0));select*into s from public.questionnaire_sessions where id=p_session_id for update;
  if not found or s.actor_user_id<>a or not private.has_questionnaire_audience_access(s.organization_id,s.library_id,s.audience,'EDIT',a)then raise exception 'SESSION_SCOPE_DENIED'using errcode='42501';end if;
  h:=encode(extensions.digest(convert_to(jsonb_build_object('session_id',p_session_id)::text,'UTF8'),'sha256'),'hex');select*into k from private.questionnaire_command_keys where actor_user_id=a and operation_scope='questionnaire.session.resume'and key=p_idempotency_key for update;
  if found then if k.request_hash<>h then raise exception 'IDEMPOTENCY_KEY_REUSED'using errcode='23505';end if;return k.response_body;end if;
  if s.status not in('DRAFT','IN_PROGRESS','READY')then raise exception 'SESSION_NOT_RESUMABLE'using errcode='55000';end if;if s.due_at is not null and s.due_at<=statement_timestamp()then raise exception 'SESSION_EXPIRED'using errcode='55000';end if;
  insert into private.questionnaire_command_keys values(a,'questionnaire.session.resume',p_idempotency_key,h,null,clock_timestamp(),null,default)returning command_id into cmd;
  update public.questionnaire_sessions set last_resumed_at=clock_timestamp(),updated_at=clock_timestamp()where id=s.id;
  r:=jsonb_build_object('outcome','QUESTIONNAIRE_SESSION_RESUMED','session_id',s.id,'row_version',s.row_version,'questionnaire_version_id',s.questionnaire_version_id,'session_snapshot_hash',(select snapshot_hash from public.questionnaire_session_snapshots where session_id=s.id),'progress',private.questionnaire_session_progress(s.id),'answers',private.questionnaire_session_answers_object(s.id));
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(s.organization_id,a,'USER','questionnaire.session.resumed','questionnaire_session',s.id::text,p_correlation_id,jsonb_build_object('row_version',s.row_version,'progress',r->'progress'),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(s.organization_id,'questionnaire_session',s.id::text,'QuestionnaireSessionResumedV1',p_correlation_id,r-'answers',p_idempotency_key,cmd);
  update private.questionnaire_command_keys set response_body=r,completed_at=clock_timestamp()where actor_user_id=a and operation_scope='questionnaire.session.resume'and key=p_idempotency_key;return r;
end$$;

create function public.terminate_questionnaire_session(p_session_id uuid,p_action text,p_reason_code text,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid)returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$
declare a uuid:=auth.uid();s public.questionnaire_sessions%rowtype;k private.questionnaire_command_keys%rowtype;h text;r jsonb;cmd uuid;target text;from_state text;begin
  if a is null then raise exception 'AUTHENTICATION_REQUIRED'using errcode='42501';end if;if p_correlation_id is null or p_action not in('ABANDON','EXPIRE')or p_reason_code!~'^[A-Z][A-Z0-9_.-]{2,79}$'or p_expected_row_version is null or p_expected_row_version<1 or length(p_idempotency_key)not between 8 and 200 then raise exception 'INVALID_TERMINATE_REQUEST'using errcode='22023';end if;
  perform pg_advisory_xact_lock(hashtextextended(a::text||':questionnaire.session.terminate:'||p_idempotency_key,0));select*into s from public.questionnaire_sessions where id=p_session_id for update;
  if not found or s.actor_user_id<>a or not private.has_questionnaire_audience_access(s.organization_id,s.library_id,s.audience,'EDIT',a)then raise exception 'SESSION_SCOPE_DENIED'using errcode='42501';end if;
  h:=encode(extensions.digest(convert_to(jsonb_build_object('session_id',p_session_id,'action',p_action,'reason_code',p_reason_code,'expected',p_expected_row_version)::text,'UTF8'),'sha256'),'hex');select*into k from private.questionnaire_command_keys where actor_user_id=a and operation_scope='questionnaire.session.terminate'and key=p_idempotency_key for update;
  if found then if k.request_hash<>h then raise exception 'IDEMPOTENCY_KEY_REUSED'using errcode='23505';end if;return k.response_body;end if;
  if s.status not in('DRAFT','IN_PROGRESS','READY')then raise exception 'SESSION_NOT_TERMINABLE'using errcode='55000';end if;if s.row_version<>p_expected_row_version then raise exception 'STALE_SESSION_VERSION'using errcode='40001';end if;if p_action='EXPIRE'and(s.due_at is null or s.due_at>statement_timestamp())then raise exception 'SESSION_NOT_DUE'using errcode='55000';end if;
  target:=case when p_action='ABANDON'then'ABANDONED'else'EXPIRED'end;from_state:=s.status;insert into private.questionnaire_command_keys values(a,'questionnaire.session.terminate',p_idempotency_key,h,null,clock_timestamp(),null,default)returning command_id into cmd;
  update public.questionnaire_sessions set status=target,abandoned_at=case when target='ABANDONED'then clock_timestamp()else null end,expired_at=case when target='EXPIRED'then clock_timestamp()else null end,updated_at=clock_timestamp(),row_version=row_version+1 where id=s.id returning*into s;
  insert into public.questionnaire_session_state_events(session_id,organization_id,from_status,to_status,reason_code,actor_user_id,correlation_id,idempotency_key)values(s.id,s.organization_id,from_state,target,p_reason_code,a,p_correlation_id,p_idempotency_key);
  r:=jsonb_build_object('outcome','QUESTIONNAIRE_SESSION_'||target,'session_id',s.id,'status',target,'row_version',s.row_version,'reason_code',p_reason_code);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(s.organization_id,a,'USER','questionnaire.session.'||lower(target),'questionnaire_session',s.id::text,p_correlation_id,jsonb_build_object('reason_code',p_reason_code,'from_status',from_state),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(s.organization_id,'questionnaire_session',s.id::text,case target when'ABANDONED'then'QuestionnaireSessionAbandonedV1'else'QuestionnaireSessionExpiredV1'end,p_correlation_id,r,p_idempotency_key,cmd);
  update private.questionnaire_command_keys set response_body=r,completed_at=clock_timestamp()where actor_user_id=a and operation_scope='questionnaire.session.terminate'and key=p_idempotency_key;return r;
end$$;

create or replace function public.submit_questionnaire_session(p_session_id uuid,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid)returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$
declare a uuid:=auth.uid();s public.questionnaire_sessions%rowtype;k private.questionnaire_command_keys%rowtype;h text;manifest jsonb;mh text;r jsonb;cmd uuid;answers jsonb;previous jsonb:='{}';evaluation jsonb;payload jsonb;rh text;snapshot_id uuid;eid uuid;hidden text[]:='{}';required_rule text[]:='{}';optional_rule text[]:='{}';act jsonb;missing integer;contradiction boolean;from_state text;engine text;policy text;begin
  if a is null then raise exception 'AUTHENTICATION_REQUIRED'using errcode='42501';end if;if p_correlation_id is null or p_expected_row_version is null or p_expected_row_version<1 or length(p_idempotency_key)not between 8 and 200 then raise exception 'INVALID_SUBMIT_REQUEST'using errcode='22023';end if;
  perform pg_advisory_xact_lock(hashtextextended(a::text||':questionnaire.session.submit:'||p_idempotency_key,0));select*into s from public.questionnaire_sessions where id=p_session_id for update;
  if not found or s.actor_user_id<>a or not private.has_questionnaire_audience_access(s.organization_id,s.library_id,s.audience,'SUBMIT',a)then raise exception 'SESSION_SCOPE_DENIED'using errcode='42501';end if;
  h:=encode(extensions.digest(convert_to(jsonb_build_object('session_id',p_session_id,'expected_row_version',p_expected_row_version)::text,'UTF8'),'sha256'),'hex');select*into k from private.questionnaire_command_keys where actor_user_id=a and operation_scope='questionnaire.session.submit'and key=p_idempotency_key for update;
  if found then if k.request_hash<>h then raise exception 'IDEMPOTENCY_KEY_REUSED'using errcode='23505';end if;return k.response_body;end if;
  if s.status not in('IN_PROGRESS','READY')then raise exception 'SESSION_NOT_SUBMITTABLE'using errcode='55000';end if;if s.row_version<>p_expected_row_version then raise exception 'STALE_SESSION_VERSION'using errcode='40001';end if;if s.due_at is not null and s.due_at<=statement_timestamp()then raise exception 'SESSION_EXPIRED'using errcode='55000';end if;
  select id,engine_version,policy_version into snapshot_id,engine,policy from public.questionnaire_session_snapshots where session_id=s.id;if snapshot_id is null then raise exception 'SESSION_SNAPSHOT_MISSING'using errcode='23514';end if;
  answers:=private.questionnaire_session_answers_object(s.id);if s.revision_of_session_id is not null then previous:=private.questionnaire_session_answers_object(s.revision_of_session_id);end if;
  if engine='1'or engine like'1.%'then evaluation:=jsonb_build_object('questionnaire_version_id',s.questionnaire_version_id,'engine_version',engine,'policy_version',policy,'score_basis_points',0,'triggered_actions','[]'::jsonb,'simulation',false,'legacy_compatibility',true);else evaluation:=public.simulate_questionnaire_rule_engine(s.questionnaire_version_id,answers,previous);end if;
  for act in select value from jsonb_array_elements(evaluation->'triggered_actions')loop
    if act->>'type'='HIDE'then hidden:=array_append(hidden,act->>'target');elsif act->>'type'='REQUIRED'then required_rule:=array_append(required_rule,act->>'target');elsif act->>'type'='OPTIONAL'then optional_rule:=array_append(optional_rule,act->>'target');end if;
  end loop;
  select exists(select 1 from unnest(required_rule)x where x=any(hidden))into contradiction;if contradiction then raise exception 'CONTRADICTORY_REQUIRED_VISIBILITY'using errcode='23514';end if;
  select count(*)into missing from public.questionnaire_version_questions x join public.question_versions q on q.id=x.question_version_id left join public.questionnaire_answers z on z.session_id=s.id and z.question_version_id=q.id left join public.questionnaire_answer_revisions ar on ar.id=z.current_revision_id where x.questionnaire_version_id=s.questionnaire_version_id and not(q.id::text=any(hidden))and((coalesce(x.required_override,q.required_by_default)and not(q.id::text=any(optional_rule)))or q.id::text=any(required_rule))and(z.current_revision_id is null or ar.value='null'::jsonb or(ar.expires_at is not null and ar.expires_at<=statement_timestamp()));
  if missing>0 then raise exception 'REQUIRED_ANSWERS_MISSING'using errcode='23514';end if;
  select coalesce(jsonb_agg(jsonb_build_object('question_version_id',z.question_version_id,'answer_revision_id',z.current_revision_id,'answer_hash',ar.answer_hash)order by z.question_version_id::text),'[]')into manifest from public.questionnaire_answers z join public.questionnaire_answer_revisions ar on ar.id=z.current_revision_id where z.session_id=s.id;
  mh:=encode(extensions.digest(convert_to(manifest::text,'UTF8'),'sha256'),'hex');payload:=(evaluation-'simulation'-'reproducibility_hash')||jsonb_build_object('mode','FINAL','session_snapshot_id',snapshot_id,'answer_manifest_hash',mh);rh:=encode(extensions.digest(convert_to(jsonb_build_object('snapshot_hash',(select snapshot_hash from public.questionnaire_session_snapshots where id=snapshot_id),'result',payload)::text,'UTF8'),'sha256'),'hex');
  insert into private.questionnaire_command_keys values(a,'questionnaire.session.submit',p_idempotency_key,h,null,clock_timestamp(),null,default)returning command_id into cmd;from_state:=s.status;
  insert into public.questionnaire_session_evaluations(session_id,organization_id,session_snapshot_id,questionnaire_version_id,engine_version,policy_version,score_basis_points,triggered_actions,answer_manifest_hash,result_payload,reproducibility_hash,evaluated_by)values(s.id,s.organization_id,snapshot_id,s.questionnaire_version_id,evaluation->>'engine_version',evaluation->>'policy_version',(evaluation->>'score_basis_points')::integer,evaluation->'triggered_actions',mh,payload,rh,a)returning id into eid;
  update public.questionnaire_sessions set status='SUBMITTED',submitted_at=clock_timestamp(),updated_at=clock_timestamp(),answer_manifest=manifest,answer_manifest_hash=mh,row_version=row_version+1 where id=s.id returning*into s;
  insert into public.questionnaire_session_state_events(session_id,organization_id,from_status,to_status,reason_code,actor_user_id,correlation_id,idempotency_key)values(s.id,s.organization_id,from_state,'SUBMITTED','VALIDATION_COMPLETED',a,p_correlation_id,p_idempotency_key);
  r:=jsonb_build_object('outcome','QUESTIONNAIRE_SESSION_SUBMITTED','session_id',s.id,'row_version',s.row_version,'answer_manifest_hash',mh,'evaluation_id',eid,'score_basis_points',(evaluation->>'score_basis_points')::integer,'reproducibility_hash',rh);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(s.organization_id,a,'USER','questionnaire.session.submitted','questionnaire_session',s.id::text,p_correlation_id,jsonb_build_object('questionnaire_version_id',s.questionnaire_version_id,'session_snapshot_id',snapshot_id,'answer_manifest_hash',mh,'evaluation_id',eid,'reproducibility_hash',rh),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)values(s.organization_id,'questionnaire_session',s.id::text,'QuestionnaireSessionSubmittedV1',p_correlation_id,r,p_idempotency_key,cmd);
  update private.questionnaire_command_keys set response_body=r,completed_at=clock_timestamp()where actor_user_id=a and operation_scope='questionnaire.session.submit'and key=p_idempotency_key;return r;
end$$;

alter table public.questionnaire_session_snapshots enable row level security;
alter table public.questionnaire_session_evaluations enable row level security;
alter table public.questionnaire_session_state_events enable row level security;
revoke all on public.questionnaire_session_snapshots,public.questionnaire_session_evaluations,public.questionnaire_session_state_events from public,anon,authenticated,service_role;
grant select on public.questionnaire_session_snapshots,public.questionnaire_session_evaluations,public.questionnaire_session_state_events to authenticated;
create policy questionnaire_session_snapshots_scoped_read on public.questionnaire_session_snapshots for select to authenticated using(private.can_access_questionnaire_session(session_id));
create policy questionnaire_session_evaluations_scoped_read on public.questionnaire_session_evaluations for select to authenticated using(private.can_access_questionnaire_session(session_id));
create policy questionnaire_session_state_events_scoped_read on public.questionnaire_session_state_events for select to authenticated using(private.can_access_questionnaire_session(session_id));
create index questionnaire_session_snapshots_org_idx on public.questionnaire_session_snapshots(organization_id,created_at desc);
create index questionnaire_session_evaluations_org_idx on public.questionnaire_session_evaluations(organization_id,evaluated_at desc);
create index questionnaire_session_state_events_timeline_idx on public.questionnaire_session_state_events(session_id,occurred_at,id);
create index questionnaire_sessions_due_idx on public.questionnaire_sessions(due_at)where status in('DRAFT','IN_PROGRESS','READY')and due_at is not null;

revoke all on function public.start_questionnaire_session(uuid,uuid,text,timestamptz,text,uuid),public.resume_questionnaire_session(uuid,text,uuid),public.terminate_questionnaire_session(uuid,text,text,integer,text,uuid),public.submit_questionnaire_session(uuid,integer,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.start_questionnaire_session(uuid,uuid,text,timestamptz,text,uuid),public.resume_questionnaire_session(uuid,text,uuid),public.terminate_questionnaire_session(uuid,text,text,integer,text,uuid),public.submit_questionnaire_session(uuid,integer,text,uuid)to authenticated;
notify pgrst,'reload schema';
