begin;
set local search_path=public,extensions;
select plan(34);

select ok((select count(*)=13 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relname=any(array['brand_assets','brand_claims','brand_restrictions','marketing_template_library_links','social_accounts','marketing_schedule_rules','marketing_schedule_rule_heads','marketing_calendars','marketing_trend_snapshots','campaign_suggestions','marketing_campaign_targets','marketing_leads','marketing_conversion_paths'])),'thirteen missing Gold Master marketing records exist');
select ok((select count(*)=13 and bool_and(c.relrowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname=any(array['brand_assets','brand_claims','brand_restrictions','marketing_template_library_links','social_accounts','marketing_schedule_rules','marketing_schedule_rule_heads','marketing_calendars','marketing_trend_snapshots','campaign_suggestions','marketing_campaign_targets','marketing_leads','marketing_conversion_paths'])),'RLS is enabled on every added marketing table');
select ok((select count(*)=13 from pg_policies where schemaname='public' and tablename=any(array['brand_assets','brand_claims','brand_restrictions','marketing_template_library_links','social_accounts','marketing_schedule_rules','marketing_schedule_rule_heads','marketing_calendars','marketing_trend_snapshots','campaign_suggestions','marketing_campaign_targets','marketing_leads','marketing_conversion_paths']) and qual like '%marketing_manage_access%'),'every added table has tenant scoped read policy');
select ok(not has_table_privilege('authenticated','public.brand_assets','INSERT') and not has_table_privilege('authenticated','public.marketing_leads','UPDATE'),'authenticated cannot bypass marketing commands');
select ok(not has_table_privilege('service_role','public.brand_assets','INSERT') and not has_table_privilege('service_role','public.marketing_conversion_paths','DELETE'),'service role has no broad direct mutation privilege');
select ok(not has_table_privilege('anon','public.marketing_calendars','SELECT'),'anonymous cannot read calendars');

select ok(exists(select 1 from pg_constraint where conrelid='public.brand_assets'::regclass and contype='c' and pg_get_constraintdef(oid) like '%PRIMARY_LOGO%' and pg_get_constraintdef(oid) like '%VIDEO%'),'Brand Kit assets constrain V1 media types');
select ok(exists(select 1 from pg_constraint where conrelid='public.brand_claims'::regclass and contype='c' and pg_get_constraintdef(oid) like '%VERIFIED%' and pg_get_constraintdef(oid) like '%EXPIRED%'),'claims carry verification lifecycle');
select ok(exists(select 1 from pg_constraint where conrelid='public.brand_restrictions'::regclass and contype='c' and pg_get_constraintdef(oid) like '%FORBIDDEN_TERM%' and pg_get_constraintdef(oid) like '%REQUIRED_MENTION%'),'brand restrictions cover required and forbidden language');
select ok(to_regclass('public.marketing_template_library_links') is not null,'versioned templates can be linked to a library');
select ok(exists(select 1 from pg_constraint where conrelid='public.social_accounts'::regclass and contype='c' and pg_get_constraintdef(oid) like '%DISCONNECTED%'),'social accounts support explicit disconnection');
select ok((select indexdef like '%organization_id, social_account_id%' from pg_indexes where schemaname='public' and indexname='marketing_schedule_rules_versions_idx'),'versioned schedule rules are scoped per social account');

select is((select column_default from information_schema.columns where table_schema='public' and table_name='marketing_schedule_rules' and column_name='posts_per_month'),'8','monthly schedule defaults to eight posts');
select is((select column_default from information_schema.columns where table_schema='public' and table_name='marketing_schedule_rules' and column_name='reels_per_month'),'4','monthly schedule defaults to four reels');
select is((select column_default from information_schema.columns where table_schema='public' and table_name='marketing_schedule_rules' and column_name='generation_day'),'25','monthly generation defaults to day twenty-five');
select ok(exists(select 1 from pg_constraint where conrelid='public.marketing_calendars'::regclass and contype='c' and pg_get_constraintdef(oid) like '%VALIDATED_BY_RULES%' and pg_get_constraintdef(oid) like '%PUBLISHED%' and pg_get_constraintdef(oid) like '%SKIPPED%'),'calendar lifecycle contains required states');
select ok((select is_nullable='NO' from information_schema.columns where table_schema='public' and table_name='marketing_calendar_items' and column_name='calendar_id'),'calendar item monthly relation is mandatory');

select ok(exists(select 1 from pg_constraint where conrelid='public.marketing_trend_snapshots'::regclass and contype='c' and pg_get_constraintdef(oid) like '%aggregate_size >= minimum_aggregate_size%'),'trend snapshots enforce their versioned privacy threshold');
select ok(not private.marketing_snapshot_keys_allowed('{"email":"x@example.invalid"}'::jsonb,array['sector','size_band','region']),'trend segment allowlist rejects direct identity keys');
select ok((select data_type='integer' from information_schema.columns where table_schema='public' and table_name='marketing_trend_snapshots' and column_name='growth_basis_points'),'trend growth uses exact basis points');
select ok(exists(select 1 from pg_constraint where conrelid='public.campaign_suggestions'::regclass and contype='c' and pg_get_constraintdef(oid) like '%PROPOSED%' and pg_get_constraintdef(oid) like '%REJECTED%'),'campaign suggestions require human-reviewable lifecycle');
select ok(exists(select 1 from pg_constraint where conrelid='public.marketing_campaign_targets'::regclass and contype='c' and pg_get_constraintdef(oid) like '%aggregate_size >= minimum_aggregate_size%'),'campaign targets enforce configurable aggregate audience minimum');
select ok(not private.marketing_snapshot_keys_allowed('{"customer_id":"abc"}'::jsonb,array['sector','size_band','region','channel','language']),'campaign target allowlist rejects unapproved identity keys');

select is((select column_default from information_schema.columns where table_schema='public' and table_name='marketing_conversion_paths' and column_name='attribution_model'),'''LAST_NON_DIRECT_CLICK''::text','attribution defaults to LAST_NON_DIRECT_CLICK');
select ok((select data_type='bigint' from information_schema.columns where table_schema='public' and table_name='marketing_conversion_paths' and column_name='attributed_value_minor'),'attributed value uses exact bigint minor units');
select ok(exists(select 1 from pg_constraint where conrelid='public.marketing_conversion_paths'::regclass and contype='c' and pg_get_constraintdef(oid) like '%attributed_value_minor%' and pg_get_constraintdef(oid) like '%currency%'),'conversion path amount and currency are paired');
select ok((select count(*)=3 from pg_trigger where tgname=any(array['marketing_schedule_rules_immutable','marketing_trends_immutable','marketing_conversion_paths_immutable']) and not tgisinternal),'rules trends and conversion paths are immutable histories');
select ok((select count(*)=9 from pg_indexes where schemaname='public' and indexname=any(array['brand_assets_org_version_idx','brand_claims_org_status_idx','marketing_template_library_links_idx','marketing_calendars_org_month_idx','marketing_calendar_items_calendar_idx','marketing_trends_period_idx','campaign_suggestions_queue_idx','marketing_leads_campaign_idx','marketing_paths_lead_idx'])),'new operational read paths are indexed');
select ok((select count(*)=13 from pg_trigger where tgname like '%_tenant' and tgfoid='private.enforce_marketing_v1_tenant_scope()'::regprocedure and not tgisinternal),'cross-tenant parent references are guarded');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('c1030000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','marketing-a@example.invalid','',now(),'{}','{}',now(),now()),
('c1030000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','marketing-b@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by) values
('ca030000-0000-0000-0000-000000000001','Marketing A SARL','Marketing A','ACTIVE','c1030000-0000-0000-0000-000000000001'),
('cb030000-0000-0000-0000-000000000002','Marketing B SARL','Marketing B','ACTIVE','c1030000-0000-0000-0000-000000000002');
insert into public.organization_memberships(organization_id,user_id,status,activated_at) values
('ca030000-0000-0000-0000-000000000001','c1030000-0000-0000-0000-000000000001','ACTIVE',now()),
('cb030000-0000-0000-0000-000000000002','c1030000-0000-0000-0000-000000000002','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code) select id,'CLIENT_OWNER' from public.organization_memberships where user_id in('c1030000-0000-0000-0000-000000000001','c1030000-0000-0000-0000-000000000002');
insert into public.marketing_trend_snapshots(organization_id,period_start,period_end,segment,privacy_policy_version,minimum_aggregate_size,aggregate_size,anomaly_count,growth_basis_points,source_hash) values
('ca030000-0000-0000-0000-000000000001','2026-08-01','2026-08-31','{"sector":"IT","region":"MA"}','privacy-v1',10,12,4,250,repeat('a',64)),
('cb030000-0000-0000-0000-000000000002','2026-08-01','2026-08-31','{"sector":"IT","region":"MA"}','privacy-v1',10,14,5,300,repeat('b',64));
insert into public.social_connections(id,organization_id,provider,status,scopes,credential_reference,connected_by) values('c1030000-0000-0000-0000-000000000010','cb030000-0000-0000-0000-000000000002','LINKEDIN','ACTIVE',array['w_member_social'],'vault://marketing-b','c1030000-0000-0000-0000-000000000002');
insert into public.social_connections(id,organization_id,provider,status,scopes,credential_reference,connected_by) values('c1030000-0000-0000-0000-000000000011','ca030000-0000-0000-0000-000000000001','LINKEDIN','ACTIVE',array['w_member_social'],'vault://marketing-a','c1030000-0000-0000-0000-000000000001');
insert into public.social_accounts(id,organization_id,connection_id,provider_account_reference,display_name,status) values('c1030000-0000-0000-0000-000000000012','ca030000-0000-0000-0000-000000000001','c1030000-0000-0000-0000-000000000011','account-a','Account A','ACTIVE');
insert into public.marketing_schedule_rules(id,organization_id,social_account_id,version,status,timezone,allowed_slots,content_hash,created_by) values
('c1030000-0000-0000-0000-000000000013','ca030000-0000-0000-0000-000000000001','c1030000-0000-0000-0000-000000000012',1,'ACTIVE','UTC','[]',repeat('c',64),'c1030000-0000-0000-0000-000000000001'),
('c1030000-0000-0000-0000-000000000014','ca030000-0000-0000-0000-000000000001','c1030000-0000-0000-0000-000000000012',2,'RETIRED','UTC','[]',repeat('d',64),'c1030000-0000-0000-0000-000000000001');
select lives_ok($$insert into public.marketing_schedule_rule_heads(organization_id,social_account_id,current_rule_id,updated_by) values('ca030000-0000-0000-0000-000000000001','c1030000-0000-0000-0000-000000000012','c1030000-0000-0000-0000-000000000013','c1030000-0000-0000-0000-000000000001')$$,'current head accepts an ACTIVE rule in the same tenant and account');
select throws_ok($$update public.marketing_schedule_rule_heads set current_rule_id='c1030000-0000-0000-0000-000000000014' where organization_id='ca030000-0000-0000-0000-000000000001'$$,'42501','MARKETING_CROSS_TENANT_REFERENCE','current head rejects an inactive rule');
select throws_ok($$insert into public.social_accounts(organization_id,connection_id,provider_account_reference,display_name,status) values('ca030000-0000-0000-0000-000000000001','c1030000-0000-0000-0000-000000000010','account-b','Cross tenant','ACTIVE')$$,'42501','MARKETING_CROSS_TENANT_REFERENCE','cross-tenant social account parent is rejected');

create temporary table marketing_rls_observed(key text primary key,value bigint);
grant insert,select on table marketing_rls_observed to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','c1030000-0000-0000-0000-000000000001',true);
insert into marketing_rls_observed values
('own',(select count(*) from public.marketing_trend_snapshots where organization_id='ca030000-0000-0000-0000-000000000001')),
('foreign',(select count(*) from public.marketing_trend_snapshots where organization_id='cb030000-0000-0000-0000-000000000002'));
reset role;
select is((select value from marketing_rls_observed where key='own'),1::bigint,'tenant owner can read its own marketing trend');
select is((select value from marketing_rls_observed where key='foreign'),0::bigint,'tenant owner cannot read another organization marketing trend');

select * from finish();
rollback;
