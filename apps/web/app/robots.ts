import type { MetadataRoute } from "next";
import { getPublicSiteUrl } from "@/lib/seo/metadata";

export default function robots(): MetadataRoute.Robots {
  const site = getPublicSiteUrl();
  return {
    rules: [{
      userAgent: "*",
      allow: ["/fr", "/ar", "/fr/services", "/ar/services", "/fr/franchise", "/ar/franchise", "/fr/a-propos", "/ar/a-propos", "/fr/contact", "/ar/contact", "/favicon.svg", "/social-card.svg"],
      disallow: ["/", "/api/", "/fr/auth/", "/ar/auth/", "/fr/administration/", "/ar/administration/", "/fr/client/", "/ar/client/", "/fr/connexion", "/ar/connexion", "/fr/invitations/", "/ar/invitations/", "/fr/notifications/", "/ar/notifications/", "/fr/organisation/", "/ar/organisation/", "/fr/securite/", "/ar/securite/", "/fr/sous-traitant/", "/ar/sous-traitant/", "/fr/tableau-de-bord", "/ar/tableau-de-bord", "/fr/catalogue", "/ar/catalogue"],
    }],
    sitemap: new URL("/sitemap.xml", site).href,
    host: site.origin,
  };
}
