import type { Metadata } from "next";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

const fallbackSiteUrl = new URL("http://localhost:5173");

function configuredSiteUrl(): string | undefined {
  const explicit = process.env.NEXT_PUBLIC_APP_URL?.trim();
  if (explicit) return explicit;
  const vercelProduction = process.env.VERCEL_PROJECT_PRODUCTION_URL?.trim();
  if (vercelProduction) return vercelProduction.includes("://") ? vercelProduction : `https://${vercelProduction}`;
  const vercelDeployment = process.env.VERCEL_URL?.trim();
  if (vercelDeployment) return vercelDeployment.includes("://") ? vercelDeployment : `https://${vercelDeployment}`;
  return undefined;
}

export function getPublicSiteUrl(): URL {
  const configured = configuredSiteUrl();
  if (!configured) {
    if (process.env.NODE_ENV === "production") throw new Error("PUBLIC_SITE_URL_NOT_CONFIGURED");
    return fallbackSiteUrl;
  }
  try {
    const url = new URL(configured);
    const secureProductionUrl = process.env.NODE_ENV !== "production" || url.protocol === "https:";
    if ((url.protocol !== "http:" && url.protocol !== "https:") || !secureProductionUrl || url.username || url.password) {
      throw new Error("PUBLIC_SITE_URL_INVALID");
    }
    url.pathname = "/";
    url.search = "";
    url.hash = "";
    return url;
  } catch {
    if (process.env.NODE_ENV === "production") throw new Error("PUBLIC_SITE_URL_INVALID");
    return fallbackSiteUrl;
  }
}

export const seoCopy = {
  fr: {
    title: "Connexion sécurisée",
    description: "Accédez à Matricia par code à usage unique pour gérer vos diagnostics, demandes et missions professionnelles.",
    locale: "fr_MA",
  },
  ar: {
    title: "تسجيل دخول آمن",
    description: "ادخل إلى ماتريسيا برمز صالح لمرة واحدة لإدارة التشخيصات والطلبات والمهام المهنية.",
    locale: "ar_MA",
  },
} as const;

export function localizedRouteMetadata(locale: Locale, pathname: string, title: string, description: string): Metadata {
  const canonical = `/${locale}${pathname}`;
  const french = `/fr${pathname}`;
  const arabic = `/ar${pathname}`;
  return {
    title,
    description,
    alternates: { canonical, languages: { "fr-MA": french, "ar-MA": arabic, "x-default": french } },
    robots: { index: true, follow: true, googleBot: { index: true, follow: true, "max-image-preview": "large", "max-snippet": -1, "max-video-preview": -1 } },
    openGraph: {
      type: "website", siteName: "Matricia", title: `${title} | Matricia`, description,
      url: canonical, locale: seoCopy[locale].locale, alternateLocale: locale === "fr" ? [seoCopy.ar.locale] : [seoCopy.fr.locale],
      images: [{ url: "/social-card.svg", width: 1200, height: 630, alt: "Matricia" }],
    },
    twitter: { card: "summary_large_image", title: `${title} | Matricia`, description, images: ["/social-card.svg"] },
  };
}

export function localizedPublicMetadata(locale: Locale, pathname: string): Metadata {
  const copy = seoCopy[locale];
  return localizedRouteMetadata(locale, pathname, copy.title, copy.description);
}

export function publicStructuredData(locale: Locale): string {
  const site = getPublicSiteUrl();
  const copy = seoCopy[locale];
  const graph = {
    "@context": "https://schema.org",
    "@graph": [
      { "@type": "Organization", "@id": new URL("/#organization", site).href, name: "Matricia", url: site.href, logo: new URL("/favicon.svg", site).href },
      { "@type": "WebSite", "@id": new URL("/#website", site).href, name: "Matricia", url: site.href, inLanguage: ["fr-MA", "ar-MA"], publisher: { "@id": new URL("/#organization", site).href } },
      { "@type": "Service", "@id": new URL("/#service", site).href, name: locale === "ar" ? "منصة ماتريسيا" : "Plateforme Matricia", description: copy.description, serviceType: locale === "ar" ? "منصة رقمية للخدمات المهنية" : "Plateforme numérique de services professionnels", areaServed: { "@type": "Country", name: locale === "ar" ? "المغرب" : "Maroc" }, provider: { "@id": new URL("/#organization", site).href } },
    ],
  };
  return JSON.stringify(graph).replace(/</gu, "\\u003c");
}
