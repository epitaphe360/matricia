begin;
set local search_path=public,extensions;
select plan(51);

select ok((select count(*)=23 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relname=any(array[
  'contract_authority_snapshots','contract_lifecycle_terms','contract_annex_versions','contract_obligation_definitions','contract_obligation_events','probative_notices','probative_notice_delivery_events','contract_lifecycle_events',
  'dispute_opening_snapshots','legal_evidence_holds','dispute_conflict_disclosures','dispute_reviewer_assignments','dispute_appeal_reviews',
  'franchise_governance_evidence','franchise_catalog_change_evidence','franchise_conflict_disclosures','franchise_favoritism_reviews','franchise_corrective_plan_versions','franchise_corrective_plan_events',
  'marketing_brand_authorizations','social_connection_security_versions','marketing_kill_switch_versions','marketing_publication_journal'
])),'all V4.1 legal governance and marketing records exist');
select ok((select count(*)=23 and bool_and(c.relrowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname=any(array[
  'contract_authority_snapshots','contract_lifecycle_terms','contract_annex_versions','contract_obligation_definitions','contract_obligation_events','probative_notices','probative_notice_delivery_events','contract_lifecycle_events',
  'dispute_opening_snapshots','legal_evidence_holds','dispute_conflict_disclosures','dispute_reviewer_assignments','dispute_appeal_reviews',
  'franchise_governance_evidence','franchise_catalog_change_evidence','franchise_conflict_disclosures','franchise_favoritism_reviews','franchise_corrective_plan_versions','franchise_corrective_plan_events',
  'marketing_brand_authorizations','social_connection_security_versions','marketing_kill_switch_versions','marketing_publication_journal'
])),'RLS is enabled on every exposed V4.1 table');
select ok(not has_table_privilege('authenticated','public.probative_notices','INSERT') and not has_table_privilege('authenticated','public.marketing_kill_switch_versions','UPDATE'),'authenticated cannot bypass governed commands');
select ok(not has_table_privilege('anon','public.dispute_opening_snapshots','SELECT'),'anonymous cannot read legal evidence');
select ok((select count(*)>=20 from pg_trigger where not tgisinternal and tgname like 'v41_%_immutable'),'critical histories are immutable');

select ok(exists(select 1 from pg_constraint where conrelid='public.probative_notices'::regclass and contype='c' and pg_get_constraintdef(oid) like '%QUALIFIED_DELIVERY%' and pg_get_constraintdef(oid) like '%EMAIL%'),'ordinary email cannot be represented as qualified delivery');
select ok(exists(select 1 from pg_constraint where conrelid='public.contract_lifecycle_terms'::regclass and contype='c' and pg_get_constraintdef(oid) like '%effective_at%'),'contract lifecycle terms validate effective dates');
select ok(exists(select 1 from pg_constraint where conrelid='public.dispute_reviewer_assignments'::regclass and contype='c' and pg_get_constraintdef(oid) like '%HUMAN%'),'dispute decisions remain assigned to human reviewers');
select ok(exists(select 1 from pg_trigger where tgrelid='public.dispute_cases'::regclass and tgname='v41_dispute_opening_snapshot' and not tgisinternal),'opening a dispute automatically freezes a scoped evidence snapshot');
select ok(exists(select 1 from pg_constraint where conrelid='public.franchise_catalog_change_evidence'::regclass and contype='c' and pg_get_constraintdef(oid) like '%FINANCIAL%' and pg_get_constraintdef(oid) like '%CONTRACTUAL%'),'sensitive franchise changes are distinguished');
select ok(exists(select 1 from pg_constraint where conrelid='public.marketing_publication_journal'::regclass and contype='c' and pg_get_constraintdef(oid) like '%content_hash%'),'published content journal requires a cryptographic hash');

select ok((select count(*)=8 and bool_and(p.prosecdef) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname=any(array['record_contract_authority_v41','record_marketing_brand_authorization_v41','record_social_connection_security_v41','record_probative_contract_notice_v41','assign_dispute_reviewer_v41','set_marketing_kill_switch_v41','claim_social_publication_job_v41','record_social_publication_result_v41'])),'V4.1 commands enforce server authorization');
select ok(has_function_privilege('authenticated','public.record_contract_authority_v41(uuid,uuid,uuid,text,text,text,timestamptz,timestamptz,timestamptz,text,uuid)','EXECUTE') and not has_function_privilege('anon','public.record_contract_authority_v41(uuid,uuid,uuid,text,text,text,timestamptz,timestamptz,timestamptz,text,uuid)','EXECUTE'),'contract authority provisioning is authenticated and governed');
select ok(has_function_privilege('authenticated','public.record_marketing_brand_authorization_v41(uuid,text,text[],text,text,timestamptz,timestamptz,text,uuid)','EXECUTE') and not has_function_privilege('anon','public.record_marketing_brand_authorization_v41(uuid,text,text[],text,text,timestamptz,timestamptz,text,uuid)','EXECUTE'),'brand authorization provisioning is authenticated and governed');
select ok(has_function_privilege('authenticated','public.record_social_connection_security_v41(uuid,text,text,text,text[],timestamptz,text,uuid)','EXECUTE') and not has_function_privilege('anon','public.record_social_connection_security_v41(uuid,text,text,text,text[],timestamptz,text,uuid)','EXECUTE'),'vault-reference provisioning is authenticated and governed');
select ok((select count(*)=3 and bool_and(proconfig::text like '%search_path=pg_catalog%')from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname=any(array['record_contract_authority_v41','record_marketing_brand_authorization_v41','record_social_connection_security_v41'])),'all provisioning commands use fixed search paths');
select ok(has_function_privilege('authenticated','public.record_social_publication_result_v41(uuid,text,text,text,text,uuid)','EXECUTE') and not has_function_privilege('anon','public.record_social_publication_result_v41(uuid,text,text,text,text,uuid)','EXECUTE'),'exact published content can only be journalled through the governed command');
select ok(has_function_privilege('authenticated','public.record_probative_contract_notice_v41(uuid,text,integer,uuid,text,text,text,text,text,text,text,jsonb,text,uuid)','EXECUTE'),'contract notice command is authenticated-only');
select ok(not has_function_privilege('anon','public.claim_social_publication_job_v41(uuid,text,uuid)','EXECUTE'),'anonymous cannot claim publication jobs');
select ok((select prosecdef and proconfig::text like '%search_path=pg_catalog%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='claim_social_publication_job_v41'),'publication claim has fixed search path');
select ok(has_function_privilege('authenticated','private.marketing_publication_ready_v41(uuid,text,uuid,uuid)','EXECUTE') and not has_function_privilege('anon','private.marketing_publication_ready_v41(uuid,text,uuid,uuid)','EXECUTE'),'marketing readiness is exposed only to authenticated actors');

select ok(exists(select 1 from pg_constraint where conrelid='public.franchise_economic_rule_versions'::regclass and contype='c' and pg_get_constraintdef(oid) like '%entry_fee_minor = 0%' and pg_get_constraintdef(oid) like '%franchisee_share_bps = 5000%' and pg_get_constraintdef(oid) like '%matricia_share_bps = 0%'),'IT franchise 50/50 and zero entry fee invariant survives V4.1');
select ok(exists(select 1 from pg_constraint where conrelid='public.franchise_mandate_versions'::regclass and contype='c' and pg_get_constraintdef(oid)~'franchisee_share_bps.*neoxa_share_bps.*matricia_share_bps.*10000'),'franchise mandates preserve exact basis-point sums');
select ok((select count(*)>=18 from pg_indexes where schemaname='public' and indexname like 'v41_legal_%'),'new legal/governance operational paths are indexed');
select ok(to_regclass('public.catalog_content_review_findings') is not null,'catalogue has explicit CONTENT_REVIEW_REQUIRED findings');
select ok((select relrowsecurity from pg_class where oid='public.catalog_content_review_findings'::regclass),'catalog review findings use RLS');
select ok(exists(select 1 from pg_constraint where conrelid='public.catalog_content_review_findings'::regclass and contype='c' and pg_get_constraintdef(oid) like '%CONTENT_REVIEW_REQUIRED%'),'catalog review uses the explicit review state');
select ok((select count(*)=6 from pg_policies where schemaname='public' and tablename=any(array['contract_authority_snapshots','probative_notices','dispute_opening_snapshots','franchise_governance_evidence','marketing_brand_authorizations','catalog_content_review_findings'])),'sampled exposed records all have scoped read policies');

select ok((select count(*)=7 and bool_and(prosecdef)from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname=any(array['record_contract_lifecycle_bundle_v41','record_contract_obligation_delivery_v41','record_contract_lifecycle_event_v41','record_probative_notice_delivery_v41','record_dispute_governance_v41','record_franchise_governance_control_v41','record_catalog_content_review_findings_v41'])),'all H2 domain commands exist and enforce server authorization');
select ok(not has_function_privilege('anon','public.record_dispute_governance_v41(uuid,text,jsonb,text,uuid)','EXECUTE')and not has_function_privilege('anon','public.record_franchise_governance_control_v41(uuid,text,jsonb,text,uuid)','EXECUTE'),'anonymous cannot invoke legal or franchise governance commands');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values
('c1140000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v41-admin@example.invalid','',now(),'{}','{}',now(),now()),
('c1140000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v41-a@example.invalid','',now(),'{}','{}',now(),now()),
('c1140000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v41-b@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)values
('ca140000-0000-0000-0000-000000000001','V41 Tenant A','V41 A','ACTIVE','c1140000-0000-0000-0000-000000000002'),
('cb140000-0000-0000-0000-000000000002','V41 Tenant B','V41 B','ACTIVE','c1140000-0000-0000-0000-000000000003');
insert into public.organization_memberships(organization_id,user_id,status,activated_at)values
('ca140000-0000-0000-0000-000000000001','c1140000-0000-0000-0000-000000000002','ACTIVE',now()),
('cb140000-0000-0000-0000-000000000002','c1140000-0000-0000-0000-000000000003','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code)select id,'CLIENT_OWNER'from public.organization_memberships where user_id in('c1140000-0000-0000-0000-000000000002','c1140000-0000-0000-0000-000000000003');
insert into public.platform_user_roles(user_id,role_code)values('c1140000-0000-0000-0000-000000000001','SUPER_ADMIN');

insert into public.marketing_consents(organization_id,purpose,decision,policy_version,evidence_hash,decided_by)values('ca140000-0000-0000-0000-000000000001','SOCIAL_PUBLISHING','GRANTED','V4.1',repeat('a',64),'c1140000-0000-0000-0000-000000000002');
insert into public.marketing_brand_authorizations(id,organization_id,decision,authorization_scope,policy_version,evidence_hash,effective_from,decided_by)values
('c1140000-0000-0000-0000-000000000010','ca140000-0000-0000-0000-000000000001','GRANTED',array['SOCIAL_PUBLISHING'],'V4.1',repeat('b',64),now()-interval'1 day','c1140000-0000-0000-0000-000000000002'),
('c1140000-0000-0000-0000-000000000011','cb140000-0000-0000-0000-000000000002','GRANTED',array['SOCIAL_PUBLISHING'],'V4.1',repeat('c',64),now()-interval'1 day','c1140000-0000-0000-0000-000000000003');
insert into public.social_connections(id,organization_id,provider,status,scopes,credential_reference,connected_by)values('c1140000-0000-0000-0000-000000000020','ca140000-0000-0000-0000-000000000001','LINKEDIN','ACTIVE',array['w_member_social'],'vault://marketing/linkedin-a','c1140000-0000-0000-0000-000000000002');
insert into public.social_connection_security_versions(organization_id,social_connection_id,version,provider,status,vault_credential_reference,ciphertext_fingerprint,approved_scopes,created_by)values('ca140000-0000-0000-0000-000000000001','c1140000-0000-0000-0000-000000000020',1,'LINKEDIN','ACTIVE','vault://marketing/linkedin-a',repeat('d',64),array['w_member_social'],'c1140000-0000-0000-0000-000000000002');
insert into public.social_accounts(id,organization_id,connection_id,provider_account_reference,display_name,status)values('c1140000-0000-0000-0000-000000000021','ca140000-0000-0000-0000-000000000001','c1140000-0000-0000-0000-000000000020','account-v41','V41 account','ACTIVE');
insert into public.marketing_schedule_rules(id,organization_id,social_account_id,version,status,timezone,allowed_slots,content_hash,created_by)values('c1140000-0000-0000-0000-000000000022','ca140000-0000-0000-0000-000000000001','c1140000-0000-0000-0000-000000000021',1,'ACTIVE','UTC','[]',repeat('9',64),'c1140000-0000-0000-0000-000000000002');
insert into public.marketing_calendars(id,organization_id,schedule_rule_id,month_start,status,generated_at,approved_by,approved_at)values('c1140000-0000-0000-0000-000000000023','ca140000-0000-0000-0000-000000000001','c1140000-0000-0000-0000-000000000022',date_trunc('month',current_date)::date,'SCHEDULED',now(),'c1140000-0000-0000-0000-000000000002',now());
insert into public.brand_kits(id,organization_id,status,created_by)values('c1140000-0000-0000-0000-000000000030','ca140000-0000-0000-0000-000000000001','DRAFT','c1140000-0000-0000-0000-000000000002');
insert into public.brand_kit_versions(id,brand_kit_id,version,payload,content_hash,change_reason,created_by)values('c1140000-0000-0000-0000-000000000031','c1140000-0000-0000-0000-000000000030',1,'{"legal_name":"A","trade_name":"A","primary_colors":[],"tone":"PRO","languages":["FR"],"primary_cta":"GO","tracked_url":"https://example.invalid","required_mentions":[],"forbidden_terms":[],"approved_hashtags":[]}',repeat('e',64),'V4.1 test','c1140000-0000-0000-0000-000000000002');
update public.brand_kits set status='READY',current_version_id='c1140000-0000-0000-0000-000000000031'where id='c1140000-0000-0000-0000-000000000030';
insert into public.marketing_templates(id,template_key,status,created_by)values('c1140000-0000-0000-0000-000000000040','PROBLEM_SOLUTION','DRAFT','c1140000-0000-0000-0000-000000000001');
insert into public.marketing_template_versions(id,template_id,version,structure,frequency_max_weekly,content_hash,created_by)values('c1140000-0000-0000-0000-000000000041','c1140000-0000-0000-0000-000000000040',1,'{"hook":"h","body":"b","target_characters":100,"required_media":[],"allowed_ctas":[],"forbidden_claims":[],"translation_rules":{},"repetition_rules":{}}',8,repeat('f',64),'c1140000-0000-0000-0000-000000000001');
update public.marketing_templates set status='ACTIVE',current_version_id='c1140000-0000-0000-0000-000000000041'where id='c1140000-0000-0000-0000-000000000040';
insert into public.marketing_campaigns(id,organization_id,brand_kit_version_id,mode,title_fr,title_ar,status,frequency_max_weekly,risk_threshold,audience_snapshot,source_snapshot,approved_by,approved_at,created_by)values('c1140000-0000-0000-0000-000000000050','ca140000-0000-0000-0000-000000000001','c1140000-0000-0000-0000-000000000031','ASSISTED','Campagne V4.1','حملة','APPROVED',8,20,'{}','{}','c1140000-0000-0000-0000-000000000002',now(),'c1140000-0000-0000-0000-000000000002');
insert into public.marketing_content(id,campaign_id,channel,template_version_id)values
('c1140000-0000-0000-0000-000000000060','c1140000-0000-0000-0000-000000000050','LINKEDIN','c1140000-0000-0000-0000-000000000041'),
('c1140000-0000-0000-0000-000000000061','c1140000-0000-0000-0000-000000000050','FACEBOOK','c1140000-0000-0000-0000-000000000041'),
('c1140000-0000-0000-0000-000000000062','c1140000-0000-0000-0000-000000000050','INSTAGRAM','c1140000-0000-0000-0000-000000000041');
insert into public.marketing_content_versions(id,content_id,version,language,title_internal,hook,body,cta,hashtags,landing_url,compliance_checks,risk_score,status,expires_at,content_hash,created_by)values
('c1140000-0000-0000-0000-000000000070','c1140000-0000-0000-0000-000000000060',1,'FR','Valid','Hook','Body','CTA',array['v41'],'https://example.invalid/v41','{"source":"PASS","brand":"PASS","claims":"PASS","privacy":"PASS","certification":"PASS","promotion":"PASS","duplicate":"PASS","offer":"PASS","price":"PASS","pii":"PASS"}',0,'APPROVED',now()+interval'1 day',repeat('1',64),'c1140000-0000-0000-0000-000000000002'),
('c1140000-0000-0000-0000-000000000071','c1140000-0000-0000-0000-000000000061',1,'FR','Expired','Hook','Body','CTA',array['v41'],'https://example.invalid/v41-expired','{"source":"PASS","brand":"PASS","claims":"PASS","privacy":"PASS","certification":"PASS","promotion":"PASS","duplicate":"PASS","offer":"PASS","price":"PASS","pii":"PASS"}',0,'APPROVED',now()-interval'1 second',repeat('2',64),'c1140000-0000-0000-0000-000000000002'),
('c1140000-0000-0000-0000-000000000072','c1140000-0000-0000-0000-000000000062',1,'FR','Blocked','Hook','Body','CTA',array['v41'],'https://example.invalid/v41-blocked','{"source":"PASS","brand":"PASS","claims":"PASS","privacy":"FAIL","certification":"PASS","promotion":"PASS","duplicate":"PASS","offer":"PASS","price":"PASS","pii":"PASS"}',0,'APPROVED',now()+interval'1 day',repeat('3',64),'c1140000-0000-0000-0000-000000000002');
insert into public.marketing_calendar_items(id,campaign_id,content_version_id,social_connection_id,scheduled_at,status,calendar_id)values
('c1140000-0000-0000-0000-000000000080','c1140000-0000-0000-0000-000000000050','c1140000-0000-0000-0000-000000000070','c1140000-0000-0000-0000-000000000020',now(),'SCHEDULED','c1140000-0000-0000-0000-000000000023'),
('c1140000-0000-0000-0000-000000000081','c1140000-0000-0000-0000-000000000050','c1140000-0000-0000-0000-000000000072','c1140000-0000-0000-0000-000000000020',now()+interval'1 second','SCHEDULED','c1140000-0000-0000-0000-000000000023');
insert into public.social_publication_jobs(id,organization_id,calendar_item_id,provider,status,idempotency_key,available_at)values
('c1140000-0000-0000-0000-000000000090','ca140000-0000-0000-0000-000000000001','c1140000-0000-0000-0000-000000000080','LINKEDIN','QUEUED','v41-valid-job',now()-interval'1 second'),
('c1140000-0000-0000-0000-000000000091','ca140000-0000-0000-0000-000000000001','c1140000-0000-0000-0000-000000000081','LINKEDIN','QUEUED','v41-blocked-job',now()-interval'1 second');

select set_config('request.jwt.claim.sub','c1140000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claims','{"sub":"c1140000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true);
select is(private.marketing_publication_ready_v41('ca140000-0000-0000-0000-000000000001','LINKEDIN','c1140000-0000-0000-0000-000000000020','c1140000-0000-0000-0000-000000000070'),true,'approved unexpired same-tenant compliant content is publishable');
select is(private.marketing_publication_ready_v41('cb140000-0000-0000-0000-000000000002','LINKEDIN','c1140000-0000-0000-0000-000000000020','c1140000-0000-0000-0000-000000000070'),false,'cross-tenant content and connection are denied');
select is(private.marketing_publication_ready_v41('ca140000-0000-0000-0000-000000000001','LINKEDIN','c1140000-0000-0000-0000-000000000020','c1140000-0000-0000-0000-000000000071'),false,'expired content is denied');
select is(private.marketing_publication_ready_v41('ca140000-0000-0000-0000-000000000001','LINKEDIN','c1140000-0000-0000-0000-000000000020','c1140000-0000-0000-0000-000000000072'),false,'failed privacy compliance is denied');
insert into public.marketing_consents(organization_id,purpose,decision,policy_version,evidence_hash,decided_by)values('ca140000-0000-0000-0000-000000000001','SOCIAL_PUBLISHING','WITHDRAWN','V4.1',repeat('4',64),'c1140000-0000-0000-0000-000000000002');
select is(private.marketing_publication_ready_v41('ca140000-0000-0000-0000-000000000001','LINKEDIN','c1140000-0000-0000-0000-000000000020','c1140000-0000-0000-0000-000000000070'),false,'publication without current consent is denied');
insert into public.marketing_consents(organization_id,purpose,decision,policy_version,evidence_hash,decided_by)values('ca140000-0000-0000-0000-000000000001','SOCIAL_PUBLISHING','GRANTED','V4.1',repeat('5',64),'c1140000-0000-0000-0000-000000000002');
select throws_ok($$select public.claim_social_publication_job_v41('c1140000-0000-0000-0000-000000000091','worker-v41')$$,'55000','MARKETING_PUBLICATION_BLOCKED','claim revalidates and blocks noncompliant content');
select lives_ok($$select public.claim_social_publication_job_v41('c1140000-0000-0000-0000-000000000090','worker-v41')$$,'claim accepts valid content');
select lives_ok($$select public.set_marketing_kill_switch_v41(null,'GLOBAL',null,true,'Incident test',repeat('6',64),'kill-v41-enable')$$,'global kill switch can be enabled idempotently');
select throws_ok($$select public.record_social_publication_result_v41('c1140000-0000-0000-0000-000000000090','PUBLISHED','provider-v41',null,'result-v41')$$,'55000','MARKETING_PUBLICATION_BLOCKED','result revalidates current kill switch before publication');
select lives_ok($$select public.set_marketing_kill_switch_v41(null,'GLOBAL',null,false,'Incident resolved',repeat('7',64),'kill-v41-disable')$$,'global kill switch can be released');
select lives_ok($$select public.record_social_publication_result_v41('c1140000-0000-0000-0000-000000000090','PUBLISHED','provider-v41',null,'result-v41')$$,'valid result is recorded after fresh checks');
select lives_ok($$select public.record_social_publication_result_v41('c1140000-0000-0000-0000-000000000090','PUBLISHED','provider-v41',null,'result-v41-replay')$$,'publication result replay is idempotent');
select is((select count(*)from public.marketing_publication_journal where job_id='c1140000-0000-0000-0000-000000000090'),1::bigint,'exact publication journal is append-only and unique');
select is((select count(*)from public.social_publication_results where job_id='c1140000-0000-0000-0000-000000000090'),1::bigint,'result replay creates no duplicate provider result');

create temporary table catalog_rpc_results(payload jsonb);
select set_config('request.jwt.claim.role','service_role',true);
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into catalog_rpc_results select public.record_catalog_content_review_findings_v41('1.0.0',repeat('8',64),'[{"code":"ARABIC_TRANSLATION_MISSING","count":6000,"samples":["Q-1"]}]','catalog-v41-replay');
insert into catalog_rpc_results select public.record_catalog_content_review_findings_v41('1.0.0',repeat('8',64),'[{"code":"ARABIC_TRANSLATION_MISSING","count":6000,"samples":["Q-1"]}]','catalog-v41-replay');
select is((select count(distinct payload->>'audit_run_id')from catalog_rpc_results),1::bigint,'catalog findings RPC replay returns the immutable original audit run');
select is((select count(*)from public.catalog_content_review_findings where source_manifest_hash=repeat('8',64)),1::bigint,'catalog findings replay creates one finding only');
select is((select count(*)from public.audit_events where action='catalog.content_review.persisted'and resource_id=(select payload->>'audit_run_id'from catalog_rpc_results limit 1)),1::bigint,'catalog findings persistence is audited once');
select is((select count(*)from public.event_outbox where event_type='CatalogContentReviewRequiredV1'and aggregate_id=(select payload->>'audit_run_id'from catalog_rpc_results limit 1)),1::bigint,'catalog findings persistence emits one outbox event');
select throws_ok($$select public.record_catalog_content_review_findings_v41('1.0.0',repeat('8',64),'[{"code":"EXPERT_REVIEW_REQUIRED","count":1,"samples":["Q-2"]}]','catalog-v41-replay')$$,'22000','IDEMPOTENCY_PAYLOAD_MISMATCH','catalog findings replay rejects a changed payload');
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','c1140000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"c1140000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true);

create temporary table legal_v41_rls(key text primary key,value bigint);grant insert,select on legal_v41_rls to authenticated;
set local role authenticated;select set_config('request.jwt.claim.sub','c1140000-0000-0000-0000-000000000002',true);
insert into legal_v41_rls values('own',(select count(*)from public.marketing_brand_authorizations where organization_id='ca140000-0000-0000-0000-000000000001')),('foreign',(select count(*)from public.marketing_brand_authorizations where organization_id='cb140000-0000-0000-0000-000000000002'));reset role;
select is((select value from legal_v41_rls where key='own'),1::bigint,'tenant reads its own marketing authorization');
select is((select value from legal_v41_rls where key='foreign'),0::bigint,'tenant cannot read another tenant marketing authorization');

select * from finish();
rollback;
