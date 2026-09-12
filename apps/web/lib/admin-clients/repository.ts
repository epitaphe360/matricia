import { z } from "zod";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { ADMIN_CLIENT_LIMITS, type AdminClientsDashboard } from "./model";

const security = z.object({
  requirement_satisfied: z.boolean(),
  matched_role_codes: z.array(z.string()),
}).passthrough();
const documentProjection = z.object({
  id: z.string().uuid(), type: z.string(), version: z.number().int().positive(),
  status: z.string(), scan_status: z.string(), expires_on: z.string().nullable(), can_review: z.boolean(),
});
const questionProjection = z.object({
  id: z.string().uuid(), text: z.string(), due_at: z.string(), status: z.string(),
  response_version: z.number().int().positive().nullable(), response_submitted_at: z.string().nullable(),
  can_review: z.boolean(),
});
const caseProjection = z.object({
  id: z.string().uuid(), organization_name: z.string().min(1), status: z.string(),
  profile_version: z.number().int().positive().nullable(), submitted_at: z.string().nullable(),
  updated_at: z.string(), public_reason: z.string().nullable(), can_decide: z.boolean(),
  documents: z.array(documentProjection).max(ADMIN_CLIENT_LIMITS.documents),
  questions: z.array(questionProjection).max(ADMIN_CLIENT_LIMITS.questions),
});
const projection = z.object({
  capabilities: z.object({ can_act: z.boolean(), read_only: z.boolean() }),
  cases: z.array(caseProjection).max(ADMIN_CLIENT_LIMITS.cases),
  limits_reached: z.array(z.enum(["cases", "documents", "questions"])),
});
type Result = { status: "success"; dashboard: AdminClientsDashboard } | { status: "error"; reason: "UNAUTHENTICATED" | "MFA_REQUIRED" | "FORBIDDEN" | "QUERY_FAILED" | "INVALID_RESPONSE" };

export async function loadAdminClients(locale: "fr" | "ar"): Promise<Result> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const securityResult = await client.rpc("get_my_account_security_requirement");
  if (securityResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const requirements = z.array(security).safeParse(securityResult.data);
  if (!requirements.success || requirements.data.length !== 1) return { status: "error", reason: "INVALID_RESPONSE" };
  if (!requirements.data[0]!.matched_role_codes.some((role) => ["SUPER_ADMIN", "MATRICIA_ADMIN", "COMPLIANCE_MANAGER", "READ_ONLY_AUDITOR"].includes(role))) return { status: "error", reason: "FORBIDDEN" };
  if (!requirements.data[0]!.requirement_satisfied) return { status: "error", reason: "MFA_REQUIRED" };
  const result = await client.rpc("get_admin_client_compliance_projection", { p_locale: locale, p_limit: ADMIN_CLIENT_LIMITS.cases });
  if (result.error) return { status: "error", reason: result.error.code === "42501" ? "FORBIDDEN" : "QUERY_FAILED" };
  const parsed = projection.safeParse(result.data);
  if (!parsed.success) return { status: "error", reason: "INVALID_RESPONSE" };
  return {
    status: "success",
    dashboard: {
      capabilities: { canAct: parsed.data.capabilities.can_act, readOnly: parsed.data.capabilities.read_only },
      limitsReached: parsed.data.limits_reached,
      cases: parsed.data.cases.map((item) => ({
        id: item.id, organizationName: item.organization_name, status: item.status,
        profileVersion: item.profile_version, submittedAt: item.submitted_at,
        updatedAt: item.updated_at, publicReason: item.public_reason, canDecide: item.can_decide,
        documents: item.documents.map((document) => ({
          id: document.id, type: document.type, version: document.version, status: document.status,
          scanStatus: document.scan_status, expiresOn: document.expires_on, canReview: document.can_review,
        })),
        questions: item.questions.map((question) => ({
          id: question.id, text: question.text, dueAt: question.due_at, status: question.status,
          responseVersion: question.response_version, responseSubmittedAt: question.response_submitted_at,
          canReview: question.can_review,
        })),
      })),
    },
  };
}
