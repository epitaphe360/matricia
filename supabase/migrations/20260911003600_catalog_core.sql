-- P06 catalog core: versioned hierarchy, staged imports and reproducible releases.

create table public.catalog_libraries (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z][A-Z0-9_-]{1,31}$'),
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  status text not null default 'DRAFT' check (status in ('DRAFT','IN_REVIEW','APPROVED','PUBLISHED','RETIRED','ARCHIVED')),
  steward_organization_id uuid not null references public.organizations(id) on delete restrict,
  current_draft_version_id uuid,
  current_published_version_id uuid,
  current_release_id uuid,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  archived_at timestamptz,
  row_version integer not null default 1 check (row_version > 0),
  check ((status = 'ARCHIVED') = (archived_at is not null))
);

create table public.catalog_library_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  version integer not null check (version > 0),
  status text not null default 'DRAFT' check (status in ('DRAFT','IN_REVIEW','APPROVED','PUBLISHED','RETIRED','ARCHIVED')),
  name_fr text not null check (length(btrim(name_fr)) between 2 and 200),
  name_ar text not null check (length(btrim(name_ar)) between 2 and 200),
  description_fr text not null check (length(btrim(description_fr)) between 3 and 2000),
  description_ar text not null check (length(btrim(description_ar)) between 3 and 2000),
  icon_key text not null check (icon_key ~ '^[a-z][a-z0-9_-]{1,79}$'),
  sort_order integer not null check (sort_order > 0),
  change_reason text not null check (length(btrim(change_reason)) between 3 and 500),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  sensitive boolean not null default false,
  translation_review_status text not null default 'PENDING' check(translation_review_status in ('PENDING','APPROVED','REJECTED')),
  translation_reviewer_user_id uuid references auth.users(id), translation_reviewed_at timestamptz,
  translation_review_proof_hash text check(translation_review_proof_hash is null or translation_review_proof_hash ~ '^[0-9a-f]{64}$'), translation_review_version integer not null default 0 check(translation_review_version>=0),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  published_at timestamptz,
  retired_at timestamptz,
  row_version integer not null default 1 check (row_version > 0),
  unique(library_id,version), unique(library_id,id),
  check ((status='PUBLISHED')=(published_at is not null and retired_at is null)),
  check ((status='RETIRED')=(retired_at is not null)),
  check ((translation_review_status='APPROVED')=(translation_reviewer_user_id is not null and translation_reviewed_at is not null and translation_review_proof_hash is not null and translation_review_version>0))
);
alter table public.catalog_libraries
  add constraint catalog_libraries_draft_fk foreign key(id,current_draft_version_id) references public.catalog_library_versions(library_id,id) on delete restrict,
  add constraint catalog_libraries_published_fk foreign key(id,current_published_version_id) references public.catalog_library_versions(library_id,id) on delete restrict;

create table public.catalog_categories (
  id uuid primary key default extensions.gen_random_uuid(), library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  code text not null, slug text not null, status text not null default 'DRAFT' check(status in ('DRAFT','IN_REVIEW','APPROVED','PUBLISHED','RETIRED','ARCHIVED')),
  current_draft_version_id uuid, current_published_version_id uuid, created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(), archived_at timestamptz, row_version integer not null default 1 check(row_version>0),
  unique(library_id,code), unique(library_id,slug), unique(library_id,id), check(code ~ '^[A-Z][A-Z0-9_-]{1,79}$'), check(slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);
create table public.catalog_category_versions (
  id uuid primary key default extensions.gen_random_uuid(), category_id uuid not null references public.catalog_categories(id) on delete restrict,
  library_id uuid not null, version integer not null check(version>0), status text not null default 'DRAFT' check(status in ('DRAFT','IN_REVIEW','APPROVED','PUBLISHED','RETIRED','ARCHIVED')),
  name_fr text not null check(length(btrim(name_fr)) between 2 and 200), name_ar text not null check(length(btrim(name_ar)) between 2 and 200),
  description_fr text not null check(length(btrim(description_fr)) between 3 and 2000), description_ar text not null check(length(btrim(description_ar)) between 3 and 2000),
  icon_key text, sort_order integer not null check(sort_order>0), visibility_rules jsonb not null default '{}'::jsonb check(jsonb_typeof(visibility_rules)='object'),
  change_reason text not null check(length(btrim(change_reason)) between 3 and 500), content_hash text not null check(content_hash ~ '^[0-9a-f]{64}$'), sensitive boolean not null default false,
  translation_review_status text not null default 'PENDING' check(translation_review_status in ('PENDING','APPROVED','REJECTED')),
  translation_reviewer_user_id uuid references auth.users(id), translation_reviewed_at timestamptz,
  translation_review_proof_hash text check(translation_review_proof_hash is null or translation_review_proof_hash ~ '^[0-9a-f]{64}$'), translation_review_version integer not null default 0 check(translation_review_version>=0),
  created_by uuid not null references auth.users(id), created_at timestamptz not null default clock_timestamp(), published_at timestamptz, retired_at timestamptz,
  row_version integer not null default 1 check(row_version>0), unique(category_id,version), unique(category_id,id),
  foreign key(category_id,library_id) references public.catalog_categories(id,library_id) on delete restrict,
  check ((status='PUBLISHED')=(published_at is not null and retired_at is null)), check ((status='RETIRED')=(retired_at is not null)),
  check ((translation_review_status='APPROVED')=(translation_reviewer_user_id is not null and translation_reviewed_at is not null and translation_review_proof_hash is not null and translation_review_version>0))
);
alter table public.catalog_categories
 add constraint catalog_categories_draft_fk foreign key(id,current_draft_version_id) references public.catalog_category_versions(category_id,id) on delete restrict,
 add constraint catalog_categories_published_fk foreign key(id,current_published_version_id) references public.catalog_category_versions(category_id,id) on delete restrict;

create table public.catalog_subcategories (
  id uuid primary key default extensions.gen_random_uuid(), library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  category_id uuid not null, code text not null, slug text not null, status text not null default 'DRAFT' check(status in ('DRAFT','IN_REVIEW','APPROVED','PUBLISHED','RETIRED','ARCHIVED')),
  current_draft_version_id uuid, current_published_version_id uuid, created_by uuid not null references auth.users(id), created_at timestamptz not null default clock_timestamp(),
  archived_at timestamptz, row_version integer not null default 1 check(row_version>0), unique(library_id,code), unique(library_id,slug), unique(library_id,id),
  foreign key(category_id,library_id) references public.catalog_categories(id,library_id) on delete restrict,
  check(code ~ '^[A-Z][A-Z0-9_-]{1,79}$'), check(slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);
create table public.catalog_subcategory_versions (
  id uuid primary key default extensions.gen_random_uuid(), subcategory_id uuid not null references public.catalog_subcategories(id) on delete restrict,
  library_id uuid not null, version integer not null check(version>0), status text not null default 'DRAFT' check(status in ('DRAFT','IN_REVIEW','APPROVED','PUBLISHED','RETIRED','ARCHIVED')),
  name_fr text not null check(length(btrim(name_fr)) between 2 and 200), name_ar text not null check(length(btrim(name_ar)) between 2 and 200),
  description_fr text not null check(length(btrim(description_fr)) between 3 and 2000), description_ar text not null check(length(btrim(description_ar)) between 3 and 2000),
  icon_key text, sort_order integer not null check(sort_order>0), visibility_rules jsonb not null default '{}'::jsonb check(jsonb_typeof(visibility_rules)='object'),
  change_reason text not null check(length(btrim(change_reason)) between 3 and 500), content_hash text not null check(content_hash ~ '^[0-9a-f]{64}$'), sensitive boolean not null default false,
  translation_review_status text not null default 'PENDING' check(translation_review_status in ('PENDING','APPROVED','REJECTED')),
  translation_reviewer_user_id uuid references auth.users(id), translation_reviewed_at timestamptz,
  translation_review_proof_hash text check(translation_review_proof_hash is null or translation_review_proof_hash ~ '^[0-9a-f]{64}$'), translation_review_version integer not null default 0 check(translation_review_version>=0),
  created_by uuid not null references auth.users(id), created_at timestamptz not null default clock_timestamp(), published_at timestamptz, retired_at timestamptz,
  row_version integer not null default 1 check(row_version>0), unique(subcategory_id,version), unique(subcategory_id,id),
  foreign key(subcategory_id,library_id) references public.catalog_subcategories(id,library_id) on delete restrict,
  check ((status='PUBLISHED')=(published_at is not null and retired_at is null)), check ((status='RETIRED')=(retired_at is not null)),
  check ((translation_review_status='APPROVED')=(translation_reviewer_user_id is not null and translation_reviewed_at is not null and translation_review_proof_hash is not null and translation_review_version>0))
);
alter table public.catalog_subcategories
 add constraint catalog_subcategories_draft_fk foreign key(id,current_draft_version_id) references public.catalog_subcategory_versions(subcategory_id,id) on delete restrict,
 add constraint catalog_subcategories_published_fk foreign key(id,current_published_version_id) references public.catalog_subcategory_versions(subcategory_id,id) on delete restrict;

create table public.catalog_services (
  id uuid primary key default extensions.gen_random_uuid(), library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  primary_subcategory_id uuid not null, code text not null unique, slug text not null, status text not null default 'DRAFT' check(status in ('DRAFT','IN_REVIEW','APPROVED','PUBLISHED','RETIRED','ARCHIVED')),
  current_draft_version_id uuid, current_published_version_id uuid, created_by uuid not null references auth.users(id), created_at timestamptz not null default clock_timestamp(),
  archived_at timestamptz, row_version integer not null default 1 check(row_version>0), unique(library_id,slug), unique(library_id,id),
  foreign key(primary_subcategory_id,library_id) references public.catalog_subcategories(id,library_id) on delete restrict,
  check(code ~ '^[A-Z][A-Z0-9_-]{1,79}$'), check(slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);
create table public.catalog_service_versions (
  id uuid primary key default extensions.gen_random_uuid(), service_id uuid not null references public.catalog_services(id) on delete restrict, library_id uuid not null,
  version integer not null check(version>0), status text not null default 'DRAFT' check(status in ('DRAFT','IN_REVIEW','APPROVED','PUBLISHED','RETIRED','ARCHIVED')),
  name_fr text not null check(length(btrim(name_fr)) between 2 and 240), name_ar text not null check(length(btrim(name_ar)) between 2 and 240),
  short_description_fr text not null check(length(btrim(short_description_fr)) between 3 and 1000), short_description_ar text not null check(length(btrim(short_description_ar)) between 3 and 1000),
  long_description_fr text not null check(length(btrim(long_description_fr)) between 3 and 8000), long_description_ar text not null check(length(btrim(long_description_ar)) between 3 and 8000),
  service_type text not null check(service_type ~ '^[A-Z][A-Z0-9_]{1,79}$'), unit_label_fr text not null, unit_label_ar text not null,
  credit_eligible boolean not null default false, volume_eligible boolean not null default false, recurring_eligible boolean not null default false,
  trial_eligible boolean not null default false, rfq_required boolean not null default true, fixed_fulfillment_allowed boolean not null default false,
  base_currency char(3) not null default 'MAD' check(base_currency ~ '^[A-Z]{3}$'), sort_order integer not null check(sort_order>0),
  fulfillment_config jsonb not null default '{}'::jsonb check(jsonb_typeof(fulfillment_config)='object'), visibility_rules jsonb not null default '{}'::jsonb check(jsonb_typeof(visibility_rules)='object'),
  change_reason text not null check(length(btrim(change_reason)) between 3 and 500), content_hash text not null check(content_hash ~ '^[0-9a-f]{64}$'), sensitive boolean not null default false,
  translation_review_status text not null default 'PENDING' check(translation_review_status in ('PENDING','APPROVED','REJECTED')),
  translation_reviewer_user_id uuid references auth.users(id), translation_reviewed_at timestamptz,
  translation_review_proof_hash text check(translation_review_proof_hash is null or translation_review_proof_hash ~ '^[0-9a-f]{64}$'), translation_review_version integer not null default 0 check(translation_review_version>=0),
  created_by uuid not null references auth.users(id), created_at timestamptz not null default clock_timestamp(), published_at timestamptz, retired_at timestamptz,
  row_version integer not null default 1 check(row_version>0), unique(service_id,version), unique(service_id,id),
  foreign key(service_id,library_id) references public.catalog_services(id,library_id) on delete restrict,
  check ((status='PUBLISHED')=(published_at is not null and retired_at is null)), check ((status='RETIRED')=(retired_at is not null)),
  check ((translation_review_status='APPROVED')=(translation_reviewer_user_id is not null and translation_reviewed_at is not null and translation_review_proof_hash is not null and translation_review_version>0))
);
alter table public.catalog_services
 add constraint catalog_services_draft_fk foreign key(id,current_draft_version_id) references public.catalog_service_versions(service_id,id) on delete restrict,
 add constraint catalog_services_published_fk foreign key(id,current_published_version_id) references public.catalog_service_versions(service_id,id) on delete restrict;

create table public.catalog_service_subcategory_links (
  id uuid primary key default extensions.gen_random_uuid(), service_id uuid not null, subcategory_id uuid not null, library_id uuid not null,
  link_type text not null check(link_type in ('PRIMARY','SECONDARY')), status text not null default 'DRAFT' check(status in ('DRAFT','IN_REVIEW','APPROVED','PUBLISHED','RETIRED','ARCHIVED')),
  current_version_id uuid, created_by uuid not null references auth.users(id), created_at timestamptz not null default clock_timestamp(), row_version integer not null default 1 check(row_version>0), unique(library_id,id),
  foreign key(service_id,library_id) references public.catalog_services(id,library_id) on delete restrict,
  foreign key(subcategory_id,library_id) references public.catalog_subcategories(id,library_id) on delete restrict,
  unique(service_id,subcategory_id)
);
create unique index catalog_one_primary_link_uidx on public.catalog_service_subcategory_links(service_id) where link_type='PRIMARY' and status not in ('RETIRED','ARCHIVED');
create table public.catalog_service_subcategory_link_versions (
  id uuid primary key default extensions.gen_random_uuid(), link_id uuid not null,
  library_id uuid not null references public.catalog_libraries(id) on delete restrict, version integer not null check(version>0),
  status text not null default 'DRAFT' check(status in ('DRAFT','IN_REVIEW','APPROVED','PUBLISHED','RETIRED','ARCHIVED')),
  change_reason text not null check(length(btrim(change_reason)) between 3 and 500), content_hash text not null check(content_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id), created_at timestamptz not null default clock_timestamp(), published_at timestamptz, retired_at timestamptz,
  row_version integer not null default 1 check(row_version>0), unique(link_id,version), unique(link_id,id),
  foreign key(link_id,library_id) references public.catalog_service_subcategory_links(id,library_id) on delete restrict,
  check ((status='PUBLISHED')=(published_at is not null and retired_at is null)), check ((status='RETIRED')=(retired_at is not null))
);
alter table public.catalog_service_subcategory_links add constraint catalog_links_current_fk foreign key(id,current_version_id) references public.catalog_service_subcategory_link_versions(link_id,id) on delete restrict;

create table public.catalog_releases (
  id uuid primary key default extensions.gen_random_uuid(), library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  release_key text not null unique check(release_key ~ '^[A-Z][A-Z0-9_.-]{2,119}$'), status text not null default 'DRAFT' check(status in ('DRAFT','IN_REVIEW','APPROVED','SCHEDULED','PUBLISHING','PUBLISHED','FAILED','DEAD_LETTER','CANCELLED','RETIRED','ARCHIVED')),
  source_bundle_hash text not null check(source_bundle_hash ~ '^[0-9a-f]{64}$'), snapshot_hash text,
  based_on_release_id uuid references public.catalog_releases(id) on delete restrict, rollback_target_release_id uuid references public.catalog_releases(id) on delete restrict, requires_central_approval boolean not null default false,
  created_by uuid not null references auth.users(id), approved_by uuid references auth.users(id), published_by uuid references auth.users(id),
  audience jsonb not null default '{"kind":"PUBLIC"}'::jsonb check(jsonb_typeof(audience)='object' and audience ? 'kind'),
  effective_from timestamptz not null default clock_timestamp(), effective_until timestamptz,
  lease_token uuid, last_lease_token uuid, lease_worker_id uuid, leased_until timestamptz, next_attempt_at timestamptz, terminal_at timestamptz, publish_attempts integer not null default 0 check(publish_attempts>=0), last_error_code text,
  created_at timestamptz not null default clock_timestamp(), approved_at timestamptz, published_at timestamptz, retired_at timestamptz,
  row_version integer not null default 1 check(row_version>0), unique(library_id,id),
  check(snapshot_hash is null or snapshot_hash ~ '^[0-9a-f]{64}$'), check((approved_by is null)=(approved_at is null)),
  check(effective_until is null or effective_until>effective_from), check((lease_token is null)=(leased_until is null)),
  check((status='PUBLISHED')=(published_at is not null and retired_at is null)), check((status='RETIRED')=(retired_at is not null))
);
alter table public.catalog_libraries add constraint catalog_libraries_release_fk foreign key(id,current_release_id) references public.catalog_releases(library_id,id) on delete restrict;
create table public.catalog_release_items (
  release_id uuid not null references public.catalog_releases(id) on delete restrict, library_id uuid not null,
  object_type text not null check(object_type in ('LIBRARY','CATEGORY','SUBCATEGORY','SERVICE','SERVICE_SUBCATEGORY_LINK')),
  object_id uuid not null, version_id uuid not null, content_hash text not null check(content_hash ~ '^[0-9a-f]{64}$'), sort_order integer not null check(sort_order>0),
  primary key(release_id,object_type,object_id), unique(release_id,sort_order), foreign key(release_id,library_id) references public.catalog_releases(id,library_id) on delete restrict
);

create table public.catalog_change_requests (
  id uuid primary key default extensions.gen_random_uuid(), library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  target_type text not null check(target_type in ('LIBRARY','CATEGORY','SUBCATEGORY','SERVICE','SERVICE_SUBCATEGORY_LINK','RELEASE')),
  target_id uuid not null, target_version_id uuid not null, status text not null default 'IN_REVIEW' check(status in ('IN_REVIEW','APPROVED','REJECTED','ARCHIVED')),
  sensitive boolean not null, requested_by uuid not null references auth.users(id), requested_at timestamptz not null default clock_timestamp(),
  reviewed_by uuid references auth.users(id), reviewed_at timestamptz, review_comment text, row_version integer not null default 1 check(row_version>0),
  check((status in ('APPROVED','REJECTED'))=(reviewed_by is not null and reviewed_at is not null)),
  check(reviewed_by is null or reviewed_by<>requested_by)
);
create table public.catalog_approvals (
  id uuid primary key default extensions.gen_random_uuid(), change_request_id uuid not null references public.catalog_change_requests(id) on delete restrict,
  library_id uuid not null references public.catalog_libraries(id) on delete restrict, decision text not null check(decision in ('APPROVED','REJECTED')),
  before_hash text, after_hash text not null check(after_hash ~ '^[0-9a-f]{64}$'), comment text not null check(length(btrim(comment)) between 3 and 1000),
  decided_by uuid not null references auth.users(id), decided_at timestamptz not null default clock_timestamp(), correlation_id uuid not null,
  unique(change_request_id)
);

create table public.catalog_import_batches (
  id uuid primary key default extensions.gen_random_uuid(), library_id uuid references public.catalog_libraries(id) on delete restrict,
  status text not null default 'RECEIVED' check(status in ('RECEIVED','VALIDATING','INVALID','READY','IMPORTING','IMPORTED','FAILED')),
  baseline_key text not null check(length(btrim(baseline_key)) between 3 and 120), bundle_hash text not null check(bundle_hash ~ '^[0-9a-f]{64}$'),
  manifest jsonb not null check(jsonb_typeof(manifest)='object'), source_kind text not null check(source_kind in ('GOLD_MASTER_BASELINE','FRANCHISE_IMPORT','CENTRAL_IMPORT')),
  is_demo boolean not null default false, created_by uuid not null references auth.users(id), created_at timestamptz not null default clock_timestamp(),
  validated_at timestamptz, imported_at timestamptz, row_version integer not null default 1 check(row_version>0), unique(baseline_key,bundle_hash)
);
create table public.catalog_import_rows (
  id bigint generated always as identity primary key, batch_id uuid not null references public.catalog_import_batches(id) on delete restrict,
  source_file text not null check(length(source_file) between 3 and 240), line_number integer not null check(line_number>0),
  entity_type text not null check(entity_type in ('LIBRARY','CATEGORY','SUBCATEGORY','SERVICE','SERVICE_SUBCATEGORY_LINK')),
  business_key text not null check(length(business_key) between 2 and 160), payload jsonb not null check(jsonb_typeof(payload)='object'),
  row_hash text not null check(row_hash ~ '^[0-9a-f]{64}$'), validation_status text not null default 'PENDING' check(validation_status in ('PENDING','VALID','INVALID','IMPORTED')),
  unique(batch_id,source_file,line_number), unique(batch_id,entity_type,business_key)
);
create table public.catalog_import_errors (
  id bigint generated always as identity primary key, batch_id uuid not null references public.catalog_import_batches(id) on delete restrict,
  import_row_id bigint references public.catalog_import_rows(id) on delete restrict, error_code text not null check(error_code ~ '^[A-Z][A-Z0-9_]{2,79}$'),
  field_name text, public_message text not null check(length(btrim(public_message)) between 3 and 500), created_at timestamptz not null default clock_timestamp()
);
create table public.catalog_command_keys (
  actor_user_id uuid not null references auth.users(id) on delete restrict, operation_scope text not null check(operation_scope ~ '^catalog\.[a-z0-9_.-]{2,90}$'),
  key text not null check(length(key) between 8 and 200), request_hash text not null check(request_hash ~ '^[0-9a-f]{64}$'),
  response_body jsonb, created_at timestamptz not null default clock_timestamp(), completed_at timestamptz, primary key(actor_user_id,operation_scope,key),
  check((response_body is null)=(completed_at is null))
);

create table public.catalog_publish_retry_policies (
  version integer primary key check(version>0), status text not null check(status in ('ACTIVE','RETIRED')),
  max_attempts integer not null check(max_attempts between 1 and 20), base_backoff_seconds integer not null check(base_backoff_seconds between 1 and 3600),
  max_backoff_seconds integer not null check(max_backoff_seconds between base_backoff_seconds and 86400), created_at timestamptz not null default clock_timestamp()
);
create unique index catalog_publish_retry_policy_active_uidx on public.catalog_publish_retry_policies(status) where status='ACTIVE';
insert into public.catalog_publish_retry_policies(version,status,max_attempts,base_backoff_seconds,max_backoff_seconds) values(1,'ACTIVE',3,1,60);

create table public.catalog_permission_policies (
  role_code text not null references public.role_definitions(code), permission_code text not null,
  policy_version integer not null check(policy_version>0), active boolean not null default true,
  valid_from timestamptz not null default '-infinity', valid_until timestamptz,
  row_version integer not null default 1 check(row_version>0),
  primary key(role_code,permission_code,policy_version),
  check(permission_code in ('CATALOG_VIEW_DRAFT','CATALOG_EDIT','CATALOG_SUBMIT','CATALOG_PUBLISH','CATALOG_APPROVE','CATALOG_ROLLBACK','CATALOG_IMPORT')),
  check(valid_until is null or valid_until>valid_from)
);
create unique index catalog_permission_policy_active_uidx on public.catalog_permission_policies(role_code,permission_code) where active;
create table public.catalog_library_mandates (
  id uuid primary key default extensions.gen_random_uuid(), library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  status text not null check(status in ('ACTIVE','SUSPENDED','REVOKED','EXPIRED')),
  valid_from timestamptz not null, valid_until timestamptz, policy_version integer not null check(policy_version>0),
  created_by uuid not null references auth.users(id), created_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check(row_version>0),
  check(valid_until is null or valid_until>valid_from), unique(library_id,organization_id,id)
);
create unique index catalog_library_active_mandate_uidx on public.catalog_library_mandates(library_id,organization_id) where status='ACTIVE';
create table private.catalog_acl_write_capabilities (
  backend_pid integer not null, transaction_id bigint not null, primary key(backend_pid,transaction_id)
);
revoke all on table private.catalog_acl_write_capabilities from public,anon,authenticated,service_role;

insert into public.catalog_permission_policies(role_code,permission_code,policy_version) values
('SUPER_ADMIN','CATALOG_VIEW_DRAFT',1),('SUPER_ADMIN','CATALOG_EDIT',1),('SUPER_ADMIN','CATALOG_SUBMIT',1),('SUPER_ADMIN','CATALOG_PUBLISH',1),('SUPER_ADMIN','CATALOG_APPROVE',1),('SUPER_ADMIN','CATALOG_ROLLBACK',1),('SUPER_ADMIN','CATALOG_IMPORT',1),
('MATRICIA_ADMIN','CATALOG_VIEW_DRAFT',1),('MATRICIA_ADMIN','CATALOG_EDIT',1),('MATRICIA_ADMIN','CATALOG_SUBMIT',1),('MATRICIA_ADMIN','CATALOG_PUBLISH',1),('MATRICIA_ADMIN','CATALOG_APPROVE',1),('MATRICIA_ADMIN','CATALOG_ROLLBACK',1),('MATRICIA_ADMIN','CATALOG_IMPORT',1),
('FRANCHISE_OWNER','CATALOG_VIEW_DRAFT',1),('FRANCHISE_OWNER','CATALOG_EDIT',1),('FRANCHISE_OWNER','CATALOG_SUBMIT',1),('FRANCHISE_OWNER','CATALOG_PUBLISH',1),('FRANCHISE_OWNER','CATALOG_IMPORT',1),
('FRANCHISE_MANAGER','CATALOG_VIEW_DRAFT',1),('FRANCHISE_MANAGER','CATALOG_EDIT',1),('FRANCHISE_MANAGER','CATALOG_SUBMIT',1),('FRANCHISE_MANAGER','CATALOG_PUBLISH',1),('FRANCHISE_MANAGER','CATALOG_IMPORT',1);

create or replace function private.has_library_permission(p_library_id uuid,p_permission_code text,p_actor_id uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=pg_catalog,private as $$
 select exists(
  select 1 from public.platform_user_roles r join public.catalog_permission_policies p on p.role_code=r.role_code
  where r.user_id=p_actor_id and r.revoked_at is null and p.permission_code=p_permission_code and p.active
    and statement_timestamp()>=p.valid_from and (p.valid_until is null or statement_timestamp()<p.valid_until)
 ) or exists(
  select 1 from public.organization_memberships m
  join public.organizations o on o.id=m.organization_id and o.status='ACTIVE'
  join public.organization_member_roles r on r.membership_id=m.id
  join public.catalog_permission_policies p on p.role_code=r.role_code
  join public.catalog_library_mandates x on x.library_id=p_library_id and x.organization_id=m.organization_id
  where m.user_id=p_actor_id and m.status='ACTIVE' and r.revoked_at is null and r.library_id=p_library_id
    and p.permission_code=p_permission_code and p.policy_version=x.policy_version and p.active and statement_timestamp()>=p.valid_from and (p.valid_until is null or statement_timestamp()<p.valid_until)
    and x.status='ACTIVE' and statement_timestamp()>=x.valid_from and (x.valid_until is null or statement_timestamp()<x.valid_until)
 )
$$;
revoke all on function private.has_library_permission(uuid,text,uuid) from public,anon,authenticated,service_role;
grant execute on function private.has_library_permission(uuid,text,uuid) to authenticated;

create or replace function private.has_catalog_library_scope(p_library_id uuid,p_actor_id uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=pg_catalog,private as $$ select private.has_library_permission(p_library_id,'CATALOG_VIEW_DRAFT',p_actor_id) $$;
revoke all on function private.has_catalog_library_scope(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function private.has_catalog_library_scope(uuid,uuid) to authenticated;

create or replace function private.can_read_catalog_release(p_release_id uuid,p_actor_id uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=pg_catalog as $$
 select exists(select 1 from public.catalog_releases r where r.id=p_release_id and r.status='PUBLISHED'
   and statement_timestamp()>=r.effective_from and (r.effective_until is null or statement_timestamp()<r.effective_until)
   and ((r.audience->>'kind'='PUBLIC') or (r.audience->>'kind'='ORGANIZATIONS' and exists(
     select 1 from public.organization_memberships m join public.organizations o on o.id=m.organization_id and o.status='ACTIVE'
     where m.user_id=p_actor_id and m.status='ACTIVE'
       and coalesce(r.audience->'organization_ids','[]'::jsonb) ? m.organization_id::text
   ))))
$$;
revoke all on function private.can_read_catalog_release(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function private.can_read_catalog_release(uuid,uuid) to authenticated;

create or replace function private.catalog_audiences_overlap(p_left jsonb,p_right jsonb) returns boolean
language sql immutable security definer set search_path=pg_catalog as $$
 select case
  when p_left->>'kind'='PUBLIC' or p_right->>'kind'='PUBLIC' then true
  when p_left->>'kind'='ORGANIZATIONS' and p_right->>'kind'='ORGANIZATIONS' then exists(
   select 1 from jsonb_array_elements_text(coalesce(p_left->'organization_ids','[]'::jsonb)) l(value)
   join jsonb_array_elements_text(coalesce(p_right->'organization_ids','[]'::jsonb)) r(value) using(value)
  ) else false end
$$;
revoke all on function private.catalog_audiences_overlap(jsonb,jsonb) from public,anon,authenticated,service_role;

create or replace function private.canonical_catalog_audience(p_audience jsonb) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $$
declare v_kind text;v_result jsonb;
begin
 if jsonb_typeof(p_audience)<>'object' then raise exception 'INVALID_CATALOG_AUDIENCE' using errcode='22023'; end if;
 v_kind:=p_audience->>'kind';
 if v_kind='PUBLIC' then
  if (select count(*) from jsonb_object_keys(p_audience))<>1 then raise exception 'INVALID_CATALOG_AUDIENCE' using errcode='22023'; end if;
  return '{"kind":"PUBLIC"}'::jsonb;
 end if;
 if v_kind<>'ORGANIZATIONS' or (select count(*) from jsonb_object_keys(p_audience))<>2 or jsonb_typeof(p_audience->'organization_ids')<>'array' or jsonb_array_length(p_audience->'organization_ids')=0
    or exists(select 1 from jsonb_array_elements_text(p_audience->'organization_ids') e(value) where e.value!~'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
  raise exception 'INVALID_CATALOG_AUDIENCE' using errcode='22023';
 end if;
 select jsonb_build_object('kind','ORGANIZATIONS','organization_ids',jsonb_agg(value order by value)) into v_result
 from (select distinct value from jsonb_array_elements_text(p_audience->'organization_ids')) ids;
 if exists(select 1 from jsonb_array_elements_text(v_result->'organization_ids') e(value) left join public.organizations o on o.id=e.value::uuid and o.status='ACTIVE' where o.id is null) then
  raise exception 'INVALID_CATALOG_AUDIENCE_ORGANIZATION' using errcode='22023';
 end if;
 return v_result;
end $$;
revoke all on function private.canonical_catalog_audience(jsonb) from public,anon,authenticated,service_role;
create or replace function private.canonicalize_catalog_release_audience() returns trigger
language plpgsql security definer set search_path=pg_catalog,private as $$
begin new.audience:=private.canonical_catalog_audience(new.audience); return new; end $$;
revoke all on function private.canonicalize_catalog_release_audience() from public,anon,authenticated,service_role;
create trigger catalog_release_audience_canonical before insert or update of audience on public.catalog_releases for each row execute function private.canonicalize_catalog_release_audience();

create or replace function private.prevent_catalog_history_mutation() returns trigger language plpgsql security definer set search_path=pg_catalog as $$
begin
 if tg_op='DELETE' and old.status<>'DRAFT' then raise exception 'IMMUTABLE_CATALOG_HISTORY' using errcode='55000'; end if;
 if tg_op='UPDATE' and to_jsonb(old)->>'translation_review_status'='APPROVED' and
    jsonb_build_array(to_jsonb(new)->'translation_review_status',to_jsonb(new)->'translation_reviewer_user_id',to_jsonb(new)->'translation_reviewed_at',to_jsonb(new)->'translation_review_proof_hash',to_jsonb(new)->'translation_review_version') is distinct from
    jsonb_build_array(to_jsonb(old)->'translation_review_status',to_jsonb(old)->'translation_reviewer_user_id',to_jsonb(old)->'translation_reviewed_at',to_jsonb(old)->'translation_review_proof_hash',to_jsonb(old)->'translation_review_version') then
  raise exception 'IMMUTABLE_TRANSLATION_ATTESTATION' using errcode='55000';
 end if;
 if tg_op='UPDATE' and old.status in ('PUBLISHED','RETIRED','ARCHIVED') then
   if (to_jsonb(new)-array['status','published_at','retired_at','row_version'])<>(to_jsonb(old)-array['status','published_at','retired_at','row_version'])
      or not ((old.status='PUBLISHED' and new.status='RETIRED') or (old.status='RETIRED' and new.status='PUBLISHED') or new.status=old.status) then
     raise exception 'IMMUTABLE_CATALOG_HISTORY' using errcode='55000';
   end if;
 end if;
 return case when tg_op='DELETE' then old else new end;
end $$;
revoke all on function private.prevent_catalog_history_mutation() from public,anon,authenticated,service_role;
create trigger catalog_library_versions_immutable before update or delete on public.catalog_library_versions for each row execute function private.prevent_catalog_history_mutation();
create trigger catalog_category_versions_immutable before update or delete on public.catalog_category_versions for each row execute function private.prevent_catalog_history_mutation();
create trigger catalog_subcategory_versions_immutable before update or delete on public.catalog_subcategory_versions for each row execute function private.prevent_catalog_history_mutation();
create trigger catalog_service_versions_immutable before update or delete on public.catalog_service_versions for each row execute function private.prevent_catalog_history_mutation();
create trigger catalog_link_versions_immutable before update or delete on public.catalog_service_subcategory_link_versions for each row execute function private.prevent_catalog_history_mutation();
create or replace function private.prevent_release_item_mutation() returns trigger language plpgsql security definer set search_path=pg_catalog as $$
declare v_release_id uuid;
begin
 v_release_id:=case when tg_op='DELETE' then old.release_id else new.release_id end;
 if exists(select 1 from public.catalog_releases r where r.id=v_release_id and r.status<>'DRAFT') then
  raise exception 'IMMUTABLE_CATALOG_RELEASE' using errcode='55000';
 end if; return case when tg_op='DELETE' then old else new end;
end $$;
revoke all on function private.prevent_release_item_mutation() from public,anon,authenticated,service_role;
create trigger catalog_release_items_immutable before update or delete on public.catalog_release_items for each row execute function private.prevent_release_item_mutation();
create or replace function private.prevent_catalog_acl_history_mutation() returns trigger language plpgsql security definer set search_path=pg_catalog as $$
begin
 if not exists(select 1 from private.catalog_acl_write_capabilities where backend_pid=pg_backend_pid() and transaction_id=txid_current()) then
  raise exception 'IMMUTABLE_CATALOG_AUTHORIZATION_HISTORY' using errcode='55000';
 end if;
 return new;
end $$;
revoke all on function private.prevent_catalog_acl_history_mutation() from public,anon,authenticated,service_role;
create trigger catalog_permission_policies_immutable before update or delete on public.catalog_permission_policies for each row execute function private.prevent_catalog_acl_history_mutation();
create trigger catalog_library_mandates_immutable before update or delete on public.catalog_library_mandates for each row execute function private.prevent_catalog_acl_history_mutation();

alter table public.catalog_libraries enable row level security; alter table public.catalog_library_versions enable row level security;
alter table public.catalog_categories enable row level security; alter table public.catalog_category_versions enable row level security;
alter table public.catalog_subcategories enable row level security; alter table public.catalog_subcategory_versions enable row level security;
alter table public.catalog_services enable row level security; alter table public.catalog_service_versions enable row level security;
alter table public.catalog_service_subcategory_links enable row level security; alter table public.catalog_service_subcategory_link_versions enable row level security;
alter table public.catalog_releases enable row level security; alter table public.catalog_release_items enable row level security;
alter table public.catalog_change_requests enable row level security; alter table public.catalog_approvals enable row level security;
alter table public.catalog_import_batches enable row level security; alter table public.catalog_import_rows enable row level security; alter table public.catalog_import_errors enable row level security;
alter table public.catalog_command_keys enable row level security;
alter table public.catalog_permission_policies enable row level security; alter table public.catalog_library_mandates enable row level security;
alter table public.catalog_publish_retry_policies enable row level security;

revoke all on public.catalog_libraries,public.catalog_library_versions,public.catalog_categories,public.catalog_category_versions,
 public.catalog_subcategories,public.catalog_subcategory_versions,public.catalog_services,public.catalog_service_versions,
 public.catalog_service_subcategory_links,public.catalog_service_subcategory_link_versions,public.catalog_releases,public.catalog_release_items,
 public.catalog_change_requests,public.catalog_approvals,public.catalog_import_batches,public.catalog_import_rows,public.catalog_import_errors,public.catalog_command_keys,
 public.catalog_permission_policies,public.catalog_library_mandates,public.catalog_publish_retry_policies
 from public,anon,authenticated,service_role;
grant select on public.catalog_libraries,public.catalog_library_versions,public.catalog_categories,public.catalog_category_versions,
 public.catalog_subcategories,public.catalog_subcategory_versions,public.catalog_services,public.catalog_service_versions,
 public.catalog_service_subcategory_links,public.catalog_service_subcategory_link_versions,public.catalog_releases,public.catalog_release_items,
 public.catalog_change_requests,public.catalog_approvals,public.catalog_import_batches,public.catalog_import_rows,public.catalog_import_errors,
 public.catalog_permission_policies,public.catalog_library_mandates to authenticated;

create policy catalog_libraries_read on public.catalog_libraries for select to authenticated using(private.can_read_catalog_release(current_release_id) or private.has_catalog_library_scope(id));
create policy catalog_library_versions_read on public.catalog_library_versions for select to authenticated using(exists(select 1 from public.catalog_release_items i where i.library_id=catalog_library_versions.library_id and i.version_id=catalog_library_versions.id and private.can_read_catalog_release(i.release_id)) or private.has_catalog_library_scope(library_id));
create policy catalog_categories_read on public.catalog_categories for select to authenticated using(exists(select 1 from public.catalog_release_items i where i.library_id=catalog_categories.library_id and i.object_type='CATEGORY' and i.object_id=catalog_categories.id and private.can_read_catalog_release(i.release_id)) or private.has_catalog_library_scope(library_id));
create policy catalog_category_versions_read on public.catalog_category_versions for select to authenticated using(exists(select 1 from public.catalog_release_items i where i.library_id=catalog_category_versions.library_id and i.version_id=catalog_category_versions.id and private.can_read_catalog_release(i.release_id)) or private.has_catalog_library_scope(library_id));
create policy catalog_subcategories_read on public.catalog_subcategories for select to authenticated using(exists(select 1 from public.catalog_release_items i where i.library_id=catalog_subcategories.library_id and i.object_type='SUBCATEGORY' and i.object_id=catalog_subcategories.id and private.can_read_catalog_release(i.release_id)) or private.has_catalog_library_scope(library_id));
create policy catalog_subcategory_versions_read on public.catalog_subcategory_versions for select to authenticated using(exists(select 1 from public.catalog_release_items i where i.library_id=catalog_subcategory_versions.library_id and i.version_id=catalog_subcategory_versions.id and private.can_read_catalog_release(i.release_id)) or private.has_catalog_library_scope(library_id));
create policy catalog_services_read on public.catalog_services for select to authenticated using(exists(select 1 from public.catalog_release_items i where i.library_id=catalog_services.library_id and i.object_type='SERVICE' and i.object_id=catalog_services.id and private.can_read_catalog_release(i.release_id)) or private.has_catalog_library_scope(library_id));
create policy catalog_service_versions_read on public.catalog_service_versions for select to authenticated using(exists(select 1 from public.catalog_release_items i where i.library_id=catalog_service_versions.library_id and i.version_id=catalog_service_versions.id and private.can_read_catalog_release(i.release_id)) or private.has_catalog_library_scope(library_id));
create policy catalog_links_read on public.catalog_service_subcategory_links for select to authenticated using(exists(select 1 from public.catalog_release_items i where i.library_id=catalog_service_subcategory_links.library_id and i.object_type='SERVICE_SUBCATEGORY_LINK' and i.object_id=catalog_service_subcategory_links.id and private.can_read_catalog_release(i.release_id)) or private.has_catalog_library_scope(library_id));
create policy catalog_link_versions_read on public.catalog_service_subcategory_link_versions for select to authenticated using(exists(select 1 from public.catalog_release_items i where i.library_id=catalog_service_subcategory_link_versions.library_id and i.version_id=catalog_service_subcategory_link_versions.id and private.can_read_catalog_release(i.release_id)) or private.has_catalog_library_scope(library_id));
create policy catalog_releases_read on public.catalog_releases for select to authenticated using(private.can_read_catalog_release(id) or private.has_catalog_library_scope(library_id));
create policy catalog_release_items_read on public.catalog_release_items for select to authenticated using(private.can_read_catalog_release(release_id) or private.has_catalog_library_scope(library_id));
create policy catalog_changes_read on public.catalog_change_requests for select to authenticated using(private.has_catalog_library_scope(library_id));
create policy catalog_approvals_read on public.catalog_approvals for select to authenticated using(private.has_catalog_library_scope(library_id));
create policy catalog_import_batches_read on public.catalog_import_batches for select to authenticated using(library_id is not null and private.has_library_permission(library_id,'CATALOG_IMPORT'));
create policy catalog_import_rows_read on public.catalog_import_rows for select to authenticated using(exists(select 1 from public.catalog_import_batches b where b.id=batch_id and b.library_id is not null and private.has_library_permission(b.library_id,'CATALOG_IMPORT')));
create policy catalog_import_errors_read on public.catalog_import_errors for select to authenticated using(exists(select 1 from public.catalog_import_batches b where b.id=batch_id and b.library_id is not null and private.has_library_permission(b.library_id,'CATALOG_IMPORT')));
create policy catalog_permission_policies_read on public.catalog_permission_policies for select to authenticated using(active and statement_timestamp()>=valid_from and (valid_until is null or statement_timestamp()<valid_until));
create policy catalog_library_mandates_read on public.catalog_library_mandates for select to authenticated using(private.has_library_permission(library_id,'CATALOG_VIEW_DRAFT'));

create index catalog_libraries_status_idx on public.catalog_libraries(status,code); create index catalog_categories_library_idx on public.catalog_categories(library_id,status,code);
create index catalog_subcategories_category_idx on public.catalog_subcategories(library_id,category_id,status,code); create index catalog_services_library_idx on public.catalog_services(library_id,status,code);
create index catalog_library_versions_current_idx on public.catalog_library_versions(library_id,status,version desc); create index catalog_category_versions_current_idx on public.catalog_category_versions(library_id,category_id,status,version desc);
create index catalog_subcategory_versions_current_idx on public.catalog_subcategory_versions(library_id,subcategory_id,status,version desc); create index catalog_service_versions_current_idx on public.catalog_service_versions(library_id,service_id,status,version desc);
create index catalog_releases_library_idx on public.catalog_releases(library_id,status,published_at desc); create index catalog_import_rows_batch_idx on public.catalog_import_rows(batch_id,validation_status,id);
create index catalog_releases_schedule_idx on public.catalog_releases(status,effective_from,leased_until) where status in ('SCHEDULED','PUBLISHING','FAILED');
create index catalog_import_errors_batch_idx on public.catalog_import_errors(batch_id,id); create index catalog_changes_review_idx on public.catalog_change_requests(status,sensitive,requested_at);

create or replace function private.validate_catalog_release_tree(p_release_id uuid) returns void
language plpgsql security definer set search_path=pg_catalog as $$
declare v_library_id uuid;
begin
 select library_id into v_library_id from public.catalog_releases where id=p_release_id;
 if v_library_id is null then raise exception 'CATALOG_RELEASE_NOT_FOUND' using errcode='P0002'; end if;
 if (select count(*) from public.catalog_release_items where release_id=p_release_id and object_type='LIBRARY')<>1
  or not exists(select 1 from public.catalog_release_items where release_id=p_release_id and object_type='CATEGORY')
  or not exists(select 1 from public.catalog_release_items where release_id=p_release_id and object_type='SUBCATEGORY')
  or not exists(select 1 from public.catalog_release_items where release_id=p_release_id and object_type='SERVICE')
  or not exists(select 1 from public.catalog_release_items where release_id=p_release_id and object_type='SERVICE_SUBCATEGORY_LINK') then
  raise exception 'INCOMPLETE_CATALOG_RELEASE' using errcode='23514';
 end if;
 if (select count(*) from public.catalog_release_items where release_id=p_release_id and object_type='CATEGORY') <>
      (select count(*) from public.catalog_categories c where c.library_id=v_library_id and c.status<>'ARCHIVED' and exists(select 1 from public.catalog_category_versions v where v.category_id=c.id and v.status in ('APPROVED','PUBLISHED')))
  or (select count(*) from public.catalog_release_items where release_id=p_release_id and object_type='SUBCATEGORY') <>
      (select count(*) from public.catalog_subcategories s where s.library_id=v_library_id and s.status<>'ARCHIVED' and exists(select 1 from public.catalog_subcategory_versions v where v.subcategory_id=s.id and v.status in ('APPROVED','PUBLISHED')))
  or (select count(*) from public.catalog_release_items where release_id=p_release_id and object_type='SERVICE') <>
      (select count(*) from public.catalog_services s where s.library_id=v_library_id and s.status<>'ARCHIVED' and exists(select 1 from public.catalog_service_versions v where v.service_id=s.id and v.status in ('APPROVED','PUBLISHED')))
  or (select count(*) from public.catalog_release_items where release_id=p_release_id and object_type='SERVICE_SUBCATEGORY_LINK') <>
      (select count(*) from public.catalog_service_subcategory_links l where l.library_id=v_library_id and l.status<>'ARCHIVED' and exists(select 1 from public.catalog_service_subcategory_link_versions v where v.link_id=l.id and v.status in ('APPROVED','PUBLISHED'))) then
  raise exception 'INCOMPLETE_CATALOG_RELEASE' using errcode='23514';
 end if;
 if exists(
  select 1 from public.catalog_release_items i
  where i.release_id=p_release_id and (
   (i.object_type='CATEGORY' and not exists(select 1 from public.catalog_categories c where c.id=i.object_id and c.library_id=v_library_id)) or
   (i.object_type='SUBCATEGORY' and not exists(select 1 from public.catalog_subcategories s join public.catalog_release_items c on c.release_id=p_release_id and c.object_type='CATEGORY' and c.object_id=s.category_id where s.id=i.object_id and s.library_id=v_library_id)) or
   (i.object_type='SERVICE' and not exists(select 1 from public.catalog_services s join public.catalog_release_items sc on sc.release_id=p_release_id and sc.object_type='SUBCATEGORY' and sc.object_id=s.primary_subcategory_id where s.id=i.object_id and s.library_id=v_library_id)) or
   (i.object_type='SERVICE_SUBCATEGORY_LINK' and not exists(select 1 from public.catalog_service_subcategory_links l join public.catalog_release_items s on s.release_id=p_release_id and s.object_type='SERVICE' and s.object_id=l.service_id join public.catalog_release_items sc on sc.release_id=p_release_id and sc.object_type='SUBCATEGORY' and sc.object_id=l.subcategory_id where l.id=i.object_id and l.library_id=v_library_id))
  )
 ) then raise exception 'INVALID_CATALOG_RELEASE_TREE' using errcode='23514'; end if;
 if exists(
  select 1 from public.catalog_release_items s where s.release_id=p_release_id and s.object_type='SERVICE'
  and (select count(*) from public.catalog_release_items i join public.catalog_service_subcategory_links l on l.id=i.object_id
       where i.release_id=p_release_id and i.object_type='SERVICE_SUBCATEGORY_LINK' and l.service_id=s.object_id and l.link_type='PRIMARY'
         and l.subcategory_id=(select primary_subcategory_id from public.catalog_services where id=s.object_id))<>1
 ) then raise exception 'PRIMARY_CATALOG_LINK_REQUIRED' using errcode='23514'; end if;
 if exists(select 1 from public.catalog_release_items i where i.release_id=p_release_id and (
   (i.object_type='LIBRARY' and exists(select 1 from public.catalog_library_versions v where v.id=i.version_id and v.translation_review_status<>'APPROVED')) or
   (i.object_type='CATEGORY' and exists(select 1 from public.catalog_category_versions v where v.id=i.version_id and v.translation_review_status<>'APPROVED')) or
   (i.object_type='SUBCATEGORY' and exists(select 1 from public.catalog_subcategory_versions v where v.id=i.version_id and v.translation_review_status<>'APPROVED')) or
   (i.object_type='SERVICE' and exists(select 1 from public.catalog_service_versions v where v.id=i.version_id and v.translation_review_status<>'APPROVED'))
 )) then raise exception 'CATALOG_AR_REVIEW_REQUIRED' using errcode='23514'; end if;
end $$;
revoke all on function private.validate_catalog_release_tree(uuid) from public,anon,authenticated,service_role;

create or replace function private.activate_catalog_release_items(p_release_id uuid) returns void
language plpgsql security definer set search_path=pg_catalog as $$
declare v_item public.catalog_release_items%rowtype;
begin
 for v_item in select * from public.catalog_release_items where release_id=p_release_id order by sort_order,object_type,object_id loop
  if v_item.object_type='LIBRARY' then
   update public.catalog_library_versions set status='RETIRED',retired_at=clock_timestamp(),row_version=row_version+1 where library_id=v_item.object_id and status='PUBLISHED' and id<>v_item.version_id;
   update public.catalog_library_versions set status='PUBLISHED',published_at=coalesce(published_at,clock_timestamp()),retired_at=null,row_version=row_version+1 where id=v_item.version_id;
   update public.catalog_libraries set status='PUBLISHED',current_published_version_id=v_item.version_id,row_version=row_version+1,updated_at=clock_timestamp() where id=v_item.object_id;
  elsif v_item.object_type='CATEGORY' then
   update public.catalog_category_versions set status='RETIRED',retired_at=clock_timestamp(),row_version=row_version+1 where category_id=v_item.object_id and status='PUBLISHED' and id<>v_item.version_id;
   update public.catalog_category_versions set status='PUBLISHED',published_at=coalesce(published_at,clock_timestamp()),retired_at=null,row_version=row_version+1 where id=v_item.version_id;
   update public.catalog_categories set status='PUBLISHED',current_published_version_id=v_item.version_id,row_version=row_version+1 where id=v_item.object_id;
  elsif v_item.object_type='SUBCATEGORY' then
   update public.catalog_subcategory_versions set status='RETIRED',retired_at=clock_timestamp(),row_version=row_version+1 where subcategory_id=v_item.object_id and status='PUBLISHED' and id<>v_item.version_id;
   update public.catalog_subcategory_versions set status='PUBLISHED',published_at=coalesce(published_at,clock_timestamp()),retired_at=null,row_version=row_version+1 where id=v_item.version_id;
   update public.catalog_subcategories set status='PUBLISHED',current_published_version_id=v_item.version_id,row_version=row_version+1 where id=v_item.object_id;
  elsif v_item.object_type='SERVICE' then
   update public.catalog_service_versions set status='RETIRED',retired_at=clock_timestamp(),row_version=row_version+1 where service_id=v_item.object_id and status='PUBLISHED' and id<>v_item.version_id;
   update public.catalog_service_versions set status='PUBLISHED',published_at=coalesce(published_at,clock_timestamp()),retired_at=null,row_version=row_version+1 where id=v_item.version_id;
   update public.catalog_services set status='PUBLISHED',current_published_version_id=v_item.version_id,row_version=row_version+1 where id=v_item.object_id;
  elsif v_item.object_type='SERVICE_SUBCATEGORY_LINK' then
   update public.catalog_service_subcategory_link_versions set status='RETIRED',retired_at=clock_timestamp(),row_version=row_version+1 where link_id=v_item.object_id and status='PUBLISHED' and id<>v_item.version_id;
   update public.catalog_service_subcategory_link_versions set status='PUBLISHED',published_at=coalesce(published_at,clock_timestamp()),retired_at=null,row_version=row_version+1 where id=v_item.version_id;
   update public.catalog_service_subcategory_links set status='PUBLISHED',current_version_id=v_item.version_id,row_version=row_version+1 where id=v_item.object_id;
  else raise exception 'INVALID_CATALOG_OBJECT_TYPE' using errcode='22023'; end if;
 end loop;
end $$;
revoke all on function private.activate_catalog_release_items(uuid) from public,anon,authenticated,service_role;

create function public.create_catalog_release(p_library_id uuid,p_release_key text,p_source_bundle_hash text,p_requires_central_approval boolean,p_expected_library_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_library public.catalog_libraries%rowtype;v_hash text;v_existing public.catalog_command_keys%rowtype;v_id uuid;v_response jsonb;
begin
 if v_actor is null or not private.has_library_permission(p_library_id,'CATALOG_EDIT',v_actor) then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501'; end if;
 if length(coalesce(p_idempotency_key,'')) not between 8 and 200 or coalesce(p_release_key,'')!~'^[A-Z][A-Z0-9_.-]{2,119}$' or coalesce(p_source_bundle_hash,'')!~'^[0-9a-f]{64}$' then raise exception 'INVALID_CATALOG_RELEASE' using errcode='22023'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.release.create.v1','library_id',p_library_id,'release_key',p_release_key,'source_bundle_hash',p_source_bundle_hash,'central',p_requires_central_approval,'expected',p_expected_library_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.release.create' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-library:'||p_library_id::text,0)); select * into v_library from public.catalog_libraries where id=p_library_id for update;
 if not found then raise exception 'CATALOG_LIBRARY_NOT_FOUND' using errcode='P0002'; end if; if v_library.row_version<>p_expected_library_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.release.create.v1','library_id',p_library_id,'release_key',p_release_key,'source_bundle_hash',p_source_bundle_hash,'central',p_requires_central_approval,'expected',p_expected_library_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.release.create' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 insert into public.catalog_command_keys values(v_actor,'catalog.release.create',p_idempotency_key,v_hash,null,clock_timestamp(),null);
 insert into public.catalog_releases(library_id,release_key,source_bundle_hash,based_on_release_id,requires_central_approval,created_by) values(p_library_id,p_release_key,p_source_bundle_hash,v_library.current_release_id,p_requires_central_approval,v_actor) returning id into v_id;
 update public.catalog_libraries set row_version=row_version+1,updated_at=clock_timestamp() where id=p_library_id;
 v_response:=jsonb_build_object('outcome','CATALOG_RELEASE_CREATED','release_id',v_id,'status','DRAFT','library_row_version',p_expected_library_row_version+1);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_library.steward_organization_id,v_actor,'USER','catalog.release.created','catalog_release',v_id::text,p_correlation_id,jsonb_build_object('library_id',p_library_id,'release_key',p_release_key),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values(v_library.steward_organization_id,'catalog_release',v_id::text,'CatalogReleaseCreatedV1',p_correlation_id,jsonb_build_object('release_id',v_id,'library_id',p_library_id));
 update public.catalog_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='catalog.release.create' and key=p_idempotency_key; return v_response;
end $$;

create function public.add_catalog_release_item(p_release_id uuid,p_object_type text,p_object_id uuid,p_version_id uuid,p_content_hash text,p_sort_order integer,p_expected_release_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_release public.catalog_releases%rowtype;v_hash text;v_existing public.catalog_command_keys%rowtype;v_valid boolean:=false;v_response jsonb;
begin
 select * into v_release from public.catalog_releases where id=p_release_id; if not found then raise exception 'CATALOG_RELEASE_NOT_FOUND' using errcode='P0002'; end if;
 if v_actor is null or not private.has_library_permission(v_release.library_id,'CATALOG_EDIT',v_actor) then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501'; end if;
 if p_object_type not in ('LIBRARY','CATEGORY','SUBCATEGORY','SERVICE','SERVICE_SUBCATEGORY_LINK') or p_content_hash!~'^[0-9a-f]{64}$' or p_sort_order<1 then raise exception 'INVALID_CATALOG_RELEASE_ITEM' using errcode='22023'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.release.item.add.v1','release_id',p_release_id,'type',p_object_type,'object_id',p_object_id,'version_id',p_version_id,'hash',p_content_hash,'sort',p_sort_order,'expected',p_expected_release_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.release.item.add' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 if p_object_type='LIBRARY' then select exists(select 1 from public.catalog_library_versions where id=p_version_id and library_id=v_release.library_id and library_id=p_object_id and status='APPROVED' and content_hash=p_content_hash) into v_valid;
 elsif p_object_type='CATEGORY' then select exists(select 1 from public.catalog_category_versions where id=p_version_id and library_id=v_release.library_id and category_id=p_object_id and status='APPROVED' and content_hash=p_content_hash) into v_valid;
 elsif p_object_type='SUBCATEGORY' then select exists(select 1 from public.catalog_subcategory_versions where id=p_version_id and library_id=v_release.library_id and subcategory_id=p_object_id and status='APPROVED' and content_hash=p_content_hash) into v_valid;
 elsif p_object_type='SERVICE' then select exists(select 1 from public.catalog_service_versions where id=p_version_id and library_id=v_release.library_id and service_id=p_object_id and status='APPROVED' and content_hash=p_content_hash) into v_valid;
 elsif p_object_type='SERVICE_SUBCATEGORY_LINK' then select exists(select 1 from public.catalog_service_subcategory_link_versions where id=p_version_id and library_id=v_release.library_id and link_id=p_object_id and status='APPROVED' and content_hash=p_content_hash) into v_valid;
 else raise exception 'INVALID_CATALOG_OBJECT_TYPE' using errcode='22023'; end if;
 if not v_valid or p_content_hash!~'^[0-9a-f]{64}$' or p_sort_order<1 then raise exception 'INVALID_CATALOG_RELEASE_ITEM' using errcode='22023'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.release.item.add.v1','release_id',p_release_id,'type',p_object_type,'object_id',p_object_id,'version_id',p_version_id,'hash',p_content_hash,'sort',p_sort_order,'expected',p_expected_release_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.release.item.add' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-release:'||p_release_id::text,0)); select * into v_release from public.catalog_releases where id=p_release_id for update;
 if v_release.status<>'DRAFT' or v_release.row_version<>p_expected_release_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.release.item.add.v1','release_id',p_release_id,'type',p_object_type,'object_id',p_object_id,'version_id',p_version_id,'hash',p_content_hash,'sort',p_sort_order,'expected',p_expected_release_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.release.item.add' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 insert into public.catalog_command_keys values(v_actor,'catalog.release.item.add',p_idempotency_key,v_hash,null,clock_timestamp(),null);
 insert into public.catalog_release_items values(p_release_id,v_release.library_id,p_object_type,p_object_id,p_version_id,p_content_hash,p_sort_order);
 update public.catalog_releases set row_version=row_version+1 where id=p_release_id;
 v_response:=jsonb_build_object('outcome','CATALOG_RELEASE_ITEM_ADDED','release_id',p_release_id,'release_row_version',p_expected_release_row_version+1);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values((select steward_organization_id from public.catalog_libraries where id=v_release.library_id),v_actor,'USER','catalog.release.item.added','catalog_release',p_release_id::text,p_correlation_id,jsonb_build_object('object_type',p_object_type,'object_id',p_object_id),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values((select steward_organization_id from public.catalog_libraries where id=v_release.library_id),'catalog_release',p_release_id::text,'CatalogReleaseItemAddedV1',p_correlation_id,jsonb_build_object('release_id',p_release_id,'object_type',p_object_type,'object_id',p_object_id));
 update public.catalog_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='catalog.release.item.add' and key=p_idempotency_key; return v_response;
end $$;

create function public.submit_catalog_release(p_release_id uuid,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_release public.catalog_releases%rowtype;v_hash text;v_existing public.catalog_command_keys%rowtype;v_snapshot text;v_response jsonb;v_sensitive boolean;
begin
 select * into v_release from public.catalog_releases where id=p_release_id; if not found then raise exception 'CATALOG_RELEASE_NOT_FOUND' using errcode='P0002'; end if;
 if v_actor is null or not private.has_library_permission(v_release.library_id,'CATALOG_SUBMIT',v_actor) then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501'; end if;
 select encode(extensions.digest(convert_to(string_agg(object_type||':'||object_id::text||':'||version_id::text||':'||content_hash||':'||sort_order::text,',' order by sort_order,object_type,object_id),'UTF8'),'sha256'),'hex') into v_snapshot from public.catalog_release_items where release_id=p_release_id;
 select v_release.requires_central_approval or exists(
  select 1 from public.catalog_release_items i
  where i.release_id=p_release_id and (
   (i.object_type='LIBRARY' and exists(select 1 from public.catalog_library_versions v where v.id=i.version_id and v.sensitive)) or
   (i.object_type='CATEGORY' and exists(select 1 from public.catalog_category_versions v where v.id=i.version_id and v.sensitive)) or
   (i.object_type='SUBCATEGORY' and exists(select 1 from public.catalog_subcategory_versions v where v.id=i.version_id and v.sensitive)) or
   (i.object_type='SERVICE' and exists(select 1 from public.catalog_service_versions v where v.id=i.version_id and v.sensitive))
  )
 ) into v_sensitive;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.release.submit.v1','release_id',p_release_id,'expected',p_expected_row_version,'snapshot',v_snapshot));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.release.submit' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-release:'||p_release_id::text,0)); select * into v_release from public.catalog_releases where id=p_release_id for update;
 if v_release.status<>'DRAFT' or v_release.row_version<>p_expected_row_version or not exists(select 1 from public.catalog_release_items where release_id=p_release_id) then raise exception 'INVALID_CATALOG_RELEASE_STATE' using errcode='55000'; end if;
 perform private.validate_catalog_release_tree(p_release_id);
 select encode(extensions.digest(convert_to(string_agg(object_type||':'||object_id::text||':'||version_id::text||':'||content_hash||':'||sort_order::text,',' order by sort_order,object_type,object_id),'UTF8'),'sha256'),'hex') into v_snapshot from public.catalog_release_items where release_id=p_release_id;
 select v_release.requires_central_approval or exists(
  select 1 from public.catalog_release_items i
  where i.release_id=p_release_id and (
   (i.object_type='LIBRARY' and exists(select 1 from public.catalog_library_versions v where v.id=i.version_id and v.sensitive)) or
   (i.object_type='CATEGORY' and exists(select 1 from public.catalog_category_versions v where v.id=i.version_id and v.sensitive)) or
   (i.object_type='SUBCATEGORY' and exists(select 1 from public.catalog_subcategory_versions v where v.id=i.version_id and v.sensitive)) or
   (i.object_type='SERVICE' and exists(select 1 from public.catalog_service_versions v where v.id=i.version_id and v.sensitive))
  )
 ) into v_sensitive;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.release.submit.v1','release_id',p_release_id,'expected',p_expected_row_version,'snapshot',v_snapshot));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.release.submit' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 insert into public.catalog_command_keys values(v_actor,'catalog.release.submit',p_idempotency_key,v_hash,null,clock_timestamp(),null);
 update public.catalog_releases set snapshot_hash=v_snapshot,requires_central_approval=v_sensitive,status=case when v_sensitive then 'IN_REVIEW' else 'APPROVED' end,row_version=row_version+1 where id=p_release_id;
 if v_sensitive then insert into public.catalog_change_requests(library_id,target_type,target_id,target_version_id,sensitive,requested_by) values(v_release.library_id,'RELEASE',p_release_id,p_release_id,true,v_actor); end if;
 v_response:=jsonb_build_object('outcome','CATALOG_RELEASE_SUBMITTED','release_id',p_release_id,'status',case when v_sensitive then 'IN_REVIEW' else 'APPROVED' end,'snapshot_hash',v_snapshot);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values((select steward_organization_id from public.catalog_libraries where id=v_release.library_id),v_actor,'USER','catalog.release.submitted','catalog_release',p_release_id::text,p_correlation_id,jsonb_build_object('sensitive',v_sensitive,'snapshot_hash',v_snapshot),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values((select steward_organization_id from public.catalog_libraries where id=v_release.library_id),'catalog_release',p_release_id::text,'CatalogChangeSubmittedV1',p_correlation_id,jsonb_build_object('release_id',p_release_id,'library_id',v_release.library_id));
 update public.catalog_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='catalog.release.submit' and key=p_idempotency_key; return v_response;
end $$;

create function public.decide_catalog_change(p_change_request_id uuid,p_approved boolean,p_comment text,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_change public.catalog_change_requests%rowtype;v_release public.catalog_releases%rowtype;v_hash text;v_existing public.catalog_command_keys%rowtype;v_response jsonb;v_decision text;v_before_hash text;
begin
 if v_actor is null or auth.jwt()->>'aal'<>'aal2' then raise exception 'CENTRAL_MFA_REQUIRED' using errcode='42501'; end if;
 if p_approved is null or length(btrim(coalesce(p_comment,''))) not between 3 and 1000 then raise exception 'INVALID_CATALOG_DECISION' using errcode='22023'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.change.decide.v1','request_id',p_change_request_id,'approved',p_approved,'comment',btrim(p_comment),'expected',p_expected_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.change.decide' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 select * into v_change from public.catalog_change_requests where id=p_change_request_id for update; if not found then raise exception 'CATALOG_CHANGE_NOT_FOUND' using errcode='P0002'; end if;
 if not private.has_library_permission(v_change.library_id,'CATALOG_APPROVE',v_actor) then raise exception 'CATALOG_APPROVAL_DENIED' using errcode='42501'; end if;
 if v_change.requested_by=v_actor then raise exception 'CATALOG_SELF_APPROVAL_DENIED' using errcode='42501'; end if;
 if v_change.status<>'IN_REVIEW' or v_change.row_version<>p_expected_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001'; end if;
 select r.snapshot_hash into v_before_hash from public.catalog_libraries l left join public.catalog_releases r on r.id=l.current_release_id where l.id=v_change.library_id;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.change.decide.v1','request_id',p_change_request_id,'approved',p_approved,'comment',btrim(p_comment),'expected',p_expected_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.change.decide' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 insert into public.catalog_command_keys values(v_actor,'catalog.change.decide',p_idempotency_key,v_hash,null,clock_timestamp(),null); v_decision:=case when p_approved then 'APPROVED' else 'REJECTED' end;
 update public.catalog_change_requests set status=v_decision,reviewed_by=v_actor,reviewed_at=clock_timestamp(),review_comment=btrim(p_comment),row_version=row_version+1 where id=p_change_request_id;
 if v_change.target_type='RELEASE' then update public.catalog_releases set status=case when p_approved then 'APPROVED' else 'DRAFT' end,approved_by=case when p_approved then v_actor else null end,approved_at=case when p_approved then clock_timestamp() else null end,row_version=row_version+1 where id=v_change.target_id returning * into v_release; else raise exception 'CATALOG_CHANGE_TYPE_NOT_IMPLEMENTED' using errcode='0A000'; end if;
 insert into public.catalog_approvals(change_request_id,library_id,decision,before_hash,after_hash,comment,decided_by,correlation_id) values(p_change_request_id,v_change.library_id,v_decision,coalesce(v_before_hash,repeat('0',64)),coalesce(v_release.snapshot_hash,repeat('0',64)),btrim(p_comment),v_actor,p_correlation_id);
 v_response:=jsonb_build_object('outcome',case when p_approved then 'CATALOG_CHANGE_APPROVED' else 'CATALOG_CHANGE_REJECTED' end,'change_request_id',p_change_request_id,'status',v_decision);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values((select steward_organization_id from public.catalog_libraries where id=v_change.library_id),v_actor,'USER','catalog.change.decided','catalog_change_request',p_change_request_id::text,p_correlation_id,jsonb_build_object('approved',p_approved),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values((select steward_organization_id from public.catalog_libraries where id=v_change.library_id),'catalog_change_request',p_change_request_id::text,case when p_approved then 'CatalogChangeApprovedV1' else 'CatalogChangeRejectedV1' end,p_correlation_id,jsonb_build_object('change_request_id',p_change_request_id,'library_id',v_change.library_id));
 update public.catalog_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='catalog.change.decide' and key=p_idempotency_key; return v_response;
end $$;

create function public.schedule_catalog_release(p_release_id uuid,p_effective_from timestamptz,p_effective_until timestamptz,p_audience jsonb,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_release public.catalog_releases%rowtype;v_hash text;v_existing public.catalog_command_keys%rowtype;v_response jsonb;v_audience jsonb;
begin
 select * into v_release from public.catalog_releases where id=p_release_id; if not found then raise exception 'CATALOG_RELEASE_NOT_FOUND' using errcode='P0002'; end if;
 if v_actor is null or not private.has_library_permission(v_release.library_id,'CATALOG_PUBLISH',v_actor) then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501'; end if;
 v_audience:=private.canonical_catalog_audience(p_audience);
 if p_effective_from is null or (p_effective_until is not null and p_effective_until<=p_effective_from) then raise exception 'INVALID_CATALOG_SCHEDULE' using errcode='22023'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.release.schedule.v1','release_id',p_release_id,'from',p_effective_from,'until',p_effective_until,'audience',v_audience,'expected',p_expected_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.release.schedule' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-library:'||v_release.library_id::text,0)); select * into v_release from public.catalog_releases where id=p_release_id for update;
 if v_release.row_version<>p_expected_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001'; end if;
 if v_release.status not in ('APPROVED','FAILED') then raise exception 'INVALID_CATALOG_RELEASE_STATE' using errcode='55000'; end if;
 if exists(select 1 from public.catalog_releases r where r.library_id=v_release.library_id and r.id<>p_release_id and r.status in ('SCHEDULED','PUBLISHING','PUBLISHED') and (r.status<>'PUBLISHED' or r.id is distinct from v_release.based_on_release_id) and private.catalog_audiences_overlap(r.audience,v_audience) and tstzrange(r.effective_from,r.effective_until,'[)') && tstzrange(p_effective_from,p_effective_until,'[)')) then raise exception 'CATALOG_SCHEDULE_CONFLICT' using errcode='23P01'; end if;
 insert into public.catalog_command_keys values(v_actor,'catalog.release.schedule',p_idempotency_key,v_hash,null,clock_timestamp(),null);
 update public.catalog_releases set status='SCHEDULED',effective_from=p_effective_from,effective_until=p_effective_until,audience=v_audience,row_version=row_version+1 where id=p_release_id;
 v_response:=jsonb_build_object('outcome','CATALOG_RELEASE_SCHEDULED','release_id',p_release_id,'effective_from',p_effective_from,'release_row_version',p_expected_row_version+1);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values((select steward_organization_id from public.catalog_libraries where id=v_release.library_id),v_actor,'USER','catalog.release.scheduled','catalog_release',p_release_id::text,p_correlation_id,jsonb_build_object('effective_from',p_effective_from,'audience',v_audience),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values((select steward_organization_id from public.catalog_libraries where id=v_release.library_id),'catalog_release',p_release_id::text,'CatalogReleaseScheduledV1',p_correlation_id,jsonb_build_object('release_id',p_release_id,'library_id',v_release.library_id,'effective_from',p_effective_from));
 update public.catalog_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='catalog.release.schedule' and key=p_idempotency_key; return v_response;
end $$;

create function public.cancel_catalog_release(p_release_id uuid,p_reason text,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_release public.catalog_releases%rowtype;v_hash text;v_existing public.catalog_command_keys%rowtype;v_response jsonb;
begin
 select * into v_release from public.catalog_releases where id=p_release_id; if not found then raise exception 'CATALOG_RELEASE_NOT_FOUND' using errcode='P0002'; end if;
 if v_actor is null or not private.has_library_permission(v_release.library_id,'CATALOG_PUBLISH',v_actor) then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501'; end if;
 if length(btrim(coalesce(p_reason,''))) not between 3 and 500 then raise exception 'INVALID_CATALOG_CANCELLATION' using errcode='22023'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.release.cancel.v1','release_id',p_release_id,'reason',btrim(p_reason),'expected',p_expected_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.release.cancel' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-library:'||v_release.library_id::text,0)); select * into v_release from public.catalog_releases where id=p_release_id for update;
 if v_release.row_version<>p_expected_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001'; end if;
 if v_release.status not in ('DRAFT','APPROVED','SCHEDULED','FAILED') then raise exception 'INVALID_CATALOG_RELEASE_STATE' using errcode='55000'; end if;
 insert into public.catalog_command_keys values(v_actor,'catalog.release.cancel',p_idempotency_key,v_hash,null,clock_timestamp(),null);
 update public.catalog_releases set status='CANCELLED',lease_token=null,leased_until=null,last_error_code=null,row_version=row_version+1 where id=p_release_id;
 v_response:=jsonb_build_object('outcome','CATALOG_RELEASE_CANCELLED','release_id',p_release_id,'release_row_version',p_expected_row_version+1);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values((select steward_organization_id from public.catalog_libraries where id=v_release.library_id),v_actor,'USER','catalog.release.cancelled','catalog_release',p_release_id::text,p_correlation_id,jsonb_build_object('reason',btrim(p_reason)),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values((select steward_organization_id from public.catalog_libraries where id=v_release.library_id),'catalog_release',p_release_id::text,'CatalogReleaseCancelledV1',p_correlation_id,jsonb_build_object('release_id',p_release_id,'library_id',v_release.library_id));
 update public.catalog_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='catalog.release.cancel' and key=p_idempotency_key; return v_response;
end $$;

create function public.attest_catalog_ar_translation(p_object_type text,p_version_id uuid,p_proof_hash text,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_library_id uuid;v_status text;v_row_version integer;v_created_by uuid;v_translation_version integer;v_hash text;v_existing public.catalog_command_keys%rowtype;v_response jsonb;v_org uuid;
begin
 if p_object_type not in ('LIBRARY','CATEGORY','SUBCATEGORY','SERVICE') or coalesce(p_proof_hash,'')!~'^[0-9a-f]{64}$' then raise exception 'INVALID_TRANSLATION_ATTESTATION' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-translation:'||p_version_id::text,0));
 select library_id,status,row_version,created_by,translation_review_version into v_library_id,v_status,v_row_version,v_created_by,v_translation_version from (
  select library_id,status,row_version,created_by,translation_review_version from public.catalog_library_versions where p_object_type='LIBRARY' and id=p_version_id
  union all select library_id,status,row_version,created_by,translation_review_version from public.catalog_category_versions where p_object_type='CATEGORY' and id=p_version_id
  union all select library_id,status,row_version,created_by,translation_review_version from public.catalog_subcategory_versions where p_object_type='SUBCATEGORY' and id=p_version_id
  union all select library_id,status,row_version,created_by,translation_review_version from public.catalog_service_versions where p_object_type='SERVICE' and id=p_version_id
 ) v;
 if v_library_id is null then raise exception 'CATALOG_VERSION_NOT_FOUND' using errcode='P0002'; end if;
 if v_actor is null or auth.jwt()->>'aal'<>'aal2' or v_created_by=v_actor or not private.has_library_permission(v_library_id,'CATALOG_APPROVE',v_actor) then raise exception 'TRANSLATION_REVIEW_DENIED' using errcode='42501'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.translation.attest.v1','object_type',p_object_type,'version_id',p_version_id,'proof_hash',p_proof_hash,'expected',p_expected_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.translation.attest' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; return v_existing.response_body; end if;
 if v_row_version<>p_expected_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001'; end if;
 if v_status in ('PUBLISHED','RETIRED','ARCHIVED') then raise exception 'IMMUTABLE_CATALOG_HISTORY' using errcode='55000'; end if;
 insert into public.catalog_command_keys values(v_actor,'catalog.translation.attest',p_idempotency_key,v_hash,null,clock_timestamp(),null);
 if p_object_type='LIBRARY' then update public.catalog_library_versions set translation_review_status='APPROVED',translation_reviewer_user_id=v_actor,translation_reviewed_at=clock_timestamp(),translation_review_proof_hash=p_proof_hash,translation_review_version=translation_review_version+1,row_version=row_version+1 where id=p_version_id and row_version=p_expected_row_version;
 elsif p_object_type='CATEGORY' then update public.catalog_category_versions set translation_review_status='APPROVED',translation_reviewer_user_id=v_actor,translation_reviewed_at=clock_timestamp(),translation_review_proof_hash=p_proof_hash,translation_review_version=translation_review_version+1,row_version=row_version+1 where id=p_version_id and row_version=p_expected_row_version;
 elsif p_object_type='SUBCATEGORY' then update public.catalog_subcategory_versions set translation_review_status='APPROVED',translation_reviewer_user_id=v_actor,translation_reviewed_at=clock_timestamp(),translation_review_proof_hash=p_proof_hash,translation_review_version=translation_review_version+1,row_version=row_version+1 where id=p_version_id and row_version=p_expected_row_version;
 else update public.catalog_service_versions set translation_review_status='APPROVED',translation_reviewer_user_id=v_actor,translation_reviewed_at=clock_timestamp(),translation_review_proof_hash=p_proof_hash,translation_review_version=translation_review_version+1,row_version=row_version+1 where id=p_version_id and row_version=p_expected_row_version; end if;
 if not found then raise exception 'STALE_CATALOG_VERSION' using errcode='40001'; end if;
 select steward_organization_id into v_org from public.catalog_libraries where id=v_library_id;
 v_response:=jsonb_build_object('outcome','CATALOG_AR_TRANSLATION_ATTESTED','object_type',p_object_type,'version_id',p_version_id,'translation_review_version',v_translation_version+1,'row_version',p_expected_row_version+1);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_org,v_actor,'USER','catalog.translation.attested','catalog_translation',p_version_id::text,p_correlation_id,jsonb_build_object('object_type',p_object_type,'proof_hash',p_proof_hash,'translation_review_version',v_translation_version+1),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values(v_org,'catalog_translation',p_version_id::text,'CatalogArabicTranslationAttestedV1',p_correlation_id,jsonb_build_object('object_type',p_object_type,'version_id',p_version_id,'translation_review_version',v_translation_version+1));
 update public.catalog_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='catalog.translation.attest' and key=p_idempotency_key; return v_response;
end $$;

create function public.revoke_catalog_library_mandate(p_mandate_id uuid,p_expected_row_version integer,p_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_mandate public.catalog_library_mandates%rowtype;v_hash text;v_existing public.catalog_command_keys%rowtype;v_response jsonb;
begin
 select * into v_mandate from public.catalog_library_mandates where id=p_mandate_id; if not found then raise exception 'CATALOG_MANDATE_NOT_FOUND' using errcode='P0002'; end if;
 if v_actor is null or auth.jwt()->>'aal'<>'aal2' or not private.has_library_permission(v_mandate.library_id,'CATALOG_APPROVE',v_actor) then raise exception 'CATALOG_MANDATE_REVOKE_DENIED' using errcode='42501'; end if;
 if length(btrim(coalesce(p_reason,''))) not between 3 and 500 then raise exception 'INVALID_CATALOG_MANDATE_REVOCATION' using errcode='22023'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.mandate.revoke.v1','mandate_id',p_mandate_id,'expected',p_expected_row_version,'reason',btrim(p_reason)));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.mandate.revoke' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; return v_existing.response_body; end if;
 select * into v_mandate from public.catalog_library_mandates where id=p_mandate_id for update;
 if v_mandate.row_version<>p_expected_row_version or v_mandate.status<>'ACTIVE' then raise exception 'STALE_CATALOG_VERSION' using errcode='40001'; end if;
 insert into public.catalog_command_keys values(v_actor,'catalog.mandate.revoke',p_idempotency_key,v_hash,null,clock_timestamp(),null);
 insert into private.catalog_acl_write_capabilities(backend_pid,transaction_id) values(pg_backend_pid(),txid_current());
 update public.catalog_library_mandates set status='REVOKED',valid_until=coalesce(valid_until,clock_timestamp()),row_version=row_version+1 where id=p_mandate_id;
 delete from private.catalog_acl_write_capabilities where backend_pid=pg_backend_pid() and transaction_id=txid_current();
 v_response:=jsonb_build_object('outcome','CATALOG_MANDATE_REVOKED','mandate_id',p_mandate_id,'row_version',p_expected_row_version+1);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_mandate.organization_id,v_actor,'USER','catalog.mandate.revoked','catalog_library_mandate',p_mandate_id::text,p_correlation_id,jsonb_build_object('reason',btrim(p_reason),'policy_version',v_mandate.policy_version),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values(v_mandate.organization_id,'catalog_library_mandate',p_mandate_id::text,'CatalogLibraryMandateRevokedV1',p_correlation_id,jsonb_build_object('mandate_id',p_mandate_id,'library_id',v_mandate.library_id));
 update public.catalog_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='catalog.mandate.revoke' and key=p_idempotency_key; return v_response;
end $$;

create function public.revoke_catalog_permission_policy(p_role_code text,p_permission_code text,p_policy_version integer,p_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_hash text;v_existing public.catalog_command_keys%rowtype;v_response jsonb;
begin
 if v_actor is null or auth.jwt()->>'aal'<>'aal2' or not exists(
  select 1 from public.platform_user_roles r join public.catalog_permission_policies p on p.role_code=r.role_code
  where r.user_id=v_actor and r.revoked_at is null and r.role_code in ('SUPER_ADMIN','MATRICIA_ADMIN')
    and p.permission_code='CATALOG_APPROVE' and p.active and statement_timestamp()>=p.valid_from and (p.valid_until is null or statement_timestamp()<p.valid_until)
 ) then raise exception 'CATALOG_POLICY_REVOKE_DENIED' using errcode='42501'; end if;
 if length(btrim(coalesce(p_reason,''))) not between 3 and 500 then raise exception 'INVALID_CATALOG_POLICY_REVOCATION' using errcode='22023'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.policy.revoke.v1','role',p_role_code,'permission',p_permission_code,'version',p_policy_version,'reason',btrim(p_reason)));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.policy.revoke' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; return v_existing.response_body; end if;
 perform 1 from public.catalog_permission_policies where role_code=p_role_code and permission_code=p_permission_code and policy_version=p_policy_version and active for update;
 if not found then raise exception 'CATALOG_POLICY_NOT_ACTIVE' using errcode='P0002'; end if;
 insert into public.catalog_command_keys values(v_actor,'catalog.policy.revoke',p_idempotency_key,v_hash,null,clock_timestamp(),null);
 insert into private.catalog_acl_write_capabilities(backend_pid,transaction_id) values(pg_backend_pid(),txid_current());
 update public.catalog_permission_policies set active=false,valid_until=coalesce(valid_until,clock_timestamp()),row_version=row_version+1 where role_code=p_role_code and permission_code=p_permission_code and policy_version=p_policy_version;
 delete from private.catalog_acl_write_capabilities where backend_pid=pg_backend_pid() and transaction_id=txid_current();
 v_response:=jsonb_build_object('outcome','CATALOG_PERMISSION_POLICY_REVOKED','role_code',p_role_code,'permission_code',p_permission_code,'policy_version',p_policy_version);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(null,v_actor,'USER','catalog.permission_policy.revoked','catalog_permission_policy',p_role_code||':'||p_permission_code||':'||p_policy_version,p_correlation_id,jsonb_build_object('reason',btrim(p_reason),'scope','PLATFORM'),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values(null,'catalog_permission_policy',p_role_code||':'||p_permission_code||':'||p_policy_version,'CatalogPermissionPolicyRevokedV1',p_correlation_id,jsonb_build_object('role_code',p_role_code,'permission_code',p_permission_code,'policy_version',p_policy_version,'scope','PLATFORM'));
 update public.catalog_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='catalog.policy.revoke' and key=p_idempotency_key; return v_response;
end $$;

create function public.record_catalog_publish_failure(p_release_id uuid,p_error_code text,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_release public.catalog_releases%rowtype;v_hash text;v_existing public.catalog_command_keys%rowtype;v_response jsonb;
begin
 if auth.role()<>'service_role' then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 select * into v_release from public.catalog_releases where id=p_release_id; if not found then raise exception 'CATALOG_RELEASE_NOT_FOUND' using errcode='P0002'; end if;
 if v_actor is null or auth.jwt()->>'aal'<>'aal2' or not private.has_library_permission(v_release.library_id,'CATALOG_PUBLISH',v_actor) then raise exception 'CENTRAL_MFA_REQUIRED' using errcode='42501'; end if;
 if coalesce(p_error_code,'')!~'^[A-Z][A-Z0-9_]{2,79}$' then raise exception 'INVALID_CATALOG_FAILURE' using errcode='22023'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.release.failure.v1','release_id',p_release_id,'error_code',p_error_code,'expected',p_expected_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.release.failure' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-library:'||v_release.library_id::text,0)); select * into v_release from public.catalog_releases where id=p_release_id for update;
 if v_release.row_version<>p_expected_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001'; end if;
 if v_release.status not in ('SCHEDULED','PUBLISHING') then raise exception 'INVALID_CATALOG_RELEASE_STATE' using errcode='55000'; end if;
 insert into public.catalog_command_keys values(v_actor,'catalog.release.failure',p_idempotency_key,v_hash,null,clock_timestamp(),null);
 update public.catalog_releases set status='FAILED',last_error_code=p_error_code,lease_token=null,leased_until=null,publish_attempts=publish_attempts+1,row_version=row_version+1 where id=p_release_id;
 v_response:=jsonb_build_object('outcome','CATALOG_RELEASE_FAILED','release_id',p_release_id,'error_code',p_error_code,'release_row_version',p_expected_row_version+1);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values((select steward_organization_id from public.catalog_libraries where id=v_release.library_id),v_actor,'USER','catalog.release.failed','catalog_release',p_release_id::text,p_correlation_id,jsonb_build_object('error_code',p_error_code),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values((select steward_organization_id from public.catalog_libraries where id=v_release.library_id),'catalog_release',p_release_id::text,'CatalogReleaseFailedV1',p_correlation_id,jsonb_build_object('release_id',p_release_id,'library_id',v_release.library_id,'error_code',p_error_code));
 update public.catalog_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='catalog.release.failure' and key=p_idempotency_key; return v_response;
end $$;

create function public.publish_catalog_release(p_release_id uuid,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_release public.catalog_releases%rowtype;v_previous uuid;v_hash text;v_existing public.catalog_command_keys%rowtype;v_response jsonb;v_actual_snapshot text;
begin
 if auth.role()<>'service_role' then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 select * into v_release from public.catalog_releases where id=p_release_id; if not found then raise exception 'CATALOG_RELEASE_NOT_FOUND' using errcode='P0002'; end if;
 if v_actor is null or not private.has_library_permission(v_release.library_id,'CATALOG_PUBLISH',v_actor) then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.release.publish.v1','release_id',p_release_id,'expected',p_expected_row_version,'snapshot',v_release.snapshot_hash));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.release.publish' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-library:'||v_release.library_id::text,0)); select * into v_release from public.catalog_releases where id=p_release_id for update;
 if v_release.row_version<>p_expected_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001'; end if;
 if v_release.status not in ('APPROVED','SCHEDULED') or v_release.snapshot_hash is null or (v_release.requires_central_approval and v_release.approved_by is null)
    or v_release.effective_from>statement_timestamp() or (v_release.effective_until is not null and v_release.effective_until<=statement_timestamp()) then raise exception 'INVALID_CATALOG_RELEASE_STATE' using errcode='55000'; end if;
 select current_release_id into v_previous from public.catalog_libraries where id=v_release.library_id for update;
 if v_previous is distinct from v_release.based_on_release_id then raise exception 'STALE_CATALOG_BASE_RELEASE' using errcode='40001'; end if;
 select encode(extensions.digest(convert_to(string_agg(object_type||':'||object_id::text||':'||version_id::text||':'||content_hash||':'||sort_order::text,',' order by sort_order,object_type,object_id),'UTF8'),'sha256'),'hex') into v_actual_snapshot from public.catalog_release_items where release_id=p_release_id;
 if v_actual_snapshot is distinct from v_release.snapshot_hash then raise exception 'STALE_CATALOG_SNAPSHOT' using errcode='40001'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.release.publish.v1','release_id',p_release_id,'expected',p_expected_row_version,'snapshot',v_release.snapshot_hash));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.release.publish' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 insert into public.catalog_command_keys values(v_actor,'catalog.release.publish',p_idempotency_key,v_hash,null,clock_timestamp(),null);
 update public.catalog_releases set status='PUBLISHING',lease_token=extensions.gen_random_uuid(),leased_until=clock_timestamp()+interval '5 minutes',publish_attempts=publish_attempts+1,row_version=row_version+1 where id=p_release_id;
 if v_previous is not null then update public.catalog_releases set status='RETIRED',retired_at=clock_timestamp(),row_version=row_version+1 where id=v_previous and status='PUBLISHED'; end if;
 perform private.activate_catalog_release_items(p_release_id);
 update public.catalog_releases set status='PUBLISHED',published_by=v_actor,published_at=clock_timestamp(),retired_at=null,lease_token=null,leased_until=null,last_error_code=null,row_version=row_version+1 where id=p_release_id;
 update public.catalog_libraries set status='PUBLISHED',current_release_id=p_release_id,row_version=row_version+1,updated_at=clock_timestamp() where id=v_release.library_id;
 v_response:=jsonb_build_object('outcome','CATALOG_RELEASE_PUBLISHED','release_id',p_release_id,'previous_release_id',v_previous,'snapshot_hash',v_release.snapshot_hash);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values((select steward_organization_id from public.catalog_libraries where id=v_release.library_id),v_actor,'USER','catalog.release.published','catalog_release',p_release_id::text,p_correlation_id,jsonb_build_object('previous_release_id',v_previous,'snapshot_hash',v_release.snapshot_hash),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values((select steward_organization_id from public.catalog_libraries where id=v_release.library_id),'catalog_release',p_release_id::text,'CatalogReleasePublishedV1',p_correlation_id,jsonb_build_object('release_id',p_release_id,'library_id',v_release.library_id,'snapshot_hash',v_release.snapshot_hash));
 update public.catalog_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='catalog.release.publish' and key=p_idempotency_key; return v_response;
end $$;

create function public.rollback_catalog_release(p_library_id uuid,p_target_release_id uuid,p_release_key text,p_expected_library_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_library public.catalog_libraries%rowtype;v_target public.catalog_releases%rowtype;v_id uuid;v_hash text;v_existing public.catalog_command_keys%rowtype;v_response jsonb;
begin
 if v_actor is null or auth.jwt()->>'aal'<>'aal2' or not private.has_library_permission(p_library_id,'CATALOG_ROLLBACK',v_actor) then raise exception 'CENTRAL_MFA_REQUIRED' using errcode='42501'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.release.rollback.v1','library_id',p_library_id,'target',p_target_release_id,'key',p_release_key,'expected',p_expected_library_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.release.rollback' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-library:'||p_library_id::text,0)); select * into v_library from public.catalog_libraries where id=p_library_id for update; select * into v_target from public.catalog_releases where id=p_target_release_id and library_id=p_library_id;
 if not found or v_target.status not in ('PUBLISHED','RETIRED') then raise exception 'ROLLBACK_RELEASE_NOT_FOUND' using errcode='P0002'; end if; if v_library.row_version<>p_expected_library_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001'; end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.release.rollback.v1','library_id',p_library_id,'target',p_target_release_id,'key',p_release_key,'expected',p_expected_library_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.release.rollback' and key=p_idempotency_key;
 if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if; if v_existing.response_body is not null then return v_existing.response_body; end if; raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000'; end if;
 insert into public.catalog_command_keys values(v_actor,'catalog.release.rollback',p_idempotency_key,v_hash,null,clock_timestamp(),null);
 insert into public.catalog_releases(library_id,release_key,status,source_bundle_hash,snapshot_hash,based_on_release_id,rollback_target_release_id,requires_central_approval,created_by,approved_by,approved_at,effective_from)
 values(p_library_id,p_release_key,'SCHEDULED',v_target.source_bundle_hash,v_target.snapshot_hash,v_library.current_release_id,p_target_release_id,true,v_actor,v_actor,clock_timestamp(),clock_timestamp()) returning id into v_id;
 insert into public.catalog_release_items select v_id,library_id,object_type,object_id,version_id,content_hash,sort_order from public.catalog_release_items where release_id=p_target_release_id;
 v_response:=jsonb_build_object('outcome','CATALOG_ROLLBACK_SCHEDULED','release_id',v_id,'rollback_target_release_id',p_target_release_id,'snapshot_hash',v_target.snapshot_hash);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_library.steward_organization_id,v_actor,'USER','catalog.release.rollback_scheduled','catalog_release',v_id::text,p_correlation_id,jsonb_build_object('rollback_target_release_id',p_target_release_id,'snapshot_hash',v_target.snapshot_hash),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values(v_library.steward_organization_id,'catalog_release',v_id::text,'CatalogRollbackScheduledV1',p_correlation_id,jsonb_build_object('release_id',v_id,'library_id',p_library_id,'rollback_target_release_id',p_target_release_id));
 update public.catalog_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='catalog.release.rollback' and key=p_idempotency_key; return v_response;
end $$;

create function public.claim_catalog_release(p_worker_id uuid,p_release_id uuid default null,p_lease_seconds integer default 300) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions as $$
declare v_release public.catalog_releases%rowtype;v_token uuid:=extensions.gen_random_uuid();v_policy public.catalog_publish_retry_policies%rowtype;v_org uuid;v_reclaimed boolean;v_correlation uuid:=extensions.gen_random_uuid();
begin
 if auth.role()<>'service_role' then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if p_worker_id is null or p_lease_seconds not between 1 and 900 then raise exception 'INVALID_CATALOG_LEASE' using errcode='22023'; end if;
 select * into v_policy from public.catalog_publish_retry_policies where status='ACTIVE'; if not found then raise exception 'CATALOG_RETRY_POLICY_MISSING' using errcode='55000'; end if;
 select * into v_release from public.catalog_releases where (p_release_id is null or id=p_release_id) and status='PUBLISHING'
   and leased_until<=clock_timestamp() and publish_attempts>=v_policy.max_attempts order by effective_from,id for update skip locked limit 1;
 if found then
  select steward_organization_id into v_org from public.catalog_libraries where id=v_release.library_id;
  update public.catalog_releases set status='DEAD_LETTER',lease_token=null,leased_until=null,next_attempt_at=null,terminal_at=clock_timestamp(),last_error_code='LEASE_EXPIRED_MAX_ATTEMPTS',row_version=row_version+1 where id=v_release.id;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_org,null,'SYSTEM','catalog.release.dead_lettered','catalog_release',v_release.id::text,v_correlation,jsonb_build_object('error_code','LEASE_EXPIRED_MAX_ATTEMPTS','worker_id',v_release.lease_worker_id,'attempt',v_release.publish_attempts),null,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values(v_org,'catalog_release',v_release.id::text,'CatalogReleaseDeadLetteredV1',v_correlation,jsonb_build_object('release_id',v_release.id,'library_id',v_release.library_id,'error_code','LEASE_EXPIRED_MAX_ATTEMPTS','attempt',v_release.publish_attempts));
  return jsonb_build_object('outcome','CATALOG_RELEASE_DEAD_LETTERED','release_id',v_release.id,'release_row_version',v_release.row_version+1);
 end if;
 select * into v_release from public.catalog_releases where (p_release_id is null or id=p_release_id)
   and ((status='SCHEDULED' and effective_from<=statement_timestamp()) or (status='FAILED' and next_attempt_at<=statement_timestamp()) or (status='PUBLISHING' and leased_until<=clock_timestamp()))
   and publish_attempts<v_policy.max_attempts and (effective_until is null or effective_until>statement_timestamp()) order by effective_from,id for update skip locked limit 1;
 if not found then return jsonb_build_object('outcome','NO_CATALOG_RELEASE_DUE'); end if;
 v_reclaimed:=v_release.status='PUBLISHING';
 update public.catalog_releases set status='PUBLISHING',lease_token=v_token,last_lease_token=v_token,lease_worker_id=p_worker_id,leased_until=clock_timestamp()+make_interval(secs=>p_lease_seconds),next_attempt_at=null,publish_attempts=publish_attempts+1,row_version=row_version+1 where id=v_release.id;
 select steward_organization_id into v_org from public.catalog_libraries where id=v_release.library_id;
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_org,null,'SYSTEM',case when v_reclaimed then 'catalog.release.reclaimed' else 'catalog.release.claimed' end,'catalog_release',v_release.id::text,v_correlation,jsonb_build_object('previous_worker_id',case when v_reclaimed then v_release.lease_worker_id else null end,'worker_id',p_worker_id,'attempt',v_release.publish_attempts+1),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values(v_org,'catalog_release',v_release.id::text,case when v_reclaimed then 'CatalogReleaseReclaimedV1' else 'CatalogReleaseClaimedV1' end,v_correlation,jsonb_build_object('release_id',v_release.id,'worker_id',p_worker_id,'attempt',v_release.publish_attempts+1));
 return jsonb_build_object('outcome','CATALOG_RELEASE_CLAIMED','release_id',v_release.id,'lease_token',v_token,'release_row_version',v_release.row_version+1,'worker_id',p_worker_id);
end $$;

create function public.complete_catalog_release_publish(p_release_id uuid,p_lease_token uuid,p_expected_row_version integer,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_release public.catalog_releases%rowtype;v_previous uuid;v_actual_snapshot text;v_org uuid;v_response jsonb;
begin
 if auth.role()<>'service_role' then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-library-publish:'||p_release_id::text,0));
 select * into v_release from public.catalog_releases where id=p_release_id for update; if not found then raise exception 'CATALOG_RELEASE_NOT_FOUND' using errcode='P0002'; end if;
 if v_release.status in ('PUBLISHED','RETIRED') and v_release.last_lease_token=p_lease_token then return jsonb_build_object('outcome','CATALOG_RELEASE_PUBLISHED','release_id',p_release_id,'previous_release_id',v_release.based_on_release_id,'snapshot_hash',v_release.snapshot_hash); end if;
 if v_release.status<>'PUBLISHING' or v_release.lease_token is distinct from p_lease_token or v_release.leased_until<=clock_timestamp() then raise exception 'INVALID_CATALOG_LEASE' using errcode='55000'; end if;
 if v_release.row_version<>p_expected_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001'; end if;
 select current_release_id,steward_organization_id into v_previous,v_org from public.catalog_libraries where id=v_release.library_id for update;
 if v_previous is distinct from v_release.based_on_release_id then raise exception 'STALE_CATALOG_BASE_RELEASE' using errcode='40001'; end if;
 select encode(extensions.digest(convert_to(string_agg(object_type||':'||object_id::text||':'||version_id::text||':'||content_hash||':'||sort_order::text,',' order by sort_order,object_type,object_id),'UTF8'),'sha256'),'hex') into v_actual_snapshot from public.catalog_release_items where release_id=p_release_id;
 if v_actual_snapshot is distinct from v_release.snapshot_hash then raise exception 'STALE_CATALOG_SNAPSHOT' using errcode='40001'; end if;
 perform private.validate_catalog_release_tree(p_release_id);
 if v_previous is not null then update public.catalog_releases set status='RETIRED',retired_at=clock_timestamp(),row_version=row_version+1 where id=v_previous and status='PUBLISHED'; end if;
 perform private.activate_catalog_release_items(p_release_id);
 update public.catalog_releases set status='PUBLISHED',published_at=clock_timestamp(),retired_at=null,lease_token=null,leased_until=null,last_error_code=null,row_version=row_version+1 where id=p_release_id;
 update public.catalog_libraries set status='PUBLISHED',current_release_id=p_release_id,row_version=row_version+1,updated_at=clock_timestamp() where id=v_release.library_id;
 v_response:=jsonb_build_object('outcome','CATALOG_RELEASE_PUBLISHED','release_id',p_release_id,'previous_release_id',v_previous,'snapshot_hash',v_release.snapshot_hash);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_org,null,'SYSTEM',case when v_release.rollback_target_release_id is null then 'catalog.release.published' else 'catalog.release.rolled_back' end,'catalog_release',p_release_id::text,p_correlation_id,jsonb_build_object('previous_release_id',v_previous,'rollback_target_release_id',v_release.rollback_target_release_id,'snapshot_hash',v_release.snapshot_hash,'worker_id',v_release.lease_worker_id),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values(v_org,'catalog_release',p_release_id::text,case when v_release.rollback_target_release_id is null then 'CatalogReleasePublishedV1' else 'CatalogReleaseRolledBackV1' end,p_correlation_id,jsonb_build_object('release_id',p_release_id,'library_id',v_release.library_id,'rollback_target_release_id',v_release.rollback_target_release_id,'snapshot_hash',v_release.snapshot_hash));
 return v_response;
end $$;

create function public.fail_catalog_release_publish(p_release_id uuid,p_lease_token uuid,p_error_code text,p_expected_row_version integer,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$
declare v_release public.catalog_releases%rowtype;v_org uuid;v_policy public.catalog_publish_retry_policies%rowtype;v_terminal boolean;v_next timestamptz;
begin
 if auth.role()<>'service_role' then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if coalesce(p_error_code,'')!~'^[A-Z][A-Z0-9_]{2,79}$' then raise exception 'INVALID_CATALOG_FAILURE' using errcode='22023'; end if;
 select * into v_release from public.catalog_releases where id=p_release_id for update; if not found then raise exception 'CATALOG_RELEASE_NOT_FOUND' using errcode='P0002'; end if;
 if v_release.status in ('FAILED','DEAD_LETTER') and v_release.last_lease_token=p_lease_token and v_release.last_error_code=p_error_code then
  return jsonb_build_object('outcome',case when v_release.status='DEAD_LETTER' then 'CATALOG_RELEASE_DEAD_LETTERED' else 'CATALOG_RELEASE_FAILED' end,'release_id',p_release_id,'next_attempt_at',v_release.next_attempt_at,'release_row_version',v_release.row_version);
 end if;
 if v_release.status<>'PUBLISHING' or v_release.lease_token is distinct from p_lease_token or v_release.leased_until<=clock_timestamp() or v_release.row_version<>p_expected_row_version then raise exception 'INVALID_CATALOG_LEASE' using errcode='55000'; end if;
 select * into v_policy from public.catalog_publish_retry_policies where status='ACTIVE'; if not found then raise exception 'CATALOG_RETRY_POLICY_MISSING' using errcode='55000'; end if;
 v_terminal:=v_release.publish_attempts>=v_policy.max_attempts;
 v_next:=clock_timestamp()+make_interval(secs=>least(v_policy.max_backoff_seconds,v_policy.base_backoff_seconds*power(2,greatest(v_release.publish_attempts-1,0))::integer));
 select steward_organization_id into v_org from public.catalog_libraries where id=v_release.library_id;
 update public.catalog_releases set status=case when v_terminal then 'DEAD_LETTER' else 'FAILED' end,last_error_code=p_error_code,lease_token=null,leased_until=null,next_attempt_at=case when v_terminal then null else v_next end,terminal_at=case when v_terminal then clock_timestamp() else null end,row_version=row_version+1 where id=p_release_id;
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_org,null,'SYSTEM',case when v_terminal then 'catalog.release.dead_lettered' else 'catalog.release.failed' end,'catalog_release',p_release_id::text,p_correlation_id,jsonb_build_object('error_code',p_error_code,'worker_id',v_release.lease_worker_id,'attempt',v_release.publish_attempts,'next_attempt_at',case when v_terminal then null else v_next end),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values(v_org,'catalog_release',p_release_id::text,case when v_terminal then 'CatalogReleaseDeadLetteredV1' else 'CatalogReleaseFailedV1' end,p_correlation_id,jsonb_build_object('release_id',p_release_id,'library_id',v_release.library_id,'error_code',p_error_code,'attempt',v_release.publish_attempts,'next_attempt_at',case when v_terminal then null else v_next end));
 return jsonb_build_object('outcome',case when v_terminal then 'CATALOG_RELEASE_DEAD_LETTERED' else 'CATALOG_RELEASE_FAILED' end,'release_id',p_release_id,'next_attempt_at',case when v_terminal then null else v_next end,'release_row_version',p_expected_row_version+1);
end $$;

revoke all on function public.create_catalog_release(uuid,text,text,boolean,integer,text,uuid),public.add_catalog_release_item(uuid,text,uuid,uuid,text,integer,integer,text,uuid),public.submit_catalog_release(uuid,integer,text,uuid),public.decide_catalog_change(uuid,boolean,text,integer,text,uuid),public.schedule_catalog_release(uuid,timestamptz,timestamptz,jsonb,integer,text,uuid),public.cancel_catalog_release(uuid,text,integer,text,uuid),public.record_catalog_publish_failure(uuid,text,integer,text,uuid),public.publish_catalog_release(uuid,integer,text,uuid),public.rollback_catalog_release(uuid,uuid,text,integer,text,uuid),public.attest_catalog_ar_translation(text,uuid,text,integer,text,uuid),public.revoke_catalog_library_mandate(uuid,integer,text,text,uuid),public.revoke_catalog_permission_policy(text,text,integer,text,text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.claim_catalog_release(uuid,uuid,integer),public.complete_catalog_release_publish(uuid,uuid,integer,uuid),public.fail_catalog_release_publish(uuid,uuid,text,integer,uuid) from public,anon,authenticated,service_role;
drop function public.record_catalog_publish_failure(uuid,text,integer,text,uuid);
drop function public.publish_catalog_release(uuid,integer,text,uuid);
grant execute on function public.create_catalog_release(uuid,text,text,boolean,integer,text,uuid),public.add_catalog_release_item(uuid,text,uuid,uuid,text,integer,integer,text,uuid),public.submit_catalog_release(uuid,integer,text,uuid),public.decide_catalog_change(uuid,boolean,text,integer,text,uuid),public.schedule_catalog_release(uuid,timestamptz,timestamptz,jsonb,integer,text,uuid),public.cancel_catalog_release(uuid,text,integer,text,uuid),public.rollback_catalog_release(uuid,uuid,text,integer,text,uuid),public.attest_catalog_ar_translation(text,uuid,text,integer,text,uuid),public.revoke_catalog_library_mandate(uuid,integer,text,text,uuid),public.revoke_catalog_permission_policy(text,text,integer,text,text,uuid) to authenticated;
grant execute on function public.claim_catalog_release(uuid,uuid,integer),public.complete_catalog_release_publish(uuid,uuid,integer,uuid),public.fail_catalog_release_publish(uuid,uuid,text,integer,uuid) to service_role;

notify pgrst,'reload schema';
