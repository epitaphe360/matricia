import { z } from "zod";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { createDisputesRepository } from "./repository";

export type DisputeParty = "client" | "provider";

export async function createServerDisputesRepository(requestedOrganizationId?: string, party: DisputeParty = "client") {
  const c = await getSupabaseServerClient();
  const organizationId = z.string().uuid().safeParse(requestedOrganizationId).success ? requestedOrganizationId : null;
  const organizationColumn = party === "provider" ? "provider_organization_id" : "client_organization_id";
  return createDisputesRepository({
    async userId() { const { data } = await c.auth.getUser(); return data.user?.id ?? null; },
    async memberships(id) { return c.from("organization_memberships").select("id,organization_id").eq("user_id", id).eq("status", "ACTIVE").limit(100); },
    async orgRoles(ids) { return ids.length ? c.from("organization_member_roles").select("membership_id,role_code,revoked_at").in("membership_id", ids).limit(300) : { data: [], error: null }; },
    async missions() { let q = c.from("missions").select("id,status").in("status", ["ACTIVE", "DELIVERY_SUBMITTED", "ACCEPTANCE_IN_PROGRESS"]); if (organizationId) q = q.eq(organizationColumn, organizationId); return q.order("created_at", { ascending: false }).limit(200); },
    async cases(id) { let q = c.from("dispute_cases").select("id,mission_id,client_organization_id,provider_organization_id,obligation_key,description,urgency,status,policy_snapshot,response_due_at,review_due_at,appeal_due_at,row_version"); if (organizationId) q = q.eq(organizationColumn, organizationId); if (id) q = q.eq("id", id); return q.order("opened_at", { ascending: false }).limit(200); },
    async evidence(ids) { return ids.length ? c.from("dispute_evidence").select("id,dispute_case_id,evidence_type,statement,url,evidence_hash,visibility,created_at").in("dispute_case_id", ids).order("created_at").limit(1000) : { data: [], error: null }; },
    async responses(ids) { return ids.length ? c.from("dispute_responses").select("id,dispute_case_id,response_type,statement,submitted_at").in("dispute_case_id", ids).order("submitted_at").limit(200) : { data: [], error: null }; },
    async decisions(ids) { return ids.length ? c.from("dispute_decisions").select("id,dispute_case_id,decision_number,outcome,reason,evidence_ids,rule_snapshot,decided_at").in("dispute_case_id", ids).order("decision_number").limit(200) : { data: [], error: null }; },
    async appeals(ids) { return ids.length ? c.from("dispute_appeals").select("id,dispute_case_id,grounds,submitted_at").in("dispute_case_id", ids).limit(200) : { data: [], error: null }; },
    async events(ids) { return ids.length ? c.from("dispute_case_events").select("id,dispute_case_id,event_type,from_status,to_status,created_at").in("dispute_case_id", ids).order("created_at").limit(1000) : { data: [], error: null }; },
    async reassignments(ids) { return ids.length ? c.from("mission_reassignments").select("id,dispute_case_id,reassignment_key,status,original_cost_minor,proposed_cost_minor,cost_delta_minor,currency,row_version").in("dispute_case_id", ids).limit(200) : { data: [], error: null }; },
    async rpc(name, input) { return c.rpc(name, input); },
  });
}
