import { beforeEach, describe, expect, it, vi } from "vitest";
const mocks = vi.hoisted(() => ({ rpc: vi.fn(), from: vi.fn() }));
vi.mock("@/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ rpc: mocks.rpc, from: mocks.from }) }));
import { recordForecast } from "./actions";
const id = "11111111-1111-4111-8111-111111111111", key = "22222222-2222-4222-8222-222222222222";
function form(amount = "1 250,50") { const f = new FormData(); f.set("missionId", id); f.set("start", "2026-09-01"); f.set("end", "2026-09-30"); f.set("grossAmount", amount); f.set("idempotencyKey", key); return f; }
beforeEach(() => { mocks.rpc.mockReset().mockResolvedValue({ data: {}, error: null }); mocks.from.mockReset().mockImplementation((table: string) => ({ select: () => ({ eq: () => ({ maybeSingle: async () => table === "missions" ? { data: { contract_version_id: id }, error: null } : { data: { commission_rule_snapshot: { commission_basis_points: 1000 } }, error: null } }) }) })); });
describe("finance approval actions", () => {
  it("convertit les MAD en unités mineures exactes côté serveur", async () => { await expect(recordForecast({ ok: false, message: "" }, form())).resolves.toEqual({ ok: true, message: "RECORDED" }); expect(mocks.rpc).toHaveBeenCalledWith("record_provider_commission_forecast", expect.objectContaining({ p_estimated_gross_minor: "125050", p_commission_basis_points: 1000 })); });
  it("refuse une saisie monétaire ambiguë avant toute lecture métier", async () => { await expect(recordForecast({ ok: false, message: "" }, form("1,2,3"))).resolves.toEqual({ ok: false, message: "VALIDATION" }); expect(mocks.from).not.toHaveBeenCalled(); });
});
