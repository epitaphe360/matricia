begin;
set local search_path = public, extensions;
select plan(24);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
('a1300000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p04-role-owner@example.invalid','',now(),'{}','{}',now(),now()),
('a1300000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p04-role-tenant-approver@example.invalid','',now(),'{}','{}',now(),now()),
('a1300000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p04-role-compliance@example.invalid','',now(),'{}','{}',now(),now()),
('a1300000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p04-role-outsider@example.invalid','',now(),'{}','{}',now(),now());

insert into public.organizations (id, legal_name, display_name, status, created_by) values
('a1310000-0000-0000-0000-000000000001','P04 Multi Role SARL','P04 Multi Role','ACTIVE','a1300000-0000-0000-0000-000000000001'),
('a1310000-0000-0000-0000-000000000002','P04 Autre Tenant SARL','P04 Autre Tenant','ACTIVE','a1300000-0000-0000-0000-000000000004');

insert into public.organization_memberships (
  id, organization_id, user_id, status, activated_at
) values
('a1320000-0000-0000-0000-000000000001','a1310000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','ACTIVE',now()),
('a1320000-0000-0000-0000-000000000002','a1310000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000002','ACTIVE',now()),
('a1320000-0000-0000-0000-000000000004','a1310000-0000-0000-0000-000000000002','a1300000-0000-0000-0000-000000000004','ACTIVE',now());

insert into public.organization_member_roles (membership_id, role_code) values
('a1320000-0000-0000-0000-000000000001','CLIENT_OWNER'),
('a1320000-0000-0000-0000-000000000002','CLIENT_ADMIN'),
('a1320000-0000-0000-0000-000000000004','CLIENT_OWNER');

insert into public.platform_user_roles (user_id, role_code) values
('a1300000-0000-0000-0000-000000000003','COMPLIANCE_MANAGER');

create temporary table p04_role_observed (
  key text primary key,
  value jsonb not null
);
grant select, insert on p04_role_observed to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','a1300000-0000-0000-0000-000000000001',true);
insert into p04_role_observed values (
  'first',
  public.request_additional_organization_role(
    'a1310000-0000-0000-0000-000000000001',
    'PROVIDER_OWNER',
    'p04-role-provider-owner-key'
  )
);
insert into p04_role_observed values (
  'retry',
  public.request_additional_organization_role(
    'a1310000-0000-0000-0000-000000000001',
    'PROVIDER_OWNER',
    'p04-role-provider-owner-key'
  )
);
insert into p04_role_observed values (
  'duplicate-key',
  public.request_additional_organization_role(
    'a1310000-0000-0000-0000-000000000001',
    'PROVIDER_OWNER',
    'p04-role-provider-owner-other-key'
  )
);
reset role;

select is(
  (select value->>'outcome' from p04_role_observed where key = 'first'),
  'ROLE_REQUESTED',
  'an active member can explicitly request an additional role'
);
select is(
  (select value from p04_role_observed where key = 'retry'),
  (select value from p04_role_observed where key = 'first'),
  'an exact retry returns the stored idempotent response'
);
select is(
  (select value->>'outcome' from p04_role_observed where key = 'duplicate-key'),
  'ROLE_REQUEST_ALREADY_PENDING',
  'a second key does not duplicate the pending business request'
);
select is(
  (select count(*) from public.organization_access_requests
   where organization_id = 'a1310000-0000-0000-0000-000000000001'
     and requester_user_id = 'a1300000-0000-0000-0000-000000000001'
     and requested_role_code = 'PROVIDER_OWNER'
     and status = 'PENDING'),
  1::bigint,
  'only one pending request exists for the actor, organization and role'
);
select ok(
  (select requires_central_approval from public.organization_access_requests
   where id = (select (value->>'request_id')::uuid from p04_role_observed where key = 'first')),
  'a cross-domain OWNER request is marked for central compliance approval'
);
select is(
  (select count(*) from public.organization_member_roles
   where membership_id = 'a1320000-0000-0000-0000-000000000001'
     and role_code = 'PROVIDER_OWNER' and revoked_at is null),
  0::bigint,
  'requesting a role never auto-escalates the membership'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','a1300000-0000-0000-0000-000000000001',true);
    select public.decide_organization_access_request(
      (select (value->>'request_id')::uuid from p04_role_observed where key = 'first'), true
    )$$,
  '42501', 'SELF_APPROVAL_FORBIDDEN',
  'an organization owner cannot approve their own role request'
);
reset role;

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','a1300000-0000-0000-0000-000000000002',true);
    select public.decide_organization_access_request(
      (select (value->>'request_id')::uuid from p04_role_observed where key = 'first'), true
    )$$,
  '42501', 'CENTRAL_COMPLIANCE_APPROVAL_REQUIRED',
  'a tenant administrator cannot approve a cross-domain OWNER role'
);
reset role;

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','a1300000-0000-0000-0000-000000000004',true);
    select public.decide_organization_access_request(
      (select (value->>'request_id')::uuid from p04_role_observed where key = 'first'), true
    )$$,
  '42501', 'FORBIDDEN',
  'a cross-tenant owner cannot decide another tenant cross-domain request'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','a1300000-0000-0000-0000-000000000004',true);
insert into p04_role_observed values (
  'outsider-visible',
  jsonb_build_object(
    'count', (
      select count(*) from public.organization_access_requests
      where organization_id = 'a1310000-0000-0000-0000-000000000001'
    )
  )
);
reset role;
select is(
  (select (value->>'count')::bigint from p04_role_observed where key = 'outsider-visible'),
  0::bigint,
  'RLS hides another tenant role requests'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','a1300000-0000-0000-0000-000000000001',true);
    select public.request_additional_organization_role(
      'a1310000-0000-0000-0000-000000000001',
      'SUPER_ADMIN',
      'p04-role-platform-forbidden-key'
    )$$,
  '42501', 'PLATFORM_ROLE_FORBIDDEN',
  'an organization owner cannot request a platform-scoped role'
);
reset role;

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','a1300000-0000-0000-0000-000000000001',true);
    select public.request_additional_organization_role(
      'a1310000-0000-0000-0000-000000000001',
      'FRANCHISE_OWNER',
      'p04-role-provider-owner-key'
    )$$,
  '22000', 'IDEMPOTENCY_PAYLOAD_MISMATCH',
  'an idempotency key cannot be reused with a different role payload'
);
reset role;

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','a1300000-0000-0000-0000-000000000004',true);
    select public.request_additional_organization_role(
      'a1310000-0000-0000-0000-000000000001',
      'PROVIDER_VIEWER',
      'p04-role-cross-tenant-request-key'
    )$$,
  '42501', 'ACTIVE_MEMBERSHIP_REQUIRED',
  'a user cannot request a role in another tenant'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','a1300000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"a1300000-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2"}',true);
select public.decide_organization_access_request(
  (select (value->>'request_id')::uuid from p04_role_observed where key = 'first'), true
);
reset role;

select is(
  (select status from public.organization_access_requests
   where id = (select (value->>'request_id')::uuid from p04_role_observed where key = 'first')),
  'APPROVED',
  'central compliance can approve a cross-domain OWNER request'
);
select is(
  (select decided_by from public.organization_access_requests
   where id = (select (value->>'request_id')::uuid from p04_role_observed where key = 'first')),
  'a1300000-0000-0000-0000-000000000003'::uuid,
  'the central compliance decision records its actor'
);
select is(
  (select count(*) from public.organization_memberships
   where organization_id = 'a1310000-0000-0000-0000-000000000001'
     and user_id = 'a1300000-0000-0000-0000-000000000001'),
  1::bigint,
  'approval reuses the unique existing membership'
);
select is(
  (select count(*) from public.organization_member_roles
   where membership_id = 'a1320000-0000-0000-0000-000000000001'
     and revoked_at is null),
  2::bigint,
  'approval accumulates Client and Provider roles on one membership'
);
select ok(
  exists (
    select 1 from public.organization_member_roles
    where membership_id = 'a1320000-0000-0000-0000-000000000001'
      and role_code = 'CLIENT_OWNER' and revoked_at is null
  ) and exists (
    select 1 from public.organization_member_roles
    where membership_id = 'a1320000-0000-0000-0000-000000000001'
      and role_code = 'PROVIDER_OWNER' and revoked_at is null
  ),
  'the organization passport now exposes both cumulative domains'
);
select is(
  (select count(*) from public.audit_events
   where action = 'organization.role.requested'
     and resource_id = (select value->>'request_id' from p04_role_observed where key = 'first')),
  1::bigint,
  'the business request emits one immutable audit event despite retries'
);
select is(
  (select count(*) from public.event_outbox
   where event_type = 'OrganizationRoleRequestedV1'
     and aggregate_id = (select value->>'request_id' from p04_role_observed where key = 'first')),
  1::bigint,
  'the business request emits one durable Outbox event despite retries'
);
select is(
  (select count(*) from public.audit_events
   where action = 'organization.access.decided'
     and resource_id = (select value->>'request_id' from p04_role_observed where key = 'first')),
  1::bigint,
  'the approval is audited exactly once'
);
select is(
  (select count(*) from public.event_outbox
   where event_type = 'OrganizationAccessDecidedV1'
     and aggregate_id = (select value->>'request_id' from p04_role_observed where key = 'first')),
  1::bigint,
  'the approval emits one durable decision event'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.request_additional_organization_role(uuid,text,text,uuid)',
    'EXECUTE'
  ),
  'anonymous actors cannot call the role request RPC'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.request_additional_organization_role(uuid,text,text,uuid)',
    'EXECUTE'
  ),
  'authenticated actors have only the explicit role request RPC'
);

select * from finish();
rollback;
