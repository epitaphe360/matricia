begin;
set local search_path=public,extensions;
select plan(20);

select has_table('public','mission_checklist_snapshots','mission checklist snapshot table exists');
select ok((select relrowsecurity from pg_class where oid='public.mission_checklist_snapshots'::regclass),'snapshot RLS is enabled');
select ok((select count(*)=1 from pg_policies where schemaname='public' and tablename='mission_checklist_snapshots' and policyname='mission_checklist_snapshots_party_read'),'snapshot has one restrictive party policy');
select ok(not has_table_privilege('anon','public.mission_checklist_snapshots','SELECT') and has_table_privilege('authenticated','public.mission_checklist_snapshots','SELECT'),'only authenticated receives snapshot SELECT');
select ok((select count(*)=2 from pg_trigger where tgname in('service_checklist_templates_immutable','mission_checklist_snapshots_immutable') and not tgisinternal),'template and snapshot records are immutable');
select ok((select p.prosecdef and p.proconfig::text like '%search_path=%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_mission'),'mission command remains security-definer with fixed search path');
select ok(has_function_privilege('authenticated','public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid)','EXECUTE') and not has_function_privilege('anon','public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid)','EXECUTE') and not has_function_privilege('service_role','public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid)','EXECUTE'),'mission command ACL remains least privilege');
select ok(exists(select 1 from pg_constraint where conname='contract_versions_service_version_snapshot_required' and conrelid='public.contract_versions'::regclass),'new contract versions must freeze a valid service version identifier');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('fd100000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','mf024-client@example.invalid','',now(),'{}','{}',now(),now()),
('fd100000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','mf024-provider@example.invalid','',now(),'{}','{}',now(),now()),
('fd100000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','mf024-outsider@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by) values
('fd110000-0000-4000-8000-000000000001','MF024 Client','MF024 Client','ACTIVE','fd100000-0000-4000-8000-000000000001'),
('fd110000-0000-4000-8000-000000000002','MF024 Provider','MF024 Provider','ACTIVE','fd100000-0000-4000-8000-000000000002'),
('fd110000-0000-4000-8000-000000000003','MF024 Outsider','MF024 Outsider','ACTIVE','fd100000-0000-4000-8000-000000000003');
insert into public.organization_memberships(id,organization_id,user_id,status) values
('fd120000-0000-4000-8000-000000000001','fd110000-0000-4000-8000-000000000001','fd100000-0000-4000-8000-000000000001','ACTIVE'),
('fd120000-0000-4000-8000-000000000002','fd110000-0000-4000-8000-000000000002','fd100000-0000-4000-8000-000000000002','ACTIVE'),
('fd120000-0000-4000-8000-000000000003','fd110000-0000-4000-8000-000000000003','fd100000-0000-4000-8000-000000000003','ACTIVE');
insert into public.organization_member_roles(membership_id,role_code) values
('fd120000-0000-4000-8000-000000000001','CLIENT_OWNER'),
('fd120000-0000-4000-8000-000000000002','PROVIDER_OWNER'),
('fd120000-0000-4000-8000-000000000003','CLIENT_OWNER');

-- Self-contained two-service catalogue fixture for local databases where the
-- production catalogue bundle is deliberately absent.
insert into public.catalog_libraries(id,code,slug,steward_organization_id,status,created_by)values('fd300000-0000-4000-8000-000000000001','MISSION_CHECK','mission-check','fd110000-0000-4000-8000-000000000001','PUBLISHED','fd100000-0000-4000-8000-000000000001');
insert into public.catalog_library_versions(id,library_id,version,status,code,slug,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at)values('fd300000-0000-4000-8000-000000000002','fd300000-0000-4000-8000-000000000001',1,'PUBLISHED','MISSION_CHECK','mission-check','Bibliothèque mission','مكتبة المهمة','Fixture mission','اختبار المهمة','check-square',1,'Fixture autonome',repeat('1',64),'APPROVED','fd100000-0000-4000-8000-000000000001',now(),repeat('2',64),1,'fd100000-0000-4000-8000-000000000001',now());update public.catalog_libraries set current_published_version_id='fd300000-0000-4000-8000-000000000002'where id='fd300000-0000-4000-8000-000000000001';
insert into public.catalog_categories(id,library_id,code,slug,status,created_by)values('fd300000-0000-4000-8000-000000000003','fd300000-0000-4000-8000-000000000001','MISSION_CAT','mission-cat','PUBLISHED','fd100000-0000-4000-8000-000000000001');
insert into public.catalog_category_versions(id,category_id,library_id,version,status,code,slug,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at)values('fd300000-0000-4000-8000-000000000004','fd300000-0000-4000-8000-000000000003','fd300000-0000-4000-8000-000000000001',1,'PUBLISHED','MISSION_CAT','mission-cat','Catégorie mission','فئة المهمة','Fixture catégorie','فئة اختبار',1,'Fixture autonome',repeat('3',64),'APPROVED','fd100000-0000-4000-8000-000000000001',now(),repeat('4',64),1,'fd100000-0000-4000-8000-000000000001',now());update public.catalog_categories set current_published_version_id='fd300000-0000-4000-8000-000000000004'where id='fd300000-0000-4000-8000-000000000003';
insert into public.catalog_subcategories(id,library_id,category_id,code,slug,status,created_by)values('fd300000-0000-4000-8000-000000000005','fd300000-0000-4000-8000-000000000001','fd300000-0000-4000-8000-000000000003','MISSION_SUB','mission-sub','PUBLISHED','fd100000-0000-4000-8000-000000000001');
insert into public.catalog_subcategory_versions(id,subcategory_id,library_id,version,status,category_id,code,slug,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at)values('fd300000-0000-4000-8000-000000000006','fd300000-0000-4000-8000-000000000005','fd300000-0000-4000-8000-000000000001',1,'PUBLISHED','fd300000-0000-4000-8000-000000000003','MISSION_SUB','mission-sub','Sous-catégorie mission','فئة فرعية','Fixture sous-catégorie','اختبار فرعي',1,'Fixture autonome',repeat('5',64),'APPROVED','fd100000-0000-4000-8000-000000000001',now(),repeat('6',64),1,'fd100000-0000-4000-8000-000000000001',now());update public.catalog_subcategories set current_published_version_id='fd300000-0000-4000-8000-000000000006'where id='fd300000-0000-4000-8000-000000000005';
insert into public.catalog_services(id,library_id,primary_subcategory_id,code,slug,status,created_by)values('fd300000-0000-4000-8000-000000000007','fd300000-0000-4000-8000-000000000001','fd300000-0000-4000-8000-000000000005','MISSION_A','mission-a','PUBLISHED','fd100000-0000-4000-8000-000000000001'),('fd300000-0000-4000-8000-000000000008','fd300000-0000-4000-8000-000000000001','fd300000-0000-4000-8000-000000000005','MISSION_B','mission-b','PUBLISHED','fd100000-0000-4000-8000-000000000001');
insert into public.catalog_service_versions(id,service_id,library_id,version,status,primary_subcategory_id,code,slug,name_fr,name_ar,short_description_fr,short_description_ar,long_description_fr,long_description_ar,service_type,unit_label_fr,unit_label_ar,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at)values
('fd300000-0000-4000-8000-000000000009','fd300000-0000-4000-8000-000000000007','fd300000-0000-4000-8000-000000000001',1,'PUBLISHED','fd300000-0000-4000-8000-000000000005','MISSION_A','mission-a','Mission A','المهمة أ','Service mission A','خدمة المهمة أ','Service mission principal','خدمة المهمة الرئيسية','CONSULTING','jour','يوم',1,'Fixture autonome',repeat('7',64),'APPROVED','fd100000-0000-4000-8000-000000000001',now(),repeat('8',64),1,'fd100000-0000-4000-8000-000000000001',now()),
('fd300000-0000-4000-8000-000000000010','fd300000-0000-4000-8000-000000000008','fd300000-0000-4000-8000-000000000001',1,'PUBLISHED','fd300000-0000-4000-8000-000000000005','MISSION_B','mission-b','Mission B','المهمة ب','Service mission B','خدمة المهمة ب','Service mission secondaire','خدمة المهمة الثانوية','CONSULTING','jour','يوم',2,'Fixture autonome',repeat('9',64),'APPROVED','fd100000-0000-4000-8000-000000000001',now(),repeat('a',64),1,'fd100000-0000-4000-8000-000000000001',now());
update public.catalog_services set current_published_version_id=case id when'fd300000-0000-4000-8000-000000000007'then'fd300000-0000-4000-8000-000000000009'::uuid else'fd300000-0000-4000-8000-000000000010'::uuid end where id in('fd300000-0000-4000-8000-000000000007','fd300000-0000-4000-8000-000000000008');

create temporary table mf024_catalog as
select s.id service_id,s.library_id,s.current_published_version_id service_version_id
from public.catalog_services s
where s.status='PUBLISHED' and s.current_published_version_id is not null
order by s.id limit 1;
select ok((select count(*)=1 from mf024_catalog),'one published service version is available for the isolated fixture');

insert into public.service_checklist_templates(id,service_version_id,version,items,content_hash,created_by,publication_status,published_at,published_by)
select 'fd130000-0000-4000-8000-000000000001',service_version_id,1,
  '[{"key":"PREPARE","label_fr":"Préparer la mission","label_ar":"إعداد المهمة","instructions_fr":"Préparer les éléments nécessaires","instructions_ar":"إعداد العناصر اللازمة","proof_required":false,"proof_types":[]},{"key":"VERIFY","label_fr":"Vérifier la preuve","label_ar":"التحقق من الدليل","instructions_fr":"Vérifier le document transmis","instructions_ar":"التحقق من الوثيقة المرسلة","proof_required":true,"proof_types":["DOCUMENT"]}]'::jsonb,
  repeat('a',64),'fd100000-0000-4000-8000-000000000001','PUBLISHED',clock_timestamp(),'fd100000-0000-4000-8000-000000000001' from mf024_catalog;

create temporary table mf024_other_catalog as
select s.id service_id,s.current_published_version_id service_version_id from public.catalog_services s,mf024_catalog selected
where s.status='PUBLISHED' and s.current_published_version_id is not null and s.id<>selected.service_id order by s.id limit 1;
insert into public.service_checklist_templates(id,service_version_id,version,items,content_hash,created_by,publication_status,published_at,published_by)
select 'fd130000-0000-4000-8000-000000000002',service_version_id,1,
  '[{"key":"OTHER","label_fr":"Autre service","label_ar":"خدمة أخرى","instructions_fr":"Exécuter la checklist de l’autre service","instructions_ar":"تنفيذ قائمة تحقق الخدمة الأخرى","proof_required":false,"proof_types":[]}]'::jsonb,
  repeat('d',64),'fd100000-0000-4000-8000-000000000001','PUBLISHED',clock_timestamp(),'fd100000-0000-4000-8000-000000000001' from mf024_other_catalog;

set local session_replication_role=replica;
insert into public.service_requests(id,client_organization_id,library_id,service_id,status,created_by)
select 'fd140000-0000-4000-8000-000000000001','fd110000-0000-4000-8000-000000000001',library_id,service_id,'CONTRACTED','fd100000-0000-4000-8000-000000000001' from mf024_catalog;
insert into public.rfqs(id,request_id,request_version_id,matching_run_id,status,deadline,invited_count,opened_by)
values('fd150000-0000-4000-8000-000000000001','fd140000-0000-4000-8000-000000000001','fd160000-0000-4000-8000-000000000001','fd170000-0000-4000-8000-000000000001','OPEN',clock_timestamp()+interval'1 day',1,'fd100000-0000-4000-8000-000000000001');
insert into public.quotes(id,rfq_id,rfq_provider_id,provider_organization_id,status,current_version_id,selected_version_id,created_by)
values('fd180000-0000-4000-8000-000000000001','fd150000-0000-4000-8000-000000000001','fd190000-0000-4000-8000-000000000001','fd110000-0000-4000-8000-000000000002','SELECTED','fd200000-0000-4000-8000-000000000001','fd200000-0000-4000-8000-000000000001','fd100000-0000-4000-8000-000000000001');
insert into public.quote_versions(id,quote_id,rfq_id,provider_organization_id,version_number,lifecycle_status,change_reason,currency,solution_fr,deliverables,warranty_fr,correction_terms_fr,proposed_start_date,duration_days,valid_until,subtotal_minor,tax_minor,total_minor,recurring_subtotal_minor,calculation_basis,content_hash,created_by,submitted_at)
values('fd200000-0000-4000-8000-000000000001','fd180000-0000-4000-8000-000000000001','fd150000-0000-4000-8000-000000000001','fd110000-0000-4000-8000-000000000002',1,'SUBMITTED','MF024 quote','MAD','Mission checklist','["Livrable"]','Garantie','Correction','2026-10-01',10,'2027-01-01',10000,2000,12000,0,'{}',repeat('b',64),'fd100000-0000-4000-8000-000000000001',clock_timestamp());
insert into public.contracts(id,client_organization_id,provider_organization_id,status,current_version,created_by)
values('fd210000-0000-4000-8000-000000000001','fd110000-0000-4000-8000-000000000001','fd110000-0000-4000-8000-000000000002','ACTIVE',1,'fd100000-0000-4000-8000-000000000001');
insert into public.contract_versions(id,contract_id,version,selected_quote_version_id,request_snapshot,quote_snapshot,clauses,price_minor,currency,commission_rule_snapshot,content_hash,change_reason,created_by)
select 'fd220000-0000-4000-8000-000000000001','fd210000-0000-4000-8000-000000000001',1,'fd200000-0000-4000-8000-000000000001',jsonb_build_object('service_version_id',service_version_id),jsonb_build_object('quote_version_id','fd200000-0000-4000-8000-000000000001'),'{}'::jsonb,12000,'MAD','{}'::jsonb,repeat('c',64),'MF024 contract','fd100000-0000-4000-8000-000000000001' from mf024_catalog;
insert into public.contracts(id,client_organization_id,provider_organization_id,status,current_version,created_by)
values('fd210000-0000-4000-8000-000000000002','fd110000-0000-4000-8000-000000000001','fd110000-0000-4000-8000-000000000002','ACTIVE',1,'fd100000-0000-4000-8000-000000000001');
insert into public.contract_versions(id,contract_id,version,selected_quote_version_id,request_snapshot,quote_snapshot,clauses,price_minor,currency,commission_rule_snapshot,content_hash,change_reason,created_by)
select 'fd220000-0000-4000-8000-000000000002','fd210000-0000-4000-8000-000000000002',1,'fd200000-0000-4000-8000-000000000001',jsonb_build_object('service_version_id',service_version_id),jsonb_build_object('quote_version_id','fd200000-0000-4000-8000-000000000001'),'{}'::jsonb,12000,'MAD','{}'::jsonb,repeat('e',64),'Spoofed service contract','fd100000-0000-4000-8000-000000000001' from mf024_other_catalog;
set local session_replication_role=origin;

create temporary table mf024_observed(key text primary key,value text);
grant insert,select on table mf024_observed to authenticated;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"fd100000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
create temporary table mf024_result as
select public.create_mission(
  'fd210000-0000-4000-8000-000000000001','fd220000-0000-4000-8000-000000000001',
  '[{"key":"M1","title_fr":"Livraison","title_ar":"التسليم","sort_order":1,"due_at":"2026-11-01T12:00:00Z","validation_required":true}]',
  '[{"key":"D1","label_fr":"Rapport","label_ar":"تقرير","proof_required":true}]',
  '[{"deliverable_key":"D1","criterion_key":"QUALITY"}]',
  'mf024-mission-create','fd230000-0000-4000-8000-000000000001'
) response;
insert into mf024_observed values
('version',(select response->>'checklist_template_version' from mf024_result)),
('snapshots',(select count(*)::text from public.mission_checklist_snapshots)),
('items',(select count(*)::text from public.mission_checklist_items)),
('exact',(select (items='[{"key":"PREPARE","label_fr":"Préparer la mission","label_ar":"إعداد المهمة","instructions_fr":"Préparer les éléments nécessaires","instructions_ar":"إعداد العناصر اللازمة","proof_required":false,"proof_types":[]},{"key":"VERIFY","label_fr":"Vérifier la preuve","label_ar":"التحقق من الدليل","instructions_fr":"Vérifier le document transmis","instructions_ar":"التحقق من الوثيقة المرسلة","proof_required":true,"proof_types":["DOCUMENT"]}]'::jsonb and template_content_hash=repeat('a',64))::text from public.mission_checklist_snapshots));
reset role;
insert into mf024_observed values
('audits',(select count(*)::text from public.audit_events where action='mission.checklist_snapshotted')),
('outbox',(select count(*)::text from public.event_outbox where event_type='MissionChecklistSnapshottedV1'));
select ok((select value='1' from mf024_observed where key='version'),'mission response exposes the frozen checklist version');
select ok((select value='1' from mf024_observed where key='snapshots'),'client sees one immutable checklist snapshot');
select ok((select value='2' from mf024_observed where key='items'),'every versioned template item is copied to the mission');
select ok((select value='true' from mf024_observed where key='exact'),'snapshot preserves exact bilingual content and hash');
select ok((select value='1' from mf024_observed where key='audits'),'snapshot emits one audit event');
select ok((select value='1' from mf024_observed where key='outbox'),'snapshot emits one Outbox event');
select throws_ok($$select public.create_mission('fd210000-0000-4000-8000-000000000002','fd220000-0000-4000-8000-000000000002','[{"key":"M1","title_fr":"Livraison","title_ar":"التسليم","sort_order":1}]','[{"key":"D1","label_fr":"Rapport","label_ar":"تقرير"}]','[{"deliverable_key":"D1","criterion_key":"QUALITY"}]','mf024-spoofed-service','fd230000-0000-4000-8000-000000000002')$$,'22023','MISSION_CHECKLIST_TEMPLATE_REQUIRED','contract snapshot cannot spoof a checklist from another RFQ service');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"fd100000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
select public.create_mission(
  'fd210000-0000-4000-8000-000000000001','fd220000-0000-4000-8000-000000000001',
  '[{"key":"M1","title_fr":"Livraison","title_ar":"التسليم","sort_order":1,"due_at":"2026-11-01T12:00:00Z","validation_required":true}]',
  '[{"key":"D1","label_fr":"Rapport","label_ar":"تقرير","proof_required":true}]',
  '[{"deliverable_key":"D1","criterion_key":"QUALITY"}]',
  'mf024-mission-create','fd230000-0000-4000-8000-000000000001'
);
insert into mf024_observed values('replay-snapshots',(select count(*)::text from public.mission_checklist_snapshots));

select set_config('request.jwt.claims','{"sub":"fd100000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal2"}',true);
insert into mf024_observed values
('outsider-snapshots',(select count(*)::text from public.mission_checklist_snapshots)),
('outsider-items',(select count(*)::text from public.mission_checklist_items));

reset role;
insert into mf024_observed values('replay-audits',(select count(*)::text from public.audit_events where action='mission.checklist_snapshotted'));
select ok((select value='1' from mf024_observed where key='replay-snapshots') and (select value='1' from mf024_observed where key='replay-audits'),'idempotent replay creates no duplicate snapshot or audit');
select ok((select value='0' from mf024_observed where key='outsider-snapshots'),'unrelated tenant cannot read the checklist snapshot');
select ok((select value='0' from mf024_observed where key='outsider-items'),'unrelated tenant cannot read mission checklist items');
select throws_ok($$update public.mission_checklist_snapshots set template_version=2 where id=(select id from public.mission_checklist_snapshots limit 1)$$,'55000','IMMUTABLE_CONTRACT_RECORD','snapshot cannot be mutated');

select * from finish();
rollback;
