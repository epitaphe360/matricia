-- MAT-FUNC-041/042: align database commands with the Client capabilities exposed by Web.
-- Existing runtime functions retain their transactions, idempotency, audit and Outbox behavior.

alter function public.run_assisted_analysis(uuid,text,text,uuid[],uuid[],text[],uuid,uuid,text,uuid) set schema private;
alter function private.run_assisted_analysis(uuid,text,text,uuid[],uuid[],text[],uuid,uuid,text,uuid) rename to run_assisted_analysis_runtime_v3;
alter function public.run_assisted_anomaly_similarity(uuid,uuid[],uuid,text,uuid) set schema private;
alter function private.run_assisted_anomaly_similarity(uuid,uuid[],uuid,text,uuid) rename to run_assisted_anomaly_similarity_runtime_v3;
alter function public.decide_assisted_suggestion(uuid,text,text,text,uuid) set schema private;
alter function private.decide_assisted_suggestion(uuid,text,text,text,uuid) rename to decide_assisted_suggestion_runtime_v3;

revoke all on function private.run_assisted_analysis_runtime_v3(uuid,text,text,uuid[],uuid[],text[],uuid,uuid,text,uuid),
 private.run_assisted_anomaly_similarity_runtime_v3(uuid,uuid[],uuid,text,uuid),
 private.decide_assisted_suggestion_runtime_v3(uuid,text,text,text,uuid)
from public,anon,authenticated,service_role;

create function public.run_assisted_analysis(
 p_organization_id uuid,p_context_type text,p_input_text text,p_candidate_service_version_ids uuid[],
 p_candidate_question_version_ids uuid[],p_known_data_keys text[],p_model_version_id uuid,
 p_profile_reassessment_id uuid,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare v_actor uuid:=auth.uid();
begin
 if v_actor is null or not(
  private.has_org_role(p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],v_actor)
  or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],v_actor)
 ) then raise exception 'ASSISTANCE_ACCESS_DENIED' using errcode='42501'; end if;
 return private.run_assisted_analysis_runtime_v3(p_organization_id,p_context_type,p_input_text,p_candidate_service_version_ids,p_candidate_question_version_ids,p_known_data_keys,p_model_version_id,p_profile_reassessment_id,p_idempotency_key,p_correlation_id);
end$$;

create function public.run_assisted_anomaly_similarity(
 p_organization_id uuid,p_candidate_anomaly_ids uuid[],p_model_version_id uuid,
 p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare v_actor uuid:=auth.uid();
begin
 if v_actor is null or not(
  private.has_org_role(p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],v_actor)
  or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],v_actor)
 ) then raise exception 'ASSISTANCE_ACCESS_DENIED' using errcode='42501'; end if;
 return private.run_assisted_anomaly_similarity_runtime_v3(p_organization_id,p_candidate_anomaly_ids,p_model_version_id,p_idempotency_key,p_correlation_id);
end$$;

create function public.decide_assisted_suggestion(
 p_suggestion_id uuid,p_decision text,p_rationale text,p_idempotency_key text,
 p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare v_actor uuid:=auth.uid();v_organization_id uuid;
begin
 select organization_id into v_organization_id from public.assistance_suggestions where id=p_suggestion_id;
 if v_actor is null or v_organization_id is null or not(
  private.has_org_role(v_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],v_actor)
  or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],v_actor)
 ) then raise exception 'ASSISTANCE_DECISION_DENIED' using errcode='42501'; end if;
 return private.decide_assisted_suggestion_runtime_v3(p_suggestion_id,p_decision,p_rationale,p_idempotency_key,p_correlation_id);
end$$;

revoke all on function public.run_assisted_analysis(uuid,text,text,uuid[],uuid[],text[],uuid,uuid,text,uuid),
 public.run_assisted_anomaly_similarity(uuid,uuid[],uuid,text,uuid),
 public.decide_assisted_suggestion(uuid,text,text,text,uuid)
from public,anon,service_role;
grant execute on function public.run_assisted_analysis(uuid,text,text,uuid[],uuid[],text[],uuid,uuid,text,uuid),
 public.run_assisted_anomaly_similarity(uuid,uuid[],uuid,text,uuid),
 public.decide_assisted_suggestion(uuid,text,text,text,uuid)
to authenticated;

notify pgrst,'reload schema';
