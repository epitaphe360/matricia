import { z } from "zod";

export const adminFinanceUuid = z.string().uuid();
export const exactMinor = z.string().regex(/^\d+$/u).refine((value) => BigInt(value) <= BigInt("9223372036854775807"));
const timestamp = z.string().min(10);
const currency = z.string().regex(/^[A-Z]{3}$/u);
const organization = { organization_id: adminFinanceUuid, organization_name: z.string().min(1).max(300) };

export const adminFinanceDashboardSchema = z.object({
  as_of: timestamp,
  payment_intents: z.array(z.object({ id: adminFinanceUuid, ...organization, plan_version_id: adminFinanceUuid, billing_interval: z.enum(["MONTHLY", "ANNUAL"]), gateway: z.enum(["DEMO", "CMI", "PAYPAL"]), amount_minor: exactMinor, currency, status: z.enum(["PENDING_VERIFICATION", "ACTIVATED"]), created_at: timestamp }).strict()).max(200),
  payment_events: z.array(z.object({ id: exactMinor, payment_intent_id: adminFinanceUuid, ...organization, gateway: z.enum(["DEMO", "CMI", "PAYPAL"]), event_type: z.literal("PAYMENT_SUCCEEDED"), amount_minor: exactMinor, currency, paid_at: timestamp, received_at: timestamp }).strict()).max(200),
  subscriptions: z.array(z.object({ id: adminFinanceUuid, ...organization, status: z.enum(["TRIAL_ACTIVE", "TRIAL_EXPIRED", "ACTIVE", "PAST_DUE", "SUSPENDED", "CANCELLED"]), plan_code: z.enum(["PREMIUM", "GOLD", "PLATINUM"]).nullable(), billing_interval: z.enum(["MONTHLY", "ANNUAL"]).nullable(), current_period_start: timestamp.nullable(), current_period_end: timestamp.nullable(), pending_plan_version_id: adminFinanceUuid.nullable(), pending_change_effective_at: timestamp.nullable(), row_version: exactMinor, updated_at: timestamp }).strict()).max(200),
  cycles: z.array(z.object({ id: adminFinanceUuid, subscription_id: adminFinanceUuid, ...organization, plan_code: z.enum(["PREMIUM", "GOLD", "PLATINUM"]), cycle_number: z.number().int().positive(), period_start: timestamp, period_end: timestamp, currency, amount_minor: exactMinor, created_at: timestamp }).strict()).max(200),
  provider_payments: z.array(z.object({ id: adminFinanceUuid, ...organization, payment_reference: z.string().min(3).max(200), currency, amount_minor: exactMinor, allocated_minor: exactMinor, unallocated_minor: exactMinor, paid_on: z.string().min(10) }).strict()).max(200),
  provider_invoices: z.array(z.object({ id: adminFinanceUuid, ...organization, invoice_number: z.string().min(3).max(80), currency, total_minor: exactMinor, paid_minor: exactMinor, outstanding_minor: exactMinor, payment_status: z.enum(["ISSUED", "PARTIALLY_PAID", "PAID", "OVERDUE", "PAYMENT_PLAN"]), due_on: z.string().min(10) }).strict()).max(200),
}).strict();

export const reconciliationSchema = z.object({ paymentId: adminFinanceUuid, invoiceId: adminFinanceUuid, amountMinor: exactMinor.refine((value) => BigInt(value) > BigInt(0)), idempotencyKey: adminFinanceUuid, correlationId: adminFinanceUuid }).strict();
export type AdminFinanceDashboard = z.infer<typeof adminFinanceDashboardSchema>;
export type AdminFinanceError = "UNAUTHENTICATED" | "MFA_REQUIRED" | "FORBIDDEN" | "INVALID_INPUT" | "INVALID_RESPONSE" | "CONFLICT" | "UNAVAILABLE";
export type AdminFinanceResult<T> = { status: "success"; value: T } | { status: "error"; reason: AdminFinanceError };
