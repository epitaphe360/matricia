"use server";

import { createHash, randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { outcomeSchema, uuidSchema } from "@/modules/shared/lib/disputes/model";

export type DomainActionState = { status: "idle" } | { status: "success" } | { status: "error"; reason: string };

const idleRoles = new Set(["SUPER_ADMIN", "MATRICIA_ADMIN", "DISPUTE_MANAGER"]);

async function platformCanDecide() {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { ok: false as const, reason: "UNAUTHENTICATED", client };
  const roles = await client.from("platform_user_roles").select("role_code").eq("user_id", auth.user.id).is("revoked_at", null).limit(20);
  if (roles.error) return { ok: false as const, reason: "UNAVAILABLE", client };
  const allowed = (roles.data ?? []).some((row) => idleRoles.has(String(row.role_code)));
  return allowed ? { ok: true as const, client } : { ok: false as const, reason: "FORBIDDEN", client };
}

export async function decideAdminDispute(_: DomainActionState, form: FormData): Promise<DomainActionState> {
  const parsed = z.object({
    locale: z.enum(["fr", "ar"]),
    caseId: uuidSchema,
    outcome: outcomeSchema,
    reason: z.string().trim().min(10).max(2000),
    ruleVersion: z.string().trim().min(1).max(80),
    evidenceIds: z.string().trim(),
    idempotencyKey: uuidSchema,
  }).safeParse({
    locale: form.get("locale"),
    caseId: form.get("caseId"),
    outcome: form.get("outcome"),
    reason: form.get("reason"),
    ruleVersion: form.get("ruleVersion") || "DISPUTE-RULE-V1",
    evidenceIds: form.get("evidenceIds") ?? "",
    idempotencyKey: form.get("idempotencyKey"),
  });
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };
  const evidenceIds = parsed.data.evidenceIds.split(/[\s,]+/).filter(Boolean);
  if (!evidenceIds.length || evidenceIds.some((id) => !uuidSchema.safeParse(id).success)) {
    return { status: "error", reason: "VALIDATION" };
  }
  const access = await platformCanDecide();
  if (!access.ok) return { status: "error", reason: access.reason };
  const contentHash = createHash("sha256").update(parsed.data.reason).digest("hex");
  const result = await access.client.rpc("decide_mission_dispute", {
    p_dispute_case_id: parsed.data.caseId,
    p_outcome: parsed.data.outcome,
    p_reason: parsed.data.reason,
    p_evidence_ids: evidenceIds,
    p_rule_snapshot: { version: parsed.data.ruleVersion, content_hash: contentHash },
    p_idempotency_key: parsed.data.idempotencyKey,
    p_correlation_id: randomUUID(),
  });
  if (result.error) return { status: "error", reason: result.error.code === "42501" ? "FORBIDDEN" : "UNAVAILABLE" };
  revalidatePath(`/${parsed.data.locale}/administration/litiges`);
  return { status: "success" };
}
