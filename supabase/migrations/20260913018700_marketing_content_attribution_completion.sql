-- MARKETING-001..006 and 008 additive completion: administrable brand truth,
-- deterministic content persistence, CTA ingestion and filterable KPI facts.

create table public.marketing_brand_evidence_review_versions(
 id uuid primary key default extensions.gen_random_uuid(),organization_id uuid not null references public.organizations(id)on delete restrict,
 brand_kit_version_id uuid not null references public.brand_kit_versions(id)on delete restrict,evidence_type text not null check(evidence_type in('CLAIM','CERTIFICATION')),
 evidence_key text not null check(length(btrim(evidence_key))between 2 and 120),version integer not null check(version>0),decision text not null check(decision in('VERIFIED','REJECTED','REVOKED')),
 evidence_hash text not null check(evidence_hash~'^[0-9a-f]{64}$'),valid_from timestamptz not null default clock_timestamp(),valid_until timestamptz,
 reason text not null check(length(btrim(reason))between 3 and 1000),supersedes_id uuid references public.marketing_brand_evidence_review_versions(id)on delete restrict,
 reviewed_by uuid not null references auth.users(id),reviewed_at timestamptz not null default clock_timestamp(),unique(brand_kit_version_id,evidence_type,evidence_key,version),
 check(valid_until is null or valid_until>valid_from),check((version=1 and supersedes_id is null)or(version>1 and supersedes_id is not null))
);
alter table public.marketing_brand_evidence_review_versions enable row level security;
revoke all on public.marketing_brand_evidence_review_versions from public,anon,authenticated,service_role;
grant select on public.marketing_brand_evidence_review_versions to authenticated;
create policy marketing_brand_evidence_review_scoped_read on public.marketing_brand_evidence_review_versions for select to authenticated using(private.marketing_manage_access(organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create trigger marketing_brand_evidence_review_immutable before update or delete on public.marketing_brand_evidence_review_versions for each row execute function private.prevent_marketing_v1_history_change();

create function public.review_marketing_brand_evidence_v1(p_brand_kit_version_id uuid,p_evidence_type text,p_evidence_key text,p_decision text,p_evidence_hash text,p_valid_until timestamptz,p_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();bv public.brand_kit_versions%rowtype;bk public.brand_kits%rowtype;proposal jsonb;prior public.marketing_brand_evidence_review_versions%rowtype;next_version integer;record_id uuid;h text;cached jsonb;r jsonb;ready boolean;
begin
 select v.*into bv from public.brand_kit_versions v where v.id=p_brand_kit_version_id;
 select*into bk from public.brand_kits where id=bv.brand_kit_id for update;
 if a is null or bv.id is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],a)or auth.jwt()->>'aal'is distinct from'aal2'then raise exception'MARKETING_BRAND_EVIDENCE_REVIEW_DENIED'using errcode='42501';end if;
 if bk.current_version_id is distinct from bv.id then raise exception'MARKETING_BRAND_EVIDENCE_VERSION_STALE'using errcode='40001';end if;
 if p_evidence_type not in('CLAIM','CERTIFICATION')or p_decision not in('VERIFIED','REJECTED','REVOKED')or p_evidence_hash!~'^[0-9a-f]{64}$'or length(btrim(coalesce(p_reason,'')))not between 3 and 1000 or p_valid_until<=clock_timestamp()then raise exception'INVALID_MARKETING_BRAND_EVIDENCE_REVIEW'using errcode='22023';end if;
 select value into proposal from jsonb_array_elements(case when p_evidence_type='CLAIM'then bv.claims else bv.certifications end)where value->>'key'=p_evidence_key and value->>'evidenceHash'=p_evidence_hash;
 if proposal is null then raise exception'MARKETING_BRAND_EVIDENCE_NOT_SUBMITTED'using errcode='P0002';end if;
 h:=private.canonical_request_hash(jsonb_build_object('brand_version',bv.id,'type',p_evidence_type,'key',p_evidence_key,'decision',p_decision,'evidence_hash',p_evidence_hash,'valid_until',p_valid_until,'reason',p_reason));cached:=private.begin_contract_command(bk.organization_id,'marketing.brand_evidence.review.'||p_evidence_type||'.'||p_evidence_key,p_idempotency_key,h,a);if cached is not null then return cached;end if;
 perform pg_advisory_xact_lock(hashtextextended('marketing-brand-evidence:'||bv.id::text||':'||p_evidence_type||':'||p_evidence_key,0));
 select*into prior from public.marketing_brand_evidence_review_versions where brand_kit_version_id=bv.id and evidence_type=p_evidence_type and evidence_key=p_evidence_key order by version desc limit 1;
 if p_decision='REVOKED'and(coalesce(prior.decision,'')<>'VERIFIED'or(prior.valid_until is not null and prior.valid_until<=clock_timestamp()))then raise exception'INVALID_MARKETING_BRAND_EVIDENCE_REVOCATION'using errcode='55000';end if;
 next_version:=coalesce(prior.version,0)+1;
 insert into public.marketing_brand_evidence_review_versions(organization_id,brand_kit_version_id,evidence_type,evidence_key,version,decision,evidence_hash,valid_until,reason,supersedes_id,reviewed_by)values(bk.organization_id,bv.id,p_evidence_type,p_evidence_key,next_version,p_decision,p_evidence_hash,case when p_decision='VERIFIED'then p_valid_until end,btrim(p_reason),prior.id,a)returning id into record_id;
 select not exists(select 1 from jsonb_array_elements(bv.claims)submitted where not exists(select 1 from public.marketing_brand_evidence_review_versions review where review.brand_kit_version_id=bv.id and review.evidence_type='CLAIM'and review.evidence_key=submitted->>'key'and review.evidence_hash=submitted->>'evidenceHash'and review.decision='VERIFIED'and(review.valid_until is null or review.valid_until>clock_timestamp())and review.version=(select max(latest.version)from public.marketing_brand_evidence_review_versions latest where latest.brand_kit_version_id=bv.id and latest.evidence_type='CLAIM'and latest.evidence_key=submitted->>'key')))and not exists(select 1 from jsonb_array_elements(bv.certifications)submitted where not exists(select 1 from public.marketing_brand_evidence_review_versions review where review.brand_kit_version_id=bv.id and review.evidence_type='CERTIFICATION'and review.evidence_key=submitted->>'key'and review.evidence_hash=submitted->>'evidenceHash'and review.decision='VERIFIED'and(review.valid_until is null or review.valid_until>clock_timestamp())and review.version=(select max(latest.version)from public.marketing_brand_evidence_review_versions latest where latest.brand_kit_version_id=bv.id and latest.evidence_type='CERTIFICATION'and latest.evidence_key=submitted->>'key')))into ready;
 update public.brand_kits set status=case when ready then'READY'else'DRAFT'end,row_version=row_version+1 where id=bk.id and current_version_id=bv.id;
 if not ready then update public.social_publication_jobs set status='SKIPPED'where organization_id=bk.organization_id and status='QUEUED';end if;
 r:=jsonb_build_object('outcome','MARKETING_BRAND_EVIDENCE_'||p_decision,'review_id',record_id,'brand_kit_version_id',bv.id,'evidence_type',p_evidence_type,'evidence_key',p_evidence_key,'version',next_version,'brand_kit_ready',ready);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(bk.organization_id,a,'USER','marketing.brand_evidence.'||lower(p_decision),'marketing_brand_evidence_review',record_id::text,p_correlation_id,r,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(bk.organization_id,'brand_kit',bk.id::text,'MarketingBrandEvidenceReviewedV1',p_correlation_id,r,p_idempotency_key);
 perform private.finish_contract_command(bk.organization_id,'marketing.brand_evidence.review.'||p_evidence_type||'.'||p_evidence_key,p_idempotency_key,r);return r;
end$$;

create function public.save_marketing_brand_kit_v1(
  p_organization_id uuid,p_payload jsonb,p_claims jsonb,p_certifications jsonb,p_change_reason text,
  p_mark_ready boolean,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();k public.brand_kits%rowtype;v integer;x uuid;h text;cached jsonb;r jsonb;legal text;trade text;payload jsonb;
begin
  if a is null or not private.marketing_manage_access(p_organization_id,a)then raise exception'MARKETING_BRAND_KIT_DENIED'using errcode='42501';end if;
  select legal_name,display_name into legal,trade from public.organizations where id=p_organization_id;
  payload:=jsonb_build_object('primary_colors',jsonb_build_array('#123B5D'),'tone',jsonb_build_array('PROFESSIONAL'),'languages',jsonb_build_array('FR','AR'),'primary_cta','DIAGNOSTIC','tracked_url','https://matricia.ma/diagnostic','allowed_url_hosts',jsonb_build_array('matricia.ma'),'logo_assets','[]'::jsonb,'asset_restrictions','[]'::jsonb,'required_mentions','[]'::jsonb,'forbidden_terms','[]'::jsonb,'approved_hashtags',jsonb_build_array('#Matricia'))||(coalesce(p_payload,'{}'::jsonb)-'legal_name'-'trade_name')||jsonb_build_object('legal_name',legal,'trade_name',trade);
  if jsonb_typeof(payload)<>'object'or not(payload?&array['legal_name','trade_name','primary_colors','tone','languages','primary_cta','tracked_url','allowed_url_hosts','logo_assets','asset_restrictions','required_mentions','forbidden_terms','approved_hashtags'])or jsonb_typeof(payload->'allowed_url_hosts')<>'array'or jsonb_typeof(payload->'logo_assets')<>'array'or jsonb_typeof(payload->'asset_restrictions')<>'array'or jsonb_typeof(p_claims)<>'array'or jsonb_typeof(p_certifications)<>'array'or length(btrim(coalesce(p_change_reason,'')))not between 3 and 500 or payload->>'tracked_url'!~'^https://[^/@:]+(?::[0-9]+)?(?:/|$)'or(select count(*)<>count(distinct c->>'key')from jsonb_array_elements(p_claims)c)or(select count(*)<>count(distinct c->>'key')from jsonb_array_elements(p_certifications)c)or exists(select 1 from jsonb_array_elements(p_claims)c where not(c?&array['key','textFr','textAr','evidenceReference','evidenceHash'])or length(btrim(c->>'key'))not between 2 and 120 or c->>'evidenceHash'!~'^[0-9a-f]{64}$'or c ?| array['status','decision','approved','reviewedBy'])or exists(select 1 from jsonb_array_elements(p_certifications)c where not(c?&array['key','name','evidenceReference','evidenceHash'])or length(btrim(c->>'key'))not between 2 and 120 or c->>'evidenceHash'!~'^[0-9a-f]{64}$'or c ?| array['status','decision','approved','reviewedBy'])then raise exception'INVALID_MARKETING_BRAND_KIT'using errcode='22023';end if;
  h:=private.canonical_request_hash(jsonb_build_object('organization',p_organization_id,'payload',payload,'claims',p_claims,'certifications',p_certifications,'reason',p_change_reason,'ready',p_mark_ready));
  cached:=private.begin_contract_command(p_organization_id,'marketing.brand_kit.save',p_idempotency_key,h,a);if cached is not null then return cached;end if;
  select*into k from public.brand_kits where organization_id=p_organization_id for update;
  if not found then insert into public.brand_kits(organization_id,status,created_by)values(p_organization_id,'DRAFT',a)returning*into k;end if;
  select coalesce(max(version),0)+1 into v from public.brand_kit_versions where brand_kit_id=k.id;
  insert into public.brand_kit_versions(brand_kit_id,version,payload,claims,certifications,content_hash,change_reason,created_by)
  values(k.id,v,payload,p_claims,p_certifications,encode(extensions.digest(payload::text||p_claims::text||p_certifications::text,'sha256'),'hex'),btrim(p_change_reason),a)returning id into x;
  update public.brand_kits set current_version_id=x,status='DRAFT',row_version=row_version+1 where id=k.id;
  r:=jsonb_build_object('outcome','MARKETING_BRAND_KIT_SAVED','brand_kit_id',k.id,'brand_kit_version_id',x,'version',v,'status','DRAFT','central_review_requested',p_mark_ready);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,a,'USER','marketing.brand_kit.saved','brand_kit',k.id::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_organization_id,'brand_kit',k.id::text,'MarketingBrandKitVersionSavedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_contract_command(p_organization_id,'marketing.brand_kit.save',p_idempotency_key,r);return r;
exception when invalid_datetime_format then raise exception'INVALID_MARKETING_BRAND_KIT'using errcode='22023';end$$;

create function public.initialize_standard_marketing_templates_v1(p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();key text;t uuid;v uuid;n integer:=0;structure jsonb;h text;cached jsonb;r jsonb;
begin
  if a is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],a)then raise exception'MARKETING_TEMPLATE_ADMIN_DENIED'using errcode='42501';end if;
  h:=private.canonical_request_hash(jsonb_build_object('templates',array['PROBLEM_SOLUTION','EXPERT_TIP','PROVIDER_INTRO','BEFORE_AFTER','SERVICE_OF_MONTH','SUCCESS_CASE'],'version',1));cached:=private.begin_marketing_worker_command('marketing.templates.initialize',p_idempotency_key,h);if cached is not null then return cached;end if;
  foreach key in array array['PROBLEM_SOLUTION','EXPERT_TIP','PROVIDER_INTRO','BEFORE_AFTER','SERVICE_OF_MONTH','SUCCESS_CASE']loop
    select id into t from public.marketing_templates where template_key=key;
    if t is null then
      insert into public.marketing_templates(template_key,status,created_by)values(key,'DRAFT',a)returning id into t;
      structure:=jsonb_build_object('hook',key||':HOOK:{service}','body',key||':BODY:{value_proposition}','target_characters',jsonb_build_object('LINKEDIN',1300,'FACEBOOK',900,'REEL',500),'required_media',case when key in('BEFORE_AFTER','SUCCESS_CASE')then jsonb_build_array('EVIDENCE_MEDIA')else'[]'::jsonb end,'allowed_ctas',jsonb_build_array('DIAGNOSTIC','RFQ','SERVICE'),'forbidden_claims',jsonb_build_array('GUARANTEED_RESULT','UNSOURCED_NUMBER'),'translation_rules',jsonb_build_object('FR','NATIVE','AR','NATIVE_RTL'),'repetition_rules',jsonb_build_object('same_service_max',2));
      insert into public.marketing_template_versions(template_id,version,structure,frequency_max_weekly,content_hash,created_by)values(t,1,structure,2,encode(extensions.digest(structure::text,'sha256'),'hex'),a)returning id into v;
      update public.marketing_templates set current_version_id=v,status='ACTIVE'where id=t;n:=n+1;
    end if;t:=null;
  end loop;
  r:=jsonb_build_object('outcome','MARKETING_STANDARD_TEMPLATES_READY','created_count',n,'template_count',6);
  insert into public.audit_events(actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(a,'USER','marketing.templates.initialized','marketing_template_catalog','STANDARD_V1',p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values('marketing_template_catalog','STANDARD_V1','MarketingStandardTemplatesInitializedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_marketing_worker_command('marketing.templates.initialize',p_idempotency_key,r);return r;end$$;

create table private.marketing_content_generation_claims(
 campaign_id uuid primary key references public.marketing_campaigns(id)on delete cascade,
 worker_id uuid not null,lease_token uuid not null,leased_until timestamptz not null,
 provider_idempotency_key text not null check(length(provider_idempotency_key)between 8 and 200),
 status text not null check(status in('CLAIMED','FAILED','COMPLETED','DEAD_LETTER')),attempt_count integer not null default 1 check(attempt_count between 1 and 5),
 next_attempt_at timestamptz not null default clock_timestamp(),last_error_code text,row_version integer not null default 1 check(row_version>0),
 updated_at timestamptz not null default clock_timestamp()
);
alter table private.marketing_content_generation_claims enable row level security;
revoke all on private.marketing_content_generation_claims from public,anon,authenticated,service_role;

create table private.marketing_cta_signing_keys(
 id uuid primary key default extensions.gen_random_uuid(),secret bytea not null check(octet_length(secret)=32),status text not null check(status in('ACTIVE','RETIRED')),created_at timestamptz not null default clock_timestamp(),retired_at timestamptz,
 check((status='ACTIVE')=(retired_at is null))
);
create unique index marketing_cta_one_active_signing_key on private.marketing_cta_signing_keys(status)where status='ACTIVE';
insert into private.marketing_cta_signing_keys(secret,status)values(extensions.gen_random_bytes(32),'ACTIVE');

create table private.marketing_cta_tokens(
 token_hash text primary key check(token_hash~'^[0-9a-f]{64}$'),organization_id uuid not null references public.organizations(id)on delete restrict,
 campaign_id uuid not null references public.marketing_campaigns(id)on delete restrict,content_id uuid not null references public.marketing_content(id)on delete restrict,
 service_id uuid not null references public.catalog_services(id)on delete restrict,destination_url text not null check(destination_url~'^https://'),active boolean not null default true,
 signing_key_id uuid not null references private.marketing_cta_signing_keys(id)on delete restrict,token_nonce text not null check(token_nonce~'^[0-9a-f]{64}$'),
 created_at timestamptz not null default clock_timestamp(),expires_at timestamptz not null default(clock_timestamp()+interval'90 days'),check(expires_at<=created_at+interval'90 days')
);
create table private.marketing_cta_visits(id bigint generated always as identity primary key,token_hash text not null references private.marketing_cta_tokens(token_hash)on delete restrict,visitor_hash text not null check(visitor_hash~'^[0-9a-f]{64}$'),idempotency_key text not null,occurred_at timestamptz not null default clock_timestamp(),unique(token_hash,idempotency_key));
alter table private.marketing_cta_tokens enable row level security;alter table private.marketing_cta_visits enable row level security;
revoke all on private.marketing_cta_signing_keys,private.marketing_cta_tokens,private.marketing_cta_visits from public,anon,authenticated,service_role;

create function public.resolve_marketing_cta_v1(p_token text,p_visitor_hash text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare t private.marketing_cta_tokens%rowtype;r jsonb;presented_signature text;expected_signature text;
begin
 if auth.role()is distinct from'service_role'then raise exception'MARKETING_CTA_RESOLVE_DENIED'using errcode='42501';end if;
 if p_token!~'^[0-9a-f]{128}$'or p_visitor_hash!~'^[0-9a-f]{64}$'or length(p_idempotency_key)not between 8 and 200 then raise exception'INVALID_MARKETING_CTA'using errcode='22023';end if;
 select*into t from private.marketing_cta_tokens where token_hash=encode(extensions.digest(p_token,'sha256'),'hex')and active and expires_at>clock_timestamp()for update;
 if not found then raise exception'MARKETING_CTA_NOT_FOUND'using errcode='P0002';end if;
 presented_signature:=right(p_token,64);
 select encode(extensions.hmac(convert_to(t.token_nonce||':'||t.organization_id::text||':'||t.campaign_id::text||':'||t.content_id::text||':'||t.service_id::text||':'||extract(epoch from t.expires_at)::bigint::text,'UTF8'),k.secret,'sha256'),'hex')into expected_signature from private.marketing_cta_signing_keys k where k.id=t.signing_key_id;
 if expected_signature is null or presented_signature<>expected_signature then raise exception'MARKETING_CTA_NOT_FOUND'using errcode='P0002';end if;
 if(select count(*)from private.marketing_cta_visits where token_hash=t.token_hash and visitor_hash=p_visitor_hash and occurred_at>clock_timestamp()-interval'1 hour')>=30 then raise exception'MARKETING_CTA_RATE_LIMITED'using errcode='P0001';end if;
 insert into private.marketing_cta_visits(token_hash,visitor_hash,idempotency_key)values(t.token_hash,p_visitor_hash,p_idempotency_key)on conflict(token_hash,idempotency_key)do nothing;
 insert into public.marketing_metric_events(organization_id,campaign_id,metric,quantity,source_event_id,occurred_at)values(t.organization_id,t.campaign_id,'CLICK',1,'cta:'||p_idempotency_key,clock_timestamp())on conflict(campaign_id,metric,source_event_id)do nothing;
 r:=jsonb_build_object('outcome','MARKETING_CTA_RESOLVED','organization_id',t.organization_id,'campaign_id',t.campaign_id,'content_id',t.content_id,'service_id',t.service_id,'destination_url',t.destination_url);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(t.organization_id,null,'SERVICE','marketing.cta.resolved','marketing_content',t.content_id::text,p_correlation_id,r-'destination_url',repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(t.organization_id,'marketing_content',t.content_id::text,'MarketingCtaClickedV1',p_correlation_id,r-'destination_url',p_idempotency_key)on conflict do nothing;
 return r;
end$$;
revoke all on function public.resolve_marketing_cta_v1(text,text,text,uuid)from public,anon,authenticated;
grant execute on function public.resolve_marketing_cta_v1(text,text,text,uuid)to service_role;

create function private.format_marketing_minor_amount_v1(p_amount bigint,p_currency text,p_language text)returns text
language plpgsql immutable set search_path=pg_catalog as $$
declare negative boolean:=p_amount<0;absolute_amount bigint:=case when p_amount<0 then-p_amount else p_amount end;whole text;fraction text;grouped text:='';separator text;digits text;
begin
 if p_currency!~'^[A-Z]{3}$'or p_language not in('FR','AR')then raise exception'INVALID_MARKETING_AMOUNT_FORMAT'using errcode='22023';end if;
 whole:=(absolute_amount/100)::text;fraction:=lpad((absolute_amount%100)::text,2,'0');separator:=case when p_language='AR'then'٬'else' 'end;
 while length(whole)>3 loop grouped:=separator||right(whole,3)||grouped;whole:=left(whole,length(whole)-3);end loop;grouped:=whole||grouped;
 if p_language='AR'then digits:=translate(grouped||'٫'||fraction,'0123456789','٠١٢٣٤٥٦٧٨٩');else digits:=grouped||','||fraction;end if;
 return(case when negative then'−'else''end)||digits||' '||p_currency;
end$$;
revoke all on function private.format_marketing_minor_amount_v1(bigint,text,text)from public,anon,authenticated,service_role;

create function public.claim_next_marketing_content_generation_v1(p_worker_id uuid,p_lease_seconds integer default 120)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare c public.marketing_campaigns%rowtype;service public.catalog_service_versions%rowtype;payload jsonb;approved_claims jsonb;template_key text;token uuid;provider_key text;offer jsonb:='{}'::jsonb;claim_version integer;
begin
 if auth.role()is distinct from'service_role'then raise exception'MARKETING_CONTENT_WORKER_DENIED'using errcode='42501';end if;
 if p_worker_id is null or p_lease_seconds not between 30 and 900 then raise exception'INVALID_MARKETING_CONTENT_CLAIM'using errcode='22023';end if;
 select campaign.* into c from public.marketing_campaigns campaign
 join public.brand_kit_versions bv on bv.id=campaign.brand_kit_version_id
 join public.brand_kits bk on bk.current_version_id=bv.id and bk.organization_id=campaign.organization_id and bk.status='READY'
 where campaign.status in('DRAFT','GENERATED')and nullif(campaign.source_snapshot->>'service_id','')is not null
 and not exists(select 1 from private.marketing_content_generation_claims claim where claim.campaign_id=campaign.id and(claim.status in('COMPLETED','DEAD_LETTER')or claim.leased_until>clock_timestamp()or claim.next_attempt_at>clock_timestamp()))
 order by campaign.created_at,campaign.id for update of campaign skip locked limit 1;
 if c.id is null then return jsonb_build_object('outcome','NO_JOB');end if;
 select version.* into service from public.catalog_services catalog join public.catalog_service_versions version on version.id=catalog.current_published_version_id
 where catalog.id=(c.source_snapshot->>'service_id')::uuid and catalog.library_id=(c.source_snapshot->>'library_id')::uuid and catalog.status='PUBLISHED';
 if service.id is null then return jsonb_build_object('outcome','NO_JOB');end if;
 select bv.payload into payload from public.brand_kit_versions bv where bv.id=c.brand_kit_version_id;
 select coalesce(jsonb_agg(jsonb_build_object('id',review.id,'key',review.evidence_key,'textFr',proposal->>'textFr','textAr',proposal->>'textAr','evidenceHash',review.evidence_hash)order by review.evidence_key),'[]'::jsonb)into approved_claims from public.marketing_brand_evidence_review_versions review join public.brand_kit_versions version on version.id=review.brand_kit_version_id cross join lateral(select value proposal from jsonb_array_elements(version.claims)value where value->>'key'=review.evidence_key and value->>'evidenceHash'=review.evidence_hash limit 1)submitted where review.brand_kit_version_id=c.brand_kit_version_id and review.evidence_type='CLAIM'and review.decision='VERIFIED'and(review.valid_until is null or review.valid_until>clock_timestamp())and review.version=(select max(latest.version)from public.marketing_brand_evidence_review_versions latest where latest.brand_kit_version_id=review.brand_kit_version_id and latest.evidence_type=review.evidence_type and latest.evidence_key=review.evidence_key);
 select t.template_key into template_key from public.marketing_templates t where t.status='ACTIVE'and t.template_key=coalesce(nullif(c.source_snapshot->>'template_key',''),'PROBLEM_SOLUTION');
 if template_key is null then return jsonb_build_object('outcome','NO_JOB');end if;
 if nullif(c.source_snapshot->>'quote_version_id','')is not null then select jsonb_build_object('offer',jsonb_build_object('quoteVersionId',qv.id,'totalMinor',qv.total_minor::text,'currency',qv.currency,'displayAmount',private.format_marketing_minor_amount_v1(qv.total_minor,qv.currency,case when coalesce(c.source_snapshot->>'language','FR')='AR'then'AR'else'FR'end)))into offer from public.quote_versions qv join public.quotes q on q.id=qv.quote_id and q.selected_version_id=qv.id and q.status='SELECTED'join public.rfqs r on r.id=q.rfq_id join public.service_requests sr on sr.id=r.request_id where qv.id=(c.source_snapshot->>'quote_version_id')::uuid and sr.service_id=service.service_id;if offer is null then return jsonb_build_object('outcome','NO_JOB');end if;end if;
 token:=extensions.gen_random_uuid();provider_key:='marketing-content:'||c.id::text;
 insert into private.marketing_content_generation_claims(campaign_id,worker_id,lease_token,leased_until,provider_idempotency_key,status)
 values(c.id,p_worker_id,token,clock_timestamp()+make_interval(secs=>p_lease_seconds),provider_key,'CLAIMED')
 on conflict(campaign_id)do update set worker_id=excluded.worker_id,lease_token=excluded.lease_token,leased_until=excluded.leased_until,next_attempt_at=clock_timestamp(),status='CLAIMED',attempt_count=private.marketing_content_generation_claims.attempt_count+1,row_version=private.marketing_content_generation_claims.row_version+1,updated_at=clock_timestamp()
 where private.marketing_content_generation_claims.status in('CLAIMED','FAILED')and private.marketing_content_generation_claims.leased_until<=clock_timestamp()and private.marketing_content_generation_claims.next_attempt_at<=clock_timestamp()and private.marketing_content_generation_claims.attempt_count<5
 returning row_version into claim_version;
 if claim_version is null then select row_version into claim_version from private.marketing_content_generation_claims where campaign_id=c.id and worker_id=p_worker_id and lease_token=token;end if;
 if claim_version is null then return jsonb_build_object('outcome','NO_JOB');end if;
 return jsonb_build_object('outcome','CLAIMED','campaignId',c.id,'organizationId',c.organization_id,'serviceId',service.service_id,'libraryId',service.library_id,'language',case when coalesce(c.source_snapshot->>'language','FR')='AR'then'AR'else'FR'end,'serviceName',case when coalesce(c.source_snapshot->>'language','FR')='AR'then service.name_ar else service.name_fr end,'valueProposition',case when coalesce(c.source_snapshot->>'language','FR')='AR'then service.short_description_ar else service.short_description_fr end,'primaryCta',payload->>'primary_cta','trackedUrl',payload->>'tracked_url','approvedHashtags',payload->'approved_hashtags','approvedClaims',approved_claims,'templateKey',template_key,'sourceHash',service.content_hash,'idempotencyKey',provider_key,'providerIdempotencyKey',provider_key,'leaseToken',token,'workerId',p_worker_id,'claimRowVersion',claim_version)||offer;
exception when invalid_text_representation then return jsonb_build_object('outcome','NO_JOB');end$$;
revoke all on function public.claim_next_marketing_content_generation_v1(uuid,integer)from public,anon,authenticated;
grant execute on function public.claim_next_marketing_content_generation_v1(uuid,integer)to service_role;

create function public.persist_marketing_content_batch_v1(
  p_organization_id uuid,p_campaign_id uuid,p_service_id uuid,p_library_id uuid,p_language text,p_template_key text,p_source_hash text,
  p_provider text,p_failover_used boolean,p_contents jsonb,p_idempotency_key text,p_worker_id uuid,p_lease_token uuid,p_expected_claim_row_version integer,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare c public.marketing_campaigns%rowtype;tv uuid;creator uuid;item jsonb;mc uuid;cv uuid;n integer:=0;channels text[]:='{}';h text;cached jsonb;r jsonb;landing text;destination text;cta_token text;trusted_content_hash text;brand_payload jsonb;brand_claims jsonb;brand_certifications jsonb;catalog_source_hash text;actor_parameter text;checks jsonb;authoritative_offer jsonb;authoritative_price_label text;cta_nonce text;cta_signature text;cta_expiry timestamptz;cta_key_id uuid;cta_key bytea;claim private.marketing_content_generation_claims%rowtype;
begin
  if auth.role()is distinct from'service_role'then raise exception'MARKETING_CONTENT_WORKER_DENIED'using errcode='42501';end if;
  h:=private.canonical_request_hash(jsonb_build_object('organization',p_organization_id,'campaign',p_campaign_id,'service',p_service_id,'library',p_library_id,'language',p_language,'template',p_template_key,'source_hash',p_source_hash,'provider',p_provider,'failover',p_failover_used,'contents',p_contents,'worker',p_worker_id,'lease',p_lease_token,'claim_version',p_expected_claim_row_version));cached:=private.begin_marketing_worker_command('marketing.content.persist.'||p_campaign_id::text,p_idempotency_key,h);if cached is not null then return cached;end if;
  select*into claim from private.marketing_content_generation_claims where campaign_id=p_campaign_id for update;
  if claim.worker_id is distinct from p_worker_id or claim.lease_token is distinct from p_lease_token or claim.row_version is distinct from p_expected_claim_row_version or claim.status<>'CLAIMED'or claim.leased_until<=clock_timestamp()then raise exception'MARKETING_CONTENT_LEASE_INVALID'using errcode='40001';end if;
  select*into c from public.marketing_campaigns where id=p_campaign_id and organization_id=p_organization_id for update;if not found then raise exception'MARKETING_CAMPAIGN_NOT_FOUND'using errcode='P0002';end if;
  select s.created_by into creator from public.marketing_campaigns s where s.id=c.id;
  select v.payload,v.claims,v.certifications into brand_payload,brand_claims,brand_certifications from public.brand_kits k join public.brand_kit_versions v on v.id=k.current_version_id where k.organization_id=p_organization_id and k.status='READY' and v.id=c.brand_kit_version_id;
  select v.content_hash into catalog_source_hash from public.catalog_services s join public.catalog_service_versions v on v.id=s.current_published_version_id where s.id=p_service_id and s.library_id=p_library_id and s.status='PUBLISHED';
  select v.id into tv from public.marketing_templates t join public.marketing_template_versions v on v.id=t.current_version_id where t.template_key=p_template_key and t.status='ACTIVE';
  if nullif(c.source_snapshot->>'quote_version_id','')is not null then select jsonb_build_object('id',qv.id,'total_minor',qv.total_minor::text,'currency',qv.currency),private.format_marketing_minor_amount_v1(qv.total_minor,qv.currency,p_language)into authoritative_offer,authoritative_price_label from public.quote_versions qv join public.quotes q on q.id=qv.quote_id and q.selected_version_id=qv.id and q.status='SELECTED'join public.rfqs r on r.id=q.rfq_id join public.service_requests sr on sr.id=r.request_id where qv.id=(c.source_snapshot->>'quote_version_id')::uuid and sr.service_id=p_service_id;end if;
  if tv is null or brand_payload is null or catalog_source_hash is null or p_source_hash is distinct from catalog_source_hash or c.status not in('DRAFT','GENERATED','VALIDATED_BY_RULES') or (c.mode='AUTOPILOT' and not private.marketing_consent_active(p_organization_id,'SOCIAL_PUBLISHING')) or p_language not in('FR','AR')or p_provider not in('DETERMINISTIC_SANDBOX','CONFIGURED_EXTERNAL')or jsonb_typeof(p_contents)<>'array'or jsonb_array_length(p_contents)<>3 then raise exception'INVALID_MARKETING_CONTENT_BATCH'using errcode='22023';end if;
  for item in select value from jsonb_array_elements(p_contents)loop
    if item->>'channel'not in('LINKEDIN','FACEBOOK','REEL')or item->>'channel'=any(channels)or not(item?&array['titleInternal','hook','body','cta','hashtags','landingUrl','riskScore','contentHash','claimIds'])or jsonb_typeof(item->'hashtags')<>'array'or jsonb_typeof(item->'claimIds')<>'array'or item->>'contentHash'!~'^[0-9a-f]{64}$'or item->>'landingUrl'!~'^https://'or position('campaign_id='||p_campaign_id::text in item->>'landingUrl')=0 or position('library_id='||p_library_id::text in item->>'landingUrl')=0 or position('service_id='||p_service_id::text in item->>'landingUrl')=0 or(item->>'riskScore')::integer not between 0 and least(100,c.risk_threshold) or concat_ws(' ',item->>'titleInternal',item->>'hook',item->>'body',item->>'cta')~*'[[:alnum:]._%+-]+@[[:alnum:].-]+[.][[:alpha:]]{2,}|(?:[+]?[0-9][ -]?){9,15}' or exists(select 1 from jsonb_array_elements_text(item->'hashtags')tag where not (brand_payload->'approved_hashtags')?tag)or exists(select 1 from jsonb_array_elements_text(item->'claimIds')used where not exists(select 1 from public.marketing_brand_evidence_review_versions authoritative where authoritative.id=used::uuid and authoritative.brand_kit_version_id=c.brand_kit_version_id and authoritative.evidence_type='CLAIM'and authoritative.decision='VERIFIED'and(authoritative.valid_until is null or authoritative.valid_until>clock_timestamp())and authoritative.version=(select max(latest.version)from public.marketing_brand_evidence_review_versions latest where latest.brand_kit_version_id=authoritative.brand_kit_version_id and latest.evidence_type=authoritative.evidence_type and latest.evidence_key=authoritative.evidence_key)))then raise exception'INVALID_MARKETING_CONTENT_ITEM'using errcode='22023';end if;
    if concat_ws(' ',item->>'hook',item->>'body',item->>'cta')~*'(100[[:space:]]*%|garanti|guaranteed|نتيجة مضمونة|remise|promotion|promo|gratuit)'or(concat_ws(' ',item->>'hook',item->>'body',item->>'cta')~*'(offre|عرض|[0-9٠-٩]+[[:space:] ٬٫,.]*(MAD|DH)|د[.]م)'and(authoritative_offer is null or position(authoritative_price_label in concat_ws(' ',item->>'hook',item->>'body',item->>'cta'))=0))then raise exception'INVALID_MARKETING_CONTENT_ITEM'using errcode='22023';end if;
    channels:=array_append(channels,item->>'channel');
    insert into public.marketing_content(campaign_id,channel,template_version_id,service_id,library_id)values(c.id,item->>'channel',tv,p_service_id,p_library_id)returning id into mc;
    actor_parameter:=case when exists(select 1 from public.franchises f where f.operator_organization_id=p_organization_id and f.status='ACTIVE')then'franchise_id='||(select f.id::text from public.franchises f where f.operator_organization_id=p_organization_id and f.status='ACTIVE'order by f.created_at limit 1)else'provider_id='||p_organization_id::text end;
    destination:=item->>'landingUrl'||case when position('?' in item->>'landingUrl')>0 then'&'else'?'end||'content_id='||mc::text||'&'||actor_parameter;
    if not exists(select 1 from jsonb_array_elements_text(brand_payload->'allowed_url_hosts')host where lower(split_part(split_part(item->>'landingUrl','//',2),'/',1))=lower(host))then raise exception'MARKETING_URL_NOT_ALLOWED'using errcode='22023';end if;
    select id,secret into cta_key_id,cta_key from private.marketing_cta_signing_keys where status='ACTIVE';cta_expiry:=clock_timestamp()+interval'90 days';cta_nonce:=encode(extensions.gen_random_bytes(32),'hex');cta_signature:=encode(extensions.hmac(convert_to(cta_nonce||':'||p_organization_id::text||':'||c.id::text||':'||mc::text||':'||p_service_id::text||':'||extract(epoch from cta_expiry)::bigint::text,'UTF8'),cta_key,'sha256'),'hex');cta_token:=cta_nonce||cta_signature;landing:=regexp_replace(brand_payload->>'tracked_url','^(https://[^/]+).*$','\1')||'/api/marketing/cta/'||cta_token;
    trusted_content_hash:=private.canonical_request_hash(jsonb_build_object('channel',item->>'channel','language',p_language,'template_key',p_template_key,'service_id',p_service_id,'hook',item->>'hook','body',item->>'body','cta',item->>'cta','hashtags',item->'hashtags','landing_url',landing,'source_hash',catalog_source_hash));
    checks:=jsonb_build_object('source',case when p_source_hash=catalog_source_hash then'PASS'else'FAIL'end,'brand',case when brand_payload?&array['logo_assets','asset_restrictions','allowed_url_hosts']then'PASS'else'FAIL'end,'claims','PASS','privacy','PASS','certification',case when not exists(select 1 from jsonb_array_elements(brand_certifications)submitted where not exists(select 1 from public.marketing_brand_evidence_review_versions review where review.brand_kit_version_id=c.brand_kit_version_id and review.evidence_type='CERTIFICATION'and review.evidence_key=submitted->>'key'and review.evidence_hash=submitted->>'evidenceHash'and review.decision='VERIFIED'and(review.valid_until is null or review.valid_until>clock_timestamp())and review.version=(select max(latest.version)from public.marketing_brand_evidence_review_versions latest where latest.brand_kit_version_id=review.brand_kit_version_id and latest.evidence_type=review.evidence_type and latest.evidence_key=review.evidence_key)))then'PASS'else'FAIL'end,'promotion','PASS','duplicate',case when not exists(select 1 from public.marketing_content_versions existing where existing.content_hash=trusted_content_hash)then'PASS'else'FAIL'end,'offer',case when concat_ws(' ',item->>'hook',item->>'body',item->>'cta')!~*'(offre|عرض)'or authoritative_offer is not null then'PASS'else'FAIL'end,'price',case when concat_ws(' ',item->>'hook',item->>'body',item->>'cta')!~*'([0-9٠-٩]+[,.٫]?[0-9٠-٩]*[[:space:]]*(MAD|DH)|د[.]م)'or authoritative_offer is not null then'PASS'else'FAIL'end,'pii',case when concat_ws(' ',item->>'titleInternal',item->>'hook',item->>'body',item->>'cta')!~*'[[:alnum:]._%+-]+@[[:alnum:].-]+[.][[:alpha:]]{2,}|(?:[+]?[0-9][ -]?){9,15}|[A-Z]{2}[0-9]{2}[A-Z0-9]{10,30}'then'PASS'else'FAIL'end);
    if exists(select 1 from jsonb_each_text(checks)x where x.value<>'PASS')then raise exception'MARKETING_COMPLIANCE_CHECK_FAILED'using errcode='22023';end if;
    insert into public.marketing_content_versions(content_id,version,language,title_internal,hook,body,cta,hashtags,landing_url,claims_used,compliance_checks,risk_score,status,content_hash,created_by)
    values(mc,1,p_language,item->>'titleInternal',item->>'hook',item->>'body',item->>'cta',array(select jsonb_array_elements_text(item->'hashtags')),landing,item->'claimIds',checks,(item->>'riskScore')::integer,'VALIDATED_BY_RULES',trusted_content_hash,creator)returning id into cv;
    update public.marketing_content set current_version_id=cv where id=mc;
    insert into private.marketing_cta_tokens(token_hash,organization_id,campaign_id,content_id,service_id,destination_url,signing_key_id,token_nonce,expires_at)values(encode(extensions.digest(cta_token,'sha256'),'hex'),p_organization_id,c.id,mc,p_service_id,destination,cta_key_id,cta_nonce,cta_expiry);
    insert into public.marketing_content_sources(content_version_id,source_type,source_id,source_hash)values(cv,'CATALOG',p_service_id::text,p_source_hash);
    if authoritative_offer is not null then insert into public.marketing_content_sources(content_version_id,source_type,source_id,source_hash)values(cv,'OFFER',authoritative_offer->>'id',private.canonical_request_hash(authoritative_offer));end if;
    insert into public.marketing_metric_events(organization_id,campaign_id,metric,quantity,source_event_id,occurred_at)values(p_organization_id,c.id,'GENERATED',1,'content:'||cv::text,clock_timestamp());n:=n+1;
  end loop;
  if not channels@>array['LINKEDIN','FACEBOOK','REEL']then raise exception'INCOMPLETE_MARKETING_CONTENT_BATCH'using errcode='22023';end if;
  update public.marketing_campaigns set status='VALIDATED_BY_RULES',row_version=row_version+1 where id=c.id and status in('DRAFT','GENERATED','VALIDATED_BY_RULES');
  r:=jsonb_build_object('outcome','MARKETING_CONTENT_BATCH_PERSISTED','campaign_id',c.id,'count',n,'provider',p_provider,'failover_used',p_failover_used);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,null,'SERVICE','marketing.content.batch_generated','marketing_campaign',c.id::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_organization_id,'marketing_campaign',c.id::text,'MarketingContentBatchGeneratedV1',p_correlation_id,r,p_idempotency_key);
  update private.marketing_content_generation_claims set status='COMPLETED',leased_until=clock_timestamp(),row_version=row_version+1,updated_at=clock_timestamp()where campaign_id=c.id and worker_id=p_worker_id and lease_token=p_lease_token and row_version=p_expected_claim_row_version;
  perform private.finish_marketing_worker_command('marketing.content.persist.'||p_campaign_id::text,p_idempotency_key,r);return r;
exception when invalid_text_representation or numeric_value_out_of_range then raise exception'INVALID_MARKETING_CONTENT_ITEM'using errcode='22023';end$$;

create function public.record_marketing_content_generation_failure_v1(
 p_campaign_id uuid,p_worker_id uuid,p_lease_token uuid,p_expected_claim_row_version integer,
 p_error_code text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare claim private.marketing_content_generation_claims%rowtype;c public.marketing_campaigns%rowtype;h text;cached jsonb;r jsonb;new_status text;next_at timestamptz;
begin
 if auth.role()is distinct from'service_role'then raise exception'MARKETING_CONTENT_WORKER_DENIED'using errcode='42501';end if;
 if p_error_code!~'^[A-Z][A-Z0-9_]{2,79}$'then raise exception'INVALID_MARKETING_CONTENT_FAILURE'using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('campaign',p_campaign_id,'worker',p_worker_id,'lease',p_lease_token,'claim_version',p_expected_claim_row_version,'error',p_error_code));cached:=private.begin_marketing_worker_command('marketing.content.failure.'||p_campaign_id::text,p_idempotency_key,h);if cached is not null then return cached;end if;
 select*into claim from private.marketing_content_generation_claims where campaign_id=p_campaign_id for update;
 if claim.worker_id is distinct from p_worker_id or claim.lease_token is distinct from p_lease_token or claim.row_version is distinct from p_expected_claim_row_version or claim.status<>'CLAIMED'or claim.leased_until<=clock_timestamp()then raise exception'MARKETING_CONTENT_LEASE_INVALID'using errcode='40001';end if;
 select*into c from public.marketing_campaigns where id=p_campaign_id;
 new_status:=case when claim.attempt_count>=5 then'DEAD_LETTER'else'FAILED'end;next_at:=case when new_status='FAILED'then clock_timestamp()+make_interval(secs=>least(1800,30*(power(2,claim.attempt_count-1)::integer)))end;
 update private.marketing_content_generation_claims set status=new_status,next_attempt_at=coalesce(next_at,clock_timestamp()),last_error_code=p_error_code,leased_until=clock_timestamp(),row_version=row_version+1,updated_at=clock_timestamp()where campaign_id=p_campaign_id;
 r:=jsonb_build_object('outcome','MARKETING_CONTENT_FAILURE_RECORDED','campaign_id',p_campaign_id,'status',new_status,'attempt_count',claim.attempt_count,'next_attempt_at',next_at);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(c.organization_id,null,'SERVICE','marketing.content.generation_failed','marketing_campaign',c.id::text,p_correlation_id,r||jsonb_build_object('error_code',p_error_code,'worker_id_hash',encode(extensions.digest(convert_to(p_worker_id::text,'UTF8'),'sha256'),'hex')),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(c.organization_id,'marketing_campaign',c.id::text,case when new_status='DEAD_LETTER'then'MarketingContentGenerationDeadLetteredV1'else'MarketingContentGenerationRetryScheduledV1'end,p_correlation_id,r,p_idempotency_key);
 perform private.finish_marketing_worker_command('marketing.content.failure.'||p_campaign_id::text,p_idempotency_key,r);return r;
end$$;

create function public.ingest_marketing_attribution_event_v1(
 p_organization_id uuid,p_campaign_id uuid,p_content_id uuid,p_event_type text,p_source text,p_medium text,p_visitor_hash text,
 p_economic_value_minor bigint,p_occurred_at timestamptz,p_metadata jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare e bigint;l uuid;h text;cached jsonb;r jsonb;metric text;touches jsonb;attributed uuid;
begin
 if auth.role()is distinct from'service_role'then raise exception'MARKETING_ATTRIBUTION_WORKER_DENIED'using errcode='42501';end if;
 if not private.marketing_consent_active(p_organization_id,'MARKETING_ANALYTICS') or not exists(select 1 from public.marketing_campaigns where id=p_campaign_id and organization_id=p_organization_id)or(p_content_id is not null and not exists(select 1 from public.marketing_content where id=p_content_id and campaign_id=p_campaign_id))or p_event_type not in('CONTENT_VIEWED','CTA_CLICKED','LANDING_VIEWED','REGISTRATION_STARTED','DIAGNOSTIC_STARTED','OPPORTUNITY_CREATED','RFQ_STARTED','CONTRACT_SIGNED')or p_visitor_hash!~'^[0-9a-f]{64}$'or length(btrim(coalesce(p_source,'')))not between 2 and 80 or length(btrim(coalesce(p_medium,'')))not between 2 and 80 or p_occurred_at>clock_timestamp()+interval'5 minutes'or jsonb_typeof(p_metadata)<>'object' or octet_length(p_metadata::text)>4096 or exists(select 1 from jsonb_object_keys(p_metadata)k where k not in('utm_campaign','utm_source','utm_medium','utm_content','landing_path','referrer_host')) or p_metadata::text~*'[[:alnum:]._%+-]+@[[:alnum:].-]+[.][[:alpha:]]{2,}|(?:[+]?[0-9][ -]?){9,15}' or p_economic_value_minor<0 then raise exception'INVALID_MARKETING_ATTRIBUTION_EVENT'using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('organization',p_organization_id,'campaign',p_campaign_id,'content',p_content_id,'event',p_event_type,'source',p_source,'medium',p_medium,'visitor',p_visitor_hash,'value',p_economic_value_minor,'occurred',p_occurred_at,'metadata',p_metadata));cached:=private.begin_marketing_worker_command('marketing.attribution.ingest',p_idempotency_key,h);if cached is not null then return cached;end if;
 insert into public.marketing_attribution_events(organization_id,campaign_id,content_id,event_type,source,medium,visitor_hash,economic_value_minor,occurred_at,metadata)values(p_organization_id,p_campaign_id,p_content_id,p_event_type,btrim(lower(p_source)),btrim(lower(p_medium)),p_visitor_hash,p_economic_value_minor,p_occurred_at,p_metadata)returning id into e;
 insert into public.marketing_leads(organization_id,campaign_id,visitor_hash,first_touch_at,last_touch_at,status)values(p_organization_id,p_campaign_id,p_visitor_hash,p_occurred_at,p_occurred_at,case when p_event_type='CONTRACT_SIGNED'then'CONVERTED'when p_event_type in('OPPORTUNITY_CREATED','RFQ_STARTED')then'QUALIFIED'when p_event_type='REGISTRATION_STARTED'then'REGISTERED'else'ANONYMOUS'end)
 on conflict(organization_id,campaign_id,visitor_hash)do update set first_touch_at=least(marketing_leads.first_touch_at,excluded.first_touch_at),last_touch_at=greatest(marketing_leads.last_touch_at,excluded.last_touch_at),status=case when excluded.status='CONVERTED'or marketing_leads.status='CONVERTED'then'CONVERTED'when excluded.status='QUALIFIED'or marketing_leads.status='QUALIFIED'then'QUALIFIED'when excluded.status='REGISTERED'or marketing_leads.status='REGISTERED'then'REGISTERED'else marketing_leads.status end returning id into l;
 select coalesce(jsonb_agg(jsonb_build_object('event_id',id,'campaign_id',campaign_id,'content_id',content_id,'event_type',event_type,'source',source,'medium',medium,'occurred_at',occurred_at)order by occurred_at,id),'[]'::jsonb)into touches from public.marketing_attribution_events where organization_id=p_organization_id and visitor_hash=p_visitor_hash;
 select campaign_id into attributed from public.marketing_attribution_events where organization_id=p_organization_id and visitor_hash=p_visitor_hash and source<>'direct'order by occurred_at desc,id desc limit 1;
 insert into public.marketing_conversion_paths(organization_id,lead_id,attribution_model,touchpoints,attributed_campaign_id,attributed_value_minor,currency)values(p_organization_id,l,'LAST_NON_DIRECT_CLICK',touches,coalesce(attributed,p_campaign_id),p_economic_value_minor,case when p_economic_value_minor is null then null else'MAD'end);
 metric:=case p_event_type when'CONTENT_VIEWED'then'VIEW'when'CTA_CLICKED'then'CLICK'when'REGISTRATION_STARTED'then'LEAD'when'DIAGNOSTIC_STARTED'then'DIAGNOSTIC'when'OPPORTUNITY_CREATED'then'OPPORTUNITY'when'RFQ_STARTED'then'RFQ'when'CONTRACT_SIGNED'then'CONTRACT'else null end;
 if metric is not null then insert into public.marketing_metric_events(organization_id,campaign_id,metric,quantity,source_event_id,occurred_at)values(p_organization_id,p_campaign_id,metric,1,'attribution:'||e::text,p_occurred_at);end if;
 if p_economic_value_minor is not null then insert into public.marketing_metric_events(organization_id,campaign_id,metric,quantity,value_minor,currency,source_event_id,occurred_at)values(p_organization_id,coalesce(attributed,p_campaign_id),'ATTRIBUTED_VALUE',1,p_economic_value_minor,'MAD','attribution-value:'||e::text,p_occurred_at);end if;
 r:=jsonb_build_object('outcome','MARKETING_ATTRIBUTION_INGESTED','event_id',e,'lead_id',l,'attributed_campaign_id',coalesce(attributed,p_campaign_id),'touchpoint_count',jsonb_array_length(touches));
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,null,'SERVICE','marketing.attribution.ingested','marketing_attribution_event',e::text,p_correlation_id,jsonb_build_object('event_type',p_event_type,'campaign_id',p_campaign_id),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_organization_id,'marketing_attribution_event',e::text,'MarketingAttributionEventIngestedV1',p_correlation_id,r,p_idempotency_key);
 perform private.finish_marketing_worker_command('marketing.attribution.ingest',p_idempotency_key,r);return r;end$$;

create or replace view public.marketing_performance_dimensions_v1 with(security_invoker=true)as
with facts as(select campaign_id,source_event_id,date_trunc('day',occurred_at)::date metric_date,metric,sum(quantity)::bigint quantity,sum(coalesce(value_minor,0))::bigint value_minor,max(currency)currency from public.marketing_metric_events group by campaign_id,source_event_id,date_trunc('day',occurred_at)::date,metric)
select c.organization_id,c.id campaign_id,c.created_by actor_user_id,d.id content_id,d.library_id,d.service_id,d.channel network,f.metric_date,f.metric,f.quantity,f.value_minor,f.currency,
 case when franchise.id is null and exists(select 1 from public.provider_profiles pp where pp.provider_organization_id=c.organization_id)then c.organization_id end provider_organization_id,franchise.id franchise_id
from facts f join public.marketing_campaigns c on c.id=f.campaign_id
left join lateral(select mc.id,mc.library_id,mc.service_id,mc.channel from public.marketing_content mc where mc.campaign_id=c.id and(f.source_event_id='content:'||mc.current_version_id::text or f.source_event_id='content-id:'||mc.id::text)order by mc.created_at,mc.id limit 1)d on true
left join lateral(select fr.id from public.franchises fr where fr.operator_organization_id=c.organization_id and fr.status='ACTIVE'order by fr.created_at,fr.id limit 1)franchise on true;

revoke all on function public.review_marketing_brand_evidence_v1(uuid,text,text,text,text,timestamptz,text,text,uuid),public.save_marketing_brand_kit_v1(uuid,jsonb,jsonb,jsonb,text,boolean,text,uuid),public.initialize_standard_marketing_templates_v1(text,uuid),public.persist_marketing_content_batch_v1(uuid,uuid,uuid,uuid,text,text,text,text,boolean,jsonb,text,uuid,uuid,integer,uuid),public.record_marketing_content_generation_failure_v1(uuid,uuid,uuid,integer,text,text,uuid),public.ingest_marketing_attribution_event_v1(uuid,uuid,uuid,text,text,text,text,bigint,timestamptz,jsonb,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.review_marketing_brand_evidence_v1(uuid,text,text,text,text,timestamptz,text,text,uuid),public.save_marketing_brand_kit_v1(uuid,jsonb,jsonb,jsonb,text,boolean,text,uuid),public.initialize_standard_marketing_templates_v1(text,uuid)to authenticated;
grant execute on function public.persist_marketing_content_batch_v1(uuid,uuid,uuid,uuid,text,text,text,text,boolean,jsonb,text,uuid,uuid,integer,uuid),public.record_marketing_content_generation_failure_v1(uuid,uuid,uuid,integer,text,text,uuid),public.ingest_marketing_attribution_event_v1(uuid,uuid,uuid,text,text,text,text,bigint,timestamptz,jsonb,text,uuid)to service_role;
revoke all on public.marketing_performance_dimensions_v1 from public,anon,service_role;grant select on public.marketing_performance_dimensions_v1 to authenticated;
notify pgrst,'reload schema';
