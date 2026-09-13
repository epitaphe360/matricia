-- V4.1 additive hardening: a human cannot decide a deliverable until every
-- proof attached to its current version has a trusted scanner verdict.

alter table public.delivery_proofs
  add column scan_status text not null default 'PENDING'
    check (scan_status in ('PENDING','CLEAN','INFECTED','ERROR')),
  add column scanned_at timestamptz;

create table private.delivery_proof_scan_results (
  id uuid primary key default extensions.gen_random_uuid(),
  proof_id uuid not null references public.delivery_proofs(id) on delete restrict,
  sequence integer not null check (sequence > 0),
  result text not null check (result in ('CLEAN','INFECTED','ERROR')),
  engine_code text not null check (engine_code ~ '^[A-Z][A-Z0-9_.-]{2,79}$'),
  engine_version text not null check (length(btrim(engine_version)) between 1 and 80),
  computed_sha256 text not null check (computed_sha256 ~ '^[0-9a-f]{64}$'),
  scanner_principal text not null check (scanner_principal = 'SUPABASE_SERVICE_ROLE'),
  correlation_id uuid not null,
  recorded_at timestamptz not null default clock_timestamp(),
  unique (proof_id, sequence),
  unique (proof_id, correlation_id)
);

alter table public.delivery_proofs
  add column current_scan_result_id uuid references private.delivery_proof_scan_results(id) on delete restrict,
  add constraint delivery_proof_scan_state_chk check (
    (scan_status = 'PENDING') = (current_scan_result_id is null)
    and (current_scan_result_id is null) = (scanned_at is null)
  );

create table private.delivery_proof_scan_idempotency (
  proof_id uuid not null references public.delivery_proofs(id) on delete restrict,
  key text not null check (length(key) between 8 and 200),
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  response_body jsonb not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key (proof_id,key)
);

alter table private.delivery_proof_scan_results enable row level security;
alter table private.delivery_proof_scan_idempotency enable row level security;
revoke all on private.delivery_proof_scan_results,private.delivery_proof_scan_idempotency from public,anon,authenticated,service_role;
create trigger delivery_proof_scan_results_immutable before update or delete on private.delivery_proof_scan_results for each row execute function private.prevent_update_delete();
create trigger delivery_proof_scan_idempotency_immutable before update or delete on private.delivery_proof_scan_idempotency for each row execute function private.prevent_update_delete();

create index delivery_proofs_pending_scan_idx on public.delivery_proofs(created_at,id) where scan_status='PENDING';

create function public.get_delivery_proof_scan_job(p_proof_id uuid) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private
as $$declare p public.delivery_proofs%rowtype;begin
  if auth.role() is distinct from 'service_role' then raise exception 'TRUSTED_SCANNER_SERVICE_REQUIRED' using errcode='42501';end if;
  select * into p from public.delivery_proofs where id=p_proof_id;
  if not found then raise exception 'DELIVERY_PROOF_NOT_FOUND' using errcode='P0002';end if;
  return jsonb_build_object('proof_id',p.id,'proof_type',p.proof_type,'storage_path',p.storage_path,'url',p.url,'expected_sha256',p.evidence_hash,'scan_status',p.scan_status);
end$$;

create function public.record_delivery_proof_scan_result(
  p_proof_id uuid,p_result text,p_engine_code text,p_engine_version text,
  p_computed_sha256 text,p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$declare
  p public.delivery_proofs%rowtype;m public.missions%rowtype;v_hash text;v_response jsonb;
  v_existing private.delivery_proof_scan_idempotency%rowtype;v_scan_id uuid;v_sequence integer;
begin
  if auth.role() is distinct from 'service_role' then raise exception 'TRUSTED_SCANNER_SERVICE_REQUIRED' using errcode='42501';end if;
  if p_result not in ('CLEAN','INFECTED','ERROR') or coalesce(p_engine_code,'')!~'^[A-Z][A-Z0-9_.-]{2,79}$'
    or length(btrim(coalesce(p_engine_version,''))) not between 1 and 80
    or coalesce(p_computed_sha256,'')!~'^[0-9a-f]{64}$' or length(coalesce(p_idempotency_key,'')) not between 8 and 200
  then raise exception 'INVALID_DELIVERY_PROOF_SCAN_RESULT' using errcode='22023';end if;
  select * into p from public.delivery_proofs where id=p_proof_id;
  if not found then raise exception 'DELIVERY_PROOF_NOT_FOUND' using errcode='P0002';end if;
  perform pg_advisory_xact_lock(hashtextextended('delivery-proof-scan:'||p.id::text,0));
  select * into p from public.delivery_proofs where id=p.id for update;
  v_hash:=private.canonical_request_hash(jsonb_build_object('operation','delivery.proof.scan.v1','proof_id',p.id,'result',p_result,'engine_code',p_engine_code,'engine_version',btrim(p_engine_version),'computed_sha256',p_computed_sha256));
  select * into v_existing from private.delivery_proof_scan_idempotency where proof_id=p.id and key=p_idempotency_key;
  if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000';end if;return v_existing.response_body;end if;
  if p_computed_sha256<>p.evidence_hash then raise exception 'SCAN_EVIDENCE_HASH_MISMATCH' using errcode='22000';end if;
  select coalesce(max(sequence),0)+1 into v_sequence from private.delivery_proof_scan_results where proof_id=p.id;
  insert into private.delivery_proof_scan_results(proof_id,sequence,result,engine_code,engine_version,computed_sha256,scanner_principal,correlation_id)
  values(p.id,v_sequence,p_result,p_engine_code,btrim(p_engine_version),p_computed_sha256,'SUPABASE_SERVICE_ROLE',p_correlation_id) returning id into v_scan_id;
  update public.delivery_proofs set scan_status=p_result,scanned_at=clock_timestamp(),current_scan_result_id=v_scan_id where id=p.id;
  select mission.* into m from public.delivery_versions version join public.deliverables deliverable on deliverable.id=version.deliverable_id join public.missions mission on mission.id=deliverable.mission_id where version.id=p.delivery_version_id;
  v_response:=jsonb_build_object('outcome','DELIVERY_PROOF_SCAN_RECORDED','proof_id',p.id,'scan_id',v_scan_id,'result',p_result);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(m.client_organization_id,auth.uid(),'SERVICE','delivery.proof.scan.recorded','delivery_proof',p.id::text,p_correlation_id,jsonb_build_object('result',p_result,'engine_code',p_engine_code),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
  values(m.client_organization_id,'delivery_proof',p.id::text,case when p_result='CLEAN'then'DeliveryProofScanCleanV1'when p_result='INFECTED'then'DeliveryProofQuarantinedV1'else'DeliveryProofScanFailedV1'end,p_correlation_id,v_response,p_idempotency_key);
  insert into private.delivery_proof_scan_idempotency(proof_id,key,request_hash,response_body)values(p.id,p_idempotency_key,v_hash,v_response);
  return v_response;
end$$;

create function private.require_clean_delivery_proofs() returns trigger language plpgsql security definer set search_path=pg_catalog,public
as $$begin
  if old.status='SUBMITTED' and new.status in('ACCEPTED','REJECTED') and exists(
    select 1 from public.delivery_versions version join public.delivery_proofs proof on proof.delivery_version_id=version.id
    where version.deliverable_id=new.id and version.version=new.current_version and proof.scan_status<>'CLEAN'
  ) then raise exception 'CLEAN_DELIVERY_PROOF_SCAN_REQUIRED' using errcode='55000';end if;
  return new;
end$$;
create trigger deliverable_clean_proofs_before_decision before update of status on public.deliverables for each row execute function private.require_clean_delivery_proofs();

revoke all on function public.get_delivery_proof_scan_job(uuid),public.record_delivery_proof_scan_result(uuid,text,text,text,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_delivery_proof_scan_job(uuid),public.record_delivery_proof_scan_result(uuid,text,text,text,text,text,uuid) to service_role;
