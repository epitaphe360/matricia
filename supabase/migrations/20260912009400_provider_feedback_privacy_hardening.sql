-- Additive privacy hardening for MAT-FUNC-015/016/048.
-- Raw feedback remains available only to platform reviewers; Providers receive a minimal projection.

drop policy if exists provider_feedback_recipient_read on public.provider_feedback_snapshots;
create policy provider_feedback_recipient_read on public.provider_feedback_snapshots for select to authenticated
using(provider_organization_id is not null and private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy provider_feedback_platform_review_read on public.provider_feedback_snapshots for select to authenticated
using(private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));

create policy provider_feedback_outbox_privacy_guard on public.event_outbox as restrictive for select to authenticated
using(event_type<>'ProviderFeedbackPublishedV1' or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));

create or replace function private.sanitize_provider_feedback_outbox() returns trigger language plpgsql security definer set search_path=pg_catalog as $$
begin
 if new.event_type='ProviderFeedbackPublishedV1' then
  new.aggregate_type:='provider_feedback_notice';
  new.aggregate_id:='anonymous-feedback';
  new.payload:=jsonb_build_object(
   'feedback_available',true,
   'ranking_position',case when (new.payload->>'ranking_position')~'^[1-9][0-9]*$' then (new.payload->>'ranking_position')::integer end,
   'ranked_quote_count',case when (new.payload->>'ranked_quote_count')~'^[1-9][0-9]*$' then (new.payload->>'ranked_quote_count')::integer end
  );
 end if;
 return new;
end$$;
revoke all on function private.sanitize_provider_feedback_outbox() from public,anon,authenticated,service_role;
create trigger provider_feedback_outbox_payload_guard before insert on public.event_outbox for each row
when(new.event_type='ProviderFeedbackPublishedV1') execute function private.sanitize_provider_feedback_outbox();

create or replace function public.list_my_anonymized_provider_feedback(p_limit integer default 50,p_before timestamptz default null)
returns table(ranking_position integer,ranked_quote_count integer,improvement_axes jsonb,methodology_version text,published_at timestamptz)
language plpgsql stable security definer set search_path=pg_catalog,public,private as $$
declare v_actor uuid:=auth.uid();
begin
 if v_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';end if;
 if p_limit not between 1 and 100 then raise exception 'INVALID_FEEDBACK_PAGE_SIZE' using errcode='22023';end if;
 return query
 select f.ranking_position,f.ranked_quote_count,f.improvement_axes,f.methodology_version,f.published_at
 from public.provider_feedback_snapshots f
 where private.has_org_role(f.provider_organization_id,array['PROVIDER_OWNER','PROVIDER_MANAGER','PROVIDER_SALES','PROVIDER_VIEWER'],v_actor)
 and(p_before is null or f.published_at<p_before)
 order by f.published_at desc
 limit p_limit;
end$$;
revoke all on function public.list_my_anonymized_provider_feedback(integer,timestamptz) from public,anon,service_role;
grant execute on function public.list_my_anonymized_provider_feedback(integer,timestamptz) to authenticated;

create or replace function private.valid_provider_reputation_evidence(p_provider_organization_id uuid,p_service_id uuid,p_refs jsonb) returns boolean
language plpgsql stable security definer set search_path=pg_catalog,public as $$
declare v_ref jsonb;v_type text;v_id uuid;
begin
 if p_refs is null or jsonb_typeof(p_refs)<>'array' or jsonb_array_length(p_refs)<1 or jsonb_array_length(p_refs)>100 then return false;end if;
 if(select count(*)<>count(distinct jsonb_build_array(value->>'type',value->>'id'))from jsonb_array_elements(p_refs))then return false;end if;
 for v_ref in select value from jsonb_array_elements(p_refs) loop
  if jsonb_typeof(v_ref)<>'object' or exists(select 1 from jsonb_object_keys(v_ref)k where k not in('type','id')) or coalesce(v_ref->>'type','')not in('MISSION','PROVIDER_PERFORMANCE_EVENT','PROVIDER_FEEDBACK') or coalesce(v_ref->>'id','')!~'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then return false;end if;
  v_type:=v_ref->>'type';v_id:=(v_ref->>'id')::uuid;
  if v_type='MISSION' and not exists(
   select 1 from public.missions m join public.contract_versions cv on cv.id=m.contract_version_id join public.quote_versions qv on qv.id=cv.selected_quote_version_id join public.quotes q on q.id=qv.quote_id join public.rfqs r on r.id=q.rfq_id join public.service_requests sr on sr.id=r.request_id
   where m.id=v_id and m.provider_organization_id=p_provider_organization_id and m.status='COMPLETED' and(p_service_id is null or sr.service_id=p_service_id)
  )then return false;
  elsif v_type='PROVIDER_PERFORMANCE_EVENT' and not exists(
   select 1 from public.provider_performance_events pe join public.missions m on m.id=pe.mission_id join public.contract_versions cv on cv.id=m.contract_version_id join public.quote_versions qv on qv.id=cv.selected_quote_version_id join public.quotes q on q.id=qv.quote_id join public.rfqs r on r.id=q.rfq_id join public.service_requests sr on sr.id=r.request_id
   where pe.id=v_id and pe.provider_organization_id=p_provider_organization_id and(p_service_id is null or sr.service_id=p_service_id)
  )then return false;
  elsif v_type='PROVIDER_FEEDBACK' and not exists(
   select 1 from public.provider_feedback_snapshots f join public.rfqs r on r.id=f.rfq_id join public.service_requests sr on sr.id=r.request_id
   where f.id=v_id and f.provider_organization_id=p_provider_organization_id and(p_service_id is null or sr.service_id=p_service_id)
  )then return false;
  end if;
 end loop;
 return true;
exception when invalid_text_representation then return false;
end$$;
revoke all on function private.valid_provider_reputation_evidence(uuid,uuid,jsonb) from public,anon,authenticated,service_role;

alter function public.calculate_provider_reputation(uuid,uuid,jsonb,jsonb,text,text,uuid) set schema private;
revoke all on function private.calculate_provider_reputation(uuid,uuid,jsonb,jsonb,text,text,uuid) from public,anon,authenticated,service_role;
create function public.calculate_provider_reputation(p_provider_organization_id uuid,p_service_id uuid,p_dimensions jsonb,p_evidence_refs jsonb,p_policy_version text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare v_actor uuid:=auth.uid();
begin
 if not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],v_actor)then raise exception 'HUMAN_REPUTATION_REVIEW_REQUIRED' using errcode='42501';end if;
 if not private.valid_provider_reputation_evidence(p_provider_organization_id,p_service_id,p_evidence_refs)then raise exception 'REPUTATION_EVIDENCE_INVALID_OR_CROSS_TENANT' using errcode='22023';end if;
 -- The guarded implementation persists overall_basis_points with INTEGER_WEIGHTED_AVERAGE_BASIS_POINTS,
 -- evidence_refs and full explanation, then writes audit_events and event_outbox atomically.
 return private.calculate_provider_reputation(p_provider_organization_id,p_service_id,p_dimensions,p_evidence_refs,p_policy_version,p_idempotency_key,p_correlation_id);
end$$;
revoke all on function public.calculate_provider_reputation(uuid,uuid,jsonb,jsonb,text,text,uuid) from public,anon,service_role;
grant execute on function public.calculate_provider_reputation(uuid,uuid,jsonb,jsonb,text,text,uuid) to authenticated;

alter function public.publish_not_selected_feedback(uuid,jsonb,text,uuid,text,uuid) set schema private;
revoke all on function private.publish_not_selected_feedback(uuid,jsonb,text,uuid,text,uuid) from public,anon,authenticated,service_role;
create function public.publish_not_selected_feedback(p_quote_id uuid,p_improvement_axes jsonb,p_methodology_version text,p_comparison_snapshot_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare v_actor uuid:=auth.uid();
begin
 if v_actor is null or not exists(select 1 from public.quotes q join public.rfqs r on r.id=q.rfq_id join public.service_requests sr on sr.id=r.request_id where q.id=p_quote_id and(private.has_org_role(sr.client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],v_actor)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],v_actor)))then raise exception 'FEEDBACK_ACCESS_DENIED' using errcode='42501';end if;
 -- Guarded implementation enforces NOT_SELECTED, FEEDBACK_REQUIRES_COMPLETED_SELECTION and ranking_position,
 -- then writes audit_events and the sanitized event_outbox notice atomically.
 return private.publish_not_selected_feedback(p_quote_id,p_improvement_axes,p_methodology_version,p_comparison_snapshot_id,p_idempotency_key,p_correlation_id);
end$$;
revoke all on function public.publish_not_selected_feedback(uuid,jsonb,text,uuid,text,uuid) from public,anon,service_role;
grant execute on function public.publish_not_selected_feedback(uuid,jsonb,text,uuid,text,uuid) to authenticated;

alter function public.revalidate_provider_favorite(uuid,uuid,text,uuid) set schema private;
revoke all on function private.revalidate_provider_favorite(uuid,uuid,text,uuid) from public,anon,authenticated,service_role;
create function public.revalidate_provider_favorite(p_favorite_id uuid,p_request_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare v_actor uuid:=auth.uid();
begin
 if v_actor is null or not exists(select 1 from public.client_provider_favorites f where f.id=p_favorite_id and private.has_org_role(f.client_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],v_actor))then raise exception 'FAVORITE_ACCESS_DENIED' using errcode='42501';end if;
 -- Guarded implementation invokes current_provider_service_eligibility, persists reasons,
 -- emits audit_events/event_outbox and retains INACTIVE_PROVIDER_FAVORITE/FAVORITE_SERVICE_MISMATCH checks.
 return private.revalidate_provider_favorite(p_favorite_id,p_request_id,p_idempotency_key,p_correlation_id);
end$$;
revoke all on function public.revalidate_provider_favorite(uuid,uuid,text,uuid) from public,anon,service_role;
grant execute on function public.revalidate_provider_favorite(uuid,uuid,text,uuid) to authenticated;
