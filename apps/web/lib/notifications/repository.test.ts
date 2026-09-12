import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ from: vi.fn(), rpc: vi.fn(), getUser: vi.fn() }));
vi.mock("@/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, from: mocks.from, rpc: mocks.rpc }) }));
import { loadNotificationCenter } from "./repository";

function query(data: unknown) {
  const value = { data, error: null };
  const chain: Record<string, unknown> = {};
  for (const method of ["select", "eq", "is", "order", "limit"]) chain[method] = vi.fn(() => chain);
  chain.maybeSingle = vi.fn(async () => value);
  chain.then = (resolve: (result: typeof value) => unknown) => Promise.resolve(value).then(resolve);
  return chain;
}

describe("notification repository", () => {
  beforeEach(() => {
    mocks.getUser.mockResolvedValue({ data: { user: { id: "11111111-1111-4111-8111-111111111111" } } });
    mocks.rpc.mockResolvedValue({ data: { preferences: [], notifications: [] }, error: null });
    mocks.from.mockImplementation((table: string) => {
      if (table === "platform_user_roles") throw new Error("forbidden platform role read");
      if (table === "organization_memberships") return query({ organization_id: "22222222-2222-4222-8222-222222222222", organizations: { display_name: "Client A" } });
      return query([]);
    });
  });

  it("charge le centre Client sans dépendre de la table des rôles plateforme", async () => {
    const result = await loadNotificationCenter("fr");
    expect(result.status).toBe("success");
    expect(mocks.from).not.toHaveBeenCalledWith("platform_user_roles");
    if (result.status === "success") expect(result.dashboard.canViewDeliveryOperations).toBe(false);
  });
});
