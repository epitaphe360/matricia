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

insert into public.service_requests(id,client_organization_id,library_id,service_id,status,created_by)
select 'c9500000-0000-0000-0000-000000000001','b9500000-0000-0000-0000-000000000001',service.library_id,service.id,'DRAFT','a9500000-0000-0000-0000-000000000001'
from public.catalog_services service
join public.catalog_service_versions version on version.id=service.current_published_version_id
where service.status='PUBLISHED' and version.status='PUBLISHED'
order by service.code limit 1;
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

set local role authenticated;
select set_config('request.jwt.claim.sub','a9500000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"a9500000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true);
select is((select count(*) from public.recurring_service_plans where id='e9500000-0000-0000-0000-000000000001'),1::bigint,'CLIENT_VIEWER can read its tenant recurring plan');
select is((select count(*) from public.recurring_service_plan_versions where plan_id='e9500000-0000-0000-0000-000000000001'),1::bigint,'CLIENT_VIEWER can read its tenant plan version');
select is((select count(*) from public.recurring_service_occurrences where plan_id='e9500000-0000-0000-0000-000000000001'),1::bigint,'CLIENT_VIEWER can read its tenant occurrences');
select throws_ok(
  $$select public.transition_recurring_service_plan('e9500000-0000-0000-0000-000000000001','PAUSE','Viewer mutation denied',1,'viewer-transition-denied-95','f9500000-0000-0000-0000-000000000001')$$,
  '42501'::char(5),'RECURRING_PLAN_SCOPE_DENIED',
  'CLIENT_VIEWER cannot mutate a recurring plan'
);
select throws_ok(
  $$select public.clone_service_request('c9500000-0000-0000-0000-000000000001',current_date+7,'Viewer clone denied','viewer-clone-denied-95','f9500000-0000-0000-0000-000000000002')$$,
  '42501'::char(5),'REQUEST_SCOPE_DENIED',
  'CLIENT_VIEWER cannot clone a service request'
);

select set_config('request.jwt.claim.sub','a9500000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"a9500000-0000-0000-0000-000000000002","role":"authenticated","aal":"aal2"}',true);
select is((select count(*) from public.recurring_service_plans where id='e9500000-0000-0000-0000-000000000001'),0::bigint,'cross-tenant viewer cannot read the recurring plan');
select is((select count(*) from public.recurring_service_occurrences where plan_id='e9500000-0000-0000-0000-000000000001'),0::bigint,'cross-tenant viewer cannot read occurrences');
reset role;

select * from finish();
rollback;
