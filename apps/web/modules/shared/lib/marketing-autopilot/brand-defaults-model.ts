import type { Locale } from "@/modules/shared/lib/i18n/locale";

export type MarketingBrandDefaults = {
  source: "BRAND_KIT" | "PROFILE";
  primaryColor: string;
  tone: "PROFESSIONAL" | "PREMIUM" | "DIRECT" | "WARM";
  primaryCta: "DIAGNOSTIC" | "CONTACT" | "NEED";
  trackedUrl: string;
  allowedHost: string;
  hashtags: string;
  forbiddenTerms: string;
};

const tones = ["PROFESSIONAL", "PREMIUM", "DIRECT", "WARM"] as const;
const ctas = ["DIAGNOSTIC", "CONTACT", "NEED"] as const;
const fallbackOrigin = "https://matricia.ma";

export function marketingHashtag(value: string): string | null {
  const words = value.normalize("NFKC").split(/[^\p{L}\p{N}]+/u).filter(Boolean);
  const tag = words.map((word) => word.charAt(0).toLocaleUpperCase("fr") + word.slice(1)).join("").slice(0, 50);
  return tag.length >= 2 ? `#${tag}` : null;
}

function strings(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

function secureOrigin(siteOrigin: string | null): string {
  if (!siteOrigin) return fallbackOrigin;
  try {
    const url = new URL(siteOrigin);
    return url.protocol === "https:" && !url.username && !url.password ? url.origin : fallbackOrigin;
  } catch {
    return fallbackOrigin;
  }
}

export function buildMarketingBrandDefaults(input: { locale: Locale; displayName: string | null; payload: Record<string, unknown> | null; topics: string[]; siteOrigin: string | null }): MarketingBrandDefaults {
  const payload = input.payload;
  if (payload) {
    const color = strings(payload.primary_colors)[0];
    const tone = strings(payload.tone)[0];
    const cta = typeof payload.primary_cta === "string" ? payload.primary_cta : "";
    const trackedUrl = typeof payload.tracked_url === "string" ? payload.tracked_url : "";
    const host = strings(payload.allowed_url_hosts)[0];
    let trackedHost = "";
    try { trackedHost = new URL(trackedUrl).hostname.toLowerCase(); } catch { trackedHost = ""; }
    if (trackedUrl.startsWith("https://") && trackedHost) {
      return {
        source: "BRAND_KIT",
        primaryColor: color && /^#[0-9a-f]{6}$/i.test(color) ? color.toLowerCase() : "#121d58",
        tone: (tones as readonly string[]).includes(tone ?? "") ? (tone as MarketingBrandDefaults["tone"]) : "PROFESSIONAL",
        primaryCta: (ctas as readonly string[]).includes(cta) ? (cta as MarketingBrandDefaults["primaryCta"]) : "DIAGNOSTIC",
        trackedUrl,
        allowedHost: host && host.toLowerCase() === trackedHost ? host.toLowerCase() : trackedHost,
        hashtags: strings(payload.approved_hashtags).join(", "),
        forbiddenTerms: strings(payload.forbidden_terms).join("\n"),
      };
    }
  }
  const origin = secureOrigin(input.siteOrigin);
  const tags = [input.displayName, ...input.topics].flatMap((value) => (value ? [marketingHashtag(value)] : [])).filter((value): value is string => value !== null);
  return {
    source: "PROFILE",
    primaryColor: "#121d58",
    tone: "PROFESSIONAL",
    primaryCta: "DIAGNOSTIC",
    trackedUrl: `${origin}/${input.locale}/diagnostic`,
    allowedHost: new URL(origin).hostname,
    hashtags: [...new Set(tags)].slice(0, 6).join(", "),
    forbiddenTerms: "",
  };
}
