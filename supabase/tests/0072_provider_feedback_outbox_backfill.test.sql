begin;
set local search_path=public,extensions;
select plan(18);

select has_function('private','provider_feedback_event_pseudonym',array['bigint','uuid'],'deterministic feedback event pseudonym helper exists');
select ok((select p.prosecdef and p.provolatile='i' and p.proconfig::text like'%search_path=pg_catalog%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='provider_feedback_event_pseudonym'),'pseudonym helper is immutable SECURITY DEFINER with fixed search path');
select ok(not has_function_privilege('authenticated','private.provider_feedback_event_pseudonym(bigint,uuid)','EXECUTE')and not has_function_privilege('service_role','private.provider_feedback_event_pseudonym(bigint,uuid)','EXECUTE'),'pseudonym helper is not externally callable');
select matches(private.provider_feedback_event_pseudonym(72,'72000000-0000-4000-8000-000000000001'),'^pf_[0-9a-f]{64}$','pseudonym has a non-reversible fixed format');
select is(private.provider_feedback_event_pseudonym(72,'72000000-0000-4000-8000-000000000001'),private.provider_feedback_event_pseudonym(72,'72000000-0000-4000-8000-000000000001'),'same event identity produces the same pseudonym');
select isnt(private.provider_feedback_event_pseudonym(72,'72000000-0000-4000-8000-000000000001'),private.provider_feedback_event_pseudonym(73,'72000000-0000-4000-8000-000000000001'),'different event identities produce different pseudonyms');
select ok((select p.prosrc like'%provider_feedback_event_pseudonym(new.id,new.correlation_id)%'and p.prosrc not like'%quote_id%'and p.prosrc not like'%rfq_id%'and p.prosrc not like'%client_organization_id%'and p.prosrc not like'%published_by%'and p.prosrc not like'%feedback_id%'and p.prosrc not like'%source_comparison_snapshot_id%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='sanitize_provider_feedback_outbox'),'future-event sanitizer pseudonymizes routing and cannot emit forbidden identifiers');
select ok(not exists(select 1 from public.event_outbox where event_type='ProviderFeedbackPublishedV1'and(aggregate_type<>'provider_feedback_notice'or aggregate_id!~'^pf_[0-9a-f]{64}$' or payload?|array['client_organization_id','quote_id','rfq_id','published_by','feedback_id','source_comparison_snapshot_id'])),'all historical feedback Outbox events are sanitized');
select ok(not exists(select 1 from public.event_outbox where event_type='ProviderFeedbackPublishedV1'and(payload-'feedback_available'-'ranking_position'-'ranked_quote_count')<>'{}'::jsonb),'historical payloads contain only the anonymous ranking contract');
select ok(exists(select 1 from public.audit_events where action='privacy.provider_feedback_outbox.backfilled'and actor_type='SYSTEM'and metadata->>'strategy'='HMAC_EVENT_PSEUDONYM_V1'),'historical privacy remediation is audited without deleting prior audit records');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('72100000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','backfill-provider@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)
values('72200000-0000-4000-8000-000000000001','Backfill Provider SARL','Backfill Provider','ACTIVE','72100000-0000-4000-8000-000000000001');
insert into public.organization_memberships(organization_id,user_id,status,activated_at)
values('72200000-0000-4000-8000-000000000001','72100000-0000-4000-8000-000000000001','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code)select id,'PROVIDER_OWNER'from public.organization_memberships where organization_id='72200000-0000-4000-8000-000000000001';

insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)
values('72200000-0000-4000-8000-000000000001','provider_feedback','sensitive-feedback-id','ProviderFeedbackPublishedV1','72300000-0000-4000-8000-000000000001','{"feedback_id":"72400000-0000-4000-8000-000000000001","client_organization_id":"72500000-0000-4000-8000-000000000001","quote_id":"72600000-0000-4000-8000-000000000001","rfq_id":"72700000-0000-4000-8000-000000000001","published_by":"72800000-0000-4000-8000-000000000001","source_comparison_snapshot_id":"72900000-0000-4000-8000-000000000001","ranking_position":3,"ranked_quote_count":8}'::jsonb);

select is((select aggregate_type from public.event_outbox where correlation_id='72300000-0000-4000-8000-000000000001'),'provider_feedback_notice','new feedback event uses anonymous aggregate type');
select matches((select aggregate_id from public.event_outbox where correlation_id='72300000-0000-4000-8000-000000000001'),'^pf_[0-9a-f]{64}$','new feedback event routing identifier is pseudonymized');
select is((select payload from public.event_outbox where correlation_id='72300000-0000-4000-8000-000000000001'),'{"feedback_available":true,"ranking_position":3,"ranked_quote_count":8}'::jsonb,'new feedback event payload is reduced to anonymous ranking');
select ok((select not(payload?|array['client_organization_id','quote_id','rfq_id','published_by','feedback_id','source_comparison_snapshot_id'])from public.event_outbox where correlation_id='72300000-0000-4000-8000-000000000001'),'new event contains none of the forbidden identifier keys');

select throws_ok($$set local role authenticated;select set_config('request.jwt.claim.sub','72100000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claims','{"sub":"72100000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);select count(*)from public.event_outbox where event_type='ProviderFeedbackPublishedV1'$$,'42501','permission denied for table event_outbox','Provider JWT cannot read even sanitized Outbox internals');
reset role;

select ok((select payload->>'feedback_available'='true'and(payload->>'ranking_position')::integer=3 and(payload->>'ranked_quote_count')::integer=8 from public.event_outbox where correlation_id='72300000-0000-4000-8000-000000000001'),'anonymous ranking remains usable after sanitization');
select ok((select aggregate_id=private.provider_feedback_event_pseudonym(id,correlation_id)from public.event_outbox where correlation_id='72300000-0000-4000-8000-000000000001'),'stored pseudonym matches deterministic event identity');
select ok((select count(*)=1 from public.event_outbox where correlation_id='72300000-0000-4000-8000-000000000001'),'sanitization preserves the event instead of deleting it');

select * from finish();
rollback;
