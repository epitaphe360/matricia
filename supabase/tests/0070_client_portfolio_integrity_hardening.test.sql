begin;
set local search_path=public,extensions;
select plan(25);

select ok((select count(*)=5 and bool_and(p.prosecdef and p.proconfig::text like'%search_path=%')from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname=any(array['client_invoice_belongs_to','client_typed_reference_valid','enforce_client_task_assignee_tenant','enforce_client_cost_allocation_reference','enforce_client_calendar_source'])),'reference and assignee guards are hardened');
select ok((select count(*)=4 from pg_trigger t join pg_class c on c.oid=t.tgrelid where c.relname in('client_projects','client_project_tasks','client_cost_allocations','client_calendar_events')and t.tgname in('client_project_state_machine','client_task_assignee_tenant_guard','client_cost_allocation_reference_guard','client_calendar_source_guard')and not t.tgisinternal),'four integrity triggers are installed');
select ok((select pg_get_functiondef(p.oid)like'%CLIENT_TASK_ASSIGNEE_OUTSIDE_TENANT%'and pg_get_functiondef(p.oid)like'%is_active_org_member%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='enforce_client_task_assignee_tenant'),'assignee guard requires active same-tenant membership');
select ok((select pg_get_functiondef(p.oid)like'%DRAFT%PLANNED%CANCELLED%'and pg_get_functiondef(p.oid)like'%ACTIVE%ON_HOLD%COMPLETED%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='enforce_client_project_state_transition'),'project state machine is explicit');
select ok((select pg_get_functiondef(p.oid)like'%PROJECT_TASK%'and pg_get_functiondef(p.oid)like'%MISSION_MILESTONE%'and pg_get_functiondef(p.oid)like'%DOCUMENT%'and pg_get_functiondef(p.oid)like'%RFQ%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='client_typed_reference_valid'),'typed reference resolver covers supported client objects');
select ok((select pg_get_functiondef(p.oid)like'%not exists%'and pg_get_functiondef(p.oid)like'%client_organization_id<>p_organization_id%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='client_invoice_belongs_to'),'mixed-client provider invoices fail closed');
select ok((select pg_get_functiondef(p.oid)like'%source_type not in%'and pg_get_functiondef(p.oid)like'%client_typed_reference_valid%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='enforce_client_calendar_source'),'calendar source whitelist fails closed');
select ok(not has_function_privilege('authenticated','private.client_typed_reference_valid(uuid,text,uuid,uuid)','EXECUTE'),'reference resolver is not client-callable');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values
('f7000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p70-owner-a@example.invalid','',now(),'{}','{}',now(),now()),
('f7000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p70-owner-b@example.invalid','',now(),'{}','{}',now(),now()),
('f7000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p70-inactive@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)values
('f7010000-0000-0000-0000-000000000001','P70 Client A SARL','P70 Client A','ACTIVE','f7000000-0000-0000-0000-000000000001'),
('f7010000-0000-0000-0000-000000000002','P70 Client B SARL','P70 Client B','ACTIVE','f7000000-0000-0000-0000-000000000002');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at)values
('f7020000-0000-0000-0000-000000000001','f7010000-0000-0000-0000-000000000001','f7000000-0000-0000-0000-000000000001','ACTIVE',now()),
('f7020000-0000-0000-0000-000000000002','f7010000-0000-0000-0000-000000000002','f7000000-0000-0000-0000-000000000002','ACTIVE',now()),
('f7020000-0000-0000-0000-000000000003','f7010000-0000-0000-0000-000000000001','f7000000-0000-0000-0000-000000000003','SUSPENDED',null);
insert into public.organization_member_roles(membership_id,role_code)values
('f7020000-0000-0000-0000-000000000001','CLIENT_OWNER'),
('f7020000-0000-0000-0000-000000000002','CLIENT_OWNER'),
('f7020000-0000-0000-0000-000000000003','CLIENT_MEMBER');
insert into public.client_projects(id,organization_id,project_code,status,created_by)values
('f7030000-0000-0000-0000-000000000001','f7010000-0000-0000-0000-000000000001','P70_A','DRAFT','f7000000-0000-0000-0000-000000000001'),
('f7030000-0000-0000-0000-000000000002','f7010000-0000-0000-0000-000000000002','P70_B','DRAFT','f7000000-0000-0000-0000-000000000002');
insert into public.client_annual_budgets(id,organization_id,fiscal_year,currency,project_id,status,created_by)values
('f7040000-0000-0000-0000-000000000001','f7010000-0000-0000-0000-000000000001',2027,'MAD','f7030000-0000-0000-0000-000000000001','APPROVED','f7000000-0000-0000-0000-000000000001');
insert into public.client_annual_budget_versions(id,budget_id,organization_id,version,amount_minor,approved_amount_minor,rationale,content_hash,created_by)values
('f7050000-0000-0000-0000-000000000001','f7040000-0000-0000-0000-000000000001','f7010000-0000-0000-0000-000000000001',1,100000,100000,'Budget approuvé P70',repeat('a',64),'f7000000-0000-0000-0000-000000000001');
insert into public.client_cost_centers(id,organization_id,code,created_by)values
('f7060000-0000-0000-0000-000000000001','f7010000-0000-0000-0000-000000000001','P70_CC','f7000000-0000-0000-0000-000000000001');

select set_config('request.jwt.claim.sub','f7000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"f7000000-0000-0000-0000-000000000001","role":"authenticated","aal":"aal2"}',true);

select ok(public.save_client_project_task('f7030000-0000-0000-0000-000000000001','TASK_ALLOW','TASK','PENDING',now()+interval'1 day','f7000000-0000-0000-0000-000000000001','Tâche permise','مهمة مسموحة',null,null,'[]','Création contrôlée',0,'p70-task-allow')->>'outcome'='CLIENT_PROJECT_TASK_SAVED','active same-tenant assignee is allowed');
select throws_ok($$select public.save_client_project_task('f7030000-0000-0000-0000-000000000001','TASK_CROSS','TASK','PENDING',now()+interval'1 day','f7000000-0000-0000-0000-000000000002','Tâche interdite','مهمة مرفوضة',null,null,'[]','Test inter organisation',0,'p70-task-cross')$$,'23514','CLIENT_TASK_ASSIGNEE_OUTSIDE_TENANT','cross-tenant assignee is denied');
select throws_ok($$select public.save_client_project_task('f7030000-0000-0000-0000-000000000001','TASK_INACTIVE','TASK','PENDING',now()+interval'1 day','f7000000-0000-0000-0000-000000000003','Tâche inactive','مهمة غير نشطة',null,null,'[]','Test membre suspendu',0,'p70-task-inactive')$$,'23514','CLIENT_TASK_ASSIGNEE_OUTSIDE_TENANT','inactive same-tenant assignee is denied');
select throws_ok($$select public.save_client_project_version('f7030000-0000-0000-0000-000000000001',2,null,'ACTIVE','Projet A','المشروع أ','Description projet A','وصف المشروع أ','[]','{}',null,null,'Transition directe interdite','p70-project-bad')$$,'55000','INVALID_CLIENT_PROJECT_TRANSITION','DRAFT to ACTIVE is denied');
select ok(public.save_client_project_version('f7030000-0000-0000-0000-000000000001',2,null,'PLANNED','Projet A','المشروع أ','Description projet A','وصف المشروع أ','[]','{}',null,null,'Planification permise','p70-project-plan')->>'outcome'='CLIENT_PROJECT_VERSION_SAVED','DRAFT to PLANNED is allowed');
select ok(public.record_client_cost_allocation('f7010000-0000-0000-0000-000000000001','f7060000-0000-0000-0000-000000000001','f7040000-0000-0000-0000-000000000001','f7030000-0000-0000-0000-000000000001','COMMITMENT',1000,'PROJECT','f7030000-0000-0000-0000-000000000001',repeat('b',64),'p70-alloc-allow')->>'outcome'='CLIENT_COST_ALLOCATED','same-tenant project allocation is allowed');
select throws_ok($$select public.record_client_cost_allocation('f7010000-0000-0000-0000-000000000001','f7060000-0000-0000-0000-000000000001','f7040000-0000-0000-0000-000000000001',null,'COMMITMENT',1000,'PROJECT','f7030000-0000-0000-0000-000000000002',repeat('c',64),'p70-alloc-cross')$$,'23514','CLIENT_COST_REFERENCE_OUTSIDE_TENANT_OR_INVALID','cross-tenant allocation reference is denied');
select throws_ok($$select public.record_client_cost_allocation('f7010000-0000-0000-0000-000000000001','f7060000-0000-0000-0000-000000000001','f7040000-0000-0000-0000-000000000001',null,'COMMITMENT',1000,'MANUAL','f7030000-0000-0000-0000-000000000001',repeat('d',64),'p70-alloc-manual')$$,'23514','CLIENT_COST_REFERENCE_OUTSIDE_TENANT_OR_INVALID','manual allocation rejects an untyped identifier');
select ok(public.schedule_client_calendar_event('f7010000-0000-0000-0000-000000000001','f7030000-0000-0000-0000-000000000001','PROJECT_DEADLINE','Échéance projet','موعد المشروع',now()+interval'2 days',null,'PROJECT','f7030000-0000-0000-0000-000000000001','p70-cal-allow')->>'outcome'='CLIENT_CALENDAR_EVENT_SCHEDULED','same-tenant calendar source is allowed');
select throws_ok($$select public.schedule_client_calendar_event('f7010000-0000-0000-0000-000000000001',null,'PROJECT_DEADLINE','Échéance externe','موعد خارجي',now()+interval'2 days',null,'PROJECT','f7030000-0000-0000-0000-000000000002','p70-cal-cross')$$,'23514','CLIENT_CALENDAR_SOURCE_OUTSIDE_TENANT_OR_INVALID','cross-tenant calendar source is denied');
select throws_ok($$select public.schedule_client_calendar_event('f7010000-0000-0000-0000-000000000001',null,'CUSTOM','Source inconnue','مصدر مجهول',now()+interval'2 days',null,'UNKNOWN','f7030000-0000-0000-0000-000000000001','p70-cal-unknown')$$,'23514','CLIENT_CALENDAR_SOURCE_OUTSIDE_TENANT_OR_INVALID','unknown calendar source type is denied');
select ok(public.schedule_client_calendar_event('f7010000-0000-0000-0000-000000000001',null,'CUSTOM','Événement manuel','حدث يدوي',now()+interval'3 days',null,null,null,'p70-cal-manual')->>'outcome'='CLIENT_CALENDAR_EVENT_SCHEDULED','calendar event without source remains allowed');

select ok((select count(*)=1 from public.client_project_tasks where project_id='f7030000-0000-0000-0000-000000000001'),'denied assignee writes leave no partial task');
select ok((select status='PLANNED'and current_version=2 from public.client_projects where id='f7030000-0000-0000-0000-000000000001'),'only the authorized project transition persists');
select ok((select count(*)=1 from public.client_cost_allocations where organization_id='f7010000-0000-0000-0000-000000000001'),'denied allocation references leave no partial ledger entry');
select ok((select count(*)=2 from public.client_calendar_events where organization_id='f7010000-0000-0000-0000-000000000001'),'only valid sourced and manual calendar events persist');
select ok((select count(*)=5 from public.audit_events where organization_id='f7010000-0000-0000-0000-000000000001'and action in('client.project_task.saved','client.project.version_saved','client.cost.allocated','client.calendar_event.scheduled')),'allowed commands emit audit evidence');

select * from finish();
rollback;
