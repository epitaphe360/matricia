begin;
set local search_path=public,extensions;
select plan(6);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)values('a8700000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','manager-87@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)values('b8700000-0000-4000-8000-000000000001','Null Retention Runtime','Null Retention','ACTIVE','a8700000-0000-4000-8000-000000000001');
insert into public.organization_memberships(id,organization_id,user_id,status,activated_at)values('c8700000-0000-4000-8000-000000000001','b8700000-0000-4000-8000-000000000001','a8700000-0000-4000-8000-000000000001','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code,granted_by)values('c8700000-0000-4000-8000-000000000001','CLIENT_ADMIN','a8700000-0000-4000-8000-000000000001');
create temporary table assistance_null_observed(key text primary key,value jsonb);grant select,insert on assistance_null_observed to authenticated;
set local role authenticated;select set_config('request.jwt.claim.sub','a8700000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claims','{"sub":"a8700000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
insert into assistance_null_observed values
('null_input',public.run_assisted_analysis('b8700000-0000-4000-8000-000000000001','CONTEXTUAL_ASSISTANT',null,'{}','{}','{}','a1000000-0000-4000-8000-000000000001',null,'null-retention-0001','f8700000-0000-4000-8000-000000000001')),
('blank_input',public.run_assisted_analysis('b8700000-0000-4000-8000-000000000001','CONTEXTUAL_ASSISTANT','   ','{}','{}','{}','a1000000-0000-4000-8000-000000000001',null,'null-retention-0002','f8700000-0000-4000-8000-000000000002')),
('text_input',public.run_assisted_analysis('b8700000-0000-4000-8000-000000000001','CONTEXTUAL_ASSISTANT','Besoin audit sécurité','{}','{}','{}','a1000000-0000-4000-8000-000000000001',null,'null-retention-0003','f8700000-0000-4000-8000-000000000003'));reset role;

select ok((select input_text is null and input_text_expires_at is null from public.assistance_requests where id=((select value->>'request_id'from assistance_null_observed where key='null_input')::uuid)),'NULL input retains neither text nor expiry');
select ok((select input_text is null and input_text_expires_at is null from public.assistance_requests where id=((select value->>'request_id'from assistance_null_observed where key='blank_input')::uuid)),'blank input normalizes to NULL without expiry');
select ok((select input_text='Besoin audit sécurité'and input_text_expires_at=created_at+interval'30 days'from public.assistance_requests where id=((select value->>'request_id'from assistance_null_observed where key='text_input')::uuid)),'non-empty minimized input receives exactly thirty days retention');
select ok((select count(*)=0 from public.assistance_requests where input_text is null and input_text_expires_at is not null),'no NULL input row carries a retention deadline');
select ok((select p.prosrc like'%btrim(new.input_text)=''''%input_text_expires_at:=null%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='normalize_assistance_request_retention'),'insert normalization handles NULL and blank values explicitly');
select ok((select p.prosrc like'%old.input_text is null%new.input_text_expires_at is null%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='protect_assistance_request'),'immutable update guard preserves the NULL retention invariant');

select * from finish();rollback;
