-- Provider payment proofs reuse the trusted delivery-proof scanner contract.
-- Financial recording remains impossible until an immutable CLEAN verdict
-- matches the reserved object's declared SHA-256.

alter table public.provider_payment_proof_uploads
  add column scan_status text not null default 'PENDING'
    check(scan_status in('PENDING','CLEAN','INFECTED','ERROR')),
  add column scanned_at timestamptz;

create table private.provider_payment_proof_scan_results(
  id uuid primary key default extensions.gen_random_uuid(),
  upload_id uuid not null references public.provider_payment_proof_uploads(id) on delete restrict,
  sequence integer not null check(sequence>0),
  result text not null check(result in('CLEAN','INFECTED','ERROR')),
  engine_code text not null check(engine_code~'^[A-Z][A-Z0-9_.-]{2,79}$'),
  engine_version text not null check(length(btrim(engine_version))between 1 and 80),
  computed_sha256 text not null check(computed_sha256~'^[0-9a-f]{64}$'),
  scanner_principal text not null default 'SUPABASE_SERVICE_ROLE' check(scanner_principal='SUPABASE_SERVICE_ROLE'),
  correlation_id uuid not null,
  recorded_at timestamptz not null default clock_timestamp(),
  unique(upload_id,sequence)
);
alter table private.provider_payment_proof_scan_results enable row level security;
revoke all on private.provider_payment_proof_scan_results from public,anon,authenticated,service_role;
create trigger provider_payment_proof_scan_results_immutable before update or delete on private.provider_payment_proof_scan_results
for each row execute function private.prevent_update_delete();

alter table public.provider_payment_proof_uploads
  add column current_scan_result_id uuid references private.provider_payment_proof_scan_results(id) on delete restrict,
  add constraint provider_payment_proof_scan_state_check check(
    (scan_status='PENDING' and scanned_at is null and current_scan_result_id is null)
    or(scan_status<>'PENDING' and scanned_at is not null and current_scan_result_id is not null)
  );
alter table public.provider_payment_proofs
  add column scan_result_id uuid references private.provider_payment_proof_scan_results(id) on delete restrict;

create index provider_payment_proof_uploads_pending_scan_idx
on public.provider_payment_proof_uploads(created_at,id)
where status='UPLOAD_PENDING'and scan_status='PENDING';

create table private.provider_payment_proof_scan_claims(
  upload_id uuid primary key references public.provider_payment_proof_uploads(id) on delete cascade,
  worker_id uuid not null,
  lease_token uuid not null default extensions.gen_random_uuid(),
  leased_until timestamptz not null,
  row_version integer not null default 1 check(row_version>0),
  attempt_count integer not null default 0 check(attempt_count between 0 and 5),
  claimed_at timestamptz not null default clock_timestamp()
);
alter table private.provider_payment_proof_scan_claims enable row level security;
revoke all on private.provider_payment_proof_scan_claims from public,anon,authenticated,service_role;

create table private.provider_payment_proof_scan_retry_history(
  id uuid primary key default extensions.gen_random_uuid(),
  upload_id uuid not null references public.provider_payment_proof_uploads(id) on delete restrict,
  attempt integer not null check(attempt between 1 and 5),
  failure_code text not null check(failure_code in('SCANNER_UNAVAILABLE','SCANNER_INVALID_RESPONSE','STORAGE_DOWNLOAD_FAILED')),
  worker_id uuid not null,lease_token uuid not null,correlation_id uuid not null,
  recorded_at timestamptz not null default clock_timestamp(),
  unique(upload_id,attempt)
);
alter table private.provider_payment_proof_scan_retry_history enable row level security;
revoke all on private.provider_payment_proof_scan_retry_history from public,anon,authenticated,service_role;
create trigger provider_payment_proof_scan_retry_history_immutable before update or delete on private.provider_payment_proof_scan_retry_history
for each row execute function private.prevent_update_delete();

create table private.provider_payment_proof_scan_idempotency(
  upload_id uuid not null references public.provider_payment_proof_uploads(id) on delete restrict,
  key text not null,request_hash text not null check(request_hash~'^[0-9a-f]{64}$'),
  response_body jsonb not null,created_at timestamptz not null default clock_timestamp(),
  primary key(upload_id,key)
);
alter table private.provider_payment_proof_scan_idempotency enable row level security;
revoke all on private.provider_payment_proof_scan_idempotency from public,anon,authenticated,service_role;
create trigger provider_payment_proof_scan_idempotency_immutable before update or delete on private.provider_payment_proof_scan_idempotency
for each row execute function private.prevent_update_delete();

create function public.claim_provider_payment_proof_scan_jobs(
  p_worker_id uuid,p_limit integer default 20,p_lease_seconds integer default 300
) returns table(
  proof_id uuid,lease_token uuid,worker_id uuid,row_version integer,attempt_count integer,
  storage_bucket text,storage_path text,expected_sha256 text,media_type text
) language plpgsql security definer set search_path=pg_catalog,public,private,extensions,storage
as $$
declare u public.provider_payment_proof_uploads%rowtype;c private.provider_payment_proof_scan_claims%rowtype;
begin
  if auth.role()is distinct from'service_role'then raise exception'TRUSTED_SCANNER_SERVICE_REQUIRED'using errcode='42501';end if;
  if p_worker_id is null or p_limit not between 1 and 100 or p_lease_seconds not between 30 and 900 then raise exception'INVALID_SCAN_CLAIM'using errcode='22023';end if;
  for u in select candidate.* from public.provider_payment_proof_uploads candidate
    where candidate.status='UPLOAD_PENDING'and candidate.scan_status='PENDING'and candidate.expires_at>clock_timestamp()
      and exists(select 1 from storage.objects o where o.bucket_id=candidate.storage_bucket and o.name=candidate.storage_object_path)
      and not exists(select 1 from private.provider_payment_proof_scan_claims active where active.upload_id=candidate.id and active.leased_until>clock_timestamp())
    order by candidate.created_at,candidate.id for update skip locked limit p_limit
  loop
    insert into private.provider_payment_proof_scan_claims(upload_id,worker_id,leased_until)
    values(u.id,p_worker_id,clock_timestamp()+make_interval(secs=>p_lease_seconds))
    on conflict on constraint provider_payment_proof_scan_claims_pkey do update
      set worker_id=excluded.worker_id,lease_token=extensions.gen_random_uuid(),leased_until=excluded.leased_until,
          row_version=private.provider_payment_proof_scan_claims.row_version+1,claimed_at=clock_timestamp()
      where private.provider_payment_proof_scan_claims.leased_until<=clock_timestamp()
    returning*into c;
    if found then proof_id:=u.id;lease_token:=c.lease_token;worker_id:=c.worker_id;row_version:=c.row_version;attempt_count:=c.attempt_count;
      storage_bucket:=u.storage_bucket;storage_path:=u.storage_object_path;expected_sha256:=u.declared_sha256;media_type:=u.declared_mime_type;return next;end if;
  end loop;
end$$;

create function public.record_provider_payment_proof_scan_result(
  p_upload_id uuid,p_result text,p_engine_code text,p_engine_version text,p_computed_sha256 text,
  p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private
as $$
declare u public.provider_payment_proof_uploads%rowtype;s integer;i uuid;h text;r jsonb;prior private.provider_payment_proof_scan_idempotency%rowtype;
begin
  if auth.role()is distinct from'service_role'then raise exception'TRUSTED_SCANNER_SERVICE_REQUIRED'using errcode='42501';end if;
  if p_result not in('CLEAN','INFECTED','ERROR')or p_engine_code!~'^[A-Z][A-Z0-9_.-]{2,79}$'
    or length(btrim(coalesce(p_engine_version,'')))not between 1 and 80 or coalesce(p_computed_sha256,'')!~'^[0-9a-f]{64}$'
    or length(btrim(coalesce(p_idempotency_key,'')))not between 8 and 200 then raise exception'INVALID_PROVIDER_PAYMENT_PROOF_SCAN'using errcode='22023';end if;
  h:=private.canonical_request_hash(jsonb_build_object('upload',p_upload_id,'result',p_result,'engine',p_engine_code,'version',p_engine_version,'sha256',p_computed_sha256));
  select*into prior from private.provider_payment_proof_scan_idempotency where upload_id=p_upload_id and key=p_idempotency_key;
  if found then if prior.request_hash<>h then raise exception'IDEMPOTENCY_CONFLICT'using errcode='23505';end if;return prior.response_body;end if;
  select*into u from public.provider_payment_proof_uploads where id=p_upload_id for update;
  if not found or u.status<>'UPLOAD_PENDING'or u.scan_status<>'PENDING'then raise exception'PROVIDER_PAYMENT_PROOF_SCAN_STATE_INVALID'using errcode='55000';end if;
  if p_result='CLEAN'and p_computed_sha256<>u.declared_sha256 then raise exception'PROVIDER_PAYMENT_PROOF_SCAN_HASH_MISMATCH'using errcode='22000';end if;
  select coalesce(max(sequence),0)+1 into s from private.provider_payment_proof_scan_results where upload_id=u.id;
  insert into private.provider_payment_proof_scan_results(upload_id,sequence,result,engine_code,engine_version,computed_sha256,correlation_id)
  values(u.id,s,p_result,p_engine_code,btrim(p_engine_version),p_computed_sha256,p_correlation_id)returning id into i;
  update public.provider_payment_proof_uploads set scan_status=p_result,scanned_at=clock_timestamp(),current_scan_result_id=i where id=u.id;
  r:=jsonb_build_object('outcome','PROVIDER_PAYMENT_PROOF_SCAN_RECORDED','proof_id',u.id,'scan_id',i,'result',p_result);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(u.provider_organization_id,null,'SERVICE','provider.payment.proof.scan.recorded','provider_payment_proof_upload',u.id::text,p_correlation_id,jsonb_build_object('result',p_result,'engine_code',p_engine_code),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
  values(u.provider_organization_id,'provider_payment_proof_upload',u.id::text,case when p_result='CLEAN'then'ProviderPaymentProofScanCleanV1'when p_result='INFECTED'then'ProviderPaymentProofQuarantinedV1'else'ProviderPaymentProofScanFailedV1'end,p_correlation_id,r,p_idempotency_key);
  insert into private.provider_payment_proof_scan_idempotency(upload_id,key,request_hash,response_body)values(u.id,p_idempotency_key,h,r);return r;
end$$;

create function public.complete_provider_payment_proof_scan_job(
  p_proof_id uuid,p_lease_token uuid,p_worker_id uuid,p_expected_row_version integer,
  p_result text,p_engine_code text,p_engine_version text,p_computed_sha256 text,p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private
as $$declare c private.provider_payment_proof_scan_claims%rowtype;r jsonb;begin
  if auth.role()is distinct from'service_role'then raise exception'TRUSTED_SCANNER_SERVICE_REQUIRED'using errcode='42501';end if;
  select*into c from private.provider_payment_proof_scan_claims where upload_id=p_proof_id for update;
  if not found or c.lease_token<>p_lease_token or c.worker_id<>p_worker_id or c.row_version<>p_expected_row_version or c.leased_until<=clock_timestamp()then raise exception'PROVIDER_PAYMENT_PROOF_SCAN_LEASE_INVALID'using errcode='55000';end if;
  r:=public.record_provider_payment_proof_scan_result(p_proof_id,p_result,p_engine_code,p_engine_version,p_computed_sha256,p_idempotency_key,p_correlation_id);
  delete from private.provider_payment_proof_scan_claims where upload_id=p_proof_id;return r;
end$$;

create function public.fail_provider_payment_proof_scan_job(
  p_proof_id uuid,p_lease_token uuid,p_worker_id uuid,p_expected_row_version integer,
  p_failure_code text,p_computed_sha256 text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private
as $$declare c private.provider_payment_proof_scan_claims%rowtype;n integer;r jsonb;u public.provider_payment_proof_uploads%rowtype;begin
  if auth.role()is distinct from'service_role'then raise exception'TRUSTED_SCANNER_SERVICE_REQUIRED'using errcode='42501';end if;
  if p_failure_code not in('SCANNER_UNAVAILABLE','SCANNER_INVALID_RESPONSE','STORAGE_DOWNLOAD_FAILED')or coalesce(p_computed_sha256,'')!~'^[0-9a-f]{64}$'then raise exception'INVALID_SCAN_FAILURE'using errcode='22023';end if;
  select*into c from private.provider_payment_proof_scan_claims where upload_id=p_proof_id for update;
  if not found or c.lease_token<>p_lease_token or c.worker_id<>p_worker_id or c.row_version<>p_expected_row_version or c.leased_until<=clock_timestamp()then raise exception'PROVIDER_PAYMENT_PROOF_SCAN_LEASE_INVALID'using errcode='55000';end if;
  select*into u from public.provider_payment_proof_uploads where id=p_proof_id;n:=c.attempt_count+1;
  insert into private.provider_payment_proof_scan_retry_history(upload_id,attempt,failure_code,worker_id,lease_token,correlation_id)values(p_proof_id,n,p_failure_code,p_worker_id,p_lease_token,p_correlation_id);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(u.provider_organization_id,null,'SERVICE',case when n>=5 then'provider.payment.proof.scan.dead_lettered'else'provider.payment.proof.scan.retry_scheduled'end,'provider_payment_proof_upload',p_proof_id::text,p_correlation_id,jsonb_build_object('attempt',n,'failure_code',p_failure_code),repeat('0',64));
  if n>=5 then r:=public.record_provider_payment_proof_scan_result(p_proof_id,'ERROR','MATRICIA_SCAN_DLQ','1.0.0',p_computed_sha256,'provider-payment-proof-scan-dlq:'||p_proof_id::text||':'||n,p_correlation_id);delete from private.provider_payment_proof_scan_claims where upload_id=p_proof_id;return jsonb_build_object('outcome','PROVIDER_PAYMENT_PROOF_SCAN_DEAD_LETTERED','proof_id',p_proof_id,'attempt',n,'scan',r);end if;
  update private.provider_payment_proof_scan_claims set attempt_count=n,row_version=row_version+1,lease_token=extensions.gen_random_uuid(),leased_until=clock_timestamp()+make_interval(secs=>least(900,30*(2^n)))where upload_id=p_proof_id;
  return jsonb_build_object('outcome','PROVIDER_PAYMENT_PROOF_SCAN_RETRY_SCHEDULED','proof_id',p_proof_id,'attempt',n,'failure_code',p_failure_code);
end$$;

create or replace function public.record_provider_payment(p_provider_organization_id uuid,p_payment_reference text,p_paid_on date,p_payment_method text,p_currency char(3),p_amount_minor bigint,p_proof_hash text,p_cash_account_id uuid,p_receivable_account_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions,storage as $$
declare a uuid:=auth.uid();h text;r jsonb;p uuid;j uuid:=extensions.gen_random_uuid();u public.provider_payment_proof_uploads%rowtype;proof uuid;object_record record;
begin
 if a is null or not(private.has_org_role(p_provider_organization_id,array['PROVIDER_OWNER','PROVIDER_ACCOUNTING'],a)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a))then raise exception'PROVIDER_PAYMENT_DENIED'using errcode='42501';end if;
 if p_amount_minor<=0 or p_currency!~'^[A-Z]{3}$'or p_payment_method not in('BANK_TRANSFER','CARD','CHECK','CASH','OTHER')or p_proof_hash!~'^[0-9a-f]{64}$'then raise exception'INVALID_PROVIDER_PAYMENT'using errcode='22023';end if;
 if not exists(select 1 from public.financial_accounts where id=p_cash_account_id and organization_id=p_provider_organization_id and currency=p_currency)or not exists(select 1 from public.financial_accounts where id=p_receivable_account_id and organization_id=p_provider_organization_id and currency=p_currency)then raise exception'INVALID_PROVIDER_LEDGER_ACCOUNT'using errcode='23514';end if;
 h:=private.canonical_request_hash(jsonb_build_object('provider',p_provider_organization_id,'reference',p_payment_reference,'paid_on',p_paid_on,'method',p_payment_method,'currency',p_currency,'amount',p_amount_minor,'proof_hash',p_proof_hash,'cash_account',p_cash_account_id,'receivable_account',p_receivable_account_id));
 r:=private.begin_provider_billing_command(p_provider_organization_id,'provider.billing.payment.record',p_idempotency_key,h,a);if r is not null then return r;end if;
 select*into u from public.provider_payment_proof_uploads candidate where candidate.provider_organization_id=p_provider_organization_id and candidate.actor_user_id=a and candidate.declared_sha256=p_proof_hash and candidate.status='UPLOAD_PENDING'and candidate.expires_at>clock_timestamp()order by candidate.created_at desc,candidate.id desc limit 1 for update;
 if not found then raise exception'PAYMENT_PROOF_UPLOAD_REQUIRED'using errcode='23514';end if;
 if u.scan_status<>'CLEAN'or u.current_scan_result_id is null or not exists(select 1 from private.provider_payment_proof_scan_results s where s.id=u.current_scan_result_id and s.upload_id=u.id and s.result='CLEAN'and s.computed_sha256=u.declared_sha256)then raise exception'PAYMENT_PROOF_SCAN_NOT_CLEAN'using errcode='55000';end if;
 select lower(o.metadata->>'mimetype')mime_type,o.metadata->>'size'size_text into object_record from storage.objects o where o.bucket_id=u.storage_bucket and o.name=u.storage_object_path;
 if not found or coalesce(object_record.size_text,'')!~'^[0-9]+$'or object_record.size_text::bigint<>u.declared_size_bytes or object_record.mime_type<>u.declared_mime_type then raise exception'PAYMENT_PROOF_STORAGE_METADATA_MISMATCH'using errcode='22000';end if;
 insert into public.financial_journals(id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,correlation_id,effective_at,description,created_by)values(j,p_provider_organization_id,'PROVIDER_PAYMENT',p_currency,'provider.billing.payment.record',p_idempotency_key,p_correlation_id,p_paid_on::timestamptz,'Provider payment '||p_payment_reference,a);
 insert into public.financial_entries(organization_id,journal_id,account_id,direction,amount_minor,currency)values(p_provider_organization_id,j,p_cash_account_id,'DEBIT',p_amount_minor,p_currency),(p_provider_organization_id,j,p_receivable_account_id,'CREDIT',p_amount_minor,p_currency);
 insert into public.provider_payments(provider_organization_id,payment_reference,paid_on,payment_method,currency,amount_minor,proof_hash,journal_id,correlation_id,recorded_by)values(p_provider_organization_id,p_payment_reference,p_paid_on,p_payment_method,p_currency,p_amount_minor,p_proof_hash,j,p_correlation_id,a)returning id into p;
 insert into public.provider_payment_proofs(provider_organization_id,payment_id,upload_id,storage_object_path,original_file_name,mime_type,size_bytes,sha256,created_by,scan_result_id)values(p_provider_organization_id,p,u.id,u.storage_object_path,u.original_file_name,u.declared_mime_type,u.declared_size_bytes,u.declared_sha256,a,u.current_scan_result_id)returning id into proof;
 update public.provider_payment_proof_uploads set status='BOUND',payment_id=p,bound_at=clock_timestamp()where id=u.id;
 r:=jsonb_build_object('outcome','PROVIDER_PAYMENT_RECORDED','payment_id',p,'payment_proof_id',proof,'journal_id',j,'amount_minor',p_amount_minor);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_provider_organization_id,a,'USER','provider.payment.recorded','provider_payment',p::text,p_correlation_id,r,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_provider_organization_id,'provider_payment',p::text,'ProviderPaymentRecordedV1',p_correlation_id,r,p_idempotency_key);
 perform private.finish_provider_billing_command(p_provider_organization_id,'provider.billing.payment.record',p_idempotency_key,r);return r;
end$$;

revoke all on function public.claim_provider_payment_proof_scan_jobs(uuid,integer,integer),public.record_provider_payment_proof_scan_result(uuid,text,text,text,text,text,uuid),public.complete_provider_payment_proof_scan_job(uuid,uuid,uuid,integer,text,text,text,text,text,uuid),public.fail_provider_payment_proof_scan_job(uuid,uuid,uuid,integer,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.claim_provider_payment_proof_scan_jobs(uuid,integer,integer),public.record_provider_payment_proof_scan_result(uuid,text,text,text,text,text,uuid),public.complete_provider_payment_proof_scan_job(uuid,uuid,uuid,integer,text,text,text,text,text,uuid),public.fail_provider_payment_proof_scan_job(uuid,uuid,uuid,integer,text,text,uuid) to service_role;
