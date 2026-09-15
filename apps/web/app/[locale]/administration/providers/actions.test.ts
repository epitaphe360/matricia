import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ getUser: vi.fn(), rpc: vi.fn(), maybeSingle: vi.fn() }));
vi.mock("@/lib/supabase/server", () => ({
  getSupabaseServerClient: async () => ({
    auth: { getUser: mocks.getUser },
    rpc: mocks.rpc,
    from: () => ({ select: () => ({ eq: () => ({ maybeSingle: mocks.maybeSingle }) }) }),
  }),
}));
vi.mock("@/lib/admin-providers/model", async () => await import("../../../../lib/admin-providers/model"));
vi.mock("@/lib/provider-billing/model", async () => await import("../../../../lib/provider-billing/model"));
import { reconcileAdminPayment, recordAdminPayment, type AdminProviderActionState } from "./actions";

const idle: AdminProviderActionState = { status: "idle" };
const id = "11111111-1111-4111-8111-111111111111";
function base() { const form = new FormData(); form.set("idempotencyKey", id); return form; }
beforeEach(() => {
  mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id } } });
  mocks.rpc.mockReset().mockResolvedValue({ data: { outcome: "RECORDED" }, error: null });
  mocks.maybeSingle.mockReset().mockResolvedValue({ data: { currency: "MAD" }, error: null });
});

describe("admin provider finance actions", () => {
  it("convertit exactement les dirhams et calcule l’empreinte du justificatif", async () => {
    const form = base();
    Object.entries({ organizationId: id, paymentReference: "VIR-2026-09", paidOn: "2026-09-15", paymentMethod: "BANK_TRANSFER", currency: "MAD", amount: "1 250,50", cashAccountId: id, receivableAccountId: id }).forEach(([key, value]) => form.set(key, value));
    form.set("proofFile", new File([new Uint8Array([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31])], "preuve.pdf", { type: "application/pdf" }));
    expect(await recordAdminPayment(idle, form)).toEqual({ status: "success", outcome: "RECORDED" });
    expect(mocks.rpc).toHaveBeenCalledWith("record_provider_payment", expect.objectContaining({ p_amount_minor: "125050", p_proof_hash: expect.stringMatching(/^[0-9a-f]{64}$/u) }));
  });

  it("refuse un faux PDF au lieu de fabriquer une preuve", async () => {
    const form = base();
    Object.entries({ organizationId: id, paymentReference: "VIR-2026-09", paidOn: "2026-09-15", paymentMethod: "BANK_TRANSFER", currency: "MAD", amount: "10,00", cashAccountId: id, receivableAccountId: id }).forEach(([key, value]) => form.set(key, value));
    form.set("proofFile", new File(["not-a-pdf"], "preuve.pdf", { type: "application/pdf" }));
    expect(await recordAdminPayment(idle, form)).toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("dérive la devise du règlement avant le rapprochement", async () => {
    const form = base(); form.set("paymentId", id); form.set("invoiceId", id); form.set("amount", "99,95");
    expect(await reconcileAdminPayment(idle, form)).toEqual({ status: "success", outcome: "RECORDED" });
    expect(mocks.rpc).toHaveBeenCalledWith("reconcile_provider_payment", expect.objectContaining({ p_allocations: [{ invoice_id: id, amount_minor: "9995" }] }));
  });
});
