begin;
set local search_path=public,extensions;
select plan(30);

select has_function('public','list_my_anonymized_provider_feedback',array['integer','timestamp with time zone'],'minimal Provider feedback RPC exists');
select ok((select p.prosecdef and p.proconfig::text like'%search_path=pg_catalog%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='list_my_anonymized_provider_feedback'),'minimal feedback RPC is hardened SECURITY DEFINER');
select ok((select not(coalesce(p.proargnames,'{}')&&array['client_organization_id','provider_organization_id','quote_id','rfq_id','published_by','feedback_id','id'])from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='list_my_anonymized_provider_feedback'),'RPC result contract exposes no organization, quote, RFQ, publisher or internal identifier');
select ok((select qual like'%provider_organization_id%'and qual like'%has_platform_role%'and qual not like'%has_org_role%'from pg_policies where schemaname='public'and tablename='provider_feedback_snapshots'and policyname='provider_feedback_recipient_read'),'legacy policy name is retained only as platform-review compatibility, without Provider membership access');
select ok((select qual like'%has_platform_role%'and qual not like'%has_org_role%'from pg_policies where schemaname='public'and tablename='provider_feedback_snapshots'and policyname='provider_feedback_platform_review_read'),'raw feedback is limited to platform review roles');
select ok((select permissive='RESTRICTIVE'and qual like'%ProviderFeedbackPublishedV1%'and qual like'%has_platform_role%'from pg_policies where schemaname='public'and tablename='event_outbox'and policyname='provider_feedback_outbox_privacy_guard'),'feedback outbox events are hidden from Provider JWT access');
select ok(exists(select 1 from pg_trigger where tgrelid='public.event_outbox'::regclass and tgname='provider_feedback_outbox_payload_guard'and not tgisinternal),'feedback outbox sanitizer trigger is installed');
select ok((select p.prosrc not like'%quote_id%'and p.prosrc not like'%rfq_id%'and p.prosrc not like'%client_organization_id%'and p.prosrc not like'%published_by%'and p.prosrc not like'%feedback_id%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='sanitize_provider_feedback_outbox'),'outbox sanitizer emits no sensitive internal identifier');
select ok((select p.prosrc not like'%quote_id%'and p.prosrc not like'%rfq_id%'and p.prosrc not like'%client_organization_id%'and p.prosrc not like'%published_by%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='list_my_anonymized_provider_feedback'),'minimal RPC cannot project sensitive feedback fields');
select ok(has_function_privilege('authenticated','public.list_my_anonymized_provider_feedback(integer,timestamp with time zone)','EXECUTE')and not has_function_privilege('anon','public.list_my_anonymized_provider_feedback(integer,timestamp with time zone)','EXECUTE')and not has_function_privilege('service_role','public.list_my_anonymized_provider_feedback(integer,timestamp with time zone)','EXECUTE'),'minimal RPC execute grant is least privilege');
select has_function('private','valid_provider_reputation_evidence',array['uuid','uuid','jsonb'],'durable reputation evidence validator exists');
select ok((select p.prosecdef and p.proconfig::text like'%search_path=pg_catalog%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='valid_provider_reputation_evidence'),'evidence validator fixes its search path');
select ok(not has_function_privilege('authenticated','private.valid_provider_reputation_evidence(uuid,uuid,jsonb)','EXECUTE')and not has_function_privilege('service_role','private.valid_provider_reputation_evidence(uuid,uuid,jsonb)','EXECUTE'),'evidence validator is private');
select ok((select p.prosrc like'%public.missions%'and p.prosrc like'%public.provider_performance_events%'and p.prosrc like'%public.provider_feedback_snapshots%'and p.prosrc like'%provider_organization_id=p_provider_organization_id%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='valid_provider_reputation_evidence'),'evidence is resolved against durable tenant-bound records');
select ok(not private.valid_provider_reputation_evidence('68100000-0000-4000-8000-000000000001',null,'[{"type":"SELF_DECLARED","id":"68100000-0000-4000-8000-000000000099"}]'::jsonb),'DENY: self-declared evidence type is rejected');
select ok(not private.valid_provider_reputation_evidence('68100000-0000-4000-8000-000000000001',null,'[{"type":"MISSION","id":"68100000-0000-4000-8000-000000000099"}]'::jsonb),'DENY: fabricated durable evidence identifier is rejected');
select ok((select p.prosrc like'%valid_provider_reputation_evidence%'and p.prosrc like'%REPUTATION_EVIDENCE_INVALID_OR_CROSS_TENANT%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='calculate_provider_reputation'),'public reputation command rejects invalid or cross-tenant evidence before delegation');
select ok(not has_function_privilege('authenticated','private.calculate_provider_reputation(uuid,uuid,jsonb,jsonb,text,text,uuid)','EXECUTE'),'unhardened reputation implementation is no longer directly callable');
select ok((select p.prosrc like'%FEEDBACK_ACCESS_DENIED%'and p.prosrc like'%has_org_role%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='publish_not_selected_feedback'),'quote feedback missing and cross-tenant access share one denial contract');
select ok((select p.prosrc like'%FAVORITE_ACCESS_DENIED%'and p.prosrc like'%has_org_role%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='revalidate_provider_favorite'),'favourite missing and cross-tenant access share one denial contract');
select ok(not has_function_privilege('anon','public.publish_not_selected_feedback(uuid,jsonb,text,uuid,text,uuid)','EXECUTE')and not has_function_privilege('anon','public.revalidate_provider_favorite(uuid,uuid,text,uuid)','EXECUTE'),'anonymous callers cannot probe quote or favourite existence');
select ok((select relrowsecurity from pg_class where oid='public.provider_feedback_snapshots'::regclass),'RLS remains enabled on raw feedback');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values
('68100000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','privacy-provider-a@example.invalid','',now(),'{}','{}',now(),now()),
('68100000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','privacy-provider-b@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)values
('68110000-0000-4000-8000-000000000001','Privacy Provider A SARL','Privacy Provider A','ACTIVE','68100000-0000-4000-8000-000000000001'),
('68110000-0000-4000-8000-000000000002','Privacy Provider B SARL','Privacy Provider B','ACTIVE','68100000-0000-4000-8000-000000000002');
insert into public.organization_memberships(organization_id,user_id,status,activated_at)values
('68110000-0000-4000-8000-000000000001','68100000-0000-4000-8000-000000000001','ACTIVE',now()),
('68110000-0000-4000-8000-000000000002','68100000-0000-4000-8000-000000000002','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code)select id,'PROVIDER_OWNER'from public.organization_memberships where user_id in('68100000-0000-4000-8000-000000000001','68100000-0000-4000-8000-000000000002');

insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values('68110000-0000-4000-8000-000000000001','provider_feedback','68120000-0000-4000-8000-000000000001','ProviderFeedbackPublishedV1','68130000-0000-4000-8000-000000000001','{"feedback_id":"68120000-0000-4000-8000-000000000001","quote_id":"68140000-0000-4000-8000-000000000001","rfq_id":"68150000-0000-4000-8000-000000000001","client_organization_id":"68160000-0000-4000-8000-000000000001","published_by":"68100000-0000-4000-8000-000000000099","ranking_position":2,"ranked_quote_count":5}'::jsonb);
select matches((select aggregate_id from public.event_outbox where correlation_id='68130000-0000-4000-8000-000000000001'),'^pf_[0-9a-f]{64}$','outbox aggregate identifier is pseudonymised at runtime');
select is((select payload from public.event_outbox where correlation_id='68130000-0000-4000-8000-000000000001'),'{"feedback_available":true,"ranking_position":2,"ranked_quote_count":5}'::jsonb,'outbox runtime payload contains only minimal anonymous feedback metadata');

create temporary table privacy_observed(key text primary key,value jsonb);
grant insert,select on privacy_observed to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','68100000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"68100000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into privacy_observed values
('raw_feedback_rows',to_jsonb((select count(*)from public.provider_feedback_snapshots))),
('minimal_rpc_rows',to_jsonb((select count(*)from public.list_my_anonymized_provider_feedback(20,null))));
reset role;

select is((select value from privacy_observed where key='raw_feedback_rows'),'0'::jsonb,'DENY runtime: Provider JWT cannot read raw feedback, including its own tenant');
select is((select value from privacy_observed where key='minimal_rpc_rows'),'0'::jsonb,'ALLOW runtime: Provider JWT can call the minimal RPC without leaking another tenant');
select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','68100000-0000-4000-8000-000000000001',true);select count(*)from public.event_outbox where event_type='ProviderFeedbackPublishedV1'$$,'42501','permission denied for table event_outbox','DENY runtime: Provider JWT cannot read feedback outbox internals');
select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','68100000-0000-4000-8000-000000000001',true);select public.publish_not_selected_feedback('68140000-0000-4000-8000-000000000099','[{"dimension":"QUALITY","message_fr":"Améliorer la preuve","message_ar":"تحسين الدليل"}]','PRIVACY-V1',null,'privacy-quote-missing-1')$$,'42501','FEEDBACK_ACCESS_DENIED','DENY runtime: missing quote uses non-enumerable access error');
select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','68100000-0000-4000-8000-000000000001',true);select public.revalidate_provider_favorite('68170000-0000-4000-8000-000000000099','68180000-0000-4000-8000-000000000099','privacy-favorite-missing-1')$$,'42501','FAVORITE_ACCESS_DENIED','DENY runtime: missing favourite uses non-enumerable access error');
reset role;
select ok((select count(*)=0 from jsonb_object_keys((select payload from public.event_outbox where correlation_id='68130000-0000-4000-8000-000000000001'))k where k in('feedback_id','quote_id','rfq_id','client_organization_id','published_by')),'runtime outbox payload contains no sensitive identifier key');

select * from finish();
rollback;
