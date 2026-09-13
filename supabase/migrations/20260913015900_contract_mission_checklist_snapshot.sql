-- MAT-FUNC-024: bind every new mission to one immutable, versioned service checklist.

create table public.mission_checklist_snapshots (
  id uuid primary key default extensions.gen_random_uuid(),
  mission_id uuid not null unique references public.missions(id) on delete restrict,
  service_checklist_template_id uuid not null references public.service_checklist_templates(id) on delete restrict,
  service_version_id uuid not null references public.catalog_service_versions(id) on delete restrict,
  template_version integer not null check (template_version > 0),
  template_content_hash text not null check (template_content_hash ~ '^[0-9a-f]{64}$'),
  items jsonb not null check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) > 0),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  unique (service_checklist_template_id, mission_id)
);

alter table public.contract_versions add constraint contract_versions_service_version_snapshot_required
check(request_snapshot->>'service_version_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$') not valid;

alter table public.mission_checklist_snapshots enable row level security;

create policy mission_checklist_snapshots_party_read
on public.mission_checklist_snapshots
for select to authenticated
using (private.mission_party_access(mission_id));

revoke all on public.mission_checklist_snapshots from public, anon, authenticated, service_role;
grant select on public.mission_checklist_snapshots to authenticated;

create trigger service_checklist_templates_immutable
before update or delete on public.service_checklist_templates
for each row execute function private.prevent_contract_immutable_change();

create trigger mission_checklist_snapshots_immutable
before update or delete on public.mission_checklist_snapshots
for each row execute function private.prevent_contract_immutable_change();

alter function public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid)
  rename to create_mission_legacy_0159;
revoke all on function public.create_mission_legacy_0159(uuid,uuid,jsonb,jsonb,jsonb,text,uuid)
  from public, anon, authenticated, service_role;

create function public.create_mission(
  p_contract_id uuid,
  p_contract_version_id uuid,
  p_milestones jsonb,
  p_deliverables jsonb,
  p_acceptance_criteria jsonb,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare
  v_actor uuid := auth.uid();
  v_response jsonb;
  v_mission_id uuid;
  v_client_organization_id uuid;
  v_template public.service_checklist_templates%rowtype;
  v_existing public.mission_checklist_snapshots%rowtype;
  v_item jsonb;
  v_snapshot_id uuid;
begin
  if v_actor is null then
    raise exception 'UNAUTHENTICATED' using errcode='42501';
  end if;

  v_response := public.create_mission_legacy_0159(
    p_contract_id,
    p_contract_version_id,
    p_milestones,
    p_deliverables,
    p_acceptance_criteria,
    p_idempotency_key,
    p_correlation_id
  );
  v_mission_id := nullif(v_response->>'mission_id','')::uuid;
  if v_mission_id is null then
    raise exception 'MISSION_CHECKLIST_SNAPSHOT_FAILED' using errcode='55000';
  end if;

  select * into v_existing
  from public.mission_checklist_snapshots
  where mission_id=v_mission_id;
  if found then
    return v_response || jsonb_build_object(
      'checklist_snapshot_id',v_existing.id,
      'checklist_template_id',v_existing.service_checklist_template_id,
      'checklist_template_version',v_existing.template_version,
      'checklist_content_hash',v_existing.template_content_hash
    );
  end if;

  select c.client_organization_id into v_client_organization_id
  from public.contract_versions cv
  join public.contracts c on c.id=cv.contract_id
  where cv.id=p_contract_version_id and cv.contract_id=p_contract_id;

  select t.* into v_template
  from public.contract_versions cv
  join public.contracts c on c.id=cv.contract_id
  join public.quote_versions qv on qv.id=cv.selected_quote_version_id
  join public.quotes q on q.id=qv.quote_id
  join public.rfqs r on r.id=q.rfq_id
  join public.service_requests sr on sr.id=r.request_id
  join public.catalog_service_versions sv on sv.service_id=sr.service_id and sv.id=case
      when cv.request_snapshot->>'service_version_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      then (cv.request_snapshot->>'service_version_id')::uuid
      else null
    end
  join public.service_checklist_templates t on t.service_version_id=sv.id
  where cv.id=p_contract_version_id
    and cv.contract_id=p_contract_id
  order by t.version desc,t.id
  limit 1;

  if v_template.id is null
    or jsonb_typeof(v_template.items)<>'array'
    or jsonb_array_length(v_template.items)=0
    or exists (
      select 1
      from jsonb_array_elements(v_template.items) item
      where jsonb_typeof(item)<>'object'
        or coalesce(item->>'key','')!~'^[A-Z][A-Z0-9_-]{1,79}$'
        or length(btrim(coalesce(item->>'label_fr',''))) not between 1 and 500
        or length(btrim(coalesce(item->>'label_ar',''))) not between 1 and 500
        or jsonb_typeof(coalesce(item->'proof_required','false'::jsonb))<>'boolean'
    )
    or (
      select count(*)<>count(distinct (item->>'key'))
      from jsonb_array_elements(v_template.items) item
    )
  then
    raise exception 'MISSION_CHECKLIST_TEMPLATE_REQUIRED' using errcode='22023';
  end if;

  insert into public.mission_checklist_snapshots(
    mission_id,service_checklist_template_id,service_version_id,template_version,
    template_content_hash,items,created_by
  ) values (
    v_mission_id,v_template.id,v_template.service_version_id,v_template.version,
    v_template.content_hash,v_template.items,v_actor
  ) returning id into v_snapshot_id;

  for v_item in select value from jsonb_array_elements(v_template.items) loop
    insert into public.mission_checklist_items(
      mission_id,milestone_id,item_key,label_fr,label_ar,proof_required
    ) values (
      v_mission_id,null,v_item->>'key',btrim(v_item->>'label_fr'),btrim(v_item->>'label_ar'),
      coalesce((v_item->>'proof_required')::boolean,false)
    );
  end loop;

  v_response := v_response || jsonb_build_object(
    'checklist_snapshot_id',v_snapshot_id,
    'checklist_template_id',v_template.id,
    'checklist_template_version',v_template.version,
    'checklist_content_hash',v_template.content_hash
  );

  insert into public.audit_events(
    organization_id,actor_user_id,actor_type,action,resource_type,resource_id,
    correlation_id,metadata,event_hash
  ) values (
    v_client_organization_id,v_actor,'USER','mission.checklist_snapshotted',
    'mission_checklist_snapshot',v_snapshot_id::text,p_correlation_id,
    jsonb_build_object(
      'mission_id',v_mission_id,
      'service_checklist_template_id',v_template.id,
      'template_version',v_template.version,
      'template_content_hash',v_template.content_hash,
      'item_count',jsonb_array_length(v_template.items)
    ),repeat('0',64)
  );
  insert into public.event_outbox(
    organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,
    idempotency_key
  ) values (
    v_client_organization_id,'mission',v_mission_id::text,
    'MissionChecklistSnapshottedV1',p_correlation_id,
    jsonb_build_object(
      'mission_id',v_mission_id,
      'checklist_snapshot_id',v_snapshot_id,
      'service_checklist_template_id',v_template.id,
      'template_version',v_template.version,
      'template_content_hash',v_template.content_hash,
      'item_count',jsonb_array_length(v_template.items)
    ),p_idempotency_key
  );
  perform private.finish_contract_command(
    v_client_organization_id,'mission.create',p_idempotency_key,v_response
  );
  return v_response;
end;
$$;

revoke all on function public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid)
  from public,anon,service_role;
grant execute on function public.create_mission(uuid,uuid,jsonb,jsonb,jsonb,text,uuid)
  to authenticated;

create index mission_checklist_snapshots_template_idx
  on public.mission_checklist_snapshots(service_checklist_template_id,template_version);
