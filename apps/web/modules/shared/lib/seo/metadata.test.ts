import { afterEach, describe, expect, it, vi } from "vitest";
import { getPublicSiteUrl, localizedRouteMetadata } from "./metadata";

describe("public SEO metadata", () => {
  afterEach(() => vi.unstubAllEnvs());

  it("uses the explicit public URL and strips path data", () => {
    vi.stubEnv("NODE_ENV", "production");
    vi.stubEnv("NEXT_PUBLIC_APP_URL", "https://matricia.example/ignored?query=1#fragment");
    expect(getPublicSiteUrl().href).toBe("https://matricia.example/");
  });

  it("uses the Vercel production domain when the explicit URL is absent", () => {
    vi.stubEnv("NODE_ENV", "production");
    vi.stubEnv("NEXT_PUBLIC_APP_URL", "");
    vi.stubEnv("VERCEL_PROJECT_PRODUCTION_URL", "matricia.vercel.app");
    expect(getPublicSiteUrl().href).toBe("https://matricia.vercel.app/");
  });

  it("never emits a localhost canonical in production", () => {
    vi.stubEnv("NODE_ENV", "production");
    vi.stubEnv("NEXT_PUBLIC_APP_URL", "");
    vi.stubEnv("VERCEL_PROJECT_PRODUCTION_URL", "");
    vi.stubEnv("VERCEL_URL", "");
    expect(() => getPublicSiteUrl()).toThrow("PUBLIC_SITE_URL_NOT_CONFIGURED");
  });

  it("keeps localized canonical and language alternates", () => {
    const metadata = localizedRouteMetadata("fr", "/contact", "Contact", "Nous contacter");
    expect(metadata.alternates).toEqual({
      canonical: "/fr/contact",
      languages: { "fr-MA": "/fr/contact", "ar-MA": "/ar/contact", "x-default": "/fr/contact" },
    });
  });
});
