import { z } from "zod";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { ADMIN_PROVIDER_LIMITS, sumMoneyByCurrency, type AdminProviderDashboard } from "./model";

const id = z.string().uuid();
const money = z.union([z.string().regex(/^\d+$/u), z.number().int().nonnegative()]).transform((value): string => String(value));
const platformRole = z.object({ role_code: z.string() });
const profile = z.object({ provider_organization_id: id, company_status: z.string(), overall_status: z.string(), partner_contract_status: z.string(), row_version: z.number().int().positive() });
const service = z.object({ id, provider_organization_id: id, service_id: id, request_status: z.string() });
const qualification = z.object({ id, provider_service_id: id, row_version: z.number().int().positive(), current_decision_id: id.nullable() });
const decision = z.object({ id, status: z.string() });
const catalogService = z.object({ id, code: z.string() });
const document = z.object({ id, provider_organization_id: id, family_id: id, version_number: z.number().int().positive(), status: z.string(), expires_on: z.string().nullable() });
const family = z.object({ id, document_kind: z.string(), code: z.string() });
const statement = z.object({ id, provider_organization_id: id, statement_number: z.string(), period_start: z.string(), period_end: z.string(), currency: z.string(), total_minor: money });
const invoice = z.object({ id, provider_organization_id: id, statement_id: id, invoice_number: z.string(), currency: z.string(), total_minor: money, paid_minor: money, outstanding_minor: money, credited_minor: money.optional(), payment_status: z.string(), due_on: z.string() });
const payment = z.object({ id, provider_organization_id: id, payment_reference: z.string(), currency: z.string(), amount_minor: money, paid_on: z.string() });
const allocation = z.object({ payment_id: id, amount_minor: money });
const account = z.object({ id, organization_id: id, code: z.string(), currency: z.string() });
const creditNote = z.object({ id, provider_organization_id: id, invoice_id: id, credit_number: z.string(), currency: z.string(), total_minor: money, issued_on: z.string() });
const paymentPlan = z.object({ id, provider_organization_id: id, invoice_id: id, reason: z.string() });
const paymentPlanDecision = z.object({ plan_id: id, decision_version: z.number().int().positive(), status: z.string() });
const collectionCase = z.object({ id, provider_organization_id: id, invoice_id: id, reason: z.string() });
const collectionDecision = z.object({ case_id: id, decision_version: z.number().int().positive(), status: z.string() });
const eligibility = z.object({
  eligible: z.boolean(),
  reasons: z.array(z.string()),
  qualification_status: z.string(),
  decision_version: z.number().int().positive().nullable().optional(),
  rule_version: z.string().nullable().optional(),
  checked_at: z.string().nullable().optional(),
});
const supervisionNames = z.object({
  organizations: z.array(z.object({ id, display_name: z.string().min(1) })).optional(),
}).passthrough();

type Result = { status: "success"; dashboard: AdminProviderDashboard } | { status: "error"; reason: "UNAUTHENTICATED" | "FORBIDDEN" | "QUERY_FAILED" | "INVALID_RESPONSE" };
type QueryResult<T> = { status: "ok"; data: T } | { status: "error"; reason: "QUERY_FAILED" | "INVALID_RESPONSE" };

function uniqueIds(values: readonly string[]): string[] {
  return [...new Set(values)];
}

function fallbackName(organizationId: string): string {
  return organizationId.slice(0, 8);
}

function toMinor(value: string | number): string {
  return String(value);
}

async function readRows<T>(schema: z.ZodType<T>, result: { data: unknown; error: unknown }): Promise<QueryResult<T>> {
  if (result.error) return { status: "error", reason: "QUERY_FAILED" };
  const parsed = schema.safeParse(result.data);
  return parsed.success ? { status: "ok", data: parsed.data } : { status: "error", reason: "INVALID_RESPONSE" };
}

function eligibilityFrom(data: unknown, qualificationStatus: string) {
  const payload = typeof data === "string" ? (() => { try { return JSON.parse(data) as unknown; } catch { return null; } })() : data;
  const parsed = eligibility.safeParse(payload);
  return parsed.success
    ? parsed.data
    : { eligible: false, reasons: ["ELIGIBILITY_UNAVAILABLE"], qualification_status: qualificationStatus, decision_version: null, rule_version: null, checked_at: null };
}

export async function loadAdminProviders(): Promise<Result> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const roleResult = await client.from("platform_user_roles").select("role_code").eq("user_id", auth.user.id).is("revoked_at", null).in("role_code", ["SUPER_ADMIN", "MATRICIA_ADMIN", "COMPLIANCE_MANAGER", "FINANCE_MANAGER", "READ_ONLY_AUDITOR"]).limit(10);
  const roles = await readRows(z.array(platformRole), roleResult);
  if (roles.status === "error") return roles;
  if (!roles.data.length) return { status: "error", reason: "FORBIDDEN" };
  const roleSet = new Set(roles.data.map((item) => item.role_code));
  const central = roleSet.has("SUPER_ADMIN") || roleSet.has("MATRICIA_ADMIN");
  const readOnly = roleSet.has("READ_ONLY_AUDITOR") && roles.data.every((item) => item.role_code === "READ_ONLY_AUDITOR");
  const canQualification = !readOnly && (central || roleSet.has("COMPLIANCE_MANAGER"));
  const canFinance = !readOnly && (central || roleSet.has("FINANCE_MANAGER"));

  const [profilesResult, servicesResult, documentsResult, statementsResult, invoicesResult, paymentsResult, allocationsResult, accountsResult, creditNotesResult, plansResult, planDecisionsResult, casesResult, caseDecisionsResult] = await Promise.all([
    client.from("provider_profiles").select("provider_organization_id,company_status,overall_status,partner_contract_status,row_version").order("updated_at", { ascending: false }).limit(ADMIN_PROVIDER_LIMITS.providers),
    client.from("provider_services").select("id,provider_organization_id,service_id,request_status").order("updated_at", { ascending: false }).limit(ADMIN_PROVIDER_LIMITS.services),
    client.from("provider_document_versions").select("id,provider_organization_id,family_id,version_number,status,expires_on").order("created_at", { ascending: false }).limit(ADMIN_PROVIDER_LIMITS.documents),
    client.from("provider_statements").select("id,provider_organization_id,statement_number,period_start,period_end,currency,total_minor").order("issued_at", { ascending: false }).limit(ADMIN_PROVIDER_LIMITS.financialRows),
    client.from("provider_invoice_balances").select("id,provider_organization_id,statement_id,invoice_number,currency,total_minor,paid_minor,outstanding_minor,credited_minor,payment_status,due_on").order("due_on", { ascending: false }).limit(ADMIN_PROVIDER_LIMITS.financialRows),
    client.from("provider_payments").select("id,provider_organization_id,payment_reference,currency,amount_minor,paid_on").order("paid_on", { ascending: false }).limit(ADMIN_PROVIDER_LIMITS.financialRows),
    client.from("provider_payment_allocations").select("payment_id,amount_minor").order("created_at", { ascending: false }).limit(ADMIN_PROVIDER_LIMITS.allocations),
    client.from("financial_accounts").select("id,organization_id,code,currency").order("code").limit(ADMIN_PROVIDER_LIMITS.accounts),
    client.from("provider_credit_notes").select("id,provider_organization_id,invoice_id,credit_number,currency,total_minor,issued_on").order("issued_on", { ascending: false }).limit(ADMIN_PROVIDER_LIMITS.financialRows),
    client.from("provider_payment_plans").select("id,provider_organization_id,invoice_id,reason").order("created_at", { ascending: false }).limit(ADMIN_PROVIDER_LIMITS.financialRows),
    client.from("provider_payment_plan_decisions").select("plan_id,decision_version,status").order("decision_version", { ascending: false }).limit(ADMIN_PROVIDER_LIMITS.financialRows),
    client.from("provider_collection_cases").select("id,provider_organization_id,invoice_id,reason").order("opened_at", { ascending: false }).limit(ADMIN_PROVIDER_LIMITS.financialRows),
    client.from("provider_collection_case_decisions").select("case_id,decision_version,status").order("decision_version", { ascending: false }).limit(ADMIN_PROVIDER_LIMITS.financialRows),
  ]);

  const profiles = await readRows(z.array(profile), profilesResult);
  const services = await readRows(z.array(service), servicesResult);
  const documents = await readRows(z.array(document), documentsResult);
  const statements = await readRows(z.array(statement), statementsResult);
  const invoices = await readRows(z.array(invoice), invoicesResult);
  const payments = await readRows(z.array(payment), paymentsResult);
  const allocations = await readRows(z.array(allocation), allocationsResult);
  const accounts = await readRows(z.array(account), accountsResult);
  const creditNotes = await readRows(z.array(creditNote), creditNotesResult);
  const plans = await readRows(z.array(paymentPlan), plansResult);
  const planDecisions = await readRows(z.array(paymentPlanDecision), planDecisionsResult);
  const cases = await readRows(z.array(collectionCase), casesResult);
  const caseDecisions = await readRows(z.array(collectionDecision), caseDecisionsResult);
  const parsed = [profiles, services, documents, statements, invoices, payments, allocations, accounts, creditNotes, plans, planDecisions, cases, caseDecisions];
  const failed = parsed.find((item) => item.status === "error");
  if (failed && failed.status === "error") return failed;
  if (profiles.status !== "ok" || services.status !== "ok" || documents.status !== "ok" || statements.status !== "ok" || invoices.status !== "ok" || payments.status !== "ok" || allocations.status !== "ok" || accounts.status !== "ok" || creditNotes.status !== "ok" || plans.status !== "ok" || planDecisions.status !== "ok" || cases.status !== "ok" || caseDecisions.status !== "ok") return { status: "error", reason: "INVALID_RESPONSE" };
  if (allocations.data.length === ADMIN_PROVIDER_LIMITS.allocations) return { status: "error", reason: "INVALID_RESPONSE" };

  const serviceIds = uniqueIds(services.data.map((item) => item.service_id));
  const serviceRowIds = uniqueIds(services.data.map((item) => item.id));
  const familyIds = uniqueIds(documents.data.map((item) => item.family_id));
  const [catalogResult, qualificationResult, familyResult, supervisionResult] = await Promise.all([
    serviceIds.length ? client.from("catalog_services").select("id,code").in("id", serviceIds).limit(ADMIN_PROVIDER_LIMITS.services) : Promise.resolve({ data: [], error: null }),
    serviceRowIds.length ? client.from("provider_qualifications").select("id,provider_service_id,row_version,current_decision_id").in("provider_service_id", serviceRowIds).limit(ADMIN_PROVIDER_LIMITS.services) : Promise.resolve({ data: [], error: null }),
    familyIds.length ? client.from("provider_document_families").select("id,document_kind,code").in("id", familyIds).limit(ADMIN_PROVIDER_LIMITS.documents) : Promise.resolve({ data: [], error: null }),
    client.rpc("list_admin_supervision_projection", { p_limit: 100 }),
  ]);

  const catalog = catalogResult.error ? { status: "ok" as const, data: [] as z.infer<typeof catalogService>[] } : await readRows(z.array(catalogService), catalogResult);
  const qualifications = await readRows(z.array(qualification), qualificationResult);
  const families = await readRows(z.array(family), familyResult);
  if (catalog.status === "error") return catalog;
  if (qualifications.status === "error") return qualifications;
  if (families.status === "error") return families;

  const decisionIds = uniqueIds(qualifications.data.map((item) => item.current_decision_id).filter((value): value is string => value !== null));
  const decisionsResult = decisionIds.length
    ? await client.from("provider_qualification_decisions").select("id,status").in("id", decisionIds).limit(ADMIN_PROVIDER_LIMITS.services)
    : { data: [], error: null };
  const decisions = await readRows(z.array(decision), decisionsResult);
  if (decisions.status === "error") return decisions;

  const names = new Map<string, string>();
  if (!supervisionResult.error) {
    const projection = supervisionNames.safeParse(supervisionResult.data);
    if (projection.success) {
      for (const organization of projection.data.organizations ?? []) names.set(organization.id, organization.display_name);
    }
  }
  const name = (organizationId: string) => names.get(organizationId) ?? fallbackName(organizationId);
  const catalogById = new Map(catalog.data.map((item) => [item.id, item.code]));
  const qualificationByService = new Map(qualifications.data.map((item) => [item.provider_service_id, item]));
  const decisionById = new Map(decisions.data.map((item) => [item.id, item.status]));
  const familyById = new Map(families.data.map((item) => [item.id, item]));

  const eligibilityResults = await Promise.all(services.data.map((item) => client.rpc("explain_provider_service_eligibility", { p_provider_organization_id: item.provider_organization_id, p_service_id: item.service_id })));
  const allocatedByPayment = new Map<string, bigint>();
  for (const item of allocations.data) allocatedByPayment.set(item.payment_id, (allocatedByPayment.get(item.payment_id) ?? BigInt(0)) + BigInt(toMinor(item.amount_minor)));
  if (payments.data.some((item) => (allocatedByPayment.get(item.id) ?? BigInt(0)) > BigInt(toMinor(item.amount_minor)))) return { status: "error", reason: "INVALID_RESPONSE" };

  const mappedInvoices = invoices.data.map((item) => ({ id: item.id, providerOrganizationId: item.provider_organization_id, providerName: name(item.provider_organization_id), statementId: item.statement_id, number: item.invoice_number, currency: item.currency, totalMinor: toMinor(item.total_minor), paidMinor: toMinor(item.paid_minor), outstandingMinor: toMinor(item.outstanding_minor), creditedMinor: toMinor(item.credited_minor ?? "0"), paymentStatus: item.payment_status, dueOn: item.due_on }));
  const mappedPayments = payments.data.map((item) => {
    const allocated = allocatedByPayment.get(item.id) ?? BigInt(0);
    const amount = BigInt(toMinor(item.amount_minor));
    return { id: item.id, providerOrganizationId: item.provider_organization_id, providerName: name(item.provider_organization_id), reference: item.payment_reference, currency: item.currency, amountMinor: toMinor(item.amount_minor), allocatedMinor: allocated.toString(), unallocatedMinor: (amount - allocated).toString(), paidOn: item.paid_on };
  });
  const limitsReached = [["providers", profiles.data.length, ADMIN_PROVIDER_LIMITS.providers], ["services", services.data.length, ADMIN_PROVIDER_LIMITS.services], ["documents", documents.data.length, ADMIN_PROVIDER_LIMITS.documents], ["finance", Math.max(statements.data.length, invoices.data.length, payments.data.length), ADMIN_PROVIDER_LIMITS.financialRows], ["accounts", accounts.data.length, ADMIN_PROVIDER_LIMITS.accounts]].filter(([, count, limit]) => count === limit).map(([key]) => String(key));

  const invoiceNumber = (invoiceId: string) => mappedInvoices.find((item) => item.id === invoiceId)?.number ?? invoiceId.slice(0, 8);
  const latestStatus = <T extends { status: string }>(rows: T[], key: (row: T) => string) => {
    const chosen = new Map<string, { version: number; status: string }>();
    for (const row of rows) {
      const id = key(row);
      const version = "decision_version" in row && typeof (row as { decision_version?: unknown }).decision_version === "number" ? (row as { decision_version: number }).decision_version : 0;
      const current = chosen.get(id);
      if (!current || version > current.version) chosen.set(id, { version, status: row.status });
    }
    return chosen;
  };
  const planStatus = latestStatus(planDecisions.data, (row) => row.plan_id);
  const caseStatus = latestStatus(caseDecisions.data, (row) => row.case_id);

  return {
    status: "success",
    dashboard: {
      capabilities: { qualificationDecision: canQualification, financeAction: canFinance, readOnly },
      providers: profiles.data.map((item) => ({ organizationId: item.provider_organization_id, organizationName: name(item.provider_organization_id), companyStatus: item.company_status, overallStatus: item.overall_status, partnerContractStatus: item.partner_contract_status, rowVersion: item.row_version })),
      services: services.data.map((item, index) => {
        const qualificationRow = qualificationByService.get(item.id) ?? null;
        const localStatus = qualificationRow?.current_decision_id ? decisionById.get(qualificationRow.current_decision_id) ?? "NOT_REQUESTED" : "NOT_REQUESTED";
        const eligibilityRow = eligibilityResults[index]?.error ? eligibilityFrom(null, localStatus) : eligibilityFrom(eligibilityResults[index]?.data, localStatus);
        return {
          id: item.id,
          providerOrganizationId: item.provider_organization_id,
          providerName: name(item.provider_organization_id),
          serviceId: item.service_id,
          serviceCode: catalogById.get(item.service_id) ?? fallbackName(item.service_id),
          requestStatus: item.request_status,
          qualificationId: qualificationRow?.id ?? null,
          qualificationRowVersion: qualificationRow?.row_version ?? null,
          qualificationStatus: eligibilityRow.qualification_status,
          eligible: eligibilityRow.eligible,
          eligibilityReasons: eligibilityRow.reasons,
          decisionVersion: eligibilityRow.decision_version ?? null,
          ruleVersion: eligibilityRow.rule_version ?? null,
          checkedAt: eligibilityRow.checked_at ?? null,
        };
      }),
      documents: documents.data.flatMap((item) => {
        const familyRow = familyById.get(item.family_id);
        return familyRow ? [{ id: item.id, providerOrganizationId: item.provider_organization_id, providerName: name(item.provider_organization_id), kind: familyRow.document_kind, code: familyRow.code, version: item.version_number, status: item.status, expiresOn: item.expires_on }] : [];
      }),
      statements: statements.data.map((item) => ({ id: item.id, providerOrganizationId: item.provider_organization_id, providerName: name(item.provider_organization_id), number: item.statement_number, periodStart: item.period_start, periodEnd: item.period_end, currency: item.currency, totalMinor: toMinor(item.total_minor) })),
      invoices: mappedInvoices,
      payments: mappedPayments,
      accounts: accounts.data.map((item) => ({ id: item.id, providerOrganizationId: item.organization_id, code: item.code, currency: item.currency })),
      creditNotes: creditNotes.data.map((item) => ({ id: item.id, providerOrganizationId: item.provider_organization_id, providerName: name(item.provider_organization_id), invoiceId: item.invoice_id, invoiceNumber: invoiceNumber(item.invoice_id), number: item.credit_number, currency: item.currency, totalMinor: toMinor(item.total_minor), issuedOn: item.issued_on })),
      paymentPlans: plans.data.map((item) => ({ id: item.id, providerOrganizationId: item.provider_organization_id, providerName: name(item.provider_organization_id), invoiceId: item.invoice_id, invoiceNumber: invoiceNumber(item.invoice_id), status: planStatus.get(item.id)?.status ?? "REQUESTED", reason: item.reason })),
      collectionCases: cases.data.map((item) => ({ id: item.id, providerOrganizationId: item.provider_organization_id, providerName: name(item.provider_organization_id), invoiceId: item.invoice_id, invoiceNumber: invoiceNumber(item.invoice_id), status: caseStatus.get(item.id)?.status ?? "OPEN", reason: item.reason })),
      totalsByCurrency: sumMoneyByCurrency(mappedInvoices, mappedPayments),
      limitsReached,
    },
  };
}
