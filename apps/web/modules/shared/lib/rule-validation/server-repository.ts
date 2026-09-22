import { hasPlatformRole, loadMyPlatformAccess } from "@/modules/shared/lib/account-security/platform-access";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { createRuleValidationRepository } from "./repository";

export async function createServerRuleValidationRepository() {
  const client = await getSupabaseServerClient();
  let accessPromise: Promise<"AUTHORIZED" | "UNAUTHENTICATED" | "FORBIDDEN" | "UNAVAILABLE"> | undefined;
  return createRuleValidationRepository({
    async access() {
      accessPromise ??= (async () => {
        const access = await loadMyPlatformAccess();
        if (access.status === "error") return access.reason === "UNAUTHENTICATED" ? "UNAUTHENTICATED" as const : "UNAVAILABLE" as const;
        if (!hasPlatformRole(access.roles, ["SUPER_ADMIN", "MATRICIA_ADMIN", "LIBRARY_MANAGER"])) return "FORBIDDEN" as const;
        return access.requirementSatisfied ? "AUTHORIZED" as const : "FORBIDDEN" as const;
      })();
      return accessPromise;
    },
    async versions() {
      return client.from("questionnaire_versions")
        .select("id,version,status,title_fr,title_ar,audience,engine_version,policy_version,library_id,catalog_libraries!inner(code)")
        .order("created_at", { ascending: false })
        .limit(100);
    },
    async questions(questionnaireVersionId) {
      return client.from("questionnaire_version_questions")
        .select("questionnaire_version_id,sort_order,required_override,question_versions!inner(id,label_fr,label_ar,answer_type,data_key,required_by_default)")
        .eq("questionnaire_version_id", questionnaireVersionId)
        .order("sort_order")
        .limit(500);
    },
    async rpc(name, input) {
      return client.rpc(name, input);
    },
  });
}
