-- P10 additive hardening: CRM PII is scoped to the operator and exact territory.
create function private.franchise_crm_row_access(p_franchise_id uuid,p_territory_version_id uuid,p_actor uuid default auth.uid())returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
 select p_actor is not null and exists(
  select 1 from public.franchises f
  join public.franchise_territory_versions t on t.franchise_id=f.id and t.id=p_territory_version_id
  where f.id=p_franchise_id and(
   private.has_org_role(f.operator_organization_id,array['FRANCHISE_OWNER','FRANCHISE_MANAGER','FRANCHISE_VIEWER'],p_actor)
   or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],p_actor)
  )
 )
$$;

create function private.guard_franchise_crm_owner_membership()returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$
declare operator_org uuid;
begin
 select f.operator_organization_id into operator_org from public.franchises f where f.id=new.franchise_id;
 if operator_org is null or not exists(
  select 1 from public.organization_memberships m
  where m.organization_id=operator_org and m.user_id=new.owner_user_id and m.status='ACTIVE'
 )then raise exception'FRANCHISE_CRM_OWNER_NOT_ACTIVE_MEMBER'using errcode='23514';end if;
 return new;
end$$;
create trigger franchise_crm_owner_membership_guard before insert or update of franchise_id,owner_user_id on public.franchise_crm_prospects for each row execute function private.guard_franchise_crm_owner_membership();

create function private.valid_franchise_performance_measurements(p_measurements jsonb)returns boolean language sql immutable set search_path=pg_catalog as $$
 select jsonb_typeof(p_measurements)='array'
  and jsonb_array_length(p_measurements)between 1 and 100
  and not exists(
   select 1 from jsonb_array_elements(p_measurements)m
   where jsonb_typeof(m)<>'object'
    or (select array_agg(k order by k)from jsonb_object_keys(m)k)<>array['denominator','evidence_refs','metric_version_id','numerator']::text[]
    or coalesce(m->>'metric_version_id','')!~'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    or coalesce(m->>'numerator','')!~'^\d{1,19}$'
    or coalesce(m->>'denominator','')!~'^\d{1,19}$'
    or (m->>'numerator')::numeric>9223372036854775807
    or (m->>'denominator')::numeric>9223372036854775807
    or (m->>'denominator')::numeric<=0
    or jsonb_typeof(m->'evidence_refs')<>'array'
    or jsonb_array_length(m->'evidence_refs')>50
  )
  and not exists(select 1 from jsonb_array_elements(p_measurements)m group by m->>'metric_version_id'having count(*)>1)
$$;
create function private.guard_franchise_performance_measurements()returns trigger language plpgsql set search_path=pg_catalog,private as $$begin if not private.valid_franchise_performance_measurements(new.measurements_snapshot)then raise exception'INVALID_PERFORMANCE_MEASUREMENT_SCHEMA'using errcode='23514';end if;return new;end$$;
create trigger franchise_performance_measurements_guard before insert on public.franchise_performance_score_snapshots for each row execute function private.guard_franchise_performance_measurements();

drop policy franchise_prospects_scoped_read on public.franchise_crm_prospects;
drop policy franchise_activities_scoped_read on public.franchise_crm_activities;
drop policy franchise_pipeline_scoped_read on public.franchise_pipeline_events;
create policy franchise_prospects_operator_territory_read on public.franchise_crm_prospects for select to authenticated using(private.franchise_crm_row_access(franchise_id,territory_version_id));
create policy franchise_activities_operator_territory_read on public.franchise_crm_activities for select to authenticated using(exists(select 1 from public.franchise_crm_prospects p where p.id=prospect_id and p.franchise_id=franchise_id and private.franchise_crm_row_access(p.franchise_id,p.territory_version_id)));
create policy franchise_pipeline_operator_territory_read on public.franchise_pipeline_events for select to authenticated using(exists(select 1 from public.franchise_crm_prospects p where p.id=prospect_id and p.franchise_id=franchise_id and private.franchise_crm_row_access(p.franchise_id,p.territory_version_id)));

create function public.list_franchise_crm_aggregate_metrics(p_franchise_id uuid,p_territory_version_id uuid)returns jsonb language plpgsql stable security definer set search_path=pg_catalog,public,private as $$
declare a uuid:=auth.uid();result jsonb;
begin
 if a is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'],a)then raise exception'FRANCHISE_CRM_AGGREGATE_DENIED'using errcode='42501';end if;
 if not exists(select 1 from public.franchise_territory_versions t where t.id=p_territory_version_id and t.franchise_id=p_franchise_id)then raise exception'FRANCHISE_TERRITORY_NOT_FOUND'using errcode='P0002';end if;
 select jsonb_build_object(
  'franchise_id',p_franchise_id,'territory_version_id',p_territory_version_id,
  'total_prospects',count(*),
  'client_prospects',count(*)filter(where p.prospect_type='CLIENT'),
  'provider_prospects',count(*)filter(where p.prospect_type='PROVIDER'),
  'overdue_followups',count(*)filter(where p.next_followup_at<clock_timestamp()),
  'pipeline',coalesce((select jsonb_object_agg(x.pipeline_stage,x.stage_count)from(select q.pipeline_stage,count(*)stage_count from public.franchise_crm_prospects q where q.franchise_id=p_franchise_id and q.territory_version_id=p_territory_version_id group by q.pipeline_stage)x),'{}'::jsonb),
  'activity_count',(select count(*)from public.franchise_crm_activities a2 join public.franchise_crm_prospects q on q.id=a2.prospect_id where q.franchise_id=p_franchise_id and q.territory_version_id=p_territory_version_id)
 )into result from public.franchise_crm_prospects p where p.franchise_id=p_franchise_id and p.territory_version_id=p_territory_version_id;
 return result;
end$$;

revoke all on function private.franchise_crm_row_access(uuid,uuid,uuid),private.guard_franchise_crm_owner_membership(),private.valid_franchise_performance_measurements(jsonb),private.guard_franchise_performance_measurements()from public,anon,authenticated,service_role;
grant execute on function private.franchise_crm_row_access(uuid,uuid,uuid)to authenticated;
revoke all on function public.list_franchise_crm_aggregate_metrics(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.list_franchise_crm_aggregate_metrics(uuid,uuid)to authenticated;
notify pgrst,'reload schema';
