import { beforeEach, describe, expect, it, vi } from "vitest";

const rpc = vi.fn();
vi.mock("@/modules/shared/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ rpc }) }));

import { loadPublicSubscriptionPlans } from "./repository";

describe("public subscription repository", () => {
  beforeEach(() => rpc.mockReset());

  it("uses only the restricted public projection", async () => {
    rpc.mockResolvedValue({ data: [{ id:"11111111-1111-4111-8111-111111111111", code:"PREMIUM", currency:"MAD", monthly_price_minor:"10000", annual_price_minor:"100000", monthly_credit_grant:"10" }], error:null });
    await expect(loadPublicSubscriptionPlans()).resolves.toMatchObject({ status:"success", plans:[{ code:"PREMIUM", monthlyPriceMinor:"10000" }] });
    expect(rpc).toHaveBeenCalledWith("get_public_subscription_plans");
  });

  it("fails closed on an invalid projection", async () => {
    rpc.mockResolvedValue({ data: [{ code:"INTERNAL" }], error:null });
    await expect(loadPublicSubscriptionPlans()).resolves.toEqual({ status:"unavailable" });
  });
});
