import { z } from "zod";

export const subscriptionCommandSchema = z.object({
  locale: z.enum(["fr", "ar"]),
  organizationId: z.string().uuid(),
  idempotencyKey: z.string().uuid(),
});

export const planChangeSchema = subscriptionCommandSchema.extend({
  subscriptionId: z.string().uuid(),
  targetPlanVersionId: z.string().uuid(),
  changeMode: z.enum(["UPGRADE_IMMEDIATE", "DOWNGRADE_NEXT_CYCLE"]),
});

export type SubscriptionPlan = {
  id: string;
  code: "PREMIUM" | "GOLD" | "PLATINUM";
  version: number;
  currency: string;
  monthlyPriceMinor: string;
  annualPriceMinor: string;
};

export type SubscriptionSummary = {
  id: string;
  status: string;
  planVersionId: string | null;
  pendingPlanVersionId: string | null;
  billingInterval: string | null;
  currentPeriodEnd: string | null;
  cycles: Array<{
    id: string;
    cycleNumber: number;
    currency: string;
    amountMinor: string;
    periodEnd: string;
  }>;
};

export type SubscriptionDashboard = {
  organizationId: string;
  organizationName: string;
  plans: SubscriptionPlan[];
  subscription: SubscriptionSummary | null;
};

export function formatMinor(value: string, currency: string, locale: "fr" | "ar") {
  const amount = BigInt(value);
  const hundred = BigInt(100);
  const major = amount / hundred;
  const minor = (amount % hundred).toString().padStart(2, "0");
  return `${major.toLocaleString(locale === "ar" ? "ar-MA" : "fr-MA")},${minor} ${currency}`;
}
