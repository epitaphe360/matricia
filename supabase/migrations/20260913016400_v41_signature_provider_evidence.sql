-- V4.1 P0: provider-neutral Moroccan e-signature evidence. This is additive and
-- deliberately stores provider secret references, never secret values.
create table public.signature_provider_configs (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_code text not null check(provider_code~'^[A-Z][A-Z0-9_]{2,63}$'),
  environment text not null check(environment in('DEVELOPMENT','STAGING','PRODUCTION')),
  version integer not null check(version>0),
  status text not null check(status in('DRAFT','ACTIVE','RETIRED','SUSPENDED')),
  supported_levels text[] not null check(cardinality(supported_levels)>0 and supported_levels<@array['SIMPLE','ADVANCED','QUALIFIED']::text[]),
  webhook_tolerance_seconds integer not null default 300 check(webhook_tolerance_seconds between 30 and 900),
  endpoint_base_url text,
  secret_reference_names text[] not null default '{}' check(not ('')=any(secret_reference_names)),
  config_metadata jsonb not null default '{}' check(jsonb_typeof(config_metadata)='object'),
  valid_from timestamptz not null default clock_timestamp(),
  valid_until timestamptz,
  created_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  unique(provider_code,environment,version),
  check(valid_until is null or valid_until>valid_from),
  check((environment='DEVELOPMENT' and provider_code='MATRICIA_DEV_MOCK') or endpoint_base_url is not null)
);

create table public.signature_envelopes (
  id uuid primary key default extensions.gen_random_uuid(),
  client_organization_id uuid not null references public.organizations(id) on delete restrict,
  contract_id uuid not null references public.contracts(id) on delete restrict,
  contract_version_id uuid not null,
  provider_config_id uuid not null references public.signature_provider_configs(id) on delete restrict,
  provider_code text not null,
  provider_envelope_id text,
  envelope_version integer not null check(envelope_version>0),
  supersedes_envelope_id uuid references public.signature_envelopes(id) on delete restrict,
  requested_level text not null check(requested_level in('SIMPLE','ADVANCED','QUALIFIED')),
  achieved_level text check(achieved_level in('SIMPLE','ADVANCED','QUALIFIED')),
  status text not null default 'DRAFT' check(status in('DRAFT','READY_FOR_SIGNATURE','SENT','PARTIALLY_SIGNED','SIGNED','DECLINED','EXPIRED','FAILED','VOIDED')),
  document_set_hash text not null check(document_set_hash~'^[0-9a-f]{64}$'),
  idempotency_key text not null check(length(idempotency_key) between 8 and 200),
  request_hash text not null check(request_hash~'^[0-9a-f]{64}$'),
  correlation_id uuid not null,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  ready_at timestamptz,
  sent_at timestamptz,
  completed_at timestamptz,
  row_version integer not null default 1 check(row_version>0),
  foreign key(contract_version_id,contract_id) references public.contract_versions(id,contract_id) on delete restrict,
  unique(contract_id,envelope_version),
  unique(client_organization_id,idempotency_key),
  check((status='SIGNED' and achieved_level is not null and completed_at is not null) or status<>'SIGNED'),
  check(supersedes_envelope_id is null or supersedes_envelope_id<>id)
);
alter table public.signature_envelopes add unique(id,contract_version_id);

create table public.signature_documents (
  id uuid primary key default extensions.gen_random_uuid(),
  envelope_id uuid not null references public.signature_envelopes(id) on delete restrict,
  contract_version_id uuid not null references public.contract_versions(id) on delete restrict,
  document_type text not null check(document_type in('CONTRACT','AMENDMENT','ANNEX','AUTHORITY_EVIDENCE')),
  exact_version integer not null check(exact_version>0),
  file_name text not null check(length(btrim(file_name)) between 1 and 255),
  storage_path text not null check(length(btrim(storage_path)) between 3 and 1000),
  sha256 text not null check(sha256~'^[0-9a-f]{64}$'),
  mime_type text not null default 'application/pdf' check(mime_type='application/pdf'),
  sort_order integer not null check(sort_order>0),
  created_at timestamptz not null default clock_timestamp(),
  unique(envelope_id,sort_order),
  unique(envelope_id,sha256),
  foreign key(envelope_id,contract_version_id) references public.signature_envelopes(id,contract_version_id) on delete restrict
);

create table public.signature_signers (
  id uuid primary key default extensions.gen_random_uuid(),
  envelope_id uuid not null references public.signature_envelopes(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  signer_user_id uuid not null references auth.users(id) on delete restrict,
  signer_role text not null check(signer_role~'^[A-Z][A-Z0-9_]{2,79}$'),
  email_hash text not null check(email_hash~'^[0-9a-f]{64}$'),
  signing_order integer not null check(signing_order>0),
  status text not null default 'PENDING' check(status in('PENDING','INVITED','SIGNED','DECLINED','FAILED')),
  identity_verification_level text not null default 'PENDING' check(identity_verification_level in('PENDING','BASIC','STRONG','QUALIFIED')),
  idempotency_key text not null check(length(idempotency_key) between 8 and 200),
  signed_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  unique(envelope_id,organization_id),
  unique(envelope_id,signing_order),
  unique(envelope_id,idempotency_key),
  check((status='SIGNED' and signed_at is not null) or status<>'SIGNED')
);

create table public.signature_signer_authorities (
  id uuid primary key default extensions.gen_random_uuid(),
  signer_id uuid not null references public.signature_signers(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  authority_type text not null check(authority_type in('LEGAL_REPRESENTATIVE','MANDATE','DELEGATION')),
  authority_scope text[] not null check(cardinality(authority_scope)>0),
  amount_ceiling_minor bigint check(amount_ceiling_minor is null or amount_ceiling_minor>=0),
  currency char(3) check(currency is null or currency~'^[A-Z]{3}$'),
  valid_from date not null,
  valid_until date,
  evidence_storage_path text not null check(length(btrim(evidence_storage_path)) between 3 and 1000),
  evidence_sha256 text not null check(evidence_sha256~'^[0-9a-f]{64}$'),
  status text not null default 'ACTIVE' check(status in('ACTIVE','REVOKED','EXPIRED')),
  revoked_at timestamptz,
  verified_by uuid not null references auth.users(id) on delete restrict,
  verified_at timestamptz not null default clock_timestamp(),
  idempotency_key text not null check(length(idempotency_key) between 8 and 200),
  unique(signer_id,idempotency_key),
  check(valid_until is null or valid_until>=valid_from),
  check((status='REVOKED' and revoked_at is not null) or (status<>'REVOKED' and revoked_at is null)),
  check((amount_ceiling_minor is null and currency is null) or (amount_ceiling_minor is not null and currency is not null))
);

create table public.signature_attempts (
  id bigint generated always as identity primary key,
  envelope_id uuid not null references public.signature_envelopes(id) on delete restrict,
  signer_id uuid references public.signature_signers(id) on delete restrict,
  attempt_type text not null check(attempt_type in('CREATE','SEND','SIGN','DECLINE','VERIFY','VOID','PROVIDER_CALLBACK')),
  outcome text not null check(outcome in('SUCCEEDED','FAILED','REJECTED','RETRYABLE')),
  provider_request_id text,
  error_code text,
  occurred_at timestamptz not null default clock_timestamp(),
  correlation_id uuid not null,
  metadata jsonb not null default '{}' check(jsonb_typeof(metadata)='object')
);

create table public.signature_provider_events (
  id bigint generated always as identity primary key,
  envelope_id uuid not null references public.signature_envelopes(id) on delete restrict,
  provider_code text not null,
  provider_event_id text not null check(length(provider_event_id) between 8 and 200),
  nonce text not null check(length(nonce) between 8 and 200),
  event_type text not null check(event_type in('SENT','SIGNER_SIGNED','DECLINED','EXPIRED','FAILED','VOIDED')),
  provider_occurred_at timestamptz not null,
  received_at timestamptz not null default clock_timestamp(),
  payload_hash text not null check(payload_hash~'^[0-9a-f]{64}$'),
  signature_fingerprint text not null check(signature_fingerprint~'^[0-9a-f]{64}$'),
  signature_verified boolean not null check(signature_verified),
  processing_result jsonb not null check(jsonb_typeof(processing_result)='object'),
  correlation_id uuid not null,
  unique(provider_code,provider_event_id),
  unique(provider_code,nonce)
);

create table public.signature_evidence_packages (
  id uuid primary key default extensions.gen_random_uuid(),
  envelope_id uuid not null unique references public.signature_envelopes(id) on delete restrict,
  contract_version_id uuid not null references public.contract_versions(id) on delete restrict,
  pdf_sha256 text not null check(pdf_sha256~'^[0-9a-f]{64}$'),
  signer_actions_snapshot jsonb not null check(jsonb_typeof(signer_actions_snapshot)='array'),
  consent_snapshot jsonb not null check(jsonb_typeof(consent_snapshot)='object'),
  provider_snapshot jsonb not null check(jsonb_typeof(provider_snapshot)='object'),
  event_chain_hash text not null check(event_chain_hash~'^[0-9a-f]{64}$'),
  verification_result text not null check(verification_result in('VERIFIED','VERIFIED_WITH_LIMITATIONS','REJECTED')),
  final_hash text not null unique check(final_hash~'^[0-9a-f]{64}$'),
  sealed_at timestamptz not null default clock_timestamp(),
  correlation_id uuid not null
);

create table public.signature_certificates (
  id uuid primary key default extensions.gen_random_uuid(),
  evidence_package_id uuid not null references public.signature_evidence_packages(id) on delete restrict,
  signer_id uuid not null references public.signature_signers(id) on delete restrict,
  provider_certificate_id text,
  certificate_fingerprint text not null check(certificate_fingerprint~'^[0-9a-f]{64}$'),
  subject_hash text not null check(subject_hash~'^[0-9a-f]{64}$'),
  issuer_name text,
  valid_from timestamptz,
  valid_until timestamptz,
  qualification_status text not null check(qualification_status in('NOT_QUALIFIED','QUALIFIED','UNKNOWN')),
  verification_status text not null check(verification_status in('VERIFIED','REVOKED','EXPIRED','UNAVAILABLE')),
  created_at timestamptz not null default clock_timestamp(),
  unique(evidence_package_id,signer_id),
  check(valid_until is null or valid_from is null or valid_until>valid_from)
);

create table public.trusted_timestamps (
  id uuid primary key default extensions.gen_random_uuid(),
  evidence_package_id uuid not null references public.signature_evidence_packages(id) on delete restrict,
  signer_id uuid references public.signature_signers(id) on delete restrict,
  authority_name text not null check(length(btrim(authority_name)) between 2 and 200),
  token_hash text not null unique check(token_hash~'^[0-9a-f]{64}$'),
  timestamped_at timestamptz not null,
  verification_status text not null check(verification_status in('VERIFIED','REJECTED','UNAVAILABLE')),
  created_at timestamptz not null default clock_timestamp()
);

create function private.signature_envelope_access(p_envelope_id uuid,p_actor uuid default auth.uid()) returns boolean
language sql stable security definer set search_path=pg_catalog,public,private
as $$select exists(select 1 from public.signature_envelopes e where e.id=p_envelope_id and private.contract_party_access(e.contract_id,p_actor))$$;

create trigger signature_documents_immutable before update or delete on public.signature_documents for each row execute function private.prevent_contract_immutable_change();
create trigger signature_authorities_immutable before update or delete on public.signature_signer_authorities for each row execute function private.prevent_contract_immutable_change();
create trigger signature_attempts_immutable before update or delete on public.signature_attempts for each row execute function private.prevent_contract_immutable_change();
create trigger signature_events_immutable before update or delete on public.signature_provider_events for each row execute function private.prevent_contract_immutable_change();
create trigger signature_evidence_immutable before update or delete on public.signature_evidence_packages for each row execute function private.prevent_contract_immutable_change();
create trigger signature_certificates_immutable before update or delete on public.signature_certificates for each row execute function private.prevent_contract_immutable_change();
create trigger signature_timestamps_immutable before update or delete on public.trusted_timestamps for each row execute function private.prevent_contract_immutable_change();
create trigger signature_configs_immutable before update or delete on public.signature_provider_configs for each row execute function private.prevent_contract_immutable_change();

insert into public.signature_provider_configs(provider_code,environment,version,status,supported_levels,webhook_tolerance_seconds,config_metadata)
values('MATRICIA_DEV_MOCK','DEVELOPMENT',1,'ACTIVE',array['SIMPLE']::text[],300,jsonb_build_object('deterministic',true,'external_provider',false));

create function public.create_signature_envelope(
  p_contract_id uuid,p_contract_version_id uuid,p_provider_code text,p_environment text,p_requested_level text,
  p_document_file_name text,p_document_storage_path text,p_document_sha256 text,p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions
as $$
declare a uuid:=auth.uid();c public.contracts%rowtype;v public.contract_versions%rowtype;cfg public.signature_provider_configs%rowtype;prior public.signature_envelopes%rowtype;n integer;h text;e uuid;r jsonb;
begin
  select * into c from public.contracts where id=p_contract_id;
  if a is null or not found or not private.has_org_role(c.client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a) then raise exception 'SIGNATURE_ENVELOPE_CREATE_DENIED' using errcode='42501';end if;
  select * into v from public.contract_versions where id=p_contract_version_id and contract_id=c.id;
  if not found then raise exception 'SIGNATURE_CONTRACT_VERSION_NOT_FOUND' using errcode='P0002';end if;
  if v.version<>c.current_version then raise exception 'SIGNATURE_CONTRACT_VERSION_STALE' using errcode='55000';end if;
  if p_requested_level not in('SIMPLE','ADVANCED','QUALIFIED') or p_document_sha256!~'^[0-9a-f]{64}$' or length(btrim(coalesce(p_document_file_name,'')))not between 1 and 255 or length(btrim(coalesce(p_document_storage_path,'')))not between 3 and 1000 then raise exception 'INVALID_SIGNATURE_ENVELOPE' using errcode='22023';end if;
  select * into cfg from public.signature_provider_configs where provider_code=p_provider_code and environment=p_environment and status='ACTIVE' and valid_from<=clock_timestamp() and(valid_until is null or valid_until>clock_timestamp()) order by version desc limit 1;
  if not found or not(p_requested_level=any(cfg.supported_levels)) then raise exception 'SIGNATURE_LEVEL_NOT_SUPPORTED' using errcode='23514';end if;
  h:=private.canonical_request_hash(jsonb_build_object('contract_id',c.id,'contract_version_id',v.id,'provider',cfg.provider_code,'provider_config_version',cfg.version,'requested_level',p_requested_level,'document_sha256',p_document_sha256));
  select * into prior from public.signature_envelopes where client_organization_id=c.client_organization_id and idempotency_key=p_idempotency_key;
  if found then if prior.request_hash<>h then raise exception 'SIGNATURE_ENVELOPE_IDEMPOTENCY_MISMATCH' using errcode='22000';end if;return jsonb_build_object('outcome','SIGNATURE_ENVELOPE_CREATED','envelope_id',prior.id,'envelope_version',prior.envelope_version,'replayed',true);end if;
  if exists(select 1 from public.signature_envelopes where contract_id=c.id and contract_version_id=v.id and status in('DRAFT','READY_FOR_SIGNATURE','SENT','PARTIALLY_SIGNED','SIGNED')) then raise exception 'SIGNATURE_ENVELOPE_ALREADY_ACTIVE' using errcode='55000';end if;
  select * into prior from public.signature_envelopes where contract_id=c.id order by envelope_version desc limit 1;
  n:=coalesce(prior.envelope_version,0)+1;
  insert into public.signature_envelopes(client_organization_id,contract_id,contract_version_id,provider_config_id,provider_code,envelope_version,supersedes_envelope_id,requested_level,document_set_hash,idempotency_key,request_hash,correlation_id,created_by)
  values(c.client_organization_id,c.id,v.id,cfg.id,cfg.provider_code,n,prior.id,p_requested_level,p_document_sha256,p_idempotency_key,h,p_correlation_id,a)returning id into e;
  insert into public.signature_documents(envelope_id,contract_version_id,document_type,exact_version,file_name,storage_path,sha256,sort_order)values(e,v.id,'CONTRACT',v.version,p_document_file_name,p_document_storage_path,p_document_sha256,1);
  r:=jsonb_build_object('outcome','SIGNATURE_ENVELOPE_CREATED','envelope_id',e,'envelope_version',n,'contract_version_id',v.id,'requested_level',p_requested_level,'supersedes_envelope_id',prior.id,'replayed',false);
  insert into public.signature_attempts(envelope_id,attempt_type,outcome,occurred_at,correlation_id)values(e,'CREATE','SUCCEEDED',clock_timestamp(),p_correlation_id);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(c.client_organization_id,a,'USER','signature.envelope_created','signature_envelope',e::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(c.client_organization_id,'signature_envelope',e::text,'SignatureEnvelopeCreatedV1',p_correlation_id,r,p_idempotency_key);
  return r;
end$$;

create function public.add_signature_signer(p_envelope_id uuid,p_organization_id uuid,p_signer_user_id uuid,p_signer_role text,p_email_hash text,p_signing_order integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();e public.signature_envelopes%rowtype;c public.contracts%rowtype;s public.signature_signers%rowtype;r jsonb;
begin select * into e from public.signature_envelopes where id=p_envelope_id;select * into c from public.contracts where id=e.contract_id;
 if a is null or e.id is null or not private.has_org_role(c.client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a)then raise exception'SIGNATURE_SIGNER_ADD_DENIED'using errcode='42501';end if;
 select * into s from public.signature_signers where envelope_id=e.id and idempotency_key=p_idempotency_key;if found then if s.organization_id<>p_organization_id or s.signer_user_id<>p_signer_user_id or s.signing_order<>p_signing_order then raise exception'SIGNATURE_SIGNER_IDEMPOTENCY_MISMATCH'using errcode='22000';end if;return jsonb_build_object('outcome','SIGNATURE_SIGNER_ADDED','signer_id',s.id,'replayed',true);end if;
 if e.status<>'DRAFT'or p_email_hash!~'^[0-9a-f]{64}$'or p_signer_role!~'^[A-Z][A-Z0-9_]{2,79}$'or p_signing_order<1 or p_organization_id not in(c.client_organization_id,c.provider_organization_id)or not private.is_active_org_member(p_organization_id,p_signer_user_id)then raise exception'INVALID_SIGNATURE_SIGNER'using errcode='22023';end if;
 insert into public.signature_signers(envelope_id,organization_id,signer_user_id,signer_role,email_hash,signing_order,idempotency_key)values(e.id,p_organization_id,p_signer_user_id,p_signer_role,p_email_hash,p_signing_order,p_idempotency_key)returning * into s;
 r:=jsonb_build_object('outcome','SIGNATURE_SIGNER_ADDED','envelope_id',e.id,'signer_id',s.id,'organization_id',p_organization_id,'replayed',false);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(e.client_organization_id,a,'USER','signature.signer_added','signature_signer',s.id::text,p_correlation_id,r,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(e.client_organization_id,'signature_envelope',e.id::text,'SignatureSignerAddedV1',p_correlation_id,r,p_idempotency_key);return r;end$$;

create function public.authorize_signature_signer(p_signer_id uuid,p_authority_type text,p_authority_scope text[],p_amount_ceiling_minor bigint,p_currency char(3),p_valid_from date,p_valid_until date,p_evidence_storage_path text,p_evidence_sha256 text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();s public.signature_signers%rowtype;e public.signature_envelopes%rowtype;x public.signature_signer_authorities%rowtype;r jsonb;
begin select * into s from public.signature_signers where id=p_signer_id;select * into e from public.signature_envelopes where id=s.envelope_id;
 if a is null or s.id is null or auth.jwt()->>'aal'is distinct from'aal2'or not private.has_org_role(s.organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','PROVIDER_OWNER','PROVIDER_MANAGER'],a)then raise exception'SIGNATURE_AUTHORITY_VERIFY_DENIED'using errcode='42501';end if;
 select * into x from public.signature_signer_authorities where signer_id=s.id and idempotency_key=p_idempotency_key;if found then return jsonb_build_object('outcome','SIGNATURE_AUTHORITY_RECORDED','authority_id',x.id,'replayed',true);end if;
 if e.status<>'DRAFT'or p_authority_type not in('LEGAL_REPRESENTATIVE','MANDATE','DELEGATION')or not('CONTRACT_SIGNATURE'=any(p_authority_scope))or p_evidence_sha256!~'^[0-9a-f]{64}$'or length(btrim(coalesce(p_evidence_storage_path,'')))not between 3 and 1000 or p_valid_from is null or p_valid_until<p_valid_from or ((p_amount_ceiling_minor is null)<>(p_currency is null))then raise exception'INVALID_SIGNATURE_AUTHORITY'using errcode='22023';end if;
 insert into public.signature_signer_authorities(signer_id,organization_id,authority_type,authority_scope,amount_ceiling_minor,currency,valid_from,valid_until,evidence_storage_path,evidence_sha256,verified_by,idempotency_key)values(s.id,s.organization_id,p_authority_type,p_authority_scope,p_amount_ceiling_minor,p_currency,p_valid_from,p_valid_until,p_evidence_storage_path,p_evidence_sha256,a,p_idempotency_key)returning * into x;
 r:=jsonb_build_object('outcome','SIGNATURE_AUTHORITY_RECORDED','envelope_id',e.id,'signer_id',s.id,'authority_id',x.id,'replayed',false);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(e.client_organization_id,a,'USER','signature.authority_recorded','signature_signer_authority',x.id::text,p_correlation_id,jsonb_build_object('signer_id',s.id,'authority_type',p_authority_type,'scope',p_authority_scope,'valid_until',p_valid_until),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(e.client_organization_id,'signature_envelope',e.id::text,'SignatureAuthorityRecordedV1',p_correlation_id,r,p_idempotency_key);return r;end$$;

create function public.ready_signature_envelope(p_envelope_id uuid,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();e public.signature_envelopes%rowtype;c public.contracts%rowtype;v public.contract_versions%rowtype;cfg public.signature_provider_configs%rowtype;r jsonb;
begin select * into e from public.signature_envelopes where id=p_envelope_id;select * into c from public.contracts where id=e.contract_id;
 if a is null or e.id is null or auth.jwt()->>'aal'is distinct from'aal2'or not private.has_org_role(c.client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a)then raise exception'SIGNATURE_READY_DENIED'using errcode='42501';end if;
 select * into e from public.signature_envelopes where id=p_envelope_id for update;select * into v from public.contract_versions where id=e.contract_version_id;select * into cfg from public.signature_provider_configs where id=e.provider_config_id;
 if e.status<>'DRAFT'or e.row_version<>p_expected_row_version or v.version<>c.current_version then raise exception'INVALID_SIGNATURE_READY_TRANSITION'using errcode='55000';end if;
 if not(e.requested_level=any(cfg.supported_levels))then raise exception'SIGNATURE_LEVEL_NOT_SUPPORTED'using errcode='23514';end if;
 if (select count(*) from public.signature_signers where envelope_id=e.id)<2 or exists(select 1 from public.signature_signers s where s.envelope_id=e.id and not exists(select 1 from public.signature_signer_authorities q where q.signer_id=s.id and q.organization_id=s.organization_id and q.status='ACTIVE'and q.revoked_at is null and current_date between q.valid_from and coalesce(q.valid_until,'infinity'::date)and'CONTRACT_SIGNATURE'=any(q.authority_scope)and(q.amount_ceiling_minor is null or(q.currency=v.currency and q.amount_ceiling_minor>=v.price_minor))))then raise exception'SIGNER_AUTHORITY_REQUIRED'using errcode='23514';end if;
 update public.signature_envelopes set status='READY_FOR_SIGNATURE',ready_at=clock_timestamp(),row_version=row_version+1 where id=e.id;
 r:=jsonb_build_object('outcome','SIGNATURE_ENVELOPE_READY','envelope_id',e.id,'row_version',e.row_version+1,'requested_level',e.requested_level);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(e.client_organization_id,a,'USER','signature.envelope_ready','signature_envelope',e.id::text,p_correlation_id,r,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(e.client_organization_id,'signature_envelope',e.id::text,'SignatureEnvelopeReadyV1',p_correlation_id,r,p_idempotency_key);return r;end$$;

create function public.process_verified_signature_provider_event(p_envelope_id uuid,p_provider_code text,p_provider_event_id text,p_nonce text,p_event_type text,p_signer_id uuid,p_provider_occurred_at timestamptz,p_payload_hash text,p_signature_fingerprint text,p_signature_verified boolean,p_achieved_level text,p_provider_evidence jsonb,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,auth,extensions as $$
declare e public.signature_envelopes%rowtype;cfg public.signature_provider_configs%rowtype;old public.signature_provider_events%rowtype;s public.signature_signers%rowtype;cnt integer;total integer;r jsonb;ep uuid;actions jsonb;final_hash text;event_chain text;
begin
 if coalesce(auth.role(),'')<>'service_role'then raise exception'SIGNATURE_EVENT_PROCESS_DENIED'using errcode='42501';end if;
 select * into e from public.signature_envelopes where id=p_envelope_id;select * into cfg from public.signature_provider_configs where id=e.provider_config_id;
 if e.id is null or cfg.provider_code<>p_provider_code or p_event_type not in('SENT','SIGNER_SIGNED','DECLINED','EXPIRED','FAILED','VOIDED')or p_payload_hash!~'^[0-9a-f]{64}$'or p_signature_fingerprint!~'^[0-9a-f]{64}$'or p_signature_verified is not true or abs(extract(epoch from(clock_timestamp()-p_provider_occurred_at)))>cfg.webhook_tolerance_seconds then raise exception'INVALID_VERIFIED_SIGNATURE_EVENT'using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_provider_code||':'||p_provider_event_id,0));
 select * into old from public.signature_provider_events where provider_code=p_provider_code and provider_event_id=p_provider_event_id;
 if found then if old.envelope_id<>e.id or old.nonce<>p_nonce or old.event_type<>p_event_type or old.payload_hash<>p_payload_hash or old.signature_fingerprint<>p_signature_fingerprint then raise exception'SIGNATURE_EVENT_REPLAY_MISMATCH'using errcode='22000';end if;return old.processing_result||jsonb_build_object('replayed',true);end if;
 if exists(select 1 from public.signature_provider_events where provider_code=p_provider_code and nonce=p_nonce)then raise exception'SIGNATURE_EVENT_REPLAY_MISMATCH'using errcode='22000';end if;
 select * into e from public.signature_envelopes where id=p_envelope_id for update;
 if p_event_type='SENT'then if e.status<>'READY_FOR_SIGNATURE'then raise exception'INVALID_SIGNATURE_EVENT_TRANSITION'using errcode='55000';end if;update public.signature_envelopes set status='SENT',provider_envelope_id=coalesce(nullif(p_provider_evidence->>'provider_envelope_id',''),provider_envelope_id),sent_at=p_provider_occurred_at,row_version=row_version+1 where id=e.id;r:=jsonb_build_object('outcome','SIGNATURE_ENVELOPE_SENT','envelope_id',e.id,'replayed',false);
 elsif p_event_type='SIGNER_SIGNED'then
  if e.status not in('SENT','PARTIALLY_SIGNED')or p_signer_id is null then raise exception'INVALID_SIGNATURE_EVENT_TRANSITION'using errcode='55000';end if;
  if p_achieved_level is null or not(p_achieved_level=any(cfg.supported_levels))then raise exception'SIGNATURE_LEVEL_NOT_SUPPORTED'using errcode='23514';end if;
  select * into s from public.signature_signers where id=p_signer_id and envelope_id=e.id for update;if not found then raise exception'SIGNATURE_SIGNER_NOT_FOUND'using errcode='P0002';end if;
  if s.status<>'SIGNED'then update public.signature_signers set status='SIGNED',identity_verification_level=case p_achieved_level when'QUALIFIED'then'QUALIFIED'when'ADVANCED'then'STRONG'else'BASIC'end,signed_at=p_provider_occurred_at where id=s.id;end if;
  select count(*) into cnt from public.signature_signers where envelope_id=e.id and status='SIGNED';select count(*) into total from public.signature_signers where envelope_id=e.id;
  if cnt=total then
   if p_achieved_level<>e.requested_level then raise exception'QUALIFIED_LEVEL_NOT_ACHIEVED'using errcode='23514';end if;
   update public.signature_envelopes set status='SIGNED',achieved_level=p_achieved_level,completed_at=p_provider_occurred_at,row_version=row_version+1 where id=e.id;
   insert into public.contract_signatures(contract_id,contract_version_id,organization_id,signer_user_id,signer_role,contract_hash,proof,signed_at,correlation_id)
   select e.contract_id,e.contract_version_id,x.organization_id,x.signer_user_id,x.signer_role,e.document_set_hash,jsonb_build_object('method','SIGNATURE_PROVIDER_'||p_achieved_level,'signed_at',x.signed_at,'evidence_hash',p_payload_hash),x.signed_at,p_correlation_id from public.signature_signers x where x.envelope_id=e.id on conflict(contract_version_id,organization_id)do nothing;
   update public.contracts set status='ACTIVE',row_version=row_version+1,updated_at=clock_timestamp()where id=e.contract_id and status='PENDING_SIGNATURE';
   select jsonb_agg(jsonb_build_object('signer_id',x.id,'organization_id',x.organization_id,'signer_user_id',x.signer_user_id,'role',x.signer_role,'signed_at',x.signed_at)order by x.signing_order)into actions from public.signature_signers x where x.envelope_id=e.id;
   event_chain:=private.canonical_request_hash(jsonb_build_object('previous_events',(select coalesce(jsonb_agg(jsonb_build_object('provider_event_id',q.provider_event_id,'payload_hash',q.payload_hash)order by q.id),'[]')from public.signature_provider_events q where q.envelope_id=e.id),'current_event_id',p_provider_event_id,'current_payload_hash',p_payload_hash));
   final_hash:=private.canonical_request_hash(jsonb_build_object('envelope_id',e.id,'contract_version_id',e.contract_version_id,'pdf_sha256',e.document_set_hash,'signers',actions,'provider',p_provider_code,'level',p_achieved_level,'event_chain_hash',event_chain));
   insert into public.signature_evidence_packages(envelope_id,contract_version_id,pdf_sha256,signer_actions_snapshot,consent_snapshot,provider_snapshot,event_chain_hash,verification_result,final_hash,correlation_id)values(e.id,e.contract_version_id,e.document_set_hash,actions,coalesce(p_provider_evidence->'consent','{}'),jsonb_build_object('provider_code',p_provider_code,'provider_config_version',cfg.version,'achieved_level',p_achieved_level,'provider_envelope_id',e.provider_envelope_id),event_chain,case when p_achieved_level='SIMPLE'then'VERIFIED_WITH_LIMITATIONS'else'VERIFIED'end,final_hash,p_correlation_id)returning id into ep;
   if p_provider_evidence?'certificate_fingerprint'then insert into public.signature_certificates(evidence_package_id,signer_id,provider_certificate_id,certificate_fingerprint,subject_hash,issuer_name,valid_from,valid_until,qualification_status,verification_status)values(ep,s.id,nullif(p_provider_evidence->>'certificate_id',''),p_provider_evidence->>'certificate_fingerprint',p_provider_evidence->>'certificate_subject_hash',nullif(p_provider_evidence->>'certificate_issuer',''),nullif(p_provider_evidence->>'certificate_valid_from','')::timestamptz,nullif(p_provider_evidence->>'certificate_valid_until','')::timestamptz,case when p_achieved_level='QUALIFIED'then'QUALIFIED'else'NOT_QUALIFIED'end,'VERIFIED');end if;
   if p_provider_evidence?'timestamp_token_hash'then insert into public.trusted_timestamps(evidence_package_id,signer_id,authority_name,token_hash,timestamped_at,verification_status)values(ep,s.id,coalesce(nullif(p_provider_evidence->>'timestamp_authority',''),'PROVIDER_TIMESTAMP'),p_provider_evidence->>'timestamp_token_hash',p_provider_occurred_at,'VERIFIED');end if;
   r:=jsonb_build_object('outcome','SIGNATURE_ENVELOPE_SIGNED','envelope_id',e.id,'evidence_package_id',ep,'final_hash',final_hash,'achieved_level',p_achieved_level,'replayed',false);
  else update public.signature_envelopes set status='PARTIALLY_SIGNED',row_version=row_version+1 where id=e.id;r:=jsonb_build_object('outcome','SIGNATURE_ENVELOPE_PARTIALLY_SIGNED','envelope_id',e.id,'signer_id',s.id,'signature_count',cnt,'replayed',false);end if;
 else
  if e.status not in('READY_FOR_SIGNATURE','SENT','PARTIALLY_SIGNED')then raise exception'INVALID_SIGNATURE_EVENT_TRANSITION'using errcode='55000';end if;
  update public.signature_envelopes set status=p_event_type,completed_at=p_provider_occurred_at,row_version=row_version+1 where id=e.id;
  r:=jsonb_build_object('outcome','SIGNATURE_ENVELOPE_'||p_event_type,'envelope_id',e.id,'replayed',false);
 end if;
 insert into public.signature_provider_events(envelope_id,provider_code,provider_event_id,nonce,event_type,provider_occurred_at,payload_hash,signature_fingerprint,signature_verified,processing_result,correlation_id)values(e.id,p_provider_code,p_provider_event_id,p_nonce,p_event_type,p_provider_occurred_at,p_payload_hash,p_signature_fingerprint,true,r,p_correlation_id);
 insert into public.signature_attempts(envelope_id,signer_id,attempt_type,outcome,provider_request_id,occurred_at,correlation_id,metadata)values(e.id,p_signer_id,case p_event_type when'SENT'then'SEND'when'SIGNER_SIGNED'then'SIGN'when'DECLINED'then'DECLINE'when'VOIDED'then'VOID'else'PROVIDER_CALLBACK'end,'SUCCEEDED',p_provider_event_id,p_provider_occurred_at,p_correlation_id,jsonb_build_object('event_type',p_event_type,'payload_hash',p_payload_hash));
 insert into public.audit_events(organization_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(e.client_organization_id,'SERVICE','signature.provider_event_processed','signature_envelope',e.id::text,p_correlation_id,r||jsonb_build_object('provider_event_id',p_provider_event_id,'event_type',p_event_type),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(e.client_organization_id,'signature_envelope',e.id::text,case when r->>'outcome'='SIGNATURE_ENVELOPE_SIGNED'then'SignatureEnvelopeSignedV1'else'SignatureEnvelopeTransitionedV1'end,p_correlation_id,r,p_provider_code||':'||p_provider_event_id);return r;
end$$;

create function public.run_mock_signature_provider(p_envelope_id uuid,p_action text,p_signer_id uuid,p_request_id text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,auth,extensions as $$
declare e public.signature_envelopes%rowtype;h text;
begin if coalesce(auth.role(),'')<>'service_role'then raise exception'SIGNATURE_MOCK_DENIED'using errcode='42501';end if;select * into e from public.signature_envelopes where id=p_envelope_id;if e.provider_code<>'MATRICIA_DEV_MOCK'or p_action not in('SENT','SIGNER_SIGNED','DECLINED','EXPIRED','FAILED','VOIDED')then raise exception'SIGNATURE_MOCK_DEVELOPMENT_ONLY'using errcode='42501';end if;h:=private.canonical_request_hash(jsonb_build_object('envelope_id',e.id,'action',p_action,'signer_id',p_signer_id,'request_id',p_request_id));return public.process_verified_signature_provider_event(e.id,e.provider_code,'mock-event:'||p_request_id,'mock-nonce:'||p_request_id,p_action,p_signer_id,clock_timestamp(),h,repeat('a',64),true,case when p_action='SIGNER_SIGNED'then'SIMPLE'else null end,jsonb_build_object('provider_envelope_id','mock-envelope:'||e.id,'consent',jsonb_build_object('method','DEVELOPMENT_MOCK')),p_correlation_id);end$$;

alter table public.signature_provider_configs enable row level security;alter table public.signature_envelopes enable row level security;alter table public.signature_documents enable row level security;alter table public.signature_signers enable row level security;alter table public.signature_signer_authorities enable row level security;alter table public.signature_attempts enable row level security;alter table public.signature_provider_events enable row level security;alter table public.signature_evidence_packages enable row level security;alter table public.signature_certificates enable row level security;alter table public.trusted_timestamps enable row level security;
create policy signature_configs_deny_tenant_read on public.signature_provider_configs for select to authenticated using(false);
create policy signature_envelopes_party_read on public.signature_envelopes for select to authenticated using(private.signature_envelope_access(id));
create policy signature_documents_party_read on public.signature_documents for select to authenticated using(private.signature_envelope_access(envelope_id));
create policy signature_signers_party_read on public.signature_signers for select to authenticated using(private.signature_envelope_access(envelope_id));
create policy signature_authorities_party_read on public.signature_signer_authorities for select to authenticated using(private.signature_envelope_access((select s.envelope_id from public.signature_signers s where s.id=signer_id)));
create policy signature_attempts_party_read on public.signature_attempts for select to authenticated using(private.signature_envelope_access(envelope_id));
create policy signature_events_party_read on public.signature_provider_events for select to authenticated using(private.signature_envelope_access(envelope_id));
create policy signature_evidence_party_read on public.signature_evidence_packages for select to authenticated using(private.signature_envelope_access(envelope_id));
create policy signature_certificates_party_read on public.signature_certificates for select to authenticated using(private.signature_envelope_access((select p.envelope_id from public.signature_evidence_packages p where p.id=evidence_package_id)));
create policy signature_timestamps_party_read on public.trusted_timestamps for select to authenticated using(private.signature_envelope_access((select p.envelope_id from public.signature_evidence_packages p where p.id=evidence_package_id)));

revoke all on public.signature_provider_configs,public.signature_envelopes,public.signature_documents,public.signature_signers,public.signature_signer_authorities,public.signature_attempts,public.signature_provider_events,public.signature_evidence_packages,public.signature_certificates,public.trusted_timestamps from public,anon,authenticated,service_role;
grant select on public.signature_envelopes,public.signature_documents,public.signature_signers,public.signature_signer_authorities,public.signature_attempts,public.signature_provider_events,public.signature_evidence_packages,public.signature_certificates,public.trusted_timestamps to authenticated;
revoke all on function private.signature_envelope_access(uuid,uuid)from public,anon,authenticated,service_role;grant execute on function private.signature_envelope_access(uuid,uuid)to authenticated;
revoke all on function public.create_signature_envelope(uuid,uuid,text,text,text,text,text,text,text,uuid),public.add_signature_signer(uuid,uuid,uuid,text,text,integer,text,uuid),public.authorize_signature_signer(uuid,text,text[],bigint,character,date,date,text,text,text,uuid),public.ready_signature_envelope(uuid,integer,text,uuid),public.process_verified_signature_provider_event(uuid,text,text,text,text,uuid,timestamptz,text,text,boolean,text,jsonb,uuid),public.run_mock_signature_provider(uuid,text,uuid,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.create_signature_envelope(uuid,uuid,text,text,text,text,text,text,text,uuid),public.add_signature_signer(uuid,uuid,uuid,text,text,integer,text,uuid),public.authorize_signature_signer(uuid,text,text[],bigint,character,date,date,text,text,text,uuid),public.ready_signature_envelope(uuid,integer,text,uuid)to authenticated;
grant execute on function public.process_verified_signature_provider_event(uuid,text,text,text,text,uuid,timestamptz,text,text,boolean,text,jsonb,uuid),public.run_mock_signature_provider(uuid,text,uuid,text,uuid)to service_role;

create index signature_envelopes_contract_status_idx on public.signature_envelopes(contract_id,status,created_at desc);
create index signature_envelopes_client_status_idx on public.signature_envelopes(client_organization_id,status,created_at desc);
create index signature_signers_envelope_status_idx on public.signature_signers(envelope_id,status,signing_order);
create index signature_authorities_signer_active_idx on public.signature_signer_authorities(signer_id,status,valid_until);
create index signature_attempts_envelope_time_idx on public.signature_attempts(envelope_id,occurred_at desc);
create index signature_events_envelope_time_idx on public.signature_provider_events(envelope_id,received_at desc);
