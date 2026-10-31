import { describe, expect, it } from "vitest";
import { marketingChannel, marketingTouchCookie, marketingTouchVisitorHash, signMarketingTouch, verifyMarketingTouch, type MarketingTouch } from "./funnel-touch";

const secret = "k".repeat(32);
const now = 1_800_000_000_000;
const touch: MarketingTouch = {
  organizationId: "11111111-1111-4111-8111-111111111111",
  campaignId: "22222222-2222-4222-8222-222222222222",
  contentId: "33333333-3333-4333-8333-333333333333",
  nonce: "a".repeat(32),
  source: "linkedin",
  medium: "social",
  expiresAt: now + 60_000,
};

describe("marketing funnel touch", () => {
  it("round-trips a signed touch", () => {
    expect(verifyMarketingTouch(signMarketingTouch(touch, secret), secret, now)).toEqual(touch);
  });

  it("rejects a tampered body, a wrong secret, an expired touch and a short secret", () => {
    const value = signMarketingTouch(touch, secret);
    const [body, signature] = value.split(".");
    const forged = Buffer.from(JSON.stringify({ o: touch.organizationId, c: "99999999-9999-4999-8999-999999999999", t: touch.contentId, n: touch.nonce, s: "linkedin", m: "social", e: touch.expiresAt })).toString("base64url");
    expect(verifyMarketingTouch(`${forged}.${signature}`, secret, now)).toBeNull();
    expect(verifyMarketingTouch(`${body}.${signature}.extra`, secret, now)).toBeNull();
    expect(verifyMarketingTouch(value, "x".repeat(32), now)).toBeNull();
    expect(verifyMarketingTouch(value, secret, touch.expiresAt)).toBeNull();
    expect(verifyMarketingTouch(value, "short", now)).toBeNull();
    expect(verifyMarketingTouch(undefined, secret, now)).toBeNull();
  });

  it("issues an HttpOnly, Secure, site-wide cookie and a stable pseudonymous visitor key", () => {
    expect(marketingTouchCookie("v")).toBe("matricia_mkt_touch=v; Max-Age=2592000; Path=/; Secure; HttpOnly; SameSite=Lax");
    expect(marketingTouchVisitorHash(touch.nonce, secret)).toMatch(/^[0-9a-f]{64}$/);
    expect(marketingTouchVisitorHash(touch.nonce, secret)).toBe(marketingTouchVisitorHash(touch.nonce, secret));
  });

  it("keeps only safe channel labels", () => {
    expect(marketingChannel("LinkedIn", "x")).toBe("linkedin");
    expect(marketingChannel("<script>", "matricia_cta")).toBe("matricia_cta");
    expect(marketingChannel(null, "social")).toBe("social");
  });
});
