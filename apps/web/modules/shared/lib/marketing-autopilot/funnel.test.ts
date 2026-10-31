import { beforeEach, describe, expect, it, vi } from "vitest";
import { MARKETING_TOUCH_COOKIE, signMarketingTouch } from "./funnel-touch";

const mocks = vi.hoisted(() => ({ rpc: vi.fn(), cookie: vi.fn() }));
vi.mock("next/headers", () => ({ cookies: async () => ({ get: mocks.cookie }) }));
vi.mock("@/modules/shared/lib/supabase/admin", () => ({ getSupabaseAdminClient: () => ({ rpc: mocks.rpc }) }));

import { recordMarketingFunnelEvent } from "./funnel";

const secret = "f".repeat(32);
const touch = { organizationId: "11111111-1111-4111-8111-111111111111", campaignId: "22222222-2222-4222-8222-222222222222", contentId: "33333333-3333-4333-8333-333333333333", nonce: "b".repeat(32), source: "linkedin", medium: "social", expiresAt: Date.now() + 60_000 };
const subject = "44444444-4444-4444-8444-444444444444";

describe("recordMarketingFunnelEvent", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    process.env.MARKETING_CTA_SIGNING_SECRET = secret;
    mocks.rpc.mockResolvedValue({ data: { outcome: "MARKETING_ATTRIBUTION_INGESTED" }, error: null });
  });

  it("does nothing without a signed touch", async () => {
    mocks.cookie.mockReturnValue(undefined);
    expect(await recordMarketingFunnelEvent("RFQ_STARTED", subject)).toBe(false);
    mocks.cookie.mockReturnValue({ value: "forged.value" });
    expect(await recordMarketingFunnelEvent("RFQ_STARTED", subject)).toBe(false);
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("ingests the step with the signed campaign and a deterministic idempotency key", async () => {
    mocks.cookie.mockImplementation((name: string) => (name === MARKETING_TOUCH_COOKIE ? { value: signMarketingTouch(touch, secret) } : undefined));
    expect(await recordMarketingFunnelEvent("CONTRACT_SIGNED", subject)).toBe(true);
    expect(await recordMarketingFunnelEvent("CONTRACT_SIGNED", subject)).toBe(true);
    expect(mocks.rpc).toHaveBeenCalledTimes(2);
    const [first, second] = mocks.rpc.mock.calls.map((call) => call[1] as Record<string, unknown>);
    expect(first).toMatchObject({ p_organization_id: touch.organizationId, p_campaign_id: touch.campaignId, p_content_id: touch.contentId, p_event_type: "CONTRACT_SIGNED", p_metadata: {}, p_economic_value_minor: null });
    expect(first!.p_idempotency_key).toMatch(/^funnel:[0-9a-f]{64}$/);
    expect(second!.p_idempotency_key).toBe(first!.p_idempotency_key);
  });

  it("never throws and reports a refused ingestion", async () => {
    mocks.cookie.mockReturnValue({ value: signMarketingTouch(touch, secret) });
    mocks.rpc.mockResolvedValueOnce({ data: null, error: { message: "CONSENT" } });
    expect(await recordMarketingFunnelEvent("DIAGNOSTIC_STARTED", subject)).toBe(false);
    mocks.rpc.mockRejectedValueOnce(new Error("network"));
    expect(await recordMarketingFunnelEvent("DIAGNOSTIC_STARTED", subject)).toBe(false);
    expect(await recordMarketingFunnelEvent("DIAGNOSTIC_STARTED", "not valid!")).toBe(false);
  });
});
