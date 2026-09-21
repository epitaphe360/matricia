import { z } from "zod";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import type { MoroccoTaxDashboard } from "./model";

const uuid = z.string().uuid();
const payloadSchema = z.object({
  categories: z.array(z.object({ code: z.string(), name_fr: z.string(), name_ar: z.string(), category_kind: z.string(), requires_source_rule: z.boolean() })),
  rules: z.array(z.object({ id: uuid, category_code: z.string(), version: z.number().int(), rate_basis_points: z.number().int(), status: z.string(), professional_validation_status: z.string(), rule_type: z.string(), effective_from: z.string(), effective_to: z.string().nullable(), legal_reference: z.string(), row_version: z.number().int() })),
});
const membershipSchema = z.object({ organization_id: uuid });

export async function loadMoroccoTaxDashboard(): Promise<{ status: "success"; dashboard: MoroccoTaxDashboard } | { status: "error"; reason: "UNAUTHENTICATED" | "FORBIDDEN" | "AAL2_REQUIRED" | "QUERY_FAILED" | "INVALID_RESPONSE" }> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const membership = await client.from("organization_memberships").select("organization_id").eq("user_id", auth.user.id).eq("status", "ACTIVE").limit(1).maybeSingle();
  if (membership.error) return { status: "error", reason: "QUERY_FAILED" };
  const parsedMembership = membershipSchema.safeParse(membership.data);
  if (!parsedMembership.success) return { status: "error", reason: "FORBIDDEN" };
  const result = await client.rpc("list_morocco_tax_rules");
  if (result.error) {
    if (result.error.code === "42501" && /AAL2/i.test(result.error.message ?? "")) return { status: "error", reason: "AAL2_REQUIRED" };
    if (result.error.code === "42501") return { status: "error", reason: "FORBIDDEN" };
    return { status: "error", reason: "QUERY_FAILED" };
  }
  const parsed = payloadSchema.safeParse(result.data);
  if (!parsed.success) return { status: "error", reason: "INVALID_RESPONSE" };
  return { status: "success", dashboard: { organizationId: parsedMembership.data.organization_id, categories: parsed.data.categories.map((item) => ({ code: item.code, nameFr: item.name_fr, nameAr: item.name_ar, kind: item.category_kind, requiresSourceRule: item.requires_source_rule })), rules: parsed.data.rules.map((item) => ({ id: item.id, categoryCode: item.category_code, version: item.version, rateBasisPoints: item.rate_basis_points, status: item.status, validationStatus: item.professional_validation_status, ruleType: item.rule_type, effectiveFrom: item.effective_from, effectiveTo: item.effective_to, legalReference: item.legal_reference, rowVersion: item.row_version })) } };
}
