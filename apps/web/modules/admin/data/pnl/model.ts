import { z } from "zod";

const id = z.string().uuid();
const minor = z.string().regex(/^-?\d+$/u);

export const adminPnlDashboardSchema = z.object({
  generated_at: z.string().min(10),
  capabilities: z.object({ can_close: z.boolean() }),
  rules: z.array(z.object({
    id, franchise_type: z.enum(["IT", "STANDARD"]), version: z.number().int().positive(),
    franchisee_share_bps: z.number().int(), neoxa_share_bps: z.number().int(), asma_share_bps: z.number().int(),
    effective_from: z.string().min(8),
  })),
  books: z.array(z.object({
    id, library_id: id, library_code: z.string(), franchise_organization_id: id, organization_name: z.string(),
    franchise_type: z.enum(["IT", "STANDARD"]), operator_code: z.string(), currency: z.string().length(3),
    status: z.string(), rule_version_id: id,
    latest_closure: z.object({
      id, period_start: z.string(), period_end: z.string(), version: z.number().int().positive(),
      gross_revenue_ex_tax_minor: minor, costs_and_refunds_minor: minor, distributable_profit_minor: minor, closed_at: z.string(),
    }).nullable(),
    allocations: z.array(z.object({ beneficiary_code: z.string(), share_bps: z.number().int(), amount_minor: minor })),
  })),
});

export type AdminPnlDashboard = z.infer<typeof adminPnlDashboardSchema>;
export type AdminPnlErrorReason = "UNAUTHENTICATED" | "FORBIDDEN" | "UNAVAILABLE" | "INVALID_RESPONSE" | "INVALID_INPUT" | "CONFLICT";
export type AdminPnlResult<T> = { status: "success"; value: T } | { status: "error"; reason: AdminPnlErrorReason };
