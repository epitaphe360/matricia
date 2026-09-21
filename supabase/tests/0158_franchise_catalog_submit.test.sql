begin;
set local search_path = public, extensions;
select plan(18);

select has_function(
  'public',
  'submit_franchise_catalog_service',
  array['uuid', 'uuid', 'integer', 'integer', 'text', 'uuid'],
  'franchise service submit exists'
);
select is_definer(
  'public',
  'submit_franchise_catalog_service',
  array['uuid', 'uuid', 'integer', 'integer', 'text', 'uuid'],
  'submit is security definer'
);
select ok(
  (
    select prosecdef and proconfig::text like '%search_path=pg_catalog%'
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'submit_franchise_catalog_service'
  ),
  'submit uses a fixed search_path'
);
select ok(
  has_function_privilege('authenticated', 'public.submit_franchise_catalog_service(uuid,uuid,integer,integer,text,uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.submit_franchise_catalog_service(uuid,uuid,integer,integer,text,uuid)', 'EXECUTE')
  and not has_function_privilege('service_role', 'public.submit_franchise_catalog_service(uuid,uuid,integer,integer,text,uuid)', 'EXECUTE'),
  'submit is authenticated-only'
);

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at) values
('f5800000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'p58-central@example.invalid', '', now(), '{}', '{}', now(), now()),
('f5800000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'p58-editor@example.invalid', '', now(), '{}', '{}', now(), now()),
('f5800000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'p58-outsider@example.invalid', '', now(), '{}', '{}', now(), now());
insert into public.platform_user_roles(user_id, role_code) values ('f5800000-0000-0000-0000-000000000001', 'MATRICIA_ADMIN');
insert into public.organizations(id, legal_name, display_name, status, created_by) values
('f5810000-0000-0000-0000-000000000001', 'P58 Steward', 'P58 Steward', 'ACTIVE', 'f5800000-0000-0000-0000-000000000001'),
('f5810000-0000-0000-0000-000000000002', 'P58 Other', 'P58 Other', 'ACTIVE', 'f5800000-0000-0000-0000-000000000003');
insert into public.organization_memberships(id, organization_id, user_id, status, activated_at) values
('f5820000-0000-0000-0000-000000000001', 'f5810000-0000-0000-0000-000000000001', 'f5800000-0000-0000-0000-000000000002', 'ACTIVE', now()),
('f5820000-0000-0000-0000-000000000002', 'f5810000-0000-0000-0000-000000000002', 'f5800000-0000-0000-0000-000000000003', 'ACTIVE', now());
insert into public.catalog_libraries(id, code, slug, steward_organization_id, status, created_by) values
('f5830000-0000-0000-0000-000000000001', 'P58_LIB', 'p58-lib', 'f5810000-0000-0000-0000-000000000001', 'DRAFT', 'f5800000-0000-0000-0000-000000000001');
insert into public.catalog_categories(id, library_id, code, slug, status, created_by) values
('f5840000-0000-0000-0000-000000000001', 'f5830000-0000-0000-0000-000000000001', 'P58_CAT', 'p58-cat', 'DRAFT', 'f5800000-0000-0000-0000-000000000001');
insert into public.catalog_subcategories(id, library_id, category_id, code, slug, status, created_by) values
('f5850000-0000-0000-0000-000000000001', 'f5830000-0000-0000-0000-000000000001', 'f5840000-0000-0000-0000-000000000001', 'P58_SUB', 'p58-sub', 'DRAFT', 'f5800000-0000-0000-0000-000000000001');
insert into public.catalog_library_mandates(library_id, organization_id, status, valid_from, policy_version, created_by) values
('f5830000-0000-0000-0000-000000000001', 'f5810000-0000-0000-0000-000000000001', 'ACTIVE', now(), 1, 'f5800000-0000-0000-0000-000000000001');
insert into public.organization_member_roles(membership_id, role_code, library_id) values
('f5820000-0000-0000-0000-000000000001', 'FRANCHISE_OWNER', 'f5830000-0000-0000-0000-000000000001'),
('f5820000-0000-0000-0000-000000000002', 'FRANCHISE_OWNER', null);

create temporary table p58_observed(key text primary key, value jsonb);
grant select, insert, update on p58_observed to authenticated;
grant usage on schema extensions to authenticated;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"f5800000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}', true);
select extensions.throws_ok(
  $$select public.submit_franchise_catalog_service('f5890000-0000-0000-0000-000000000001','f5890000-0000-0000-0000-000000000002',1,1,'p58-unknown')$$,
  '42501',
  'CATALOG_SCOPE_DENIED',
  'unknown service is hidden before disclosure'
);
insert into p58_observed values (
  'created',
  public.create_catalog_service(
    'f5830000-0000-0000-0000-000000000001',
    'f5850000-0000-0000-0000-000000000001',
    'P58_SERVICE',
    'p58-service',
    'Service franchisé',
    'خدمة الامتياز',
    'Description courte',
    'وصف قصير',
    'Description française complète',
    'وصف عربي كامل',
    'ADVISORY',
    'unité',
    'وحدة',
    false, false, false, false, true, false,
    'MAD',
    1,
    '{"schema_version":1}',
    '{"schema_version":1}',
    false,
    'Création du service',
    'p58-create'
  )
);
insert into p58_observed values (
  'submitted',
  public.submit_franchise_catalog_service(
    (select (value->>'service_id')::uuid from p58_observed where key = 'created'),
    (select (value->>'version_id')::uuid from p58_observed where key = 'created'),
    1,
    1,
    'p58-submit'
  )
);
insert into p58_observed values (
  'submitted-replay',
  public.submit_franchise_catalog_service(
    (select (value->>'service_id')::uuid from p58_observed where key = 'created'),
    (select (value->>'version_id')::uuid from p58_observed where key = 'created'),
    1,
    1,
    'p58-submit'
  )
);
select set_config('request.jwt.claims', '{"sub":"f5800000-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2"}', true);
select extensions.throws_ok(
  format(
    $sql$select public.submit_franchise_catalog_service(%L::uuid,%L::uuid,1,1,'p58-cross')$sql$,
    (select value->>'service_id' from p58_observed where key = 'created'),
    (select value->>'version_id' from p58_observed where key = 'created')
  ),
  '42501',
  'CATALOG_SCOPE_DENIED',
  'outsider cannot submit another library service'
);
reset role;

select is((select value->>'outcome' from p58_observed where key = 'submitted'), 'CATALOG_CHANGE_SUBMITTED', 'mandated editor submits a service draft');
select is((select value from p58_observed where key = 'submitted-replay'), (select value from p58_observed where key = 'submitted'), 'submit replay returns the original DTO');
select ok(
  (
    select s.status = 'IN_REVIEW' and v.status = 'IN_REVIEW'
    from public.catalog_services s
    join public.catalog_service_versions v on v.id = s.current_draft_version_id
    where s.id = (select (value->>'service_id')::uuid from p58_observed where key = 'created')
  ),
  'submit moves identity and version to IN_REVIEW'
);
select ok(
  (
    select count(*) = 1
    from public.catalog_change_requests
    where target_type = 'SERVICE'
      and target_id = (select (value->>'service_id')::uuid from p58_observed where key = 'created')
      and status = 'IN_REVIEW'
  ),
  'submit opens one SERVICE change request'
);
select ok(
  (
    select count(*) = 1 from public.audit_events
    where action = 'catalog.change.submitted'
      and resource_id = (select value->>'change_request_id' from p58_observed where key = 'submitted')
  ) and (
    select count(*) = 1 and bool_and(event_type = 'CatalogChangeSubmittedV1')
    from public.event_outbox
    where aggregate_id = (select value->>'change_request_id' from p58_observed where key = 'submitted')
  ),
  'submit emits one audit and one outbox event'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"f5800000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}', true);
select extensions.throws_ok(
  format(
    $sql$select public.decide_catalog_change(%L::uuid,'APPROVE','Auto approbation interdite',1,'p58-self')$sql$,
    (select value->>'change_request_id' from p58_observed where key = 'submitted')
  ),
  '42501',
  'CATALOG_APPROVAL_DENIED',
  'submitter cannot approve their own service change'
);
select set_config('request.jwt.claims', '{"sub":"f5800000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}', true);
insert into p58_observed values (
  'decided',
  public.decide_catalog_change(
    (select (value->>'change_request_id')::uuid from p58_observed where key = 'submitted'),
    'APPROVE',
    'Validation Matricia du service',
    1,
    'p58-decide'
  )
);
reset role;

select is((select value->>'outcome' from p58_observed where key = 'decided'), 'CATALOG_CHANGE_APPROVED', 'central reviewer approves a SERVICE change');
select ok(
  (
    select s.status = 'APPROVED' and v.status = 'APPROVED'
    from public.catalog_services s
    join public.catalog_service_versions v on v.id = s.current_draft_version_id
    where s.id = (select (value->>'service_id')::uuid from p58_observed where key = 'created')
  ),
  'SERVICE approval writes APPROVED without mutating published history'
);
select ok(
  (
    select status = 'APPROVED'
    from public.catalog_change_requests
    where id = (select (value->>'change_request_id')::uuid from p58_observed where key = 'submitted')
  ),
  'change request is closed as APPROVED'
);

select * from finish();
rollback;
