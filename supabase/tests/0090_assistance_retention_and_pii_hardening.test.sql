begin;
set local search_path=public,extensions;
select plan(21);

select is(private.minimize_assistance_input('CIN AB123456'),'CIN [CIN]','CIN is minimized');
select is(private.minimize_assistance_input('Passeport XY987654'),'Passeport [PASSPORT]','passport is minimized');
select is(private.minimize_assistance_input('AB123456 requis'),'[IDENTIFIER] requis','unlabelled identifier is minimized');
select is(private.minimize_assistance_input('Jalil Mansouri;'),'[NAME];','unlabelled French name is minimized');
select is(private.minimize_assistance_input('جليل المنصوري؛'),'[NAME]؛','unlabelled Arabic name is minimized');
select ok(length(private.minimize_assistance_input(repeat('x',1500)))<=1000,'retained input remains bounded');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values('a9000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','purge-90@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)values('b9000000-0000-4000-8000-000000000001','Purge Runtime','Purge Runtime','ACTIVE','a9000000-0000-4000-8000-000000000001');
insert into public.assistance_model_versions(id,model_key,version,algorithm,configuration,status,effective_from,content_hash,change_reason,created_by)values('d9000000-0000-4000-8000-000000000001','PURGE_TEST_V90',1,'TOKEN_OVERLAP_V1','{"minimum_score_basis_points":1000,"duplicate_score_basis_points":8000,"candidate_limit":10}','ARCHIVED',clock_timestamp()-interval'1 year',repeat('9',64),'Purge runtime fixture','a9000000-0000-4000-8000-000000000001');
insert into public.assistance_requests(id,organization_id,model_version_id,context_type,status,input_text,input_hash,input_text_expires_at,created_by,created_at)values('c9000000-0000-4000-8000-000000000001','b9000000-0000-4000-8000-000000000001','d9000000-0000-4000-8000-000000000001','CONTEXTUAL_ASSISTANT','COMPLETED','CIN AB123456 Passeport XY987654',repeat('8',64),statement_timestamp()-interval'1 day','a9000000-0000-4000-8000-000000000001',statement_timestamp()-interval'31 days');
create temporary table purge90(k text primary key,v jsonb);grant select,insert,update on purge90 to service_role;
set local role service_role;select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into purge90 values('scheduled',jsonb_build_object('count',public.schedule_assistance_input_purges(clock_timestamp(),10)));
insert into purge90 values('scheduled_replay',jsonb_build_object('count',public.schedule_assistance_input_purges(clock_timestamp(),10)));
insert into purge90 select 'claim',x from public.claim_assistance_input_purge_jobs('worker-90',1,300)x;
insert into purge90 select 'complete',public.complete_assistance_input_purge_job((v->>'job_id')::uuid,(v->>'lease_token')::uuid,'worker-90','complete-90')from purge90 where k='claim';
insert into purge90 select 'complete_replay',public.complete_assistance_input_purge_job((v->>'job_id')::uuid,(v->>'lease_token')::uuid,'worker-90','complete-90')from purge90 where k='claim';
reset role;

select is((select(v->>'count')::int from purge90 where k='scheduled'),1,'scheduler queues expired input');
select is((select(v->>'count')::int from purge90 where k='scheduled_replay'),0,'scheduler replay is idempotent');
select is((select v->>'status'from purge90 where k='complete'),'COMPLETED','worker purges expired input');
select is((select v from purge90 where k='complete_replay'),(select v from purge90 where k='complete'),'completion replay returns stable result');
select ok((select input_text is null and input_text_expires_at is null and input_text_redacted_at is not null from public.assistance_requests where id='c9000000-0000-4000-8000-000000000001'),'expired text is actually purged');
select is((select count(*)from public.assistance_input_purge_attempts),1::bigint,'completion replay creates one attempt');
select ok(not exists(select 1 from public.event_outbox where aggregate_id in(select id::text from public.assistance_input_purge_jobs)and(payload::text ilike'%AB123456%'or payload::text ilike'%XY987654%')),'outbox contains no source PII');
select ok(not exists(select 1 from public.audit_events where resource_type='assistance_input_purge_job'and metadata::text ilike'%AB123456%'),'audit contains no source PII');
select ok((select correlation_id=(select(v->>'lease_token')::uuid from purge90 where k='claim')from public.audit_events where action='assistance.input_purge.completed'and resource_id=(select v->>'job_id'from purge90 where k='claim')),'completion audit uses the replay-stable non-PII lease correlation');
select ok(has_function_privilege('service_role','public.schedule_assistance_input_purges(timestamptz,integer)','EXECUTE'),'service role can schedule');
select ok(not has_function_privilege('authenticated','public.schedule_assistance_input_purges(timestamptz,integer)','EXECUTE'),'authenticated cannot schedule');
select ok(not has_function_privilege('anon','public.claim_assistance_input_purge_jobs(text,integer,integer)','EXECUTE'),'anon cannot claim');
select throws_ok($$select public.schedule_assistance_input_purges(clock_timestamp(),1001)$$,'22023','ASSISTANCE_PURGE_LIMIT_INVALID','scheduler bound enforced');
set local role service_role;select set_config('request.jwt.claims','{"role":"service_role"}',true);
reset role;
select throws_ok($$select public.claim_assistance_input_purge_jobs('worker',101,300)$$::text,'22023'::text,'ASSISTANCE_PURGE_CLAIM_INVALID'::text,'claim bound enforced'::text);
select ok((select status='COMPLETED'and attempt_count=1 from public.assistance_input_purge_jobs where request_id='c9000000-0000-4000-8000-000000000001'),'queue state is terminal and bounded');

select * from finish();rollback;
