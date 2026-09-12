import { z } from "zod";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import type { BillingDashboard } from "./model";

const id = z.string().uuid();
const money = z.string().regex(/^\d+$/);
const membership = z.object({ organization_id: id, organizations: z.object({ display_name: z.string().min(1) }) });
const payableSchema = z.object({ id, occurred_on: z.string(), event_type: z.string(), currency: z.string(), total_due_minor: money });
const statementSchema = z.object({ id, statement_number: z.string(), period_start: z.string(), period_end: z.string(), currency: z.string(), total_minor: money });
const invoiceSchema = z.object({ id, invoice_number: z.string(), currency: z.string(), total_minor: money, paid_minor: money, outstanding_minor: money, payment_status: z.string(), due_on: z.string() });
const paymentSchema = z.object({ id, payment_reference: z.string(), currency: z.string(), amount_minor: money, paid_on: z.string() });
const allocationSchema = z.object({ id: money, reconciliation_batch_id: id, payment_id: id, invoice_id: id, amount_minor: money, created_at: z.string() });
const accountSchema = z.object({ id, code: z.string(), currency: z.string() });

type BillingLoadResult =
  | { status: "success"; dashboard: BillingDashboard }
  | { status: "error"; reason: "UNAUTHENTICATED" | "NO_BILLING_ORGANIZATION" | "QUERY_FAILED" | "INVALID_RESPONSE" };

export async function loadProviderBilling(): Promise<BillingLoadResult> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };

  const membershipResult = await client.from("organization_memberships")
    .select("organization_id,organizations!inner(display_name),organization_member_roles!inner(role_code,revoked_at)")
    .eq("user_id", auth.user.id).eq("status", "ACTIVE").is("organization_member_roles.revoked_at", null)
    .in("organization_member_roles.role_code", ["PROVIDER_OWNER", "PROVIDER_ACCOUNTING"]).limit(1).maybeSingle();
  if (membershipResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const parsedMembership = membership.safeParse(membershipResult.data);
  if (!parsedMembership.success) return { status: "error", reason: membershipResult.data ? "INVALID_RESPONSE" : "NO_BILLING_ORGANIZATION" };

  const organizationId = parsedMembership.data.organization_id;
  const [payablesResult, statementsResult, invoicesResult, paymentsResult, accountsResult] = await Promise.all([
    client.from("provider_payable_events").select("id,occurred_on,event_type,currency,total_due_minor::text").eq("provider_organization_id", organizationId).order("occurred_on", { ascending: false }).limit(50),
    client.from("provider_statements").select("id,statement_number,period_start,period_end,currency,total_minor::text").eq("provider_organization_id", organizationId).order("issued_at", { ascending: false }).limit(30),
    client.from("provider_invoice_balances").select("id,invoice_number,currency,total_minor::text,paid_minor::text,outstanding_minor::text,payment_status,due_on").eq("provider_organization_id", organizationId).order("due_on", { ascending: false }).limit(50),
    client.from("provider_payments").select("id,payment_reference,currency,amount_minor::text,paid_on").eq("provider_organization_id", organizationId).order("paid_on", { ascending: false }).limit(50),
    client.from("financial_accounts").select("id,code,currency").eq("organization_id", organizationId).order("code"),
  ]);
  if (payablesResult.error || statementsResult.error || invoicesResult.error || paymentsResult.error || accountsResult.error) return { status: "error", reason: "QUERY_FAILED" };

  const payables = z.array(payableSchema).safeParse(payablesResult.data);
  const statements = z.array(statementSchema).safeParse(statementsResult.data);
  const invoices = z.array(invoiceSchema).safeParse(invoicesResult.data);
  const payments = z.array(paymentSchema).safeParse(paymentsResult.data);
  const accounts = z.array(accountSchema).safeParse(accountsResult.data);
  if (!payables.success || !statements.success || !invoices.success || !payments.success || !accounts.success) return { status: "error", reason: "INVALID_RESPONSE" };

  const allocationsResult = payments.data.length === 0 ? { data: [], error: null } : await client
    .from("provider_payment_allocations")
    .select("id::text,reconciliation_batch_id,payment_id,invoice_id,amount_minor::text,created_at")
    .eq("provider_organization_id", organizationId)
    .in("payment_id", payments.data.map((item) => item.id))
    .order("created_at", { ascending: false });
  if (allocationsResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const allocations = z.array(allocationSchema).safeParse(allocationsResult.data);
  if (!allocations.success) return { status: "error", reason: "INVALID_RESPONSE" };

  const allocatedByPayment = new Map<string, bigint>();
  for (const item of allocations.data) allocatedByPayment.set(item.payment_id, (allocatedByPayment.get(item.payment_id) ?? BigInt(0)) + BigInt(item.amount_minor));
  if (payments.data.some((item) => (allocatedByPayment.get(item.id) ?? BigInt(0)) > BigInt(item.amount_minor))) return { status: "error", reason: "INVALID_RESPONSE" };
  const invoiceById = new Map(invoices.data.map((item) => [item.id, item]));
  const paymentById = new Map(payments.data.map((item) => [item.id, item]));

  return { status: "success", dashboard: {
    organizationId,
    organizationName: parsedMembership.data.organizations.display_name,
    payables: payables.data.map((item) => ({ id: item.id, occurredOn: item.occurred_on, eventType: item.event_type, currency: item.currency, totalDueMinor: item.total_due_minor })),
    statements: statements.data.map((item) => ({ id: item.id, number: item.statement_number, periodStart: item.period_start, periodEnd: item.period_end, currency: item.currency, totalMinor: item.total_minor })),
    invoices: invoices.data.map((item) => ({ id: item.id, number: item.invoice_number, currency: item.currency, totalMinor: item.total_minor, paidMinor: item.paid_minor, outstandingMinor: item.outstanding_minor, paymentStatus: item.payment_status, dueOn: item.due_on })),
    payments: payments.data.map((item) => {
      const allocatedMinor = allocatedByPayment.get(item.id) ?? BigInt(0);
      return { id: item.id, reference: item.payment_reference, currency: item.currency, amountMinor: item.amount_minor, allocatedMinor: allocatedMinor.toString(), unallocatedMinor: (BigInt(item.amount_minor) - allocatedMinor).toString(), paidOn: item.paid_on };
    }),
    allocations: allocations.data.map((item) => ({
      id: item.id, batchId: item.reconciliation_batch_id, paymentId: item.payment_id,
      paymentReference: paymentById.get(item.payment_id)?.payment_reference ?? item.payment_id.slice(0, 8),
      invoiceId: item.invoice_id, invoiceNumber: invoiceById.get(item.invoice_id)?.invoice_number ?? item.invoice_id.slice(0, 8),
      currency: paymentById.get(item.payment_id)?.currency ?? invoiceById.get(item.invoice_id)?.currency ?? "MAD",
      amountMinor: item.amount_minor, createdAt: item.created_at,
    })),
    accounts: accounts.data,
  } };
}
