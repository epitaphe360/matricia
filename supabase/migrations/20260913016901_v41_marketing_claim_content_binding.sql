-- V4.1 corrective additive migration: bind publication claims to the exact content version.
create or replace function public.claim_social_publication_job_v41(
  p_job_id uuid,
  p_worker_id text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare
  a uuid:=auth.uid();
  j public.social_publication_jobs%rowtype;
  connection_id uuid;
  content_version_id uuid;
  result jsonb;
begin
  if a is null
     or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],a)
     or length(btrim(p_worker_id)) not between 3 and 100 then
    raise exception 'MARKETING_JOB_CLAIM_DENIED' using errcode='42501';
  end if;
  select * into j from public.social_publication_jobs where id=p_job_id for update;
  if not found or j.status<>'QUEUED' or j.available_at>clock_timestamp() then
    raise exception 'MARKETING_JOB_NOT_CLAIMABLE' using errcode='55000';
  end if;
  select item.social_connection_id,item.content_version_id
  into connection_id,content_version_id
  from public.marketing_calendar_items item where item.id=j.calendar_item_id;
  if not private.marketing_publication_ready_v41(
    j.organization_id,j.provider,connection_id,content_version_id
  ) then
    raise exception 'MARKETING_PUBLICATION_BLOCKED' using errcode='55000';
  end if;
  update public.social_publication_jobs
  set status='CLAIMED',attempt_count=attempt_count+1 where id=j.id;
  result:=jsonb_build_object(
    'outcome','SOCIAL_PUBLICATION_JOB_CLAIMED','job_id',j.id,
    'worker_id',p_worker_id,'attempt',j.attempt_count+1
  );
  insert into public.audit_events(
    organization_id,actor_user_id,actor_type,action,resource_type,resource_id,
    correlation_id,metadata,event_hash
  ) values (
    j.organization_id,a,'USER','marketing.publication.claimed',
    'social_publication_job',j.id::text,p_correlation_id,
    jsonb_build_object('provider',j.provider,'attempt',j.attempt_count+1),
    repeat('0',64)
  );
  return result;
end
$$;
revoke all on function public.claim_social_publication_job_v41(uuid,text,uuid)
from public,anon,authenticated,service_role;
grant execute on function public.claim_social_publication_job_v41(uuid,text,uuid)
to authenticated;
