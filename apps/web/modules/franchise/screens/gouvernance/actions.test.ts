import { beforeEach, describe, expect, it, vi } from "vitest";
const mocks = vi.hoisted(() => ({ getUser: vi.fn(), rpc: vi.fn() }));
vi.mock("@/modules/shared/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, rpc: mocks.rpc }) }));
vi.mock("@/modules/shared/lib/i18n/locale", () => ({ isLocale: (value: string) => value === "fr" || value === "ar" }));
vi.mock("@/modules/franchise/data/governance/model", async () => await import("@/modules/franchise/data/governance/model"));
import { acceptInvitation, createEntryFee, recordPayout, type FranchiseActionState } from "./actions";
const idle: FranchiseActionState = { status: "idle" }, id = "11111111-1111-4111-8111-111111111111", key = "22222222-2222-4222-8222-222222222222";
function form() { const value = new FormData(); value.set("locale", "fr"); value.set("idempotencyKey", key); return value; }
beforeEach(() => { mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id: "u" } } }); mocks.rpc.mockReset().mockResolvedValue({ data: { outcome: "RECORDED" }, error: null }); });
describe("franchise governance actions", () => {
  it("hashes invitation tokens before the RPC", async () => { const value = form(); value.set("invitationId", id); value.set("invitationToken", "temporary-invitation-token-123"); value.set("rowVersion", "1"); await acceptInvitation(idle, value); expect(mocks.rpc).toHaveBeenCalledWith("accept_franchise_invitation", expect.objectContaining({ p_token_hash: "e2f595650024f843fa314306e78da1b887c1565080f8ccfe3adde5347f6bc3d7" })); expect(mocks.rpc.mock.calls[0]?.[1]).not.toHaveProperty("p_token"); });
  it("sends exact minor-unit strings for the IT exemption", async () => { const value = form(); Object.entries({ bookId: id, mode: "EXEMPT", principalMinor: "0", depositMinor: "0", withholdingBps: "", installmentCount: "", startsOn: "2026-09-10", dueOn: "2026-09-10" }).forEach(([name, content]) => value.set(name, content)); await createEntryFee(idle, value); expect(mocks.rpc).toHaveBeenCalledWith("create_franchise_entry_fee_schedule", expect.objectContaining({ p_principal_minor: "0", p_deposit_minor: "0", p_withholding_bps: null })); });
  it("never converts a payout amount to Number", async () => { const value = form(); Object.entries({ bookId: id, beneficiaryCode: "HATIM_AHMITECH", amountMinor: "9007199254740993", journalId: "33333333-3333-4333-8333-333333333333", reference: "VIR-2026-09", proofHash: "a".repeat(64) }).forEach(([name, content]) => value.set(name, content)); await recordPayout(idle, value); expect(mocks.rpc).toHaveBeenCalledWith("record_franchise_distribution_payout", expect.objectContaining({ p_amount_minor: "9007199254740993" })); });
});
