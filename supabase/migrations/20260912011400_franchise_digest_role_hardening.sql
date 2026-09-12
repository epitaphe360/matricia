-- P1 MAT-FUNC-064 hardening: digest visibility and delivery require an active franchise role.

create function private.franchise_digest_role_access(p_franchise_id uuid,p_allow_platform_admin boolean default true,p_actor uuid default auth.uid())returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
 select p_actor is not null and exists(
  select 1 from public.franchises f
  where f.id=p_franchise_id and f.status='ACTIVE'and(
   (p_allow_platform_admin and private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'],p_actor))
   or exists(
    select 1 from public.organization_memberships m
    join public.organization_member_roles mr on mr.membership_id=m.id and mr.revoked_at is null
    where m.organization_id=f.operator_organization_id and m.user_id=p_actor and m.status='ACTIVE'
     and mr.role_code in('FRANCHISE_OWNER','FRANCHISE_MANAGER','FRANCHISE_VIEWER')
     and(mr.franchise_id is null or mr.franchise_id=f.id)
   )
  )
 )
$$;

create function private.guard_franchise_digest_job_recipient()returns trigger language plpgsql security definer set search_path=pg_catalog,public,private as $$
begin
 if not private.franchise_digest_role_access(new.franchise_id,false,new.recipient_user_id)then raise exception'FRANCHISE_DIGEST_RECIPIENT_ACCESS_REVOKED'using errcode='42501';end if;
 return new;
end$$;
create trigger franchise_digest_job_recipient_guard before insert or update of franchise_id,recipient_user_id on public.franchise_daily_digest_jobs for each row execute function private.guard_franchise_digest_job_recipient();

create function private.guard_franchise_digest_notification_recipient()returns trigger language plpgsql security definer set search_path=pg_catalog,public,private as $$
declare fid uuid;
begin
 if new.source_aggregate_type='franchise_daily_digest'then
  select j.franchise_id into fid from public.franchise_daily_digest_jobs j where j.digest_id=new.source_aggregate_id::uuid and j.recipient_user_id=new.recipient_user_id;
  if fid is null or not private.franchise_digest_role_access(fid,false,new.recipient_user_id)then raise exception'FRANCHISE_DIGEST_RECIPIENT_ACCESS_REVOKED'using errcode='42501';end if;
 end if;
 return new;
end$$;
create trigger franchise_digest_notification_recipient_guard before insert on public.notification_instances for each row execute function private.guard_franchise_digest_notification_recipient();

drop policy franchise_digest_configs_scoped_read on public.franchise_daily_digest_config_versions;
drop policy franchise_digests_scoped_read on public.franchise_daily_digests;
drop policy franchise_digest_jobs_scoped_read on public.franchise_daily_digest_jobs;
drop policy franchise_digest_attempts_scoped_read on public.franchise_daily_digest_job_attempts;
create policy franchise_digest_configs_role_read on public.franchise_daily_digest_config_versions for select to authenticated using(private.franchise_digest_role_access(franchise_id,true));
create policy franchise_digests_role_read on public.franchise_daily_digests for select to authenticated using(private.franchise_digest_role_access(franchise_id,true));
create policy franchise_digest_jobs_role_read on public.franchise_daily_digest_jobs for select to authenticated using(private.franchise_digest_role_access(franchise_id,true));
create policy franchise_digest_attempts_role_read on public.franchise_daily_digest_job_attempts for select to authenticated using(exists(select 1 from public.franchise_daily_digest_jobs j where j.id=job_id and private.franchise_digest_role_access(j.franchise_id,true)));

create or replace function public.claim_franchise_daily_digest_jobs(p_worker_id uuid,p_limit integer default 20,p_lease_seconds integer default 300)returns setof jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare j record;token uuid;corr uuid;
begin
 if auth.role()<>'service_role'then raise exception'FRANCHISE_DIGEST_WORKER_ONLY'using errcode='42501';end if;
 if p_worker_id is null or p_limit not between 1 and 100 or p_lease_seconds not between 30 and 900 then raise exception'INVALID_FRANCHISE_DIGEST_CLAIM'using errcode='22023';end if;
 for j in
  select x.id,q.organization_id from public.franchise_daily_digest_jobs x
  join public.franchise_daily_digests q on q.id=x.digest_id
  where((x.status in('QUEUED','FAILED')and x.next_attempt_at<=clock_timestamp())or(x.status='CLAIMED'and x.leased_until<=clock_timestamp()))
   and private.franchise_digest_role_access(x.franchise_id,false,x.recipient_user_id)
  order by coalesce(x.next_attempt_at,x.leased_until),x.id for update of x skip locked limit p_limit
 loop
  token:=extensions.gen_random_uuid();corr:=extensions.gen_random_uuid();
  update public.franchise_daily_digest_jobs set status='CLAIMED',attempt_count=attempt_count+1,next_attempt_at=null,lease_token=token,worker_id=p_worker_id,leased_until=clock_timestamp()+make_interval(secs=>p_lease_seconds),row_version=row_version+1,updated_at=clock_timestamp()where id=j.id;
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(j.organization_id,null,'SYSTEM','franchise.daily_digest.claimed','franchise_daily_digest_job',j.id::text,corr,jsonb_build_object('worker_id',p_worker_id,'lease_seconds',p_lease_seconds),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)values(j.organization_id,'franchise_daily_digest_job',j.id::text,'FranchiseDailyDigestClaimedV1',corr,jsonb_build_object('job_id',j.id,'worker_id',p_worker_id));
  return next jsonb_build_object('job_id',j.id,'lease_token',token,'worker_id',p_worker_id);
 end loop;return;
end$$;

revoke all on function private.franchise_digest_role_access(uuid,boolean,uuid),private.guard_franchise_digest_job_recipient(),private.guard_franchise_digest_notification_recipient()from public,anon,authenticated,service_role;
grant execute on function private.franchise_digest_role_access(uuid,boolean,uuid)to authenticated;
revoke all on function public.claim_franchise_daily_digest_jobs(uuid,integer,integer)from public,anon,authenticated,service_role;
grant execute on function public.claim_franchise_daily_digest_jobs(uuid,integer,integer)to service_role;
