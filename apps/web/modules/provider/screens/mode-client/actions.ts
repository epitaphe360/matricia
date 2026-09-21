"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";

const input = z.object({
  locale: z.string().refine(isLocale),
  organizationId: z.string().uuid(),
  requestedRoleCode: z.literal("CLIENT_OWNER"),
  idempotencyKey: z.string().uuid(),
});

export type ModeClientActionState =
  | { status: "idle" }
  | { status: "success"; outcome: "ROLE_REQUESTED" | "ROLE_REQUEST_ALREADY_PENDING" }
  | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "UNAVAILABLE" };

export async function requestClientRole(
  _previous: ModeClientActionState,
  form: FormData,
): Promise<ModeClientActionState> {
  const parsed = input.safeParse({
    locale: form.get("locale"),
    organizationId: form.get("organizationId"),
    requestedRoleCode: form.get("requestedRoleCode"),
    idempotencyKey: form.get("idempotencyKey"),
  });
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };
  const client = await getSupabaseServerClient();
  const { data: { user }, error: authError } = await client.auth.getUser();
  if (authError || !user) return { status: "error", reason: "UNAUTHENTICATED" };
  const { data, error } = await client.rpc("request_additional_organization_role", {
    p_organization_id: parsed.data.organizationId,
    p_requested_role_code: parsed.data.requestedRoleCode,
    p_idempotency_key: parsed.data.idempotencyKey,
    p_correlation_id: randomUUID(),
  });
  if (error) return { status: "error", reason: "UNAVAILABLE" };
  const outcome = z.object({ outcome: z.enum(["ROLE_REQUESTED", "ROLE_REQUEST_ALREADY_PENDING"]) }).passthrough().safeParse(data);
  if (!outcome.success) return { status: "error", reason: "UNAVAILABLE" };
  revalidatePath(`/${parsed.data.locale}/sous-traitant/mode-client`);
  revalidatePath(`/${parsed.data.locale}/organisation/roles`);
  return { status: "success", outcome: outcome.data.outcome };
}
