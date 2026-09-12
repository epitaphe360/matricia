import { beforeEach, describe, expect, it, vi } from "vitest";
const mocks = vi.hoisted(() => ({ getUser: vi.fn(), rpc: vi.fn() }));
vi.mock("@/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, rpc: mocks.rpc }) }));
vi.mock("@/lib/i18n/locale", () => ({ isLocale: (value: string) => value === "fr" || value === "ar" }));
vi.mock("@/lib/marketing-autopilot/model", async () => await import("../../../../lib/marketing-autopilot/model"));
import { approveCampaign, createCampaign, recordConsent, scheduleCampaign, type MarketingActionState } from "./actions";
const idle: MarketingActionState = { status: "idle" }, id = "11111111-1111-4111-8111-111111111111";
function form(values: Record<string, string>) { const result = new FormData(); result.set("locale", "fr"); result.set("idempotencyKey", id); Object.entries(values).forEach(([key, value]) => result.set(key, value)); return result; }
beforeEach(() => { mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id } } }); mocks.rpc.mockReset().mockResolvedValue({ data: { outcome: "OK" }, error: null }); });
describe("marketing actions", () => {
  it("mappe un retrait de consentement prouvé", async () => { await recordConsent(idle, form({ organizationId: id, purpose: "SOCIAL_PUBLISHING", decision: "WITHDRAWN", policyVersion: "P18-1", evidenceHash: "a".repeat(64) })); expect(mocks.rpc).toHaveBeenCalledWith("record_marketing_consent", expect.objectContaining({ p_decision: "WITHDRAWN" })); });
  it("rejette un snapshot audience qui n’est pas un objet", async () => { const result = await createCampaign(idle, form({ organizationId: id, brandKitVersionId: id, mode: "ASSISTED", titleFr: "Campagne", titleAr: "حملة", frequencyMaxWeekly: "8", riskThreshold: "20", audienceSnapshot: "[]", sourceSnapshot: "{}" })); expect(result).toEqual({ status: "error", reason: "VALIDATION" }); expect(mocks.rpc).not.toHaveBeenCalled(); });
  it("approuve avec verrou optimiste", async () => { await approveCampaign(idle, form({ campaignId: id, rowVersion: "3" })); expect(mocks.rpc).toHaveBeenCalledWith("approve_marketing_campaign", expect.objectContaining({ p_expected_row_version: 3 })); });
  it("planifie en UTC via un lot serveur", async () => { await scheduleCampaign(idle, form({ campaignId: id, contentVersionId: id, socialConnectionId: id, scheduledAt: "2026-09-14T09:30", rowVersion: "4" })); expect(mocks.rpc).toHaveBeenCalledWith("schedule_marketing_campaign", expect.objectContaining({ p_items: [expect.objectContaining({ scheduled_at: "2026-09-14T09:30:00.000Z" })] })); });
  it("échoue fermé sans session", async () => { mocks.getUser.mockResolvedValueOnce({ data: { user: null } }); expect(await approveCampaign(idle, form({ campaignId: id, rowVersion: "1" }))).toEqual({ status: "error", reason: "UNAUTHENTICATED" }); });
});
