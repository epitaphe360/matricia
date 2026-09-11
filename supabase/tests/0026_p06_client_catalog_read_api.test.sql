begin;
set local search_path = public, extensions;
select plan(55);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('d2600000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-read-a@example.invalid','',now(),'{}','{}',now(),now()),
('d2600000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-read-b@example.invalid','',now(),'{}','{}',now(),now()),
('d2600000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p06-read-editor@example.invalid','',now(),'{}','{}',now(),now());

insert into public.organizations(id,legal_name,display_name,status,created_by) values
('d2610000-0000-0000-0000-000000000001','P06 Read Organization A','P06 Read A','ACTIVE','d2600000-0000-0000-0000-000000000001'),
('d2610000-0000-0000-0000-000000000002','P06 Read Organization B','P06 Read B','ACTIVE','d2600000-0000-0000-0000-000000000002'),
('d2610000-0000-0000-0000-000000000003','P06 Read Steward','P06 Read Steward','ACTIVE','d2600000-0000-0000-0000-000000000003');

insert into public.organization_memberships(id,organization_id,user_id,status,activated_at) values
('d2620000-0000-0000-0000-000000000001','d2610000-0000-0000-0000-000000000001','d2600000-0000-0000-0000-000000000001','ACTIVE',now()),
('d2620000-0000-0000-0000-000000000002','d2610000-0000-0000-0000-000000000002','d2600000-0000-0000-0000-000000000002','ACTIVE',now()),
('d2620000-0000-0000-0000-000000000003','d2610000-0000-0000-0000-000000000003','d2600000-0000-0000-0000-000000000003','ACTIVE',now());

insert into public.catalog_libraries(id,code,slug,steward_organization_id,created_by) values
('d2630000-0000-0000-0000-000000000001','A00_P06_READ','p06-read','d2610000-0000-0000-0000-000000000003','d2600000-0000-0000-0000-000000000003');

insert into public.organization_member_roles(membership_id,role_code,library_id) values
('d2620000-0000-0000-0000-000000000003','FRANCHISE_OWNER','d2630000-0000-0000-0000-000000000001');
insert into public.catalog_library_mandates(library_id,organization_id,status,valid_from,policy_version,created_by) values
('d2630000-0000-0000-0000-000000000001','d2610000-0000-0000-0000-000000000003','ACTIVE',now()-interval '1 day',1,'d2600000-0000-0000-0000-000000000003');

insert into public.catalog_library_versions(
  id,library_id,version,status,code,slug,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,change_reason,content_hash,
  translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at
) values (
  'd2640000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001',1,'APPROVED','A00_P06_READ','p06-read',
  'Bibliothèque lecture','مكتبة القراءة','Catalogue publié pour les tests','كتالوج منشور للاختبارات','book-open',1,'Publication initiale',repeat('1',64),
  'APPROVED','d2600000-0000-0000-0000-000000000003',now(),repeat('2',64),1,'d2600000-0000-0000-0000-000000000003',null
);

insert into public.catalog_categories(id,library_id,code,slug,created_by) values
('d2650000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001','READ_CAT','read-category','d2600000-0000-0000-0000-000000000003');
insert into public.catalog_category_versions(
  id,category_id,library_id,version,status,code,slug,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,
  translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at
) values (
  'd2660000-0000-0000-0000-000000000001','d2650000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001',1,'APPROVED','READ_CAT','read-category',
  'Conseil numérique','الاستشارات الرقمية','Description de catégorie','وصف الفئة',1,'Publication initiale',repeat('3',64),
  'APPROVED','d2600000-0000-0000-0000-000000000003',now(),repeat('4',64),1,'d2600000-0000-0000-0000-000000000003',null
);

insert into public.catalog_subcategories(id,library_id,category_id,code,slug,created_by) values
('d2670000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001','d2650000-0000-0000-0000-000000000001','READ_SUB','read-subcategory','d2600000-0000-0000-0000-000000000003');
insert into public.catalog_subcategory_versions(
  id,subcategory_id,library_id,version,status,category_id,code,slug,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,
  translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at
) values (
  'd2680000-0000-0000-0000-000000000001','d2670000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001',1,'APPROVED','d2650000-0000-0000-0000-000000000001','READ_SUB','read-subcategory',
  'Transformation','التحول','Description de sous-catégorie','وصف الفئة الفرعية',1,'Publication initiale',repeat('5',64),
  'APPROVED','d2600000-0000-0000-0000-000000000003',now(),repeat('6',64),1,'d2600000-0000-0000-0000-000000000003',null
);

insert into public.catalog_services(id,library_id,primary_subcategory_id,code,slug,created_by) values
('d2690000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001','d2670000-0000-0000-0000-000000000001','READ_ALPHA','audit-alpha','d2600000-0000-0000-0000-000000000003'),
('d2690000-0000-0000-0000-000000000002','d2630000-0000-0000-0000-000000000001','d2670000-0000-0000-0000-000000000001','READ_BETA','conseil-beta','d2600000-0000-0000-0000-000000000003'),
('d2690000-0000-0000-0000-000000000003','d2630000-0000-0000-0000-000000000001','d2670000-0000-0000-0000-000000000001','READ_GAMMA','deploiement-gamma','d2600000-0000-0000-0000-000000000003');

insert into public.catalog_service_versions(
  id,service_id,library_id,version,status,primary_subcategory_id,code,slug,name_fr,name_ar,short_description_fr,short_description_ar,long_description_fr,long_description_ar,
  service_type,unit_label_fr,unit_label_ar,credit_eligible,volume_eligible,recurring_eligible,trial_eligible,rfq_required,sort_order,
  change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at
) values
('d26a0000-0000-0000-0000-000000000001','d2690000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001',1,'APPROVED','d2670000-0000-0000-0000-000000000001','READ_ALPHA','audit-alpha','Audit Alpha','تدقيق ألفا','État des lieux Alpha','تقييم ألفا','Analyse détaillée Alpha','تحليل ألفا المفصل','AUDIT','mission','مهمة',true,false,false,true,true,1,'Publication initiale',repeat('7',64),'APPROVED','d2600000-0000-0000-0000-000000000003',now(),repeat('8',64),1,'d2600000-0000-0000-0000-000000000003',null),
('d26a0000-0000-0000-0000-000000000002','d2690000-0000-0000-0000-000000000002','d2630000-0000-0000-0000-000000000001',1,'APPROVED','d2670000-0000-0000-0000-000000000001','READ_BETA','conseil-beta','Conseil Bêta','استشارة بيتا','Accompagnement Bêta','مرافقة بيتا','Conseil détaillé Bêta','استشارة بيتا المفصلة','CONSULTING','jour','يوم',false,true,true,false,true,2,'Publication initiale',repeat('9',64),'APPROVED','d2600000-0000-0000-0000-000000000003',now(),repeat('a',64),1,'d2600000-0000-0000-0000-000000000003',null),
('d26a0000-0000-0000-0000-000000000003','d2690000-0000-0000-0000-000000000003','d2630000-0000-0000-0000-000000000001',1,'APPROVED','d2670000-0000-0000-0000-000000000001','READ_GAMMA','deploiement-gamma','Déploiement Gamma','نشر غاما','Mise en œuvre Gamma','تنفيذ غاما','Déploiement détaillé Gamma','نشر غاما المفصل','IMPLEMENTATION','projet','مشروع',false,false,false,false,true,3,'Publication initiale',repeat('b',64),'APPROVED','d2600000-0000-0000-0000-000000000003',now(),repeat('c',64),1,'d2600000-0000-0000-0000-000000000003',null);

insert into public.catalog_service_subcategory_links(id,service_id,subcategory_id,library_id,link_type,created_by) values
('d26b0000-0000-0000-0000-000000000001','d2690000-0000-0000-0000-000000000001','d2670000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001','PRIMARY','d2600000-0000-0000-0000-000000000003'),
('d26b0000-0000-0000-0000-000000000002','d2690000-0000-0000-0000-000000000002','d2670000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001','PRIMARY','d2600000-0000-0000-0000-000000000003'),
('d26b0000-0000-0000-0000-000000000003','d2690000-0000-0000-0000-000000000003','d2670000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001','PRIMARY','d2600000-0000-0000-0000-000000000003');
insert into public.catalog_service_subcategory_link_versions(id,link_id,library_id,version,status,service_id,subcategory_id,link_type,change_reason,content_hash,created_by,published_at) values
('d26c0000-0000-0000-0000-000000000001','d26b0000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001',1,'APPROVED','d2690000-0000-0000-0000-000000000001','d2670000-0000-0000-0000-000000000001','PRIMARY','Publication initiale',repeat('d',64),'d2600000-0000-0000-0000-000000000003',null),
('d26c0000-0000-0000-0000-000000000002','d26b0000-0000-0000-0000-000000000002','d2630000-0000-0000-0000-000000000001',1,'APPROVED','d2690000-0000-0000-0000-000000000002','d2670000-0000-0000-0000-000000000001','PRIMARY','Publication initiale',repeat('e',64),'d2600000-0000-0000-0000-000000000003',null),
('d26c0000-0000-0000-0000-000000000003','d26b0000-0000-0000-0000-000000000003','d2630000-0000-0000-0000-000000000001',1,'APPROVED','d2690000-0000-0000-0000-000000000003','d2670000-0000-0000-0000-000000000001','PRIMARY','Publication initiale',repeat('f',64),'d2600000-0000-0000-0000-000000000003',null);

insert into public.catalog_releases(id,library_id,release_key,status,source_bundle_hash,snapshot_hash,audience,effective_from,effective_until,created_by,published_at) values
('d26d0000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001','P06.READ.ORG.A','DRAFT',repeat('1',64),repeat('2',64),'{"kind":"ORGANIZATIONS","organization_ids":["d2610000-0000-0000-0000-000000000001"]}',now()-interval '1 hour',now()+interval '1 hour','d2600000-0000-0000-0000-000000000003',null),
('d26d0000-0000-0000-0000-000000000002','d2630000-0000-0000-0000-000000000001','P06.READ.ORG.B','DRAFT',repeat('3',64),repeat('4',64),'{"kind":"ORGANIZATIONS","organization_ids":["d2610000-0000-0000-0000-000000000002"]}',now()-interval '1 hour',now()+interval '1 hour','d2600000-0000-0000-0000-000000000003',null),
('d26d0000-0000-0000-0000-000000000003','d2630000-0000-0000-0000-000000000001','P06.READ.EXPIRED','DRAFT',repeat('5',64),repeat('6',64),'{"kind":"PUBLIC"}',now()-interval '2 hours',now()-interval '1 hour','d2600000-0000-0000-0000-000000000003',null),
('d26d0000-0000-0000-0000-000000000004','d2630000-0000-0000-0000-000000000001','P06.READ.DRAFT','DRAFT',repeat('7',64),null,'{"kind":"PUBLIC"}',now()-interval '1 hour',null,'d2600000-0000-0000-0000-000000000003',null),
('d26d0000-0000-0000-0000-000000000005','d2630000-0000-0000-0000-000000000001','P06.READ.FUTURE','DRAFT',repeat('8',64),repeat('9',64),'{"kind":"PUBLIC"}',now()+interval '1 hour',now()+interval '2 hours','d2600000-0000-0000-0000-000000000003',null),
('d26d0000-0000-0000-0000-000000000006','d2630000-0000-0000-0000-000000000001','P06.READ.PUBLIC','DRAFT',repeat('a',64),repeat('b',64),'{"kind":"PUBLIC"}',now()-interval '1 hour',now()+interval '1 hour','d2600000-0000-0000-0000-000000000003',null);

insert into public.catalog_release_items(release_id,library_id,object_type,object_id,version_id,content_hash,sort_order)
select release_id,'d2630000-0000-0000-0000-000000000001',object_type,object_id,version_id,content_hash,sort_order
from (values
  ('LIBRARY','d2630000-0000-0000-0000-000000000001'::uuid,'d2640000-0000-0000-0000-000000000001'::uuid,repeat('1',64),1),
  ('CATEGORY','d2650000-0000-0000-0000-000000000001'::uuid,'d2660000-0000-0000-0000-000000000001'::uuid,repeat('3',64),2),
  ('SUBCATEGORY','d2670000-0000-0000-0000-000000000001'::uuid,'d2680000-0000-0000-0000-000000000001'::uuid,repeat('5',64),3),
  ('SERVICE','d2690000-0000-0000-0000-000000000001'::uuid,'d26a0000-0000-0000-0000-000000000001'::uuid,repeat('7',64),4),
  ('SERVICE','d2690000-0000-0000-0000-000000000002'::uuid,'d26a0000-0000-0000-0000-000000000002'::uuid,repeat('9',64),5),
  ('SERVICE','d2690000-0000-0000-0000-000000000003'::uuid,'d26a0000-0000-0000-0000-000000000003'::uuid,repeat('b',64),6),
  ('SERVICE_SUBCATEGORY_LINK','d26b0000-0000-0000-0000-000000000001'::uuid,'d26c0000-0000-0000-0000-000000000001'::uuid,repeat('d',64),7),
  ('SERVICE_SUBCATEGORY_LINK','d26b0000-0000-0000-0000-000000000002'::uuid,'d26c0000-0000-0000-0000-000000000002'::uuid,repeat('e',64),8),
  ('SERVICE_SUBCATEGORY_LINK','d26b0000-0000-0000-0000-000000000003'::uuid,'d26c0000-0000-0000-0000-000000000003'::uuid,repeat('f',64),9)
) item(object_type,object_id,version_id,content_hash,sort_order)
cross join (values
  ('d26d0000-0000-0000-0000-000000000001'::uuid),
  ('d26d0000-0000-0000-0000-000000000002'::uuid)
) release(release_id);

insert into public.catalog_release_items(release_id,library_id,object_type,object_id,version_id,content_hash,sort_order) values
('d26d0000-0000-0000-0000-000000000003','d2630000-0000-0000-0000-000000000001','LIBRARY','d2630000-0000-0000-0000-000000000001','d2640000-0000-0000-0000-000000000001',repeat('1',64),1),
('d26d0000-0000-0000-0000-000000000004','d2630000-0000-0000-0000-000000000001','LIBRARY','d2630000-0000-0000-0000-000000000001','d2640000-0000-0000-0000-000000000001',repeat('1',64),1);

insert into public.catalog_release_items(release_id,library_id,object_type,object_id,version_id,content_hash,sort_order)
select target.release_id,item.library_id,item.object_type,item.object_id,item.version_id,item.content_hash,item.sort_order
from public.catalog_release_items item
cross join (values ('d26d0000-0000-0000-0000-000000000005'::uuid),('d26d0000-0000-0000-0000-000000000006'::uuid)) target(release_id)
where item.release_id='d26d0000-0000-0000-0000-000000000001';

-- Non-empty visibility rules fail closed until a versioned evaluator exists.
insert into public.catalog_services(id,library_id,primary_subcategory_id,code,slug,created_by) values
('d2690000-0000-0000-0000-000000000004','d2630000-0000-0000-0000-000000000001','d2670000-0000-0000-0000-000000000001','READ_RESTRICTED','restricted-service','d2600000-0000-0000-0000-000000000003');
insert into public.catalog_service_versions(id,service_id,library_id,version,status,primary_subcategory_id,code,slug,name_fr,name_ar,short_description_fr,short_description_ar,long_description_fr,long_description_ar,service_type,unit_label_fr,unit_label_ar,sort_order,visibility_rules,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at) values
('d26a0000-0000-0000-0000-000000000004','d2690000-0000-0000-0000-000000000004','d2630000-0000-0000-0000-000000000001',1,'APPROVED','d2670000-0000-0000-0000-000000000001','READ_RESTRICTED','restricted-service','Service restreint','خدمة مقيدة','Invisible sans évaluateur','غير مرئي','Contenu soumis à une règle','محتوى مقيد','CONSULTING','jour','يوم',4,'{"plan":"GOLD"}','Publication restreinte',repeat('1',64),'APPROVED','d2600000-0000-0000-0000-000000000003',now(),repeat('2',64),1,'d2600000-0000-0000-0000-000000000003',null);
insert into public.catalog_service_subcategory_links(id,service_id,subcategory_id,library_id,link_type,created_by) values
('d26b0000-0000-0000-0000-000000000004','d2690000-0000-0000-0000-000000000004','d2670000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001','PRIMARY','d2600000-0000-0000-0000-000000000003');
insert into public.catalog_service_subcategory_link_versions(id,link_id,library_id,version,status,service_id,subcategory_id,link_type,change_reason,content_hash,created_by,published_at) values
('d26c0000-0000-0000-0000-000000000004','d26b0000-0000-0000-0000-000000000004','d2630000-0000-0000-0000-000000000001',1,'APPROVED','d2690000-0000-0000-0000-000000000004','d2670000-0000-0000-0000-000000000001','PRIMARY','Publication restreinte',repeat('3',64),'d2600000-0000-0000-0000-000000000003',null);
insert into public.catalog_release_items(release_id,library_id,object_type,object_id,version_id,content_hash,sort_order) values
('d26d0000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001','SERVICE','d2690000-0000-0000-0000-000000000004','d26a0000-0000-0000-0000-000000000004',repeat('1',64),10),
('d26d0000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001','SERVICE_SUBCATEGORY_LINK','d26b0000-0000-0000-0000-000000000004','d26c0000-0000-0000-0000-000000000004',repeat('3',64),11);

-- Four malformed published snapshots prove every link in the versioned chain is mandatory.
insert into public.catalog_service_subcategory_link_versions(id,link_id,library_id,version,status,service_id,subcategory_id,link_type,change_reason,content_hash,created_by) values
('d26c0000-0000-0000-0000-000000000005','d26b0000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001',2,'APPROVED','d2690000-0000-0000-0000-000000000001','d2670000-0000-0000-0000-000000000001','SECONDARY','Lien secondaire adversarial',repeat('4',64),'d2600000-0000-0000-0000-000000000003');
insert into public.catalog_libraries(id,code,slug,steward_organization_id,created_by) values
('d2630000-0000-0000-0000-000000000002','CROSS_LIB','cross-library','d2610000-0000-0000-0000-000000000003','d2600000-0000-0000-0000-000000000003');
insert into public.catalog_library_versions(id,library_id,version,status,code,slug,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,change_reason,content_hash,created_by) values
('d2640000-0000-0000-0000-000000000002','d2630000-0000-0000-0000-000000000002',1,'APPROVED','CROSS_LIB','cross-library','Autre bibliothèque','مكتبة أخرى','Bibliothèque adversariale','مكتبة اختبارية','shield',2,'Version adversariale',repeat('5',64),'d2600000-0000-0000-0000-000000000003');
insert into public.catalog_categories(id,library_id,code,slug,created_by) values
('d2650000-0000-0000-0000-000000000002','d2630000-0000-0000-0000-000000000002','CROSS_CAT','cross-category','d2600000-0000-0000-0000-000000000003');
insert into public.catalog_category_versions(id,category_id,library_id,version,status,code,slug,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,created_by) values
('d2660000-0000-0000-0000-000000000002','d2650000-0000-0000-0000-000000000002','d2630000-0000-0000-0000-000000000002',1,'APPROVED','CROSS_CAT','cross-category','Catégorie externe','فئة خارجية','Catégorie adversariale','فئة اختبارية',1,'Version adversariale',repeat('6',64),'d2600000-0000-0000-0000-000000000003');
insert into public.catalog_releases(id,library_id,release_key,status,source_bundle_hash,snapshot_hash,audience,effective_from,effective_until,created_by,published_at) values
('d26d0000-0000-0000-0000-000000000007','d2630000-0000-0000-0000-000000000001','P06.READ.NO.LINK','DRAFT',repeat('1',64),repeat('1',64),'{"kind":"PUBLIC"}',now()-interval '1 hour',now()+interval '1 hour','d2600000-0000-0000-0000-000000000003',null),
('d26d0000-0000-0000-0000-000000000008','d2630000-0000-0000-0000-000000000001','P06.READ.WRONG.LINK','DRAFT',repeat('2',64),repeat('2',64),'{"kind":"PUBLIC"}',now()-interval '1 hour',now()+interval '1 hour','d2600000-0000-0000-0000-000000000003',null),
('d26d0000-0000-0000-0000-000000000009','d2630000-0000-0000-0000-000000000001','P06.READ.SECONDARY','DRAFT',repeat('3',64),repeat('3',64),'{"kind":"PUBLIC"}',now()-interval '1 hour',now()+interval '1 hour','d2600000-0000-0000-0000-000000000003',null),
('d26d0000-0000-0000-0000-000000000010','d2630000-0000-0000-0000-000000000001','P06.READ.CROSS.LIB','DRAFT',repeat('4',64),repeat('4',64),'{"kind":"PUBLIC"}',now()-interval '1 hour',now()+interval '1 hour','d2600000-0000-0000-0000-000000000003',null);
insert into public.catalog_release_items(release_id,library_id,object_type,object_id,version_id,content_hash,sort_order)
select release_id,'d2630000-0000-0000-0000-000000000001',object_type,object_id,version_id,content_hash,sort_order
from (values
 ('LIBRARY','d2630000-0000-0000-0000-000000000001'::uuid,'d2640000-0000-0000-0000-000000000001'::uuid,repeat('1',64),1),
 ('CATEGORY','d2650000-0000-0000-0000-000000000001'::uuid,'d2660000-0000-0000-0000-000000000001'::uuid,repeat('3',64),2),
 ('SUBCATEGORY','d2670000-0000-0000-0000-000000000001'::uuid,'d2680000-0000-0000-0000-000000000001'::uuid,repeat('5',64),3),
 ('SERVICE','d2690000-0000-0000-0000-000000000001'::uuid,'d26a0000-0000-0000-0000-000000000001'::uuid,repeat('7',64),4)
)item(object_type,object_id,version_id,content_hash,sort_order)
cross join(values('d26d0000-0000-0000-0000-000000000007'::uuid),('d26d0000-0000-0000-0000-000000000008'::uuid),('d26d0000-0000-0000-0000-000000000009'::uuid))release(release_id);
insert into public.catalog_release_items values
('d26d0000-0000-0000-0000-000000000008','d2630000-0000-0000-0000-000000000001','SERVICE_SUBCATEGORY_LINK','d26b0000-0000-0000-0000-000000000002','d26c0000-0000-0000-0000-000000000002',repeat('e',64),5),
('d26d0000-0000-0000-0000-000000000009','d2630000-0000-0000-0000-000000000001','SERVICE_SUBCATEGORY_LINK','d26b0000-0000-0000-0000-000000000001','d26c0000-0000-0000-0000-000000000005',repeat('4',64),5);
insert into public.catalog_release_items values
('d26d0000-0000-0000-0000-000000000010','d2630000-0000-0000-0000-000000000001','LIBRARY','d2630000-0000-0000-0000-000000000001','d2640000-0000-0000-0000-000000000001',repeat('1',64),1),
('d26d0000-0000-0000-0000-000000000010','d2630000-0000-0000-0000-000000000001','CATEGORY','d2650000-0000-0000-0000-000000000001','d2660000-0000-0000-0000-000000000002',repeat('6',64),2),
('d26d0000-0000-0000-0000-000000000010','d2630000-0000-0000-0000-000000000001','SUBCATEGORY','d2670000-0000-0000-0000-000000000001','d2680000-0000-0000-0000-000000000001',repeat('5',64),3),
('d26d0000-0000-0000-0000-000000000010','d2630000-0000-0000-0000-000000000001','SERVICE','d2690000-0000-0000-0000-000000000001','d26a0000-0000-0000-0000-000000000001',repeat('7',64),4),
('d26d0000-0000-0000-0000-000000000010','d2630000-0000-0000-0000-000000000001','SERVICE_SUBCATEGORY_LINK','d26b0000-0000-0000-0000-000000000001','d26c0000-0000-0000-0000-000000000001',repeat('d',64),5);

-- Assemble every snapshot while its release is DRAFT. Once all items exist, move
-- releases to PUBLISHING and activate the valid baseline through the protected
-- lifecycle helper. Adversarial-only versions remain APPROVED by design.
update public.catalog_releases
set status='PUBLISHING',row_version=row_version+1
where id in (
  'd26d0000-0000-0000-0000-000000000001','d26d0000-0000-0000-0000-000000000002',
  'd26d0000-0000-0000-0000-000000000003','d26d0000-0000-0000-0000-000000000005',
  'd26d0000-0000-0000-0000-000000000006','d26d0000-0000-0000-0000-000000000007',
  'd26d0000-0000-0000-0000-000000000008','d26d0000-0000-0000-0000-000000000009',
  'd26d0000-0000-0000-0000-000000000010'
);

select private.activate_catalog_release_items('d26d0000-0000-0000-0000-000000000001');

update public.catalog_releases
set status='PUBLISHED',published_at=case when id='d26d0000-0000-0000-0000-000000000003'::uuid then now()-interval '2 hours' else now() end,row_version=row_version+1
where status='PUBLISHING' and id in (
  'd26d0000-0000-0000-0000-000000000001','d26d0000-0000-0000-0000-000000000002',
  'd26d0000-0000-0000-0000-000000000003','d26d0000-0000-0000-0000-000000000005',
  'd26d0000-0000-0000-0000-000000000006','d26d0000-0000-0000-0000-000000000007',
  'd26d0000-0000-0000-0000-000000000008','d26d0000-0000-0000-0000-000000000009',
  'd26d0000-0000-0000-0000-000000000010'
);

update public.catalog_libraries set status='PUBLISHED',current_published_version_id='d2640000-0000-0000-0000-000000000001',current_release_id='d26d0000-0000-0000-0000-000000000001' where id='d2630000-0000-0000-0000-000000000001';
update public.catalog_categories set status='PUBLISHED',current_published_version_id='d2660000-0000-0000-0000-000000000001' where id='d2650000-0000-0000-0000-000000000001';
update public.catalog_subcategories set status='PUBLISHED',current_published_version_id='d2680000-0000-0000-0000-000000000001' where id='d2670000-0000-0000-0000-000000000001';
update public.catalog_services set status='PUBLISHED',current_published_version_id=case id
  when 'd2690000-0000-0000-0000-000000000001'::uuid then 'd26a0000-0000-0000-0000-000000000001'::uuid
  when 'd2690000-0000-0000-0000-000000000002'::uuid then 'd26a0000-0000-0000-0000-000000000002'::uuid
  else 'd26a0000-0000-0000-0000-000000000003'::uuid end
where id in ('d2690000-0000-0000-0000-000000000001','d2690000-0000-0000-0000-000000000002','d2690000-0000-0000-0000-000000000003');
update public.catalog_service_subcategory_links set status='PUBLISHED',current_version_id=case id
  when 'd26b0000-0000-0000-0000-000000000001'::uuid then 'd26c0000-0000-0000-0000-000000000001'::uuid
  when 'd26b0000-0000-0000-0000-000000000002'::uuid then 'd26c0000-0000-0000-0000-000000000002'::uuid
  else 'd26c0000-0000-0000-0000-000000000003'::uuid end
where id in ('d26b0000-0000-0000-0000-000000000001','d26b0000-0000-0000-0000-000000000002','d26b0000-0000-0000-0000-000000000003');

-- Current identities are deliberately moved after publication. Snapshot versions stay OLD.
insert into public.catalog_categories(id,library_id,code,slug,created_by) values
('d2750000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001','NEW_CAT','new-category','d2600000-0000-0000-0000-000000000003');
insert into public.catalog_subcategories(id,library_id,category_id,code,slug,created_by) values
('d2770000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001','d2750000-0000-0000-0000-000000000001','NEW_SUB','new-subcategory','d2600000-0000-0000-0000-000000000003');
update public.catalog_categories set code='CURRENT_CAT',slug='current-category' where id='d2650000-0000-0000-0000-000000000001';
update public.catalog_subcategories set category_id='d2750000-0000-0000-0000-000000000001',code='CURRENT_SUB',slug='current-subcategory' where id='d2670000-0000-0000-0000-000000000001';
update public.catalog_services set primary_subcategory_id='d2770000-0000-0000-0000-000000000001',code='CURRENT_ALPHA',slug='current-alpha' where id='d2690000-0000-0000-0000-000000000001';
update public.catalog_service_subcategory_links set subcategory_id='d2770000-0000-0000-0000-000000000001' where id='d26b0000-0000-0000-0000-000000000001';

-- A deliberately tempting question proves the catalogue read RPCs never load question payloads.
insert into public.question_bank_questions(id,library_id,question_key,scope,created_by) values
('d26e0000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001','READ.NO.LEAK','LIBRARY','d2600000-0000-0000-0000-000000000003');
insert into public.question_versions(id,question_id,library_id,version,label_fr,label_ar,answer_type,data_key,content_hash,change_reason,created_by) values
('d26f0000-0000-0000-0000-000000000001','d26e0000-0000-0000-0000-000000000001','d2630000-0000-0000-0000-000000000001',1,'LEAK-ME-QUESTION','سؤال سري','YES_NO','catalog.no_leak',repeat('0',64),'Question sentinelle','d2600000-0000-0000-0000-000000000003');

create temporary table p06_read_observed(key text primary key,value jsonb);
grant select,insert on p06_read_observed to authenticated;
create temporary table p06_read_errors(key text primary key,sqlstate text not null,message text not null);
grant select,insert on p06_read_errors to authenticated,anon;

select has_function('public','list_client_catalog_libraries',array['text'],'library read RPC exists');
select has_function('public','search_client_catalog_release',array['uuid','text','text','jsonb','integer'],'catalogue search RPC exists');
select has_function('public','get_client_catalog_service',array['uuid','text','text'],'service detail RPC exists');
select ok(
  (select pro.prosecdef and pro.proconfig @> array['search_path=pg_catalog, private']::text[]
   from pg_proc pro where pro.oid='public.list_client_catalog_libraries(text)'::regprocedure),
  'library RPC is SECURITY DEFINER with a fixed search_path'
);
select ok(
  (select bool_and(pro.prosecdef and pro.proconfig @> array['search_path=pg_catalog, private']::text[])
   from pg_proc pro where pro.oid in (
     'public.search_client_catalog_release(uuid,text,text,jsonb,integer)'::regprocedure,
     'public.get_client_catalog_service(uuid,text,text)'::regprocedure
   )),
  'search and detail RPCs are SECURITY DEFINER with a fixed search_path'
);
select ok(
  has_function_privilege('authenticated','public.list_client_catalog_libraries(text)','EXECUTE')
  and has_function_privilege('authenticated','public.search_client_catalog_release(uuid,text,text,jsonb,integer)','EXECUTE')
  and has_function_privilege('authenticated','public.get_client_catalog_service(uuid,text,text)','EXECUTE'),
  'authenticated actors can execute only the client read surface'
);
select ok(
  not has_function_privilege('anon','public.list_client_catalog_libraries(text)','EXECUTE')
  and not has_function_privilege('anon','public.search_client_catalog_release(uuid,text,text,jsonb,integer)','EXECUTE')
  and not has_function_privilege('anon','public.get_client_catalog_service(uuid,text,text)','EXECUTE')
  and not has_function_privilege('service_role','public.list_client_catalog_libraries(text)','EXECUTE')
  and not has_function_privilege('service_role','public.search_client_catalog_release(uuid,text,text,jsonb,integer)','EXECUTE')
  and not has_function_privilege('service_role','public.get_client_catalog_service(uuid,text,text)','EXECUTE'),
  'anonymous and service roles receive no client read grants'
);
select ok(
  position('private.can_read_catalog_release' in pg_get_functiondef('public.list_client_catalog_libraries(text)'::regprocedure)) > 0
  and position('private.can_read_catalog_release' in pg_get_functiondef('public.search_client_catalog_release(uuid,text,text,jsonb,integer)'::regprocedure)) > 0
  and position('private.can_read_catalog_release' in pg_get_functiondef('public.get_client_catalog_service(uuid,text,text)'::regprocedure)) > 0
  and position('has_catalog_library_scope' in pg_get_functiondef('public.list_client_catalog_libraries(text)'::regprocedure)) = 0
  and position('has_catalog_library_scope' in pg_get_functiondef('public.search_client_catalog_release(uuid,text,text,jsonb,integer)'::regprocedure)) = 0
  and position('has_catalog_library_scope' in pg_get_functiondef('public.get_client_catalog_service(uuid,text,text)'::regprocedure)) = 0,
  'every RPC enforces release audience without an editor-scope bypass'
);
select ok(
  position('question_' in lower(pg_get_functiondef('public.list_client_catalog_libraries(text)'::regprocedure))) = 0
  and position('question_' in lower(pg_get_functiondef('public.search_client_catalog_release(uuid,text,text,jsonb,integer)'::regprocedure))) = 0
  and position('question_' in lower(pg_get_functiondef('public.get_client_catalog_service(uuid,text,text)'::regprocedure))) = 0,
  'client catalogue functions do not query questionnaire or question tables'
);

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"d2600000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal1"}',true);
insert into p06_read_observed values
('list-fr',public.list_client_catalog_libraries('fr')),
('list-ar',public.list_client_catalog_libraries('ar')),
('page-1',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000001','fr','',null,1)),
('search-fr',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000001','fr','Bêta',null,12)),
('search-ar',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000001','ar','بيتا',null,12)),
('detail-fr',public.get_client_catalog_service('d26d0000-0000-0000-0000-000000000001','fr','conseil-beta')),
('detail-ar',public.get_client_catalog_service('d26d0000-0000-0000-0000-000000000001','ar','conseil-beta')),
('missing',public.get_client_catalog_service('d26d0000-0000-0000-0000-000000000001','fr','service-absent')),
('cross-org',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000002','fr','',null,12)),
('expired',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000003','fr','',null,12)),
('unknown',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000099','fr','',null,12));
insert into p06_read_observed select 'page-2',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000001','fr','',(select value->'next_cursor' from p06_read_observed where key='page-1'),1);
insert into p06_read_observed select 'page-3',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000001','fr','',(select value->'next_cursor' from p06_read_observed where key='page-2'),1);
insert into p06_read_observed values
('after-last',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000001','fr','',jsonb_build_object('sort_order',3,'name','Déploiement Gamma','code','READ_GAMMA','service_id','d2690000-0000-0000-0000-000000000003'),1)),
('future',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000005','fr','',null,12)),
('public',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000006','fr','',null,12)),
('restricted',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000001','fr','restreint',null,12)),
('link-absent',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000007','fr','',null,12)),
('link-wrong-service',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000008','fr','',null,12)),
('link-secondary',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000009','fr','',null,12)),
('link-cross-library',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000010','fr','',null,12));
do $runtime$ begin perform public.list_client_catalog_libraries('fr-MA'); exception when others then insert into p06_read_errors values('locale',sqlstate,sqlerrm); end $runtime$;
do $runtime$ begin perform public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000001','fr',repeat('𐐀',81),null,12); exception when others then insert into p06_read_errors values('search-length',sqlstate,sqlerrm); end $runtime$;
do $runtime$ begin perform public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000001','fr','',jsonb_build_object('sort_order',1),12); exception when others then insert into p06_read_errors values('cursor-shape',sqlstate,sqlerrm); end $runtime$;
do $runtime$ begin perform public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000001','fr','',jsonb_build_object('sort_order',1,'name','Forgé','code','READ_ALPHA','service_id','d2690000-0000-0000-0000-000000000001'),12); exception when others then insert into p06_read_errors values('cursor-mismatch',sqlstate,sqlerrm); end $runtime$;
do $runtime$ begin perform public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000001','fr','',null,13); exception when others then insert into p06_read_errors values('page-size',sqlstate,sqlerrm); end $runtime$;
select set_config('request.jwt.claims','{"sub":"d2600000-0000-0000-0000-000000000003","role":"authenticated","aal":"aal1"}',true);
insert into p06_read_observed values ('editor-draft',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000004','fr','',null,12));
reset role;

update public.organization_memberships set status='SUSPENDED' where id='d2620000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"d2600000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal1"}',true);
insert into p06_read_observed values ('membership-suspended',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000001','fr','',null,12));
reset role;
update public.organization_memberships set status='REVOKED' where id='d2620000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"d2600000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal1"}',true);
insert into p06_read_observed values ('membership-revoked',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000001','fr','',null,12));
reset role;
update public.organization_memberships set status='ACTIVE' where id='d2620000-0000-0000-0000-000000000001';
update public.organizations set status='SUSPENDED' where id='d2610000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"d2600000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal1"}',true);
insert into p06_read_observed values ('organization-inactive',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000001','fr','',null,12));
reset role;
update public.organizations set status='ACTIVE' where id='d2610000-0000-0000-0000-000000000001';

select is((select value->>'locale' from p06_read_observed where key='list-fr'),'fr','authenticated list returns the requested locale');
select ok(
  (select count(*)=1 from p06_read_observed observed cross join lateral jsonb_array_elements(observed.value->'items') item where observed.key='list-fr' and item->>'release_id'='d26d0000-0000-0000-0000-000000000001')
  and (select count(*)=0 from p06_read_observed observed cross join lateral jsonb_array_elements(observed.value->'items') item where observed.key='list-fr' and item->>'release_id' in ('d26d0000-0000-0000-0000-000000000002','d26d0000-0000-0000-0000-000000000003','d26d0000-0000-0000-0000-000000000004','d26d0000-0000-0000-0000-000000000007','d26d0000-0000-0000-0000-000000000008','d26d0000-0000-0000-0000-000000000009','d26d0000-0000-0000-0000-000000000010')),
  'organization A sees its audience release but not cross-org, expired, draft, or invalid-chain releases'
);
select is(
  (select item->>'release_id' from p06_read_observed observed cross join lateral jsonb_array_elements(observed.value->'items') item where observed.key='list-fr' and item->>'release_id'='d26d0000-0000-0000-0000-000000000001'),
  'd26d0000-0000-0000-0000-000000000001','list returns the exact authorized release identifier'
);
select is(
  (select (item->>'category_count')::integer from p06_read_observed observed cross join lateral jsonb_array_elements(observed.value->'items') item where observed.key='list-fr' and item->>'release_id'='d26d0000-0000-0000-0000-000000000001'),
  1,'library list counts only category snapshot items'
);
select is(
  (select (item->>'service_count')::integer from p06_read_observed observed cross join lateral jsonb_array_elements(observed.value->'items') item where observed.key='list-fr' and item->>'release_id'='d26d0000-0000-0000-0000-000000000001'),
  3,'library list counts only service snapshot items'
);
select is(
  (select item#>>'{library,name}' from p06_read_observed observed cross join lateral jsonb_array_elements(observed.value->'items') item where observed.key='list-ar' and item->>'release_id'='d26d0000-0000-0000-0000-000000000001'),
  'مكتبة القراءة','Arabic library localization is selected server-side'
);
select is((select (value->>'total')::integer from p06_read_observed where key='page-1'),3,'search total covers the exact release snapshot');
select is((select value#>>'{services,0,service,slug}' from p06_read_observed where key='page-1'),'audit-alpha','deterministic page one starts with sort order one');
select is((select value#>>'{services,0,service,slug}' from p06_read_observed where key='page-2'),'conseil-beta','bounded pagination returns deterministic page two');
select ok((select (value->>'has_more')::boolean and value->'next_cursor'=jsonb_build_object('sort_order',1,'name','Audit Alpha','code','READ_ALPHA','service_id','d2690000-0000-0000-0000-000000000001') from p06_read_observed where key='page-1'),'next cursor is the exact last returned stable tuple');
select is((select value#>>'{services,0,service,slug}' from p06_read_observed where key='page-3'),'deploiement-gamma','keyset navigation reaches the final item');
select ok((select jsonb_array_length(value->'services')=0 and not (value->>'has_more')::boolean and value->'next_cursor'='null'::jsonb from p06_read_observed where key='after-last'),'cursor after the last row returns an empty terminal page');
select is((select (value->>'total')::integer from p06_read_observed where key='search-fr'),1,'French literal search narrows the snapshot');
select is((select value#>>'{services,0,service,slug}' from p06_read_observed where key='search-fr'),'conseil-beta','French search returns the matching service');
select is((select value#>>'{services,0,service,name}' from p06_read_observed where key='search-ar'),'استشارة بيتا','Arabic search and localization return the matching translation');
select ok(position('LEAK-ME-QUESTION' in coalesce((select value::text from p06_read_observed where key='search-fr'),''))=0,'search output never loads question payloads');
select is((select value->>'release_id' from p06_read_observed where key='detail-fr'),'d26d0000-0000-0000-0000-000000000001','detail is pinned to the requested release');
select is((select value#>>'{service,slug}' from p06_read_observed where key='detail-fr'),'conseil-beta','detail returns only the requested snapshot service');
select ok(
  (select value#>>'{service,name}'='Conseil Bêta' and value#>>'{category,name}'='Conseil numérique' and value#>>'{subcategory,name}'='Transformation' from p06_read_observed where key='detail-fr'),
  'detail uses the exact localized service/category/subcategory snapshot versions'
);
select is((select value#>>'{service,name}' from p06_read_observed where key='detail-ar'),'استشارة بيتا','Arabic detail is localized server-side');
select ok((select value#>>'{service,slug}'='conseil-beta' and value#>>'{category,slug}'='read-category' and value#>>'{subcategory,slug}'='read-subcategory' from p06_read_observed where key='detail-fr'),'published OLD snapshot is stable after current identity reparent and rename');
select is((select (value->>'total')::integer from p06_read_observed where key='restricted'),0,'non-empty visibility rules fail closed without leaking restricted services');
select is((select (value->>'service_count')::integer from p06_read_observed where key='link-absent'),0,'service without a snapshot link is rejected');
select is((select (value->>'service_count')::integer from p06_read_observed where key='link-wrong-service'),0,'link targeting another service is rejected');
select is((select (value->>'service_count')::integer from p06_read_observed where key='link-secondary'),0,'SECONDARY link cannot replace the required PRIMARY link');
select is((select (value->>'service_count')::integer from p06_read_observed where key='link-cross-library'),0,'cross-library version in the snapshot chain is rejected');
select is((select value from p06_read_observed where key='missing'),null::jsonb,'missing service returns null without substituting another release');
select is((select value from p06_read_observed where key='cross-org'),null::jsonb,'cross-organization release is indistinguishable from unavailable');
select is((select value from p06_read_observed where key='expired'),null::jsonb,'expired publication window is unavailable');
select is((select value from p06_read_observed where key='future'),null::jsonb,'future publication window is unavailable');
select is((select value->>'release_id' from p06_read_observed where key='public'),'d26d0000-0000-0000-0000-000000000006','active PUBLIC release is readable by an authenticated actor');
select is((select value from p06_read_observed where key='membership-suspended'),null::jsonb,'suspended membership cannot satisfy an organization audience');
select is((select value from p06_read_observed where key='membership-revoked'),null::jsonb,'revoked membership cannot satisfy an organization audience');
select is((select value from p06_read_observed where key='organization-inactive'),null::jsonb,'inactive organization cannot satisfy an organization audience');
select is((select value from p06_read_observed where key='unknown'),null::jsonb,'unknown exact release is unavailable');
select is((select value from p06_read_observed where key='editor-draft'),null::jsonb,'catalogue editor scope cannot expose a draft through the client RPC');
select is((select sqlstate||':'||message from p06_read_errors where key='locale'),'22023:INVALID_CATALOG_LOCALE','unsupported locale is rejected');
select is((select sqlstate||':'||message from p06_read_errors where key='search-length'),'22023:CATALOG_SEARCH_TOO_LONG','search is bounded by Unicode code points');
select is((select sqlstate||':'||message from p06_read_errors where key='cursor-shape'),'22023:INVALID_CATALOG_CURSOR','cursor shape is exact and bounded');
select is((select sqlstate||':'||message from p06_read_errors where key='cursor-mismatch'),'22023:INVALID_CATALOG_CURSOR','forged cursor tuple is rejected');
select is((select sqlstate||':'||message from p06_read_errors where key='page-size'),'22023:INVALID_CATALOG_PAGE_SIZE','page size is capped at twelve');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"d2600000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal1"}',true);
insert into p06_read_observed values
('org-b-own',public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000002','fr','',null,12)),
('org-b-denied-a',public.get_client_catalog_service('d26d0000-0000-0000-0000-000000000001','fr','conseil-beta'));
reset role;
select is((select value->>'release_id' from p06_read_observed where key='org-b-own'),'d26d0000-0000-0000-0000-000000000002','organization B reads only its exact audience release');
select is((select value from p06_read_observed where key='org-b-denied-a'),null::jsonb,'organization B cannot read organization A detail');

set local role anon;
select set_config('request.jwt.claims','{"role":"anon"}',true);
do $runtime$ begin perform public.list_client_catalog_libraries('fr'); exception when others then insert into p06_read_errors values('anon-list',sqlstate,sqlerrm); end $runtime$;
do $runtime$ begin perform public.search_client_catalog_release('d26d0000-0000-0000-0000-000000000001','fr','',null,12); exception when others then insert into p06_read_errors values('anon-search',sqlstate,sqlerrm); end $runtime$;
do $runtime$ begin perform public.get_client_catalog_service('d26d0000-0000-0000-0000-000000000001','fr','conseil-beta'); exception when others then insert into p06_read_errors values('anon-detail',sqlstate,sqlerrm); end $runtime$;
reset role;
select is((select sqlstate from p06_read_errors where key='anon-list'),'42501','anonymous library listing is denied');
select is((select sqlstate from p06_read_errors where key='anon-search'),'42501','anonymous catalogue search is denied');
select is((select sqlstate from p06_read_errors where key='anon-detail'),'42501','anonymous service detail is denied');

select * from finish();
rollback;
