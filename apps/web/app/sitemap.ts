import type { MetadataRoute } from "next";
import { getPublicSiteUrl } from "@/lib/seo/metadata";

export default function sitemap(): MetadataRoute.Sitemap {
  const site = getPublicSiteUrl();
  const routes = [
    { path: "", changeFrequency: "weekly" as const, priority: 1 },
    { path: "/diagnostic", changeFrequency: "monthly" as const, priority: 0.9 },
    { path: "/besoin", changeFrequency: "monthly" as const, priority: 0.8 },
    { path: "/fournisseur", changeFrequency: "monthly" as const, priority: 0.8 },
    { path: "/abonnements", changeFrequency: "monthly" as const, priority: 0.8 },
    { path: "/franchise", changeFrequency: "monthly" as const, priority: 0.8 },
    { path: "/a-propos", changeFrequency: "monthly" as const, priority: 0.7 },
    { path: "/contact", changeFrequency: "monthly" as const, priority: 0.7 },
  ];
  return routes.flatMap((route) => {
    const languages = { "fr-MA": new URL(`/fr${route.path}`, site).href, "ar-MA": new URL(`/ar${route.path}`, site).href };
    return (["fr", "ar"] as const).map((locale) => ({
      url: new URL(`/${locale}${route.path}`, site).href,
      lastModified: new Date("2026-09-12T00:00:00.000Z"),
      changeFrequency: route.changeFrequency,
      priority: route.priority,
      alternates: { languages },
    }));
  });
}
