"use server";

import { revalidatePath } from "next/cache";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { planChangeSchema, subscriptionCommandSchema } from "@/lib/subscriptions/model";

export type SubscriptionActionState = { status: "idle" | "success" | "error" };
const value = (form: FormData, key: string) => String(form.get(key) ?? "").trim();

export async function ensureTrialAction(_: SubscriptionActionState, form: FormData): Promise<SubscriptionActionState> {
  const parsed = subscriptionCommandSchema.safeParse({
    locale: value(form, "locale"),
    organizationId: value(form, "organizationId"),
    idempotencyKey: value(form, "idempotencyKey"),
  });
  if (!parsed.success) return { status: "error" };
  const client = await getSupabaseServerClient();
  const { error } = await client.rpc("ensure_trial_subscription", {
    p_organization_id: parsed.data.organizationId,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) return { status: "error" };
  revalidatePath(`/${parsed.data.locale}/client/abonnement`);
  return { status: "success" };
}

export async function changePlanAction(_: SubscriptionActionState, form: FormData): Promise<SubscriptionActionState> {
  const parsed = planChangeSchema.safeParse({
    locale: value(form, "locale"),
    organizationId: value(form, "organizationId"),
    subscriptionId: value(form, "subscriptionId"),
    targetPlanVersionId: value(form, "targetPlanVersionId"),
    changeMode: value(form, "changeMode"),
    idempotencyKey: value(form, "idempotencyKey"),
  });
  if (!parsed.success) return { status: "error" };
  const client = await getSupabaseServerClient();
  const { error } = await client.rpc("change_subscription_plan", {
    p_subscription_id: parsed.data.subscriptionId,
    p_target_plan_version_id: parsed.data.targetPlanVersionId,
    p_change_mode: parsed.data.changeMode,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) return { status: "error" };
  revalidatePath(`/${parsed.data.locale}/client/abonnement`);
  return { status: "success" };
}
