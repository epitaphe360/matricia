begin;
set local search_path=public,extensions;
select plan(64);

select has_table('public','provider_reputation_evidence_events','authoritative reputation evidence exists');
select has_table('public','mission_provider_feedback','mission feedback snapshot exists');
select has_column('public','mission_checklist_items','completion_proof_id','checklist completion binds a proof');
select has_column('public','mission_checklist_items','checklist_snapshot_id','checklist item binds the frozen template');
select has_function('public','publish_service_checklist_template',array['uuid','uuid','jsonb','text','text','uuid'],'checklist publication command exists');
select has_function('public','complete_mission_checklist_item',array['uuid','text','uuid','text','uuid'],'checklist execution command exists');
select has_function('public','submit_mission_provider_feedback',array['uuid','integer','integer','integer','jsonb','text','uuid'],'mission feedback command exists');
select has_function('public','refresh_provider_reputation_from_events',array['uuid','uuid','text','text','uuid'],'authoritative reputation refresh exists');
select ok(not has_function_privilege('authenticated','public.calculate_provider_reputation(uuid,uuid,jsonb,jsonb,text,text,uuid)','EXECUTE'),'manual score injection is disabled');
select ok(has_function_privilege('authenticated','public.refresh_provider_reputation_from_events(uuid,uuid,text,text,uuid)','EXECUTE')and not has_function_privilege('anon','public.refresh_provider_reputation_from_events(uuid,uuid,text,text,uuid)','EXECUTE'),'refresh is authenticated only');
select ok((select bool_and(p.prosecdef and p.proconfig::text like'%search_path=pg_catalog%')from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname in('publish_service_checklist_template','complete_mission_checklist_item','submit_mission_provider_feedback','refresh_provider_reputation_from_events')),'commands are security definer with fixed search paths');
select ok(private.valid_published_checklist_items_v1('[{"key":"VERIFY","label_fr":"Vérifier le livrable","label_ar":"التحقق من التسليم","instructions_fr":"Comparer le résultat au périmètre signé.","instructions_ar":"قارن النتيجة بالنطاق الموقع.","proof_required":true,"proof_types":["DOCUMENT"]}]'),'a complete bilingual executable checklist is accepted');
select ok(not private.valid_published_checklist_items_v1('[{"key":"VERIFY","label_fr":"Vérifier","label_ar":"تحقق","proof_required":true,"proof_types":[]}]'),'missing instructions and proof types are rejected');
select ok((select p.prosrc like'%mission_provider_feedback%'and p.prosrc like'%rfq_providers%'and p.prosrc like'%provider_payable_events%'and p.prosrc like'%deliverables%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='refresh_provider_reputation_from_events'),'refresh derives evidence from delivery, feedback, responsiveness and finance sources');
select ok((select p.prosrc like'%ProviderBadgeEvaluationAwaitingHumanReviewV1%'and p.prosrc like'%human_decision_required%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='refresh_provider_reputation_from_events'),'badge recalculation cannot publish without human review');
select ok((select p.prosrc like'%CLEAN_CHECKLIST_PROOF_REQUIRED%'and p.prosrc like'%scan_status=''CLEAN''%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='complete_mission_checklist_item'),'required checklist evidence must be CLEAN and mission-bound');
select col_default_is('public','service_checklist_templates','publication_status','DRAFT','legacy checklist rows are not auto-published');
select ok((select p.prosrc like'%publication_status<>''PUBLISHED''%'and p.prosrc like'%valid_published_checklist_items_v1%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='create_mission'),'mission creation requires an executable published checklist');
select ok((select p.prosrc like'%FEEDBACK_SCORE_NOT_AUTHORITATIVE%'and p.prosrc like'%acceptance_checklists%'and p.prosrc like'%mission_checklist_items%'and p.prosrc like'%COMMUNICATION%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='submit_mission_provider_feedback'),'feedback scores are recomputed from authoritative acceptance, checklist and fixed rubric criteria');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values
('13700000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p137-provider@example.invalid','',now(),'{}','{}',now(),now()),
('13700000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p137-outsider@example.invalid','',now(),'{}','{}',now(),now()),
('13700000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p137-admin@example.invalid','',now(),'{}','{}',now(),now());
insert into public.platform_user_roles(user_id,role_code)values('13700000-0000-4000-8000-000000000003','COMPLIANCE_MANAGER'),('13700000-0000-4000-8000-000000000003','LIBRARY_MANAGER');
insert into public.organizations(id,legal_name,display_name,status,created_by)values
('13710000-0000-4000-8000-000000000001','P137 Provider','P137 Provider','ACTIVE','13700000-0000-4000-8000-000000000001'),
('13710000-0000-4000-8000-000000000002','P137 Outsider','P137 Outsider','ACTIVE','13700000-0000-4000-8000-000000000002');
insert into public.organization_memberships(id,organization_id,user_id,status)values
('13720000-0000-4000-8000-000000000001','13710000-0000-4000-8000-000000000001','13700000-0000-4000-8000-000000000001','ACTIVE'),
('13720000-0000-4000-8000-000000000002','13710000-0000-4000-8000-000000000002','13700000-0000-4000-8000-000000000002','ACTIVE');
insert into public.organization_member_roles(membership_id,role_code)values('13720000-0000-4000-8000-000000000001','PROVIDER_OWNER'),('13720000-0000-4000-8000-000000000002','CLIENT_OWNER');
insert into public.provider_profiles(provider_organization_id,activity_summary,team_size,years_experience,created_by)values('13710000-0000-4000-8000-000000000001','Prestataire fixture P137',2,3,'13700000-0000-4000-8000-000000000001');
insert into public.provider_reputation_evidence_events(id,provider_organization_id,source_type,source_id,dimension,score_basis_points,source_snapshot,content_hash,occurred_at)values('13730000-0000-4000-8000-000000000001','13710000-0000-4000-8000-000000000001','DELIVERY','13740000-0000-4000-8000-000000000001','QUALITY',9000,'{"source":"fixture"}',repeat('a',64),clock_timestamp());
insert into public.provider_reputation_snapshots(id,provider_organization_id,version_number,policy_version,quality_basis_points,delivery_basis_points,compliance_basis_points,responsiveness_basis_points,satisfaction_basis_points,finance_basis_points,overall_basis_points,evidence_count,explanation,evidence_refs,input_hash,calculated_by,correlation_id)values('13760000-0000-4000-8000-000000000001','13710000-0000-4000-8000-000000000001',1,'PROVIDER-REPUTATION-V1',9000,9000,9000,9000,9000,9000,9000,6,'{"source":"fixture"}','["13730000-0000-4000-8000-000000000001"]',repeat('b',64),'13700000-0000-4000-8000-000000000003','13750000-0000-4000-8000-000000000001');
insert into public.provider_badge_evaluations(id,provider_organization_id,badge_policy_id,reputation_snapshot_id,evaluation_version,eligible,evaluated_basis_points,explanation,evaluated_by,correlation_id)select'13770000-0000-4000-8000-000000000001','13710000-0000-4000-8000-000000000001',id,'13760000-0000-4000-8000-000000000001',1,true,9000,'{"human_decision_required":true}','13700000-0000-4000-8000-000000000003','13750000-0000-4000-8000-000000000001'from public.provider_badge_policy_versions order by created_at,id limit 1;

create temporary table p137_observed(key text primary key,value integer);grant select,insert on p137_observed to authenticated;grant usage on schema extensions to authenticated,service_role;grant execute on all functions in schema extensions to authenticated,service_role;
set local role authenticated;select set_config('request.jwt.claims','{"sub":"13700000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into p137_observed values('provider_read',(select count(*)from public.provider_reputation_evidence_events));
select set_config('request.jwt.claims','{"sub":"13700000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);
insert into p137_observed values('outsider_read',(select count(*)from public.provider_reputation_evidence_events));
select throws_ok($$select public.refresh_provider_reputation_from_events('13710000-0000-4000-8000-000000000001',null,'PROVIDER-REPUTATION-V1','p137-outsider-refresh','13750000-0000-4000-8000-000000000001')$$,'42501'::char(5),'AUTHORITATIVE_REPUTATION_REFRESH_DENIED','tenant user cannot run platform reputation refresh');
reset role;
select is((select value from p137_observed where key='provider_read'),1,'provider reads its own authoritative evidence');
select is((select value from p137_observed where key='outsider_read'),0,'unrelated tenant cannot read provider evidence');
select throws_ok($$update public.provider_reputation_evidence_events set score_basis_points=1 where id='13730000-0000-4000-8000-000000000001'$$,'55000'::char(5),'IMMUTABLE_PROVIDER_REPUTATION_RECORD','authoritative evidence is immutable');
select ok(not has_table_privilege('authenticated','public.provider_reputation_evidence_events','INSERT')and not has_table_privilege('authenticated','public.mission_provider_feedback','UPDATE'),'direct evidence and feedback mutation is denied');
select ok((select count(*)=2 from pg_trigger where tgname in('mission_provider_feedback_immutable_v1','provider_reputation_evidence_immutable_v1')and not tgisinternal),'feedback and evidence histories are immutable');
select ok((select count(*)=2 from pg_policies where schemaname='public'and tablename in('mission_provider_feedback','provider_reputation_evidence_events')),'new sensitive tables have explicit RLS policies');

create temporary table p137_badge(key text primary key,value jsonb);grant select,insert on p137_badge to authenticated;
set local role authenticated;select set_config('request.jwt.claims','{"sub":"13700000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
select throws_ok($$select public.decide_provider_badge('13770000-0000-4000-8000-000000000001','PUBLISHED','Revue humaine documentée','p137-badge-publish','13750000-0000-4000-8000-000000000002')$$,'42501'::char(5),'HUMAN_BADGE_DECISION_REQUIRED','AAL1 cannot publish a provider badge');
select set_config('request.jwt.claims','{"sub":"13700000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal2"}',true);
insert into p137_badge values('first',public.decide_provider_badge('13770000-0000-4000-8000-000000000001','PUBLISHED','Revue humaine documentée','p137-badge-publish','13750000-0000-4000-8000-000000000002'));
insert into p137_badge values('replay',public.decide_provider_badge('13770000-0000-4000-8000-000000000001','PUBLISHED','Revue humaine documentée','p137-badge-publish','13750000-0000-4000-8000-000000000002'));
reset role;
select is((select value->>'outcome'from p137_badge where key='first'),'PROVIDER_BADGE_DECIDED','AAL2 human publishes an eligible badge');
select is((select value from p137_badge where key='replay'),(select value from p137_badge where key='first'),'badge decision replay is returned before mutable transition guards');
select is((select count(*)::integer from public.provider_badge_decisions where evaluation_id='13770000-0000-4000-8000-000000000001'),1,'badge replay creates no duplicate decision');
select is((select count(*)::integer from public.audit_events where resource_type='provider_badge_decision'and resource_id=(select value->>'decision_id'from p137_badge where key='first')),1,'badge decision is audited once');
select is((select count(*)::integer from public.event_outbox where aggregate_type='provider_badge'and aggregate_id='13770000-0000-4000-8000-000000000001'and event_type='ProviderBadgePublishedV1'),1,'badge decision is outboxed once');

-- Self-contained published catalogue: a fresh local database deliberately has
-- no production catalogue seed, so this fixture creates a complete valid tree.
insert into public.catalog_libraries(id,code,slug,steward_organization_id,status,created_by)values('137a0000-0000-4000-8000-000000000001','P137_LIBRARY','p137-library','13710000-0000-4000-8000-000000000002','PUBLISHED','13700000-0000-4000-8000-000000000003');
insert into public.catalog_library_versions(id,library_id,version,status,code,slug,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at)values('137a0000-0000-4000-8000-000000000002','137a0000-0000-4000-8000-000000000001',1,'PUBLISHED','P137_LIBRARY','p137-library','Bibliothèque P137','مكتبة P137','Fixture réputation','بيانات السمعة','badge-check',1,'Publication fixture P137',repeat('1',64),'APPROVED','13700000-0000-4000-8000-000000000003',clock_timestamp(),repeat('2',64),1,'13700000-0000-4000-8000-000000000003',clock_timestamp());
update public.catalog_libraries set current_published_version_id='137a0000-0000-4000-8000-000000000002'where id='137a0000-0000-4000-8000-000000000001';
insert into public.catalog_categories(id,library_id,code,slug,status,created_by)values('137a0000-0000-4000-8000-000000000003','137a0000-0000-4000-8000-000000000001','P137_CATEGORY','p137-category','PUBLISHED','13700000-0000-4000-8000-000000000003');
insert into public.catalog_category_versions(id,category_id,library_id,version,status,code,slug,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at)values('137a0000-0000-4000-8000-000000000004','137a0000-0000-4000-8000-000000000003','137a0000-0000-4000-8000-000000000001',1,'PUBLISHED','P137_CATEGORY','p137-category','Catégorie P137','فئة P137','Fixture catégorie réputation','فئة اختبار السمعة',1,'Publication fixture P137',repeat('3',64),'APPROVED','13700000-0000-4000-8000-000000000003',clock_timestamp(),repeat('4',64),1,'13700000-0000-4000-8000-000000000003',clock_timestamp());
update public.catalog_categories set current_published_version_id='137a0000-0000-4000-8000-000000000004'where id='137a0000-0000-4000-8000-000000000003';
insert into public.catalog_subcategories(id,library_id,category_id,code,slug,status,created_by)values('137a0000-0000-4000-8000-000000000005','137a0000-0000-4000-8000-000000000001','137a0000-0000-4000-8000-000000000003','P137_SUBCATEGORY','p137-subcategory','PUBLISHED','13700000-0000-4000-8000-000000000003');
insert into public.catalog_subcategory_versions(id,subcategory_id,library_id,version,status,category_id,code,slug,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at)values('137a0000-0000-4000-8000-000000000006','137a0000-0000-4000-8000-000000000005','137a0000-0000-4000-8000-000000000001',1,'PUBLISHED','137a0000-0000-4000-8000-000000000003','P137_SUBCATEGORY','p137-subcategory','Sous-catégorie P137','فئة فرعية P137','Fixture sous-catégorie réputation','فئة فرعية لاختبار السمعة',1,'Publication fixture P137',repeat('5',64),'APPROVED','13700000-0000-4000-8000-000000000003',clock_timestamp(),repeat('6',64),1,'13700000-0000-4000-8000-000000000003',clock_timestamp());
update public.catalog_subcategories set current_published_version_id='137a0000-0000-4000-8000-000000000006'where id='137a0000-0000-4000-8000-000000000005';
insert into public.catalog_services(id,library_id,primary_subcategory_id,code,slug,status,created_by)values('137a0000-0000-4000-8000-000000000007','137a0000-0000-4000-8000-000000000001','137a0000-0000-4000-8000-000000000005','P137_SERVICE','p137-service','PUBLISHED','13700000-0000-4000-8000-000000000003');
insert into public.catalog_service_versions(id,service_id,library_id,version,status,primary_subcategory_id,code,slug,name_fr,name_ar,short_description_fr,short_description_ar,long_description_fr,long_description_ar,service_type,unit_label_fr,unit_label_ar,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at)values('137a0000-0000-4000-8000-000000000008','137a0000-0000-4000-8000-000000000007','137a0000-0000-4000-8000-000000000001',1,'PUBLISHED','137a0000-0000-4000-8000-000000000005','P137_SERVICE','p137-service','Service réputation P137','خدمة السمعة P137','Service comportemental','خدمة سلوكية','Service complet de validation réputation','خدمة كاملة للتحقق من السمعة','CONSULTING','mission','مهمة',1,'Publication fixture P137',repeat('7',64),'APPROVED','13700000-0000-4000-8000-000000000003',clock_timestamp(),repeat('8',64),1,'13700000-0000-4000-8000-000000000003',clock_timestamp());
update public.catalog_services set current_published_version_id='137a0000-0000-4000-8000-000000000008'where id='137a0000-0000-4000-8000-000000000007';

create temporary table p137_catalog as select sv.id service_version_id,s.id service_id,s.library_id,l.steward_organization_id from public.catalog_service_versions sv join public.catalog_services s on s.id=sv.service_id and s.current_published_version_id=sv.id join public.catalog_libraries l on l.id=s.library_id where sv.status='PUBLISHED' order by sv.created_at,sv.id limit 1;
create temporary table p137_publish(key text primary key,value jsonb);grant select,insert on p137_catalog,p137_publish to authenticated;
select is((select count(*)::integer from p137_catalog),1,'fixture resolves one current published service version and its authoritative steward');
set local role authenticated;select set_config('request.jwt.claims','{"sub":"13700000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
select throws_ok($$select public.publish_service_checklist_template((select steward_organization_id from p137_catalog),(select service_version_id from p137_catalog),'[{"key":"VERIFY_SCOPE","label_fr":"Vérifier le périmètre","label_ar":"التحقق من النطاق","instructions_fr":"Comparer au périmètre contractuel signé.","instructions_ar":"قارن بالنطاق التعاقدي الموقع.","proof_required":true,"proof_types":["DOCUMENT"]}]','Publication comportementale P137','p137-checklist-publish')$$,'42501'::char(5),'CHECKLIST_PUBLISH_DENIED','AAL1 cannot publish a service checklist');
select set_config('request.jwt.claims','{"sub":"13700000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal2"}',true);
insert into p137_publish values('first',public.publish_service_checklist_template((select steward_organization_id from p137_catalog),(select service_version_id from p137_catalog),'[{"key":"VERIFY_SCOPE","label_fr":"Vérifier le périmètre","label_ar":"التحقق من النطاق","instructions_fr":"Comparer au périmètre contractuel signé.","instructions_ar":"قارن بالنطاق التعاقدي الموقع.","proof_required":true,"proof_types":["DOCUMENT"]}]','Publication comportementale P137','p137-checklist-publish'));
insert into p137_publish values('replay',public.publish_service_checklist_template((select steward_organization_id from p137_catalog),(select service_version_id from p137_catalog),'[{"key":"VERIFY_SCOPE","label_fr":"Vérifier le périmètre","label_ar":"التحقق من النطاق","instructions_fr":"Comparer au périmètre contractuel signé.","instructions_ar":"قارن بالنطاق التعاقدي الموقع.","proof_required":true,"proof_types":["DOCUMENT"]}]','Publication comportementale P137','p137-checklist-publish'));
reset role;
select is((select value->>'outcome'from p137_publish where key='first'),'SERVICE_CHECKLIST_PUBLISHED','AAL2 admin publishes an executable checklist');
select is((select value from p137_publish where key='replay'),(select value from p137_publish where key='first'),'checklist publication replay returns the cached response');
select is((select count(*)::integer from public.service_checklist_templates where id=(select(value->>'template_id')::uuid from p137_publish where key='first')and publication_status='PUBLISHED'and published_by='13700000-0000-4000-8000-000000000003'),1,'published checklist persists once with human publication evidence');
select is((select count(*)::integer from public.audit_events where resource_type='service_checklist_template'and resource_id=(select value->>'template_id'from p137_publish where key='first')),1,'checklist publication audit is emitted once');

-- Complete transactional behavior: a valid RFQ/quote/contract FK graph feeds
-- mission creation, the trusted proof scan gates acceptance, and only derived
-- mission/finance events can refresh reputation and reach human badge review.
insert into public.provider_services(id,provider_organization_id,service_id,request_status,requested_by,requested_at)
select '13780000-0000-4000-8000-000000000001','13710000-0000-4000-8000-000000000001',service_id,'DECIDED','13700000-0000-4000-8000-000000000001',clock_timestamp() from p137_catalog;

set local session_replication_role=replica;
insert into public.service_requests(id,client_organization_id,library_id,service_id,status,created_by)
select '13780000-0000-4000-8000-000000000010','13710000-0000-4000-8000-000000000002',library_id,service_id,'CONTRACTED','13700000-0000-4000-8000-000000000002' from p137_catalog;
insert into public.service_request_versions(id,request_id,client_organization_id,library_id,version_number,description,urgency,currency_code,required_quote_data,required_fields_complete,catalog_snapshot_hash,questionnaire_snapshot_hash,change_reason,content_hash,created_by)
select '13780000-0000-4000-8000-000000000011','13780000-0000-4000-8000-000000000010','13710000-0000-4000-8000-000000000002',library_id,1,'Demande comportementale réputation P137','NORMAL','MAD','{}',true,repeat('1',64),repeat('2',64),'Fixture complète P137',repeat('3',64),'13700000-0000-4000-8000-000000000002' from p137_catalog;
update public.service_requests set current_version_id='13780000-0000-4000-8000-000000000011' where id='13780000-0000-4000-8000-000000000010';
insert into public.matching_runs(id,request_id,request_version_id,policy_version,status,target_panel_size,started_by,completed_at)
values('13780000-0000-4000-8000-000000000012','13780000-0000-4000-8000-000000000010','13780000-0000-4000-8000-000000000011','MATCH-V1','COMPLETED',1,'13700000-0000-4000-8000-000000000002',clock_timestamp());
insert into public.matching_candidates(id,matching_run_id,provider_organization_id,eligible,score_basis_points,score_explanation,rotation_component)
values('13780000-0000-4000-8000-000000000013','13780000-0000-4000-8000-000000000012','13710000-0000-4000-8000-000000000001',true,10000,'{"fixture":"P137"}',100);
insert into public.rfqs(id,request_id,request_version_id,matching_run_id,version_number,deadline,status,invited_count,opened_by)
values('13780000-0000-4000-8000-000000000014','13780000-0000-4000-8000-000000000010','13780000-0000-4000-8000-000000000011','13780000-0000-4000-8000-000000000012',1,clock_timestamp()+interval'7 days','OPEN',1,'13700000-0000-4000-8000-000000000002');
insert into public.rfq_providers(id,rfq_id,provider_organization_id,matching_candidate_id,status,invited_at,responded_at)
values('13780000-0000-4000-8000-000000000015','13780000-0000-4000-8000-000000000014','13710000-0000-4000-8000-000000000001','13780000-0000-4000-8000-000000000013','ACCEPTED',clock_timestamp()-interval'1 hour',clock_timestamp());
insert into public.quotes(id,rfq_id,rfq_provider_id,provider_organization_id,status,current_version_id,selected_version_id,created_by)
values('13780000-0000-4000-8000-000000000016','13780000-0000-4000-8000-000000000014','13780000-0000-4000-8000-000000000015','13710000-0000-4000-8000-000000000001','SELECTED','13780000-0000-4000-8000-000000000017','13780000-0000-4000-8000-000000000017','13700000-0000-4000-8000-000000000001');
insert into public.quote_versions(id,quote_id,rfq_id,provider_organization_id,version_number,lifecycle_status,change_reason,currency,solution_fr,deliverables,warranty_fr,correction_terms_fr,proposed_start_date,duration_days,valid_until,subtotal_minor,tax_minor,total_minor,recurring_subtotal_minor,calculation_basis,content_hash,submitted_at,created_by)
values('13780000-0000-4000-8000-000000000017','13780000-0000-4000-8000-000000000016','13780000-0000-4000-8000-000000000014','13710000-0000-4000-8000-000000000001',1,'SUBMITTED','Offre comportementale P137','MAD','Exécution complète P137','[{"key":"D1"}]','Garantie P137','Correction P137',current_date,7,clock_timestamp()+interval'30 days',100000,20000,120000,0,'{}',repeat('4',64),clock_timestamp(),'13700000-0000-4000-8000-000000000001');
insert into public.contracts(id,client_organization_id,provider_organization_id,status,current_version,created_by)
values('13780000-0000-4000-8000-000000000018','13710000-0000-4000-8000-000000000002','13710000-0000-4000-8000-000000000001','ACTIVE',1,'13700000-0000-4000-8000-000000000002');
insert into public.contract_versions(id,contract_id,version,selected_quote_version_id,request_snapshot,quote_snapshot,clauses,price_minor,currency,commission_rule_snapshot,content_hash,change_reason,created_by)
select '13780000-0000-4000-8000-000000000019','13780000-0000-4000-8000-000000000018',1,'13780000-0000-4000-8000-000000000017',jsonb_build_object('service_version_id',service_version_id),'{"quote_version_id":"13780000-0000-4000-8000-000000000017"}','{}',120000,'MAD','{"commission_basis_points":1000}',repeat('5',64),'Contrat comportemental P137','13700000-0000-4000-8000-000000000002' from p137_catalog;
set local session_replication_role=origin;
select is((select count(*)::integer from public.contract_versions cv join public.quote_versions qv on qv.id=cv.selected_quote_version_id join public.quotes q on q.id=qv.quote_id join public.rfq_providers rp on rp.id=q.rfq_provider_id and rp.rfq_id=q.rfq_id and rp.provider_organization_id=q.provider_organization_id join public.rfqs r on r.id=q.rfq_id join public.matching_runs mr on mr.id=r.matching_run_id and mr.request_id=r.request_id join public.service_request_versions srv on srv.id=r.request_version_id and srv.request_id=r.request_id join public.service_requests sr on sr.id=r.request_id join p137_catalog c on c.service_id=sr.service_id and c.library_id=sr.library_id where cv.id='13780000-0000-4000-8000-000000000019'),1,'fixture contract resolves through a complete valid request, matching, RFQ and quote FK graph');

create temporary table p137_flow(key text primary key,value jsonb);grant select,insert on p137_flow to authenticated,service_role;
set local role authenticated;select set_config('request.jwt.claims','{"sub":"13700000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);
insert into p137_flow values('mission',public.create_mission(
 '13780000-0000-4000-8000-000000000018','13780000-0000-4000-8000-000000000019',
 '[{"key":"M1","title_fr":"Réception finale","title_ar":"الاستلام النهائي","sort_order":1,"due_at":"2027-01-01T12:00:00Z","owner_organization_id":"13710000-0000-4000-8000-000000000001","validation_required":true}]',
 '[{"key":"D1","label_fr":"Rapport final","label_ar":"التقرير النهائي","proof_required":true}]',
 '[{"deliverable_key":"D1","criterion_key":"QUALITY"}]','p137-flow-mission-create','13790000-0000-4000-8000-000000000001'));
reset role;
create temporary table p137_ids as select
 (select(value->>'mission_id')::uuid from p137_flow where key='mission') mission_id,
 (select d.id from public.deliverables d where d.mission_id=(select(value->>'mission_id')::uuid from p137_flow where key='mission')and d.deliverable_key='D1') deliverable_id,
 (select mm.id from public.mission_milestones mm where mm.mission_id=(select(value->>'mission_id')::uuid from p137_flow where key='mission')and mm.milestone_key='M1') milestone_id,
 (select ci.id from public.mission_checklist_items ci where ci.mission_id=(select(value->>'mission_id')::uuid from p137_flow where key='mission')and ci.item_key='VERIFY_SCOPE') checklist_item_id;
update public.deliverables d set milestone_id=i.milestone_id from p137_ids i where d.id=i.deliverable_id;
grant select on p137_ids to authenticated,service_role;
select is((select value->>'outcome'from p137_flow where key='mission'),'MISSION_CREATED','happy path creates a mission through the governed command');
select ok((select count(*)=1 from public.mission_checklist_snapshots s join public.mission_checklist_items i on i.checklist_snapshot_id=s.id join p137_ids x on x.mission_id=s.mission_id where i.id=x.checklist_item_id and i.proof_required and i.allowed_proof_types=array['DOCUMENT']::text[]),'mission freezes one executable published checklist item');

set local role authenticated;select set_config('request.jwt.claims','{"sub":"13700000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into storage.objects(bucket_id,name,owner_id,metadata)select'delivery-proofs','13700000-0000-4000-8000-000000000001/'||deliverable_id::text||'/p137-flow.pdf','13700000-0000-4000-8000-000000000001','{"mimetype":"application/pdf"}' from p137_ids;
insert into p137_flow select'delivery',public.submit_delivery(deliverable_id,'Rapport final vérifiable','[]',jsonb_build_array(jsonb_build_object('type','DOCUMENT','storage_path','13700000-0000-4000-8000-000000000001/'||deliverable_id::text||'/p137-flow.pdf','evidence_hash',repeat('c',64),'metadata',jsonb_build_object('mime_type','application/pdf'))),'p137-flow-delivery-submit','13790000-0000-4000-8000-000000000002')from p137_ids;
insert into p137_flow select'milestone-submit',public.submit_mission_milestone(milestone_id,1,'p137-flow-milestone-submit','13790000-0000-4000-8000-000000000003')from p137_ids;
reset role;
alter table p137_ids add column proof_id uuid;
update p137_ids x set proof_id=p.id from public.delivery_proofs p join public.delivery_versions v on v.id=p.delivery_version_id where v.deliverable_id=x.deliverable_id and v.version=1;
select is((select value->>'outcome'from p137_flow where key='delivery'),'DELIVERY_SUBMITTED','provider submits a storage-bound delivery proof');
select is((select value->>'outcome'from p137_flow where key='milestone-submit'),'MILESTONE_SUBMITTED','provider submits the governed milestone');

set local role service_role;select set_config('request.jwt.claims','{"role":"service_role","aal":"aal2"}',true);
create temporary table p137_scan_claim on commit drop as select c.* from public.claim_delivery_proof_scan_jobs('13790000-0000-4000-8000-000000000010',2,300)c join p137_ids i on i.proof_id=c.proof_id;
select is((select count(*)::integer from p137_scan_claim),1,'trusted scanner claims the pending proof once');
insert into p137_flow select'scan',public.complete_delivery_proof_scan_job(i.proof_id,c.lease_token,c.worker_id,c.row_version,'CLEAN','TEST_AV','1.0',repeat('c',64),'p137-flow-scan-clean','13790000-0000-4000-8000-000000000004')from p137_scan_claim c join p137_ids i on i.proof_id=c.proof_id;
reset role;
select is((select value->>'result'from p137_flow where key='scan'),'CLEAN','trusted scanner records the clean verdict');
select is((select p.scan_status from public.delivery_proofs p join p137_ids i on i.proof_id=p.id),'CLEAN','clean verdict is projected on the immutable proof');

set local role authenticated;select set_config('request.jwt.claims','{"sub":"13700000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into p137_flow select'checklist',public.complete_mission_checklist_item(checklist_item_id,'PENDING',proof_id,'p137-flow-checklist-complete','13790000-0000-4000-8000-000000000005')from p137_ids;
insert into p137_flow select'checklist-replay',public.complete_mission_checklist_item(checklist_item_id,'PENDING',proof_id,'p137-flow-checklist-complete','13790000-0000-4000-8000-000000000005')from p137_ids;
reset role;
select is((select value->>'outcome'from p137_flow where key='checklist'),'MISSION_CHECKLIST_ITEM_COMPLETED','provider completes the snapshotted checklist with the clean proof');
select is((select value from p137_flow where key='checklist-replay'),(select value from p137_flow where key='checklist'),'checklist completion replay is cached before the mutable guard');

set local role authenticated;select set_config('request.jwt.claims','{"sub":"13700000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);
insert into p137_flow select'accept',public.accept_delivery(deliverable_id,'[{"criterion_key":"QUALITY","status":"COMPLIANT","comment":"Conforme au contrat","evidence":[]}]','p137-flow-delivery-accept','13790000-0000-4000-8000-000000000006')from p137_ids;
insert into p137_flow select'accept-replay',public.accept_delivery(deliverable_id,'[{"criterion_key":"QUALITY","status":"COMPLIANT","comment":"Conforme au contrat","evidence":[]}]','p137-flow-delivery-accept','13790000-0000-4000-8000-000000000006')from p137_ids;
insert into p137_flow select'milestone-accept',public.decide_mission_milestone(milestone_id,2,'ACCEPTED','Réception client documentée','p137-flow-milestone-accept','13790000-0000-4000-8000-000000000007')from p137_ids;
reset role;
select is((select value->>'outcome'from p137_flow where key='accept'),'DELIVERY_ACCEPTED','client accepts only after proof and checklist completion');
select is((select value from p137_flow where key='accept-replay'),(select value from p137_flow where key='accept'),'delivery acceptance replay is cached after the state transition');
select is((select value->>'outcome'from p137_flow where key='milestone-accept'),'MILESTONE_ACCEPTED','client accepts the milestone after its delivery');
select is((select m.status from public.missions m join p137_ids i on i.mission_id=m.id),'COMPLETED','accepted delivery completes the mission');

set local role authenticated;select set_config('request.jwt.claims','{"sub":"13700000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into p137_flow select'payable',public.record_provider_payable_event(mission_id,'CLIENT_RECEIPT_CONFIRMED',current_date,'MAD',120000,'P137-RECEIPT',repeat('d',64),'p137-flow-payable','13790000-0000-4000-8000-000000000008')from p137_ids;
reset role;
select is((select value->>'outcome'from p137_flow where key='payable'),'PROVIDER_PAYABLE_RECORDED','provider finance event is recorded through the governed exact-money command');

set local role authenticated;select set_config('request.jwt.claims','{"sub":"13700000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);
insert into p137_flow select'feedback',public.submit_mission_provider_feedback(mission_id,10000,10000,10000,'{"summary_code":"MISSION_SUCCESS","criteria":[{"key":"COMMUNICATION","rating":5},{"key":"PROFESSIONALISM","rating":5},{"key":"VALUE","rating":5}]}','p137-flow-feedback','13790000-0000-4000-8000-000000000009')from p137_ids;
reset role;
select is((select value->>'outcome'from p137_flow where key='feedback'),'MISSION_PROVIDER_FEEDBACK_SUBMITTED','client feedback passes only with server-derived scores');
select ok((select f.quality_basis_points=10000 and f.compliance_basis_points=10000 and f.satisfaction_basis_points=10000 from public.mission_provider_feedback f join p137_ids i on i.mission_id=f.mission_id),'persisted feedback equals acceptance, checklist and fixed-rubric derivation');

set local role authenticated;select set_config('request.jwt.claims','{"sub":"13700000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal2"}',true);
insert into p137_flow select'refresh',public.refresh_provider_reputation_from_events('13710000-0000-4000-8000-000000000001',service_id,'PROVIDER-REPUTATION-V1','p137-flow-reputation-refresh','13790000-0000-4000-8000-000000000011')from p137_catalog;
reset role;
select is((select value->>'outcome'from p137_flow where key='refresh'),'PROVIDER_REPUTATION_REFRESHED_FROM_EVENTS','AAL2 refresh builds reputation from authoritative events');
select is((select count(distinct dimension)::integer from public.provider_reputation_evidence_events e,p137_catalog c where e.provider_organization_id='13710000-0000-4000-8000-000000000001'and e.service_id=c.service_id),6,'refresh materializes all six authoritative dimensions');
select ok((select s.version_number=1 and s.overall_basis_points=10000 and s.evidence_count>=8 from public.provider_reputation_snapshots s,p137_catalog c where s.id=(select(value->>'snapshot_id')::uuid from p137_flow where key='refresh')and s.service_id=c.service_id),'refresh creates a versioned service reputation snapshot from complete evidence');
select ok((select count(*)>=1 from public.provider_badge_evaluations e where e.reputation_snapshot_id=(select(value->>'snapshot_id')::uuid from p137_flow where key='refresh')and e.eligible),'refresh creates eligible evaluations pending human review');

create temporary table p137_flow_badge as select e.id evaluation_id from public.provider_badge_evaluations e where e.reputation_snapshot_id=(select(value->>'snapshot_id')::uuid from p137_flow where key='refresh')and e.eligible order by e.id limit 1;grant select on p137_flow_badge to authenticated;
set local role authenticated;select set_config('request.jwt.claims','{"sub":"13700000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
select throws_ok($$select public.decide_provider_badge((select evaluation_id from p137_flow_badge),'PUBLISHED','Validation humaine complète P137','p137-flow-badge-publish','13790000-0000-4000-8000-000000000012')$$,'42501'::char(5),'HUMAN_BADGE_DECISION_REQUIRED','fresh badge evaluation rejects an AAL1 decision');
select set_config('request.jwt.claims','{"sub":"13700000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal2"}',true);
insert into p137_flow select'flow-badge',public.decide_provider_badge(evaluation_id,'PUBLISHED','Validation humaine complète P137','p137-flow-badge-publish','13790000-0000-4000-8000-000000000012')from p137_flow_badge;
insert into p137_flow select'flow-badge-replay',public.decide_provider_badge(evaluation_id,'PUBLISHED','Validation humaine complète P137','p137-flow-badge-publish','13790000-0000-4000-8000-000000000012')from p137_flow_badge;
reset role;
select is((select value->>'outcome'from p137_flow where key='flow-badge'),'PROVIDER_BADGE_DECIDED','AAL2 human review publishes the event-derived badge');
select is((select value from p137_flow where key='flow-badge-replay'),(select value from p137_flow where key='flow-badge'),'fresh badge replay returns the exact cached decision');
select ok((select count(*)>=8 from public.audit_events where correlation_id::text like'13790000-0000-4000-8000-%'),'full sensitive chain appends audit events');
select ok((select count(*)>=9 from public.event_outbox where correlation_id::text like'13790000-0000-4000-8000-%'),'full sensitive chain appends versioned Outbox events');

select*from finish();rollback;
