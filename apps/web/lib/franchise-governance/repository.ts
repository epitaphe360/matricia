import { z } from "zod";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { sumExact, type FranchiseDashboard } from "./model";

const id = z.string().uuid(), minor = z.union([z.string().regex(/^-?\d+$/), z.number().int().safe()]).transform(String);
const franchise = z.object({ id, library_id: id, operator_organization_id: id, franchise_type: z.enum(["IT", "STANDARD"]), operator_code: z.string(), territory_code: z.string(), status: z.string(), current_mandate_version_id: id.nullable(), row_version: z.number().int().positive() });
const library = z.object({ id, code: z.string() });
const mandate = z.object({ id, franchise_id: id, version: z.number().int().positive(), mandate_status: z.string(), entry_fee_minor: minor, entry_fee_mode: z.string(), franchisee_share_bps: z.number().int(), neoxa_share_bps: z.number().int(), matricia_share_bps: z.number().int(), effective_from: z.string() });
const approval = z.object({ id, franchise_id: id, request_type: z.string(), status: z.string(), change_reason: z.string(), row_version: z.number().int().positive() });
const invitation = z.object({ id, franchise_id: id, invited_email: z.string(), status: z.string(), expires_at: z.string(), row_version: z.number().int().positive() });
const rule = z.object({ id, franchise_type: z.enum(["IT", "STANDARD"]), version: z.number().int(), entry_fee_required: z.boolean(), franchisee_share_bps: z.number().int(), neoxa_share_bps: z.number().int(), asma_matricia_share_bps: z.number().int(), effective_from: z.string() });
const book = z.object({ id, library_id: id, franchise_organization_id: id, franchise_type: z.enum(["IT", "STANDARD"]), operator_code: z.string(), currency: z.string(), opened_under_rule_version_id: id, status: z.string() });
const fee = z.object({ book_id: id, mode: z.string(), principal_minor: minor, deposit_minor: minor, starts_on: z.string(), due_on: z.string() });
const closure = z.object({ id, book_id: id, period_start: z.string(), period_end: z.string(), version: z.number().int(), gross_revenue_ex_tax_minor: minor, costs_and_refunds_minor: minor, distributable_profit_minor: minor });
const allocation = z.object({ closure_version_id: id, beneficiary_code: z.string(), share_bps: z.number().int(), amount_minor: minor });
const ledger = z.object({ book_id: id, beneficiary_code: z.string(), amount_minor: minor });

export type FranchiseLoadResult = { status: "success"; dashboard: FranchiseDashboard } | { status: "error"; reason: "UNAUTHENTICATED" | "FORBIDDEN" | "QUERY_FAILED" | "INVALID_RESPONSE" };

export async function loadFranchiseDashboard(): Promise<FranchiseLoadResult> {
  const client = await getSupabaseServerClient(), { data: auth } = await client.auth.getUser(); if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const platform = await client.from("platform_user_roles").select("role_code").eq("user_id", auth.user.id).is("revoked_at", null).limit(20); if (platform.error) return { status: "error", reason: "QUERY_FAILED" };
  const roles = new Set((platform.data ?? []).map((value: { role_code: string }) => value.role_code));
  const [fs, ls, ms, aps, ins, rs, bs, fees, cs, als, ledgers] = await Promise.all([
    client.from("franchises").select("id,library_id,operator_organization_id,franchise_type,operator_code,territory_code,status,current_mandate_version_id,row_version").order("created_at", { ascending: false }).limit(100),
    client.from("catalog_libraries").select("id,code").limit(100),
    client.from("franchise_mandate_versions").select("id,franchise_id,version,mandate_status,entry_fee_minor,entry_fee_mode,franchisee_share_bps,neoxa_share_bps,matricia_share_bps,effective_from").order("version", { ascending: false }).limit(300),
    client.from("franchise_approval_requests").select("id,franchise_id,request_type,status,change_reason,row_version").order("requested_at", { ascending: false }).limit(200),
    client.from("franchise_invitations").select("id,franchise_id,invited_email,status,expires_at,row_version").order("created_at", { ascending: false }).limit(200),
    client.from("franchise_finance_rule_versions").select("id,franchise_type,version,entry_fee_required,franchisee_share_bps,neoxa_share_bps,asma_matricia_share_bps,effective_from").eq("status", "ACTIVE").order("version", { ascending: false }).limit(50),
    client.from("franchise_pnl_books").select("id,library_id,franchise_organization_id,franchise_type,operator_code,currency,opened_under_rule_version_id,status").limit(100),
    client.from("franchise_entry_fee_schedules").select("book_id,mode,principal_minor,deposit_minor,starts_on,due_on").limit(100),
    client.from("franchise_profit_closure_versions").select("id,book_id,period_start,period_end,version,gross_revenue_ex_tax_minor,costs_and_refunds_minor,distributable_profit_minor").order("version", { ascending: false }).limit(300),
    client.from("franchise_profit_allocations").select("closure_version_id,beneficiary_code,share_bps,amount_minor").limit(900),
    client.from("franchise_distribution_ledger_entries").select("book_id,beneficiary_code,amount_minor").limit(2000),
  ]);
  if ([fs, ls, ms, aps, ins, rs, bs, fees, cs, als, ledgers].some((result) => result.error)) return { status: "error", reason: "QUERY_FAILED" };
  const parsed = [z.array(franchise).safeParse(fs.data), z.array(library).safeParse(ls.data), z.array(mandate).safeParse(ms.data), z.array(approval).safeParse(aps.data), z.array(invitation).safeParse(ins.data), z.array(rule).safeParse(rs.data), z.array(book).safeParse(bs.data), z.array(fee).safeParse(fees.data), z.array(closure).safeParse(cs.data), z.array(allocation).safeParse(als.data), z.array(ledger).safeParse(ledgers.data)] as const;
  if (parsed.some((result) => !result.success)) return { status: "error", reason: "INVALID_RESPONSE" };
  const [franchises, libraries, mandates, approvals, invitations, rules, books, schedules, closures, allocations, entries] = parsed.map((result) => result.success ? result.data : []) as [z.infer<typeof franchise>[], z.infer<typeof library>[], z.infer<typeof mandate>[], z.infer<typeof approval>[], z.infer<typeof invitation>[], z.infer<typeof rule>[], z.infer<typeof book>[], z.infer<typeof fee>[], z.infer<typeof closure>[], z.infer<typeof allocation>[], z.infer<typeof ledger>[]];
  if (!franchises.length && !roles.size) return { status: "error", reason: "FORBIDDEN" };
  return { status: "success", dashboard: {
    canApprove: roles.has("SUPER_ADMIN") || roles.has("MATRICIA_ADMIN"), canManageFinance: roles.has("SUPER_ADMIN") || roles.has("FINANCE_MANAGER"),
    franchises: franchises.map((f) => { const lib = libraries.find((l) => l.id === f.library_id), m = mandates.find((value) => value.id === f.current_mandate_version_id) ?? mandates.find((value) => value.franchise_id === f.id); return { id: f.id, libraryCode: lib?.code ?? "—", libraryNameFr: lib?.code ?? "—", libraryNameAr: lib?.code ?? "—", organizationId: f.operator_organization_id, type: f.franchise_type, operatorCode: f.operator_code, territoryCode: f.territory_code, status: f.status, rowVersion: f.row_version, mandate: m ? { id: m.id, version: m.version, status: m.mandate_status, entryFeeMinor: m.entry_fee_minor, entryFeeMode: m.entry_fee_mode, franchiseeShareBps: m.franchisee_share_bps, neoxaShareBps: m.neoxa_share_bps, asmaShareBps: m.matricia_share_bps, effectiveFrom: m.effective_from } : null }; }),
    approvals: approvals.map((v) => ({ id: v.id, franchiseId: v.franchise_id, requestType: v.request_type, status: v.status, reason: v.change_reason, rowVersion: v.row_version })), invitations: invitations.map((v) => ({ id: v.id, franchiseId: v.franchise_id, email: v.invited_email, status: v.status, expiresAt: v.expires_at, rowVersion: v.row_version })), rules: rules.map((v) => ({ id: v.id, franchiseType: v.franchise_type, version: v.version, entryFeeRequired: v.entry_fee_required, franchiseeShareBps: v.franchisee_share_bps, neoxaShareBps: v.neoxa_share_bps, asmaShareBps: v.asma_matricia_share_bps, effectiveFrom: v.effective_from })),
    books: books.map((b) => { const latest = closures.find((v) => v.book_id === b.id), closureAllocations = latest ? allocations.filter((v) => v.closure_version_id === latest.id) : [], schedule = schedules.find((v) => v.book_id === b.id); const beneficiaryCodes = [...new Set(entries.filter((v) => v.book_id === b.id).map((v) => v.beneficiary_code))]; return { id: b.id, libraryId: b.library_id, organizationId: b.franchise_organization_id, type: b.franchise_type, operatorCode: b.operator_code, currency: b.currency, ruleVersionId: b.opened_under_rule_version_id, status: b.status, entryFee: schedule ? { mode: schedule.mode, principalMinor: schedule.principal_minor, depositMinor: schedule.deposit_minor, startsOn: schedule.starts_on, dueOn: schedule.due_on } : null, latestClosure: latest ? { id: latest.id, version: latest.version, periodStart: latest.period_start, periodEnd: latest.period_end, revenueMinor: latest.gross_revenue_ex_tax_minor, costsMinor: latest.costs_and_refunds_minor, profitMinor: latest.distributable_profit_minor } : null, allocations: closureAllocations.map((v) => ({ beneficiaryCode: v.beneficiary_code, shareBps: v.share_bps, amountMinor: v.amount_minor })), balances: beneficiaryCodes.map((code) => ({ beneficiaryCode: code, amountMinor: sumExact(entries.filter((v) => v.book_id === b.id && v.beneficiary_code === code).map((v) => v.amount_minor)) })) }; }),
  } };
}
