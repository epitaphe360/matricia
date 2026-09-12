import { getSupabaseServerClient } from "@/lib/supabase/server";
import { createRuleValidationRepository } from "./repository";

export async function createServerRuleValidationRepository() {
  const client = await getSupabaseServerClient();
  let accessPromise: Promise<"AUTHORIZED" | "UNAUTHENTICATED" | "FORBIDDEN" | "UNAVAILABLE"> | undefined;
  return createRuleValidationRepository({
    async access() {
      accessPromise ??= (async () => {
        const { data, error } = await client.auth.getUser();
        if (error || !data.user) return "UNAUTHENTICATED" as const;
        const role = await client.from("platform_user_roles").select("role_code").eq("user_id", data.user.id).is("revoked_at", null).in("role_code", ["SUPER_ADMIN", "MATRICIA_ADMIN", "LIBRARY_MANAGER"]).limit(1).maybeSingle();
        if (role.error) return "UNAVAILABLE" as const;
        return role.data ? "AUTHORIZED" as const : "FORBIDDEN" as const;
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
