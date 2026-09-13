begin;
set local search_path=public,extensions;
select plan(8);

select ok(
  position('is_active_org_member' in pg_get_expr(
    (select polqual from pg_policy where polname='recurring_plans_tenant_read'),
    'public.recurring_service_plans'::regclass
  )) > 0,
  'recurring plan SELECT policy uses tenant membership rather than mutation capability'
);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('a9500000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','recurring-viewer-95@example.invalid','',now(),'{}','{}',now(),now()),
('a9500000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','recurring-outsider-95@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by) values
('b9500000-0000-0000-0000-000000000001','Recurring Viewer 95','Recurring Viewer 95','ACTIVE','a9500000-0000-0000-0000-000000000001'),
('b9500000-0000-0000-0000-000000000002','Recurring Outsider 95','Recurring Outsider 95','ACTIVE','a9500000-0000-0000-0000-000000000002');
insert into public.organization_memberships(organization_id,user_id,status,activated_at) values
('b9500000-0000-0000-0000-000000000001','a9500000-0000-0000-0000-000000000001','ACTIVE',now()),
('b9500000-0000-0000-0000-000000000002','a9500000-0000-0000-0000-000000000002','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code)
select id,'CLIENT_VIEWER' from public.organization_memberships where user_id::text like 'a9500000-%';

insert into public.catalog_libraries(id,code,slug,steward_organization_id,status,created_by)values('f9500000-0000-0000-0000-000000000010','RECURRING_VIEW','recurring-view','b9500000-0000-0000-0000-000000000001','PUBLISHED','a9500000-0000-0000-0000-000000000001');
insert into public.catalog_library_versions(id,library_id,version,status,code,slug,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at)values('f9500000-0000-0000-0000-000000000011','f9500000-0000-0000-0000-000000000010',1,'PUBLISHED','RECURRING_VIEW','recurring-view','Bibliothèque récurrente','مكتبة متكررة','Fixture lecture récurrente','اختبار القراءة','calendar',1,'Fixture autonome',repeat('1',64),'APPROVED','a9500000-0000-0000-0000-000000000001',now(),repeat('2',64),1,'a9500000-0000-0000-0000-000000000001',now());update public.catalog_libraries set current_published_version_id='f9500000-0000-0000-0000-000000000011'where id='f9500000-0000-0000-0000-000000000010';
insert into public.catalog_categories(id,library_id,code,slug,status,created_by)values('f9500000-0000-0000-0000-000000000012','f9500000-0000-0000-0000-000000000010','REC_CAT','rec-cat','PUBLISHED','a9500000-0000-0000-0000-000000000001');
insert into public.catalog_category_versions(id,category_id,library_id,version,status,code,slug,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at)values('f9500000-0000-0000-0000-000000000013','f9500000-0000-0000-0000-000000000012','f9500000-0000-0000-0000-000000000010',1,'PUBLISHED','REC_CAT','rec-cat','Catégorie récurrente','فئة متكررة','Fixture catégorie','فئة اختبار',1,'Fixture autonome',repeat('3',64),'APPROVED','a9500000-0000-0000-0000-000000000001',now(),repeat('4',64),1,'a9500000-0000-0000-0000-000000000001',now());update public.catalog_categories set current_published_version_id='f9500000-0000-0000-0000-000000000013'where id='f9500000-0000-0000-0000-000000000012';
insert into public.catalog_subcategories(id,library_id,category_id,code,slug,status,created_by)values('f9500000-0000-0000-0000-000000000014','f9500000-0000-0000-0000-000000000010','f9500000-0000-0000-0000-000000000012','REC_SUB','rec-sub','PUBLISHED','a9500000-0000-0000-0000-000000000001');
insert into public.catalog_subcategory_versions(id,subcategory_id,library_id,version,status,category_id,code,slug,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at)values('f9500000-0000-0000-0000-000000000015','f9500000-0000-0000-0000-000000000014','f9500000-0000-0000-0000-000000000010',1,'PUBLISHED','f9500000-0000-0000-0000-000000000012','REC_SUB','rec-sub','Sous-catégorie','فئة فرعية','Fixture sous-catégorie','اختبار فرعي',1,'Fixture autonome',repeat('5',64),'APPROVED','a9500000-0000-0000-0000-000000000001',now(),repeat('6',64),1,'a9500000-0000-0000-0000-000000000001',now());update public.catalog_subcategories set current_published_version_id='f9500000-0000-0000-0000-000000000015'where id='f9500000-0000-0000-0000-000000000014';
insert into public.catalog_services(id,library_id,primary_subcategory_id,code,slug,status,created_by)values('f9500000-0000-0000-0000-000000000016','f9500000-0000-0000-0000-000000000010','f9500000-0000-0000-0000-000000000014','REC_SERVICE','rec-service','PUBLISHED','a9500000-0000-0000-0000-000000000001');
insert into public.catalog_service_versions(id,service_id,library_id,version,status,primary_subcategory_id,code,slug,name_fr,name_ar,short_description_fr,short_description_ar,long_description_fr,long_description_ar,service_type,unit_label_fr,unit_label_ar,recurring_eligible,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,published_at)values('f9500000-0000-0000-0000-000000000017','f9500000-0000-0000-0000-000000000016','f9500000-0000-0000-0000-000000000010',1,'PUBLISHED','f9500000-0000-0000-0000-000000000014','REC_SERVICE','rec-service','Service récurrent','خدمة متكررة','Fixture service','خدمة اختبار','Service récurrent autonome','خدمة متكررة مستقلة','CONSULTING','jour','يوم',true,1,'Fixture autonome',repeat('7',64),'APPROVED','a9500000-0000-0000-0000-000000000001',now(),repeat('8',64),1,'a9500000-0000-0000-0000-000000000001',now());update public.catalog_services set current_published_version_id='f9500000-0000-0000-0000-000000000017'where id='f9500000-0000-0000-0000-000000000016';

insert into public.service_requests(id,client_organization_id,library_id,service_id,status,created_by)
select 'c9500000-0000-0000-0000-000000000001','b9500000-0000-0000-0000-000000000001',service.library_id,service.id,'DRAFT','a9500000-0000-0000-0000-000000000001'
from public.catalog_services service
join public.catalog_service_versions version on version.id=service.current_published_version_id
where service.id='f9500000-0000-0000-0000-000000000016'and service.status='PUBLISHED' and version.status='PUBLISHED';
insert into public.service_request_versions(id,request_id,client_organization_id,library_id,version_number,description,urgency,desired_date,budget_minor,currency_code,required_quote_data,required_fields_complete,catalog_snapshot_hash,questionnaire_snapshot_hash,change_reason,content_hash,created_by)
select 'd9500000-0000-0000-0000-000000000001',request.id,request.client_organization_id,request.library_id,1,'Viewer read policy fixture','NORMAL',current_date,1000,'MAD','{}',true,version.content_hash,repeat('0',64),'Viewer policy fixture',repeat('a',64),'a9500000-0000-0000-0000-000000000001'
from public.service_requests request
join public.catalog_services service on service.id=request.service_id
join public.catalog_service_versions version on version.id=service.current_published_version_id
where request.id='c9500000-0000-0000-0000-000000000001';
update public.service_requests
set current_version_id='d9500000-0000-0000-0000-000000000001'
where id='c9500000-0000-0000-0000-000000000001';
insert into public.recurring_service_plans(id,client_organization_id,template_request_id,status,created_by)
values('e9500000-0000-0000-0000-000000000001','b9500000-0000-0000-0000-000000000001','c9500000-0000-0000-0000-000000000001','ACTIVE','a9500000-0000-0000-0000-000000000001');
insert into public.recurring_service_plan_versions(id,plan_id,version_number,cadence,starts_on,ends_on,status,reason,created_by)
values('e9500000-0000-0000-0000-000000000002','e9500000-0000-0000-0000-000000000001',1,'MONTHLY',current_date,current_date+30,'ACTIVE','Viewer policy fixture','a9500000-0000-0000-0000-000000000001');
insert into public.recurring_service_occurrences(id,plan_id,plan_version_id,client_organization_id,scheduled_on,generated_request_id,generated_request_version_id)
values('e9500000-0000-0000-0000-000000000003','e9500000-0000-0000-0000-000000000001','e9500000-0000-0000-0000-000000000002','b9500000-0000-0000-0000-000000000001',current_date,'c9500000-0000-0000-0000-000000000001','d9500000-0000-0000-0000-000000000001');

create temporary table p95_observed(key text primary key,value bigint not null);
grant select,insert on p95_observed to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','a9500000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"a9500000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into p95_observed values
('tenant_plan',(select count(*) from public.recurring_service_plans where id='e9500000-0000-0000-0000-000000000001')),
('tenant_version',(select count(*) from public.recurring_service_plan_versions where plan_id='e9500000-0000-0000-0000-000000000001')),
('tenant_occurrence',(select count(*) from public.recurring_service_occurrences where plan_id='e9500000-0000-0000-0000-000000000001'));
reset role;

select is((select value from p95_observed where key='tenant_plan'),1::bigint,'CLIENT_VIEWER can read its tenant recurring plan');
select is((select value from p95_observed where key='tenant_version'),1::bigint,'CLIENT_VIEWER can read its tenant plan version');
select is((select value from p95_observed where key='tenant_occurrence'),1::bigint,'CLIENT_VIEWER can read its tenant occurrences');
select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','a9500000-0000-0000-0000-000000000001',true); select set_config('request.jwt.claims','{"sub":"a9500000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true); select public.transition_recurring_service_plan('e9500000-0000-0000-0000-000000000001','PAUSE','Viewer mutation denied',1,'viewer-transition-denied-95','f9500000-0000-0000-0000-000000000001')$$,
  '42501'::char(5),'RECURRING_PLAN_SCOPE_DENIED','CLIENT_VIEWER cannot mutate a recurring plan'
);
select throws_ok(
  $$set local role authenticated; select set_config('request.jwt.claim.sub','a9500000-0000-0000-0000-000000000001',true); select set_config('request.jwt.claims','{"sub":"a9500000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true); select public.clone_service_request('c9500000-0000-0000-0000-000000000001',current_date+7,'Viewer clone denied','viewer-clone-denied-95','f9500000-0000-0000-0000-000000000002')$$,
  '42501'::char(5),'REQUEST_SCOPE_DENIED','CLIENT_VIEWER cannot clone a service request'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','a9500000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"a9500000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}',true);
insert into p95_observed values
('outsider_plan',(select count(*) from public.recurring_service_plans where id='e9500000-0000-0000-0000-000000000001')),
('outsider_occurrence',(select count(*) from public.recurring_service_occurrences where plan_id='e9500000-0000-0000-0000-000000000001'));
reset role;
select is((select value from p95_observed where key='outsider_plan'),0::bigint,'cross-tenant viewer cannot read the recurring plan');
select is((select value from p95_observed where key='outsider_occurrence'),0::bigint,'cross-tenant viewer cannot read occurrences');

select * from finish();
rollback;
