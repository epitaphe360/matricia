import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ requestCapture: vi.fn(), rpc: vi.fn(), getUser: vi.fn() }));
vi.mock("@matricia/infrastructure", () => ({
  PaymentGatewayError: class PaymentGatewayError extends Error { constructor(readonly code: string) { super(code); } },
  createPaymentGateway: () => ({ code: "PAYPAL", requestCapture: mocks.requestCapture }),
}));
vi.mock("@/modules/shared/lib/env", () => ({
  getPaymentRuntimeConfig: () => ({}),
  getServerEnvironment: () => ({ NEXT_PUBLIC_APP_URL: "https://app.matricia.test" }),
}));
vi.mock("@/modules/shared/lib/supabase/server", () => ({
  getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, rpc: mocks.rpc }),
}));

import { POST } from "./route";

describe("POST /api/payments/paypal/capture", () => {
  beforeEach(() => {
    mocks.requestCapture.mockReset().mockResolvedValue({ status: "PENDING_WEBHOOK" });
    mocks.rpc.mockReset().mockResolvedValue({ data: { provider_intent_id: "ORDER-12345678", replayed: false }, error: null });
    mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id: "user-1" } } });
  });

  it("resolves the server-owned order and remains pending until webhook", async () => {
    const paymentIntentId = "11111111-1111-4111-8111-111111111111";
    const response = await POST(new Request("https://app.matricia.test/api/payments/paypal/capture", {
      method: "POST", headers: { origin: "https://app.matricia.test", "content-type": "application/json" }, body: JSON.stringify({ paymentIntentId }),
    }));
    expect(response.status).toBe(202);
    expect(await response.json()).toEqual({ paymentIntentId, status: "PENDING_WEBHOOK" });
    expect(mocks.rpc).toHaveBeenCalledWith("prepare_subscription_payment_capture", { p_payment_intent_id: paymentIntentId });
    expect(mocks.requestCapture).toHaveBeenCalledWith("ORDER-12345678", paymentIntentId);
  });

  it("rejects cross-origin requests before auth or provider access", async () => {
    const response = await POST(new Request("https://app.matricia.test/api/payments/paypal/capture", {
      method: "POST", headers: { origin: "https://evil.example", "content-type": "application/json" }, body: "{}",
    }));
    expect(response.status).toBe(403);
    expect(mocks.rpc).not.toHaveBeenCalled();
    expect(mocks.requestCapture).not.toHaveBeenCalled();
  });
});
