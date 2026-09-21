"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { callBoxesCommand } from "@/modules/admin/data/boxes/repository";
import { closeAdminProfitPeriod } from "@/modules/admin/data/pnl/repository";
import { issueAdminProviderStatement, sweepAdminExceptions } from "@/modules/admin/data/closure/repository";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";

export type CommerceActionState =
  | { status: "idle" }
  | { status: "success"; outcome: string }
  | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "FORBIDDEN" | "CONFLICT" | "FAILED" };

export const commerceIdle: CommerceActionState = { status: "idle" };

const text = (form: FormData, key: string) => String(form.get(key) ?? "").trim();
const emptyToNull = (value: string) => (value.length ? value : null);

function fail(reason: string): CommerceActionState {
  if (reason === "FORBIDDEN") return { status: "error", reason: "FORBIDDEN" };
  if (reason === "UNAUTHENTICATED") return { status: "error", reason: "UNAUTHENTICATED" };
  if (reason === "INVALID_INPUT") return { status: "error", reason: "VALIDATION" };
  if (reason === "CONFLICT") return { status: "error", reason: "CONFLICT" };
  return { status: "error", reason: "FAILED" };
}

function localeOrFail(form: FormData): string | null {
  const locale = text(form, "locale");
  return isLocale(locale) ? locale : null;
}

async function boxed(locale: string, name: string, args: Record<string, unknown>): Promise<CommerceActionState> {
  const result = await callBoxesCommand(name, args);
  if (result.status === "error") return fail(result.reason);
  revalidatePath(`/${locale}/administration/finance`);
  return { status: "success", outcome: result.value.outcome };
}

export async function createBenefitAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale) return { status: "error", reason: "VALIDATION" };
  return boxed(locale, "create_benefit_version", {
    p_audit_organization_id: text(form, "auditOrganizationId"),
    p_code: text(form, "code").toUpperCase(),
    p_benefit_type: text(form, "benefitType"),
    p_fulfillment_mode: text(form, "fulfillmentMode"),
    p_name_fr: text(form, "nameFr"),
    p_name_ar: text(form, "nameAr"),
    p_description_fr: text(form, "descriptionFr"),
    p_description_ar: text(form, "descriptionAr"),
    p_credit_cost: Number(text(form, "creditCost")),
    p_reference_value_minor: Number(text(form, "referenceValueMinor")),
    p_internal_cost_minor: Number(text(form, "internalCostMinor")),
    p_currency: text(form, "currency").toUpperCase(),
    p_library_id: emptyToNull(text(form, "libraryId")),
    p_service_id: emptyToNull(text(form, "serviceId")),
    p_quota: text(form, "quota") ? Number(text(form, "quota")) : null,
    p_capacity_rule: {},
    p_eligibility_rule: {},
    p_cancellation_rule_version: text(form, "cancellationRuleVersion") || "CANCEL_V1",
    p_effective_from: new Date().toISOString(),
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
}

export async function activateBenefitAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale) return { status: "error", reason: "VALIDATION" };
  return boxed(locale, "activate_benefit_version", {
    p_audit_organization_id: text(form, "auditOrganizationId"),
    p_benefit_version_id: text(form, "benefitVersionId"),
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
}

export async function createBoxAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale) return { status: "error", reason: "VALIDATION" };
  const slotCode = text(form, "slotCode").toUpperCase();
  const benefitIds = text(form, "allowedBenefitVersionIds").split(/[\s,]+/u).filter(Boolean);
  const slots = slotCode
    ? [{
        slot_code: slotCode,
        slot_kind: text(form, "slotKind") || "MANDATORY",
        minimum_selections: Number(text(form, "slotMin") || "0"),
        maximum_selections: Number(text(form, "slotMax") || "1"),
        allowed_benefit_version_ids: benefitIds,
      }]
    : [];
  return boxed(locale, "create_box_version", {
    p_audit_organization_id: text(form, "auditOrganizationId"),
    p_code: text(form, "code").toUpperCase(),
    p_box_type: text(form, "boxType"),
    p_name_fr: text(form, "nameFr"),
    p_name_ar: text(form, "nameAr"),
    p_credit_budget: Number(text(form, "creditBudget")),
    p_rollover_months: Number(text(form, "rolloverMonths") || "0"),
    p_rules_snapshot: { version: "BOX_BUILDER_V1" },
    p_cost_low_minor: Number(text(form, "costLowMinor")),
    p_cost_expected_minor: Number(text(form, "costExpectedMinor")),
    p_cost_full_minor: Number(text(form, "costFullMinor")),
    p_currency: text(form, "currency").toUpperCase(),
    p_effective_from: new Date().toISOString(),
    p_slots: slots,
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
}

export async function activateBoxAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale) return { status: "error", reason: "VALIDATION" };
  return boxed(locale, "activate_box_version", {
    p_audit_organization_id: text(form, "auditOrganizationId"),
    p_box_version_id: text(form, "boxVersionId"),
    p_approval_reference: emptyToNull(text(form, "approvalReference")),
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
}

export async function linkPlanBoxAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale) return { status: "error", reason: "VALIDATION" };
  return boxed(locale, "link_plan_box_rule", {
    p_audit_organization_id: text(form, "auditOrganizationId"),
    p_plan_version_id: text(form, "planVersionId"),
    p_box_version_id: text(form, "boxVersionId"),
    p_rule_snapshot: { version: "PLAN_BOX_V1" },
    p_effective_from: new Date().toISOString(),
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
}

export async function issueCreditsAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale) return { status: "error", reason: "VALIDATION" };
  const expires = text(form, "expiresAt");
  const expiresAt = expires.includes("T") ? new Date(expires).toISOString() : `${expires}T23:59:59.000Z`;
  return boxed(locale, "issue_credits", {
    p_organization_id: text(form, "organizationId"),
    p_wallet_id: text(form, "walletId"),
    p_source_type: text(form, "sourceType"),
    p_quantity: Number(text(form, "quantity")),
    p_expires_at: expiresAt,
    p_library_id: emptyToNull(text(form, "libraryId")),
    p_source_reference: text(form, "sourceReference"),
    p_revenue_value_minor: Number(text(form, "revenueValueMinor") || "0"),
    p_rule_version: text(form, "ruleVersion") || "ADMIN_GRANT_V1",
    p_approval_reference: emptyToNull(text(form, "approvalReference")),
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
}

export async function ensureWalletAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale) return { status: "error", reason: "VALIDATION" };
  return boxed(locale, "ensure_client_credit_wallet", {
    p_organization_id: text(form, "organizationId"),
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
}

export async function closePnlAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale) return { status: "error", reason: "VALIDATION" };
  const cutoff = text(form, "entryCutoffAt");
  const result = await closeAdminProfitPeriod({
    bookId: text(form, "bookId"),
    periodStart: text(form, "periodStart"),
    periodEnd: text(form, "periodEnd"),
    ruleVersionId: text(form, "ruleVersionId"),
    entryCutoffAt: cutoff.includes("T") ? new Date(cutoff).toISOString() : new Date().toISOString(),
    reason: text(form, "reason"),
    idempotencyKey: text(form, "idempotencyKey"),
    correlationId: randomUUID(),
  });
  if (result.status === "error") return fail(result.reason);
  revalidatePath(`/${locale}/administration/finance`);
  return { status: "success", outcome: result.value.outcome };
}

export async function issueStatementAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale) return { status: "error", reason: "VALIDATION" };
  const result = await issueAdminProviderStatement({
    providerOrganizationId: text(form, "providerOrganizationId"),
    statementNumber: text(form, "statementNumber"),
    periodStart: text(form, "periodStart"),
    periodEnd: text(form, "periodEnd"),
    currency: text(form, "currency").toUpperCase(),
    idempotencyKey: text(form, "idempotencyKey"),
    correlationId: randomUUID(),
  });
  if (result.status === "error") return fail(result.reason);
  revalidatePath(`/${locale}/administration/finance`);
  return { status: "success", outcome: result.value.outcome };
}

export async function sweepExceptionsAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale) return { status: "error", reason: "VALIDATION" };
  const result = await sweepAdminExceptions();
  if (result.status === "error") return fail(result.reason);
  revalidatePath(`/${locale}/administration/command-center`);
  revalidatePath(`/${locale}/administration/finance`);
  return { status: "success", outcome: `${result.value.outcome}:${result.value.opened}:${result.value.skipped}` };
}

export async function createFrameworkAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale) return { status: "error", reason: "VALIDATION" };
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const unitPrice = Number(text(form, "unitPriceMinor"));
  const response = await client.rpc("create_framework_agreement_draft", {
    p_owner_organization_id: text(form, "ownerOrganizationId"),
    p_sku_id: text(form, "skuId"),
    p_agreement_code: text(form, "agreementCode"),
    p_valid_from: text(form, "validFrom"),
    p_valid_to: text(form, "validTo"),
    p_forecast_units: text(form, "forecastUnits"),
    p_minimum_commitment_units: text(form, "minimumCommitmentUnits") || "0",
    p_maximum_units: text(form, "maximumUnits"),
    p_payment_model: text(form, "paymentModel"),
    p_currency: text(form, "currency").toUpperCase(),
    p_price_tiers: [{ min_units: 1, unit_price_minor: unitPrice }],
    p_rebate_rules: [],
    p_sla_snapshot: { version: "FRAMEWORK_SLA_V1" },
    p_penalty_rules: [],
    p_exit_rules: { version: "FRAMEWORK_EXIT_V1" },
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
  if (response.error) {
    if (response.error.code === "42501") return { status: "error", reason: "FORBIDDEN" };
    if (response.error.code === "22023") return { status: "error", reason: "VALIDATION" };
    return { status: "error", reason: "FAILED" };
  }
  revalidatePath(`/${locale}/administration/achats-groupes`);
  return { status: "success", outcome: "FRAMEWORK_DRAFT_CREATED" };
}

function exactMinor(value: string | null): number | null {
  if (!value || !/^[0-9]+$/u.test(value)) return null;
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) ? parsed : null;
}

export async function activateFrameworkPoolAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale) return { status: "error", reason: "VALIDATION" };
  const ttlHours = exactMinor(text(form, "reservationTtlHours") || "168");
  if (ttlHours === null || ttlHours < 1 || ttlHours > 2160) return { status: "error", reason: "VALIDATION" };
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const provider = emptyToNull(text(form, "providerOrganizationId"));
  const contracted = emptyToNull(text(form, "contractedUnits"));
  const response = await client.rpc("activate_framework_pool", {
    p_agreement_id: text(form, "agreementId"),
    p_contracted_units: contracted,
    p_low_stock_threshold_units: text(form, "lowStockThresholdUnits") || "0",
    p_reservation_ttl_hours: ttlHours,
    p_provider_organization_id: provider,
    p_provider_capacity_units: provider ? emptyToNull(text(form, "providerCapacityUnits")) : null,
    p_unit_price_minor: provider ? exactMinor(text(form, "unitPriceMinor")) : null,
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
  if (response.error) {
    if (response.error.code === "42501") return { status: "error", reason: "FORBIDDEN" };
    if (response.error.code === "22023") return { status: "error", reason: "VALIDATION" };
    if (response.error.code === "55000" || response.error.code === "23505") return { status: "error", reason: "CONFLICT" };
    return { status: "error", reason: "FAILED" };
  }
  revalidatePath(`/${locale}/administration/achats-groupes`);
  return { status: "success", outcome: "POOL_ACTIVE" };
}

function positive(value: string): number | null {
  const parsed = exactMinor(value);
  return parsed !== null && parsed > 0 ? parsed : null;
}

function dayStart(value: string): string | null {
  return /^\d{4}-\d{2}-\d{2}$/u.test(value) ? `${value}T00:00:00.000Z` : null;
}

export async function createCreditPackAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  const quantity = positive(text(form, "quantity"));
  const price = exactMinor(text(form, "priceMinor"));
  const days = positive(text(form, "validityDays"));
  if (!locale || quantity === null || price === null || days === null || days > 3660) return { status: "error", reason: "VALIDATION" };
  return boxed(locale, "create_credit_pack_version", {
    p_audit_organization_id: text(form, "auditOrganizationId"),
    p_code: text(form, "code").toUpperCase(),
    p_name_fr: text(form, "nameFr"),
    p_name_ar: text(form, "nameAr"),
    p_quantity: quantity,
    p_price_minor: price,
    p_currency: text(form, "currency").toUpperCase(),
    p_validity_days: days,
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
}

export async function activateCreditPackAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale) return { status: "error", reason: "VALIDATION" };
  return boxed(locale, "activate_credit_pack_version", {
    p_audit_organization_id: text(form, "auditOrganizationId"),
    p_pack_version_id: text(form, "packVersionId"),
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
}

export async function grantCreditPackAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale || text(form, "paymentReference").length < 3) return { status: "error", reason: "VALIDATION" };
  return boxed(locale, "grant_credit_pack", {
    p_pack_version_id: text(form, "packVersionId"),
    p_organization_id: text(form, "organizationId"),
    p_wallet_id: text(form, "walletId"),
    p_payment_reference: text(form, "paymentReference"),
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
}

export async function createCreditPromotionAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  const bonus = positive(text(form, "bonusCredits"));
  const days = positive(text(form, "validityDays"));
  const from = dayStart(text(form, "effectiveFrom"));
  const untilRaw = text(form, "effectiveUntil");
  const until = untilRaw ? dayStart(untilRaw) : null;
  if (!locale || bonus === null || days === null || days > 3660 || !from || (untilRaw.length > 0 && !until)) return { status: "error", reason: "VALIDATION" };
  return boxed(locale, "create_credit_promotion_version", {
    p_audit_organization_id: text(form, "auditOrganizationId"),
    p_code: text(form, "code").toUpperCase(),
    p_name_fr: text(form, "nameFr"),
    p_name_ar: text(form, "nameAr"),
    p_bonus_credits: bonus,
    p_validity_days: days,
    p_effective_from: from,
    p_effective_until: until,
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
}

export async function activateCreditPromotionAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale || text(form, "approvalReference").length < 3) return { status: "error", reason: "VALIDATION" };
  return boxed(locale, "activate_credit_promotion_version", {
    p_audit_organization_id: text(form, "auditOrganizationId"),
    p_promotion_version_id: text(form, "promotionVersionId"),
    p_approval_reference: text(form, "approvalReference"),
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
}

export async function grantCreditPromotionAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale) return { status: "error", reason: "VALIDATION" };
  return boxed(locale, "grant_credit_promotion", {
    p_promotion_version_id: text(form, "promotionVersionId"),
    p_organization_id: text(form, "organizationId"),
    p_wallet_id: text(form, "walletId"),
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
}

export async function createPlatformParameterAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  const value = positive(text(form, "valueInteger"));
  if (!locale || value === null || text(form, "changeReason").length < 10) return { status: "error", reason: "VALIDATION" };
  return boxed(locale, "create_platform_parameter_version", {
    p_audit_organization_id: text(form, "auditOrganizationId"),
    p_parameter_key: text(form, "parameterKey"),
    p_value_integer: value,
    p_change_reason: text(form, "changeReason"),
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
}

export async function activatePlatformParameterAction(_: CommerceActionState, form: FormData): Promise<CommerceActionState> {
  const locale = localeOrFail(form);
  if (!locale) return { status: "error", reason: "VALIDATION" };
  return boxed(locale, "activate_platform_parameter_version", {
    p_audit_organization_id: text(form, "auditOrganizationId"),
    p_parameter_version_id: text(form, "parameterVersionId"),
    p_idempotency_key: text(form, "idempotencyKey"),
    p_correlation_id: randomUUID(),
  });
}
