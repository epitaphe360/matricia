import { getSupabaseServerClient } from "@/lib/supabase/server";
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
    async rpc(name, input) {
      return client.rpc(name, input);
    },
  });
}
