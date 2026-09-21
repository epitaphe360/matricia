import { z } from "zod";

const id = z.string().uuid();
const minor = z.string().regex(/^-?\d+$/u);

export const adminClosureDashboardSchema = z.object({
  generated_at: z.string().min(10),
  capabilities: z.object({ can_issue_statement: z.boolean() }),
  unstatemented: z.array(z.object({
    provider_organization_id: id, organization_name: z.string(), currency: z.string().length(3),
    event_count: z.number().int().nonnegative(), subtotal_minor: minor, tax_minor: minor, total_minor: minor,
  })),
  statements: z.array(z.object({
    id, provider_organization_id: id, organization_name: z.string(), statement_number: z.string(),
    period_start: z.string(), period_end: z.string(), currency: z.string().length(3), total_minor: minor, invoiced: z.boolean(),
  })),
  overdue_invoices: z.array(z.object({
    id, provider_organization_id: id, organization_name: z.string(), invoice_number: z.string(),
    due_on: z.string(), currency: z.string().length(3), outstanding_minor: minor,
    blocks_new_opportunities: z.boolean(),
  })),
});

export type AdminClosureDashboard = z.infer<typeof adminClosureDashboardSchema>;
export type AdminClosureErrorReason = "UNAUTHENTICATED" | "FORBIDDEN" | "UNAVAILABLE" | "INVALID_RESPONSE" | "INVALID_INPUT" | "CONFLICT";
export type AdminClosureResult<T> = { status: "success"; value: T } | { status: "error"; reason: AdminClosureErrorReason };
