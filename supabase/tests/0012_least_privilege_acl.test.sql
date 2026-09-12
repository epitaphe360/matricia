begin;
set local search_path=public,extensions;
select plan(8);

select ok(not exists(
  select 1 from unnest(array['anon','authenticated','service_role']) role_name,
    unnest(array['idempotency_keys','financial_accounts','financial_journals','financial_entries','credit_wallets','credit_ledger_entries']) table_name
  where has_table_privilege(role_name,'public.'||table_name,'TRUNCATE')
),'runtime roles cannot truncate immutable or idempotency tables');

select ok(not exists(
  select 1 from unnest(array['anon','authenticated','service_role']) role_name,
    unnest(array['financial_accounts','financial_journals','financial_entries','credit_wallets','credit_ledger_entries','audit_events','event_outbox']) table_name,
    unnest(array['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) privilege_name
  where has_table_privilege(role_name,'public.'||table_name,privilege_name)
),'runtime roles hold no mutation or DDL-like privilege on protected records');

select ok(not has_table_privilege('anon','public.organizations','SELECT'),'anonymous role has no organization table access');
select ok(has_table_privilege('authenticated','public.organizations','SELECT'),'authenticated reads organizations only through RLS');
select ok(has_column_privilege('authenticated','public.user_profiles','display_name','UPDATE'),'authenticated may update the explicitly allowed profile column');
select ok(not has_table_privilege('authenticated','public.user_profiles','UPDATE'),'authenticated has no whole-row profile update privilege');
select ok(not has_table_privilege('service_role','public.organization_audit_activity','SELECT'),'service role cannot query tenant audit view directly');

create temporary table readiness_acl_observed(before_ok boolean,after_ok boolean);
grant select,insert,update on readiness_acl_observed to service_role;
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
insert into readiness_acl_observed(before_ok) select database_ok and outbox_ok from public.readiness_status();
reset role;

insert into public.event_outbox(aggregate_type,aggregate_id,event_type,correlation_id,payload,occurred_at,dead_lettered_at)
values('acl_test','old-dead-letter','AclTestV1',extensions.gen_random_uuid(),'{}',statement_timestamp()-interval '30 days',statement_timestamp());
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
update readiness_acl_observed set after_ok=(select database_ok and outbox_ok from public.readiness_status());
reset role;
select is((select after_ok from readiness_acl_observed),(select before_ok from readiness_acl_observed),'dead-lettered events do not degrade readiness');

select * from finish();
rollback;
