-- MAT-FUNC-016/017/024: authoritative reputation evidence and executable published checklists.

alter table public.service_checklist_templates
  add column publication_status text not null default 'DRAFT'
    check (publication_status in('DRAFT','PUBLISHED')),
  add column published_at timestamptz,
  add column published_by uuid references auth.users(id) on delete restrict;

create or replace function private.valid_published_checklist_items_v1(p_items jsonb)
returns boolean language sql immutable set search_path=pg_catalog as $$
 select p_items is not null and jsonb_typeof(p_items)='array'
   and jsonb_array_length(p_items) between 1 and 100
   and not exists(
     select 1 from jsonb_array_elements(p_items) item
     where jsonb_typeof(item)<>'object'
       or exists(select 1 from jsonb_object_keys(item) key where key not in
         ('key','label_fr','label_ar','instructions_fr','instructions_ar','proof_required','proof_types'))
       or coalesce(item->>'key','')!~'^[A-Z][A-Z0-9_-]{1,79}$'
       or length(btrim(coalesce(item->>'label_fr',''))) not between 2 and 500
       or length(btrim(coalesce(item->>'label_ar',''))) not between 2 and 500
       or length(btrim(coalesce(item->>'instructions_fr',''))) not between 3 and 2000
       or length(btrim(coalesce(item->>'instructions_ar',''))) not between 3 and 2000
       or jsonb_typeof(coalesce(item->'proof_required','null'::jsonb))<>'boolean'
       or jsonb_typeof(coalesce(item->'proof_types','null'::jsonb))<>'array'
       or jsonb_array_length(item->'proof_types')>5
       or exists(select 1 from jsonb_array_elements_text(item->'proof_types') p where p not in('DOCUMENT','IMAGE','URL','CHECKLIST','OTHER'))
       or ((item->>'proof_required')::boolean and jsonb_array_length(item->'proof_types')=0)
   )
   and (select count(*)=count(distinct item->>'key') from jsonb_array_elements(p_items) item)
$$;
revoke all on function private.valid_published_checklist_items_v1(jsonb) from public,anon,authenticated,service_role;

alter table public.mission_checklist_items
  add column checklist_snapshot_id uuid references public.mission_checklist_snapshots(id) on delete restrict,
  add column instructions_fr text,
  add column instructions_ar text,
  add column allowed_proof_types text[] not null default '{}',
  add column completion_proof_id uuid references public.delivery_proofs(id) on delete restrict;

update public.mission_checklist_items item
set checklist_snapshot_id=snapshot.id,
    instructions_fr=nullif(source_item->>'instructions_fr',''),
    instructions_ar=nullif(source_item->>'instructions_ar',''),
    allowed_proof_types=coalesce(array(select jsonb_array_elements_text(coalesce(source_item->'proof_types','[]'::jsonb))),array[]::text[])
from public.mission_checklist_snapshots snapshot
cross join lateral jsonb_array_elements(snapshot.items) source_item
where snapshot.mission_id=item.mission_id and source_item->>'key'=item.item_key;

alter table public.mission_checklist_items add constraint mission_checklist_completion_consistent_v1
check (
 (status='PENDING' and completed_by is null and completed_at is null and completion_proof_id is null)
 or (status='COMPLETED' and completed_by is not null and completed_at is not null and (not proof_required or completion_proof_id is not null))
 or (status='WAIVED' and completed_by is not null and completed_at is not null)
) not valid;

create or replace function private.bind_mission_checklist_item_snapshot_v1()
returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$
declare v_snapshot public.mission_checklist_snapshots%rowtype;v_item jsonb;
begin
 select * into v_snapshot from public.mission_checklist_snapshots where mission_id=new.mission_id;
 if not found then raise exception 'MISSION_CHECKLIST_SNAPSHOT_REQUIRED' using errcode='55000';end if;
 select value into v_item from jsonb_array_elements(v_snapshot.items) where value->>'key'=new.item_key limit 1;
 if v_item is null then raise exception 'MISSION_CHECKLIST_ITEM_NOT_IN_SNAPSHOT' using errcode='22023';end if;
 new.checklist_snapshot_id:=v_snapshot.id;
 new.label_fr:=btrim(v_item->>'label_fr');new.label_ar:=btrim(v_item->>'label_ar');
 new.instructions_fr:=nullif(btrim(coalesce(v_item->>'instructions_fr','')),'');
 new.instructions_ar:=nullif(btrim(coalesce(v_item->>'instructions_ar','')),'');
 new.proof_required:=coalesce((v_item->>'proof_required')::boolean,false);
 new.allowed_proof_types:=coalesce(array(select jsonb_array_elements_text(coalesce(v_item->'proof_types','[]'::jsonb))),array[]::text[]);
 return new;
end$$;
revoke all on function private.bind_mission_checklist_item_snapshot_v1() from public,anon,authenticated,service_role;
create trigger mission_checklist_item_snapshot_binding_v1 before insert on public.mission_checklist_items
for each row execute function private.bind_mission_checklist_item_snapshot_v1();

create table public.mission_provider_feedback (
 id uuid primary key default extensions.gen_random_uuid(),
 mission_id uuid not null unique references public.missions(id) on delete restrict,
 client_organization_id uuid not null references public.organizations(id) on delete restrict,
 provider_organization_id uuid not null references public.organizations(id) on delete restrict,
 service_id uuid not null references public.catalog_services(id) on delete restrict,
 quality_basis_points integer not null check(quality_basis_points between 0 and 10000),
 compliance_basis_points integer not null check(compliance_basis_points between 0 and 10000),
 satisfaction_basis_points integer not null check(satisfaction_basis_points between 0 and 10000),
 feedback_snapshot jsonb not null check(jsonb_typeof(feedback_snapshot)='object'),
 content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),
 submitted_by uuid not null references auth.users(id) on delete restrict,
 correlation_id uuid not null,submitted_at timestamptz not null default clock_timestamp(),
 check(client_organization_id<>provider_organization_id),unique(id,provider_organization_id)
);

create table public.provider_reputation_evidence_events (
 id uuid primary key default extensions.gen_random_uuid(),
 provider_organization_id uuid not null references public.provider_profiles(provider_organization_id) on delete restrict,
 service_id uuid references public.catalog_services(id) on delete restrict,
 source_type text not null check(source_type in('DELIVERY','FEEDBACK','FINANCE','RESPONSIVENESS')),
 source_id uuid not null,dimension text not null check(dimension in('QUALITY','DELIVERY','COMPLIANCE','RESPONSIVENESS','SATISFACTION','FINANCE')),
 score_basis_points integer not null check(score_basis_points between 0 and 10000),
 source_snapshot jsonb not null check(jsonb_typeof(source_snapshot)='object'),
 content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),occurred_at timestamptz not null,
 created_at timestamptz not null default clock_timestamp(),
 unique(provider_organization_id,source_type,source_id,dimension)
);
create index provider_reputation_evidence_lookup_v1 on public.provider_reputation_evidence_events(provider_organization_id,service_id,dimension,occurred_at desc);

create trigger mission_provider_feedback_immutable_v1 before update or delete on public.mission_provider_feedback
for each row execute function private.prevent_provider_reputation_snapshot_mutation();
create trigger provider_reputation_evidence_immutable_v1 before update or delete on public.provider_reputation_evidence_events
for each row execute function private.prevent_provider_reputation_snapshot_mutation();

alter table public.mission_provider_feedback enable row level security;
alter table public.provider_reputation_evidence_events enable row level security;
revoke all on public.mission_provider_feedback,public.provider_reputation_evidence_events from public,anon,authenticated,service_role;
grant select on public.mission_provider_feedback,public.provider_reputation_evidence_events to authenticated;
create policy mission_provider_feedback_client_admin_read_v1 on public.mission_provider_feedback for select to authenticated
using(private.has_org_role(client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN']) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR']));
create policy provider_reputation_evidence_provider_read_v1 on public.provider_reputation_evidence_events for select to authenticated
using(private.is_active_org_member(provider_organization_id) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR']));

create or replace function public.publish_service_checklist_template(
 p_audit_organization_id uuid,p_service_version_id uuid,p_items jsonb,p_change_reason text,
 p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();h text;cached jsonb;v integer;x uuid;r jsonb;
begin
 if a is null or auth.jwt()->>'aal'is distinct from'aal2' or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','LIBRARY_MANAGER'],a)then raise exception'CHECKLIST_PUBLISH_DENIED'using errcode='42501';end if;
 if not exists(select 1 from public.catalog_service_versions sv join public.catalog_services s on s.id=sv.service_id join public.catalog_libraries l on l.id=s.library_id where sv.id=p_service_version_id and sv.status='PUBLISHED' and s.current_published_version_id=sv.id and l.steward_organization_id=p_audit_organization_id) or not private.valid_published_checklist_items_v1(p_items) or length(btrim(coalesce(p_change_reason,'')))not between 3 and 500 then raise exception'INVALID_CHECKLIST_PUBLICATION'using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('operation','service.checklist.publish.v1','service_version',p_service_version_id,'items',p_items,'reason',btrim(p_change_reason)));
 cached:=private.begin_contract_command(p_audit_organization_id,'service.checklist.publish',p_idempotency_key,h,a);if cached is not null then return cached;end if;
 perform pg_advisory_xact_lock(hashtextextended('service-checklist:'||p_service_version_id::text,0));
 select coalesce(max(version),0)+1 into v from public.service_checklist_templates where service_version_id=p_service_version_id;
 insert into public.service_checklist_templates(service_version_id,version,items,content_hash,created_by,publication_status,published_at,published_by)
 values(p_service_version_id,v,p_items,h,a,'PUBLISHED',clock_timestamp(),a)returning id into x;
 r:=jsonb_build_object('outcome','SERVICE_CHECKLIST_PUBLISHED','template_id',x,'version',v,'content_hash',h,'item_count',jsonb_array_length(p_items));
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_audit_organization_id,a,'USER','service.checklist.published','service_checklist_template',x::text,p_correlation_id,r||jsonb_build_object('change_reason',btrim(p_change_reason)),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_audit_organization_id,'service_checklist_template',x::text,'ServiceChecklistPublishedV1',p_correlation_id,r,p_idempotency_key);
 perform private.finish_contract_command(p_audit_organization_id,'service.checklist.publish',p_idempotency_key,r);return r;
end$$;

create or replace function public.complete_mission_checklist_item(
 p_item_id uuid,p_expected_status text,p_proof_id uuid,p_idempotency_key text,
 p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();i public.mission_checklist_items%rowtype;m public.missions%rowtype;p public.delivery_proofs%rowtype;h text;cached jsonb;r jsonb;
begin
 select * into i from public.mission_checklist_items where id=p_item_id;
 if not found then raise exception'CHECKLIST_ITEM_NOT_FOUND'using errcode='P0002';end if;
 select * into m from public.missions where id=i.mission_id;
 if a is null or not private.has_org_role(m.provider_organization_id,array['PROVIDER_OWNER','PROVIDER_MANAGER','PROVIDER_TECHNICIAN'],a)then raise exception'CHECKLIST_COMPLETE_DENIED'using errcode='42501';end if;
 h:=private.canonical_request_hash(jsonb_build_object('operation','mission.checklist.complete.v1','item',p_item_id,'expected',p_expected_status,'proof',p_proof_id));
 cached:=private.begin_contract_command(m.provider_organization_id,'mission.checklist.complete',p_idempotency_key,h,a);if cached is not null then return cached;end if;
 select * into i from public.mission_checklist_items where id=p_item_id for update;
 if m.status not in('ACTIVE','DELIVERY_SUBMITTED','ACCEPTANCE_IN_PROGRESS') or i.status is distinct from p_expected_status or p_expected_status<>'PENDING'then raise exception'INVALID_CHECKLIST_TRANSITION'using errcode='55000';end if;
 if p_proof_id is not null then select proof.* into p from public.delivery_proofs proof join public.delivery_versions dv on dv.id=proof.delivery_version_id join public.deliverables d on d.id=dv.deliverable_id where proof.id=p_proof_id and d.mission_id=i.mission_id and proof.scan_status='CLEAN' and(cardinality(i.allowed_proof_types)=0 or proof.proof_type=any(i.allowed_proof_types));end if;
 if (i.proof_required and p.id is null)or(p_proof_id is not null and p.id is null)then raise exception'CLEAN_CHECKLIST_PROOF_REQUIRED'using errcode='55000';end if;
 update public.mission_checklist_items set status='COMPLETED',completed_by=a,completed_at=clock_timestamp(),completion_proof_id=p_proof_id where id=i.id;
 r:=jsonb_build_object('outcome','MISSION_CHECKLIST_ITEM_COMPLETED','item_id',i.id,'mission_id',i.mission_id,'proof_id',p_proof_id);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(m.provider_organization_id,a,'USER','mission.checklist_item.completed','mission_checklist_item',i.id::text,p_correlation_id,jsonb_build_object('mission_id',i.mission_id,'proof_id',p_proof_id,'snapshot_id',i.checklist_snapshot_id),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(m.provider_organization_id,'mission',i.mission_id::text,'MissionChecklistItemCompletedV1',p_correlation_id,r,p_idempotency_key);
 perform private.finish_contract_command(m.provider_organization_id,'mission.checklist.complete',p_idempotency_key,r);return r;
end$$;

create or replace function public.submit_mission_provider_feedback(
 p_mission_id uuid,p_quality_basis_points integer,p_compliance_basis_points integer,p_satisfaction_basis_points integer,
 p_feedback_snapshot jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();m public.missions%rowtype;s uuid;h text;cached jsonb;x uuid;r jsonb;quality integer;compliance integer;satisfaction integer;acceptance_total integer;checklist_total integer;rubric_total integer;
begin
 select * into m from public.missions where id=p_mission_id;
 if not found then raise exception'MISSION_NOT_FOUND'using errcode='P0002';end if;
 if a is null or not private.has_org_role(m.client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a)then raise exception'MISSION_FEEDBACK_DENIED'using errcode='42501';end if;
 h:=private.canonical_request_hash(jsonb_build_object('operation','mission.feedback.submit.v2','mission',p_mission_id,'quality',p_quality_basis_points,'compliance',p_compliance_basis_points,'satisfaction',p_satisfaction_basis_points,'snapshot',p_feedback_snapshot));
 cached:=private.begin_provider_reputation_command(m.client_organization_id,a,'mission.feedback.submit',p_idempotency_key,h);if cached is not null then return cached;end if;
 if m.status<>'COMPLETED' or jsonb_typeof(p_feedback_snapshot)<>'object' or not(p_feedback_snapshot?&array['summary_code','criteria']) or exists(select 1 from jsonb_object_keys(p_feedback_snapshot)k where k not in('summary_code','criteria')) or coalesce(p_feedback_snapshot->>'summary_code','')!~'^[A-Z][A-Z0-9_-]{2,79}$' or jsonb_typeof(p_feedback_snapshot->'criteria')<>'array' or jsonb_array_length(p_feedback_snapshot->'criteria')<>3 or exists(select 1 from jsonb_array_elements(p_feedback_snapshot->'criteria')c where jsonb_typeof(c)<>'object' or exists(select 1 from jsonb_object_keys(c)k where k not in('key','rating')) or c->>'key' not in('COMMUNICATION','PROFESSIONALISM','VALUE') or (c->>'rating')!~'^[1-5]$') or (select count(distinct c->>'key') from jsonb_array_elements(p_feedback_snapshot->'criteria')c)<>3 then raise exception'INVALID_MISSION_FEEDBACK'using errcode='22023';end if;
 select count(*)::integer,round(10000::numeric*count(*)filter(where ac.status='COMPLIANT')/nullif(count(*),0))::integer into acceptance_total,quality from public.deliverables d join public.acceptance_checklists ac on ac.deliverable_id=d.id where d.mission_id=m.id and d.status='ACCEPTED' and ac.status in('COMPLIANT','NONCOMPLIANT');
 select count(*)::integer,round(10000::numeric*count(*)filter(where ci.status='COMPLETED')/nullif(count(*),0))::integer into checklist_total,compliance from public.mission_checklist_items ci where ci.mission_id=m.id;
 select count(*)::integer,round(avg(((c->>'rating')::integer-1)*2500))::integer into rubric_total,satisfaction from jsonb_array_elements(p_feedback_snapshot->'criteria')c;
 if acceptance_total=0 or checklist_total=0 or rubric_total<>3 or p_quality_basis_points is distinct from quality or p_compliance_basis_points is distinct from compliance or p_satisfaction_basis_points is distinct from satisfaction then raise exception'FEEDBACK_SCORE_NOT_AUTHORITATIVE'using errcode='23514';end if;
 select sr.service_id into s from public.contract_versions cv join public.quote_versions qv on qv.id=cv.selected_quote_version_id join public.quotes q on q.id=qv.quote_id join public.rfqs rfq on rfq.id=q.rfq_id join public.service_requests sr on sr.id=rfq.request_id where cv.id=m.contract_version_id;
 if s is null then raise exception'MISSION_SERVICE_SNAPSHOT_MISSING'using errcode='55000';end if;
 insert into public.mission_provider_feedback(mission_id,client_organization_id,provider_organization_id,service_id,quality_basis_points,compliance_basis_points,satisfaction_basis_points,feedback_snapshot,content_hash,submitted_by,correlation_id)values(m.id,m.client_organization_id,m.provider_organization_id,s,p_quality_basis_points,p_compliance_basis_points,p_satisfaction_basis_points,p_feedback_snapshot,h,a,p_correlation_id)returning id into x;
 r:=jsonb_build_object('outcome','MISSION_PROVIDER_FEEDBACK_SUBMITTED','feedback_id',x,'mission_id',m.id);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(m.client_organization_id,a,'USER','mission.provider_feedback.submitted','mission_provider_feedback',x::text,p_correlation_id,jsonb_build_object('mission_id',m.id,'provider_organization_id',m.provider_organization_id),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(m.provider_organization_id,'mission',m.id::text,'MissionProviderFeedbackSubmittedV1',p_correlation_id,r,p_idempotency_key);
 perform private.finish_provider_reputation_command(m.client_organization_id,'mission.feedback.submit',p_idempotency_key,r);return r;
end$$;

create or replace function public.refresh_provider_reputation_from_events(
 p_provider_organization_id uuid,p_service_id uuid,p_policy_version text,p_idempotency_key text,
 p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();pol public.provider_reputation_policy_versions%rowtype;h text;cached jsonb;dims jsonb;refs jsonb;cnt integer;overall integer;ver integer;snapshot_id uuid;r jsonb;badge_count integer:=0;b record;badge_score integer;eligible boolean;eval_ver integer;eval_id uuid;
begin
 if a is null or auth.jwt()->>'aal'is distinct from'aal2' or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],a)then raise exception'AUTHORITATIVE_REPUTATION_REFRESH_DENIED'using errcode='42501';end if;
 if not exists(select 1 from public.provider_profiles where provider_organization_id=p_provider_organization_id)or(p_service_id is not null and not exists(select 1 from public.provider_services where provider_organization_id=p_provider_organization_id and service_id=p_service_id))then raise exception'PROVIDER_REPUTATION_SCOPE_DENIED'using errcode='42501';end if;
 select * into pol from public.provider_reputation_policy_versions where policy_version=p_policy_version and effective_from<=clock_timestamp()and(effective_until is null or effective_until>clock_timestamp());if not found then raise exception'REPUTATION_POLICY_NOT_ACTIVE'using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('operation','provider.reputation.refresh.events.v1','provider',p_provider_organization_id,'service',p_service_id,'policy',p_policy_version));
 cached:=private.begin_provider_reputation_command(p_provider_organization_id,a,'provider.reputation.refresh.events',p_idempotency_key,h);if cached is not null then return cached;end if;
 perform pg_advisory_xact_lock(hashtextextended('provider-reputation-events:'||p_provider_organization_id::text||':'||coalesce(p_service_id::text,'GLOBAL'),0));
 with mission_service as(
  select m.id,m.provider_organization_id,sr.service_id from public.missions m join public.contract_versions cv on cv.id=m.contract_version_id join public.quote_versions qv on qv.id=cv.selected_quote_version_id join public.quotes q on q.id=qv.quote_id join public.rfqs rfq on rfq.id=q.rfq_id join public.service_requests sr on sr.id=rfq.request_id where m.provider_organization_id=p_provider_organization_id and(p_service_id is null or sr.service_id=p_service_id)
 ),source as(
  select ms.provider_organization_id,ms.service_id,'DELIVERY'::text source_type,d.id source_id,'QUALITY'::text dimension,round(10000::numeric*count(*)filter(where ac.status='COMPLIANT')/count(*))::integer score,jsonb_build_object('deliverable_id',d.id,'accepted_version',d.current_version,'criteria',count(ac.id)) snap,max(coalesce(ac.decided_at,dv.submitted_at)) occurred_at from mission_service ms join public.deliverables d on d.mission_id=ms.id and d.status='ACCEPTED' join public.delivery_versions dv on dv.deliverable_id=d.id and dv.version=d.current_version join public.acceptance_checklists ac on ac.deliverable_id=d.id and ac.status in('COMPLIANT','NONCOMPLIANT') group by ms.provider_organization_id,ms.service_id,d.id
  union all select ms.provider_organization_id,ms.service_id,'DELIVERY',d.id,'COMPLIANCE',round(10000::numeric*count(*)filter(where ac.status='COMPLIANT')/count(*))::integer,jsonb_build_object('deliverable_id',d.id,'criteria',count(ac.id)),max(coalesce(ac.decided_at,dv.submitted_at)) from mission_service ms join public.deliverables d on d.mission_id=ms.id and d.status='ACCEPTED' join public.delivery_versions dv on dv.deliverable_id=d.id and dv.version=d.current_version join public.acceptance_checklists ac on ac.deliverable_id=d.id and ac.status in('COMPLIANT','NONCOMPLIANT') group by ms.provider_organization_id,ms.service_id,d.id
  union all select ms.provider_organization_id,ms.service_id,'DELIVERY',mm.id,'DELIVERY',case when mm.due_at is null or mm.decided_at<=mm.due_at then 10000 else greatest(0,10000-(extract(epoch from(mm.decided_at-mm.due_at))/86400)::integer*500)end,jsonb_build_object('milestone_id',mm.id,'due_at',mm.due_at,'decided_at',mm.decided_at),mm.decided_at from mission_service ms join public.mission_milestones mm on mm.mission_id=ms.id and mm.status='ACCEPTED'
  union all select f.provider_organization_id,f.service_id,'FEEDBACK',f.id,'QUALITY',f.quality_basis_points,jsonb_build_object('feedback_id',f.id,'content_hash',f.content_hash),f.submitted_at from public.mission_provider_feedback f where f.provider_organization_id=p_provider_organization_id and(p_service_id is null or f.service_id=p_service_id)
  union all select f.provider_organization_id,f.service_id,'FEEDBACK',f.id,'COMPLIANCE',f.compliance_basis_points,jsonb_build_object('feedback_id',f.id,'content_hash',f.content_hash),f.submitted_at from public.mission_provider_feedback f where f.provider_organization_id=p_provider_organization_id and(p_service_id is null or f.service_id=p_service_id)
  union all select f.provider_organization_id,f.service_id,'FEEDBACK',f.id,'SATISFACTION',f.satisfaction_basis_points,jsonb_build_object('feedback_id',f.id,'content_hash',f.content_hash),f.submitted_at from public.mission_provider_feedback f where f.provider_organization_id=p_provider_organization_id and(p_service_id is null or f.service_id=p_service_id)
  union all select rp.provider_organization_id,sr.service_id,'RESPONSIVENESS',rp.id,'RESPONSIVENESS',case when rp.responded_at<=rfq.deadline then 10000 else 0 end,jsonb_build_object('criterion','RFQ_DEADLINE_MET','rfq_provider_id',rp.id,'invited_at',rp.invited_at,'responded_at',rp.responded_at,'deadline',rfq.deadline),rp.responded_at from public.rfq_providers rp join public.rfqs rfq on rfq.id=rp.rfq_id join public.service_requests sr on sr.id=rfq.request_id where rp.provider_organization_id=p_provider_organization_id and rp.responded_at is not null and(p_service_id is null or sr.service_id=p_service_id)
  union all select pe.provider_organization_id,ms.service_id,'FINANCE',pe.id,'FINANCE',case when pe.event_type='PENALTY_ACCRUAL'then 0 else 10000 end,jsonb_build_object('payable_event_id',pe.id,'event_type',pe.event_type,'proof_hash',pe.proof_hash),pe.created_at from public.provider_payable_events pe join mission_service ms on ms.id=pe.mission_id where pe.provider_organization_id=p_provider_organization_id
 )insert into public.provider_reputation_evidence_events(provider_organization_id,service_id,source_type,source_id,dimension,score_basis_points,source_snapshot,content_hash,occurred_at)
 select source.provider_organization_id,source.service_id,source.source_type,source.source_id,source.dimension,source.score,source.snap,private.canonical_request_hash(jsonb_build_object('provider',source.provider_organization_id,'source_type',source.source_type,'source_id',source.source_id,'dimension',source.dimension,'score',source.score,'snapshot',source.snap)),source.occurred_at from source where source.occurred_at is not null on conflict do nothing;
 select jsonb_object_agg(lower(dimension),score),sum(n),jsonb_agg(ids order by dimension) into dims,cnt,refs from(select dimension,round(avg(score_basis_points))::integer score,count(*)::integer n,jsonb_agg(id order by occurred_at,id)ids from public.provider_reputation_evidence_events where provider_organization_id=p_provider_organization_id and(p_service_id is null or service_id=p_service_id)group by dimension)e;
 if dims is null or not dims?&array['quality','delivery','compliance','responsiveness','satisfaction','finance'] or cnt<pol.minimum_evidence_count then raise exception'INCOMPLETE_AUTHORITATIVE_REPUTATION_EVIDENCE'using errcode='55000';end if;
 overall:=((dims->>'quality')::integer*(pol.weights->>'quality')::integer+(dims->>'delivery')::integer*(pol.weights->>'delivery')::integer+(dims->>'compliance')::integer*(pol.weights->>'compliance')::integer+(dims->>'responsiveness')::integer*(pol.weights->>'responsiveness')::integer+(dims->>'satisfaction')::integer*(pol.weights->>'satisfaction')::integer+(dims->>'finance')::integer*(pol.weights->>'finance')::integer)/100;
 select coalesce(max(version_number),0)+1 into ver from public.provider_reputation_snapshots where provider_organization_id=p_provider_organization_id and service_id is not distinct from p_service_id;
 insert into public.provider_reputation_snapshots(provider_organization_id,service_id,version_number,policy_version,quality_basis_points,delivery_basis_points,compliance_basis_points,responsiveness_basis_points,satisfaction_basis_points,finance_basis_points,overall_basis_points,evidence_count,explanation,evidence_refs,input_hash,calculated_by,correlation_id)values(p_provider_organization_id,p_service_id,ver,p_policy_version,(dims->>'quality')::integer,(dims->>'delivery')::integer,(dims->>'compliance')::integer,(dims->>'responsiveness')::integer,(dims->>'satisfaction')::integer,(dims->>'finance')::integer,overall,cnt,jsonb_build_object('source','AUTHORITATIVE_EVENTS_V1','weights',pol.weights,'dimensions',dims),refs,private.canonical_request_hash(jsonb_build_object('events',refs,'dimensions',dims,'policy',p_policy_version)),a,p_correlation_id)returning id into snapshot_id;
 for b in select * from public.provider_badge_policy_versions where effective_from<=clock_timestamp()and(effective_until is null or effective_until>clock_timestamp()) loop
  badge_score:=case b.dimension when'OVERALL'then overall else(dims->>lower(b.dimension))::integer end;eligible:=badge_score>=b.minimum_basis_points and cnt>=b.minimum_evidence_count;
  select coalesce(max(evaluation_version),0)+1 into eval_ver from public.provider_badge_evaluations where provider_organization_id=p_provider_organization_id and service_id is not distinct from p_service_id and badge_policy_id=b.id;
  insert into public.provider_badge_evaluations(provider_organization_id,service_id,badge_policy_id,reputation_snapshot_id,evaluation_version,eligible,evaluated_basis_points,explanation,evaluated_by,correlation_id)values(p_provider_organization_id,p_service_id,b.id,snapshot_id,eval_ver,eligible,badge_score,jsonb_build_object('source','AUTHORITATIVE_REPUTATION_SNAPSHOT','human_decision_required',true,'minimum_basis_points',b.minimum_basis_points,'evidence_count',cnt),a,p_correlation_id)returning id into eval_id;
  badge_count:=badge_count+1;
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(p_provider_organization_id,'provider_badge',eval_id::text,'ProviderBadgeEvaluationAwaitingHumanReviewV1',p_correlation_id,jsonb_build_object('evaluation_id',eval_id,'snapshot_id',snapshot_id,'eligible',eligible,'human_decision_required',true));
 end loop;
 r:=jsonb_build_object('outcome','PROVIDER_REPUTATION_REFRESHED_FROM_EVENTS','snapshot_id',snapshot_id,'version_number',ver,'overall_basis_points',overall,'evidence_count',cnt,'badge_evaluations_pending_review',badge_count);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_provider_organization_id,a,'USER','provider.reputation.refreshed_from_events','provider_reputation_snapshot',snapshot_id::text,p_correlation_id,r||jsonb_build_object('policy_version',p_policy_version),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_provider_organization_id,'provider_reputation',p_provider_organization_id::text,'ProviderReputationRefreshedFromEventsV1',p_correlation_id,r,p_idempotency_key);
 perform private.finish_provider_reputation_command(p_provider_organization_id,'provider.reputation.refresh.events',p_idempotency_key,r);return r;
end$$;

create or replace function public.decide_provider_badge(p_evaluation_id uuid,p_action text,p_rationale text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();e public.provider_badge_evaluations%rowtype;last_action text;v integer;x uuid;h text;cached jsonb;r jsonb;
begin
 select * into e from public.provider_badge_evaluations where id=p_evaluation_id;
 if a is null or e.id is null or auth.jwt()->>'aal'is distinct from'aal2' or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],a)then raise exception'HUMAN_BADGE_DECISION_REQUIRED'using errcode='42501';end if;
 h:=private.canonical_request_hash(jsonb_build_object('operation','provider.badge.decide.v2','evaluation',p_evaluation_id,'action',p_action,'rationale',btrim(coalesce(p_rationale,''))));
 cached:=private.begin_provider_reputation_command(e.provider_organization_id,a,'provider.badge.decide',p_idempotency_key,h);if cached is not null then return cached;end if;
 select * into e from public.provider_badge_evaluations where id=p_evaluation_id for update;
 if p_action not in('PUBLISHED','REVOKED')or length(btrim(coalesce(p_rationale,'')))not between 10 and 1000 then raise exception'INVALID_BADGE_DECISION'using errcode='22023';end if;
 if p_action='PUBLISHED'and not e.eligible then raise exception'INELIGIBLE_BADGE_CANNOT_BE_PUBLISHED'using errcode='55000';end if;
 select action into last_action from public.provider_badge_decisions where evaluation_id=e.id order by decision_version desc limit 1;
 if(last_action is null and p_action<>'PUBLISHED')or last_action=p_action then raise exception'INVALID_BADGE_DECISION_TRANSITION'using errcode='55000';end if;
 select coalesce(max(decision_version),0)+1 into v from public.provider_badge_decisions where evaluation_id=e.id;
 insert into public.provider_badge_decisions(evaluation_id,provider_organization_id,decision_version,action,rationale,decided_by,correlation_id)values(e.id,e.provider_organization_id,v,p_action,btrim(p_rationale),a,p_correlation_id)returning id into x;
 r:=jsonb_build_object('outcome','PROVIDER_BADGE_DECIDED','decision_id',x,'decision_version',v,'action',p_action);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(e.provider_organization_id,a,'USER','provider.badge.'||lower(p_action),'provider_badge_decision',x::text,p_correlation_id,jsonb_build_object('evaluation_id',e.id,'rationale',btrim(p_rationale)),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(e.provider_organization_id,'provider_badge',e.id::text,case p_action when'PUBLISHED'then'ProviderBadgePublishedV1'else'ProviderBadgeRevokedV1'end,p_correlation_id,jsonb_build_object('evaluation_id',e.id,'decision_id',x,'decision_version',v),p_idempotency_key);
 perform private.finish_provider_reputation_command(e.provider_organization_id,'provider.badge.decide',p_idempotency_key,r);return r;
end$$;

alter function public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid) rename to create_mission_legacy_0191;
revoke all on function public.create_mission_legacy_0191(uuid,uuid,jsonb,jsonb,jsonb,text,uuid) from public,anon,authenticated,service_role;
create function public.create_mission(p_contract_id uuid,p_contract_version_id uuid,p_milestones jsonb,p_deliverables jsonb,p_acceptance_criteria jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare r jsonb;s public.mission_checklist_snapshots%rowtype;t public.service_checklist_templates%rowtype;sv public.catalog_service_versions%rowtype;cs public.catalog_services%rowtype;
begin
 r:=public.create_mission_legacy_0191(p_contract_id,p_contract_version_id,p_milestones,p_deliverables,p_acceptance_criteria,p_idempotency_key,p_correlation_id);
 select * into s from public.mission_checklist_snapshots where mission_id=nullif(r->>'mission_id','')::uuid;
 select * into t from public.service_checklist_templates where id=s.service_checklist_template_id;
 select * into sv from public.catalog_service_versions where id=s.service_version_id;
 select * into cs from public.catalog_services where id=sv.service_id;
 if s.id is null or t.publication_status<>'PUBLISHED' or t.published_at is null or t.published_by is null or not private.valid_published_checklist_items_v1(t.items) or sv.status<>'PUBLISHED' or cs.current_published_version_id is distinct from sv.id then raise exception'MISSION_EXECUTABLE_PUBLISHED_CHECKLIST_REQUIRED'using errcode='55000';end if;
 return r;
end$$;
revoke all on function public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid)from public,anon,service_role;
grant execute on function public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid)to authenticated;

revoke all on function public.calculate_provider_reputation(uuid,uuid,jsonb,jsonb,text,text,uuid) from authenticated;
revoke all on function public.publish_service_checklist_template(uuid,uuid,jsonb,text,text,uuid),public.complete_mission_checklist_item(uuid,text,uuid,text,uuid),public.submit_mission_provider_feedback(uuid,integer,integer,integer,jsonb,text,uuid),public.refresh_provider_reputation_from_events(uuid,uuid,text,text,uuid) from public,anon,service_role;
grant execute on function public.publish_service_checklist_template(uuid,uuid,jsonb,text,text,uuid),public.complete_mission_checklist_item(uuid,text,uuid,text,uuid),public.submit_mission_provider_feedback(uuid,integer,integer,integer,jsonb,text,uuid),public.refresh_provider_reputation_from_events(uuid,uuid,text,text,uuid) to authenticated;
