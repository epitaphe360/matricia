begin;
set local search_path = public, extensions;
select plan(16);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
('a1400000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p04-decline-inviter@example.invalid','',now(),'{}','{}',now(),now()),
('a1400000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p04-decline-invitee@example.invalid','',now(),'{}','{}',now(),now()),
('a1400000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p04-decline-outsider@example.invalid','',now(),'{}','{}',now(),now());

insert into public.organizations (id, legal_name, display_name, status, created_by)
values ('a1410000-0000-0000-0000-000000000001','P04 Decline SARL','P04 Decline','ACTIVE','a1400000-0000-0000-0000-000000000001');

insert into public.organization_memberships (
  id, organization_id, user_id, status, activated_at
) values (
  'a1420000-0000-0000-0000-000000000001',
  'a1410000-0000-0000-0000-000000000001',
  'a1400000-0000-0000-0000-000000000001',
  'ACTIVE', now()
);

insert into public.organization_member_roles (membership_id, role_code)
values ('a1420000-0000-0000-0000-000000000001','CLIENT_ADMIN');

create temporary table p04_decline_observed (
  key text primary key,
  value text not null
);
grant select, insert on p04_decline_observed to authenticated;

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','a1400000-0000-0000-0000-000000000001',true);
    select public.invite_organization_member(
      'a1410000-0000-0000-0000-000000000001',
      'a1400000-0000-0000-0000-000000000001',
      array['CLIENT_VIEWER'],
      clock_timestamp() + interval '2 days'
    )$$,
  '42501', 'SELF_INVITATION_FORBIDDEN',
  'an administrator cannot invite themselves'
);
reset role;
select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','a1400000-0000-0000-0000-000000000001',true);
    select public.invite_organization_member(
      'a1410000-0000-0000-0000-000000000001',
      'a1400000-0000-0000-0000-000000000002',
      array['PROVIDER_OWNER'],
      clock_timestamp() + interval '2 days'
    )$$,
  '42501', 'CROSS_DOMAIN_OWNER_INVITATION_FORBIDDEN',
  'a tenant administrator cannot grant a cross-domain OWNER role by invitation'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','a1400000-0000-0000-0000-000000000001',true);
insert into p04_decline_observed values (
  'invitation_id',
  public.invite_organization_member(
    'a1410000-0000-0000-0000-000000000001',
    'a1400000-0000-0000-0000-000000000002',
    array['CLIENT_VIEWER'],
    clock_timestamp() + interval '2 days'
  )::text
);
reset role;

select is(
  (select status from public.organization_invitations
   where id = (select value::uuid from p04_decline_observed where key = 'invitation_id')),
  'PENDING',
  'the invitation starts pending'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','a1400000-0000-0000-0000-000000000003',true);
    select public.decline_organization_invitation(
      (select value::uuid from p04_decline_observed where key = 'invitation_id')
    )$$,
  'P0002', 'INVITATION_NOT_FOUND',
  'an unrelated user receives a neutral not-found response'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','a1400000-0000-0000-0000-000000000003',true);
insert into p04_decline_observed values (
  'outsider_visible',
  (select count(*)::text from public.organization_invitations
   where organization_id = 'a1410000-0000-0000-0000-000000000001')
);
reset role;

select is(
  (select value::bigint from p04_decline_observed where key = 'outsider_visible'),
  0::bigint,
  'RLS hides the invitation from an unrelated user'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','a1400000-0000-0000-0000-000000000002',true);
insert into p04_decline_observed values (
  'first_decline',
  public.decline_organization_invitation(
    (select value::uuid from p04_decline_observed where key = 'invitation_id')
  )::text
);
insert into p04_decline_observed values (
  'retry_decline',
  public.decline_organization_invitation(
    (select value::uuid from p04_decline_observed where key = 'invitation_id')
  )::text
);
reset role;

select is(
  (select value::boolean from p04_decline_observed where key = 'first_decline'),
  true,
  'the invited user can decline the invitation'
);
select is(
  (select value::boolean from p04_decline_observed where key = 'retry_decline'),
  false,
  'an exact decline retry is an idempotent no-op'
);
select is(
  (select status from public.organization_invitations
   where id = (select value::uuid from p04_decline_observed where key = 'invitation_id')),
  'DECLINED',
  'the invitation records an explicit declined state'
);
select is(
  (select accepted_at from public.organization_invitations
   where id = (select value::uuid from p04_decline_observed where key = 'invitation_id')),
  null::timestamptz,
  'declining never records an acceptance timestamp'
);
select is(
  (select row_version from public.organization_invitations
   where id = (select value::uuid from p04_decline_observed where key = 'invitation_id')),
  2,
  'declining advances the optimistic row version exactly once'
);
select is(
  (select count(*) from public.organization_memberships
   where organization_id = 'a1410000-0000-0000-0000-000000000001'
     and user_id = 'a1400000-0000-0000-0000-000000000002'),
  0::bigint,
  'declining never creates a membership'
);
select is(
  (select count(*) from public.audit_events
   where action = 'organization.invitation.declined'
     and resource_id = (select value from p04_decline_observed where key = 'invitation_id')),
  1::bigint,
  'decline emits one immutable audit event despite retry'
);
select is(
  (select count(*) from public.event_outbox
   where event_type = 'OrganizationInvitationDeclinedV1'
     and aggregate_id = (select value from p04_decline_observed where key = 'invitation_id')),
  1::bigint,
  'decline emits one durable Outbox event despite retry'
);
select ok(
  not has_function_privilege(
    'anon', 'public.decline_organization_invitation(uuid,uuid)', 'EXECUTE'
  ),
  'anonymous actors cannot decline invitations'
);
select ok(
  has_function_privilege(
    'authenticated', 'public.decline_organization_invitation(uuid,uuid)', 'EXECUTE'
  ),
  'authenticated actors have only the explicit decline RPC'
);
select is(
  (select count(*) from public.organization_invitation_roles
   where invitation_id = (select value::uuid from p04_decline_observed where key = 'invitation_id')),
  1::bigint,
  'declining preserves the immutable invitation role evidence'
);

select * from finish();
rollback;
