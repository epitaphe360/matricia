-- P06 W2: immutable questionnaire/question/rule versions and conflict-safe diagnostic autosave.

create table public.questionnaires (
  id uuid primary key default extensions.gen_random_uuid(),
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  code text not null check (code ~ '^[A-Z][A-Z0-9_-]{1,79}$'),
  status text not null default 'DRAFT' check (status in ('DRAFT','PUBLISHED','ARCHIVED')),
  current_draft_version_id uuid,
  current_published_version_id uuid,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  archived_at timestamptz,
  row_version integer not null default 1 check (row_version > 0),
  unique (library_id, code),
  unique (library_id, id),
  check ((status = 'ARCHIVED') = (archived_at is not null))
);

create table public.questionnaire_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  questionnaire_id uuid not null,
  library_id uuid not null,
  catalog_release_id uuid not null,
  version integer not null check (version > 0),
  status text not null default 'DRAFT' check (status in ('DRAFT','LOCAL_TEST','FRANCHISE_REVIEW','CENTRAL_REVIEW','APPROVED','SCHEDULED','PUBLISHED','SUPERSEDED','ARCHIVED')),
  title_fr text not null check (length(btrim(title_fr)) between 2 and 240),
  title_ar text not null check (length(btrim(title_ar)) between 2 and 240),
  description_fr text not null check (length(btrim(description_fr)) between 3 and 4000),
  description_ar text not null check (length(btrim(description_ar)) between 3 and 4000),
  audience text not null check (audience in ('CLIENT','PROVIDER','FRANCHISE','INTERNAL')),
  engine_version text not null check (engine_version ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$'),
  policy_version text not null check (policy_version ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$'),
  snapshot_hash text not null check (snapshot_hash ~ '^[0-9a-f]{64}$'),
  sensitive boolean not null default false,
  translation_review_status text not null default 'PENDING' check (translation_review_status in ('PENDING','APPROVED','REJECTED')),
  translation_reviewer_user_id uuid references auth.users(id),
  translation_reviewed_at timestamptz,
  translation_review_proof_hash text check (translation_review_proof_hash is null or translation_review_proof_hash ~ '^[0-9a-f]{64}$'),
  translation_review_version integer not null default 0 check (translation_review_version >= 0),
  change_reason text not null check (length(btrim(change_reason)) between 3 and 500),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  published_at timestamptz,
  superseded_at timestamptz,
  row_version integer not null default 1 check (row_version > 0),
  unique (questionnaire_id, version),
  unique (questionnaire_id, id),
  unique (library_id, id),
  foreign key (questionnaire_id, library_id) references public.questionnaires(id, library_id) on delete restrict,
  foreign key (catalog_release_id, library_id) references public.catalog_releases(id, library_id) on delete restrict,
  check ((status = 'PUBLISHED') = (published_at is not null and superseded_at is null)),
  check ((status = 'SUPERSEDED') = (superseded_at is not null)),
  check ((translation_review_status='APPROVED')=(translation_reviewer_user_id is not null and translation_reviewed_at is not null and translation_review_proof_hash is not null and translation_review_version>0))
);

alter table public.questionnaires
  add constraint questionnaires_draft_fk foreign key (id, current_draft_version_id) references public.questionnaire_versions(questionnaire_id, id) on delete restrict,
  add constraint questionnaires_published_fk foreign key (id, current_published_version_id) references public.questionnaire_versions(questionnaire_id, id) on delete restrict;

create table public.questionnaire_sections (
  id uuid primary key default extensions.gen_random_uuid(),
  questionnaire_version_id uuid not null references public.questionnaire_versions(id) on delete restrict,
  section_key text not null check (section_key ~ '^[A-Z][A-Z0-9_-]{1,79}$'),
  label_fr text not null check (length(btrim(label_fr)) between 1 and 240),
  label_ar text not null check (length(btrim(label_ar)) between 1 and 240),
  help_fr text,
  help_ar text,
  sort_order integer not null check (sort_order > 0),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  unique (questionnaire_version_id, section_key),
  unique (questionnaire_version_id, sort_order),
  unique (questionnaire_version_id, id)
);

create table public.question_bank_questions (
  id uuid primary key default extensions.gen_random_uuid(),
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  question_key text not null check (question_key ~ '^[A-Z][A-Z0-9_.-]{1,119}$'),
  scope text not null check (scope in ('GLOBAL','LIBRARY','CATEGORY','SUBCATEGORY','SERVICE')),
  source_question_id uuid references public.question_bank_questions(id) on delete restrict,
  status text not null default 'DRAFT' check (status in ('DRAFT','PUBLISHED','ARCHIVED')),
  current_draft_version_id uuid,
  current_published_version_id uuid,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  archived_at timestamptz,
  row_version integer not null default 1 check (row_version > 0),
  unique (library_id, question_key),
  unique (library_id, id),
  check ((status = 'ARCHIVED') = (archived_at is not null))
);

create table public.question_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  question_id uuid not null,
  library_id uuid not null,
  version integer not null check (version > 0),
  status text not null default 'DRAFT' check (status in ('DRAFT','APPROVED','PUBLISHED','SUPERSEDED','ARCHIVED')),
  label_fr text not null check (length(btrim(label_fr)) between 1 and 1000),
  label_ar text not null check (length(btrim(label_ar)) between 1 and 1000),
  help_fr text,
  help_ar text,
  why_we_ask_fr text,
  why_we_ask_ar text,
  answer_type text not null check (answer_type in ('YES_NO','SINGLE_CHOICE','MULTIPLE_CHOICE','SHORT_TEXT','LONG_TEXT','INTEGER','DECIMAL','PERCENTAGE','MONEY','CURRENCY','DATE','DATE_RANGE','TIME','EMAIL','PHONE','URL','ADDRESS','GEO_AREA','RATING_5','RATING_10','QUANTITY','UNIT_VALUE','FILE','MULTI_FILE','IMAGE','TABLE','REPEATER','CONTACT','ORGANIZATION','PRODUCT_LIST','SITE_LIST','MILESTONE_LIST','BUDGET_BREAKDOWN')),
  data_key text not null check (data_key ~ '^[A-Za-z][A-Za-z0-9_.-]{1,159}$'),
  required_by_default boolean not null default false,
  required_for_quote boolean not null default false,
  required_for_publication boolean not null default false,
  options jsonb not null default '[]'::jsonb check (jsonb_typeof(options) = 'array'),
  validation_schema jsonb not null default '{}'::jsonb check (jsonb_typeof(validation_schema) = 'object'),
  structured_schema jsonb check (structured_schema is null or jsonb_typeof(structured_schema) = 'object'),
  visibility_rule jsonb check (visibility_rule is null or jsonb_typeof(visibility_rule) = 'object'),
  default_value jsonb,
  prefill_source text check (prefill_source is null or prefill_source in ('PROFILE','ORGANIZATION','SITE','PREVIOUS_ANSWER','DOCUMENT')),
  sensitivity text not null default 'BUSINESS' check (sensitivity in ('PUBLIC','BUSINESS','CONFIDENTIAL','RESTRICTED')),
  nullable boolean not null default false,
  translation_review_status text not null default 'PENDING' check (translation_review_status in ('PENDING','APPROVED','REJECTED')),
  translation_reviewer_user_id uuid references auth.users(id),
  translation_reviewed_at timestamptz,
  translation_review_proof_hash text check (translation_review_proof_hash is null or translation_review_proof_hash ~ '^[0-9a-f]{64}$'),
  translation_review_version integer not null default 0 check (translation_review_version >= 0),
  weight numeric(20,6) not null default 0 check (weight >= 0),
  maximum_score numeric(20,6) not null default 0 check (maximum_score >= 0),
  template_key text,
  validity_interval interval check (validity_interval is null or validity_interval > interval '0 seconds'),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  change_reason text not null check (length(btrim(change_reason)) between 3 and 500),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  published_at timestamptz,
  superseded_at timestamptz,
  row_version integer not null default 1 check (row_version > 0),
  unique (question_id, version),
  unique (question_id, id),
  unique (library_id, id),
  foreign key (question_id, library_id) references public.question_bank_questions(id, library_id) on delete restrict,
  check ((answer_type in ('SINGLE_CHOICE','MULTIPLE_CHOICE')) = (jsonb_array_length(options) > 0)),
  check ((answer_type in ('TABLE','REPEATER')) = (structured_schema is not null)),
  check ((status = 'PUBLISHED') = (published_at is not null and superseded_at is null)),
  check ((status = 'SUPERSEDED') = (superseded_at is not null)),
  check ((translation_review_status='APPROVED')=(translation_reviewer_user_id is not null and translation_reviewed_at is not null and translation_review_proof_hash is not null and translation_review_version>0))
);

alter table public.question_bank_questions
  add constraint question_bank_draft_fk foreign key (id, current_draft_version_id) references public.question_versions(question_id, id) on delete restrict,
  add constraint question_bank_published_fk foreign key (id, current_published_version_id) references public.question_versions(question_id, id) on delete restrict;

create table public.questionnaire_version_questions (
  questionnaire_version_id uuid not null references public.questionnaire_versions(id) on delete restrict,
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  section_id uuid not null,
  question_version_id uuid not null,
  sort_order integer not null check (sort_order > 0),
  required_override boolean,
  primary key (questionnaire_version_id, question_version_id),
  unique (questionnaire_version_id, sort_order),
  foreign key (library_id, questionnaire_version_id) references public.questionnaire_versions(library_id, id) on delete restrict,
  foreign key (library_id, question_version_id) references public.question_versions(library_id, id) on delete restrict,
  foreign key (questionnaire_version_id, section_id) references public.questionnaire_sections(questionnaire_version_id, id) on delete restrict
);

create table public.question_rules (
  id uuid primary key default extensions.gen_random_uuid(),
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  rule_key text not null check (rule_key ~ '^[A-Z][A-Z0-9_.-]{1,119}$'),
  status text not null default 'DRAFT' check (status in ('DRAFT','PUBLISHED','ARCHIVED')),
  current_draft_version_id uuid,
  current_published_version_id uuid,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  archived_at timestamptz,
  row_version integer not null default 1 check (row_version > 0),
  unique (library_id, rule_key),
  unique (library_id, id),
  check ((status = 'ARCHIVED') = (archived_at is not null))
);

create table public.question_rule_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  rule_id uuid not null,
  library_id uuid not null,
  version integer not null check (version > 0),
  status text not null default 'DRAFT' check (status in ('DRAFT','APPROVED','PUBLISHED','SUPERSEDED','ARCHIVED')),
  condition_ast jsonb not null check (jsonb_typeof(condition_ast) = 'object'),
  actions jsonb not null check (jsonb_typeof(actions) = 'array' and jsonb_array_length(actions) > 0),
  dependency_graph jsonb not null check (jsonb_typeof(dependency_graph) = 'object'),
  priority integer not null default 100 check (priority between 0 and 100000),
  sensitive boolean not null default false,
  compiled_hash text not null check (compiled_hash ~ '^[0-9a-f]{64}$'),
  change_reason text not null check (length(btrim(change_reason)) between 3 and 500),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  published_at timestamptz,
  superseded_at timestamptz,
  row_version integer not null default 1 check (row_version > 0),
  unique (rule_id, version),
  unique (rule_id, id),
  unique (library_id, id),
  foreign key (rule_id, library_id) references public.question_rules(id, library_id) on delete restrict,
  check ((status = 'PUBLISHED') = (published_at is not null and superseded_at is null)),
  check ((status = 'SUPERSEDED') = (superseded_at is not null))
);

alter table public.question_rules
  add constraint question_rules_draft_fk foreign key (id, current_draft_version_id) references public.question_rule_versions(rule_id, id) on delete restrict,
  add constraint question_rules_published_fk foreign key (id, current_published_version_id) references public.question_rule_versions(rule_id, id) on delete restrict;

create table public.questionnaire_version_rules (
  questionnaire_version_id uuid not null references public.questionnaire_versions(id) on delete restrict,
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  rule_version_id uuid not null,
  evaluation_order integer not null check (evaluation_order > 0),
  primary key (questionnaire_version_id, rule_version_id),
  unique (questionnaire_version_id, evaluation_order),
  foreign key (library_id, questionnaire_version_id) references public.questionnaire_versions(library_id, id) on delete restrict,
  foreign key (library_id, rule_version_id) references public.question_rule_versions(library_id, id) on delete restrict
);

create unique index questionnaire_one_published_version_uidx on public.questionnaire_versions(questionnaire_id) where status='PUBLISHED';
create unique index question_one_published_version_uidx on public.question_versions(question_id) where status='PUBLISHED';
create unique index question_rule_one_published_version_uidx on public.question_rule_versions(rule_id) where status='PUBLISHED';

create table public.questionnaire_sessions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  catalog_release_id uuid not null,
  questionnaire_version_id uuid not null,
  revision_of_session_id uuid references public.questionnaire_sessions(id) on delete restrict,
  site_id uuid,
  project_id uuid,
  audience text not null check (audience in ('CLIENT','PROVIDER','FRANCHISE','INTERNAL')),
  locale text not null check (locale in ('fr-MA','ar-MA')),
  status text not null default 'DRAFT' check (status in ('DRAFT','IN_PROGRESS','READY','SUBMITTED','ABANDONED','EXPIRED')),
  is_simulation boolean not null default false,
  started_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  due_at timestamptz,
  submitted_at timestamptz,
  answer_manifest jsonb,
  answer_manifest_hash text check (answer_manifest_hash is null or answer_manifest_hash ~ '^[0-9a-f]{64}$'),
  row_version integer not null default 1 check (row_version > 0),
  unique (organization_id, id),
  check (revision_of_session_id is null or revision_of_session_id<>id),
  foreign key (catalog_release_id, library_id) references public.catalog_releases(id, library_id) on delete restrict,
  foreign key (questionnaire_version_id, library_id) references public.questionnaire_versions(id, library_id) on delete restrict,
  foreign key (organization_id, revision_of_session_id) references public.questionnaire_sessions(organization_id, id) on delete restrict,
  check (due_at is null or due_at > started_at),
  check ((status = 'SUBMITTED') = (submitted_at is not null and answer_manifest is not null and answer_manifest_hash is not null)),
  check (status <> 'SUBMITTED' or is_simulation = false)
);

create table public.questionnaire_answers (
  id uuid primary key default extensions.gen_random_uuid(),
  session_id uuid not null references public.questionnaire_sessions(id) on delete restrict,
  organization_id uuid not null,
  question_version_id uuid not null references public.question_versions(id) on delete restrict,
  current_revision_id uuid,
  row_version integer not null default 1 check (row_version > 0),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (session_id, question_version_id),
  unique (session_id, id),
  unique (id, session_id, organization_id, question_version_id),
  foreign key (organization_id, session_id) references public.questionnaire_sessions(organization_id, id) on delete restrict
);

create table public.questionnaire_answer_revisions (
  id uuid primary key default extensions.gen_random_uuid(),
  answer_id uuid not null,
  session_id uuid not null,
  organization_id uuid not null,
  question_version_id uuid not null references public.question_versions(id) on delete restrict,
  revision integer not null check (revision > 0),
  value jsonb,
  source text not null check (source in ('USER','PROFILE','ORGANIZATION','SITE','PREVIOUS_ANSWER','IMPORT')),
  sensitivity text not null check (sensitivity in ('PUBLIC','BUSINESS','CONFIDENTIAL','RESTRICTED')),
  answer_hash text not null check (answer_hash ~ '^[0-9a-f]{64}$'),
  answered_by uuid not null references auth.users(id),
  answered_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz,
  unique (answer_id, revision),
  unique (answer_id, id),
  foreign key (answer_id, session_id, organization_id, question_version_id) references public.questionnaire_answers(id, session_id, organization_id, question_version_id) on delete restrict,
  foreign key (organization_id, session_id) references public.questionnaire_sessions(organization_id, id) on delete restrict,
  check (expires_at is null or expires_at > answered_at)
);

alter table public.questionnaire_answers
  add constraint questionnaire_answers_current_fk foreign key (id, current_revision_id) references public.questionnaire_answer_revisions(answer_id, id) on delete restrict;

create table private.questionnaire_command_keys (
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  operation_scope text not null check (operation_scope in ('questionnaire.version.publish','questionnaire.session.start','questionnaire.session.autosave','questionnaire.session.submit')),
  key text not null check (length(key) between 8 and 200),
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  response_body jsonb,
  created_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  command_id uuid not null default extensions.gen_random_uuid() unique,
  primary key (actor_user_id, operation_scope, key),
  check ((response_body is null) = (completed_at is null))
);
alter table public.event_outbox add column idempotency_key text, add column causation_id uuid;
do $$declare v_name text;begin select c.conname into v_name from pg_constraint c where c.conrelid='public.event_outbox'::regclass and c.contype='u' and pg_get_constraintdef(c.oid) like '%aggregate_type, aggregate_id, event_type, event_version, correlation_id%'; if v_name is null then raise exception 'EVENT_OUTBOX_DEDUP_CONSTRAINT_NOT_FOUND'; end if; execute format('alter table public.event_outbox drop constraint %I',v_name);end$$;
create unique index event_outbox_legacy_dedup_uidx on public.event_outbox(aggregate_type,aggregate_id,event_type,event_version,correlation_id) where idempotency_key is null;
create unique index event_outbox_command_dedup_uidx on public.event_outbox(event_type,causation_id) where causation_id is not null;

create or replace function private.prevent_questionnaire_history_mutation() returns trigger
language plpgsql security definer set search_path = pg_catalog as $$
begin
  if tg_op = 'DELETE' then raise exception 'IMMUTABLE_QUESTIONNAIRE_HISTORY' using errcode = '55000'; end if;
  if to_jsonb(new) is distinct from to_jsonb(old) then raise exception 'IMMUTABLE_QUESTIONNAIRE_HISTORY' using errcode = '55000'; end if;
  return new;
end $$;
revoke all on function private.prevent_questionnaire_history_mutation() from public, anon, authenticated, service_role;
create trigger questionnaire_answer_revisions_immutable before update or delete on public.questionnaire_answer_revisions for each row execute function private.prevent_questionnaire_history_mutation();

create or replace function private.compute_questionnaire_snapshot_hash(p_version_id uuid, p_metadata jsonb) returns text
language sql stable security definer set search_path=pg_catalog as $$
  select encode(extensions.digest(convert_to(jsonb_build_object(
    'metadata',p_metadata,
    'sections',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'key',s.section_key,'order',s.sort_order,'hash',s.content_hash) order by s.sort_order,s.id) from public.questionnaire_sections s where s.questionnaire_version_id=p_version_id),'[]'::jsonb),
    'questions',coalesce((select jsonb_agg(jsonb_build_object('id',x.question_version_id,'section_id',x.section_id,'order',x.sort_order,'required_override',x.required_override,'hash',q.content_hash) order by x.sort_order,x.question_version_id) from public.questionnaire_version_questions x join public.question_versions q on q.id=x.question_version_id where x.questionnaire_version_id=p_version_id),'[]'::jsonb),
    'rules',coalesce((select jsonb_agg(jsonb_build_object('id',x.rule_version_id,'order',x.evaluation_order,'hash',r.compiled_hash) order by x.evaluation_order,x.rule_version_id) from public.questionnaire_version_rules x join public.question_rule_versions r on r.id=x.rule_version_id where x.questionnaire_version_id=p_version_id),'[]'::jsonb)
  )::text,'UTF8'),'sha256'),'hex')
$$;
revoke all on function private.compute_questionnaire_snapshot_hash(uuid,jsonb) from public,anon,authenticated,service_role;

create or replace function private.validate_questionnaire_publication() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare v_expected text; v_metadata jsonb;
begin
  if new.status='PUBLISHED' then
    if new.translation_review_status<>'APPROVED' then raise exception 'QUESTIONNAIRE_TRANSLATION_NOT_APPROVED' using errcode='23514'; end if;
    if not exists(select 1 from public.questionnaire_version_questions x where x.questionnaire_version_id=new.id) then raise exception 'QUESTIONNAIRE_HAS_NO_QUESTIONS' using errcode='23514'; end if;
    if exists(select 1 from public.questionnaire_version_questions x join public.question_versions q on q.id=x.question_version_id where x.questionnaire_version_id=new.id and (q.status<>'PUBLISHED' or q.translation_review_status<>'APPROVED')) then raise exception 'QUESTION_VERSION_NOT_PUBLISHABLE' using errcode='23514'; end if;
    if exists(select 1 from public.questionnaire_version_rules x join public.question_rule_versions r on r.id=x.rule_version_id where x.questionnaire_version_id=new.id and r.status<>'PUBLISHED') then raise exception 'RULE_VERSION_NOT_PUBLISHABLE' using errcode='23514'; end if;
    v_metadata:=jsonb_build_object('questionnaire_id',new.questionnaire_id,'library_id',new.library_id,'release_id',new.catalog_release_id,'version',new.version,'title_fr',new.title_fr,'title_ar',new.title_ar,'description_fr',new.description_fr,'description_ar',new.description_ar,'audience',new.audience,'engine_version',new.engine_version,'policy_version',new.policy_version);
    v_expected:=private.compute_questionnaire_snapshot_hash(new.id,v_metadata);
    if new.snapshot_hash<>v_expected then raise exception 'QUESTIONNAIRE_SNAPSHOT_HASH_MISMATCH' using errcode='23514'; end if;
  end if;
  return new;
end $$;
revoke all on function private.validate_questionnaire_publication() from public,anon,authenticated,service_role;
create trigger questionnaire_publication_validate before insert or update on public.questionnaire_versions for each row execute function private.validate_questionnaire_publication();

create or replace function private.protect_questionnaire_snapshot_child() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare v_parent uuid; v_status text;
begin
  if tg_op in ('UPDATE','DELETE') then
    select status into v_status from public.questionnaire_versions where id=old.questionnaire_version_id;
    if v_status in ('PUBLISHED','SUPERSEDED','ARCHIVED') then raise exception 'IMMUTABLE_QUESTIONNAIRE_SNAPSHOT' using errcode='55000'; end if;
  end if;
  if tg_op in ('INSERT','UPDATE') then
    select status into v_status from public.questionnaire_versions where id=new.questionnaire_version_id;
    if v_status in ('PUBLISHED','SUPERSEDED','ARCHIVED') then raise exception 'IMMUTABLE_QUESTIONNAIRE_SNAPSHOT' using errcode='55000'; end if;
  end if;
  return case when tg_op='DELETE' then old else new end;
end $$;
revoke all on function private.protect_questionnaire_snapshot_child() from public,anon,authenticated,service_role;
create trigger questionnaire_sections_snapshot_immutable before insert or update or delete on public.questionnaire_sections for each row execute function private.protect_questionnaire_snapshot_child();
create trigger questionnaire_questions_snapshot_immutable before insert or update or delete on public.questionnaire_version_questions for each row execute function private.protect_questionnaire_snapshot_child();
create trigger questionnaire_rules_snapshot_immutable before insert or update or delete on public.questionnaire_version_rules for each row execute function private.protect_questionnaire_snapshot_child();

create or replace function private.validate_questionnaire_snapshot_link() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
begin
  if tg_table_name='questionnaire_version_questions' then
    if not exists(select 1 from public.question_versions q where q.id=new.question_version_id and q.library_id=new.library_id and q.status in ('APPROVED','PUBLISHED')) then raise exception 'QUESTION_VERSION_NOT_LINKABLE' using errcode='23514'; end if;
  elsif tg_table_name='questionnaire_version_rules' then
    if not exists(select 1 from public.question_rule_versions r where r.id=new.rule_version_id and r.library_id=new.library_id and r.status in ('APPROVED','PUBLISHED')) then raise exception 'RULE_VERSION_NOT_LINKABLE' using errcode='23514'; end if;
  end if;
  return new;
end $$;
revoke all on function private.validate_questionnaire_snapshot_link() from public,anon,authenticated,service_role;
create trigger questionnaire_questions_link_validate before insert or update on public.questionnaire_version_questions for each row execute function private.validate_questionnaire_snapshot_link();
create trigger questionnaire_rules_link_validate before insert or update on public.questionnaire_version_rules for each row execute function private.validate_questionnaire_snapshot_link();

create or replace function private.validate_session_revision_chain() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare v_parent public.questionnaire_sessions%rowtype;
begin
  if new.revision_of_session_id is null then return new; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('questionnaire.revision:'||new.organization_id::text,0));
  select * into v_parent from public.questionnaire_sessions where id=new.revision_of_session_id for share;
  if not found or v_parent.organization_id<>new.organization_id or v_parent.library_id<>new.library_id or v_parent.questionnaire_version_id<>new.questionnaire_version_id or v_parent.status<>'SUBMITTED' then raise exception 'INVALID_SESSION_REVISION_PARENT' using errcode='23514'; end if;
  if new.revision_of_session_id=new.id or exists(with recursive chain(id,ancestor) as (select s.id,s.revision_of_session_id from public.questionnaire_sessions s where s.id=new.revision_of_session_id union all select s.id,s.revision_of_session_id from public.questionnaire_sessions s join chain c on s.id=c.ancestor where c.ancestor is not null) select 1 from chain where ancestor=new.id) then raise exception 'INVALID_SESSION_REVISION_CHAIN' using errcode='23514'; end if;
  return new;
end $$;
revoke all on function private.validate_session_revision_chain() from public,anon,authenticated,service_role;
create trigger questionnaire_session_revision_validate before insert or update of revision_of_session_id on public.questionnaire_sessions for each row execute function private.validate_session_revision_chain();

create or replace function private.validate_questionnaire_identity_pointer() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
begin
  if new.status='PUBLISHED' and (new.current_published_version_id is null or not exists(select 1 from public.questionnaire_versions v where v.id=new.current_published_version_id and v.questionnaire_id=new.id and v.status='PUBLISHED')) then raise exception 'INVALID_QUESTIONNAIRE_PUBLISHED_POINTER' using errcode='23514'; end if;
  return new;
end $$;
revoke all on function private.validate_questionnaire_identity_pointer() from public,anon,authenticated,service_role;
create trigger questionnaire_identity_pointer_validate before insert or update on public.questionnaires for each row execute function private.validate_questionnaire_identity_pointer();

create or replace function private.validate_question_or_rule_identity_pointer() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
begin
  if new.status='PUBLISHED' and tg_table_name='question_bank_questions' and (new.current_published_version_id is null or not exists(select 1 from public.question_versions v where v.id=new.current_published_version_id and v.question_id=new.id and v.status='PUBLISHED')) then raise exception 'INVALID_QUESTION_PUBLISHED_POINTER' using errcode='23514'; end if;
  if new.status='PUBLISHED' and tg_table_name='question_rules' and (new.current_published_version_id is null or not exists(select 1 from public.question_rule_versions v where v.id=new.current_published_version_id and v.rule_id=new.id and v.status='PUBLISHED')) then raise exception 'INVALID_RULE_PUBLISHED_POINTER' using errcode='23514'; end if;
  return new;
end $$;
revoke all on function private.validate_question_or_rule_identity_pointer() from public,anon,authenticated,service_role;
create trigger question_identity_pointer_validate before insert or update on public.question_bank_questions for each row execute function private.validate_question_or_rule_identity_pointer();
create trigger rule_identity_pointer_validate before insert or update on public.question_rules for each row execute function private.validate_question_or_rule_identity_pointer();

create or replace function private.enforce_published_reverse_pointer() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare v_identity_id uuid;
begin
  if tg_table_name='questionnaires' then v_identity_id:=new.id; elsif tg_table_name='questionnaire_versions' then v_identity_id:=new.questionnaire_id;
  elsif tg_table_name='question_bank_questions' then v_identity_id:=new.id; elsif tg_table_name='question_versions' then v_identity_id:=new.question_id;
  elsif tg_table_name='question_rules' then v_identity_id:=new.id; else v_identity_id:=new.rule_id; end if;
  if tg_table_name in ('questionnaires','questionnaire_versions') and exists(select 1 from public.questionnaire_versions v join public.questionnaires q on q.id=v.questionnaire_id where q.id=v_identity_id and ((v.status='PUBLISHED') is distinct from (q.status='PUBLISHED' and q.current_published_version_id=v.id))) then raise exception 'QUESTIONNAIRE_PUBLISHED_POINTER_MISMATCH' using errcode='23514'; end if;
  if tg_table_name in ('question_bank_questions','question_versions') and exists(select 1 from public.question_versions v join public.question_bank_questions q on q.id=v.question_id where q.id=v_identity_id and ((v.status='PUBLISHED') is distinct from (q.status='PUBLISHED' and q.current_published_version_id=v.id))) then raise exception 'QUESTION_PUBLISHED_POINTER_MISMATCH' using errcode='23514'; end if;
  if tg_table_name in ('question_rules','question_rule_versions') and exists(select 1 from public.question_rule_versions v join public.question_rules q on q.id=v.rule_id where q.id=v_identity_id and ((v.status='PUBLISHED') is distinct from (q.status='PUBLISHED' and q.current_published_version_id=v.id))) then raise exception 'RULE_PUBLISHED_POINTER_MISMATCH' using errcode='23514'; end if;
  return new;
end $$;
revoke all on function private.enforce_published_reverse_pointer() from public,anon,authenticated,service_role;
create constraint trigger questionnaire_reverse_pointer after insert or update on public.questionnaires deferrable initially deferred for each row execute function private.enforce_published_reverse_pointer();
create constraint trigger questionnaire_version_reverse_pointer after insert or update on public.questionnaire_versions deferrable initially deferred for each row execute function private.enforce_published_reverse_pointer();
create constraint trigger question_reverse_pointer after insert or update on public.question_bank_questions deferrable initially deferred for each row execute function private.enforce_published_reverse_pointer();
create constraint trigger question_version_reverse_pointer after insert or update on public.question_versions deferrable initially deferred for each row execute function private.enforce_published_reverse_pointer();
create constraint trigger rule_reverse_pointer after insert or update on public.question_rules deferrable initially deferred for each row execute function private.enforce_published_reverse_pointer();
create constraint trigger rule_version_reverse_pointer after insert or update on public.question_rule_versions deferrable initially deferred for each row execute function private.enforce_published_reverse_pointer();

create or replace function private.has_questionnaire_audience_access(p_organization_id uuid,p_library_id uuid,p_audience text,p_mode text,p_actor_id uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=pg_catalog as $$
  select exists(select 1 from public.organizations o join public.organization_memberships m on m.organization_id=o.id join public.organization_member_roles r on r.membership_id=m.id and r.revoked_at is null where o.id=p_organization_id and o.status='ACTIVE' and m.user_id=p_actor_id and m.status='ACTIVE' and (
    (p_audience='CLIENT' and ((p_mode='READ' and r.role_code in ('CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER','CLIENT_ACCOUNTING','CLIENT_MEMBER','CLIENT_VIEWER')) or (p_mode in ('START','EDIT','SUBMIT') and r.role_code in ('CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER','CLIENT_MEMBER'))))
    or (p_audience='PROVIDER' and ((p_mode='READ' and r.role_code in ('PROVIDER_OWNER','PROVIDER_MANAGER','PROVIDER_SALES','PROVIDER_TECHNICIAN','PROVIDER_ACCOUNTING','PROVIDER_VIEWER')) or (p_mode in ('START','EDIT','SUBMIT') and r.role_code in ('PROVIDER_OWNER','PROVIDER_MANAGER','PROVIDER_SALES','PROVIDER_TECHNICIAN'))))
    or (p_audience='FRANCHISE' and r.library_id=p_library_id and ((p_mode='READ' and r.role_code in ('FRANCHISE_OWNER','FRANCHISE_MANAGER','FRANCHISE_EXPERT','FRANCHISE_PROVIDER_MANAGER','FRANCHISE_ACCOUNTING','FRANCHISE_VIEWER')) or (p_mode in ('START','EDIT','SUBMIT') and r.role_code in ('FRANCHISE_OWNER','FRANCHISE_MANAGER','FRANCHISE_EXPERT','FRANCHISE_PROVIDER_MANAGER'))))
    or (p_audience='INTERNAL' and private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','LIBRARY_MANAGER'],p_actor_id))
  ))
$$;
revoke all on function private.has_questionnaire_audience_access(uuid,uuid,text,text,uuid) from public,anon,authenticated,service_role;

create or replace function private.has_any_questionnaire_platform_role() returns boolean language sql stable security definer set search_path=pg_catalog as $$ select exists(select 1 from public.platform_user_roles r where r.user_id=auth.uid() and r.revoked_at is null) $$;
revoke all on function private.has_any_questionnaire_platform_role() from public,anon,authenticated,service_role;
grant execute on function private.has_any_questionnaire_platform_role() to authenticated;

create or replace function private.can_read_questionnaire_version(p_version_id uuid) returns boolean
language sql stable security definer set search_path=pg_catalog as $$
  select exists(select 1 from public.questionnaire_versions v where v.id=p_version_id and (
    (v.status in ('DRAFT','LOCAL_TEST','FRANCHISE_REVIEW','CENTRAL_REVIEW','APPROVED','SCHEDULED') and private.has_library_permission(v.library_id,'CATALOG_VIEW_DRAFT',auth.uid()) and (auth.jwt()->>'aal'='aal2' or not private.has_any_questionnaire_platform_role()))
    or (v.status='PUBLISHED' and (
      (v.audience='INTERNAL' and private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','LIBRARY_MANAGER'],auth.uid()))
      or exists(select 1 from public.organization_memberships m join public.organizations o on o.id=m.organization_id and o.status='ACTIVE' join public.catalog_releases r on r.id=v.catalog_release_id and r.status='PUBLISHED' and statement_timestamp()>=r.effective_from and (r.effective_until is null or statement_timestamp()<r.effective_until) where m.user_id=auth.uid() and m.status='ACTIVE' and (r.audience->>'kind'='PUBLIC' or (r.audience->>'kind'='ORGANIZATIONS' and coalesce(r.audience->'organization_ids','[]'::jsonb)?m.organization_id::text)) and private.has_questionnaire_audience_access(m.organization_id,v.library_id,v.audience,'READ',auth.uid()))
    ))
    or (v.status='SUPERSEDED' and exists(
      select 1
      from public.questionnaire_sessions s
      join public.organization_memberships m on m.organization_id=s.organization_id and m.user_id=auth.uid() and m.status='ACTIVE'
      join public.organizations o on o.id=s.organization_id and o.status='ACTIVE'
      where s.questionnaire_version_id=v.id and s.actor_user_id=auth.uid()
        and private.has_questionnaire_audience_access(s.organization_id,v.library_id,v.audience,'READ',auth.uid())
    ))
  ))
$$;
revoke all on function private.can_read_questionnaire_version(uuid) from public,anon,authenticated,service_role;
grant execute on function private.can_read_questionnaire_version(uuid) to authenticated;

create or replace function private.protect_questionnaire_version_history() returns trigger
language plpgsql security definer set search_path = pg_catalog as $$
begin
  if tg_op='DELETE' and old.status<>'DRAFT' then raise exception 'IMMUTABLE_QUESTIONNAIRE_VERSION' using errcode='55000'; end if;
  if tg_op='UPDATE' and old.status in ('PUBLISHED','SUPERSEDED','ARCHIVED') then
    if old.status='PUBLISHED' and new.status='SUPERSEDED'
       and (to_jsonb(new)-array['status','superseded_at','row_version'])=(to_jsonb(old)-array['status','superseded_at','row_version']) then return new; end if;
    if to_jsonb(new) is distinct from to_jsonb(old) then raise exception 'IMMUTABLE_QUESTIONNAIRE_VERSION' using errcode='55000'; end if;
  end if;
  return case when tg_op='DELETE' then old else new end;
end $$;
revoke all on function private.protect_questionnaire_version_history() from public, anon, authenticated, service_role;
create trigger questionnaire_versions_immutable before update or delete on public.questionnaire_versions for each row execute function private.protect_questionnaire_version_history();
create trigger question_versions_immutable before update or delete on public.question_versions for each row execute function private.protect_questionnaire_version_history();
create trigger question_rule_versions_immutable before update or delete on public.question_rule_versions for each row execute function private.protect_questionnaire_version_history();

create or replace function private.protect_submitted_questionnaire_history() returns trigger
language plpgsql security definer set search_path = pg_catalog as $$
declare v_session_id uuid; v_status text;
begin
  if tg_table_name='questionnaire_sessions' then
    if tg_op='DELETE' or old.status='SUBMITTED' then raise exception 'IMMUTABLE_SUBMITTED_QUESTIONNAIRE' using errcode='55000'; end if;
    return new;
  end if;
  v_session_id:=case when tg_op='DELETE' then old.session_id else new.session_id end;
  select status into v_status from public.questionnaire_sessions where id=v_session_id;
  if tg_op='DELETE' or v_status='SUBMITTED' then raise exception 'IMMUTABLE_SUBMITTED_QUESTIONNAIRE' using errcode='55000'; end if;
  return new;
end $$;
revoke all on function private.protect_submitted_questionnaire_history() from public, anon, authenticated, service_role;
create trigger questionnaire_sessions_history before update or delete on public.questionnaire_sessions for each row execute function private.protect_submitted_questionnaire_history();
create trigger questionnaire_answers_history before update or delete on public.questionnaire_answers for each row execute function private.protect_submitted_questionnaire_history();

create or replace function private.can_access_questionnaire_session(p_session_id uuid) returns boolean
language sql stable security definer set search_path = pg_catalog as $$
  select exists (
    select 1 from public.questionnaire_sessions s join public.organizations o on o.id=s.organization_id and o.status='ACTIVE'
    where s.id = p_session_id and s.actor_user_id=auth.uid() and private.has_questionnaire_audience_access(s.organization_id,s.library_id,s.audience,'READ')
  )
$$;
revoke all on function private.can_access_questionnaire_session(uuid) from public, anon, authenticated, service_role;
grant execute on function private.can_access_questionnaire_session(uuid) to authenticated;

create or replace function private.can_read_questionnaire_answer_revision(p_session_id uuid) returns boolean
language sql stable security definer set search_path=pg_catalog as $$
  select exists(select 1 from public.questionnaire_sessions s where s.id=p_session_id and s.actor_user_id=auth.uid() and private.has_questionnaire_audience_access(s.organization_id,s.library_id,s.audience,'READ'))
$$;
revoke all on function private.can_read_questionnaire_answer_revision(uuid) from public,anon,authenticated,service_role;
grant execute on function private.can_read_questionnaire_answer_revision(uuid) to authenticated;

create or replace function private.is_controlled_question_pattern(p_pattern text) returns boolean
language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_unbounded integer; v_cost integer; v_match text[];
begin
  if p_pattern is null or length(p_pattern) not between 1 and 128 or left(p_pattern,1)<>'^' or right(p_pattern,1)<>'$'
     or p_pattern ~ '(^|[^\\])\|' or p_pattern ~ '\\[1-9]' or p_pattern ~ '\(\?[:=!<]' or p_pattern ~ '\(\?<'
     or p_pattern ~ '\{[0-9]+,\}' or p_pattern ~ '([*+?]){2}' or p_pattern ~ '\)[+*{]'
     or p_pattern ~ '\([^)]*[+*][^)]*\)[+*]' then return false; end if;
  select count(*) into v_unbounded from regexp_matches(p_pattern,'(^|[^\\])[*+]','g');
  if v_unbounded>1 then return false; end if;
  for v_match in select regexp_matches(p_pattern,'\{([0-9]+)(,([0-9]+))?\}','g') loop
    if coalesce(v_match[3],v_match[1])::integer>100 then return false; end if;
  end loop;
  v_cost:=length(p_pattern)+8*length(regexp_replace(p_pattern,'[^|*+?{\[]','','g'));
  return v_cost<=500;
exception when others then return false;
end $$;
revoke all on function private.is_controlled_question_pattern(text) from public,anon,authenticated,service_role;

create or replace function private.round_exact_question_numeric(p_value numeric,p_scale integer,p_rounding text) returns numeric
language plpgsql immutable security definer set search_path=pg_catalog as $$
declare v_factor numeric;v_magnitude numeric;v_quotient numeric;v_remainder numeric;v_increment boolean;
begin
  if p_value is null or p_scale not between 0 and 1000 or p_rounding not in ('HALF_UP','HALF_EVEN','DOWN','UP') then return null;end if;
  v_factor:=power(10::numeric,p_scale);v_magnitude:=abs(p_value)*v_factor;v_quotient:=trunc(v_magnitude);v_remainder:=v_magnitude-v_quotient;
  v_increment:=case p_rounding when 'UP' then v_remainder>0 when 'DOWN' then false when 'HALF_UP' then v_remainder>=0.5 else v_remainder>0.5 or (v_remainder=0.5 and mod(v_quotient,2)=1) end;
  return (case when p_value<0 then -1 else 1 end)*(v_quotient+case when v_increment then 1 else 0 end)/v_factor;
end $$;
revoke all on function private.round_exact_question_numeric(numeric,integer,text) from public,anon,authenticated,service_role;

create or replace function private.is_valid_typed_question_answer(p_answer_type text,p_nullable boolean,p_options jsonb,p_numeric jsonb,p_validation jsonb,p_structured jsonb,p_value jsonb) returns boolean
language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_type text:=jsonb_typeof(p_value);v_text text;v_count integer;v_min integer;v_max integer;v_exact numeric;v_rounded numeric;v_scale integer;v_precision integer;v_rounding text;v_fields jsonb;v_row jsonb;v_field jsonb;v_local timestamp;v_candidates integer;v_date date;
begin
  if p_value is null or octet_length(convert_to(p_value::text,'UTF8'))>50000 then return false; end if;
  if p_value='null'::jsonb then return p_nullable; end if;
  p_options:=coalesce(p_options,'[]'::jsonb);p_numeric:=coalesce(p_numeric,'{}'::jsonb);p_validation:=coalesce(p_validation,'{}'::jsonb);
  if jsonb_typeof(p_options)<>'array' or jsonb_typeof(p_numeric)<>'object' or jsonb_typeof(p_validation)<>'object' then return false; end if;
  if p_answer_type='YES_NO' then return v_type='boolean'; end if;
  if p_answer_type='SINGLE_CHOICE' then return v_type='string' and exists(select 1 from jsonb_array_elements(p_options) o where o=p_value); end if;
  if p_answer_type='MULTIPLE_CHOICE' then return v_type='array' and jsonb_array_length(p_value) between coalesce((p_validation->>'minItems')::integer,0) and least(coalesce((p_validation->>'maxItems')::integer,1000),1000) and not exists(select 1 from jsonb_array_elements(p_value) x where jsonb_typeof(x)<>'string' or not exists(select 1 from jsonb_array_elements(p_options) o where o=x)); end if;
  if p_answer_type in ('SHORT_TEXT','LONG_TEXT','EMAIL','PHONE','URL','ADDRESS','GEO_AREA','CURRENCY','FILE','IMAGE') then
    if v_type<>'string' then return false; end if;v_text:=p_value#>>'{}';v_min:=coalesce((p_validation->>'minLength')::integer,0);v_max:=least(coalesce((p_validation->>'maxLength')::integer,case when p_answer_type='LONG_TEXT' then 10000 else 1000 end),10000);
    if v_min<0 or v_max<v_min or char_length(v_text) not between v_min and v_max then return false; end if;
    if p_answer_type='EMAIL' and v_text!~'^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then return false; end if;
    if p_answer_type='PHONE' and v_text!~'^\+?[0-9 ()-]{6,30}$' then return false; end if;
    if p_answer_type='URL' and v_text!~'^https://[^[:space:]]+$' then return false; end if;
    if p_answer_type='CURRENCY' and v_text!~'^[A-Z]{3}$' then return false; end if;
    if p_validation?'pattern' and (not private.is_controlled_question_pattern(p_validation->>'pattern') or v_text!~(p_validation->>'pattern')) then return false; end if;return true;
  end if;
  if p_answer_type in ('INTEGER','RATING_5','RATING_10') then
    if v_type<>'object' or p_value->>'kind'<>'INTEGER' or p_value->>'value'!~'^-?(0|[1-9][0-9]*)$' or (select count(*) from jsonb_object_keys(p_value))<>2 then return false; end if;v_exact:=(p_value->>'value')::numeric;
  elsif p_answer_type in ('DECIMAL','PERCENTAGE','QUANTITY','UNIT_VALUE') then
    if v_type<>'object' or p_value->>'kind'<>'DECIMAL' or p_value->>'value'!~'^-?(0|[1-9][0-9]*)(\.[0-9]+)?$' or (select count(*) from jsonb_object_keys(p_value))<>2 then return false; end if;v_exact:=(p_value->>'value')::numeric;
  end if;
  if p_answer_type in ('INTEGER','DECIMAL','PERCENTAGE','QUANTITY','UNIT_VALUE','RATING_5','RATING_10') then
    v_scale:=coalesce((p_numeric->>'scale')::integer,(p_validation->>'scale')::integer,case when p_answer_type in ('INTEGER','RATING_5','RATING_10') then 0 else 1000 end);v_precision:=coalesce((p_numeric->>'precision')::integer,(p_validation->>'precision')::integer,1000);v_rounding:=coalesce(p_numeric->>'rounding',p_validation->>'rounding','HALF_EVEN');
    if v_scale<0 or v_scale>v_precision or v_precision not between 1 and 1000 or v_rounding not in ('HALF_UP','HALF_EVEN','DOWN','UP') then return false; end if;
    if p_numeric<>'{}'::jsonb and (select count(*) from jsonb_object_keys(p_numeric))<>3 then return false;end if;v_rounded:=private.round_exact_question_numeric(v_exact,v_scale,v_rounding);v_text:=v_rounded::text;if position('.' in v_text)>0 then v_text:=rtrim(rtrim(v_text,'0'),'.');end if;
    if length(replace(replace(v_text,'-',''),'.',''))>v_precision then return false;end if;
    if p_answer_type='PERCENTAGE' and v_rounded not between 0 and 100 then return false; end if;if p_answer_type='RATING_5' and v_rounded not between 1 and 5 then return false; end if;if p_answer_type='RATING_10' and v_rounded not between 1 and 10 then return false; end if;
    return (not(p_validation?'minimum') or v_rounded>=(p_validation->>'minimum')::numeric) and (not(p_validation?'maximum') or v_rounded<=(p_validation->>'maximum')::numeric);
  end if;
  if p_answer_type='MONEY' then return v_type='object' and p_value->>'kind'='MONEY' and p_value->>'amountMinor'~'^-?(0|[1-9][0-9]*)$' and p_value->>'currency'~'^[A-Z]{3}$' and (select count(*) from jsonb_object_keys(p_value))=3; end if;
  if p_answer_type='DATE' then if v_type<>'string' or (p_value#>>'{}')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then return false;end if;v_text:=p_value#>>'{}';v_date:=v_text::date;return to_char(v_date,'YYYY-MM-DD')=v_text;end if;
  if p_answer_type='DATE_RANGE' then if v_type<>'object' or p_value->>'kind'<>'DATE_RANGE' or (select count(*) from jsonb_object_keys(p_value))<>3 or not private.is_valid_typed_question_answer('DATE',false,'[]','{}','{}',null,to_jsonb(p_value->>'start')) or not private.is_valid_typed_question_answer('DATE',false,'[]','{}','{}',null,to_jsonb(p_value->>'end')) then return false;end if;return (p_value->>'start')::date<=(p_value->>'end')::date;end if;
  if p_answer_type='TIME' then
    if v_type<>'object' or p_value->>'kind'<>'LOCAL_TIME' or p_value->>'localTime'!~'^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$' or p_value->>'dstPolicy' not in ('EARLIER','LATER','REJECT') or (select count(*) from jsonb_object_keys(p_value))<>5 or not private.is_valid_typed_question_answer('DATE',false,'[]','{}','{}',null,to_jsonb(p_value->>'localDate')) or not exists(select 1 from pg_timezone_names z where z.name=p_value->>'timeZone' and (z.name='UTC' or z.name like '%/%')) then return false;end if;
    v_local:=((p_value->>'localDate')||' '||(p_value->>'localTime'))::timestamp;select count(*) into v_candidates from generate_series((v_local at time zone 'UTC')-interval '15 hours',(v_local at time zone 'UTC')+interval '15 hours',interval '1 minute') g where date_trunc('second',pg_catalog.timezone(p_value->>'timeZone',g))=v_local;return v_candidates>=1 and (p_value->>'dstPolicy'<>'REJECT' or v_candidates=1);
  end if;
  if p_answer_type in ('TABLE','REPEATER') then
    if v_type<>'array' or p_structured is null or p_structured->>'kind'<>p_answer_type or length(p_structured->>'version')<1 then return false;end if;v_fields:=p_structured->(case when p_answer_type='TABLE' then 'columns' else 'children' end);
    if jsonb_typeof(v_fields)<>'array' or jsonb_array_length(v_fields)<1 or exists(select 1 from jsonb_array_elements(v_fields) f where jsonb_typeof(f)<>'object' or not(f?'key' and f?'type' and f?'nullable') or exists(select 1 from jsonb_object_keys(f) k where k not in ('key','type','nullable','options','numeric','validation')) or f->>'type' in ('TABLE','REPEATER')) or (select count(*) from jsonb_array_elements(v_fields))<>(select count(distinct f->>'key') from jsonb_array_elements(v_fields) f) then return false;end if;
    v_count:=jsonb_array_length(p_value);v_min:=coalesce((p_structured->>case when p_answer_type='TABLE' then 'minRows' else 'minItems' end)::integer,-1);v_max:=coalesce((p_structured->>case when p_answer_type='TABLE' then 'maxRows' else 'maxItems' end)::integer,-1);if v_min<0 or v_max<v_min or v_max>1000 or v_count not between v_min and v_max then return false;end if;
    for v_row in select value from jsonb_array_elements(p_value) loop
      if jsonb_typeof(v_row)<>'object' or (select count(*) from jsonb_object_keys(v_row))<>jsonb_array_length(v_fields) or exists(select 1 from jsonb_object_keys(v_row) k where not exists(select 1 from jsonb_array_elements(v_fields) f where f->>'key'=k)) then return false;end if;
      for v_field in select value from jsonb_array_elements(v_fields) loop if not private.is_valid_typed_question_answer(v_field->>'type',coalesce((v_field->>'nullable')::boolean,false),coalesce(v_field->'options','[]'),coalesce(v_field->'numeric','{}'),coalesce(v_field->'validation','{}'),null,v_row->(v_field->>'key')) then return false;end if;end loop;
    end loop;return true;
  end if;
  if p_answer_type in ('MULTI_FILE','PRODUCT_LIST','SITE_LIST','MILESTONE_LIST') then return v_type='array' and jsonb_array_length(p_value) between coalesce((p_validation->>'minItems')::integer,0) and least(coalesce((p_validation->>'maxItems')::integer,1000),1000);end if;
  if p_answer_type in ('CONTACT','ORGANIZATION','BUDGET_BREAKDOWN') then return v_type='object' and (select count(*) from jsonb_object_keys(p_value)) between 1 and 100;end if;return false;
exception when others then return false;
end $$;
revoke all on function private.is_valid_typed_question_answer(text,boolean,jsonb,jsonb,jsonb,jsonb,jsonb) from public,anon,authenticated,service_role;

create or replace function private.is_valid_question_answer(p_question public.question_versions,p_value jsonb) returns boolean
language sql stable security definer set search_path=pg_catalog as $$
  select private.is_valid_typed_question_answer(p_question.answer_type,p_question.nullable,p_question.options,jsonb_build_object('precision',coalesce((p_question.validation_schema->>'precision')::integer,1000),'scale',coalesce((p_question.validation_schema->>'scale')::integer,case when p_question.answer_type in ('INTEGER','RATING_5','RATING_10') then 0 else 1000 end),'rounding',coalesce(p_question.validation_schema->>'rounding','HALF_EVEN')),p_question.validation_schema,p_question.structured_schema,p_value)
$$;
revoke all on function private.is_valid_question_answer(public.question_versions,jsonb) from public,anon,authenticated,service_role;

create or replace function private.is_valid_typed_question_metadata(p_answer_type text,p_options jsonb,p_numeric jsonb,p_validation jsonb,p_structured jsonb) returns boolean
language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_field jsonb;v_fields jsonb;v_min integer;v_max integer;
begin
  p_options:=coalesce(p_options,'[]');p_numeric:=coalesce(p_numeric,'{}');p_validation:=coalesce(p_validation,'{}');
  if jsonb_typeof(p_options)<>'array' or jsonb_typeof(p_numeric)<>'object' or jsonb_typeof(p_validation)<>'object' or exists(select 1 from jsonb_object_keys(p_validation) k where k not in ('minLength','maxLength','minItems','maxItems','minimum','maximum','pattern','precision','scale','rounding')) then return false;end if;
  if exists(select 1 from jsonb_array_elements(p_options) o where jsonb_typeof(o)<>'string' or length(o#>>'{}')<1) or jsonb_array_length(p_options)<>(select count(distinct o) from jsonb_array_elements(p_options) o) then return false;end if;
  if (p_answer_type in ('SINGLE_CHOICE','MULTIPLE_CHOICE')) is distinct from (jsonb_array_length(p_options)>0) then return false;end if;
  if p_validation?'minLength' or p_validation?'maxLength' then v_min:=coalesce((p_validation->>'minLength')::integer,0);v_max:=coalesce((p_validation->>'maxLength')::integer,10000);if v_min<0 or v_max<v_min or v_max>10000 then return false;end if;end if;
  if p_validation?'minItems' or p_validation?'maxItems' then v_min:=coalesce((p_validation->>'minItems')::integer,0);v_max:=coalesce((p_validation->>'maxItems')::integer,1000);if v_min<0 or v_max<v_min or v_max>1000 then return false;end if;end if;
  if p_validation?'minimum' and (p_validation->>'minimum')!~'^-?(0|[1-9][0-9]*)(\.[0-9]+)?$' then return false;end if;if p_validation?'maximum' and (p_validation->>'maximum')!~'^-?(0|[1-9][0-9]*)(\.[0-9]+)?$' then return false;end if;if p_validation?'minimum' and p_validation?'maximum' and (p_validation->>'minimum')::numeric>(p_validation->>'maximum')::numeric then return false;end if;
  if p_validation?'pattern' and (p_answer_type not in ('SHORT_TEXT','LONG_TEXT','EMAIL','PHONE','URL') or not private.is_controlled_question_pattern(p_validation->>'pattern')) then return false;end if;
  if p_answer_type in ('INTEGER','DECIMAL','PERCENTAGE','QUANTITY','UNIT_VALUE','RATING_5','RATING_10') then if (select count(*) from jsonb_object_keys(p_numeric))<>3 or (p_numeric->>'precision')::integer not between 1 and 1000 or (p_numeric->>'scale')::integer not between 0 and (p_numeric->>'precision')::integer or p_numeric->>'rounding' not in ('HALF_UP','HALF_EVEN','DOWN','UP') or (p_answer_type in ('INTEGER','RATING_5','RATING_10') and (p_numeric->>'scale')::integer<>0) then return false;end if;elsif p_numeric<>'{}' then return false;end if;
  if p_answer_type in ('TABLE','REPEATER') then v_fields:=p_structured->(case when p_answer_type='TABLE' then 'columns' else 'children' end);v_min:=coalesce((p_structured->>case when p_answer_type='TABLE' then 'minRows' else 'minItems' end)::integer,-1);v_max:=coalesce((p_structured->>case when p_answer_type='TABLE' then 'maxRows' else 'maxItems' end)::integer,-1);if p_structured is null or p_structured->>'kind'<>p_answer_type or length(p_structured->>'version')<1 or jsonb_typeof(v_fields)<>'array' or jsonb_array_length(v_fields)<1 or v_min<0 or v_max<v_min or v_max>1000 then return false;end if;for v_field in select value from jsonb_array_elements(v_fields) loop if not private.is_valid_typed_question_metadata(v_field->>'type',coalesce(v_field->'options','[]'),coalesce(v_field->'numeric','{}'),coalesce(v_field->'validation','{}'),null) then return false;end if;end loop;elsif p_structured is not null then return false;end if;return true;
exception when others then return false;
end $$;
revoke all on function private.is_valid_typed_question_metadata(text,jsonb,jsonb,jsonb,jsonb) from public,anon,authenticated,service_role;

create or replace function private.is_valid_question_metadata(p_question public.question_versions) returns boolean
language sql stable security definer set search_path=pg_catalog as $$ select private.is_valid_typed_question_metadata(p_question.answer_type,p_question.options,case when p_question.answer_type in ('INTEGER','DECIMAL','PERCENTAGE','QUANTITY','UNIT_VALUE','RATING_5','RATING_10') then jsonb_build_object('precision',coalesce((p_question.validation_schema->>'precision')::integer,1000),'scale',coalesce((p_question.validation_schema->>'scale')::integer,case when p_question.answer_type in ('INTEGER','RATING_5','RATING_10') then 0 else 1000 end),'rounding',coalesce(p_question.validation_schema->>'rounding','HALF_EVEN')) else '{}'::jsonb end,p_question.validation_schema,p_question.structured_schema) $$;
revoke all on function private.is_valid_question_metadata(public.question_versions) from public,anon,authenticated,service_role;

alter table public.questionnaires enable row level security;
alter table public.questionnaire_versions enable row level security;
alter table public.questionnaire_sections enable row level security;
alter table public.question_bank_questions enable row level security;
alter table public.question_versions enable row level security;
alter table public.questionnaire_version_questions enable row level security;
alter table public.question_rules enable row level security;
alter table public.question_rule_versions enable row level security;
alter table public.questionnaire_version_rules enable row level security;
alter table public.questionnaire_sessions enable row level security;
alter table public.questionnaire_answers enable row level security;
alter table public.questionnaire_answer_revisions enable row level security;

revoke all on table public.questionnaires, public.questionnaire_versions, public.questionnaire_sections,
  public.question_bank_questions, public.question_versions, public.questionnaire_version_questions,
  public.question_rules, public.question_rule_versions, public.questionnaire_version_rules,
  public.questionnaire_sessions, public.questionnaire_answers, public.questionnaire_answer_revisions
from public, anon, authenticated, service_role;
revoke all on table private.questionnaire_command_keys from public, anon, authenticated, service_role;

grant select on table public.questionnaires, public.questionnaire_versions, public.questionnaire_sections,
  public.question_bank_questions, public.question_versions, public.questionnaire_version_questions,
  public.question_rules, public.question_rule_versions, public.questionnaire_version_rules,
  public.questionnaire_sessions, public.questionnaire_answers, public.questionnaire_answer_revisions
to authenticated;
grant select on table public.question_rules,public.question_rule_versions,public.questionnaire_version_rules to service_role;

create policy questionnaires_read on public.questionnaires for select to authenticated using (exists(select 1 from public.questionnaire_versions v where v.questionnaire_id=questionnaires.id and ((v.id=current_published_version_id and private.can_read_questionnaire_version(v.id)) or (v.status<>'PUBLISHED' and private.can_read_questionnaire_version(v.id)))));
create policy questionnaire_versions_read on public.questionnaire_versions for select to authenticated using (private.can_read_questionnaire_version(id));
create policy questionnaire_sections_read on public.questionnaire_sections for select to authenticated using (
  private.can_read_questionnaire_version(questionnaire_version_id)
);
create policy question_bank_read on public.question_bank_questions for select to authenticated using (
  (private.has_library_permission(library_id,'CATALOG_VIEW_DRAFT',auth.uid()) and (auth.jwt()->>'aal'='aal2' or not private.has_any_questionnaire_platform_role()))
  or exists (select 1 from public.question_versions qv join public.questionnaire_version_questions qvq on qvq.question_version_id=qv.id where qv.question_id=question_bank_questions.id and qv.status in ('PUBLISHED','SUPERSEDED') and private.can_read_questionnaire_version(qvq.questionnaire_version_id))
);
create policy question_versions_read on public.question_versions for select to authenticated using (
  (private.has_library_permission(library_id,'CATALOG_VIEW_DRAFT',auth.uid()) and (auth.jwt()->>'aal'='aal2' or not private.has_any_questionnaire_platform_role()))
  or (status in ('PUBLISHED','SUPERSEDED') and exists (select 1 from public.questionnaire_version_questions qvq where qvq.question_version_id=question_versions.id and private.can_read_questionnaire_version(qvq.questionnaire_version_id)))
);
create policy questionnaire_version_questions_read on public.questionnaire_version_questions for select to authenticated using (
  private.can_read_questionnaire_version(questionnaire_version_id)
);
create policy question_rules_read on public.question_rules for select to authenticated using (private.has_library_permission(library_id,'CATALOG_VIEW_DRAFT',auth.uid()) and (auth.jwt()->>'aal'='aal2' or not private.has_any_questionnaire_platform_role()));
create policy question_rule_versions_read on public.question_rule_versions for select to authenticated using (private.has_library_permission(library_id,'CATALOG_VIEW_DRAFT',auth.uid()) and (auth.jwt()->>'aal'='aal2' or not private.has_any_questionnaire_platform_role()));
create policy questionnaire_version_rules_read on public.questionnaire_version_rules for select to authenticated using (
  exists (select 1 from public.questionnaire_versions v where v.id=questionnaire_version_id and private.has_library_permission(v.library_id,'CATALOG_VIEW_DRAFT',auth.uid()) and (auth.jwt()->>'aal'='aal2' or not private.has_any_questionnaire_platform_role()))
);
create policy questionnaire_sessions_read on public.questionnaire_sessions for select to authenticated using (private.can_access_questionnaire_session(id));
create policy questionnaire_answers_read on public.questionnaire_answers for select to authenticated using (private.can_access_questionnaire_session(session_id));
create policy questionnaire_answer_revisions_read on public.questionnaire_answer_revisions for select to authenticated using (private.can_read_questionnaire_answer_revision(session_id));

create index questionnaires_library_status_idx on public.questionnaires(library_id, status, code);
create index questionnaire_versions_release_idx on public.questionnaire_versions(catalog_release_id, status, questionnaire_id, version desc);
create index questionnaire_sections_order_idx on public.questionnaire_sections(questionnaire_version_id, sort_order);
create index question_bank_library_idx on public.question_bank_questions(library_id, status, question_key);
create index question_versions_question_idx on public.question_versions(question_id, status, version desc);
create index questionnaire_questions_order_idx on public.questionnaire_version_questions(questionnaire_version_id, sort_order);
create index question_rules_library_idx on public.question_rules(library_id, status, rule_key);
create index question_rule_versions_rule_idx on public.question_rule_versions(rule_id, status, version desc);
create index questionnaire_rules_order_idx on public.questionnaire_version_rules(questionnaire_version_id, evaluation_order);
create index questionnaire_sessions_actor_idx on public.questionnaire_sessions(actor_user_id, status, updated_at desc);
create index questionnaire_sessions_org_idx on public.questionnaire_sessions(organization_id, status, updated_at desc);
create index questionnaire_answers_session_idx on public.questionnaire_answers(session_id, question_version_id);
create index questionnaire_answer_revisions_session_idx on public.questionnaire_answer_revisions(session_id, answered_at desc);
create index questionnaires_created_by_idx on public.questionnaires(created_by);
create index questionnaire_versions_library_idx on public.questionnaire_versions(library_id, status);
create index questionnaire_versions_created_by_idx on public.questionnaire_versions(created_by);
create index questionnaire_sections_version_fk_idx on public.questionnaire_sections(questionnaire_version_id);
create index question_bank_source_idx on public.question_bank_questions(source_question_id) where source_question_id is not null;
create index question_bank_created_by_idx on public.question_bank_questions(created_by);
create index question_versions_library_idx on public.question_versions(library_id, status);
create index question_versions_created_by_idx on public.question_versions(created_by);
create index questionnaire_questions_section_idx on public.questionnaire_version_questions(section_id);
create index questionnaire_questions_question_idx on public.questionnaire_version_questions(question_version_id);
create index question_rules_created_by_idx on public.question_rules(created_by);
create index question_rule_versions_library_idx on public.question_rule_versions(library_id, status);
create index question_rule_versions_created_by_idx on public.question_rule_versions(created_by);
create index questionnaire_rules_rule_idx on public.questionnaire_version_rules(rule_version_id);
create index questionnaire_sessions_revision_idx on public.questionnaire_sessions(revision_of_session_id) where revision_of_session_id is not null;
create index questionnaire_sessions_library_idx on public.questionnaire_sessions(library_id, questionnaire_version_id);
create index questionnaire_sessions_release_idx on public.questionnaire_sessions(catalog_release_id);
create index questionnaire_answers_org_idx on public.questionnaire_answers(organization_id, session_id);
create index questionnaire_answers_question_idx on public.questionnaire_answers(question_version_id);
create index questionnaire_answer_revisions_answer_idx on public.questionnaire_answer_revisions(answer_id, revision desc);
create index questionnaire_answer_revisions_org_idx on public.questionnaire_answer_revisions(organization_id, session_id);
create index questionnaire_answer_revisions_question_idx on public.questionnaire_answer_revisions(question_version_id);
create index questionnaire_answer_revisions_actor_idx on public.questionnaire_answer_revisions(answered_by);

create or replace function public.publish_questionnaire_version(p_questionnaire_version_id uuid,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$
declare v_actor uuid:=auth.uid();v_version public.questionnaire_versions%rowtype;v_identity public.questionnaires%rowtype;v_existing private.questionnaire_command_keys%rowtype;v_hash text;v_snapshot text;v_response jsonb;v_metadata jsonb;v_effective_sensitive boolean;v_command_id uuid;
begin
  if v_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if p_expected_row_version is null or p_expected_row_version<1 or p_correlation_id is null or length(p_idempotency_key) not between 8 and 200 then raise exception 'INVALID_PUBLISH_REQUEST' using errcode='22023'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('questionnaire.publish:'||p_questionnaire_version_id::text,0));
  select * into v_version from public.questionnaire_versions where id=p_questionnaire_version_id for update;
  v_effective_sensitive:=v_version.sensitive or exists(select 1 from public.questionnaire_version_questions x join public.question_versions q on q.id=x.question_version_id where x.questionnaire_version_id=v_version.id and q.sensitivity in ('CONFIDENTIAL','RESTRICTED')) or exists(select 1 from public.questionnaire_version_rules x join public.question_rule_versions r on r.id=x.rule_version_id where x.questionnaire_version_id=v_version.id and r.sensitive);
  if not found or not private.has_library_permission(v_version.library_id,'CATALOG_PUBLISH',v_actor) or (v_effective_sensitive and (not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],v_actor) or auth.jwt()->>'aal'<>'aal2')) then raise exception 'QUESTIONNAIRE_PUBLISH_DENIED' using errcode='42501'; end if;
  v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('version_id',p_questionnaire_version_id,'expected_row_version',p_expected_row_version)::text,'UTF8'),'sha256'),'hex');
  select * into v_existing from private.questionnaire_command_keys where actor_user_id=v_actor and operation_scope='questionnaire.version.publish' and key=p_idempotency_key for update;
  if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_KEY_REUSED' using errcode='23505'; end if; return v_existing.response_body; end if;
  if v_version.status not in ('APPROVED','SCHEDULED') then raise exception 'QUESTIONNAIRE_NOT_PUBLISHABLE' using errcode='55000'; end if;
  if v_version.row_version is distinct from p_expected_row_version then raise exception 'STALE_QUESTIONNAIRE_VERSION' using errcode='40001'; end if;
  if exists(select 1 from public.questionnaire_version_questions x join public.question_versions q on q.id=x.question_version_id where x.questionnaire_version_id=v_version.id and not private.is_valid_question_metadata(q)) then raise exception 'QUESTIONNAIRE_QUESTION_METADATA_INVALID' using errcode='23514';end if;
  select * into v_identity from public.questionnaires where id=v_version.questionnaire_id for update;
  insert into private.questionnaire_command_keys values(v_actor,'questionnaire.version.publish',p_idempotency_key,v_hash,null,clock_timestamp(),null,default) returning command_id into v_command_id;
  if v_identity.current_published_version_id is not null then update public.questionnaire_versions set status='SUPERSEDED',superseded_at=clock_timestamp(),row_version=row_version+1 where id=v_identity.current_published_version_id and status='PUBLISHED'; end if;
  v_metadata:=jsonb_build_object('questionnaire_id',v_version.questionnaire_id,'library_id',v_version.library_id,'release_id',v_version.catalog_release_id,'version',v_version.version,'title_fr',v_version.title_fr,'title_ar',v_version.title_ar,'description_fr',v_version.description_fr,'description_ar',v_version.description_ar,'audience',v_version.audience,'engine_version',v_version.engine_version,'policy_version',v_version.policy_version);
  v_snapshot:=private.compute_questionnaire_snapshot_hash(v_version.id,v_metadata);
  update public.questionnaire_versions set status='PUBLISHED',snapshot_hash=v_snapshot,published_at=clock_timestamp(),row_version=row_version+1 where id=v_version.id returning * into v_version;
  update public.questionnaires set status='PUBLISHED',current_published_version_id=v_version.id,current_draft_version_id=null,archived_at=null,row_version=row_version+1 where id=v_identity.id;
  v_response:=jsonb_build_object('outcome','QUESTIONNAIRE_VERSION_PUBLISHED','questionnaire_id',v_identity.id,'questionnaire_version_id',v_version.id,'row_version',v_version.row_version,'snapshot_hash',v_snapshot);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values((select steward_organization_id from public.catalog_libraries where id=v_version.library_id),v_actor,'USER','questionnaire.version.published','questionnaire_version',v_version.id::text,p_correlation_id,jsonb_build_object('questionnaire_id',v_identity.id,'snapshot_hash',v_snapshot,'superseded_version_id',v_identity.current_published_version_id),null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id) values((select steward_organization_id from public.catalog_libraries where id=v_version.library_id),'questionnaire_version',v_version.id::text,'QuestionnaireVersionPublishedV1',p_correlation_id,jsonb_build_object('questionnaire_id',v_identity.id,'questionnaire_version_id',v_version.id,'snapshot_hash',v_snapshot,'superseded_version_id',v_identity.current_published_version_id),p_idempotency_key,v_command_id);
  update private.questionnaire_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='questionnaire.version.publish' and key=p_idempotency_key;
  return v_response;
end $$;

create or replace function public.start_questionnaire_session(
  p_organization_id uuid, p_questionnaire_version_id uuid, p_locale text,
  p_due_at timestamptz, p_idempotency_key text, p_correlation_id uuid
) returns jsonb language plpgsql security definer set search_path = pg_catalog as $$
declare v_actor uuid := auth.uid(); v_version public.questionnaire_versions%rowtype; v_existing private.questionnaire_command_keys%rowtype; v_hash text; v_id uuid; v_response jsonb; v_command_id uuid;
begin
  if v_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if p_correlation_id is null or length(p_idempotency_key) not between 8 and 200 or p_locale not in ('fr-MA','ar-MA') then raise exception 'INVALID_SESSION_REQUEST' using errcode='22023'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_actor::text||':questionnaire.session.start:'||p_idempotency_key,0));
  select * into v_version from public.questionnaire_versions where id=p_questionnaire_version_id;
  if not found or v_version.status<>'PUBLISHED' or not private.can_read_catalog_release(v_version.catalog_release_id,v_actor) or not exists(select 1 from public.questionnaires q where q.id=v_version.questionnaire_id and q.status='PUBLISHED' and q.current_published_version_id=v_version.id) or not exists(select 1 from public.catalog_releases r where r.id=v_version.catalog_release_id and (r.audience->>'kind'='PUBLIC' or (r.audience->>'kind'='ORGANIZATIONS' and coalesce(r.audience->'organization_ids','[]'::jsonb)?p_organization_id::text))) then raise exception 'QUESTIONNAIRE_NOT_AVAILABLE' using errcode='42501'; end if;
  if not private.has_questionnaire_audience_access(p_organization_id,v_version.library_id,v_version.audience,'START',v_actor) then raise exception 'ORGANIZATION_SCOPE_DENIED' using errcode='42501'; end if;
  if p_due_at is not null and p_due_at<=statement_timestamp() then raise exception 'INVALID_SESSION_DUE_AT' using errcode='22023'; end if;
  v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('organization_id',p_organization_id,'questionnaire_version_id',p_questionnaire_version_id,'locale',p_locale,'due_at',p_due_at)::text,'UTF8'),'sha256'),'hex');
  select * into v_existing from private.questionnaire_command_keys where actor_user_id=v_actor and operation_scope='questionnaire.session.start' and key=p_idempotency_key for update;
  if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_KEY_REUSED' using errcode='23505'; end if; return v_existing.response_body; end if;
  insert into private.questionnaire_command_keys values(v_actor,'questionnaire.session.start',p_idempotency_key,v_hash,null,clock_timestamp(),null,default) returning command_id into v_command_id;
  insert into public.questionnaire_sessions(organization_id,actor_user_id,library_id,catalog_release_id,questionnaire_version_id,audience,locale,status,due_at)
  values(p_organization_id,v_actor,v_version.library_id,v_version.catalog_release_id,v_version.id,v_version.audience,p_locale,'DRAFT',p_due_at) returning id into v_id;
  v_response:=jsonb_build_object('outcome','QUESTIONNAIRE_SESSION_STARTED','session_id',v_id,'row_version',1,'questionnaire_version_id',v_version.id);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
  values(p_organization_id,v_actor,'USER','questionnaire.session.started','questionnaire_session',v_id::text,p_correlation_id,jsonb_build_object('questionnaire_version_id',v_version.id),null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)
  values(p_organization_id,'questionnaire_session',v_id::text,'QuestionnaireSessionStartedV1',p_correlation_id,jsonb_build_object('session_id',v_id,'questionnaire_version_id',v_version.id),p_idempotency_key,v_command_id);
  update private.questionnaire_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='questionnaire.session.start' and key=p_idempotency_key;
  return v_response;
end $$;

create or replace function public.autosave_questionnaire_answers(
  p_session_id uuid, p_expected_row_version integer, p_answers jsonb,
  p_idempotency_key text, p_correlation_id uuid
) returns jsonb language plpgsql security definer set search_path = pg_catalog as $$
declare v_actor uuid:=auth.uid(); v_session public.questionnaire_sessions%rowtype; v_existing private.questionnaire_command_keys%rowtype; v_hash text; v_response jsonb; v_item jsonb; v_qv public.question_versions%rowtype; v_answer public.questionnaire_answers%rowtype; v_answer_id uuid; v_revision integer; v_accepted jsonb:='[]'::jsonb; v_conflicts jsonb:='[]'::jsonb; v_seen uuid[]:='{}'; v_command_id uuid;
begin
  if v_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if p_correlation_id is null or p_expected_row_version is null or p_expected_row_version<1 or length(p_idempotency_key) not between 8 and 200 or p_answers is null or jsonb_typeof(p_answers)<>'array' or jsonb_array_length(p_answers) not between 1 and 100 or octet_length(convert_to(p_answers::text,'UTF8'))>50000 then raise exception 'INVALID_AUTOSAVE_REQUEST' using errcode='22023'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_actor::text||':questionnaire.session.autosave:'||p_idempotency_key,0));
  v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('session_id',p_session_id,'expected_row_version',p_expected_row_version,'answers',p_answers)::text,'UTF8'),'sha256'),'hex');
  select * into v_session from public.questionnaire_sessions where id=p_session_id for update;
  if not found or v_session.actor_user_id<>v_actor or not private.has_questionnaire_audience_access(v_session.organization_id,v_session.library_id,v_session.audience,'EDIT',v_actor) then raise exception 'SESSION_SCOPE_DENIED' using errcode='42501'; end if;
  select * into v_existing from private.questionnaire_command_keys where actor_user_id=v_actor and operation_scope='questionnaire.session.autosave' and key=p_idempotency_key for update;
  if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_KEY_REUSED' using errcode='23505'; end if; return v_existing.response_body; end if;
  if v_session.status not in ('DRAFT','IN_PROGRESS','READY') then raise exception 'SESSION_NOT_EDITABLE' using errcode='55000'; end if;
  if v_session.row_version<>p_expected_row_version then
    v_response:=jsonb_build_object('outcome','AUTOSAVE_CONFLICT','session_id',p_session_id,'server_row_version',v_session.row_version,'conflicts',(select coalesce(jsonb_agg(jsonb_build_object('question_version_id',a.question_version_id,'answer_row_version',a.row_version) order by a.question_version_id::text),'[]'::jsonb) from public.questionnaire_answers a where a.session_id=p_session_id));
    insert into private.questionnaire_command_keys values(v_actor,'questionnaire.session.autosave',p_idempotency_key,v_hash,v_response,clock_timestamp(),clock_timestamp(),default);
    return v_response;
  end if;
  insert into private.questionnaire_command_keys values(v_actor,'questionnaire.session.autosave',p_idempotency_key,v_hash,null,clock_timestamp(),null,default) returning command_id into v_command_id;
  for v_item in select value from jsonb_array_elements(p_answers) loop
    if jsonb_typeof(v_item)<>'object' or not (v_item ? 'question_version_id') or not (v_item ? 'value') or not (v_item ? 'expected_answer_row_version') or (v_item-array['question_version_id','value','expected_answer_row_version'])<>'{}'::jsonb or (v_item->>'expected_answer_row_version') is null or (v_item->>'expected_answer_row_version')::integer<0 then raise exception 'INVALID_ANSWER_ITEM' using errcode='22023'; end if;
    if (v_item->>'question_version_id')::uuid = any(v_seen) then raise exception 'DUPLICATE_ANSWER_ITEM' using errcode='22023'; end if;
    v_seen:=array_append(v_seen,(v_item->>'question_version_id')::uuid);
    select qv.* into v_qv from public.question_versions qv join public.questionnaire_version_questions qvq on qvq.question_version_id=qv.id where qvq.questionnaire_version_id=v_session.questionnaire_version_id and qv.id=(v_item->>'question_version_id')::uuid;
    if not found then raise exception 'QUESTION_NOT_IN_SESSION_SNAPSHOT' using errcode='23503'; end if;
    if not private.is_valid_question_answer(v_qv,v_item->'value') then raise exception 'INVALID_ANSWER_VALUE' using errcode='22023'; end if;
    select * into v_answer from public.questionnaire_answers where session_id=p_session_id and question_version_id=v_qv.id for update;
    if found and v_answer.row_version is distinct from (v_item->>'expected_answer_row_version')::integer then
      v_conflicts:=v_conflicts||jsonb_build_array(jsonb_build_object('question_version_id',v_qv.id,'answer_row_version',v_answer.row_version));
      continue;
    elsif not found and (v_item->>'expected_answer_row_version')::integer<>0 then
      v_conflicts:=v_conflicts||jsonb_build_array(jsonb_build_object('question_version_id',v_qv.id,'answer_row_version',0));
      continue;
    end if;
    if not found then
      insert into public.questionnaire_answers(session_id,organization_id,question_version_id) values(p_session_id,v_session.organization_id,v_qv.id) returning * into v_answer;
      v_answer_id:=v_answer.id;
      v_revision:=1;
    else v_answer_id:=v_answer.id; v_revision:=v_answer.row_version+1; end if;
    insert into public.questionnaire_answer_revisions(answer_id,session_id,organization_id,question_version_id,revision,value,source,sensitivity,answer_hash,answered_by,expires_at)
    values(v_answer_id,p_session_id,v_session.organization_id,v_qv.id,v_revision,v_item->'value','USER',v_qv.sensitivity,encode(extensions.digest(convert_to((v_item->'value')::text,'UTF8'),'sha256'),'hex'),v_actor,case when v_qv.validity_interval is null then null else clock_timestamp()+v_qv.validity_interval end)
    returning id into v_answer.current_revision_id;
    update public.questionnaire_answers set current_revision_id=v_answer.current_revision_id,row_version=v_revision,updated_at=clock_timestamp() where id=v_answer_id;
    v_accepted:=v_accepted||jsonb_build_array(jsonb_build_object('question_version_id',v_qv.id,'answer_row_version',v_revision));
  end loop;
  if jsonb_array_length(v_accepted)>0 then
    update public.questionnaire_sessions set status=case when status='DRAFT' then 'IN_PROGRESS' else status end,row_version=row_version+1,updated_at=clock_timestamp() where id=p_session_id returning row_version into v_session.row_version;
  end if;
  v_response:=jsonb_build_object('outcome',case when jsonb_array_length(v_conflicts)>0 then 'AUTOSAVE_PARTIAL_CONFLICT' else 'AUTOSAVE_SAVED' end,'session_id',p_session_id,'server_row_version',v_session.row_version,'accepted',v_accepted,'conflicts',v_conflicts);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
  values(v_session.organization_id,v_actor,'USER',case when jsonb_array_length(v_accepted)>0 then 'questionnaire.answers.autosaved' else 'questionnaire.answers.conflicted' end,'questionnaire_session',p_session_id::text,p_correlation_id,jsonb_build_object('accepted_count',jsonb_array_length(v_accepted),'conflict_count',jsonb_array_length(v_conflicts)),null,repeat('0',64));
  if jsonb_array_length(v_accepted)>0 then
    insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)
    values(v_session.organization_id,'questionnaire_session',p_session_id::text,'QuestionnaireAnswersSavedV1',p_correlation_id,jsonb_build_object('session_id',p_session_id,'accepted_question_version_ids',(select coalesce(jsonb_agg(x->>'question_version_id'),'[]'::jsonb) from pg_catalog.jsonb_array_elements(v_accepted) x)),p_idempotency_key,v_command_id);
  end if;
  update private.questionnaire_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='questionnaire.session.autosave' and key=p_idempotency_key;
  return v_response;
exception when invalid_text_representation then raise exception 'INVALID_ANSWER_ITEM' using errcode='22023';
end $$;

create or replace function public.submit_questionnaire_session(
  p_session_id uuid, p_expected_row_version integer, p_idempotency_key text, p_correlation_id uuid
) returns jsonb language plpgsql security definer set search_path = pg_catalog as $$
declare v_actor uuid:=auth.uid(); v_session public.questionnaire_sessions%rowtype; v_existing private.questionnaire_command_keys%rowtype; v_hash text; v_manifest jsonb; v_manifest_hash text; v_response jsonb; v_missing integer; v_command_id uuid;
begin
  if v_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if p_correlation_id is null or p_expected_row_version is null or p_expected_row_version<1 or length(p_idempotency_key) not between 8 and 200 then raise exception 'INVALID_SUBMIT_REQUEST' using errcode='22023'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_actor::text||':questionnaire.session.submit:'||p_idempotency_key,0));
  v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('session_id',p_session_id,'expected_row_version',p_expected_row_version)::text,'UTF8'),'sha256'),'hex');
  select * into v_session from public.questionnaire_sessions where id=p_session_id for update;
  if not found or v_session.actor_user_id<>v_actor or not private.has_questionnaire_audience_access(v_session.organization_id,v_session.library_id,v_session.audience,'SUBMIT',v_actor) then raise exception 'SESSION_SCOPE_DENIED' using errcode='42501'; end if;
  select * into v_existing from private.questionnaire_command_keys where actor_user_id=v_actor and operation_scope='questionnaire.session.submit' and key=p_idempotency_key for update;
  if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_KEY_REUSED' using errcode='23505'; end if; return v_existing.response_body; end if;
  if v_session.status not in ('IN_PROGRESS','READY') then raise exception 'SESSION_NOT_SUBMITTABLE' using errcode='55000'; end if;
  if v_session.row_version is distinct from p_expected_row_version then raise exception 'STALE_SESSION_VERSION' using errcode='40001'; end if;
  select count(*) into v_missing from public.questionnaire_version_questions qvq join public.question_versions qv on qv.id=qvq.question_version_id left join public.questionnaire_answers a on a.session_id=p_session_id and a.question_version_id=qv.id left join public.questionnaire_answer_revisions ar on ar.id=a.current_revision_id where qvq.questionnaire_version_id=v_session.questionnaire_version_id and coalesce(qvq.required_override,qv.required_by_default) and (a.current_revision_id is null or ar.value='null'::jsonb);
  if v_missing>0 then raise exception 'REQUIRED_ANSWERS_MISSING' using errcode='23514'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('question_version_id',a.question_version_id,'answer_revision_id',a.current_revision_id,'answer_hash',r.answer_hash) order by a.question_version_id::text),'[]'::jsonb) into v_manifest from public.questionnaire_answers a join public.questionnaire_answer_revisions r on r.id=a.current_revision_id where a.session_id=p_session_id;
  v_manifest_hash:=encode(extensions.digest(convert_to(v_manifest::text,'UTF8'),'sha256'),'hex');
  insert into private.questionnaire_command_keys values(v_actor,'questionnaire.session.submit',p_idempotency_key,v_hash,null,clock_timestamp(),null,default) returning command_id into v_command_id;
  update public.questionnaire_sessions set status='SUBMITTED',submitted_at=clock_timestamp(),updated_at=clock_timestamp(),answer_manifest=v_manifest,answer_manifest_hash=v_manifest_hash,row_version=row_version+1 where id=p_session_id returning * into v_session;
  v_response:=jsonb_build_object('outcome','QUESTIONNAIRE_SESSION_SUBMITTED','session_id',p_session_id,'row_version',v_session.row_version,'answer_manifest_hash',v_manifest_hash);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
  values(v_session.organization_id,v_actor,'USER','questionnaire.session.submitted','questionnaire_session',p_session_id::text,p_correlation_id,jsonb_build_object('questionnaire_version_id',v_session.questionnaire_version_id,'answer_manifest_hash',v_manifest_hash),null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)
  values(v_session.organization_id,'questionnaire_session',p_session_id::text,'QuestionnaireSessionSubmittedV1',p_correlation_id,jsonb_build_object('session_id',p_session_id,'questionnaire_version_id',v_session.questionnaire_version_id),p_idempotency_key,v_command_id);
  update private.questionnaire_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='questionnaire.session.submit' and key=p_idempotency_key;
  return v_response;
end $$;

revoke all on function public.publish_questionnaire_version(uuid,integer,text,uuid), public.start_questionnaire_session(uuid,uuid,text,timestamptz,text,uuid), public.autosave_questionnaire_answers(uuid,integer,jsonb,text,uuid), public.submit_questionnaire_session(uuid,integer,text,uuid) from public, anon, authenticated, service_role;
grant execute on function public.publish_questionnaire_version(uuid,integer,text,uuid), public.start_questionnaire_session(uuid,uuid,text,timestamptz,text,uuid), public.submit_questionnaire_session(uuid,integer,text,uuid) to authenticated;
grant execute on function public.autosave_questionnaire_answers(uuid,integer,jsonb,text,uuid) to authenticated;

notify pgrst, 'reload schema';
