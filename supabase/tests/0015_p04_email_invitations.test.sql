begin;
set local search_path = public, extensions;
select plan(20);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
('a1500000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p04-email-owner@example.invalid','',now(),'{}','{}',now(),now()),
('a1500000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p04-email-outsider@example.invalid','',now(),'{}','{}',now(),now());

insert into public.organizations (id, legal_name, display_name, status, created_by)
values ('a1510000-0000-0000-0000-000000000001','P04 Email SARL','P04 Email','ACTIVE','a1500000-0000-0000-0000-000000000001');

insert into public.organization_memberships (
  id, organization_id, user_id, status, activated_at
) values (
  'a1520000-0000-0000-0000-000000000001',
  'a1510000-0000-0000-0000-000000000001',
  'a1500000-0000-0000-0000-000000000001',
  'ACTIVE', now()
);
insert into public.organization_member_roles (membership_id, role_code)
values ('a1520000-0000-0000-0000-000000000001','CLIENT_ADMIN');

create temporary table p04_email_observed (
  key text primary key,
  value jsonb not null
);
grant select, insert on p04_email_observed to authenticated;

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','a1500000-0000-0000-0000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"a1500000-0000-0000-0000-000000000001","email":"p04-email-owner@example.invalid","role":"authenticated"}',true);
    select public.invite_organization_member_by_email(
      'a1510000-0000-0000-0000-000000000001',
      'P04-EMAIL-OWNER@EXAMPLE.INVALID', array['CLIENT_MEMBER'],
      clock_timestamp() + interval '2 days', 'p04-email-self-key'
    )$$,
  '42501', 'SELF_INVITATION_FORBIDDEN',
  'an administrator cannot invite their own verified email'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','a1500000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"a1500000-0000-0000-0000-000000000001","email":"p04-email-owner@example.invalid","role":"authenticated"}',true);
insert into p04_email_observed values (
  'first',
  public.invite_organization_member_by_email(
    'a1510000-0000-0000-0000-000000000001',
    '  FUTURE.USER@EXAMPLE.INVALID  ', array['CLIENT_MEMBER','CLIENT_VIEWER'],
    transaction_timestamp() + interval '7 days', 'p04-email-future-key'
  )
);
insert into p04_email_observed values (
  'retry',
  public.invite_organization_member_by_email(
    'a1510000-0000-0000-0000-000000000001',
    'future.user@example.invalid', array['CLIENT_MEMBER','CLIENT_VIEWER'],
    transaction_timestamp() + interval '7 days', 'p04-email-future-key'
  )
);
reset role;

select is(
  (select value from p04_email_observed where key='retry'),
  (select value from p04_email_observed where key='first'),
  'an exact retry returns the stored response'
);
select is(
  (select count(*) from public.organization_invitations
   where organization_id='a1510000-0000-0000-0000-000000000001' and status='PENDING'),
  1::bigint,
  'an exact retry creates one pending invitation'
);
select is(
  (select invited_email from public.organization_invitations
   where id=(select (value->>'invitation_id')::uuid from p04_email_observed where key='first')),
  'future.user@example.invalid',
  'the invitation stores a normalized email'
);
select is(
  (select invited_user_id from public.organization_invitations
   where id=(select (value->>'invitation_id')::uuid from p04_email_observed where key='first')),
  null::uuid,
  'an invitation remains active before the auth account exists'
);
select is(
  (select count(*) from public.audit_events
   where action='organization.invitation.created'
     and resource_id=(select value->>'invitation_id' from p04_email_observed where key='first')),
  1::bigint,
  'the email invitation is audited once despite retry'
);
select is(
  (select count(*) from public.event_outbox
   where event_type='OrganizationEmailInvitationRequestedV1'
     and aggregate_id=(select value->>'invitation_id' from p04_email_observed where key='first')),
  1::bigint,
  'the email invitation emits one durable Outbox event'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','a1500000-0000-0000-0000-000000000001',true);
    select set_config('request.jwt.claims','{"sub":"a1500000-0000-0000-0000-000000000001","email":"p04-email-owner@example.invalid","role":"authenticated"}',true);
    select public.invite_organization_member_by_email(
      'a1510000-0000-0000-0000-000000000001',
      'different@example.invalid', array['CLIENT_MEMBER'],
      transaction_timestamp() + interval '7 days', 'p04-email-future-key'
    )$$,
  '22000', 'IDEMPOTENCY_PAYLOAD_MISMATCH',
  'an idempotency key cannot be reused with another recipient'
);
reset role;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  'a1500000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','future.user@example.invalid','',now(),'{}','{}',now(),now()
);

set local role authenticated;
select set_config('request.jwt.claim.sub','a1500000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"a1500000-0000-0000-0000-000000000003","email":"p04-email-outsider@example.invalid","role":"authenticated"}',true);
insert into p04_email_observed values (
  'outsider_count',
  jsonb_build_object('count',(select count(*) from public.organization_invitations))
);
reset role;
select is(
  (select (value->>'count')::bigint from p04_email_observed where key='outsider_count'),
  0::bigint,
  'RLS hides email invitations from unrelated users'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','a1500000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"a1500000-0000-0000-0000-000000000002","email":"future.user@example.invalid","role":"authenticated"}',true);
insert into p04_email_observed values (
  'invitee_count',
  jsonb_build_object('count',(select count(*) from public.organization_invitations))
);
insert into p04_email_observed values (
  'invitee_roles',
  jsonb_build_object('count',(select count(*) from public.organization_invitation_roles))
);
insert into p04_email_observed values (
  'membership_id',
  to_jsonb(public.accept_organization_invitation(
    (select (value->>'invitation_id')::uuid from p04_email_observed where key='first')
  ))
);
reset role;

select is((select (value->>'count')::bigint from p04_email_observed where key='invitee_count'),1::bigint,'the verified recipient email can read its invitation');
select is((select (value->>'count')::bigint from p04_email_observed where key='invitee_roles'),2::bigint,'the recipient can read the proposed roles');
select ok((select value is not null from p04_email_observed where key='membership_id'),'acceptance returns a membership id');
select is((select status from public.organization_invitations where id=(select (value->>'invitation_id')::uuid from p04_email_observed where key='first')),'ACCEPTED','acceptance closes the invitation');
select is((select invited_user_id from public.organization_invitations where id=(select (value->>'invitation_id')::uuid from p04_email_observed where key='first')),'a1500000-0000-0000-0000-000000000002'::uuid,'acceptance binds the invitation to the authenticated user');
select is((select count(*) from public.organization_memberships where organization_id='a1510000-0000-0000-0000-000000000001' and user_id='a1500000-0000-0000-0000-000000000002'),1::bigint,'acceptance creates one membership');
select is((select count(*) from public.organization_member_roles where membership_id=(select (value #>> '{}')::uuid from p04_email_observed where key='membership_id') and revoked_at is null),2::bigint,'acceptance grants every invited role');
select is((select count(*) from public.audit_events where action='organization.invitation.accepted' and resource_id=(select value->>'invitation_id' from p04_email_observed where key='first')),1::bigint,'acceptance is audited once');
select ok(not has_function_privilege('anon','public.invite_organization_member_by_email(uuid,text,text[],timestamptz,text,uuid)','EXECUTE'),'anonymous actors cannot create email invitations');
select ok(has_function_privilege('authenticated','public.invite_organization_member_by_email(uuid,text,text[],timestamptz,text,uuid)','EXECUTE'),'authenticated actors have the explicit email invitation RPC');
select is((select count(*) from public.organization_invitations where organization_id='a1510000-0000-0000-0000-000000000001' and status='PENDING'),0::bigint,'acceptance removes the invitation from the pending queue');

select * from finish();
rollback;
