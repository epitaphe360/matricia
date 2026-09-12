import { z } from "zod";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import type { SubscriptionDashboard } from "./model";

const uuid = z.string().uuid();
const exactInteger = z.string().regex(/^\d+$/);
const membershipSchema = z.object({
  organization_id: uuid,
  organizations: z.object({ display_name: z.string().min(1) }),
  organization_member_roles: z.array(z.object({ role_code: z.enum(["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_ACCOUNTING", "CLIENT_VIEWER"]) })).min(1),
});
const planSchema = z.object({
  id: uuid,
  version: z.number().int().positive(),
  currency: z.string().regex(/^[A-Z]{3}$/),
  monthly_price_minor: exactInteger,
  annual_price_minor: exactInteger,
  monthly_credit_grant: exactInteger,
  valid_from: z.string(),
  valid_to: z.string().nullable(),
  subscription_plans: z.object({ code: z.enum(["PREMIUM", "GOLD", "PLATINUM"]) }),
});
const subscriptionSchema = z.object({
  id: uuid,
  status: z.string(),
  plan_version_id: uuid.nullable(),
  pending_plan_version_id: uuid.nullable(),
  billing_interval: z.string().nullable(),
  current_period_end: z.string().nullable(),
  pending_change_effective_at: z.string().nullable(),
  row_version: exactInteger,
});
const cycleSchema = z.object({
  id: uuid,
  cycle_number: z.number().int().positive(),
  currency: z.string().regex(/^[A-Z]{3}$/),
  amount_minor: exactInteger,
  period_end: z.string(),
});
const transitionSchema = z.object({ id: exactInteger, from_status: z.string().nullable(), to_status: z.string(), reason_code: z.string(), occurred_at: z.string() });

export async function loadSubscriptionDashboard(): Promise<
  | { status: "success"; dashboard: SubscriptionDashboard }
  | { status: "error"; reason: "UNAUTHENTICATED" | "NO_CLIENT_ORGANIZATION" | "QUERY_FAILED" | "INVALID_RESPONSE" }
> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const membership = await client
    .from("organization_memberships")
    .select("organization_id,organizations!inner(display_name),organization_member_roles!inner(role_code,revoked_at)")
    .eq("user_id", auth.user.id)
    .eq("status", "ACTIVE")
    .is("organization_member_roles.revoked_at", null)
    .in("organization_member_roles.role_code", ["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_ACCOUNTING", "CLIENT_VIEWER"])
    .limit(1)
    .maybeSingle();
  if (membership.error) return { status: "error", reason: "QUERY_FAILED" };
  const parsedMembership = membershipSchema.safeParse(membership.data);
  if (!parsedMembership.success) {
    return { status: "error", reason: membership.data ? "INVALID_RESPONSE" : "NO_CLIENT_ORGANIZATION" };
  }
  const organizationId = parsedMembership.data.organization_id;
  const [plansResult, subscriptionResult] = await Promise.all([
    client
      .from("subscription_plan_versions")
      .select("id,version,currency,monthly_price_minor::text,annual_price_minor::text,monthly_credit_grant::text,valid_from,valid_to,subscription_plans!inner(code)")
      .eq("status", "ACTIVE")
      .order("monthly_price_minor"),
    client
      .from("subscriptions")
      .select("id,status,plan_version_id,pending_plan_version_id,billing_interval,current_period_end,pending_change_effective_at,row_version::text")
      .eq("organization_id", organizationId)
      .maybeSingle(),
  ]);
  if (plansResult.error || subscriptionResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const plans = z.array(planSchema).safeParse(plansResult.data);
  const subscription = subscriptionResult.data ? subscriptionSchema.safeParse(subscriptionResult.data) : null;
  if (!plans.success || (subscription && !subscription.success)) return { status: "error", reason: "INVALID_RESPONSE" };
  const subscriptionValue = subscription?.data ?? null;
  const [cyclesResult, transitionsResult] = subscriptionValue ? await Promise.all([
    client.from("subscription_cycles").select("id,cycle_number,currency,amount_minor::text,period_end").eq("subscription_id", subscriptionValue.id).order("cycle_number", { ascending: false }).limit(24),
    client.from("subscription_state_events").select("id::text,from_status,to_status,reason_code,occurred_at").eq("subscription_id", subscriptionValue.id).order("occurred_at", { ascending: false }).limit(50),
  ]) : [{ data: [], error: null }, { data: [], error: null }];
  if (cyclesResult.error || transitionsResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const cycles = z.array(cycleSchema).safeParse(cyclesResult.data);
  const transitions = z.array(transitionSchema).safeParse(transitionsResult.data);
  if (!cycles.success || !transitions.success) return { status: "error", reason: "INVALID_RESPONSE" };
  const roles = parsedMembership.data.organization_member_roles.map((role) => role.role_code);
  return {
    status: "success",
    dashboard: {
      organizationId,
      organizationName: parsedMembership.data.organizations.display_name,
      capabilities: { canStartTrial: roles.some((role) => role === "CLIENT_OWNER" || role === "CLIENT_ADMIN"), canChangePlan: roles.some((role) => role === "CLIENT_OWNER" || role === "CLIENT_ADMIN") },
      plans: plans.data.map((plan) => ({
        id: plan.id,
        code: plan.subscription_plans.code,
        version: plan.version,
        currency: plan.currency,
        monthlyPriceMinor: plan.monthly_price_minor,
        annualPriceMinor: plan.annual_price_minor,
        monthlyCreditGrant: plan.monthly_credit_grant,
        validFrom: plan.valid_from,
        validTo: plan.valid_to,
      })),
      subscription: subscriptionValue ? {
        id: subscriptionValue.id,
        status: subscriptionValue.status,
        planVersionId: subscriptionValue.plan_version_id,
        pendingPlanVersionId: subscriptionValue.pending_plan_version_id,
        billingInterval: subscriptionValue.billing_interval,
        currentPeriodEnd: subscriptionValue.current_period_end,
        pendingChangeEffectiveAt: subscriptionValue.pending_change_effective_at,
        rowVersion: subscriptionValue.row_version,
        cycles: cycles.data.map((cycle) => ({
          id: cycle.id,
          cycleNumber: cycle.cycle_number,
          currency: cycle.currency,
          amountMinor: cycle.amount_minor,
          periodEnd: cycle.period_end,
        })),
        transitions: transitions.data.map((event) => ({ id: event.id, fromStatus: event.from_status, toStatus: event.to_status, reasonCode: event.reason_code, occurredAt: event.occurred_at })),
      } : null,
    },
  };
}
