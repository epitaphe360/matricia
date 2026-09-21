import { beforeEach, describe, expect, it, vi } from "vitest";
const mocks = vi.hoisted(() => ({ getUser: vi.fn(), rpc: vi.fn() }));
vi.mock("@/modules/shared/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, rpc: mocks.rpc }) }));
vi.mock("@/modules/shared/lib/i18n/locale", () => ({ isLocale: (value: string) => value === "fr" || value === "ar" }));
vi.mock("@/modules/shared/lib/contracts-missions/model", async () => await import("@/modules/shared/lib/contracts-missions/model"));
import { decideMilestone, type MissionActionState } from "./actions";

const idle: MissionActionState = { status: "idle" };
const milestoneId = "11111111-1111-4111-8111-111111111111";
const key = "22222222-2222-4222-8222-222222222222";
function form() { const value = new FormData(); value.set("locale", "fr"); value.set("milestoneId", milestoneId); value.set("expectedRowVersion", "3"); value.set("decision", "ACCEPTED"); value.set("reason", "Critères du jalon validés"); value.set("idempotencyKey", key); return value; }

beforeEach(() => { mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id: "user" } } }); mocks.rpc.mockReset().mockResolvedValue({ data: { outcome: "MILESTONE_ACCEPTED" }, error: null }); });
describe("client milestone decision", () => {
  it("passes actor decision, reason, optimistic version and replay key", async () => { await expect(decideMilestone(idle, form())).resolves.toEqual({ status: "success", outcome: "MILESTONE_ACCEPTED" }); expect(mocks.rpc).toHaveBeenCalledWith("decide_mission_milestone", { p_milestone_id: milestoneId, p_expected_row_version: 3, p_decision: "ACCEPTED", p_reason: "Critères du jalon validés", p_idempotency_key: key }); });
  it("rejects a decision without a reason before RPC", async () => { const value = form(); value.set("reason", ""); await expect(decideMilestone(idle, value)).resolves.toEqual({ status: "error", reason: "VALIDATION" }); expect(mocks.rpc).not.toHaveBeenCalled(); });
});
