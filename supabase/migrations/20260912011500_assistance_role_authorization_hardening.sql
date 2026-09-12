-- P1 least-privilege authorization for assisted intelligence.

create function private.assistance_role_access(p_organization_id uuid,p_mode text,p_actor uuid default auth.uid())returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
 select p_actor is not null and case p_mode
  when'ANALYSE'then private.has_org_role(p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],p_actor)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],p_actor)
  when'DECIDE'then private.has_org_role(p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],p_actor)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],p_actor)
  when'READ'then private.has_org_role(p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],p_actor)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'],p_actor)
  when'INPUT'then private.has_org_role(p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],p_actor)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],p_actor)
  else false end
$$;

alter function public.run_assisted_analysis(uuid,text,text,uuid[],uuid[],text[],uuid,uuid,text,uuid)set schema private;
alter function private.run_assisted_analysis(uuid,text,text,uuid[],uuid[],text[],uuid,uuid,text,uuid)rename to run_assisted_analysis_runtime_v2;
revoke all on function private.run_assisted_analysis_runtime_v2(uuid,text,text,uuid[],uuid[],text[],uuid,uuid,text,uuid)from public,anon,authenticated,service_role;
create function public.run_assisted_analysis(p_organization_id uuid,p_context_type text,p_input_text text,p_candidate_service_version_ids uuid[],p_candidate_question_version_ids uuid[],p_known_data_keys text[],p_model_version_id uuid,p_profile_reassessment_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();begin if not private.assistance_role_access(p_organization_id,'ANALYSE',a)then raise exception'ASSISTANCE_ACCESS_DENIED'using errcode='42501';end if;return private.run_assisted_analysis_runtime_v2(p_organization_id,p_context_type,p_input_text,p_candidate_service_version_ids,p_candidate_question_version_ids,p_known_data_keys,p_model_version_id,p_profile_reassessment_id,p_idempotency_key,p_correlation_id);end$$;

alter function public.decide_assisted_suggestion(uuid,text,text,text,uuid)set schema private;
alter function private.decide_assisted_suggestion(uuid,text,text,text,uuid)rename to decide_assisted_suggestion_runtime_v2;
revoke all on function private.decide_assisted_suggestion_runtime_v2(uuid,text,text,text,uuid)from public,anon,authenticated,service_role;
create function public.decide_assisted_suggestion(p_suggestion_id uuid,p_decision text,p_rationale text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();org uuid;begin select organization_id into org from public.assistance_suggestions where id=p_suggestion_id;if org is null or not private.assistance_role_access(org,'DECIDE',a)then raise exception'ASSISTANCE_DECISION_DENIED'using errcode='42501';end if;return private.decide_assisted_suggestion_runtime_v2(p_suggestion_id,p_decision,p_rationale,p_idempotency_key,p_correlation_id);end$$;

alter function public.run_assisted_anomaly_similarity(uuid,uuid[],uuid,text,uuid)set schema private;
alter function private.run_assisted_anomaly_similarity(uuid,uuid[],uuid,text,uuid)rename to run_assisted_anomaly_similarity_runtime_v2;
revoke all on function private.run_assisted_anomaly_similarity_runtime_v2(uuid,uuid[],uuid,text,uuid)from public,anon,authenticated,service_role;
create function public.run_assisted_anomaly_similarity(p_organization_id uuid,p_candidate_anomaly_ids uuid[],p_model_version_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();begin if not private.assistance_role_access(p_organization_id,'ANALYSE',a)then raise exception'ASSISTANCE_ACCESS_DENIED'using errcode='42501';end if;return private.run_assisted_anomaly_similarity_runtime_v2(p_organization_id,p_candidate_anomaly_ids,p_model_version_id,p_idempotency_key,p_correlation_id);end$$;

create or replace function public.get_assistance_request_input(p_request_id uuid)returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();q public.assistance_requests%rowtype;r jsonb;begin select*into q from public.assistance_requests where id=p_request_id;if q.id is null or not private.assistance_role_access(q.organization_id,'INPUT',a)then raise exception'ASSISTANCE_INPUT_ACCESS_DENIED'using errcode='42501';end if;if q.input_text is null or q.input_text_redacted_at is not null or clock_timestamp()>=q.input_text_expires_at then return jsonb_build_object('request_id',q.id,'available',false);end if;r:=jsonb_build_object('request_id',q.id,'available',true,'input_text',q.input_text,'expires_at',q.input_text_expires_at);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(q.organization_id,a,'USER','assistance.input.viewed','assistance_request',q.id::text,extensions.gen_random_uuid(),jsonb_build_object('expires_at',q.input_text_expires_at),repeat('0',64));return r;end$$;

drop policy assistance_reassessments_tenant_read on public.assistance_profile_reassessments;
drop policy assistance_requests_tenant_read on public.assistance_requests;
drop policy assistance_suggestions_tenant_read on public.assistance_suggestions;
drop policy assistance_decisions_tenant_read on public.assistance_suggestion_decisions;
create policy assistance_reassessments_tenant_read on public.assistance_profile_reassessments for select to authenticated using(private.assistance_role_access(organization_id,'DECIDE'));
create policy assistance_requests_tenant_read on public.assistance_requests for select to authenticated using(private.assistance_role_access(organization_id,'READ'));
create policy assistance_suggestions_tenant_read on public.assistance_suggestions for select to authenticated using(private.assistance_role_access(organization_id,'READ'));
create policy assistance_decisions_tenant_read on public.assistance_suggestion_decisions for select to authenticated using(private.assistance_role_access(organization_id,'READ'));

revoke all on function private.assistance_role_access(uuid,text,uuid),private.run_assisted_analysis_runtime_v2(uuid,text,text,uuid[],uuid[],text[],uuid,uuid,text,uuid),private.decide_assisted_suggestion_runtime_v2(uuid,text,text,text,uuid),private.run_assisted_anomaly_similarity_runtime_v2(uuid,uuid[],uuid,text,uuid)from public,anon,authenticated,service_role;
revoke all on function public.run_assisted_analysis(uuid,text,text,uuid[],uuid[],text[],uuid,uuid,text,uuid),public.decide_assisted_suggestion(uuid,text,text,text,uuid),public.run_assisted_anomaly_similarity(uuid,uuid[],uuid,text,uuid),public.get_assistance_request_input(uuid)from public,anon,authenticated,service_role;
grant execute on function public.run_assisted_analysis(uuid,text,text,uuid[],uuid[],text[],uuid,uuid,text,uuid),public.decide_assisted_suggestion(uuid,text,text,text,uuid),public.run_assisted_anomaly_similarity(uuid,uuid[],uuid,text,uuid),public.get_assistance_request_input(uuid)to authenticated;
