-- Recover abandoned publication claims and fail closed with an auditable exception.

alter table public.social_publication_jobs
  add column claimed_by text,
  add column claimed_at timestamptz,
  add column lease_expires_at timestamptz;
create index social_publication_jobs_lease_idx
  on public.social_publication_jobs(status,lease_expires_at)
  where status='CLAIMED';

create or replace function private.marketing_publication_ready_v41(
  p_organization_id uuid,p_provider text,p_connection_id uuid,p_content_version_id uuid
)returns boolean language sql stable security definer
set search_path=pg_catalog,public,private as $$
 select private.marketing_consent_active(p_organization_id,'SOCIAL_PUBLISHING')
 and exists(select 1 from public.social_connections c where c.id=p_connection_id
   and c.organization_id=p_organization_id and c.provider=p_provider and c.status='ACTIVE')
 and coalesce((select decision='GRANTED' and effective_from<=clock_timestamp()
   and(effective_until is null or effective_until>clock_timestamp())
   and authorization_scope@>array['SOCIAL_PUBLISHING']::text[]
   from public.marketing_brand_authorizations where organization_id=p_organization_id
   order by decided_at desc,id desc limit 1),false)
 and exists(select 1 from public.social_connection_security_versions s
   join public.social_connections connection on connection.id=s.social_connection_id
   join public.marketing_content_versions version on version.id=p_content_version_id
   join public.marketing_content content on content.id=version.content_id
   where s.social_connection_id=p_connection_id and s.status='ACTIVE'
   and(s.expires_at is null or s.expires_at>clock_timestamp())
   and connection.scopes@>s.approved_scopes and connection.scopes<@s.approved_scopes
   and case when p_provider='LINKEDIN'and content.channel='LINKEDIN' then
     s.approved_scopes@>array['w_member_social']::text[]
     and s.approved_scopes<@array['w_member_social']::text[]
   when p_provider='META'and content.channel='FACEBOOK' then
     s.approved_scopes@>array['pages_manage_posts']::text[]
     and s.approved_scopes<@array['pages_manage_posts']::text[]
   when p_provider='META'and content.channel in('INSTAGRAM','REEL') then
     s.approved_scopes@>array['pages_manage_posts','instagram_basic','instagram_content_publish']::text[]
     and s.approved_scopes<@array['pages_manage_posts','instagram_basic','instagram_content_publish']::text[]
   else false end
   order by s.version desc limit 1)
 and exists(select 1 from public.marketing_content_versions v
   join public.marketing_content mc on mc.id=v.content_id
   join public.marketing_campaigns campaign on campaign.id=mc.campaign_id
   where v.id=p_content_version_id and campaign.organization_id=p_organization_id
   and campaign.status in('APPROVED','SCHEDULED','PUBLISHED')and v.status='APPROVED'
   and(v.expires_at is null or v.expires_at>clock_timestamp())
   and v.compliance_checks?&array['source','brand','claims','privacy','certification',
     'promotion','duplicate','offer','price','pii']
   and not exists(select 1 from jsonb_each_text(v.compliance_checks)q where q.value<>'PASS'))
 and not coalesce((select enabled from public.marketing_kill_switch_versions
   where organization_id is null and scope='GLOBAL'order by version desc limit 1),false)
 and not coalesce((select enabled from public.marketing_kill_switch_versions
   where organization_id is null and scope='PROVIDER'and provider=p_provider order by version desc limit 1),false)
 and not coalesce((select enabled from public.marketing_kill_switch_versions
   where organization_id=p_organization_id and scope='GLOBAL'order by version desc limit 1),false)
 and not coalesce((select enabled from public.marketing_kill_switch_versions
   where organization_id=p_organization_id and scope='PROVIDER'and provider=p_provider order by version desc limit 1),false)
$$;

create or replace function public.claim_next_social_publication_job_v41(
  p_worker_id text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare j public.social_publication_jobs%rowtype;i public.marketing_calendar_items%rowtype;
v public.marketing_content_versions%rowtype;c public.social_connections%rowtype;
s public.social_connection_security_versions%rowtype;channel text;r jsonb;
campaign_id uuid;was_reclaimed boolean;
begin
  if auth.role() is distinct from 'service_role'
    or length(btrim(coalesce(p_worker_id,''))) not between 3 and 100 then
    raise exception'MARKETING_WORKER_CLAIM_DENIED'using errcode='42501';
  end if;
  select * into j from public.social_publication_jobs
    where(status='QUEUED'and available_at<=clock_timestamp())
      or(status='CLAIMED'and lease_expires_at<=clock_timestamp())
    order by case when status='CLAIMED'then 0 else 1 end,available_at,id
    for update skip locked limit 1;
  if not found then return jsonb_build_object('outcome','NO_JOB');end if;
  was_reclaimed:=j.status='CLAIMED';
  select * into i from public.marketing_calendar_items where id=j.calendar_item_id;
  select * into v from public.marketing_content_versions where id=i.content_version_id;
  select mc.channel,mc.campaign_id into channel,campaign_id from public.marketing_content mc where mc.id=v.content_id;
  select * into c from public.social_connections where id=i.social_connection_id;
  select * into s from public.social_connection_security_versions
    where social_connection_id=c.id order by version desc limit 1;
  if not private.marketing_publication_ready_v41(j.organization_id,j.provider,c.id,v.id) then
    update public.social_publication_jobs set status='SKIPPED',claimed_by=null,claimed_at=null,lease_expires_at=null where id=j.id;
    update public.marketing_calendar_items set status='SKIPPED'where id=i.id;
    if not exists(select 1 from public.marketing_exceptions where campaign_id=campaign_id
      and content_version_id=v.id and exception_type='PUBLICATION_POLICY_BLOCKED'and status='OPEN')then
      insert into public.marketing_exceptions(
        organization_id,campaign_id,content_version_id,exception_type,severity,reason,
        automatic_resolution_possible,status
      )values(j.organization_id,campaign_id,v.id,'PUBLICATION_POLICY_BLOCKED','BLOCKING',
        'Publication blocked by current consent, authorization, security, compliance or kill-switch policy.',
        false,'OPEN');
    end if;
    r:=jsonb_build_object('outcome','SKIPPED_POLICY','job_id',j.id,'campaign_id',campaign_id);
    insert into public.audit_events(
      organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash
    )values(j.organization_id,null,'SERVICE','marketing.publication.policy_blocked','social_publication_job',
      j.id::text,p_correlation_id,r,repeat('0',64));
    insert into public.event_outbox(
      organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key
    )values(j.organization_id,'social_publication_job',j.id::text,'SocialPublicationPolicyBlockedV1',
      p_correlation_id,r,'marketing-policy-blocked:'||j.id::text);
    return r;
  end if;
  update public.social_publication_jobs set status='CLAIMED',attempt_count=attempt_count+1,
    claimed_by=p_worker_id,claimed_at=clock_timestamp(),lease_expires_at=clock_timestamp()+interval'5 minutes'
    where id=j.id returning * into j;
  r:=jsonb_build_object('outcome','JOB_CLAIMED','job_id',j.id,'attempt',j.attempt_count,
    'provider',j.provider,'channel',channel,'credential_reference',s.vault_credential_reference,
    'lease_expires_at',j.lease_expires_at,'reclaimed',was_reclaimed,
    'content',jsonb_build_object('language',v.language,'hook',v.hook,'body',v.body,'cta',v.cta,
      'hashtags',v.hashtags,'landing_url',v.landing_url,'media_url',v.media_url));
  insert into public.audit_events(
    organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash
  )values(j.organization_id,null,'SERVICE','marketing.publication.worker_claimed','social_publication_job',
    j.id::text,p_correlation_id,jsonb_build_object('worker_id',p_worker_id,'provider',j.provider,
      'attempt',j.attempt_count,'reclaimed',was_reclaimed,'lease_expires_at',j.lease_expires_at),repeat('0',64));
  return r;
end$$;

revoke all on function private.marketing_publication_ready_v41(uuid,text,uuid,uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.claim_next_social_publication_job_v41(text,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.claim_next_social_publication_job_v41(text,uuid) to service_role;
notify pgrst,'reload schema';
