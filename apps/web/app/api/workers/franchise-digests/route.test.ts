import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ rpc: vi.fn() }));
vi.mock("@/modules/shared/lib/supabase/admin", () => ({ getSupabaseAdminClient: () => ({ rpc: mocks.rpc }) }));

import { GET, POST } from "./route";

const token = "d".repeat(32);
const workerId = "11111111-1111-4111-8111-111111111111";
const jobId = "22222222-2222-4222-8222-222222222222";
const leaseToken = "33333333-3333-4333-8333-333333333333";

vi.mock("node:crypto", async (importOriginal) => {
  const original = await importOriginal<typeof import("node:crypto")>();
  let calls = 0;
  return { ...original, randomUUID: () => (++calls % 2 ? workerId : "44444444-4444-4444-8444-444444444444") };
});

function request(query = "", method = "POST") {
  return new Request(`http://localhost/api/workers/franchise-digests${query}`, { method, headers: { authorization: `Bearer ${token}` } });
}

describe("franchise digest worker", () => {
  beforeEach(() => { vi.clearAllMocks(); process.env.CRON_SECRET = token; });

  it("refuse un appel non autorisé", async () => {
    const response = await POST(new Request("http://localhost/api/workers/franchise-digests", { method: "POST" }));
    expect(response.status).toBe(401);
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("refuse une limite hors contrat", async () => {
    expect((await POST(request("?limit=101"))).status).toBe(400);
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("planifie, réclame et notifie les digests avec la lease", async () => {
    mocks.rpc
      .mockResolvedValueOnce({ data: [{ job_id: jobId }], error: null })
      .mockResolvedValueOnce({ data: [{ job_id: jobId, lease_token: leaseToken, worker_id: workerId, row_version: 2 }], error: null })
      .mockResolvedValueOnce({ data: { outcome: "FRANCHISE_DAILY_DIGEST_NOTIFIED" }, error: null });
    const response = await GET(request("?limit=10", "GET"));
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ scheduled: 1, claimed: 1, completed: 1 });
    expect(mocks.rpc).toHaveBeenNthCalledWith(3, "complete_franchise_daily_digest_job", expect.objectContaining({
      p_job_id: jobId, p_lease_token: leaseToken, p_worker_id: workerId, p_expected_row_version: 2,
    }));
  });

  it("échoue fermé si le claim ne respecte pas le contrat", async () => {
    mocks.rpc.mockResolvedValueOnce({ data: [], error: null }).mockResolvedValueOnce({ data: [{ job_id: jobId }], error: null });
    const response = await POST(request());
    expect(response.status).toBe(503);
    expect(mocks.rpc).toHaveBeenCalledTimes(2);
  });

  it("échoue fermé et masque une erreur de complétion", async () => {
    mocks.rpc
      .mockResolvedValueOnce({ data: [], error: null })
      .mockResolvedValueOnce({ data: [{ job_id: jobId, lease_token: leaseToken, worker_id: workerId, row_version: 3 }], error: null })
      .mockResolvedValueOnce({ data: null, error: { message: "lease or recipient detail" } });
    const response = await POST(request());
    expect(response.status).toBe(503);
    const body = JSON.stringify(await response.json());
    expect(body).toContain("FRANCHISE_DIGEST_COMPLETION_FAILED");
    expect(body).not.toContain("lease or recipient detail");
  });

  it("masque les erreurs de base", async () => {
    mocks.rpc.mockResolvedValue({ data: null, error: { message: "secret database detail" } });
    const response = await POST(request());
    expect(response.status).toBe(503);
    expect(JSON.stringify(await response.json())).not.toContain("secret database detail");
  });
});
