import { createHmac, timingSafeEqual } from "node:crypto";
import { z } from "zod";

export const MARKETING_TOUCH_COOKIE = "matricia_mkt_touch";
export const MARKETING_TOUCH_TTL_SECONDS = 30 * 24 * 60 * 60;

export const marketingFunnelEvents = ["REGISTRATION_STARTED", "DIAGNOSTIC_STARTED", "OPPORTUNITY_CREATED", "RFQ_STARTED", "CONTRACT_SIGNED"] as const;
export type MarketingFunnelEvent = (typeof marketingFunnelEvents)[number];

const channelLabel = z.string().trim().toLowerCase().regex(/^[a-z0-9_.-]{2,80}$/u);
const touchSchema = z.object({
  o: z.string().uuid(),
  c: z.string().uuid(),
  t: z.string().uuid(),
  n: z.string().regex(/^[0-9a-f]{32}$/u),
  s: channelLabel,
  m: channelLabel,
  e: z.number().int().positive(),
}).strict();

export type MarketingTouch = {
  organizationId: string;
  campaignId: string;
  contentId: string;
  nonce: string;
  source: string;
  medium: string;
  expiresAt: number;
};

function signature(body: string, secret: string): string {
  return createHmac("sha256", secret).update(`marketing-touch\0${body}`).digest("hex");
}

/** Signs a server-resolved CTA touch so later server actions can trust campaign and content without trusting the browser. */
export function signMarketingTouch(touch: MarketingTouch, secret: string): string {
  const body = Buffer.from(JSON.stringify({ o: touch.organizationId, c: touch.campaignId, t: touch.contentId, n: touch.nonce, s: touch.source, m: touch.medium, e: touch.expiresAt })).toString("base64url");
  return `${body}.${signature(body, secret)}`;
}

export function verifyMarketingTouch(value: string | undefined | null, secret: string, now = Date.now()): MarketingTouch | null {
  if (!value || secret.length < 32 || value.length > 1024) return null;
  const [body, presented, extra] = value.split(".");
  if (!body || !presented || extra !== undefined || !/^[0-9a-f]{64}$/u.test(presented)) return null;
  const expected = Buffer.from(signature(body, secret), "hex");
  const given = Buffer.from(presented, "hex");
  if (expected.length !== given.length || !timingSafeEqual(expected, given)) return null;
  let raw: unknown;
  try { raw = JSON.parse(Buffer.from(body, "base64url").toString("utf8")); } catch { return null; }
  const parsed = touchSchema.safeParse(raw);
  if (!parsed.success || parsed.data.e <= now) return null;
  return { organizationId: parsed.data.o, campaignId: parsed.data.c, contentId: parsed.data.t, nonce: parsed.data.n, source: parsed.data.s, medium: parsed.data.m, expiresAt: parsed.data.e };
}

export function marketingTouchCookie(value: string): string {
  return `${MARKETING_TOUCH_COOKIE}=${value}; Max-Age=${MARKETING_TOUCH_TTL_SECONDS}; Path=/; Secure; HttpOnly; SameSite=Lax`;
}

/** Pseudonymous visitor key shared by every event of one touch, so the conversion path links click and later steps. */
export function marketingTouchVisitorHash(nonce: string, secret: string): string {
  return createHmac("sha256", secret).update(`marketing-touch-visitor\0${nonce}`).digest("hex");
}

export function marketingChannel(value: string | null | undefined, fallback: string): string {
  const parsed = channelLabel.safeParse(value ?? "");
  return parsed.success ? parsed.data : fallback;
}
