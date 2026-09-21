import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ rpc: vi.fn() }));
vi.mock("@/modules/shared/lib/supabase/admin", () => ({ getSupabaseAdminClient: () => ({ rpc: mocks.rpc }) }));

import { POST } from "./route";

const token = "t".repeat(32);
function request(query = "") {
  return new Request(`http://localhost/api/workers/marketing-trends${query}`, { method: "POST", headers: { authorization: `Bearer ${token}` } });
}

describe("marketing trend worker", () => {
  beforeEach(() => { vi.clearAllMocks(); process.env.CRON_SECRET = token; });

  it("refuse un appel non autorisé", async () => {
    const response = await POST(new Request("http://localhost/api/workers/marketing-trends", { method: "POST" }));
    expect(response.status).toBe(401);
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("refuse une date qui n'est pas un lundi ISO", async () => {
    const response = await POST(request("?week=2026-09-13"));
    expect(response.status).toBe(400);
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("génère une semaine explicite avec une clé stable", async () => {
    mocks.rpc.mockResolvedValue({ data: { generatedSnapshots: 2, proposedSuggestions: 1, skippedSuggestions: 0, hasMore: false, nextCursor: null }, error: null });
    const response = await POST(request("?week=2026-09-07"));
    expect(response.status).toBe(200);
    expect(mocks.rpc).toHaveBeenCalledWith("generate_weekly_marketing_trends_v1", expect.objectContaining({
      p_idempotency_key: "marketing-trends:2026-09-07:page:0", p_week_start: "2026-09-07", p_limit: 500, p_correlation_id: expect.any(String), p_cursor: null,
    }));
  });

  it("parcourt toutes les pages avec des clés distinctes", async () => {
    mocks.rpc
      .mockResolvedValueOnce({ data: { generatedSnapshots: 500, proposedSuggestions: 4, skippedSuggestions: 2, hasMore: true, nextCursor: "org|library|service" }, error: null })
      .mockResolvedValueOnce({ data: { generatedSnapshots: 3, proposedSuggestions: 1, skippedSuggestions: 0, hasMore: false, nextCursor: null }, error: null });
    const response = await POST(request("?week=2026-09-07"));
    expect(await response.json()).toMatchObject({ generatedSnapshots: 503, proposedSuggestions: 5, pages: 2 });
    expect(mocks.rpc).toHaveBeenNthCalledWith(2, "generate_weekly_marketing_trends_v1", expect.objectContaining({ p_idempotency_key: "marketing-trends:2026-09-07:page:1", p_cursor: "org|library|service" }));
  });

  it("masque les erreurs de base", async () => {
    mocks.rpc.mockResolvedValue({ data: null, error: { message: "sensitive detail" } });
    const response = await POST(request("?week=2026-09-07"));
    expect(response.status).toBe(503);
    expect(JSON.stringify(await response.json())).not.toContain("sensitive detail");
  });
});
