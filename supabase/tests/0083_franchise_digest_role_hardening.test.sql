begin;
set local search_path=public,extensions;
select plan(36);

select ok((select p.prosecdef and p.proconfig::text like'%search_path=%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='franchise_digest_role_access'),'dedicated franchise digest access helper is hardened');
select ok((select p.prosrc like'%f.status=''ACTIVE''%'and p.prosrc like'%FRANCHISE_OWNER%'and p.prosrc like'%FRANCHISE_MANAGER%'and p.prosrc like'%FRANCHISE_VIEWER%'and p.prosrc like'%mr.revoked_at is null%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='franchise_digest_role_access'),'helper requires active franchise and active dedicated role');
select ok((select p.prosrc like'%SUPER_ADMIN%'and p.prosrc like'%MATRICIA_ADMIN%'and p.prosrc like'%READ_ONLY_AUDITOR%'and p.prosrc like'%p_allow_platform_admin%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='franchise_digest_role_access'),'only explicit platform admin roles receive administrative read scope');
select ok((select p.prosrc like'%mr.franchise_id=f.id%'and p.prosrc like'%mr.franchise_id is null%'and p.prosrc like'%count(*)from public.franchises sibling%'and p.prosrc like'%sibling.status=''ACTIVE''%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='franchise_digest_role_access'),'exact franchise scope is required when an operator has multiple active franchises');
select ok(not exists(select 1 from pg_policies where schemaname='public'and policyname in('franchise_digest_configs_scoped_read','franchise_digests_scoped_read','franchise_digest_jobs_scoped_read','franchise_digest_attempts_scoped_read')),'broad organization-membership digest policies are removed');
select ok((select count(*)=4 and bool_and(qual like'%franchise_digest_role_access%')from pg_policies where schemaname='public'and policyname in('franchise_digest_configs_role_read','franchise_digests_role_read','franchise_digest_jobs_role_read','franchise_digest_attempts_role_read')),'all digest histories use dedicated role-aware RLS');
select ok((select count(*)=2 from pg_trigger where tgname in('franchise_digest_job_recipient_guard','franchise_digest_notification_recipient_guard')and not tgisinternal),'scheduling and notification writes both revalidate recipient role');
select ok((select p.prosrc like'%franchise_digest_role_access(new.franchise_id,false,new.recipient_user_id)%'and p.prosrc like'%FRANCHISE_DIGEST_RECIPIENT_ACCESS_REVOKED%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='guard_franchise_digest_job_recipient'),'job insertion fails closed for an unauthorized recipient');
select ok((select p.prosrc like'%franchise_digest_role_access(x.franchise_id,false,x.recipient_user_id)%'and p.prosrc like'%skip locked%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='claim_franchise_daily_digest_jobs'),'claim and retry exclude revoked franchise recipients');
select ok((select p.prosrc like'%source_aggregate_type=''franchise_daily_digest''%'and p.prosrc like'%FRANCHISE_DIGEST_RECIPIENT_ACCESS_REVOKED%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='guard_franchise_digest_notification_recipient'),'completion has a final write-time revoked-role guard');
select ok(not has_function_privilege('anon','private.franchise_digest_role_access(uuid,boolean,uuid)','EXECUTE')and not has_function_privilege('service_role','private.franchise_digest_role_access(uuid,boolean,uuid)','EXECUTE'),'helper is not a public or service-role oracle');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values
('a8300000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner-a-83@example.invalid','',now(),'{}','{}',now(),now()),
('a8300000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','client-a-83@example.invalid','',now(),'{}','{}',now(),now()),
('a8300000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner-b-83@example.invalid','',now(),'{}','{}',now(),now()),
('a8300000-0000-4000-8000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','admin-83@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)values
('b8300000-0000-4000-8000-000000000001','Franchise Runtime A SARL','Franchise Runtime A','ACTIVE','a8300000-0000-4000-8000-000000000001'),
('b8300000-0000-4000-8000-000000000002','Franchise Runtime B SARL','Franchise Runtime B','ACTIVE','a8300000-0000-4000-8000-000000000003');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at)values
('c8300000-0000-4000-8000-000000000001','b8300000-0000-4000-8000-000000000001','a8300000-0000-4000-8000-000000000001','ACTIVE',now()),
('c8300000-0000-4000-8000-000000000002','b8300000-0000-4000-8000-000000000001','a8300000-0000-4000-8000-000000000002','ACTIVE',now()),
('c8300000-0000-4000-8000-000000000003','b8300000-0000-4000-8000-000000000002','a8300000-0000-4000-8000-000000000003','ACTIVE',now());
insert into public.franchises(id,library_id,operator_organization_id,franchise_type,operator_code,territory_code,status,created_by)values
('d8300000-0000-4000-8000-000000000001',(select id from public.catalog_libraries order by code limit 1),'b8300000-0000-4000-8000-000000000001','STANDARD','FRANCHISEE','P83_A','ACTIVE','a8300000-0000-4000-8000-000000000001'),
('d8300000-0000-4000-8000-000000000002',(select id from public.catalog_libraries order by code limit 1),'b8300000-0000-4000-8000-000000000002','STANDARD','FRANCHISEE','P83_B','ACTIVE','a8300000-0000-4000-8000-000000000003');
insert into public.organization_member_roles(membership_id,role_code,franchise_id)values
('c8300000-0000-4000-8000-000000000001','FRANCHISE_OWNER','d8300000-0000-4000-8000-000000000001'),
('c8300000-0000-4000-8000-000000000002','CLIENT_OWNER',null),
('c8300000-0000-4000-8000-000000000003','FRANCHISE_OWNER','d8300000-0000-4000-8000-000000000002');
insert into public.platform_user_roles(user_id,role_code)values('a8300000-0000-4000-8000-000000000004','MATRICIA_ADMIN');
insert into public.franchise_daily_digest_config_versions(id,franchise_id,recipient_user_id,version,policy_version_id,enabled,frequency,local_send_time,time_zone,locale,change_reason,content_hash,created_by)
values('e8300000-0000-4000-8000-000000000001','d8300000-0000-4000-8000-000000000001','a8300000-0000-4000-8000-000000000001',1,(select id from public.franchise_daily_digest_policy_versions where status='ACTIVE'),'true','DAILY','00:00','UTC','fr-MA','Configuration runtime P83',repeat('a',64),'a8300000-0000-4000-8000-000000000001');

select ok(private.franchise_digest_role_access('d8300000-0000-4000-8000-000000000001',false,'a8300000-0000-4000-8000-000000000001'),'ALLOW: active franchise owner has digest scope');
select ok(not private.franchise_digest_role_access('d8300000-0000-4000-8000-000000000001',false,'a8300000-0000-4000-8000-000000000002'),'DENY: same-organization client role has no digest scope');
select ok(not private.franchise_digest_role_access('d8300000-0000-4000-8000-000000000001',false,'a8300000-0000-4000-8000-000000000003'),'DENY: other-tenant franchise owner has no digest scope');
select ok(private.franchise_digest_role_access('d8300000-0000-4000-8000-000000000001',true,'a8300000-0000-4000-8000-000000000004'),'ALLOW: explicitly authorized platform admin has read scope');

create temporary table p83_observed(key text primary key,value jsonb);
grant select,insert,update on p83_observed to service_role,authenticated;
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
insert into p83_observed select'schedule_ok',v from public.schedule_franchise_daily_digests(clock_timestamp(),10)v limit 1;
reset role;
select is((select value->>'locale'from p83_observed where key='schedule_ok'),'fr-MA','schedule creates the configured localized digest job');
update public.franchise_daily_digest_jobs set next_attempt_at='2000-01-01'where id=((select value->>'job_id'from p83_observed where key='schedule_ok')::uuid);

set local role authenticated;select set_config('request.jwt.claim.sub','a8300000-0000-4000-8000-000000000002',true);select set_config('request.jwt.claim.role','authenticated',true);
insert into p83_observed values('same_org_client_counts',jsonb_build_object('configs',(select count(*)from public.franchise_daily_digest_config_versions),'digests',(select count(*)from public.franchise_daily_digests),'jobs',(select count(*)from public.franchise_daily_digest_jobs)));
reset role;
select is(((select value->>'configs'from p83_observed where key='same_org_client_counts')::bigint),0::bigint,'DENY: same-org client role cannot read digest configs');
select is(((select value->>'digests'from p83_observed where key='same_org_client_counts')::bigint),0::bigint,'DENY: same-org client role cannot read digest contents');
select is(((select value->>'jobs'from p83_observed where key='same_org_client_counts')::bigint),0::bigint,'DENY: same-org client role cannot read digest jobs');
set local role authenticated;select set_config('request.jwt.claim.sub','a8300000-0000-4000-8000-000000000003',true);
insert into p83_observed values('cross_tenant_count',to_jsonb((select count(*)from public.franchise_daily_digests where franchise_id='d8300000-0000-4000-8000-000000000001')));
reset role;
select is(((select value#>>'{}'from p83_observed where key='cross_tenant_count')::bigint),0::bigint,'DENY: cross-tenant franchise role cannot read another digest');
set local role authenticated;select set_config('request.jwt.claim.sub','a8300000-0000-4000-8000-000000000001',true);
insert into p83_observed values('owner_count',to_jsonb((select count(*)from public.franchise_daily_digests where franchise_id='d8300000-0000-4000-8000-000000000001')));
reset role;
select is(((select value#>>'{}'from p83_observed where key='owner_count')::bigint),1::bigint,'ALLOW: legitimate franchise owner reads its digest');
set local role authenticated;select set_config('request.jwt.claim.sub','a8300000-0000-4000-8000-000000000004',true);select set_config('request.jwt.claims','{"sub":"a8300000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal2"}',true);
insert into p83_observed values('admin_count',to_jsonb((select count(*)from public.franchise_daily_digests where franchise_id='d8300000-0000-4000-8000-000000000001')));
reset role;
select is(((select value#>>'{}'from p83_observed where key='admin_count')::bigint),1::bigint,'ALLOW: authorized platform admin reads scoped digest');

set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
insert into p83_observed select'claim_ok',v from public.claim_franchise_daily_digest_jobs('f8300000-0000-4000-8000-000000000001',1,300)v;
reset role;
select is((select value->>'job_id'from p83_observed where key='claim_ok'),(select value->>'job_id'from p83_observed where key='schedule_ok'),'worker claims the authorized scheduled job');
insert into p83_observed values('claim_ok_row_version',to_jsonb((select row_version from public.franchise_daily_digest_jobs where id=((select value->>'job_id'from p83_observed where key='claim_ok')::uuid))));
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
insert into p83_observed select'complete_ok',public.complete_franchise_daily_digest_job((select(value->>'job_id')::uuid from p83_observed where key='claim_ok'),(select(value->>'lease_token')::uuid from p83_observed where key='claim_ok'),'f8300000-0000-4000-8000-000000000001',(select(value#>>'{}')::integer from p83_observed where key='claim_ok_row_version'),'p83-complete-ok');
insert into p83_observed select'complete_replay',public.complete_franchise_daily_digest_job((select(value->>'job_id')::uuid from p83_observed where key='claim_ok'),(select(value->>'lease_token')::uuid from p83_observed where key='claim_ok'),'f8300000-0000-4000-8000-000000000001',2,'p83-complete-ok');
reset role;
select is((select value->>'outcome'from p83_observed where key='complete_ok'),'FRANCHISE_DAILY_DIGEST_NOTIFIED','authorized cycle completes through notification');
select is((select value->>'notification_id'from p83_observed where key='complete_ok'),(select value->>'notification_id'from p83_observed where key='complete_replay'),'completion replay returns the same delivery proof');
select is((select count(*)from public.franchise_daily_digest_job_attempts where job_id=((select value->>'job_id'from p83_observed where key='claim_ok')::uuid)),1::bigint,'completion replay creates one immutable attempt');
select is((select count(*)from public.notification_instances where id=((select value->>'notification_id'from p83_observed where key='complete_ok')::uuid)),1::bigint,'successful completion creates exactly one notification');

update public.franchise_daily_digest_config_versions set created_at=created_at where false;
insert into public.franchise_daily_digest_config_versions(id,franchise_id,recipient_user_id,version,policy_version_id,enabled,frequency,local_send_time,time_zone,locale,supersedes_config_id,change_reason,content_hash,created_by)
values('e8300000-0000-4000-8000-000000000002','d8300000-0000-4000-8000-000000000001','a8300000-0000-4000-8000-000000000001',2,(select id from public.franchise_daily_digest_policy_versions where status='ACTIVE'),true,'DAILY','00:00','UTC','ar-MA','e8300000-0000-4000-8000-000000000001','Version arabe runtime',repeat('b',64),'a8300000-0000-4000-8000-000000000001');
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
insert into p83_observed select'schedule_fail',v from public.schedule_franchise_daily_digests(clock_timestamp()+interval'1 day',10)v where v->>'locale'='ar-MA'limit 1;
reset role;
update public.franchise_daily_digest_jobs set next_attempt_at='2000-01-01'where id=((select value->>'job_id'from p83_observed where key='schedule_fail')::uuid);
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
insert into p83_observed select'claim_fail',v from public.claim_franchise_daily_digest_jobs('f8300000-0000-4000-8000-000000000002',1,300)v;
insert into p83_observed select'fail_once',public.fail_franchise_daily_digest_job((select(value->>'job_id')::uuid from p83_observed where key='claim_fail'),(select(value->>'lease_token')::uuid from p83_observed where key='claim_fail'),'f8300000-0000-4000-8000-000000000002','WORKER_TIMEOUT','p83-fail-once');
insert into p83_observed select'fail_replay',public.fail_franchise_daily_digest_job((select(value->>'job_id')::uuid from p83_observed where key='claim_fail'),(select(value->>'lease_token')::uuid from p83_observed where key='claim_fail'),'f8300000-0000-4000-8000-000000000002','WORKER_TIMEOUT','p83-fail-once');
reset role;
select is((select value->>'outcome'from p83_observed where key='fail_once'),'FRANCHISE_DAILY_DIGEST_FAILED','worker records a retryable failure');
select is((select value from p83_observed where key='fail_once'),(select value from p83_observed where key='fail_replay'),'failure replay is idempotent');
update public.franchise_daily_digest_jobs set next_attempt_at='2000-01-01'where id=((select value->>'job_id'from p83_observed where key='claim_fail')::uuid);
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
insert into p83_observed select'claim_retry',v from public.claim_franchise_daily_digest_jobs('f8300000-0000-4000-8000-000000000003',1,300)v;
reset role;
insert into p83_observed values('claim_retry_row_version',to_jsonb((select row_version from public.franchise_daily_digest_jobs where id=((select value->>'job_id'from p83_observed where key='claim_retry')::uuid))));
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
insert into p83_observed select'complete_retry',public.complete_franchise_daily_digest_job((select(value->>'job_id')::uuid from p83_observed where key='claim_retry'),(select(value->>'lease_token')::uuid from p83_observed where key='claim_retry'),'f8300000-0000-4000-8000-000000000003',(select(value#>>'{}')::integer from p83_observed where key='claim_retry_row_version'),'p83-complete-retry');
reset role;
select is((select value->>'job_id'from p83_observed where key='claim_retry'),(select value->>'job_id'from p83_observed where key='claim_fail'),'retry reclaims the same authorized job');
select is((select value->>'outcome'from p83_observed where key='complete_retry'),'FRANCHISE_DAILY_DIGEST_NOTIFIED','retry can complete after a recorded failure');

insert into public.franchise_daily_digest_config_versions(id,franchise_id,recipient_user_id,version,policy_version_id,enabled,frequency,local_send_time,time_zone,locale,supersedes_config_id,change_reason,content_hash,created_by)
values('e8300000-0000-4000-8000-000000000003','d8300000-0000-4000-8000-000000000001','a8300000-0000-4000-8000-000000000001',3,(select id from public.franchise_daily_digest_policy_versions where status='ACTIVE'),true,'DAILY','00:00','UTC','fr-MA','e8300000-0000-4000-8000-000000000002','Version révocation runtime',repeat('c',64),'a8300000-0000-4000-8000-000000000001');
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
insert into p83_observed select'schedule_revoke',v from public.schedule_franchise_daily_digests(clock_timestamp()+interval'2 days',10)v where v->>'locale'='fr-MA'limit 1;
reset role;
update public.franchise_daily_digest_jobs set next_attempt_at='2000-01-01'where id=((select value->>'job_id'from p83_observed where key='schedule_revoke')::uuid);
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
insert into p83_observed select'claim_revoke',v from public.claim_franchise_daily_digest_jobs('f8300000-0000-4000-8000-000000000004',1,300)v;
reset role;
update public.organization_member_roles set revoked_at=clock_timestamp()where membership_id='c8300000-0000-4000-8000-000000000001'and role_code='FRANCHISE_OWNER';
select ok(not private.franchise_digest_role_access('d8300000-0000-4000-8000-000000000001',false,'a8300000-0000-4000-8000-000000000001'),'DENY: revoked franchise role immediately loses digest scope');
select throws_ok(format($sql$set local role service_role;select set_config('request.jwt.claim.role','service_role',true);select public.complete_franchise_daily_digest_job(%L::uuid,%L::uuid,%L::uuid,%s,%L)$sql$,(select value->>'job_id'from p83_observed where key='claim_revoke'),(select value->>'lease_token'from p83_observed where key='claim_revoke'),'f8300000-0000-4000-8000-000000000004',(select row_version from public.franchise_daily_digest_jobs where id=((select value->>'job_id'from p83_observed where key='claim_revoke')::uuid)),'p83-revoked-complete'),'42501'::char(5),'FRANCHISE_DIGEST_RECIPIENT_ACCESS_REVOKED','DENY: role revoked after claim cannot receive notification at completion');
select is((select count(*)from public.notification_instances where source_aggregate_id=(select value->>'digest_id'from p83_observed where key='schedule_revoke')),0::bigint,'revoked completion leaves no notification or delivery proof');
update public.franchise_daily_digest_jobs set status='FAILED',next_attempt_at='2000-01-01',lease_token=null,worker_id=null,leased_until=null,last_error_code='ROLE_REVOKED'where id=((select value->>'job_id'from p83_observed where key='claim_revoke')::uuid);
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
insert into p83_observed select'revoked_retry',v from public.claim_franchise_daily_digest_jobs('f8300000-0000-4000-8000-000000000005',10,300)v;
reset role;
select is((select count(*)from p83_observed where key='revoked_retry'and value->>'job_id'=(select value->>'job_id'from p83_observed where key='claim_revoke')),0::bigint,'DENY: revoked recipient job is not reclaimed for retry');
select ok((select count(*)from public.audit_events where action in('franchise.daily_digest.scheduled','franchise.daily_digest.claimed','franchise.daily_digest.notified','franchise.daily_digest.failed'))>=8 and(select count(*)from public.event_outbox where event_type in('FranchiseDailyDigestScheduledV1','FranchiseDailyDigestClaimedV1','FranchiseDailyDigestNotifiedV1','FranchiseDailyDigestFailedV1'))>=8,'allowed lifecycle writes audit and Outbox evidence while denied completion rolls back');

select * from finish();
rollback;
