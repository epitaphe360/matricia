begin;
set local search_path=public,extensions;
select plan(22);

select columns_are('private','benchmark_verified_sources',
  array['id','organization_id','metric_code','segment_key','period_start','period_end','input_version',
    'source_hash','evidence_hash','verification_method','verified_by','verified_at','correlation_id',
    'registry_version_id','verified_value_exact','value_canonical','source_policy_snapshot',
    'source_policy_hash','binding_hash'],
  'verified proof records exact registry, value and policy binding');
select ok((select p.prosrc like'%source_row.registry_version_id=registry.id%'
  and p.prosrc like'%source_row.verified_value_exact=canonical_value%'
  and p.prosrc like'%source_row.source_policy_snapshot=registry.source_policy%'
  and p.prosrc like'%source_row.binding_hash=private.canonical_request_hash%'
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='submit_benchmark_contribution'),
  'submission requires the complete verified binding');
select ok((select position('pg_advisory_xact_lock' in p.prosrc)
  <position('source_row.registry_version_id=registry.id' in p.prosrc)
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='submit_benchmark_contribution'),
  'proof reload and validation remain under the cell lock');
select ok((select indexdef like'%source_verification_id%' and indexdef like'%WHERE (source_verification_id IS NOT NULL)%'
  from pg_indexes where indexname='benchmark_source_proof_single_use_uidx'),
  'one verified proof can back only one contribution');
select ok(not has_function_privilege('authenticated',
  'public.verify_benchmark_source(uuid,text,text,date,date,text,text,text,text,text,uuid)','EXECUTE'),
  'legacy verification without exact value is unavailable');
select ok(has_function_privilege('authenticated',
  'public.verify_benchmark_source(uuid,text,text,date,date,numeric,text,text,text,text,text,uuid)','EXECUTE'),
  'value-bound verification command is available');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
('a8800000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','benchmark-binding-admin@example.invalid','',now(),'{}','{}',now(),now()),
('a8800000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','benchmark-binding-client@example.invalid','',now(),'{}','{}',now(),now()),
('a8800000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','benchmark-binding-outsider@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by) values
('b8800000-0000-0000-0000-000000000001','Binding Tenant','Binding Tenant','ACTIVE','a8800000-0000-0000-0000-000000000002'),
('b8800000-0000-0000-0000-000000000002','Other Binding Tenant','Other Binding Tenant','ACTIVE','a8800000-0000-0000-0000-000000000003');
insert into public.platform_user_roles(user_id,role_code,granted_by)
values('a8800000-0000-0000-0000-000000000001','SUPER_ADMIN','a8800000-0000-0000-0000-000000000001');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at) values
('c8800000-0000-0000-0000-000000000001','b8800000-0000-0000-0000-000000000001','a8800000-0000-0000-0000-000000000002','ACTIVE',now()),
('c8800000-0000-0000-0000-000000000002','b8800000-0000-0000-0000-000000000002','a8800000-0000-0000-0000-000000000003','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code,granted_by) values
('c8800000-0000-0000-0000-000000000001','CLIENT_OWNER','a8800000-0000-0000-0000-000000000002'),
('c8800000-0000-0000-0000-000000000002','CLIENT_OWNER','a8800000-0000-0000-0000-000000000003');
insert into public.benchmark_registry_versions(
  id,metric_code,segment_key,version,status,minimum_value,maximum_value,unit_code,
  input_version_pattern,source_policy,content_hash,effective_from,created_by,correlation_id
) values(
  'd8800000-0000-0000-0000-000000000001','BOUND_VALUE','BOUND_SEGMENT',1,'ACTIVE',0,100,
  'COUNT','^v[0-9]+$', '{"allowed_verification_methods":["ADMIN_ATTESTATION"]}',
  repeat('8',64),now()-interval '1 day','a8800000-0000-0000-0000-000000000001',
  'e8800000-0000-0000-0000-000000000001'
);
create temporary table benchmark_binding_observed(key text primary key,value text);
grant insert,select on benchmark_binding_observed to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','a8800000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"a8800000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into benchmark_binding_observed values('proof',
  public.verify_benchmark_source(
    'b8800000-0000-0000-0000-000000000001','BOUND_VALUE','BOUND_SEGMENT',
    '2026-02-01','2026-02-28',10.000000,'v1',repeat('a',64),repeat('b',64),
    'ADMIN_ATTESTATION','verify-bound-value-0001'
  )::text);
reset role;

select is((select count(*) from private.benchmark_verified_sources
  where organization_id='b8800000-0000-0000-0000-000000000001' and verified_value_exact=10),1::bigint,
  'exact value proof is persisted once');
select is((select registry_version_id from private.benchmark_verified_sources
  where organization_id='b8800000-0000-0000-0000-000000000001'),
  'd8800000-0000-0000-0000-000000000001'::uuid,'proof binds the exact registry version');
select is((select source_policy_snapshot from private.benchmark_verified_sources
  where organization_id='b8800000-0000-0000-0000-000000000001'),
  '{"allowed_verification_methods":["ADMIN_ATTESTATION"]}'::jsonb,'proof snapshots applied source policy');

select throws_ok($$
  set local role authenticated;
  select set_config('request.jwt.claim.sub','a8800000-0000-0000-0000-000000000002',true);
  select set_config('request.jwt.claims','{"sub":"a8800000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}',true);
  select public.submit_benchmark_contribution(
    'b8800000-0000-0000-0000-000000000001','BOUND_VALUE','BOUND_SEGMENT',
    '2026-02-01','2026-02-28',100.000000,'v1',repeat('a',64),'submit-poisoned-max-0001')
$$,'22023','BENCHMARK_SOURCE_VALUE_NOT_VERIFIED',
  'proof for value 10 cannot be replayed with maximum value');
select is((select count(*) from private.benchmark_contributions
  where organization_id='b8800000-0000-0000-0000-000000000001'),0::bigint,
  'mismatched value rolls back contribution');
select is((select count(*) from public.audit_events
  where action='benchmark.contribution.submitted'
    and organization_id='b8800000-0000-0000-0000-000000000001'),0::bigint,
  'mismatched value emits no success audit');
select is((select count(*) from public.event_outbox
  where event_type='BenchmarkContributionAcceptedV3'
    and organization_id='b8800000-0000-0000-0000-000000000001'),0::bigint,
  'mismatched value emits no success outbox event');
select is((select count(*) from public.idempotency_keys
  where operation_scope='benchmark.contribution.submit' and key='submit-poisoned-max-0001'),0::bigint,
  'mismatched value rolls back idempotency reservation');

set local role authenticated;
select set_config('request.jwt.claim.sub','a8800000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"a8800000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}',true);
insert into benchmark_binding_observed values('accepted',
  public.submit_benchmark_contribution(
    'b8800000-0000-0000-0000-000000000001','BOUND_VALUE','BOUND_SEGMENT',
    '2026-02-01','2026-02-28',10.000000,'v1',repeat('a',64),'submit-bound-value-0001'
  )::text);
insert into benchmark_binding_observed values('replay',
  public.submit_benchmark_contribution(
    'b8800000-0000-0000-0000-000000000001','BOUND_VALUE','BOUND_SEGMENT',
    '2026-02-01','2026-02-28',10.000000,'v1',repeat('a',64),'submit-bound-value-0001'
  )::text);
reset role;

select is((select value from benchmark_binding_observed where key='replay'),
  (select value from benchmark_binding_observed where key='accepted'),'exact replay returns the original result');
select is((select count(*) from private.benchmark_contributions
  where organization_id='b8800000-0000-0000-0000-000000000001'),1::bigint,
  'exact verified value creates one contribution');
select is((select count(*) from public.audit_events
  where action='benchmark.contribution.submitted'
    and organization_id='b8800000-0000-0000-0000-000000000001'),1::bigint,
  'accepted contribution is audited once');
select is((select count(*) from public.event_outbox
  where event_type='BenchmarkContributionAcceptedV3'
    and organization_id='b8800000-0000-0000-0000-000000000001'),1::bigint,
  'accepted contribution is outboxed once');

select throws_ok($$
  set local role authenticated;
  select set_config('request.jwt.claim.sub','a8800000-0000-0000-0000-000000000003',true);
  select set_config('request.jwt.claims','{"sub":"a8800000-0000-0000-0000-000000000003","role":"authenticated","aal":"aal2"}',true);
  select public.submit_benchmark_contribution(
    'b8800000-0000-0000-0000-000000000001','BOUND_VALUE','BOUND_SEGMENT',
    '2026-02-01','2026-02-28',10.000000,'v1',repeat('a',64),'cross-tenant-binding-0001')
$$,'42501','BENCHMARK_CONTRIBUTION_DENIED','cross-tenant proof use is denied');

select throws_ok($$
  set local role authenticated;
  select set_config('request.jwt.claim.sub','a8800000-0000-0000-0000-000000000002',true);
  select set_config('request.jwt.claims','{"sub":"a8800000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}',true);
  select public.submit_benchmark_contribution(
    'b8800000-0000-0000-0000-000000000001','BOUND_VALUE','BOUND_SEGMENT',
    '2026-02-01','2026-02-28',10.000000,'v1',repeat('a',64),'submit-bound-value-again-0002')
$$,'22023','BENCHMARK_SOURCE_VALUE_NOT_VERIFIED','consumed proof cannot be reused under another command');

select ok((select source_verification_id is not null and registry_version_id is not null
  from private.benchmark_contributions
  where organization_id='b8800000-0000-0000-0000-000000000001'),
  'accepted contribution retains reproducible proof and registry lineage');
select ok((select binding_hash=private.canonical_request_hash(jsonb_build_object(
    'organization',organization_id,'registry_version_id',registry_version_id,
    'metric',metric_code,'segment',segment_key,'period_start',period_start,'period_end',period_end,
    'value_canonical',value_canonical,'input_version',input_version,'source_hash',source_hash,
    'evidence_hash',evidence_hash,'verification_method',verification_method,
    'source_policy_hash',source_policy_hash))
  from private.benchmark_verified_sources
  where organization_id='b8800000-0000-0000-0000-000000000001'),
  'stored proof binding is independently reproducible');

select * from finish();
rollback;
