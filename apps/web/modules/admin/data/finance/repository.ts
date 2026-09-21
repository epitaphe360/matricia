import { z } from "zod";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { adminFinanceDashboardSchema, adminFinanceUuid, exactMinor, reconciliationSchema, type AdminFinanceDashboard, type AdminFinanceResult } from "./model";

const roleRow = z.object({ role_code: z.enum(["SUPER_ADMIN", "MATRICIA_ADMIN", "FINANCE_MANAGER"]) }).strict();
const paymentRow = z.object({ id: adminFinanceUuid, provider_organization_id: adminFinanceUuid, currency: z.string().regex(/^[A-Z]{3}$/u), amount_minor: exactMinor }).strict();
const allocationRow = z.object({ amount_minor: exactMinor }).strict();
const invoiceRow = z.object({ id: adminFinanceUuid, provider_organization_id: adminFinanceUuid, currency: z.string().regex(/^[A-Z]{3}$/u), outstanding_minor: exactMinor }).strict();
const reconciliationOutput = z.object({ outcome: z.literal("PROVIDER_PAYMENT_RECONCILED"), payment_id: adminFinanceUuid, reconciliation_batch_id: adminFinanceUuid, allocated_minor: z.union([exactMinor, z.number().int().positive()]), unallocated_minor: z.union([exactMinor, z.number().int().nonnegative()]) }).passthrough();
const platformRoles = ["SUPER_ADMIN", "MATRICIA_ADMIN", "FINANCE_MANAGER"] as const;

async function authorizedClient() {
  const client = await getSupabaseServerClient();
  const { data: auth, error } = await client.auth.getUser();
  if (error || !auth.user) return { status: "error", reason: "UNAUTHENTICATED" } as const;
  const rolesQuery = await client.from("platform_user_roles").select("role_code").eq("user_id", auth.user.id).is("revoked_at", null).in("role_code", [...platformRoles]).limit(10);
  if (rolesQuery.error) return { status: "error", reason: "UNAVAILABLE" } as const;
  const roles = z.array(roleRow).max(10).safeParse(rolesQuery.data);
  if (!roles.success) return { status: "error", reason: "INVALID_RESPONSE" } as const;
  if (roles.data.length === 0) return { status: "error", reason: "FORBIDDEN" } as const;
  return { status: "success", client } as const;
}

export async function loadAdminFinanceDashboard(): Promise<AdminFinanceResult<AdminFinanceDashboard>> {
  const access = await authorizedClient();
  if (access.status === "error") return access;
  const response = await access.client.rpc("list_admin_finance_dashboard", { p_limit: 100 });
  if (response.error) return { status: "error", reason: response.error.code === "42501" ? "FORBIDDEN" : "UNAVAILABLE" };
  const parsed = adminFinanceDashboardSchema.safeParse(response.data);
  if (!parsed.success) return { status: "error", reason: "INVALID_RESPONSE" };
  if (parsed.data.provider_payments.some((payment) => BigInt(payment.allocated_minor) + BigInt(payment.unallocated_minor) !== BigInt(payment.amount_minor))) return { status: "error", reason: "INVALID_RESPONSE" };
  return { status: "success", value: parsed.data };
}

export async function reconcileAdminProviderPayment(input: unknown): Promise<AdminFinanceResult<{ batchId: string }>> {
  const parsed = reconciliationSchema.safeParse(input);
  if (!parsed.success) return { status: "error", reason: "INVALID_INPUT" };
  const access = await authorizedClient();
  if (access.status === "error") return access;
  const value = parsed.data;
  const [paymentQuery, allocationsQuery, invoiceQuery] = await Promise.all([
    access.client.from("provider_payments").select("id,provider_organization_id,currency,amount_minor::text").eq("id", value.paymentId).limit(1).maybeSingle(),
    access.client.from("provider_payment_allocations").select("amount_minor::text").eq("payment_id", value.paymentId).limit(200),
    access.client.from("provider_invoice_balances").select("id,provider_organization_id,currency,outstanding_minor::text").eq("id", value.invoiceId).limit(1).maybeSingle(),
  ]);
  if (paymentQuery.error || allocationsQuery.error || invoiceQuery.error) return { status: "error", reason: "UNAVAILABLE" };
  const payment = paymentRow.safeParse(paymentQuery.data), allocations = z.array(allocationRow).max(200).safeParse(allocationsQuery.data), invoice = invoiceRow.safeParse(invoiceQuery.data);
  if (!payment.success || !allocations.success || !invoice.success) return { status: "error", reason: "INVALID_INPUT" };
  if (payment.data.provider_organization_id !== invoice.data.provider_organization_id || payment.data.currency !== invoice.data.currency) return { status: "error", reason: "INVALID_INPUT" };
  const allocated = allocations.data.reduce((total, item) => total + BigInt(item.amount_minor), BigInt(0));
  const amount = BigInt(value.amountMinor);
  if (amount > BigInt(payment.data.amount_minor) - allocated || amount > BigInt(invoice.data.outstanding_minor)) return { status: "error", reason: "CONFLICT" };
  const response = await access.client.rpc("reconcile_provider_payment", { p_payment_id: value.paymentId, p_allocations: [{ invoice_id: value.invoiceId, amount_minor: value.amountMinor }], p_idempotency_key: value.idempotencyKey, p_correlation_id: value.correlationId });
  if (response.error) {
    if (response.error.code === "42501") return { status: "error", reason: "FORBIDDEN" };
    if (["22000", "23505", "23514", "40001", "55000"].includes(response.error.code ?? "")) return { status: "error", reason: "CONFLICT" };
    return { status: "error", reason: "UNAVAILABLE" };
  }
  const output = reconciliationOutput.safeParse(response.data);
  return output.success && output.data.payment_id === value.paymentId ? { status: "success", value: { batchId: output.data.reconciliation_batch_id } } : { status: "error", reason: "INVALID_RESPONSE" };
}
