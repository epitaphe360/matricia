begin;
set local search_path = public, extensions;
select plan(9);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
('a1800000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p04-hard-owner@example.invalid','',now(),'{}','{}',now(),now()),
('a1800000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p04-hard-invitee@example.invalid','',now(),'{}','{}',now(),now()),
('a1800000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p04-hard-attacker@example.invalid','',now(),'{}','{}',now(),now()),
('a1800000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p04-hard-central@example.invalid','',now(),'{}','{}',now(),now());

insert into public.organizations (id, legal_name, display_name, status, created_by)
values ('a1810000-0000-0000-0000-000000000001','P04 Hardening SARL','P04 Hardening','ACTIVE','a1800000-0000-0000-0000-000000000001');
insert into public.organization_memberships (id, organization_id, user_id, status, activated_at)
values ('a1820000-0000-0000-0000-000000000001','a1810000-0000-0000-0000-000000000001','a1800000-0000-0000-0000-000000000001','ACTIVE',now());
insert into public.organization_member_roles (membership_id, role_code)
values ('a1820000-0000-0000-0000-000000000001','CLIENT_OWNER');

create temporary table p04_hard_observed (key text primary key, value text not null);
grant select, insert on p04_hard_observed to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','a1800000-0000-0000-0000-000000000001',true);
insert into p04_hard_observed values (
  'invitation_id',
  public.invite_organization_member_by_email(
    'a1810000-0000-0000-0000-000000000001',
    'p04-hard-invitee@example.invalid', array['CLIENT_VIEWER'],
    clock_timestamp() + interval '7 days', 'p04-hardening-invite-key'
  )->>'invitation_id'
);
reset role;

select is(
  (select invited_user_id from public.organization_invitations where id=(select value::uuid from p04_hard_observed where key='invitation_id')),
  null::uuid,
  'an email invitation never reveals whether the recipient already has an account'
);

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','a1800000-0000-0000-0000-000000000001',true);
    select public.invite_organization_member_by_email(
      'a1810000-0000-0000-0000-000000000001','future@example.invalid',array['CLIENT_VIEWER'],
      clock_timestamp() + interval '31 days','p04-too-long-key'
    )$$,
  '22023', 'INVITATION_EXPIRY_TOO_LONG',
  'an invitation cannot remain valid for more than 30 days'
);
reset role;

select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','a1800000-0000-0000-0000-000000000003',true);
    select set_config('request.jwt.claims','{"sub":"a1800000-0000-0000-0000-000000000003","email":"p04-hard-invitee@example.invalid","role":"authenticated"}',true);
    select public.accept_organization_invitation((select value::uuid from p04_hard_observed where key='invitation_id'))$$,
  '42501', 'INVITATION_RECIPIENT_MISMATCH',
  'acceptance validates the canonical confirmed auth email rather than JWT claims alone'
);
reset role;

update public.organization_member_roles
set revoked_at = clock_timestamp()
where membership_id = 'a1820000-0000-0000-0000-000000000001' and role_code = 'CLIENT_OWNER';
select throws_ok(
  $$set local role authenticated;
    select set_config('request.jwt.claim.sub','a1800000-0000-0000-0000-000000000002',true);
    select set_config('request.jwt.claims','{"sub":"a1800000-0000-0000-0000-000000000002","email":"p04-hard-invitee@example.invalid","role":"authenticated"}',true);
    select public.accept_organization_invitation((select value::uuid from p04_hard_observed where key='invitation_id'))$$,
  '42501', 'INVITATION_AUTHORITY_REVOKED',
  'acceptance revalidates the inviter current authority'
);
reset role;

select ok(
  not has_function_privilege('authenticated','public.invite_organization_member(uuid,uuid,text[],timestamptz,uuid)','EXECUTE'),
  'the account-enumerating UUID invitation endpoint is revoked'
);

insert into public.platform_user_roles (user_id, role_code)
values ('a1800000-0000-0000-0000-000000000004','MATRICIA_ADMIN');
select set_config('request.jwt.claim.sub','a1800000-0000-0000-0000-000000000004',true);
select set_config('request.jwt.claims','{"sub":"a1800000-0000-0000-0000-000000000004","role":"authenticated","aal":"aal1"}',true);
insert into p04_hard_observed values ('aal1_role',private.has_platform_role(array['MATRICIA_ADMIN'])::text);
select set_config('request.jwt.claims','{"sub":"a1800000-0000-0000-0000-000000000004","role":"authenticated","aal":"aal2"}',true);
insert into p04_hard_observed values ('aal2_role',private.has_platform_role(array['MATRICIA_ADMIN'])::text);
insert into p04_hard_observed values ('requirement',(select row_to_json(requirement)::text from public.get_my_account_security_requirement() requirement));

select is((select value::boolean from p04_hard_observed where key='aal1_role'),false,'AAL1 cannot exercise a central role requiring MFA');
select is((select value::boolean from p04_hard_observed where key='aal2_role'),true,'AAL2 can exercise an assigned central role');
select is((select value::jsonb->>'mfa_required' from p04_hard_observed where key='requirement'), 'true','the account policy reports MFA as required');
select is((select value::jsonb->>'requirement_satisfied' from p04_hard_observed where key='requirement'),'true','the account policy reports the AAL2 session as compliant');

select * from finish();
rollback;
