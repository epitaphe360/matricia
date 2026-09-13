begin;
select plan(34);

select has_table('public','business_approval_policy_versions','versioned approval policies exist');
select has_table('public','business_approval_requests','approval requests exist');
select has_table('public','business_approval_decisions','approval decisions exist');
select has_table('public','provider_commission_forecasts','commission forecasts exist');
select has_function('public','record_provider_commission_forecast',array['uuid','date','date','bigint','integer','jsonb','text','text','uuid'],'forecast RPC exists');
select has_function('public','request_marketing_campaign_approval_v1',array['uuid','integer','text','uuid'],'campaign approval request command exists');
select ok(has_function_privilege('authenticated','public.request_marketing_campaign_approval_v1(uuid,integer,text,uuid)','EXECUTE'),'authenticated campaign managers can reach the guarded approval command');
select function_privs_are('public','claim_franchise_daily_digest_jobs',array['uuid','integer','integer'],'authenticated',array[]::text[],'authenticated cannot claim digest jobs');
select function_privs_are('public','claim_franchise_daily_digest_jobs',array['uuid','integer','integer'],'service_role',array['EXECUTE'],'service role can claim digest jobs');
select isnt_empty($$select 1 from pg_trigger where tgrelid='public.business_approval_decisions'::regclass and not tgisinternal$$,'approval decisions are immutable');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
 ('13500000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p135-owner@example.invalid','',now(),'{}','{}',now(),now()),
 ('13500000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p135-approver@example.invalid','',now(),'{}','{}',now(),now()),
 ('13500000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p135-provider@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by) values
 ('13510000-0000-4000-8000-000000000001','P135 Client SARL','P135 Client','ACTIVE','13500000-0000-4000-8000-000000000001'),
 ('13510000-0000-4000-8000-000000000002','P135 Provider SARL','P135 Provider','ACTIVE','13500000-0000-4000-8000-000000000003');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at) values
 ('13520000-0000-4000-8000-000000000001','13510000-0000-4000-8000-000000000001','13500000-0000-4000-8000-000000000001','ACTIVE',now()),
 ('13520000-0000-4000-8000-000000000002','13510000-0000-4000-8000-000000000001','13500000-0000-4000-8000-000000000002','ACTIVE',now()),
 ('13520000-0000-4000-8000-000000000003','13510000-0000-4000-8000-000000000002','13500000-0000-4000-8000-000000000003','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code) values
 ('13520000-0000-4000-8000-000000000001','CLIENT_OWNER'),
 ('13520000-0000-4000-8000-000000000002','CLIENT_ADMIN'),
 ('13520000-0000-4000-8000-000000000003','PROVIDER_OWNER');
insert into public.platform_user_roles(user_id,role_code,granted_by)values('13500000-0000-4000-8000-000000000002','MATRICIA_ADMIN','13500000-0000-4000-8000-000000000001');
insert into public.brand_kits(id,organization_id,status,created_by)values('13521000-0000-4000-8000-000000000001','13510000-0000-4000-8000-000000000001','DRAFT','13500000-0000-4000-8000-000000000001');
insert into public.brand_kit_versions(id,brand_kit_id,version,payload,claims,certifications,content_hash,change_reason,created_by)values('13522000-0000-4000-8000-000000000001','13521000-0000-4000-8000-000000000001',1,'{"legal_name":"P135 Client SARL","trade_name":"P135 Client","primary_colors":["#123B5D"],"tone":["PROFESSIONAL"],"languages":["FR","AR"],"primary_cta":"DIAGNOSTIC","tracked_url":"https://matricia.ma/diagnostic","required_mentions":[],"forbidden_terms":[],"approved_hashtags":["#Matricia"]}','[{"key":"claim-one","textFr":"Claim soumis","textAr":"ادعاء مقدم","evidenceReference":"P135-EVIDENCE","evidenceHash":"9999999999999999999999999999999999999999999999999999999999999999"}]','[]',repeat('8',64),'Fixture revue centrale','13500000-0000-4000-8000-000000000001');
update public.brand_kits set current_version_id='13522000-0000-4000-8000-000000000001'where id='13521000-0000-4000-8000-000000000001';

create temp table p135_observed(key text primary key,value jsonb);
grant select,insert on p135_observed to authenticated,service_role;
grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','13500000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"13500000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select extensions.throws_ok($$select public.propose_business_approval_policy('13510000-0000-4000-8000-000000000001','COST_CENTER','COST_CENTER',1,array['CLIENT_ADMIN'],true,clock_timestamp()-interval '1 minute','Politique contrôlée P135','p135-propose-aal1')$$,'42501'::char(5),'BUSINESS_APPROVAL_POLICY_DENIED','AAL1 cannot propose policy');
select set_config('request.jwt.claims','{"sub":"13500000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into p135_observed values('proposal',public.propose_business_approval_policy('13510000-0000-4000-8000-000000000001','COST_CENTER','COST_CENTER',1,array['CLIENT_ADMIN'],true,clock_timestamp()-interval '1 minute','Politique contrôlée P135','p135-propose-ok'));
select is((select value->>'outcome' from p135_observed where key='proposal'),'BUSINESS_APPROVAL_POLICY_PROPOSED','AAL2 owner proposes policy');
select extensions.throws_ok(format($$select public.activate_business_approval_policy(%L,%L,'p135-activate-self')$$,(select value->>'policy_version_id' from p135_observed where key='proposal'),(select value->>'content_hash' from p135_observed where key='proposal')),'42501'::char(5),'BUSINESS_APPROVAL_POLICY_ACTIVATION_DENIED','author cannot self-activate');
select set_config('request.jwt.claim.sub','13500000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"13500000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select extensions.throws_ok(format($$select public.activate_business_approval_policy(%L,%L,'p135-activate-aal1')$$,(select value->>'policy_version_id' from p135_observed where key='proposal'),(select value->>'content_hash' from p135_observed where key='proposal')),'42501'::char(5),'BUSINESS_APPROVAL_POLICY_ACTIVATION_DENIED','AAL1 second human denied');
select extensions.throws_ok($$select public.record_marketing_brand_authorization_v41('13510000-0000-4000-8000-000000000001','GRANTED',array['SOCIAL_PUBLISHING'],'P135-AAL2',repeat('9',64),clock_timestamp(),null,'p135-brand-aal1')$$,'42501'::char(5),'MARKETING_GOVERNANCE_AAL2_REQUIRED','AAL1 cannot record social governance authorization');
select extensions.throws_ok($$select public.review_marketing_brand_evidence_v1('13522000-0000-4000-8000-000000000001','CLAIM','claim-one','VERIFIED',repeat('9',64),clock_timestamp()+interval'1 day','Revue humaine P135','13523000-0000-4000-8000-000000000001')$$,'42501'::char(5),'MARKETING_BRAND_EVIDENCE_REVIEW_DENIED','AAL1 cannot approve tenant-submitted Brand evidence');
select set_config('request.jwt.claims','{"sub":"13500000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);
insert into p135_observed values('activation',public.activate_business_approval_policy((select (value->>'policy_version_id')::uuid from p135_observed where key='proposal'),(select value->>'content_hash' from p135_observed where key='proposal'),'p135-activate-ok'));
select is((select value->>'outcome' from p135_observed where key='activation'),'BUSINESS_APPROVAL_POLICY_ACTIVATED','distinct AAL2 admin activates');
insert into p135_observed values('brand_aal2',public.record_marketing_brand_authorization_v41('13510000-0000-4000-8000-000000000001','GRANTED',array['SOCIAL_PUBLISHING'],'P135-AAL2',repeat('9',64),clock_timestamp(),null,'p135-brand-aal2'));
select is((select value->>'outcome'from p135_observed where key='brand_aal2'),'MARKETING_BRAND_AUTHORIZATION_GRANTED','AAL2 records social governance authorization');
insert into p135_observed values('evidence_aal2',public.review_marketing_brand_evidence_v1('13522000-0000-4000-8000-000000000001','CLAIM','claim-one','VERIFIED',repeat('9',64),clock_timestamp()+interval'1 day','Revue humaine P135','13523000-0000-4000-8000-000000000002'));
select is((select value->>'outcome'from p135_observed where key='evidence_aal2'),'MARKETING_BRAND_EVIDENCE_VERIFIED','AAL2 Matricia admin verifies submitted evidence');
insert into p135_observed values('activation_replay',public.activate_business_approval_policy((select (value->>'policy_version_id')::uuid from p135_observed where key='proposal'),(select value->>'content_hash' from p135_observed where key='proposal'),'p135-activate-ok'));
select is((select value from p135_observed where key='activation_replay'),(select value from p135_observed where key='activation'),'activation replay survives state transition');

select set_config('request.jwt.claim.sub','13500000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"13500000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into p135_observed values('request',public.request_business_approval('13510000-0000-4000-8000-000000000001','COST_CENTER','COST_CENTER','CC-001',12500,'MAD',repeat('a',64),'p135-request-ok'));
select is((select value->>'outcome' from p135_observed where key='request'),'BUSINESS_APPROVAL_REQUESTED','member requests approval');
select extensions.throws_ok(format($$select public.decide_business_approval(%L,1,'APPROVE','Motif valide','p135-decide-self')$$,(select value->>'approval_request_id' from p135_observed where key='request')),'42501'::char(5),'BUSINESS_APPROVAL_DECISION_DENIED','requester separation enforced');
select set_config('request.jwt.claim.sub','13500000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"13500000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select extensions.throws_ok(format($$select public.decide_business_approval(%L,1,'APPROVE','Motif valide','p135-decide-aal1')$$,(select value->>'approval_request_id' from p135_observed where key='request')),'42501'::char(5),'BUSINESS_APPROVAL_DECISION_DENIED','AAL1 approver denied');
select set_config('request.jwt.claims','{"sub":"13500000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);
insert into p135_observed values('decision',public.decide_business_approval((select (value->>'approval_request_id')::uuid from p135_observed where key='request'),1,'APPROVE','Motif valide','p135-decide-ok'));
select is((select value->>'outcome' from p135_observed where key='decision'),'BUSINESS_APPROVAL_APPROVED','eligible AAL2 approver decides');
insert into p135_observed values('decision_replay',public.decide_business_approval((select (value->>'approval_request_id')::uuid from p135_observed where key='request'),1,'APPROVE','Motif valide','p135-decide-ok'));
select is((select value from p135_observed where key='decision_replay'),(select value from p135_observed where key='decision'),'decision replay survives row version change');
select is((select count(*)::integer from public.business_approval_decisions),1,'decision replay creates no duplicate');

reset role;
select isnt_empty($$select 1 from pg_get_functiondef('public.record_provider_commission_forecast(uuid,date,date,bigint,integer,jsonb,text,text,uuid)'::regprocedure)d where d like '%p_commission_rule_snapshot is distinct from cv.commission_rule_snapshot%' and d like '%authoritative_basis_points%'$$,'forecast uses authoritative contract snapshot');
set session_replication_role=replica;
insert into public.provider_commission_forecasts(id,provider_organization_id,client_organization_id,mission_id,contract_version_id,forecast_period_start,forecast_period_end,currency,estimated_gross_minor,commission_basis_points,estimated_commission_minor,commission_rule_snapshot,source_hash,correlation_id,created_by) values('13530000-0000-4000-8000-000000000001','13510000-0000-4000-8000-000000000002','13510000-0000-4000-8000-000000000001','13540000-0000-4000-8000-000000000001','13550000-0000-4000-8000-000000000001',current_date,current_date,'MAD',10000,1000,1000,'{"commission_basis_points":1000}',repeat('b',64),'13560000-0000-4000-8000-000000000001','13500000-0000-4000-8000-000000000003');
insert into public.provider_commission_forecasts(id,provider_organization_id,client_organization_id,mission_id,contract_version_id,forecast_period_start,forecast_period_end,currency,estimated_gross_minor,commission_basis_points,estimated_commission_minor,commission_rule_snapshot,source_hash,correlation_id,created_by) values('13530000-0000-4000-8000-000000000002','13510000-0000-4000-8000-000000000002','13510000-0000-4000-8000-000000000001','13540000-0000-4000-8000-000000000002','13550000-0000-4000-8000-000000000002',current_date,current_date,'MAD',20000,1000,2000,'{"commission_basis_points":1000}',repeat('c',64),'13560000-0000-4000-8000-000000000002','13500000-0000-4000-8000-000000000003');
set session_replication_role=origin;
set local role authenticated;
select set_config('request.jwt.claim.sub','13500000-0000-4000-8000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"13500000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal2"}',true);
select is((select count(*)::integer from public.provider_commission_forecasts),2,'provider reads own forecasts');
select set_config('request.jwt.claim.sub','13500000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"13500000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
select is((select count(*)::integer from public.provider_commission_forecasts),0,'client cannot read provider commission');

reset role;
set session_replication_role=replica;
insert into public.provider_commission_forecast_reconciliations(provider_organization_id,forecast_id,payable_event_id,forecast_amount_minor,official_amount_minor,variance_minor,reason,correlation_id,reconciled_by)values('13510000-0000-4000-8000-000000000002','13530000-0000-4000-8000-000000000001','13570000-0000-4000-8000-000000000010',1000,1100,100,'Fixture reconciliation','13560000-0000-4000-8000-000000000010','13500000-0000-4000-8000-000000000003');
select extensions.throws_ok($$insert into public.provider_commission_forecast_reconciliations(provider_organization_id,forecast_id,payable_event_id,forecast_amount_minor,official_amount_minor,variance_minor,reason,correlation_id,reconciled_by)values('13510000-0000-4000-8000-000000000002','13530000-0000-4000-8000-000000000001','13570000-0000-4000-8000-000000000011',1000,1100,100,'Duplicate forecast','13560000-0000-4000-8000-000000000011','13500000-0000-4000-8000-000000000003')$$,'23505'::char(5),null,'a forecast cannot be reconciled twice');
select extensions.throws_ok($$insert into public.provider_commission_forecast_reconciliations(provider_organization_id,forecast_id,payable_event_id,forecast_amount_minor,official_amount_minor,variance_minor,reason,correlation_id,reconciled_by)values('13510000-0000-4000-8000-000000000002','13530000-0000-4000-8000-000000000002','13570000-0000-4000-8000-000000000010',2000,2100,100,'Duplicate payable','13560000-0000-4000-8000-000000000012','13500000-0000-4000-8000-000000000003')$$,'23505'::char(5),null,'a payable event cannot reconcile two forecasts');
set session_replication_role=origin;

reset role;
create or replace function private.franchise_digest_role_access(p_franchise_id uuid,p_allow_platform_admin boolean default true,p_actor uuid default auth.uid()) returns boolean language sql stable security definer set search_path=pg_catalog as $$select true$$;
set session_replication_role=replica;
insert into public.franchises(id,library_id,operator_organization_id,franchise_type,operator_code,territory_code,status,created_by) values('13590000-0000-4000-8000-000000000001','135e0000-0000-4000-8000-000000000001','13510000-0000-4000-8000-000000000002','STANDARD','FRANCHISEE','P135','ACTIVE','13500000-0000-4000-8000-000000000003');
insert into public.franchise_daily_digest_policy_versions(id,version,status,max_attempts,base_backoff_seconds,max_backoff_seconds,max_pipeline_stages,effective_from,content_hash,change_reason,created_by) values('135a0000-0000-4000-8000-000000000001',135,'RETIRED',3,30,300,10,clock_timestamp()-interval '1 day',repeat('d',64),'Fixture lease P135','13500000-0000-4000-8000-000000000003');
insert into public.franchise_daily_digest_config_versions(id,franchise_id,recipient_user_id,version,policy_version_id,enabled,frequency,local_send_time,time_zone,locale,change_reason,content_hash,created_by) values('135d0000-0000-4000-8000-000000000001','13590000-0000-4000-8000-000000000001','13500000-0000-4000-8000-000000000003',1,'135a0000-0000-4000-8000-000000000001',true,'DAILY','09:00','Africa/Casablanca','fr-MA','Fixture lease P135',repeat('e',64),'13500000-0000-4000-8000-000000000003');
insert into public.franchise_daily_digests(id,franchise_id,organization_id,digest_date,locale,policy_version_id,metrics_snapshot,snapshot_hash,correlation_id) values('13580000-0000-4000-8000-000000000001','13590000-0000-4000-8000-000000000001','13510000-0000-4000-8000-000000000002',current_date,'fr-MA','135a0000-0000-4000-8000-000000000001','{}',repeat('c',64),'135b0000-0000-4000-8000-000000000001');
insert into public.franchise_daily_digest_jobs(id,digest_id,franchise_id,recipient_user_id,config_version_id,status,next_attempt_at) values('135c0000-0000-4000-8000-000000000001','13580000-0000-4000-8000-000000000001','13590000-0000-4000-8000-000000000001','13500000-0000-4000-8000-000000000003','135d0000-0000-4000-8000-000000000001','QUEUED',clock_timestamp()-interval '1 minute');
set session_replication_role=origin;
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into p135_observed select 'claim',value from public.claim_franchise_daily_digest_jobs('13570000-0000-4000-8000-000000000001',1,60)value;
reset role;
select is((select (value->>'row_version')::integer from p135_observed where key='claim'),2,'claim returns post-claim row version');
select ok((select j.row_version=2 and j.status='CLAIMED' and j.lease_token=(o.value->>'lease_token')::uuid from public.franchise_daily_digest_jobs j join p135_observed o on o.key='claim' where j.id='135c0000-0000-4000-8000-000000000001'),'claim response matches persisted lease');
select is((select count(*)::integer from public.event_outbox where aggregate_id='135c0000-0000-4000-8000-000000000001' and event_type='FranchiseDailyDigestClaimedV1'),1,'claim emits one Outbox event');

select * from finish();
rollback;
