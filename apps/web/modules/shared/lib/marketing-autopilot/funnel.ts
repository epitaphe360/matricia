import { createHash } from "node:crypto";
import { cookies } from "next/headers";
import { MARKETING_TOUCH_COOKIE, marketingTouchVisitorHash, verifyMarketingTouch, type MarketingFunnelEvent } from "./funnel-touch";

/**
 * Links a completed business step to the marketing content the visitor clicked.
 * Never throws: attribution must not block registration, diagnostics, requests or contracts.
 * Consent, campaign ownership and deduplication are enforced by ingest_marketing_attribution_event_v1.
 */
export async function recordMarketingFunnelEvent(event: MarketingFunnelEvent, subjectId: string, economicValueMinor: string | null = null): Promise<boolean> {
  try {
    const secret = process.env.MARKETING_CTA_SIGNING_SECRET ?? "";
    const touch = verifyMarketingTouch((await cookies()).get(MARKETING_TOUCH_COOKIE)?.value, secret);
    if (!touch || !/^[0-9a-zA-Z-]{8,80}$/u.test(subjectId) || (economicValueMinor !== null && !/^\d{1,18}$/u.test(economicValueMinor))) return false;
    const idempotencyKey = `funnel:${createHash("sha256").update(`${event}\0${subjectId}\0${touch.nonce}`).digest("hex")}`;
    const { getSupabaseAdminClient } = await import("@/modules/shared/lib/supabase/admin");
    const result = await getSupabaseAdminClient().rpc("ingest_marketing_attribution_event_v1", {
      p_organization_id: touch.organizationId,
      p_campaign_id: touch.campaignId,
      p_content_id: touch.contentId,
      p_event_type: event,
      p_source: touch.source,
      p_medium: touch.medium,
      p_visitor_hash: marketingTouchVisitorHash(touch.nonce, secret),
      p_economic_value_minor: economicValueMinor,
      p_occurred_at: new Date().toISOString(),
      p_metadata: {},
      p_idempotency_key: idempotencyKey,
    });
    return !result.error;
  } catch {
    return false;
  }
}
