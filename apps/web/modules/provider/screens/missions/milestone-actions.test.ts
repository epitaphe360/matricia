import { beforeEach, describe, expect, it, vi } from "vitest";
const mocks = vi.hoisted(() => ({ getUser: vi.fn(), rpc: vi.fn() }));
vi.mock("@/modules/shared/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, rpc: mocks.rpc }) }));
vi.mock("@/modules/shared/lib/i18n/locale", () => ({ isLocale: (value: string) => value === "fr" || value === "ar" }));
vi.mock("@/modules/provider/data/missions/model", async () => await import("@/modules/provider/data/missions/model"));
import { submitProviderMilestone, type DeliveryActionState } from "./actions";

const idle: DeliveryActionState = { status: "idle" };
const milestoneId = "11111111-1111-4111-8111-111111111111";
const key = "22222222-2222-4222-8222-222222222222";
function form() { const value = new FormData(); value.set("locale", "ar"); value.set("milestoneId", milestoneId); value.set("expectedRowVersion", "2"); value.set("idempotencyKey", key); return value; }

beforeEach(() => { mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id: "user" } } }); mocks.rpc.mockReset().mockResolvedValue({ data: { outcome: "MILESTONE_SUBMITTED" }, error: null }); });
describe("provider milestone submission", () => {
  it("passes the optimistic version and replay key", async () => { await expect(submitProviderMilestone(idle, form())).resolves.toEqual({ status: "success", outcome: "MILESTONE_SUBMITTED" }); expect(mocks.rpc).toHaveBeenCalledWith("submit_mission_milestone", { p_milestone_id: milestoneId, p_expected_row_version: 2, p_idempotency_key: key }); });
  it("maps cross-tenant denial without leaking details", async () => { mocks.rpc.mockResolvedValueOnce({ data: null, error: { code: "42501" } }); await expect(submitProviderMilestone(idle, form())).resolves.toEqual({ status: "error", reason: "FORBIDDEN" }); });
});
