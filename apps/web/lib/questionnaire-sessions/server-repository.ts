import { getSupabaseServerClient } from "@/lib/supabase/server";
import { createQuestionnaireSessionsRepository } from "./repository";

export async function createServerQuestionnaireSessionsRepository() {
  const client = await getSupabaseServerClient();
  return createQuestionnaireSessionsRepository({
    async user() { const { data, error } = await client.auth.getUser(); return error ? null : data.user?.id ?? null; },
    async memberships(userId) { return client.from("organization_memberships").select("id,organization_id").eq("user_id", userId).eq("status", "ACTIVE").limit(100); },
    async roles(ids) { return ids.length ? client.from("organization_member_roles").select("membership_id,role_code,revoked_at").in("membership_id", ids).in("role_code", ["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_BUYER"]).limit(300) : { data: [], error: null }; },
    async organizations(ids) { return ids.length ? client.from("organizations").select("id,display_name").in("id", ids).order("display_name").limit(100) : { data: [], error: null }; },
    async documents(ids) { return ids.length ? client.from("client_compliance_documents").select("id,organization_id,original_file_name,document_type,declared_mime_type,status").in("organization_id", ids).in("status", ["PENDING_REVIEW", "VERIFIED"]).order("updated_at", { ascending: false }).limit(100) : { data: [], error: null }; },
    async publishedVersions() { return client.from("questionnaire_versions").select("id,version,status,audience,title_fr,title_ar,description_fr,description_ar").eq("status", "PUBLISHED").eq("audience", "CLIENT").order("published_at", { ascending: false }).limit(50); },
    async sessions(userId) { return client.from("questionnaire_sessions").select("id,organization_id,actor_user_id,questionnaire_version_id,status,locale,updated_at,submitted_at,row_version").eq("actor_user_id", userId).eq("is_simulation", false).order("updated_at", { ascending: false }).limit(100); },
    async versions(ids) { return ids.length ? client.from("questionnaire_versions").select("id,version,status,audience,title_fr,title_ar,description_fr,description_ar").in("id", ids).limit(100) : { data: [], error: null }; },
    async session(id) { return client.from("questionnaire_sessions").select("id,organization_id,actor_user_id,questionnaire_version_id,status,locale,updated_at,submitted_at,row_version").eq("id", id).eq("is_simulation", false).limit(1); },
    async sections(versionId) { return client.from("questionnaire_sections").select("id,label_fr,label_ar,help_fr,help_ar,sort_order").eq("questionnaire_version_id", versionId).order("sort_order").limit(101); },
    async questionLinks(versionId) { return client.from("questionnaire_version_questions").select("section_id,question_version_id,sort_order,required_override").eq("questionnaire_version_id", versionId).order("sort_order").limit(101); },
    async questions(ids) { return ids.length ? client.from("question_versions").select("id,label_fr,label_ar,help_fr,help_ar,why_we_ask_fr,why_we_ask_ar,answer_type,required_by_default,options,validation_schema,structured_schema,nullable").in("id", ids).limit(100) : { data: [], error: null }; },
    async answers(sessionId) { return client.from("questionnaire_answers").select("id,question_version_id,current_revision_id,row_version").eq("session_id", sessionId).limit(100); },
    async revisions(ids) { return ids.length ? client.from("questionnaire_answer_revisions").select("id,value,answered_at,expires_at").in("id", ids).limit(100) : { data: [], error: null }; },
    async rpc(name, input) { return client.rpc(name, input); },
  });
}
