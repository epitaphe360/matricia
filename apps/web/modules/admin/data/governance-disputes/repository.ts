import { z } from "zod";
import { loadFranchiseDashboard } from "@/modules/franchise/data/governance/repository";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import type { AdminGovernanceResult } from "./model";

const uuid = z.string().uuid();
const platformRole = z.object({ role_code: z.string() }).strict();
const disputeCase = z.object({ id: uuid, mission_id: uuid, obligation_key: z.string(), urgency: z.enum(["STANDARD", "URGENT"]), status: z.string(), policy_snapshot: z.record(z.string(), z.unknown()), response_due_at: z.string(), review_due_at: z.string().nullable(), opened_by: uuid }).strict();
const decision = z.object({ dispute_case_id: uuid, decision_number: z.number().int().positive(), outcome: z.string(), reason: z.string(), evidence_ids: z.array(uuid), rule_snapshot: z.record(z.string(), z.unknown()), decided_by: uuid, decided_at: z.string() }).strict();
const reassignment = z.object({ dispute_case_id: uuid, reassignment_key: z.string(), status: z.string(), original_cost_minor: z.union([z.string(), z.number().int().safe()]), proposed_cost_minor: z.union([z.string(), z.number().int().safe()]).nullable(), cost_delta_minor: z.union([z.string(), z.number().int().safe()]).nullable(), currency: z.string().length(3), client_cost_approved_by: uuid.nullable(), replacement_contract_id: uuid.nullable(), replacement_mission_id: uuid.nullable() }).strict();
const consequence = z.object({ dispute_case_id: uuid, consequence_type: z.string(), direction: z.enum(["ACCRUAL", "REVERSAL"]), amount_minor: z.union([z.string(), z.number().int().safe()]), currency: z.string().length(3) }).strict();
const approvalRequest = z.object({ id: uuid, requested_by: uuid }).strict();
const approvalDecision = z.object({ approval_request_id: uuid, decided_by: uuid }).strict();

const governanceRoles = new Set(["SUPER_ADMIN", "MATRICIA_ADMIN", "FINANCE_MANAGER", "LIBRARY_MANAGER", "READ_ONLY_AUDITOR"]);
const financeRoles = new Set(["SUPER_ADMIN", "MATRICIA_ADMIN", "FINANCE_MANAGER", "READ_ONLY_AUDITOR"]);
const disputeRoles = new Set(["SUPER_ADMIN", "MATRICIA_ADMIN", "DISPUTE_MANAGER", "READ_ONLY_AUDITOR"]);

function error(reason: "UNAUTHENTICATED" | "FORBIDDEN" | "UNAVAILABLE" | "INVALID_RESPONSE"): AdminGovernanceResult {
  return { status: "error", reason };
}

export async function loadAdminGovernanceDashboard(locale: "fr" | "ar"): Promise<AdminGovernanceResult> {
  const client = await getSupabaseServerClient();
  const { data: auth, error: authError } = await client.auth.getUser();
  if (authError || !auth.user) return error("UNAUTHENTICATED");
  const roleQuery = await client.from("platform_user_roles").select("role_code").eq("user_id", auth.user.id).is("revoked_at", null).limit(20);
  if (roleQuery.error) return error("UNAVAILABLE");
  const parsedRoles = z.array(platformRole).max(20).safeParse(roleQuery.data);
  if (!parsedRoles.success) return error("INVALID_RESPONSE");
  const roles = new Set(parsedRoles.data.map(value => value.role_code));
  const canGovern = [...roles].some(role => governanceRoles.has(role));
  const canFinance = [...roles].some(role => financeRoles.has(role));
  const canDispute = [...roles].some(role => disputeRoles.has(role));
  if (!canGovern && !canDispute) return error("FORBIDDEN");

  const franchiseResult = canGovern ? await loadFranchiseDashboard(locale) : null;
  if (franchiseResult?.status === "error") return error(franchiseResult.reason === "INVALID_RESPONSE" ? "INVALID_RESPONSE" : "UNAVAILABLE");

  const approvalRequestsQuery = canGovern
    ? await client.from("franchise_approval_requests").select("id,requested_by").order("requested_at", { ascending: false }).limit(200)
    : { data: [], error: null };
  const approvalDecisionsQuery = canGovern
    ? await client.from("franchise_approval_decisions").select("approval_request_id,decided_by").order("decided_at", { ascending: false }).limit(200)
    : { data: [], error: null };
  const approvalRequests = z.array(approvalRequest).max(200).safeParse(approvalRequestsQuery.data);
  const approvalDecisions = z.array(approvalDecision).max(200).safeParse(approvalDecisionsQuery.data);
  if (approvalRequestsQuery.error || approvalDecisionsQuery.error || !approvalRequests.success || !approvalDecisions.success) return error("UNAVAILABLE");

  const casesQuery = canDispute
    ? await client.from("dispute_cases").select("id,mission_id,obligation_key,urgency,status,policy_snapshot,response_due_at,review_due_at,opened_by").order("opened_at", { ascending: false }).limit(200)
    : { data: [], error: null };
  const cases = z.array(disputeCase).max(200).safeParse(casesQuery.data);
  if (casesQuery.error || !cases.success) return error("UNAVAILABLE");
  const caseIds = cases.data.map(value => value.id);
  const [decisionsQuery, reassignmentsQuery, consequencesQuery] = caseIds.length === 0 ? [
    { data: [], error: null }, { data: [], error: null }, { data: [], error: null },
  ] : await Promise.all([
    client.from("dispute_decisions").select("dispute_case_id,decision_number,outcome,reason,evidence_ids,rule_snapshot,decided_by,decided_at").in("dispute_case_id", caseIds).order("decision_number", { ascending: false }).limit(400),
    client.from("mission_reassignments").select("dispute_case_id,reassignment_key,status,original_cost_minor,proposed_cost_minor,cost_delta_minor,currency,client_cost_approved_by,replacement_contract_id,replacement_mission_id").in("dispute_case_id", caseIds).limit(200),
    client.from("dispute_financial_consequences").select("dispute_case_id,consequence_type,direction,amount_minor,currency").in("dispute_case_id", caseIds).limit(400),
  ]);
  const decisions = z.array(decision).max(400).safeParse(decisionsQuery.data);
  const reassignments = z.array(reassignment).max(200).safeParse(reassignmentsQuery.data);
  const consequences = z.array(consequence).max(400).safeParse(consequencesQuery.data);
  if (decisionsQuery.error || reassignmentsQuery.error || consequencesQuery.error || !decisions.success || !reassignments.success || !consequences.success) return error("UNAVAILABLE");

  return { status: "success", value: {
    capabilities: { governance: canGovern, finance: canFinance, disputes: canDispute, canApproveGovernance: roles.has("SUPER_ADMIN") || roles.has("MATRICIA_ADMIN"), fourEyesRequired: true },
    franchise: franchiseResult?.status === "success" ? franchiseResult.dashboard : null,
    approvalSeparation: approvalRequests.data.map(request => {
      const review = approvalDecisions.data.find(value => value.approval_request_id === request.id);
      return { approvalRequestId: request.id, hasDecision: Boolean(review), independentReviewer: review ? review.decided_by !== request.requested_by : null };
    }),
    disputes: cases.data.map(item => {
      const latestDecision = decisions.data.find(value => value.dispute_case_id === item.id) ?? null;
      const replacement = reassignments.data.find(value => value.dispute_case_id === item.id) ?? null;
      return {
        id: item.id, missionId: item.mission_id, obligationKey: item.obligation_key, urgency: item.urgency, status: item.status,
        policyVersion: String(item.policy_snapshot.version ?? "—"), responseDueAt: item.response_due_at, reviewDueAt: item.review_due_at,
        latestDecision: latestDecision ? { number: latestDecision.decision_number, outcome: latestDecision.outcome, reason: latestDecision.reason, evidenceCount: latestDecision.evidence_ids.length, ruleVersion: String(latestDecision.rule_snapshot.version ?? "—"), decidedAt: latestDecision.decided_at, independentReviewer: latestDecision.decided_by !== item.opened_by } : null,
        reassignment: replacement ? { key: replacement.reassignment_key, status: replacement.status, originalCostMinor: String(replacement.original_cost_minor), proposedCostMinor: replacement.proposed_cost_minor === null ? null : String(replacement.proposed_cost_minor), costDeltaMinor: replacement.cost_delta_minor === null ? null : String(replacement.cost_delta_minor), currency: replacement.currency, clientCostApproved: replacement.client_cost_approved_by !== null, replacementContractId: replacement.replacement_contract_id, replacementMissionId: replacement.replacement_mission_id } : null,
        consequences: consequences.data.filter(value => value.dispute_case_id === item.id).map(value => ({ type: value.consequence_type, direction: value.direction, amountMinor: String(value.amount_minor), currency: value.currency })),
      };
    }),
  } };
}
