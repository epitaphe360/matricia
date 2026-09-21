import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { createAssistedIntelligenceRepository } from "./repository";

export async function createServerAssistedIntelligenceRepository() {
  const client = await getSupabaseServerClient();
  return createAssistedIntelligenceRepository({
    async userId() {
      const { data } = await client.auth.getUser();
      return data.user?.id ?? null;
    },
    async memberships(userId) {
      return client.from("organization_memberships").select("id,organization_id").eq("user_id", userId).eq("status", "ACTIVE").limit(100);
    },
    async roles(membershipIds) {
      return membershipIds.length
        ? client.from("organization_member_roles").select("membership_id,role_code,revoked_at").in("membership_id", membershipIds).limit(300)
        : { data: [], error: null };
    },
    async organizations(organizationIds) {
      return organizationIds.length
        ? client.from("organizations").select("id,display_name").in("id", organizationIds).limit(100)
        : { data: [], error: null };
    },
    async models() {
      return client.from("assistance_model_versions").select("id,version,algorithm").eq("status", "ACTIVE").order("version", { ascending: false }).limit(1);
    },
    async requests() {
      return client.from("assistance_requests").select("id,organization_id,context_type,status,created_at,input_text_expires_at,input_text_redacted_at").order("created_at", { ascending: false }).limit(100);
    },
    async suggestions(requestIds) {
      return requestIds.length
        ? client.from("assistance_suggestions").select("id,request_id,organization_id,suggestion_kind,target_type,target_id,related_target_id,score_basis_points,explanation_code,explanation,proposed_payload,status,created_at,decided_at").in("request_id", requestIds).order("created_at", { ascending: false }).limit(300)
        : { data: [], error: null };
    },
    async decisions(suggestionIds) {
      return suggestionIds.length
        ? client.from("assistance_suggestion_decisions").select("id,suggestion_id,decision,rationale,decided_at").in("suggestion_id", suggestionIds).order("decided_at", { ascending: false }).limit(300)
        : { data: [], error: null };
    },
    async sessions(organizationIds) {
      return organizationIds.length
        ? client.from("questionnaire_sessions").select("organization_id,questionnaire_version_id").in("organization_id", organizationIds).eq("audience", "CLIENT").order("updated_at", { ascending: false }).limit(50)
        : { data: [], error: null };
    },
    async questionnaireQuestions(questionnaireVersionIds) {
      return questionnaireVersionIds.length
        ? client.from("questionnaire_version_questions").select("questionnaire_version_id,question_version_id").in("questionnaire_version_id", questionnaireVersionIds).order("sort_order").limit(50)
        : { data: [], error: null };
    },
    async questions(questionVersionIds) {
      return questionVersionIds.length
        ? client.from("question_versions").select("id,label_fr,label_ar,data_key").in("id", questionVersionIds).eq("status", "PUBLISHED").limit(50)
        : { data: [], error: null };
    },
    async recommendations(organizationIds) {
      return organizationIds.length
        ? client.from("diagnostic_recommendations").select("organization_id,service_id").in("organization_id", organizationIds).not("service_id", "is", null).order("created_at", { ascending: false }).limit(50)
        : { data: [], error: null };
    },
    async services(serviceIds) {
      return serviceIds.length
        ? client.from("catalog_services").select("id,current_published_version_id").in("id", serviceIds).limit(50)
        : { data: [], error: null };
    },
    async serviceVersions(serviceVersionIds) {
      return serviceVersionIds.length
        ? client.from("catalog_service_versions").select("id,service_id,name_fr,name_ar,code").in("id", serviceVersionIds).eq("status", "PUBLISHED").limit(50)
        : { data: [], error: null };
    },
    async anomalies(organizationIds) {
      return organizationIds.length
        ? client.from("diagnostic_anomalies").select("id,organization_id,anomaly_code,title_fr,title_ar,status").in("organization_id", organizationIds).order("created_at", { ascending: false }).limit(50)
        : { data: [], error: null };
    },
    async reassessments(organizationIds) {
      return organizationIds.length
        ? client.from("assistance_profile_reassessments").select("id,organization_id,changed_keys,status,created_at").in("organization_id", organizationIds).eq("status", "PENDING").order("created_at", { ascending: false }).limit(50)
        : { data: [], error: null };
    },
    async rpc(name, input) {
      return client.rpc(name, input);
    },
  });
}
