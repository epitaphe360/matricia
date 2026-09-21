-- Provider payment evidence is archived as an immutable, tenant-bound document.
-- The existing private provider document bucket is reused; no object becomes public.
-- Rollback: stop calling begin_provider_payment_proof_upload, then remove only
-- unbound payment objects before dropping these additive objects/functions.

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('provider-qualification','provider-qualification',false,10485760,array['application/pdf','image/jpeg','image/png'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create table public.provider_payment_proof_uploads(
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.organizations(id) on delete restrict,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  storage_bucket text not null default 'provider-qualification' check(storage_bucket='provider-qualification'),
  storage_object_path text not null unique check(length(storage_object_path) between 40 and 400 and storage_object_path!~'(^|/)\.\.(/|$)'),
  original_file_name text not null check(length(btrim(original_file_name)) between 3 and 255 and original_file_name!~'[\\/[:cntrl:]]'),
  declared_mime_type text not null check(declared_mime_type in('application/pdf','image/jpeg','image/png')),
  declared_size_bytes bigint not null check(declared_size_bytes between 1 and 10485760),
  declared_sha256 text not null check(declared_sha256~'^[0-9a-f]{64}$'),
  status text not null default 'UPLOAD_PENDING' check(status in('UPLOAD_PENDING','BOUND')),
  payment_id uuid,
  expires_at timestamptz not null default clock_timestamp()+interval '30 minutes',
  created_at timestamptz not null default clock_timestamp(),
  bound_at timestamptz,
  unique(provider_organization_id,id),
  check((status='BOUND')=(payment_id is not null and bound_at is not null))
);

create table public.provider_payment_proofs(
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null,
  payment_id uuid not null,
  version integer not null default 1 check(version>0),
  upload_id uuid not null unique,
  storage_bucket text not null default 'provider-qualification' check(storage_bucket='provider-qualification'),
  storage_object_path text not null unique,
  original_file_name text not null check(length(btrim(original_file_name)) between 3 and 255 and original_file_name!~'[\\/[:cntrl:]]'),
  mime_type text not null check(mime_type in('application/pdf','image/jpeg','image/png')),
  size_bytes bigint not null check(size_bytes between 1 and 10485760),
  sha256 text not null check(sha256~'^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  unique(provider_organization_id,payment_id,version),
  foreign key(provider_organization_id,payment_id) references public.provider_payments(provider_organization_id,id) on delete restrict,
  foreign key(provider_organization_id,upload_id) references public.provider_payment_proof_uploads(provider_organization_id,id) on delete restrict
);

alter table public.provider_payment_proof_uploads
  add foreign key(provider_organization_id,payment_id) references public.provider_payments(provider_organization_id,id) on delete restrict;

create index provider_payment_proof_uploads_pending_idx on public.provider_payment_proof_uploads(expires_at,actor_user_id)
where status='UPLOAD_PENDING';
create index provider_payment_proofs_payment_idx on public.provider_payment_proofs(provider_organization_id,payment_id,version desc);

alter table public.provider_payment_proof_uploads enable row level security;
alter table public.provider_payment_proofs enable row level security;
revoke all on public.provider_payment_proof_uploads,public.provider_payment_proofs from public,anon,authenticated,service_role;
grant select on public.provider_payment_proof_uploads,public.provider_payment_proofs to authenticated;

create policy provider_payment_proof_uploads_scoped_read on public.provider_payment_proof_uploads for select to authenticated
using(actor_user_id=auth.uid() or private.provider_billing_access(provider_organization_id,auth.uid()));
create policy provider_payment_proofs_scoped_read on public.provider_payment_proofs for select to authenticated
using(private.provider_billing_access(provider_organization_id,auth.uid()));

create function public.begin_provider_payment_proof_upload(
  p_provider_organization_id uuid,p_original_file_name text,p_declared_mime_type text,
  p_declared_size_bytes bigint,p_declared_sha256 text,p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions
as $$
declare a uuid:=auth.uid();h text;r jsonb;u uuid:=extensions.gen_random_uuid();ext text;path text;
begin
  if a is null or not coalesce(private.has_org_role(p_provider_organization_id,array['PROVIDER_OWNER','PROVIDER_ACCOUNTING'],a)
    or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a),false)then
    raise exception'PROVIDER_PAYMENT_PROOF_DENIED'using errcode='42501';end if;
  if length(btrim(coalesce(p_original_file_name,'')))not between 3 and 255 or p_original_file_name~'[\\/[:cntrl:]]'
    or p_declared_mime_type not in('application/pdf','image/jpeg','image/png')
    or p_declared_size_bytes is null or p_declared_size_bytes not between 1 and 10485760 or coalesce(p_declared_sha256,'')!~'^[0-9a-f]{64}$'then
    raise exception'INVALID_PROVIDER_PAYMENT_PROOF'using errcode='22023';end if;
  ext:=case p_declared_mime_type when'application/pdf'then'.pdf'when'image/jpeg'then'.jpg'else'.png'end;
  if lower(right(p_original_file_name,length(ext)))<>ext and not(p_declared_mime_type='image/jpeg'and lower(right(p_original_file_name,5))='.jpeg')then
    raise exception'PROVIDER_PAYMENT_PROOF_EXTENSION_MISMATCH'using errcode='22023';end if;
  h:=private.canonical_request_hash(jsonb_build_object('operation','provider.payment.proof.reserve.v1','provider',p_provider_organization_id,'file_name',p_original_file_name,'mime',p_declared_mime_type,'size',p_declared_size_bytes,'sha256',p_declared_sha256));
  r:=private.begin_provider_billing_command(p_provider_organization_id,'provider.billing.payment-proof.reserve',p_idempotency_key,h,a);if r is not null then return r;end if;
  path:='payments/'||p_provider_organization_id::text||'/'||a::text||'/'||u::text||ext;
  insert into public.provider_payment_proof_uploads(id,provider_organization_id,actor_user_id,storage_object_path,original_file_name,declared_mime_type,declared_size_bytes,declared_sha256)
  values(u,p_provider_organization_id,a,path,btrim(p_original_file_name),p_declared_mime_type,p_declared_size_bytes,p_declared_sha256);
  r:=jsonb_build_object('outcome','PROVIDER_PAYMENT_PROOF_UPLOAD_RESERVED','upload_id',u,'storage_bucket','provider-qualification','storage_object_path',path,'expires_at',clock_timestamp()+interval'30 minutes');
  perform private.finish_provider_billing_command(p_provider_organization_id,'provider.billing.payment-proof.reserve',p_idempotency_key,r);return r;
end$$;

create function private.provider_payment_proof_upload_allowed(p_bucket text,p_name text,p_actor uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public,private
as $$select p_actor is not null and p_bucket='provider-qualification' and exists(
  select 1 from public.provider_payment_proof_uploads u where u.actor_user_id=p_actor and u.storage_bucket=p_bucket
  and u.storage_object_path=p_name and u.status='UPLOAD_PENDING'and u.expires_at>clock_timestamp()
  and(private.has_org_role(u.provider_organization_id,array['PROVIDER_OWNER','PROVIDER_ACCOUNTING'],p_actor)
    or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],p_actor)))$$;

create policy provider_payment_proof_storage_reserved_insert on storage.objects for insert to authenticated
with check(private.provider_payment_proof_upload_allowed(bucket_id,name,auth.uid()));
create policy provider_payment_proof_storage_orphan_delete on storage.objects for delete to authenticated
using(private.provider_payment_proof_upload_allowed(bucket_id,name,auth.uid()));
create policy provider_payment_proof_storage_scoped_read on storage.objects for select to authenticated
using(bucket_id='provider-qualification'and exists(select 1 from public.provider_payment_proofs p
  where p.storage_bucket=bucket_id and p.storage_object_path=name and private.provider_billing_access(p.provider_organization_id,auth.uid())));

create or replace function public.record_provider_payment(p_provider_organization_id uuid,p_payment_reference text,p_paid_on date,p_payment_method text,p_currency char(3),p_amount_minor bigint,p_proof_hash text,p_cash_account_id uuid,p_receivable_account_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions,storage as $$
declare a uuid:=auth.uid();h text;r jsonb;p uuid;j uuid:=extensions.gen_random_uuid();u public.provider_payment_proof_uploads%rowtype;proof uuid;object_record record;
begin
  if a is null or not(private.has_org_role(p_provider_organization_id,array['PROVIDER_OWNER','PROVIDER_ACCOUNTING'],a)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a))then raise exception'PROVIDER_PAYMENT_DENIED'using errcode='42501';end if;
  if p_amount_minor<=0 or p_currency!~'^[A-Z]{3}$'or p_payment_method not in('BANK_TRANSFER','CARD','CHECK','CASH','OTHER')or p_proof_hash!~'^[0-9a-f]{64}$'then raise exception'INVALID_PROVIDER_PAYMENT'using errcode='22023';end if;
  if not exists(select 1 from public.financial_accounts where id=p_cash_account_id and organization_id=p_provider_organization_id and currency=p_currency)or not exists(select 1 from public.financial_accounts where id=p_receivable_account_id and organization_id=p_provider_organization_id and currency=p_currency)then raise exception'INVALID_PROVIDER_LEDGER_ACCOUNT'using errcode='23514';end if;
  h:=private.canonical_request_hash(jsonb_build_object('provider',p_provider_organization_id,'reference',p_payment_reference,'paid_on',p_paid_on,'method',p_payment_method,'currency',p_currency,'amount',p_amount_minor,'proof_hash',p_proof_hash,'cash_account',p_cash_account_id,'receivable_account',p_receivable_account_id));
  r:=private.begin_provider_billing_command(p_provider_organization_id,'provider.billing.payment.record',p_idempotency_key,h,a);if r is not null then return r;end if;
  select*into u from public.provider_payment_proof_uploads candidate where candidate.provider_organization_id=p_provider_organization_id
    and candidate.actor_user_id=a and candidate.declared_sha256=p_proof_hash and candidate.status='UPLOAD_PENDING'
    and candidate.expires_at>clock_timestamp() order by candidate.created_at desc,candidate.id desc limit 1 for update;
  if not found then raise exception'PAYMENT_PROOF_UPLOAD_REQUIRED'using errcode='23514';end if;
  select lower(o.metadata->>'mimetype')mime_type,o.metadata->>'size'size_text into object_record from storage.objects o
    where o.bucket_id=u.storage_bucket and o.name=u.storage_object_path;
  if not found or coalesce(object_record.size_text,'')!~'^[0-9]+$'or object_record.size_text::bigint<>u.declared_size_bytes
    or object_record.mime_type<>u.declared_mime_type then raise exception'PAYMENT_PROOF_STORAGE_METADATA_MISMATCH'using errcode='22000';end if;
  insert into public.financial_journals(id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,correlation_id,effective_at,description,created_by)values(j,p_provider_organization_id,'PROVIDER_PAYMENT',p_currency,'provider.billing.payment.record',p_idempotency_key,p_correlation_id,p_paid_on::timestamptz,'Provider payment '||p_payment_reference,a);
  insert into public.financial_entries(organization_id,journal_id,account_id,direction,amount_minor,currency)values(p_provider_organization_id,j,p_cash_account_id,'DEBIT',p_amount_minor,p_currency),(p_provider_organization_id,j,p_receivable_account_id,'CREDIT',p_amount_minor,p_currency);
  insert into public.provider_payments(provider_organization_id,payment_reference,paid_on,payment_method,currency,amount_minor,proof_hash,journal_id,correlation_id,recorded_by)values(p_provider_organization_id,p_payment_reference,p_paid_on,p_payment_method,p_currency,p_amount_minor,p_proof_hash,j,p_correlation_id,a)returning id into p;
  insert into public.provider_payment_proofs(provider_organization_id,payment_id,upload_id,storage_object_path,original_file_name,mime_type,size_bytes,sha256,created_by)
    values(p_provider_organization_id,p,u.id,u.storage_object_path,u.original_file_name,u.declared_mime_type,u.declared_size_bytes,u.declared_sha256,a)returning id into proof;
  update public.provider_payment_proof_uploads set status='BOUND',payment_id=p,bound_at=clock_timestamp()where id=u.id;
  r:=jsonb_build_object('outcome','PROVIDER_PAYMENT_RECORDED','payment_id',p,'payment_proof_id',proof,'journal_id',j,'amount_minor',p_amount_minor);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_provider_organization_id,a,'USER','provider.payment.recorded','provider_payment',p::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_provider_organization_id,'provider_payment',p::text,'ProviderPaymentRecordedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_provider_billing_command(p_provider_organization_id,'provider.billing.payment.record',p_idempotency_key,r);return r;
end$$;

create trigger provider_payment_proofs_immutable before update or delete on public.provider_payment_proofs
for each row execute function private.prevent_update_delete();

revoke all on function public.begin_provider_payment_proof_upload(uuid,text,text,bigint,text,text,uuid) from public,anon,service_role;
grant execute on function public.begin_provider_payment_proof_upload(uuid,text,text,bigint,text,text,uuid) to authenticated;
revoke all on function private.provider_payment_proof_upload_allowed(text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function private.provider_payment_proof_upload_allowed(text,text,uuid) to authenticated;
