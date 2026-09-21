import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ getUser: vi.fn(), rpc: vi.fn() }));
vi.mock("@/modules/shared/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, rpc: mocks.rpc }) }));
vi.mock("@/modules/shared/lib/i18n/locale", () => ({ isLocale: (value: string) => value === "fr" || value === "ar" }));
vi.mock("@/modules/franchise/data/crm/model", async () => await import("@/modules/franchise/data/crm/model"));

import { advancePipeline, recordSnapshot, type FranchiseCrmActionState } from "./actions";

const idle: FranchiseCrmActionState = { status: "idle" };
const id = "11111111-1111-4111-8111-111111111111";
const key = "22222222-2222-4222-8222-222222222222";
function form() { const value = new FormData(); value.set("locale", "fr"); value.set("idempotencyKey", key); return value; }

beforeEach(() => {
  mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id } } });
  mocks.rpc.mockReset().mockResolvedValue({ data: { outcome: "RECORDED" }, error: null });
});

describe("franchise CRM actions", () => {
  it("keeps exact performance integers as strings", async () => {
    const value = form();
    Object.entries({ franchiseId: id, metricVersionId: id, periodStart: "2026-09-01", periodEnd: "2026-09-30", modelVersion: "P10-V1", numerator: "9007199254740993", denominator: "10000000000000000", evidenceReference: "audit://09" }).forEach(([name, content]) => value.set(name, content));
    await recordSnapshot(idle, value);
    expect(mocks.rpc).toHaveBeenCalledWith("record_franchise_performance_snapshot", expect.objectContaining({ p_measurements: [expect.objectContaining({ numerator: "9007199254740993" })] }));
    expect(mocks.rpc).toHaveBeenCalledWith("record_franchise_performance_snapshot", expect.objectContaining({ p_source_evidence_hash: expect.stringMatching(/^[0-9a-f]{64}$/u) }));
  });
  it("sends only the requested sequential stage and row version", async () => {
    const value = form();
    Object.entries({ prospectId: id, toStage: "OPENED", reasonCode: "INVITATION_OPENED", rowVersion: "4", evidenceReference: "event://open" }).forEach(([name, content]) => value.set(name, content));
    await advancePipeline(idle, value);
    expect(mocks.rpc).toHaveBeenCalledWith("advance_franchise_pipeline", expect.objectContaining({ p_to_stage: "OPENED", p_expected_row_version: 4 }));
  });
});
