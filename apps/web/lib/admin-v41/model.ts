import { z } from "zod";

export const adminV41Modules = ["procurement","supplier_ap","own_payments","treasury","finops","margins","signature","privacy","third_parties","incidents","operations","contracts_disputes","catalog_marketing"] as const;
export type AdminV41Module = (typeof adminV41Modules)[number];

const count = z.number().int().nonnegative();
export const adminV41OverviewSchema = z.object({
  generated_at: z.string().datetime({ offset: true }),
  limit: z.number().int().min(1).max(100),
  financial_flows: z.object({ client_to_provider_declared: count, matricia_own_revenue: count, provider_commission_receipts: count }).strict(),
  modules: z.array(z.object({ key: z.enum(adminV41Modules), open: count, exceptions: count }).strict()).length(adminV41Modules.length),
}).strict();

export type AdminV41Overview = z.infer<typeof adminV41OverviewSchema>;
export type AdminV41Result = { status:"success"; value:AdminV41Overview } | { status:"error"; reason:"UNAUTHENTICATED"|"FORBIDDEN"|"UNAVAILABLE"|"INVALID_RESPONSE" };
