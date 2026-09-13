begin;
set local search_path=public,extensions;
select plan(40);

select has_function('public','generate_weekly_marketing_trends_v1',array['text','date','integer','uuid','text'],'weekly trend generator exists');
select ok((select p.prosecdef and p.proconfig::text like'%search_path=%'from pg_proc p where p.oid='public.generate_weekly_marketing_trends_v1(text,date,integer,uuid,text)'::regprocedure),'generator is hardened SECURITY DEFINER');
select ok(has_function_privilege('service_role','public.generate_weekly_marketing_trends_v1(text,date,integer,uuid,text)','EXECUTE')and not has_function_privilege('authenticated','public.generate_weekly_marketing_trends_v1(text,date,integer,uuid,text)','EXECUTE')and not has_function_privilege('anon','public.generate_weekly_marketing_trends_v1(text,date,integer,uuid,text)','EXECUTE'),'generator is service-role only');
select ok((select min(minimum_aggregate_size)>=10 from public.marketing_trend_policy_versions),'versioned privacy policy never permits k below ten');
select ok((select min(minimum_anomaly_count)>=1 and min(minimum_growth_basis_points)>=1 from public.marketing_trend_policy_versions),'versioned policy requires real anomaly volume and positive growth');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('70000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','trend-owner@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by)values
('71000000-0000-4000-8000-000000000001','Below Threshold SARL','Below Threshold','ACTIVE','70000000-0000-4000-8000-000000000001'),
('72000000-0000-4000-8000-000000000001','Consent Withdrawn SARL','Consent Withdrawn','ACTIVE','70000000-0000-4000-8000-000000000001'),
('73000000-0000-4000-8000-000000000001','Positive Trend SARL','Positive Trend','ACTIVE','70000000-0000-4000-8000-000000000001');
insert into public.organization_memberships(organization_id,user_id,status,activated_at)
values('73000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000001','ACTIVE',now());
insert into public.organization_member_roles(membership_id,role_code)
select id,'CLIENT_OWNER'from public.organization_memberships where organization_id='73000000-0000-4000-8000-000000000001';

set local session_replication_role=replica;
insert into public.catalog_libraries(id,code,slug,status,steward_organization_id,created_by)values
('74000000-0000-4000-8000-000000000001','TRENDLIB','trend-library','DRAFT','73000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000001');
insert into public.catalog_services(id,library_id,primary_subcategory_id,code,slug,status,created_by)values
('75000000-0000-4000-8000-000000000001','74000000-0000-4000-8000-000000000001','76000000-0000-4000-8000-000000000001','TREND_SERVICE_LOW','trend-service-low','DRAFT','70000000-0000-4000-8000-000000000001'),
('75000000-0000-4000-8000-000000000002','74000000-0000-4000-8000-000000000001','76000000-0000-4000-8000-000000000001','TREND_SERVICE_OFF','trend-service-off','DRAFT','70000000-0000-4000-8000-000000000001'),
('75000000-0000-4000-8000-000000000003','74000000-0000-4000-8000-000000000001','76000000-0000-4000-8000-000000000001','TREND_SERVICE_POS','trend-service-pos','DRAFT','70000000-0000-4000-8000-000000000001');

do $$
declare target_week date:=date_trunc('week',current_date)::date-7;i integer;org uuid;svc uuid;n integer;sess uuid;run uuid;anom uuid;
begin
  foreach org in array array['71000000-0000-4000-8000-000000000001'::uuid,'72000000-0000-4000-8000-000000000001'::uuid,'73000000-0000-4000-8000-000000000001'::uuid]loop
    svc:=case org when'71000000-0000-4000-8000-000000000001'::uuid then'75000000-0000-4000-8000-000000000001'::uuid when'72000000-0000-4000-8000-000000000001'::uuid then'75000000-0000-4000-8000-000000000002'::uuid else'75000000-0000-4000-8000-000000000003'::uuid end;
    n:=case when org='71000000-0000-4000-8000-000000000001'::uuid then 9 else 10 end;
    for i in 1..n loop
      sess:=extensions.gen_random_uuid();run:=extensions.gen_random_uuid();anom:=extensions.gen_random_uuid();
      insert into public.questionnaire_sessions(id,organization_id,actor_user_id,library_id,catalog_release_id,questionnaire_version_id,audience,locale,status,is_simulation,submitted_at,answer_manifest,answer_manifest_hash)
      values(sess,org,'70000000-0000-4000-8000-000000000001','74000000-0000-4000-8000-000000000001',extensions.gen_random_uuid(),extensions.gen_random_uuid(),'CLIENT','fr-MA','SUBMITTED',false,target_week+interval'1 day','{}',repeat('1',64));
      insert into public.diagnostic_runs(id,organization_id,questionnaire_session_id,library_id,status,input_manifest_hash,scoring_policy_snapshot,overall_score,rating,explanation,completed_by,completed_at,correlation_id)
      values(run,org,sess,'74000000-0000-4000-8000-000000000001','COMPLETED',repeat('2',64),jsonb_build_object('version','v1','content_hash',repeat('3',64),'thresholds','{}'::jsonb),50,'IMPORTANT','{}','70000000-0000-4000-8000-000000000001',target_week+interval'1 day',extensions.gen_random_uuid());
      insert into public.diagnostic_anomalies(id,diagnostic_run_id,organization_id,anomaly_code,severity,blocking,title_fr,title_ar,explanation,rule_snapshot,created_at)
      values(anom,run,org,'TREND_SIGNAL','HIGH',false,'Signal agrégé','إشارة مجمعة','{}','{}',target_week+interval'1 day');
      insert into public.diagnostic_recommendations(diagnostic_run_id,organization_id,anomaly_id,recommendation_key,priority,title_fr,title_ar,client_text_fr,client_text_ar,service_id,solution_level,rule_snapshot,created_at)
      values(run,org,anom,'TREND_ACTION',50,'Action agrégée','إجراء مجمع','Texte','نص',svc,'ASSISTED','{}',target_week+interval'1 day');
    end loop;
  end loop;
  -- Five prior-week observations make current growth exactly +10000 basis points for the positive tenant.
  for i in 1..5 loop
    sess:=extensions.gen_random_uuid();run:=extensions.gen_random_uuid();anom:=extensions.gen_random_uuid();
    insert into public.questionnaire_sessions(id,organization_id,actor_user_id,library_id,catalog_release_id,questionnaire_version_id,audience,locale,status,is_simulation,submitted_at,answer_manifest,answer_manifest_hash)
    values(sess,'73000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000001','74000000-0000-4000-8000-000000000001',extensions.gen_random_uuid(),extensions.gen_random_uuid(),'CLIENT','fr-MA','SUBMITTED',false,target_week-interval'6 days','{}',repeat('4',64));
    insert into public.diagnostic_runs(id,organization_id,questionnaire_session_id,library_id,status,input_manifest_hash,scoring_policy_snapshot,overall_score,rating,explanation,completed_by,completed_at,correlation_id)
    values(run,'73000000-0000-4000-8000-000000000001',sess,'74000000-0000-4000-8000-000000000001','COMPLETED',repeat('5',64),jsonb_build_object('version','v1','content_hash',repeat('6',64),'thresholds','{}'::jsonb),50,'IMPORTANT','{}','70000000-0000-4000-8000-000000000001',target_week-interval'6 days',extensions.gen_random_uuid());
    insert into public.diagnostic_anomalies(id,diagnostic_run_id,organization_id,anomaly_code,severity,blocking,title_fr,title_ar,explanation,rule_snapshot,created_at)
    values(anom,run,'73000000-0000-4000-8000-000000000001','TREND_SIGNAL','HIGH',false,'Signal agrégé','إشارة مجمعة','{}','{}',target_week-interval'6 days');
    insert into public.diagnostic_recommendations(diagnostic_run_id,organization_id,anomaly_id,recommendation_key,priority,title_fr,title_ar,client_text_fr,client_text_ar,service_id,solution_level,rule_snapshot,created_at)
    values(run,'73000000-0000-4000-8000-000000000001',anom,'TREND_ACTION',50,'Action agrégée','إجراء مجمع','Texte','نص','75000000-0000-4000-8000-000000000003','ASSISTED','{}',target_week-interval'6 days');
  end loop;
end$$;

with target as(
  select r.id run_id,r.organization_id
  from public.diagnostic_runs r join public.diagnostic_anomalies a on a.diagnostic_run_id=r.id
  where r.organization_id='73000000-0000-4000-8000-000000000001'
    and a.created_at>=date_trunc('week',current_date)::date-14
    and a.created_at<date_trunc('week',current_date)::date-7
  order by r.id limit 1
),extra as(
  insert into public.diagnostic_anomalies(id,diagnostic_run_id,organization_id,anomaly_code,severity,blocking,title_fr,title_ar,explanation,rule_snapshot,created_at)
  select extensions.gen_random_uuid(),run_id,organization_id,'TREND_SIGNAL_EXTRA','WARNING',false,'Signal supplémentaire','إشارة إضافية','{}','{}',date_trunc('week',current_date)::date-13 from target
  returning id,diagnostic_run_id,organization_id,created_at
)
insert into public.diagnostic_recommendations(diagnostic_run_id,organization_id,anomaly_id,recommendation_key,priority,title_fr,title_ar,client_text_fr,client_text_ar,service_id,solution_level,rule_snapshot,created_at)
select diagnostic_run_id,organization_id,id,'TREND_ACTION_EXTRA',40,'Action supplémentaire','إجراء إضافي','Texte','نص','75000000-0000-4000-8000-000000000003','GUIDANCE','{}',created_at from extra;

insert into public.brand_kits(id,organization_id,status,current_version_id,created_by)values
('77000000-0000-4000-8000-000000000002','72000000-0000-4000-8000-000000000001','READY','78000000-0000-4000-8000-000000000002','70000000-0000-4000-8000-000000000001'),
('77000000-0000-4000-8000-000000000003','73000000-0000-4000-8000-000000000001','READY','78000000-0000-4000-8000-000000000003','70000000-0000-4000-8000-000000000001');
insert into public.brand_kit_versions(id,brand_kit_id,version,payload,content_hash,change_reason,created_by)values
('78000000-0000-4000-8000-000000000002','77000000-0000-4000-8000-000000000002',1,'{"legal_name":"A","trade_name":"A","primary_colors":[],"tone":"pro","languages":["fr"],"primary_cta":"go","tracked_url":"https://example.invalid","required_mentions":[],"forbidden_terms":[],"approved_hashtags":[]}',repeat('7',64),'Initial brand','70000000-0000-4000-8000-000000000001'),
('78000000-0000-4000-8000-000000000003','77000000-0000-4000-8000-000000000003',1,'{"legal_name":"B","trade_name":"B","primary_colors":[],"tone":"pro","languages":["fr"],"primary_cta":"go","tracked_url":"https://example.invalid","required_mentions":[],"forbidden_terms":[],"approved_hashtags":[]}',repeat('8',64),'Initial brand','70000000-0000-4000-8000-000000000001');
insert into public.marketing_consents(organization_id,purpose,decision,policy_version,evidence_hash,decided_by,decided_at)values
('72000000-0000-4000-8000-000000000001','MARKETING_ANALYTICS','WITHDRAWN','v1',repeat('9',64),'70000000-0000-4000-8000-000000000001',now()),
('73000000-0000-4000-8000-000000000001','MARKETING_ANALYTICS','GRANTED','v1',repeat('a',64),'70000000-0000-4000-8000-000000000001',now());
insert into public.marketing_brand_authorizations(organization_id,decision,authorization_scope,policy_version,evidence_hash,effective_from,decided_by)values
('72000000-0000-4000-8000-000000000001','GRANTED',array['MARKETING_AUTOPILOT'],'v1',repeat('b',64),now()-interval'1 day','70000000-0000-4000-8000-000000000001'),
('73000000-0000-4000-8000-000000000001','GRANTED',array['MARKETING_AUTOPILOT'],'v1',repeat('c',64),now()-interval'1 day','70000000-0000-4000-8000-000000000001');
set local session_replication_role=origin;
select is((select count(distinct a.id)from public.diagnostic_anomalies a join public.diagnostic_runs r on r.id=a.diagnostic_run_id where r.organization_id='73000000-0000-4000-8000-000000000001'and a.created_at>=date_trunc('week',current_date)::date-14 and a.created_at<date_trunc('week',current_date)::date-7),6::bigint,'previous week fixture has multiple anomalies within one diagnostic run');

create temporary table trend_results(result jsonb);
grant insert,select on trend_results to service_role;
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
insert into trend_results select public.generate_weekly_marketing_trends_v1('trend-weekly-test-001',date_trunc('week',current_date)::date-7,100,'79000000-0000-4000-8000-000000000001');
reset role;

select is((select count(*)from public.marketing_trend_snapshots where period_start=date_trunc('week',current_date)::date-7),1::bigint,'only consented groups meeting k are persisted');
select is((select count(*)from public.marketing_trend_snapshots where organization_id='71000000-0000-4000-8000-000000000001'),0::bigint,'insufficient aggregate is suppressed');
select is((select count(*)from public.marketing_trend_snapshots where organization_id='72000000-0000-4000-8000-000000000001'),0::bigint,'withdrawn analytics consent suppresses the snapshot before aggregation');
select is((select count(*)from public.campaign_suggestions where organization_id='72000000-0000-4000-8000-000000000001'),0::bigint,'withdrawn analytics consent blocks suggestions');
select is((select count(*)from public.campaign_suggestions where organization_id='73000000-0000-4000-8000-000000000001'and status='PROPOSED'),1::bigint,'ready and authorized tenant receives PROPOSED suggestion');
select ok((select bool_and(service_id is not null)from public.marketing_trend_snapshots),'every generated trend is associated with a real service');
select ok((select bool_and(segment='{}'::jsonb and source_hash~'^[0-9a-f]{64}$')from public.marketing_trend_snapshots),'snapshots contain no free-form identifier or PII fields');
select is((select growth_basis_points from public.marketing_trend_snapshots where organization_id='73000000-0000-4000-8000-000000000001'),6667,'growth counts distinct anomalies, including multiple anomalies in one run, with exact basis points');
select is((select count(*)from public.audit_events where action='marketing.trend.snapshot_generated'),1::bigint,'each new snapshot is audited');
select is((select count(*)from public.audit_events where action='marketing.campaign_suggestion.proposed'),1::bigint,'positive suggestion is audited');
select is((select count(*)from public.event_outbox where event_type='MarketingTrendSnapshotGeneratedV1'),1::bigint,'snapshot events are outboxed');
select is((select count(*)from public.event_outbox where event_type='MarketingCampaignSuggestionProposedV1'),1::bigint,'suggestion event is outboxed');
select is((select result->>'generatedSnapshots'from trend_results limit 1),'1','bounded generation reports created snapshots');

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
insert into trend_results select public.generate_weekly_marketing_trends_v1('trend-weekly-test-001',date_trunc('week',current_date)::date-7,100,'79000000-0000-4000-8000-000000000001');
reset role;
select is((select count(*)from public.marketing_trend_snapshots),1::bigint,'idempotent replay creates no duplicate snapshot');
select is((select count(*)from public.campaign_suggestions),1::bigint,'idempotent replay creates no duplicate suggestion');
select is((select count(distinct result)from trend_results),1::bigint,'idempotent replay returns the cached response');

create temporary table tenant_observed(visible_count bigint,foreign_count bigint);
grant insert,select on tenant_observed to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','70000000-0000-4000-8000-000000000001',true);
insert into tenant_observed select count(*),count(*)filter(where organization_id<>'73000000-0000-4000-8000-000000000001')from public.marketing_trend_snapshots;
reset role;
select is((select visible_count from tenant_observed),1::bigint,'tenant member sees its own trend snapshot');
select is((select foreign_count from tenant_observed),0::bigint,'RLS denies cross-tenant trend visibility');
select isnt_empty($$select 1 from(select lower(pg_get_functiondef('public.generate_weekly_marketing_trends_v1(text,date,integer,uuid,text)'::regprocedure))d)x where d like'%marketing_consent_active(a.organization_id%'and strpos(d,'marketing_consent_active(a.organization_id')<strpos(d,'group by a.organization_id')$$,'consent is checked before source aggregation');
select isnt_empty($$select 1 from(select lower(pg_get_functiondef('public.generate_weekly_marketing_trends_v1(text,date,integer,uuid,text)'::regprocedure))d)x where d like'%b.status=''ready''%'$$,'brand kit must be READY');
select isnt_empty($$select 1 from(select lower(pg_get_functiondef('public.generate_weekly_marketing_trends_v1(text,date,integer,uuid,text)'::regprocedure))d)x where d like'%ba.decision=''granted''%'and d like'%ba.effective_until%'$$,'withdrawn or expired brand authorization is denied');
select isnt_empty($$select 1 from(select lower(pg_get_functiondef('public.generate_weekly_marketing_trends_v1(text,date,integer,uuid,text)'::regprocedure))d)x where d like'%marketing_kill_switch_versions%'and d like'%ks.enabled%'$$,'global and tenant kill switches block suggestions');
select isnt_empty($$select 1 from(select lower(pg_get_functiondef('public.generate_weekly_marketing_trends_v1(text,date,integer,uuid,text)'::regprocedure))d)x where d like'%growth_bps is not null%'and d like'%minimum_growth_basis_points%'$$,'undefined or sub-threshold growth blocks suggestions');
select isnt_empty($$select 1 from(select lower(pg_get_functiondef('public.generate_weekly_marketing_trends_v1(text,date,integer,uuid,text)'::regprocedure))d)x where d like'%eligible_count>p_limit%'and d like'%nextcursor%'$$,'bounded batches expose explicit continuation without silent starvation');

create procedure pg_temp.seed_positive_trend_week(p_week date)
language plpgsql as $$declare i integer;sess uuid;run uuid;anom uuid;begin
  for i in 1..15 loop
    sess:=extensions.gen_random_uuid();run:=extensions.gen_random_uuid();anom:=extensions.gen_random_uuid();
    insert into public.questionnaire_sessions(id,organization_id,actor_user_id,library_id,catalog_release_id,questionnaire_version_id,audience,locale,status,is_simulation,submitted_at,answer_manifest,answer_manifest_hash)
    values(sess,'73000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000001','74000000-0000-4000-8000-000000000001',extensions.gen_random_uuid(),extensions.gen_random_uuid(),'CLIENT','fr-MA','SUBMITTED',false,p_week+case when i<=10 then interval'1 day'else interval'-6 days'end,'{}',repeat('d',64));
    insert into public.diagnostic_runs(id,organization_id,questionnaire_session_id,library_id,status,input_manifest_hash,scoring_policy_snapshot,overall_score,rating,explanation,completed_by,completed_at,correlation_id)
    values(run,'73000000-0000-4000-8000-000000000001',sess,'74000000-0000-4000-8000-000000000001','COMPLETED',repeat('e',64),jsonb_build_object('version','v1','content_hash',repeat('f',64),'thresholds','{}'::jsonb),50,'IMPORTANT','{}','70000000-0000-4000-8000-000000000001',p_week+case when i<=10 then interval'1 day'else interval'-6 days'end,extensions.gen_random_uuid());
    insert into public.diagnostic_anomalies(id,diagnostic_run_id,organization_id,anomaly_code,severity,blocking,title_fr,title_ar,explanation,rule_snapshot,created_at)
    values(anom,run,'73000000-0000-4000-8000-000000000001','TREND_GATE','HIGH',false,'Signal agrégé','إشارة مجمعة','{}','{}',p_week+case when i<=10 then interval'1 day'else interval'-6 days'end);
    insert into public.diagnostic_recommendations(diagnostic_run_id,organization_id,anomaly_id,recommendation_key,priority,title_fr,title_ar,client_text_fr,client_text_ar,service_id,solution_level,rule_snapshot,created_at)
    values(run,'73000000-0000-4000-8000-000000000001',anom,'TREND_GATE_ACTION',50,'Action agrégée','إجراء مجمع','Texte','نص','75000000-0000-4000-8000-000000000003','ASSISTED','{}',p_week+case when i<=10 then interval'1 day'else interval'-6 days'end);
  end loop;
end$$;
set local session_replication_role=replica;
call pg_temp.seed_positive_trend_week(date_trunc('week',current_date)::date-28);
call pg_temp.seed_positive_trend_week(date_trunc('week',current_date)::date-49);
call pg_temp.seed_positive_trend_week(date_trunc('week',current_date)::date-70);
call pg_temp.seed_positive_trend_week(date_trunc('week',current_date)::date-91);
call pg_temp.seed_positive_trend_week(date_trunc('week',current_date)::date-112);
set local session_replication_role=origin;

update public.brand_kits set status='DRAFT'where id='77000000-0000-4000-8000-000000000003';
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
select public.generate_weekly_marketing_trends_v1('trend-gate-brand-draft',date_trunc('week',current_date)::date-28,100,'79000000-0000-4000-8000-000000000028',null);reset role;
select is((select count(*)from public.campaign_suggestions s join public.marketing_trend_snapshots t on t.id=s.trend_snapshot_id where t.period_start=date_trunc('week',current_date)::date-28),0::bigint,'brand non READY blocks a behaviorally eligible suggestion');
update public.brand_kits set status='READY'where id='77000000-0000-4000-8000-000000000003';

insert into public.marketing_brand_authorizations(organization_id,decision,authorization_scope,policy_version,evidence_hash,effective_from,decided_by,decided_at)
values('73000000-0000-4000-8000-000000000001','WITHDRAWN',array['MARKETING_AUTOPILOT'],'v2',repeat('1',64),now()-interval'1 day','70000000-0000-4000-8000-000000000001',clock_timestamp()+interval'1 second');
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
select public.generate_weekly_marketing_trends_v1('trend-gate-auth-withdrawn',date_trunc('week',current_date)::date-49,100,'79000000-0000-4000-8000-000000000049',null);reset role;
select is((select count(*)from public.campaign_suggestions s join public.marketing_trend_snapshots t on t.id=s.trend_snapshot_id where t.period_start=date_trunc('week',current_date)::date-49),0::bigint,'withdrawn brand authorization blocks an eligible suggestion');

insert into public.marketing_brand_authorizations(organization_id,decision,authorization_scope,policy_version,evidence_hash,effective_from,effective_until,decided_by,decided_at)
values('73000000-0000-4000-8000-000000000001','GRANTED',array['MARKETING_AUTOPILOT'],'v3',repeat('2',64),now()-interval'2 days',now()-interval'1 day','70000000-0000-4000-8000-000000000001',clock_timestamp()+interval'2 seconds');
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
select public.generate_weekly_marketing_trends_v1('trend-gate-auth-expired',date_trunc('week',current_date)::date-70,100,'79000000-0000-4000-8000-000000000070',null);reset role;
select is((select count(*)from public.campaign_suggestions s join public.marketing_trend_snapshots t on t.id=s.trend_snapshot_id where t.period_start=date_trunc('week',current_date)::date-70),0::bigint,'expired brand authorization blocks an eligible suggestion');

insert into public.marketing_brand_authorizations(organization_id,decision,authorization_scope,policy_version,evidence_hash,effective_from,decided_by,decided_at)
values('73000000-0000-4000-8000-000000000001','GRANTED',array['MARKETING_AUTOPILOT'],'v4',repeat('3',64),now()-interval'1 day','70000000-0000-4000-8000-000000000001',clock_timestamp()+interval'3 seconds');
insert into public.marketing_kill_switch_versions(organization_id,scope,provider,version,enabled,reason,evidence_hash,idempotency_key,request_hash,decided_by)
values('73000000-0000-4000-8000-000000000001','GLOBAL',null,1,true,'Test stop enabled',repeat('4',64),'trend-kill-on-001',repeat('5',64),'70000000-0000-4000-8000-000000000001');
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
select public.generate_weekly_marketing_trends_v1('trend-gate-kill-switch',date_trunc('week',current_date)::date-91,100,'79000000-0000-4000-8000-000000000091',null);reset role;
select is((select count(*)from public.campaign_suggestions s join public.marketing_trend_snapshots t on t.id=s.trend_snapshot_id where t.period_start=date_trunc('week',current_date)::date-91),0::bigint,'tenant kill switch blocks an eligible suggestion');

insert into public.marketing_kill_switch_versions(organization_id,scope,provider,version,enabled,reason,evidence_hash,idempotency_key,request_hash,decided_by)
values('73000000-0000-4000-8000-000000000001','GLOBAL',null,2,false,'Test stop disabled',repeat('6',64),'trend-kill-off-001',repeat('7',64),'70000000-0000-4000-8000-000000000001');
insert into public.marketing_trend_policy_versions(organization_id,version,status,privacy_policy_version,minimum_aggregate_size,minimum_anomaly_count,minimum_growth_basis_points,effective_from,policy_hash)
values('73000000-0000-4000-8000-000000000001',1,'ACTIVE','MARKETING-PRIVACY-HIGH-GROWTH',10,10,20000,'2020-01-01',repeat('8',64));
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
select public.generate_weekly_marketing_trends_v1('trend-gate-growth-threshold',date_trunc('week',current_date)::date-112,100,'79000000-0000-4000-8000-000000000112',null);reset role;
select is((select count(*)from public.campaign_suggestions s join public.marketing_trend_snapshots t on t.id=s.trend_snapshot_id where t.period_start=date_trunc('week',current_date)::date-112),0::bigint,'growth below the versioned threshold blocks suggestion');

set local session_replication_role=replica;
insert into public.catalog_services(id,library_id,primary_subcategory_id,code,slug,status,created_by)
values('75000000-0000-4000-8000-000000000004','74000000-0000-4000-8000-000000000001','76000000-0000-4000-8000-000000000001','TREND_SERVICE_PAGE','trend-service-page','DRAFT','70000000-0000-4000-8000-000000000001');
insert into public.diagnostic_recommendations(diagnostic_run_id,organization_id,anomaly_id,recommendation_key,priority,title_fr,title_ar,client_text_fr,client_text_ar,service_id,solution_level,rule_snapshot,created_at)
select r.id,r.organization_id,a.id,'TREND_PAGE_ACTION_'||row_number()over(partition by r.id order by a.id),50,'Action paginée','إجراء مرقم','Texte','نص','75000000-0000-4000-8000-000000000004','ASSISTED','{}',a.created_at
from public.diagnostic_runs r join public.diagnostic_anomalies a on a.diagnostic_run_id=r.id
where r.organization_id='73000000-0000-4000-8000-000000000001'and a.created_at>=date_trunc('week',current_date)::date-14;
set local session_replication_role=origin;
update private.marketing_trend_generation_checkpoints set resume_cursor=null,completed=false,completed_at=null
where week_start=date_trunc('week',current_date)::date-7;
create temporary table page_results(page integer,result jsonb);
grant insert,select on page_results to service_role;
set local role service_role;select set_config('request.jwt.claim.role','service_role',true);
insert into page_results select 1,public.generate_weekly_marketing_trends_v1('trend-pagination-page-1',date_trunc('week',current_date)::date-7,1,'79000000-0000-4000-8000-000000000201',null);
insert into page_results select 2,public.generate_weekly_marketing_trends_v1('trend-pagination-page-2',date_trunc('week',current_date)::date-7,1,'79000000-0000-4000-8000-000000000202',null);reset role;
select is((select(result->>'hasMore')::boolean from page_results where page=1),true,'a batch over its limit explicitly reports continuation');
select is((select count(*)from public.marketing_trend_snapshots where service_id='75000000-0000-4000-8000-000000000004'),1::bigint,'continuation cursor reaches the next eligible service without starvation');
select ok((select completed from private.marketing_trend_generation_checkpoints where week_start=date_trunc('week',current_date)::date-7),'database checkpoint durably completes pagination even when the next invocation omits the cursor');
select throws_ok($$update public.marketing_trend_policy_versions set minimum_aggregate_size=11 where id='00000000-0000-4000-8000-000000000186'$$,'55000','MARKETING_HISTORY_IMMUTABLE','privacy policies are immutable');
select set_config('request.jwt.claim.role','authenticated',true);
select throws_ok($$select public.generate_weekly_marketing_trends_v1('authenticated-deny',date_trunc('week',current_date)::date-7,100,extensions.gen_random_uuid())$$,'42501','MARKETING_TREND_GENERATION_DENIED','non-service execution is rejected inside the command');

select * from finish();
rollback;
