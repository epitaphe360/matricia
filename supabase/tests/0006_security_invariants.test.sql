begin;
set local search_path = public, extensions;
select plan(13);

insert into auth.users (
  id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values (
  '60000000-0000-0000-0000-000000000006',
  '00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','invariants@example.invalid','',now(),'{}','{}',now(),now()
);
insert into public.organizations (id,legal_name,display_name,status,created_by)
values (
  'e0000000-0000-0000-0000-000000000006',
  'Invariant SARL','Invariant','ACTIVE',
  '60000000-0000-0000-0000-000000000006'
);
insert into public.organization_memberships (id,organization_id,user_id,status,activated_at)
values (
  'e1000000-0000-0000-0000-000000000006',
  'e0000000-0000-0000-0000-000000000006',
  '60000000-0000-0000-0000-000000000006','ACTIVE',now()
);
insert into public.organization_member_roles (membership_id,role_code)
values ('e1000000-0000-0000-0000-000000000006','CLIENT_ACCOUNTING');

insert into public.financial_accounts (id,organization_id,code,name,account_type,currency) values
('e2000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000006','MAD-CASH','MAD Cash','ASSET','MAD'),
('e2000000-0000-0000-0000-000000000002','e0000000-0000-0000-0000-000000000006','MAD-REV','MAD Revenue','REVENUE','MAD'),
('e2000000-0000-0000-0000-000000000003','e0000000-0000-0000-0000-000000000006','EUR-CASH','EUR Cash','ASSET','EUR');
insert into public.financial_journals (
  id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,
  correlation_id,effective_at,description,created_by
) values (
  'e3000000-0000-0000-0000-000000000006',
  'e0000000-0000-0000-0000-000000000006',
  'TEST','MAD','invariant.test','valid-journal-key',
  'e4000000-0000-0000-0000-000000000006',now(),'Valid journal',
  '60000000-0000-0000-0000-000000000006'
);
insert into public.financial_entries (
  organization_id,journal_id,account_id,direction,amount_minor,currency
) values
('e0000000-0000-0000-0000-000000000006','e3000000-0000-0000-0000-000000000006','e2000000-0000-0000-0000-000000000001','DEBIT',100,'MAD'),
('e0000000-0000-0000-0000-000000000006','e3000000-0000-0000-0000-000000000006','e2000000-0000-0000-0000-000000000002','CREDIT',100,'MAD');
set constraints financial_journal_balanced, financial_journal_not_empty immediate;
set constraints all deferred;

insert into public.credit_wallets (id,organization_id,wallet_type)
values (
  'e5000000-0000-0000-0000-000000000006',
  'e0000000-0000-0000-0000-000000000006','CLIENT'
);

select throws_ok(
  $$insert into public.financial_entries (organization_id,journal_id,account_id,direction,amount_minor,currency)
    values ('e0000000-0000-0000-0000-000000000006','e3000000-0000-0000-0000-000000000006','e2000000-0000-0000-0000-000000000003','DEBIT',1,'MAD')$$,
  '23503',null,'an account currency mismatch is rejected by a composite foreign key'
);
select throws_ok(
  $$insert into public.financial_entries (organization_id,journal_id,account_id,direction,amount_minor,currency)
    values ('e0000000-0000-0000-0000-000000000006','e3000000-0000-0000-0000-000000000006','e2000000-0000-0000-0000-000000000003','DEBIT',1,'EUR')$$,
  '23503',null,'a journal currency mismatch is rejected by a composite foreign key'
);
select throws_ok(
  $$insert into public.credit_ledger_entries (
      organization_id,wallet_id,entry_type,quantity,idempotency_scope,idempotency_key,
      correlation_id,reference_type,reference_id,created_by
    ) values (
      'e0000000-0000-0000-0000-000000000006','e5000000-0000-0000-0000-000000000006',
      'GRANT',-1,'invariant.test','bad-sign-key',
      'e6000000-0000-0000-0000-000000000001','TEST','bad-sign',
      '60000000-0000-0000-0000-000000000006'
    )$$,
  '23514',null,'an invalid credit sign is rejected at table level'
);

create function pg_temp.attempt_negative_credit() returns void
language plpgsql as $function$
begin
  insert into public.credit_ledger_entries (
    organization_id,wallet_id,entry_type,quantity,idempotency_scope,idempotency_key,
    correlation_id,reference_type,reference_id,created_by
  ) values (
    'e0000000-0000-0000-0000-000000000006','e5000000-0000-0000-0000-000000000006',
    'CONSUME',-1,'invariant.test','negative-balance-key',
    'e6000000-0000-0000-0000-000000000002','TEST','negative-balance',
    '60000000-0000-0000-0000-000000000006'
  );
  set constraints credit_wallet_nonnegative immediate;
end;
$function$;
select throws_ok(
  $$select pg_temp.attempt_negative_credit()$$,
  '23514','NEGATIVE_CREDIT_BALANCE','a direct ledger insert cannot create a negative credit balance'
);

create function pg_temp.attempt_empty_journal() returns void
language plpgsql as $function$
begin
  insert into public.financial_journals (
    id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,
    correlation_id,effective_at,description,created_by
  ) values (
    'e3000000-0000-0000-0000-000000000007',
    'e0000000-0000-0000-0000-000000000006',
    'TEST','MAD','invariant.test','empty-journal-key',
    'e4000000-0000-0000-0000-000000000007',now(),'Empty journal',
    '60000000-0000-0000-0000-000000000006'
  );
  set constraints financial_journal_not_empty immediate;
end;
$function$;
select throws_ok(
  $$select pg_temp.attempt_empty_journal()$$,
  '23514','EMPTY_FINANCIAL_JOURNAL','a posted journal must contain entries'
);

select throws_ok(
  $$insert into public.event_outbox (
      aggregate_type,aggregate_id,event_type,correlation_id,payload,locked_at
    ) values (
      'test','bad-lock','TestEventV1','e7000000-0000-0000-0000-000000000001','{}',now()
    )$$,
  '23514',null,'an Outbox lock timestamp requires a worker identifier'
);
select throws_ok(
  $$insert into public.event_outbox (
      aggregate_type,aggregate_id,event_type,correlation_id,payload,published_at,dead_lettered_at
    ) values (
      'test','bad-terminal','TestEventV1','e7000000-0000-0000-0000-000000000002','{}',now(),now()
    )$$,
  '23514',null,'an Outbox event cannot be both published and dead-lettered'
);

insert into public.audit_events (
  organization_id,actor_user_id,actor_type,action,resource_type,resource_id,
  correlation_id,metadata,previous_hash,event_hash
) values (
  'e0000000-0000-0000-0000-000000000006',
  '60000000-0000-0000-0000-000000000006',
  'USER','security.test','organization','e0000000-0000-0000-0000-000000000006',
  'e8000000-0000-0000-0000-000000000006','{}',null,repeat('0',64)
);
create temporary table observed (key text primary key,value bigint);
grant insert,select on table observed to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000006',true);
insert into observed values
('raw_audit_count',(select count(*) from public.audit_events)),
('safe_audit_count',(select count(*) from public.organization_audit_activity));
reset role;

select is((select value from observed where key='raw_audit_count'),0::bigint,'ordinary organization members cannot read raw audit records');
select is((select value from observed where key='safe_audit_count'),1::bigint,'organization members can read the expurgated audit activity view');
select ok(not has_table_privilege('authenticated','public.event_outbox','SELECT'),'authenticated cannot read the Outbox table');
select ok(not has_table_privilege('service_role','public.financial_entries','INSERT'),'service role cannot bypass financial write RPCs');
select ok(not has_function_privilege('authenticated','private.canonical_request_hash(jsonb)','EXECUTE'),'authenticated cannot execute the canonical hash helper');
select ok(not has_column_privilege('authenticated','public.user_profiles','created_at','UPDATE'),'authenticated cannot rewrite profile creation timestamps');

select * from finish();
rollback;
