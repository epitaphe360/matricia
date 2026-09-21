"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";

export type ApprovalActionState =
  | { status: "idle" }
  | { status: "success" }
  | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "FORBIDDEN" | "CONFLICT" | "FAILED" };

const input = z.object({
  approvalRequestId: z.string().uuid(),
  rowVersion: z.coerce.number().int().positive(),
  decision: z.enum(["APPROVE", "REJECT"]),
  reason: z.string().trim().min(3).max(1000),
  idempotencyKey: z.string().uuid(),
});

export async function decideClientApproval(_previous: ApprovalActionState, form: FormData): Promise<ApprovalActionState> {
  if (!isLocale(String(form.get("locale") ?? ""))) return { status: "error", reason: "VALIDATION" };
  const parsed = input.safeParse({
    approvalRequestId: form.get("approvalRequestId"),
    rowVersion: form.get("rowVersion"),
    decision: form.get("decision"),
    reason: form.get("reason"),
    idempotencyKey: form.get("idempotencyKey"),
  });
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const result = await client.rpc("decide_business_approval", {
    p_approval_request_id: parsed.data.approvalRequestId,
    p_expected_row_version: parsed.data.rowVersion,
    p_decision: parsed.data.decision,
    p_reason: parsed.data.reason,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  if (result.error) {
    if (result.error.code === "42501") return { status: "error", reason: "FORBIDDEN" };
    if (result.error.code === "40001") return { status: "error", reason: "CONFLICT" };
    return { status: "error", reason: "FAILED" };
  }
  revalidatePath(`/${String(form.get("locale"))}/client/actions`);
  return { status: "success" };
}
