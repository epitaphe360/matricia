-- MAT-FUNC-022/023 hardening: keep submitted evidence immutable while allowing
-- the trusted scanner to append its verdict, and expose explicit milestone
-- transitions for the provider and client parties.

alter table public.delivery_proofs
  add column storage_bucket text not null default 'delivery-proofs'
    check (storage_bucket = 'delivery-proofs');

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('delivery-proofs','delivery-proofs',false,10485760,array['application/pdf','image/jpeg','image/png'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create policy delivery_proof_storage_insert on storage.objects for insert to authenticated
with check (
  bucket_id='delivery-proofs'
  and (storage.foldername(name))[1]=auth.uid()::text
  and coalesce((storage.foldername(name))[2],'')~*'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and exists(
    select 1 from public.deliverables d join public.missions m on m.id=d.mission_id
    where d.id=((storage.foldername(name))[2])::uuid
      and m.status in ('ACTIVE','DELIVERY_SUBMITTED')
      and private.has_org_role(m.provider_organization_id,array['PROVIDER_OWNER','PROVIDER_MANAGER','PROVIDER_TECHNICIAN'],auth.uid())
  )
);

create policy delivery_proof_storage_owner_unbound_read on storage.objects for select to authenticated
using (
  bucket_id='delivery-proofs' and (storage.foldername(name))[1]=auth.uid()::text
  and not exists(select 1 from public.delivery_proofs p where p.storage_bucket=bucket_id and p.storage_path=name)
);

create policy delivery_proof_storage_orphan_delete on storage.objects for delete to authenticated
using (
  bucket_id='delivery-proofs' and (storage.foldername(name))[1]=auth.uid()::text
  and not exists(select 1 from public.delivery_proofs p where p.storage_bucket=bucket_id and p.storage_path=name)
);

create policy delivery_proof_storage_party_read on storage.objects for select to authenticated
using (
  bucket_id='delivery-proofs'
  and exists(
    select 1 from public.delivery_proofs p
    join public.delivery_versions v on v.id=p.delivery_version_id
    join public.deliverables d on d.id=v.deliverable_id
    where p.storage_bucket=bucket_id and p.storage_path=name
      and p.scan_status='CLEAN' and private.mission_party_access(d.mission_id)
  )
);

create or replace function private.bind_delivery_proof_storage()
returns trigger language plpgsql security definer set search_path=pg_catalog,public,storage
as $$declare v_deliverable uuid;begin
  select d.id into v_deliverable from public.delivery_versions v join public.deliverables d on d.id=v.deliverable_id where v.id=new.delivery_version_id;
  if new.storage_path is not null then
    if new.storage_bucket<>'delivery-proofs'
      or split_part(new.storage_path,'/',1)<>auth.uid()::text
      or split_part(new.storage_path,'/',2)<>v_deliverable::text
      or not exists(select 1 from storage.objects o where o.bucket_id=new.storage_bucket and o.name=new.storage_path)
    then raise exception 'DELIVERY_PROOF_STORAGE_BINDING_REQUIRED' using errcode='22000';end if;
  elsif new.url is null or new.url!~'^https://' then
    raise exception 'DELIVERY_PROOF_LOCATION_INVALID' using errcode='22023';
  end if;
  return new;
end$$;

create trigger delivery_proof_storage_binding before insert on public.delivery_proofs for each row execute function private.bind_delivery_proof_storage();

create function private.enforce_milestone_owner_party()
returns trigger language plpgsql security definer set search_path=pg_catalog,public
as $$begin
  if not exists(select 1 from public.missions m where m.id=new.mission_id and new.owner_organization_id in (m.client_organization_id,m.provider_organization_id))
  then raise exception 'MILESTONE_OWNER_MUST_BE_MISSION_PARTY' using errcode='23514'; end if;
  return new;
end$$;
create trigger mission_milestone_owner_party before insert or update of mission_id,owner_organization_id on public.mission_milestones for each row execute function private.enforce_milestone_owner_party();

drop trigger if exists delivery_proofs_immutable on public.delivery_proofs;

create or replace function private.protect_delivery_proof_content()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'IMMUTABLE_DELIVERY_PROOF' using errcode = '55000';
  end if;

  if auth.role() is distinct from 'service_role'
    or new.id is distinct from old.id
    or new.delivery_version_id is distinct from old.delivery_version_id
    or new.storage_bucket is distinct from old.storage_bucket
    or new.proof_type is distinct from old.proof_type
    or new.storage_path is distinct from old.storage_path
    or new.url is distinct from old.url
    or new.evidence_hash is distinct from old.evidence_hash
    or new.metadata is distinct from old.metadata
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at
  then
    raise exception 'IMMUTABLE_DELIVERY_PROOF' using errcode = '55000';
  end if;

  return new;
end
$$;

create trigger delivery_proofs_immutable
before update or delete on public.delivery_proofs
for each row execute function private.protect_delivery_proof_content();

create or replace function private.require_clean_delivery_proofs()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if old.status = 'SUBMITTED' and new.status in ('ACCEPTED', 'REJECTED') and (
    not exists (
      select 1
      from public.delivery_versions version
      where version.deliverable_id = new.id
        and version.version = new.current_version
    )
    or (new.proof_required and not exists (
      select 1
      from public.delivery_versions version
      join public.delivery_proofs proof on proof.delivery_version_id = version.id
      where version.deliverable_id = new.id
        and version.version = new.current_version
    ))
    or exists (
      select 1
      from public.delivery_versions version
      join public.delivery_proofs proof on proof.delivery_version_id = version.id
      where version.deliverable_id = new.id
        and version.version = new.current_version
        and proof.scan_status <> 'CLEAN'
    )
  ) then
    raise exception 'CLEAN_DELIVERY_PROOF_SCAN_REQUIRED' using errcode = '55000';
  end if;
  return new;
end
$$;

create or replace function public.submit_mission_milestone(
  p_milestone_id uuid,
  p_expected_row_version integer,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_actor uuid := auth.uid();
  v_milestone public.mission_milestones%rowtype;
  v_mission public.missions%rowtype;
  v_hash text;
  v_response jsonb;
begin
  select * into v_milestone from public.mission_milestones where id = p_milestone_id;
  select * into v_mission from public.missions where id = v_milestone.mission_id;
  if v_actor is null or not found
    or v_milestone.owner_organization_id <> v_mission.provider_organization_id
    or not private.has_org_role(v_milestone.owner_organization_id, array['PROVIDER_OWNER','PROVIDER_MANAGER','PROVIDER_TECHNICIAN'], v_actor) then
    raise exception 'MILESTONE_SUBMIT_DENIED' using errcode = '42501';
  end if;
  v_hash := private.canonical_request_hash(jsonb_build_object('operation','mission.milestone.submit.v1','milestone_id',p_milestone_id,'expected_row_version',p_expected_row_version));
  v_response := private.begin_contract_command(v_mission.client_organization_id, 'mission.milestone.submit.' || p_milestone_id::text, p_idempotency_key, v_hash, v_actor);
  if v_response is not null then return v_response; end if;
  if v_mission.status not in ('ACTIVE','DELIVERY_SUBMITTED')
    or v_milestone.status not in ('PENDING','IN_PROGRESS')
    or v_milestone.row_version <> p_expected_row_version
  then
    raise exception 'INVALID_MILESTONE_TRANSITION' using errcode = '55000';
  end if;
  update public.mission_milestones
  set status = 'SUBMITTED', submitted_at = clock_timestamp(), row_version = row_version + 1
  where id = p_milestone_id and row_version = p_expected_row_version;
  if not found then raise exception 'INVALID_MILESTONE_TRANSITION' using errcode = '55000'; end if;
  v_response := jsonb_build_object('outcome','MILESTONE_SUBMITTED','mission_id',v_mission.id,'milestone_id',p_milestone_id,'row_version',p_expected_row_version + 1);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(v_mission.client_organization_id,v_actor,'USER','mission.milestone.submitted','mission_milestone',p_milestone_id::text,p_correlation_id,v_response,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
  values(v_mission.client_organization_id,'mission',v_mission.id::text,'MissionMilestoneSubmittedV1',p_correlation_id,v_response,p_idempotency_key);
  perform private.finish_contract_command(v_mission.client_organization_id, 'mission.milestone.submit.' || p_milestone_id::text, p_idempotency_key, v_response);
  return v_response;
end
$$;

create or replace function public.decide_mission_milestone(
  p_milestone_id uuid,
  p_expected_row_version integer,
  p_decision text,
  p_reason text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_actor uuid := auth.uid();
  v_milestone public.mission_milestones%rowtype;
  v_mission public.missions%rowtype;
  v_hash text;
  v_response jsonb;
begin
  select * into v_milestone from public.mission_milestones where id = p_milestone_id;
  select * into v_mission from public.missions where id = v_milestone.mission_id;
  if v_actor is null or not found or not private.has_org_role(v_mission.client_organization_id, array['CLIENT_OWNER','CLIENT_ADMIN'], v_actor) then
    raise exception 'MILESTONE_DECIDE_DENIED' using errcode = '42501';
  end if;
  if p_decision not in ('ACCEPTED','REJECTED') or length(btrim(coalesce(p_reason,''))) not between 3 and 1000 then raise exception 'INVALID_MILESTONE_TRANSITION' using errcode = '55000'; end if;
  v_hash := private.canonical_request_hash(jsonb_build_object('operation','mission.milestone.decide.v1','milestone_id',p_milestone_id,'expected_row_version',p_expected_row_version,'decision',p_decision,'reason',btrim(p_reason)));
  v_response := private.begin_contract_command(v_mission.client_organization_id, 'mission.milestone.decide.' || p_milestone_id::text, p_idempotency_key, v_hash, v_actor);
  if v_response is not null then return v_response; end if;
  if v_milestone.status <> 'SUBMITTED' or v_milestone.row_version <> p_expected_row_version then raise exception 'INVALID_MILESTONE_TRANSITION' using errcode = '55000'; end if;
  if p_decision='ACCEPTED' and (
    not exists(select 1 from public.deliverables d where d.milestone_id=p_milestone_id)
    or exists(select 1 from public.deliverables d where d.milestone_id=p_milestone_id and (
      d.status<>'ACCEPTED' or (d.proof_required and (
        not exists(select 1 from public.delivery_versions v join public.delivery_proofs p on p.delivery_version_id=v.id where v.deliverable_id=d.id and v.version=d.current_version)
        or exists(select 1 from public.delivery_versions v join public.delivery_proofs p on p.delivery_version_id=v.id where v.deliverable_id=d.id and v.version=d.current_version and p.scan_status<>'CLEAN')
      ))
    ))
  ) then raise exception 'MILESTONE_DELIVERABLES_NOT_ACCEPTED' using errcode='55000'; end if;
  update public.mission_milestones
  set status = p_decision, decided_at = clock_timestamp(), row_version = row_version + 1
  where id = p_milestone_id and row_version = p_expected_row_version;
  if not found then raise exception 'INVALID_MILESTONE_TRANSITION' using errcode = '55000'; end if;
  v_response := jsonb_build_object('outcome',case when p_decision='ACCEPTED' then 'MILESTONE_ACCEPTED' else 'MILESTONE_REJECTED' end,'mission_id',v_mission.id,'milestone_id',p_milestone_id,'row_version',p_expected_row_version + 1);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(v_mission.client_organization_id,v_actor,'USER','mission.milestone.decided','mission_milestone',p_milestone_id::text,p_correlation_id,jsonb_build_object('decision',p_decision,'reason',btrim(p_reason)),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
  values(v_mission.client_organization_id,'mission',v_mission.id::text,case when p_decision='ACCEPTED' then 'MissionMilestoneAcceptedV1' else 'MissionMilestoneRejectedV1' end,p_correlation_id,v_response,p_idempotency_key);
  perform private.finish_contract_command(v_mission.client_organization_id, 'mission.milestone.decide.' || p_milestone_id::text, p_idempotency_key, v_response);
  return v_response;
end
$$;

revoke all on function private.protect_delivery_proof_content() from public, anon, authenticated, service_role;
revoke all on function private.bind_delivery_proof_storage() from public, anon, authenticated, service_role;
revoke all on function private.enforce_milestone_owner_party() from public, anon, authenticated, service_role;
revoke all on function public.submit_mission_milestone(uuid,integer,text,uuid), public.decide_mission_milestone(uuid,integer,text,text,text,uuid) from public, anon, authenticated, service_role;
grant execute on function public.submit_mission_milestone(uuid,integer,text,uuid), public.decide_mission_milestone(uuid,integer,text,text,text,uuid) to authenticated;

-- A private lease prevents two scheduler invocations from scanning the same
-- object concurrently. Only service_role can claim or complete a lease.
create table private.delivery_proof_scan_claims (
  proof_id uuid primary key references public.delivery_proofs(id) on delete cascade,
  worker_id uuid not null,
  lease_token uuid not null unique default extensions.gen_random_uuid(),
  leased_until timestamptz not null,
  row_version integer not null default 1 check (row_version > 0),
  attempt_count integer not null default 0 check (attempt_count between 0 and 5),
  claimed_at timestamptz not null default clock_timestamp()
);
alter table private.delivery_proof_scan_claims enable row level security;
revoke all on private.delivery_proof_scan_claims from public, anon, authenticated, service_role;
create table private.delivery_proof_scan_retry_history(
 id uuid primary key default extensions.gen_random_uuid(),proof_id uuid not null references public.delivery_proofs(id) on delete restrict,attempt integer not null check(attempt between 1 and 5),failure_code text not null check(failure_code in('SCANNER_UNAVAILABLE','SCANNER_INVALID_RESPONSE','STORAGE_DOWNLOAD_FAILED')),worker_id uuid not null,lease_token uuid not null,correlation_id uuid not null,recorded_at timestamptz not null default clock_timestamp(),unique(proof_id,attempt)
);
alter table private.delivery_proof_scan_retry_history enable row level security;
revoke all on private.delivery_proof_scan_retry_history from public,anon,authenticated,service_role;
create trigger delivery_proof_scan_retry_history_immutable before update or delete on private.delivery_proof_scan_retry_history for each row execute function private.prevent_update_delete();

create function public.claim_delivery_proof_scan_jobs(
  p_worker_id uuid,
  p_limit integer default 20,
  p_lease_seconds integer default 300
) returns table(
  proof_id uuid, lease_token uuid, worker_id uuid, row_version integer, attempt_count integer,
  storage_bucket text, storage_path text, expected_sha256 text, media_type text
) language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare v_proof record; v_claim private.delivery_proof_scan_claims%rowtype;
begin
  if auth.role() is distinct from 'service_role' then raise exception 'TRUSTED_SCANNER_SERVICE_REQUIRED' using errcode='42501'; end if;
  if p_worker_id is null or p_limit not between 1 and 100 or p_lease_seconds not between 30 and 900 then raise exception 'INVALID_SCAN_CLAIM' using errcode='22023'; end if;
  for v_proof in
    select p.id,p.storage_bucket,p.storage_path,p.evidence_hash,coalesce(p.metadata->>'mime_type',p.metadata->>'media_type') as media_type
    from public.delivery_proofs p
    where p.scan_status='PENDING' and p.storage_path is not null
      and not exists(select 1 from private.delivery_proof_scan_claims c where c.proof_id=p.id and c.leased_until>clock_timestamp())
    order by p.created_at,p.id for update skip locked limit p_limit
  loop
    insert into private.delivery_proof_scan_claims(proof_id,worker_id,leased_until)
    values(v_proof.id,p_worker_id,clock_timestamp()+make_interval(secs=>p_lease_seconds))
    on conflict on constraint delivery_proof_scan_claims_pkey do update set worker_id=excluded.worker_id,lease_token=extensions.gen_random_uuid(),leased_until=excluded.leased_until,row_version=private.delivery_proof_scan_claims.row_version+1,claimed_at=clock_timestamp()
      where private.delivery_proof_scan_claims.leased_until<=clock_timestamp()
    returning * into v_claim;
    if found then
      proof_id:=v_proof.id; lease_token:=v_claim.lease_token; worker_id:=v_claim.worker_id; row_version:=v_claim.row_version; attempt_count:=v_claim.attempt_count;
      storage_bucket:=v_proof.storage_bucket; storage_path:=v_proof.storage_path; expected_sha256:=v_proof.evidence_hash; media_type:=v_proof.media_type;
      return next;
    end if;
  end loop;
end$$;

create function public.fail_delivery_proof_scan_job(
  p_proof_id uuid,p_lease_token uuid,p_worker_id uuid,p_expected_row_version integer,
  p_failure_code text,p_computed_sha256 text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private
as $$declare v_claim private.delivery_proof_scan_claims%rowtype;v_attempt integer;v_response jsonb;v_mission public.missions%rowtype;begin
  if auth.role() is distinct from 'service_role' then raise exception 'TRUSTED_SCANNER_SERVICE_REQUIRED' using errcode='42501';end if;
  if p_failure_code not in('SCANNER_UNAVAILABLE','SCANNER_INVALID_RESPONSE','STORAGE_DOWNLOAD_FAILED') or coalesce(p_computed_sha256,'')!~'^[0-9a-f]{64}$' then raise exception 'INVALID_SCAN_FAILURE' using errcode='22023';end if;
  select * into v_claim from private.delivery_proof_scan_claims where proof_id=p_proof_id for update;
  if not found or v_claim.lease_token<>p_lease_token or v_claim.worker_id<>p_worker_id or v_claim.row_version<>p_expected_row_version or v_claim.leased_until<=clock_timestamp() then raise exception 'DELIVERY_PROOF_SCAN_LEASE_INVALID' using errcode='55000';end if;
  v_attempt:=v_claim.attempt_count+1;
  select m.* into v_mission from public.delivery_proofs p join public.delivery_versions v on v.id=p.delivery_version_id join public.deliverables d on d.id=v.deliverable_id join public.missions m on m.id=d.mission_id where p.id=p_proof_id;
  insert into private.delivery_proof_scan_retry_history(proof_id,attempt,failure_code,worker_id,lease_token,correlation_id) values(p_proof_id,v_attempt,p_failure_code,p_worker_id,p_lease_token,p_correlation_id);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash) values(v_mission.client_organization_id,null,'SERVICE',case when v_attempt>=5 then'delivery.proof.scan.dead_lettered'else'delivery.proof.scan.retry_scheduled'end,'delivery_proof',p_proof_id::text,p_correlation_id,jsonb_build_object('attempt',v_attempt,'failure_code',p_failure_code),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key) values(v_mission.client_organization_id,'delivery_proof',p_proof_id::text,case when v_attempt>=5 then'DeliveryProofScanDeadLetteredV1'else'DeliveryProofScanRetryScheduledV1'end,p_correlation_id,jsonb_build_object('proof_id',p_proof_id,'attempt',v_attempt,'failure_code',p_failure_code),'delivery-proof-scan-attempt:'||p_proof_id::text||':'||v_attempt);
  if v_attempt>=5 then
    v_response:=public.record_delivery_proof_scan_result(p_proof_id,'ERROR','MATRICIA_SCAN_DLQ','1.0.0',p_computed_sha256,'delivery-proof-scan-dlq:'||p_proof_id::text||':'||v_attempt,p_correlation_id);
    delete from private.delivery_proof_scan_claims where proof_id=p_proof_id;
    return jsonb_build_object('outcome','DELIVERY_PROOF_SCAN_DEAD_LETTERED','proof_id',p_proof_id,'attempt',v_attempt,'scan',v_response);
  end if;
  update private.delivery_proof_scan_claims set attempt_count=v_attempt,row_version=row_version+1,lease_token=extensions.gen_random_uuid(),leased_until=clock_timestamp()+make_interval(secs=>least(900,30*(2^v_attempt))) where proof_id=p_proof_id;
  return jsonb_build_object('outcome','DELIVERY_PROOF_SCAN_RETRY_SCHEDULED','proof_id',p_proof_id,'attempt',v_attempt,'failure_code',p_failure_code);
end$$;

create function public.cleanup_delivery_proof_storage_orphans(p_limit integer default 20,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,storage
as $$declare v_object record;v_count integer:=0;begin
  if auth.role() is distinct from 'service_role' then raise exception 'TRUSTED_SCANNER_SERVICE_REQUIRED' using errcode='42501';end if;
  if p_limit not between 1 and 100 then raise exception 'INVALID_ORPHAN_CLEANUP_LIMIT' using errcode='22023';end if;
  for v_object in select o.id,o.name,m.client_organization_id,d.mission_id from storage.objects o join public.deliverables d on d.id=(case when split_part(o.name,'/',2)~*'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then split_part(o.name,'/',2)::uuid end) join public.missions m on m.id=d.mission_id where o.bucket_id='delivery-proofs' and o.created_at<clock_timestamp()-interval '1 hour' and not exists(select 1 from public.delivery_proofs p where p.storage_bucket=o.bucket_id and p.storage_path=o.name) order by o.created_at,o.id for update of o skip locked limit p_limit
  loop
    delete from storage.objects where id=v_object.id;
    insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash) values(v_object.client_organization_id,null,'SERVICE','delivery.proof.orphan.removed','storage_object',v_object.name,p_correlation_id,jsonb_build_object('mission_id',v_object.mission_id),repeat('0',64));
    insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key) values(v_object.client_organization_id,'storage_object',v_object.name,'DeliveryProofOrphanRemovedV1',p_correlation_id,jsonb_build_object('storage_path',v_object.name,'mission_id',v_object.mission_id),'delivery-proof-orphan:'||v_object.id::text);
    v_count:=v_count+1;
  end loop;
  return jsonb_build_object('outcome','DELIVERY_PROOF_ORPHANS_CLEANED','count',v_count);
end$$;

create or replace function public.accept_delivery(p_deliverable_id uuid,p_decisions jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();d public.deliverables%rowtype;m public.missions%rowtype;h text;r jsonb;x jsonb;remaining integer;
begin
 select * into d from public.deliverables where id=p_deliverable_id;select * into m from public.missions where id=d.mission_id;
 if a is null or not found or not private.has_org_role(m.client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a)then raise exception 'DELIVERY_ACCEPT_DENIED' using errcode='42501';end if;
 if jsonb_typeof(p_decisions)<>'array'or jsonb_array_length(p_decisions)=0 then raise exception 'INVALID_ACCEPTANCE' using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('deliverable',d.id,'version',d.current_version,'decisions',p_decisions));r:=private.begin_contract_command(m.client_organization_id,'delivery.accept.'||d.id::text,p_idempotency_key,h,a);if r is not null then return r;end if;
 if d.status<>'SUBMITTED' then raise exception 'INVALID_ACCEPTANCE' using errcode='22023';end if;
 for x in select * from jsonb_array_elements(p_decisions)loop update public.acceptance_checklists set status=x->>'status',comment=nullif(x->>'comment',''),evidence=coalesce(x->'evidence','[]'),decided_by=a,decided_at=clock_timestamp()where deliverable_id=d.id and criterion_key=x->>'criterion_key'and status='PENDING';if not found then raise exception 'ACCEPTANCE_CRITERION_NOT_FOUND_OR_DECIDED' using errcode='P0002';end if;end loop;
 select count(*)into remaining from public.acceptance_checklists where deliverable_id=d.id and status='PENDING';if remaining>0 then raise exception 'ACCEPTANCE_INCOMPLETE' using errcode='22023';end if;
 if exists(select 1 from public.acceptance_checklists where deliverable_id=d.id and status='NONCOMPLIANT')then update public.deliverables set status='REJECTED'where id=d.id;r:=jsonb_build_object('outcome','DELIVERY_REJECTED','mission_id',m.id,'deliverable_id',d.id);else update public.deliverables set status='ACCEPTED'where id=d.id;if not exists(select 1 from public.deliverables where mission_id=m.id and status<>'ACCEPTED')then update public.missions set status='COMPLETED',completed_at=clock_timestamp(),row_version=row_version+1,updated_at=now()where id=m.id;update public.contracts set status='COMPLETED',row_version=row_version+1,updated_at=now()where id=m.contract_id;end if;r:=jsonb_build_object('outcome','DELIVERY_ACCEPTED','mission_id',m.id,'deliverable_id',d.id);end if;
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(m.client_organization_id,a,'USER','delivery.decided','deliverable',d.id::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(m.client_organization_id,'mission',m.id::text,case when r->>'outcome'='DELIVERY_ACCEPTED'then'DeliveryAcceptedV1'else'DeliveryRejectedV1'end,p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(m.client_organization_id,'delivery.accept.'||d.id::text,p_idempotency_key,r);return r;
end$$;

create function public.complete_delivery_proof_scan_job(
  p_proof_id uuid,p_lease_token uuid,p_worker_id uuid,p_expected_row_version integer,
  p_result text,p_engine_code text,p_engine_version text,p_computed_sha256 text,
  p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,private
as $$declare v_claim private.delivery_proof_scan_claims%rowtype; v_response jsonb;begin
  if auth.role() is distinct from 'service_role' then raise exception 'TRUSTED_SCANNER_SERVICE_REQUIRED' using errcode='42501'; end if;
  select * into v_claim from private.delivery_proof_scan_claims where proof_id=p_proof_id for update;
  if not found or v_claim.lease_token<>p_lease_token or v_claim.worker_id<>p_worker_id or v_claim.row_version<>p_expected_row_version or v_claim.leased_until<=clock_timestamp()
  then raise exception 'DELIVERY_PROOF_SCAN_LEASE_INVALID' using errcode='55000'; end if;
  v_response:=public.record_delivery_proof_scan_result(p_proof_id,p_result,p_engine_code,p_engine_version,p_computed_sha256,p_idempotency_key,p_correlation_id);
  delete from private.delivery_proof_scan_claims where proof_id=p_proof_id;
  return v_response;
end$$;

-- A corrupt download must be persistently quarantined as an ERROR; CLEAN or
-- INFECTED verdicts still require exact binding to the submitted SHA-256.
create or replace function public.record_delivery_proof_scan_result(
  p_proof_id uuid,p_result text,p_engine_code text,p_engine_version text,
  p_computed_sha256 text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$declare p public.delivery_proofs%rowtype;m public.missions%rowtype;v_hash text;v_response jsonb;v_existing private.delivery_proof_scan_idempotency%rowtype;v_scan_id uuid;v_sequence integer;
begin
  if auth.role() is distinct from 'service_role' then raise exception 'TRUSTED_SCANNER_SERVICE_REQUIRED' using errcode='42501';end if;
  if p_result not in ('CLEAN','INFECTED','ERROR') or coalesce(p_engine_code,'')!~'^[A-Z][A-Z0-9_.-]{2,79}$' or length(btrim(coalesce(p_engine_version,''))) not between 1 and 80 or coalesce(p_computed_sha256,'')!~'^[0-9a-f]{64}$' or length(coalesce(p_idempotency_key,'')) not between 8 and 200 then raise exception 'INVALID_DELIVERY_PROOF_SCAN_RESULT' using errcode='22023';end if;
  select * into p from public.delivery_proofs where id=p_proof_id;if not found then raise exception 'DELIVERY_PROOF_NOT_FOUND' using errcode='P0002';end if;
  perform pg_advisory_xact_lock(hashtextextended('delivery-proof-scan:'||p.id::text,0));select * into p from public.delivery_proofs where id=p.id for update;
  v_hash:=private.canonical_request_hash(jsonb_build_object('operation','delivery.proof.scan.v1','proof_id',p.id,'result',p_result,'engine_code',p_engine_code,'engine_version',btrim(p_engine_version),'computed_sha256',p_computed_sha256));
  select * into v_existing from private.delivery_proof_scan_idempotency where proof_id=p.id and key=p_idempotency_key;
  if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000';end if;return v_existing.response_body;end if;
  if p_result<>'ERROR' and p_computed_sha256<>p.evidence_hash then raise exception 'SCAN_EVIDENCE_HASH_MISMATCH' using errcode='22000';end if;
  select coalesce(max(sequence),0)+1 into v_sequence from private.delivery_proof_scan_results where proof_id=p.id;
  insert into private.delivery_proof_scan_results(proof_id,sequence,result,engine_code,engine_version,computed_sha256,scanner_principal,correlation_id) values(p.id,v_sequence,p_result,p_engine_code,btrim(p_engine_version),p_computed_sha256,'SUPABASE_SERVICE_ROLE',p_correlation_id) returning id into v_scan_id;
  update public.delivery_proofs set scan_status=p_result,scanned_at=clock_timestamp(),current_scan_result_id=v_scan_id where id=p.id;
  select mission.* into m from public.delivery_versions version join public.deliverables deliverable on deliverable.id=version.deliverable_id join public.missions mission on mission.id=deliverable.mission_id where version.id=p.delivery_version_id;
  v_response:=jsonb_build_object('outcome','DELIVERY_PROOF_SCAN_RECORDED','proof_id',p.id,'scan_id',v_scan_id,'result',p_result);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash) values(m.client_organization_id,auth.uid(),'SERVICE','delivery.proof.scan.recorded','delivery_proof',p.id::text,p_correlation_id,jsonb_build_object('result',p_result,'engine_code',p_engine_code),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key) values(m.client_organization_id,'delivery_proof',p.id::text,case when p_result='CLEAN'then'DeliveryProofScanCleanV1'when p_result='INFECTED'then'DeliveryProofQuarantinedV1'else'DeliveryProofScanFailedV1'end,p_correlation_id,v_response,p_idempotency_key);
  insert into private.delivery_proof_scan_idempotency(proof_id,key,request_hash,response_body) values(p.id,p_idempotency_key,v_hash,v_response);return v_response;
end$$;

revoke all on function public.claim_delivery_proof_scan_jobs(uuid,integer,integer),public.complete_delivery_proof_scan_job(uuid,uuid,uuid,integer,text,text,text,text,text,uuid),public.fail_delivery_proof_scan_job(uuid,uuid,uuid,integer,text,text,uuid),public.cleanup_delivery_proof_storage_orphans(integer,uuid) from public,anon,authenticated,service_role;
grant execute on function public.claim_delivery_proof_scan_jobs(uuid,integer,integer),public.complete_delivery_proof_scan_job(uuid,uuid,uuid,integer,text,text,text,text,text,uuid),public.fail_delivery_proof_scan_job(uuid,uuid,uuid,integer,text,text,uuid),public.cleanup_delivery_proof_storage_orphans(integer,uuid) to service_role;
