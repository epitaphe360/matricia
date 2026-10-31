import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ rpc: vi.fn() }));
vi.mock("@/modules/shared/lib/supabase/admin", () => ({ getSupabaseAdminClient: () => ({ rpc: mocks.rpc }) }));

import { POST } from "./route";

const token = "t".repeat(32);
function request(query = "") {
  return new Request(`http://localhost/api/workers/marketing-frequency${query}`, { method: "POST", headers: { authorization: `Bearer ${token}` } });
}

describe("marketing weekly frequency worker", () => {
  beforeEach(() => { vi.clearAllMocks(); process.env.CRON_SECRET = token; });

  it("refuse un appel non autorisé", async () => {
    const response = await POST(new Request("http://localhost/api/workers/marketing-frequency", { method: "POST" }));
    expect(response.status).toBe(401);
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("refuse une date qui n'est pas un lundi ou qui est future", async () => {
    expect((await POST(request("?week=2026-09-13"))).status).toBe(400);
    expect((await POST(request("?week=2999-01-06"))).status).toBe(400);
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("applique la semaine avec une clé d'idempotence stable", async () => {
    mocks.rpc.mockResolvedValue({ data: { outcome: "MARKETING_WEEKLY_FREQUENCY_APPLIED", applied: 2, human_review_required: 1, at_limit: 0 }, error: null });
    const response = await POST(request("?week=2026-09-07"));
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ weekStart: "2026-09-07", applied: 2, humanReviewRequired: 1, atLimit: 0 });
    expect(mocks.rpc).toHaveBeenCalledWith("apply_marketing_weekly_frequency_v1", { p_week_start: "2026-09-07", p_idempotency_key: "marketing-frequency:2026-09-07", p_correlation_id: expect.any(String) });
  });

  it("masque les erreurs de base et les réponses invalides", async () => {
    mocks.rpc.mockResolvedValueOnce({ data: null, error: { message: "sensitive detail" } });
    const failed = await POST(request("?week=2026-09-07"));
    expect(failed.status).toBe(503);
    expect(JSON.stringify(await failed.json())).not.toContain("sensitive detail");
    mocks.rpc.mockResolvedValueOnce({ data: { outcome: "MARKETING_WEEKLY_FREQUENCY_APPLIED", applied: "2" }, error: null });
    expect((await POST(request("?week=2026-09-07"))).status).toBe(503);
  });
});
