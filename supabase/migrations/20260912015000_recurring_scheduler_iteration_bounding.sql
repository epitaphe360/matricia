-- MAT-FUNC-050: bound per-plan backlog work and resume from the latest occurrence.
create or replace function public.schedule_recurring_service_requests(p_as_of date default current_date,p_limit integer default 100) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare candidate record;plan_row public.recurring_service_plans%rowtype;version_row public.recurring_service_plan_versions%rowtype;generated jsonb;next_date date;last_date date;months integer;iterations integer;processed integer:=0;created integer:=0;skipped integer:=0;correlation uuid;
begin
 if auth.role()<>'service_role' then raise exception 'RECURRING_SCHEDULER_DENIED' using errcode='42501';end if;
 if p_as_of is null or p_as_of<current_date-1 or p_as_of>current_date+31 or p_limit not between 1 and 500 then raise exception 'INVALID_RECURRING_SCHEDULER_BOUNDS' using errcode='22023';end if;
 for candidate in
  select p.id,m.user_id actor_user_id
  from public.recurring_service_plans p
  join public.recurring_service_plan_versions v on v.plan_id=p.id and v.version_number=p.current_version and v.status='ACTIVE'
  join lateral(select om.user_id from public.organization_memberships om join public.organization_member_roles r on r.membership_id=om.id and r.revoked_at is null and r.role_code in('CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER') where om.organization_id=p.client_organization_id and om.status='ACTIVE' order by case r.role_code when'CLIENT_OWNER'then 1 when'CLIENT_ADMIN'then 2 else 3 end,om.user_id limit 1)m on true
  where p.status='ACTIVE'and v.starts_on<=p_as_of
  order by p.id limit p_limit
 loop
  processed:=processed+1;iterations:=0;perform pg_advisory_xact_lock(hashtextextended('recurring-plan:'||candidate.id::text,0));select * into plan_row from public.recurring_service_plans where id=candidate.id and status='ACTIVE' for update;if not found then skipped:=skipped+1;continue;end if;
  select * into version_row from public.recurring_service_plan_versions where plan_id=plan_row.id and version_number=plan_row.current_version and status='ACTIVE';months:=case version_row.cadence when'MONTHLY'then 1 when'QUARTERLY'then 3 when'ANNUALLY'then 12 else null end;if months is null then skipped:=skipped+1;continue;end if;
  select max(occurrence.scheduled_on)into last_date from public.recurring_service_occurrences occurrence where occurrence.plan_id=plan_row.id;
  next_date:=case when last_date is null then version_row.starts_on else(last_date+make_interval(months=>months))::date end;
  while next_date<=p_as_of and(version_row.ends_on is null or next_date<=version_row.ends_on)and iterations<24 loop
   iterations:=iterations+1;
   if not exists(select 1 from public.recurring_service_occurrences occurrence where occurrence.plan_id=plan_row.id and occurrence.scheduled_on=next_date)then
    generated:=private.clone_request_core(plan_row.template_request_id,next_date,candidate.actor_user_id,'Génération planifiée automatique',false);
    insert into public.recurring_service_occurrences(plan_id,plan_version_id,client_organization_id,scheduled_on,generated_request_id,generated_request_version_id)values(plan_row.id,version_row.id,plan_row.client_organization_id,next_date,(generated->>'request_id')::uuid,(generated->>'request_version_id')::uuid)on conflict(plan_id,scheduled_on)do nothing;
    if found then created:=created+1;correlation:=extensions.gen_random_uuid();insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(plan_row.client_organization_id,candidate.actor_user_id,'SYSTEM','recurring.requests.scheduled','recurring_service_plan',plan_row.id::text,correlation,jsonb_build_object('scheduled_on',next_date,'plan_version_id',version_row.id,'autonomous_invitations',false,'autonomous_spend',false),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(plan_row.client_organization_id,'recurring_service_plan',plan_row.id::text,'RecurringServiceRequestScheduledV1',correlation,jsonb_build_object('plan_id',plan_row.id,'request_id',generated->>'request_id','scheduled_on',next_date,'autonomous_invitations',false,'autonomous_spend',false),'recurring-scheduler:'||plan_row.id::text||':'||next_date::text)on conflict do nothing;end if;
   end if;
   next_date:=(next_date+make_interval(months=>months))::date;
  end loop;
 end loop;
 return jsonb_build_object('outcome','RECURRING_SCHEDULER_COMPLETED','as_of',p_as_of,'processed_plans',processed,'created_drafts',created,'skipped_plans',skipped,'per_plan_iteration_limit',24,'autonomous_invitations',false,'autonomous_spend',false);
end$$;
revoke all on function public.schedule_recurring_service_requests(date,integer) from public,anon,authenticated,service_role;
grant execute on function public.schedule_recurring_service_requests(date,integer) to service_role;
notify pgrst,'reload schema';
