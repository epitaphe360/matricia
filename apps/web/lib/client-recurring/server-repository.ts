import { getSupabaseServerClient } from "@/lib/supabase/server";
import { createClientRecurringRepository } from "./repository";

export async function createServerClientRecurringRepository() {
  const client = await getSupabaseServerClient();
  return createClientRecurringRepository({
    async user() { const { data, error } = await client.auth.getUser(); return error ? null : data.user?.id ?? null; },
    async requests() { return await client.from("service_requests").select("id,current_version_id,status,created_at").order("created_at", { ascending: false }).limit(200); },
    async requestVersions(ids) { return ids.length === 0 ? { data: [], error: null } : await client.from("service_request_versions").select("id,request_id,version_number,description,desired_date").in("request_id", ids).order("version_number", { ascending: false }).limit(400); },
    async plans() { return await client.from("recurring_service_plans").select("id,template_request_id,status,current_version,row_version,updated_at").order("updated_at", { ascending: false }).limit(100); },
    async planVersions(ids) { return ids.length === 0 ? { data: [], error: null } : await client.from("recurring_service_plan_versions").select("id,plan_id,version_number,cadence,starts_on,ends_on,status,reason").in("plan_id", ids).order("version_number", { ascending: false }).limit(500); },
    async occurrences(ids) { return ids.length === 0 ? { data: [], error: null } : await client.from("recurring_service_occurrences").select("id,plan_id,scheduled_on,generated_request_id,created_at").in("plan_id", ids).order("scheduled_on", { ascending: false }).limit(2400); },
    async rpc(name, input) { return await client.rpc(name, input); },
  });
}

