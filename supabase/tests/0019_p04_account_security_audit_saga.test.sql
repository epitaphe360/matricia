begin;
set local search_path = public, extensions;
select plan(8);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  'a1900000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','p04-saga@example.invalid','',now(),'{}','{}',now(),now()
);

select ok(not has_function_privilege('authenticated','public.begin_account_security_change(uuid,uuid,text,text,text)','EXECUTE'),'authenticated cannot forge security sagas');
select ok(not has_function_privilege('authenticated','public.complete_account_security_change(uuid)','EXECUTE'),'authenticated cannot complete security sagas');

create temporary table p04_saga_observed (key text primary key, value text not null);
grant select, insert on p04_saga_observed to service_role;
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
insert into p04_saga_observed values ('operation',public.begin_account_security_change(
  'a1910000-0000-0000-0000-000000000001','a1900000-0000-0000-0000-000000000001',
  'identity.password.change.requested','identity.password.updated','password-update'
)::text);
insert into p04_saga_observed values ('first_complete',public.complete_account_security_change('a1910000-0000-0000-0000-000000000001')::text);
insert into p04_saga_observed values ('retry_complete',public.complete_account_security_change('a1910000-0000-0000-0000-000000000001')::text);
reset role;

select is((select value::boolean from p04_saga_observed where key='first_complete'),true,'first completion records the Auth success');
select is((select value::boolean from p04_saga_observed where key='retry_complete'),false,'completion retry is idempotent');
select is((select status from private.account_security_change_operations where id='a1910000-0000-0000-0000-000000000001'),'COMPLETED','durable operation records completed reconciliation state');
select is((select count(*) from public.audit_events where correlation_id='a1910000-0000-0000-0000-000000000001'),2::bigint,'request and success are audited exactly once');
select is((select count(*) from public.event_outbox where correlation_id='a1910000-0000-0000-0000-000000000001'),2::bigint,'request and success emit durable Outbox events exactly once');
select is((select count(*) from public.audit_events where action='identity.password.updated' and correlation_id='a1910000-0000-0000-0000-000000000001'),1::bigint,'ambiguous completion retries cannot duplicate the success audit');

select * from finish();
rollback;
