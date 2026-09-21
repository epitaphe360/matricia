import { z } from "zod";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";

const rowSchema = z.object({
  id: z.string().uuid(),
  code: z.enum(["PREMIUM", "GOLD", "PLATINUM"]),
  currency: z.string().regex(/^[A-Z]{3}$/u),
  monthly_price_minor: z.coerce.string().regex(/^\d+$/u),
  annual_price_minor: z.coerce.string().regex(/^\d+$/u),
  monthly_credit_grant: z.coerce.string().regex(/^\d+$/u),
});

export type PublicSubscriptionPlan = {
  id: string;
  code: "PREMIUM" | "GOLD" | "PLATINUM";
  currency: string;
  monthlyPriceMinor: string;
  annualPriceMinor: string;
  monthlyCreditGrant: string;
};

export async function loadPublicSubscriptionPlans(): Promise<{ status: "success"; plans: PublicSubscriptionPlan[] } | { status: "unavailable" }> {
  const client = await getSupabaseServerClient();
  const result = await client.rpc("get_public_subscription_plans");
  if (result.error) return { status: "unavailable" };
  const parsed = z.array(rowSchema).safeParse(result.data);
  if (!parsed.success) return { status: "unavailable" };
  return {
    status: "success",
    plans: parsed.data.map((plan) => ({
      id: plan.id,
      code: plan.code,
      currency: plan.currency,
      monthlyPriceMinor: plan.monthly_price_minor,
      annualPriceMinor: plan.annual_price_minor,
      monthlyCreditGrant: plan.monthly_credit_grant,
    })),
  };
}
