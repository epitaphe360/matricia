"use server";

import { createHash } from "node:crypto";
import { z } from "zod";
import { companyDecisionInput, documentDecisionInput, qualificationDecisionInput } from "@/lib/admin-providers/model";
import { invoiceInput, paymentInput, reconciliationInput, statementInput } from "@/lib/provider-billing/model";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { parseMoneyToMinor } from "../../sous-traitant/devis/money";

export type AdminProviderActionState = { status: "idle" } | { status: "success"; outcome: string } | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "FORBIDDEN" | "CONFLICT" | "FAILED" };
const output = z.object({ outcome: z.string().min(3) }).passthrough(); const text = (data: FormData, key: string) => String(data.get(key) ?? ""); const nullable = (value: string) => value.trim() || null;
function percentageToBasisPoints(value: string): number | null { const normalized = value.trim().replace(",", "."); if (!/^(?:\d{1,2}(?:\.\d{1,2})?|100(?:\.0{1,2})?)$/u.test(normalized)) return null; const [whole = "0", decimals = ""] = normalized.split("."); return Number(whole) * 100 + Number(decimals.padEnd(2, "0")); }
function optionalIso(value: string): string | null { if (!value.trim()) return null; const parsed = new Date(value); return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString(); }
function failure(error: { code?: string; message?: string } | null): AdminProviderActionState { if (error?.code === "42501") return { status: "error", reason: "FORBIDDEN" }; if (["40001", "23505", "23514", "55000"].includes(error?.code ?? "") || error?.message?.includes("IDEMPOTENCY") || error?.message?.includes("OVERALLOCATED")) return { status: "error", reason: "CONFLICT" }; return { status: "error", reason: "FAILED" }; }
async function rpc(name: string, args: Record<string, unknown>): Promise<AdminProviderActionState> { const client = await getSupabaseServerClient(); const { data } = await client.auth.getUser(); if (!data.user) return { status: "error", reason: "UNAUTHENTICATED" }; const result = await client.rpc(name, args); if (result.error) return failure(result.error); const parsed = output.safeParse(result.data); return parsed.success ? { status: "success", outcome: parsed.data.outcome } : { status: "error", reason: "FAILED" }; }

async function proofDigest(value: FormDataEntryValue | null): Promise<string | null> {
  if (!(value instanceof File) || value.size < 1 || value.size > 10 * 1024 * 1024 || !["application/pdf", "image/jpeg", "image/png"].includes(value.type)) return null;
  let bytes: Buffer;
  try { bytes = Buffer.from(await value.arrayBuffer()); } catch { return null; }
  const signatures: Record<string, number[]> = { "application/pdf": [0x25, 0x50, 0x44, 0x46, 0x2d], "image/jpeg": [0xff, 0xd8, 0xff], "image/png": [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a] };
  return signatures[value.type]?.every((byte, index) => bytes[index] === byte) ? createHash("sha256").update(bytes).digest("hex") : null;
}

export async function decideCompany(_: AdminProviderActionState, data: FormData): Promise<AdminProviderActionState> { const parsed = companyDecisionInput.safeParse({ organizationId: text(data, "organizationId"), companyStatus: text(data, "companyStatus"), partnerContractStatus: text(data, "partnerContractStatus"), partnerContractExpiresAt: nullable(text(data, "partnerContractExpiresAt")), reason: text(data, "reason"), ruleVersion: text(data, "ruleVersion").toUpperCase(), expectedRowVersion: text(data, "expectedRowVersion"), idempotencyKey: text(data, "idempotencyKey") }); if (!parsed.success) return { status: "error", reason: "VALIDATION" }; const value = parsed.data; return rpc("decide_provider_company", { p_provider_organization_id: value.organizationId, p_company_status: value.companyStatus, p_partner_contract_status: value.partnerContractStatus, p_partner_contract_expires_at: value.partnerContractExpiresAt, p_reason: value.reason, p_rule_version: value.ruleVersion, p_expected_row_version: value.expectedRowVersion, p_idempotency_key: value.idempotencyKey }); }
export async function reviewDocument(_: AdminProviderActionState, data: FormData): Promise<AdminProviderActionState> { const parsed = documentDecisionInput.safeParse({ documentVersionId: text(data, "documentVersionId"), status: text(data, "status"), rationale: text(data, "rationale"), ruleVersion: text(data, "ruleVersion").toUpperCase(), idempotencyKey: text(data, "idempotencyKey") }); if (!parsed.success) return { status: "error", reason: "VALIDATION" }; const value = parsed.data; return rpc("review_provider_document", { p_document_version_id: value.documentVersionId, p_status: value.status, p_rationale: value.rationale, p_rule_version: value.ruleVersion, p_idempotency_key: value.idempotencyKey }); }
export async function decideQualification(_: AdminProviderActionState, data: FormData): Promise<AdminProviderActionState> {
  const qualificationId = text(data, "qualificationId"), status = text(data, "status");
  const client = await getSupabaseServerClient(); const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const qualificationResult = await client.from("provider_qualifications").select("id,provider_organization_id,row_version").eq("id", qualificationId).maybeSingle();
  const qualification = z.object({ id: z.string().uuid(), provider_organization_id: z.string().uuid(), row_version: z.number().int().positive() }).safeParse(qualificationResult.data);
  if (qualificationResult.error) return failure(qualificationResult.error); if (!qualification.success) return { status: "error", reason: "FORBIDDEN" };
  const needsEvidence = status === "APPROVED" || status === "CONDITIONAL";
  const scoreBasisPoints = needsEvidence ? percentageToBasisPoints(text(data, "scorePercent")) : null;
  if (needsEvidence && (text(data, "evidenceConfirmed") !== "yes" || scoreBasisPoints === null)) return { status: "error", reason: "VALIDATION" };
  let questionnaireSessionId: string | null = null;
  if (needsEvidence) {
    const sessionResult = await client.from("questionnaire_sessions").select("id").eq("organization_id", qualification.data.provider_organization_id).eq("audience", "PROVIDER").eq("status", "SUBMITTED").eq("is_simulation", false).order("submitted_at", { ascending: false }).limit(1).maybeSingle();
    if (sessionResult.error) return failure(sessionResult.error); const session = z.object({ id: z.string().uuid() }).safeParse(sessionResult.data); if (!session.success) return { status: "error", reason: "VALIDATION" }; questionnaireSessionId = session.data.id;
  }
  const conditions = text(data, "blockingConditions").split(/\r?\n/u).map(value => value.trim()).filter(Boolean).slice(0, 100).map(condition => ({ condition }));
  if (status === "CONDITIONAL" && conditions.length === 0) return { status: "error", reason: "VALIDATION" };
  const parsed = qualificationDecisionInput.safeParse({ qualificationId, status, questionnaireSessionId, scoreBasisPoints, mandatoryChecks: needsEvidence ? [{ check: "SUBMITTED_PROVIDER_QUESTIONNAIRE", passed: true }, { check: "HUMAN_EVIDENCE_REVIEW", passed: true }] : [], blockingConditions: conditions, rationale: text(data, "rationale"), ruleVersion: "PROVIDER-QUALIFICATION-V1", expiresAt: optionalIso(text(data, "expiresAt")), expectedRowVersion: qualification.data.row_version, idempotencyKey: text(data, "idempotencyKey") });
  if (!parsed.success) return { status: "error", reason: "VALIDATION" }; const value = parsed.data;
  const result = await client.rpc("decide_provider_qualification", { p_qualification_id: value.qualificationId, p_status: value.status, p_questionnaire_session_id: value.questionnaireSessionId, p_score_basis_points: value.scoreBasisPoints, p_mandatory_checks: value.mandatoryChecks, p_blocking_conditions: value.blockingConditions, p_rationale: value.rationale, p_rule_version: value.ruleVersion, p_expires_at: value.expiresAt, p_expected_row_version: value.expectedRowVersion, p_idempotency_key: value.idempotencyKey });
  if (result.error) return failure(result.error); const response = output.safeParse(result.data); return response.success ? { status: "success", outcome: response.data.outcome } : { status: "error", reason: "FAILED" };
}
export async function issueAdminStatement(_: AdminProviderActionState, data: FormData): Promise<AdminProviderActionState> { const parsed = statementInput.safeParse({ organizationId: text(data, "organizationId"), statementNumber: text(data, "statementNumber"), periodStart: text(data, "periodStart"), periodEnd: text(data, "periodEnd"), currency: text(data, "currency").toUpperCase(), idempotencyKey: text(data, "idempotencyKey") }); if (!parsed.success) return { status: "error", reason: "VALIDATION" }; const value = parsed.data; return rpc("issue_provider_statement", { p_provider_organization_id: value.organizationId, p_statement_number: value.statementNumber, p_period_start: value.periodStart, p_period_end: value.periodEnd, p_currency: value.currency, p_idempotency_key: value.idempotencyKey }); }
export async function issueAdminInvoice(_: AdminProviderActionState, data: FormData): Promise<AdminProviderActionState> { const parsed = invoiceInput.safeParse({ statementId: text(data, "statementId"), invoiceNumber: text(data, "invoiceNumber"), issuedOn: text(data, "issuedOn"), dueOn: text(data, "dueOn"), receivableAccountId: text(data, "receivableAccountId"), revenueAccountId: text(data, "revenueAccountId"), taxLiabilityAccountId: text(data, "taxLiabilityAccountId"), idempotencyKey: text(data, "idempotencyKey") }); if (!parsed.success) return { status: "error", reason: "VALIDATION" }; const value = parsed.data; return rpc("issue_provider_invoice", { p_statement_id: value.statementId, p_invoice_number: value.invoiceNumber, p_issued_on: value.issuedOn, p_due_on: value.dueOn, p_receivable_account_id: value.receivableAccountId, p_revenue_account_id: value.revenueAccountId, p_tax_liability_account_id: value.taxLiabilityAccountId, p_idempotency_key: value.idempotencyKey }); }
export async function recordAdminPayment(_: AdminProviderActionState, data: FormData): Promise<AdminProviderActionState> {
  const currency = text(data, "currency").toUpperCase(), amountMinor = parseMoneyToMinor(text(data, "amount"), currency), proofHash = await proofDigest(data.get("proofFile"));
  const parsed = paymentInput.safeParse({ organizationId: text(data, "organizationId"), paymentReference: text(data, "paymentReference"), paidOn: text(data, "paidOn"), paymentMethod: text(data, "paymentMethod"), currency, amountMinor, proofHash, cashAccountId: text(data, "cashAccountId"), receivableAccountId: text(data, "receivableAccountId"), idempotencyKey: text(data, "idempotencyKey") });
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };
  const value = parsed.data;
  return rpc("record_provider_payment", { p_provider_organization_id: value.organizationId, p_payment_reference: value.paymentReference, p_paid_on: value.paidOn, p_payment_method: value.paymentMethod, p_currency: value.currency, p_amount_minor: value.amountMinor, p_proof_hash: value.proofHash, p_cash_account_id: value.cashAccountId, p_receivable_account_id: value.receivableAccountId, p_idempotency_key: value.idempotencyKey });
}
export async function reconcileAdminPayment(_: AdminProviderActionState, data: FormData): Promise<AdminProviderActionState> {
  const client = await getSupabaseServerClient(), { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const paymentId = text(data, "paymentId"), result = await client.from("provider_payments").select("currency").eq("id", paymentId).maybeSingle();
  if (result.error) return failure(result.error);
  const currency = z.object({ currency: z.string().regex(/^[A-Z]{3}$/u) }).safeParse(result.data);
  if (!currency.success) return { status: "error", reason: "FORBIDDEN" };
  const parsed = reconciliationInput.safeParse({ paymentId, invoiceId: text(data, "invoiceId"), amountMinor: parseMoneyToMinor(text(data, "amount"), currency.data.currency), idempotencyKey: text(data, "idempotencyKey") });
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };
  const value = parsed.data, rpcResult = await client.rpc("reconcile_provider_payment", { p_payment_id: value.paymentId, p_allocations: [{ invoice_id: value.invoiceId, amount_minor: value.amountMinor }], p_idempotency_key: value.idempotencyKey });
  return rpcResult.error ? failure(rpcResult.error) : output.safeParse(rpcResult.data).success ? { status: "success", outcome: output.parse(rpcResult.data).outcome } : { status: "error", reason: "FAILED" };
}
