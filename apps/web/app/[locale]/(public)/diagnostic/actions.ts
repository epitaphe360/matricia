"use server";

import { createHash, randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { getSupabaseServerClient } from "@/lib/supabase/server";

const answersSchema = z.object({
  goals: z.array(z.enum(["save_time", "control_costs", "grow_sales", "secure_activity", "global_review"])).min(1).max(5),
  sector: z.enum(["professional_services", "commerce", "construction", "industry_logistics", "other"]),
  team_size: z.enum(["solo", "small", "medium", "large"]),
  priority_tracking: z.enum(["regular", "partial", "no", "unknown"]),
  sales_tracking: z.enum(["shared", "manual", "ad_hoc", "unknown"]),
  backup_restore: z.enum(["recent", "old", "no", "unknown", "not_applicable"]),
  decision_trace: z.enum(["systematic", "partial", "no", "unknown"]),
  next_action: z.string().trim().min(3).max(500),
}).strict();
const inputSchema = z.object({ locale: z.enum(["fr", "ar"]), organizationId: z.string().uuid(), answers: z.string().max(8192) });
export type SaveIntakeState = { status: "idle" } | { status: "success"; intakeId: string } | { status: "error"; reason: "VALIDATION" | "FORBIDDEN" | "UNAVAILABLE" };

export async function savePublicDiagnosticIntake(_: SaveIntakeState, formData: FormData): Promise<SaveIntakeState> {
  const input = inputSchema.safeParse({ locale: formData.get("locale"), organizationId: formData.get("organizationId"), answers: formData.get("answers") });
  if (!input.success) return { status: "error", reason: "VALIDATION" };
  let raw: unknown;
  try { raw = JSON.parse(input.data.answers); } catch { return { status: "error", reason: "VALIDATION" }; }
  const answers = answersSchema.safeParse(raw);
  if (!answers.success) return { status: "error", reason: "VALIDATION" };
  const canonical = JSON.stringify(answers.data);
  const idempotencyKey = createHash("sha256").update(`${input.data.organizationId}:${canonical}`).digest("hex");
  const client = await getSupabaseServerClient();
  const result = await client.rpc("save_public_diagnostic_intake", { p_organization_id: input.data.organizationId, p_answers: answers.data, p_locale: input.data.locale, p_idempotency_key: idempotencyKey, p_correlation_id: randomUUID() });
  if (result.error) return { status: "error", reason: result.error.code === "42501" ? "FORBIDDEN" : "UNAVAILABLE" };
  const response = z.object({ outcome: z.literal("PUBLIC_DIAGNOSTIC_INTAKE_SAVED"), intake_id: z.string().uuid(), status: z.literal("INDICATIVE") }).passthrough().safeParse(result.data);
  if (!response.success) return { status: "error", reason: "UNAVAILABLE" };
  revalidatePath(`/${input.data.locale}/client/diagnostics`);
  return { status: "success", intakeId: response.data.intake_id };
}
