-- V4.1: least-privilege service worker contract for scheduled social publishing.
alter table public.marketing_content_versions add column media_url text check(media_url is null or media_url~'^https://');
create function public.claim_next_social_publication_job_v41(
  p_worker_id text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$declare j public.social_publication_jobs%rowtype;i public.marketing_calendar_items%rowtype;
v public.marketing_content_versions%rowtype;c public.social_connections%rowtype;s public.social_connection_security_versions%rowtype;channel text;r jsonb;
begin
  if auth.role() is distinct from 'service_role' or length(btrim(coalesce(p_worker_id,''))) not between 3 and 100 then raise exception'MARKETING_WORKER_CLAIM_DENIED'using errcode='42501';end if;
  select * into j from public.social_publication_jobs where status='QUEUED'and available_at<=clock_timestamp() order by available_at,id for update skip locked limit 1;
  if not found then return jsonb_build_object('outcome','NO_JOB');end if;
  select * into i from public.marketing_calendar_items where id=j.calendar_item_id;
  select * into v from public.marketing_content_versions where id=i.content_version_id;
  select mc.channel into channel from public.marketing_content mc where mc.id=v.content_id;
  select * into c from public.social_connections where id=i.social_connection_id;
  select * into s from public.social_connection_security_versions where social_connection_id=c.id order by version desc limit 1;
  if not private.marketing_publication_ready_v41(j.organization_id,j.provider,c.id,v.id) then update public.social_publication_jobs set status='SKIPPED'where id=j.id;update public.marketing_calendar_items set status='SKIPPED'where id=i.id;return jsonb_build_object('outcome','SKIPPED_POLICY','job_id',j.id);end if;
  update public.social_publication_jobs set status='CLAIMED',attempt_count=attempt_count+1 where id=j.id returning * into j;
  r:=jsonb_build_object('outcome','JOB_CLAIMED','job_id',j.id,'attempt',j.attempt_count,'provider',j.provider,'channel',channel,'credential_reference',s.vault_credential_reference,'content',jsonb_build_object('language',v.language,'hook',v.hook,'body',v.body,'cta',v.cta,'hashtags',v.hashtags,'landing_url',v.landing_url,'media_url',v.media_url));
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(j.organization_id,null,'SERVICE','marketing.publication.worker_claimed','social_publication_job',j.id::text,p_correlation_id,jsonb_build_object('worker_id',p_worker_id,'provider',j.provider,'attempt',j.attempt_count),repeat('0',64));
  return r;
end$$;

create function public.record_social_publication_worker_result_v41(
  p_job_id uuid,p_outcome text,p_provider_publication_id text,p_error_code text,
  p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$declare j public.social_publication_jobs%rowtype;i public.marketing_calendar_items%rowtype;v public.marketing_content_versions%rowtype;prior public.social_publication_results%rowtype;auth_hash text;consent_hash text;r jsonb;
begin
  if auth.role() is distinct from 'service_role' then raise exception'MARKETING_WORKER_RESULT_DENIED'using errcode='42501';end if;
  if p_outcome not in('PUBLISHED','RETRYABLE_FAILURE','PERMANENT_FAILURE')or length(coalesce(p_idempotency_key,''))not between 8 and 200 or(p_outcome='PUBLISHED')<>(p_provider_publication_id is not null)or(p_outcome='PUBLISHED'and p_error_code is not null)then raise exception'INVALID_MARKETING_WORKER_RESULT'using errcode='22023';end if;
  select * into j from public.social_publication_jobs where id=p_job_id for update;if not found then raise exception'MARKETING_JOB_NOT_FOUND'using errcode='P0002';end if;
  select * into prior from public.social_publication_results where job_id=j.id and attempt=j.attempt_count;if found then if prior.outcome<>p_outcome or prior.provider_publication_id is distinct from p_provider_publication_id or prior.error_code is distinct from p_error_code then raise exception'IDEMPOTENCY_PAYLOAD_MISMATCH'using errcode='22000';end if;return jsonb_build_object('outcome',prior.outcome,'job_id',j.id,'attempt',prior.attempt);end if;
  if j.status<>'CLAIMED'then raise exception'MARKETING_JOB_NOT_CLAIMED'using errcode='55000';end if;
  select * into i from public.marketing_calendar_items where id=j.calendar_item_id;select * into v from public.marketing_content_versions where id=i.content_version_id;
  if p_outcome='PUBLISHED'and not private.marketing_publication_ready_v41(j.organization_id,j.provider,i.social_connection_id,i.content_version_id)then raise exception'MARKETING_PUBLICATION_BLOCKED'using errcode='55000';end if;
  insert into public.social_publication_results(job_id,attempt,outcome,provider_publication_id,error_code)values(j.id,j.attempt_count,p_outcome,p_provider_publication_id,p_error_code);
  if p_outcome='PUBLISHED'then
    select evidence_hash into auth_hash from public.marketing_brand_authorizations where organization_id=j.organization_id and decision='GRANTED'order by decided_at desc,id desc limit 1;
    select evidence_hash into consent_hash from public.marketing_consents where organization_id=j.organization_id and purpose='SOCIAL_PUBLISHING'and decision='GRANTED'order by decided_at desc,id desc limit 1;
    insert into public.marketing_publication_journal(organization_id,job_id,content_version_id,provider,provider_publication_id,content_snapshot,content_hash,authorization_evidence_hash,consent_evidence_hash,published_at)values(j.organization_id,j.id,v.id,j.provider,p_provider_publication_id,jsonb_build_object('language',v.language,'hook',v.hook,'body',v.body,'cta',v.cta,'hashtags',v.hashtags,'landing_url',v.landing_url,'media_url',v.media_url),v.content_hash,auth_hash,consent_hash,clock_timestamp());
    update public.social_publication_jobs set status='PUBLISHED'where id=j.id;update public.marketing_calendar_items set status='PUBLISHED'where id=i.id;r:=jsonb_build_object('outcome','PUBLISHED','job_id',j.id,'provider_publication_id',p_provider_publication_id);
  elsif p_outcome='RETRYABLE_FAILURE'and j.attempt_count<20 then
    update public.social_publication_jobs set status='QUEUED',available_at=clock_timestamp()+make_interval(secs=>least(3600,30*(2^least(j.attempt_count,7))::integer))where id=j.id;update public.marketing_calendar_items set status='SCHEDULED'where id=i.id;r:=jsonb_build_object('outcome','RETRY_SCHEDULED','job_id',j.id,'attempt',j.attempt_count);
  else update public.social_publication_jobs set status='FAILED'where id=j.id;update public.marketing_calendar_items set status='FAILED'where id=i.id;r:=jsonb_build_object('outcome','PERMANENT_FAILURE','job_id',j.id,'error_code',p_error_code);end if;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(j.organization_id,null,'SERVICE','marketing.publication.worker_result','social_publication_job',j.id::text,p_correlation_id,jsonb_build_object('outcome',p_outcome,'attempt',j.attempt_count,'error_code',p_error_code),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(j.organization_id,'social_publication_job',j.id::text,case when p_outcome='PUBLISHED'then'SocialPublicationRecordedV1'when p_outcome='RETRYABLE_FAILURE'then'SocialPublicationRetryScheduledV1'else'SocialPublicationFailedV1'end,p_correlation_id,r,p_idempotency_key);
  return r;
end$$;

revoke all on function public.claim_next_social_publication_job_v41(text,uuid),public.record_social_publication_worker_result_v41(uuid,text,text,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.claim_next_social_publication_job_v41(text,uuid),public.record_social_publication_worker_result_v41(uuid,text,text,text,text,uuid) to service_role;
