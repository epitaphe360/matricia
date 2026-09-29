import { describe, expect, it } from "vitest";
import { buildMarketingBrandDefaults, marketingHashtag } from "./brand-defaults-model";

describe("marketing brand defaults", () => {
  it("builds approved hashtags from business names", () => {
    expect(marketingHashtag("Atlas Maintenance SARL")).toBe("#AtlasMaintenanceSARL");
    expect(marketingHashtag("Nettoyage & hygiène")).toBe("#NettoyageHygiène");
    expect(marketingHashtag("صيانة المكاتب")).toBe("#صيانةالمكاتب");
    expect(marketingHashtag("!")).toBeNull();
  });

  it("prefills from the latest brand kit version when one exists", () => {
    const value = buildMarketingBrandDefaults({ locale: "fr", displayName: "Atlas", topics: [], siteOrigin: null, payload: { primary_colors: ["#AA2233"], tone: ["PREMIUM"], primary_cta: "CONTACT", tracked_url: "https://atlas.ma/contact", allowed_url_hosts: ["atlas.ma"], approved_hashtags: ["#Atlas"], forbidden_terms: ["gratuit"] } });
    expect(value).toEqual({ source: "BRAND_KIT", primaryColor: "#aa2233", tone: "PREMIUM", primaryCta: "CONTACT", trackedUrl: "https://atlas.ma/contact", allowedHost: "atlas.ma", hashtags: "#Atlas", forbiddenTerms: "gratuit" });
  });

  it("proposes profile values on the secure public site when no brand kit exists", () => {
    const value = buildMarketingBrandDefaults({ locale: "ar", displayName: "Atlas Services", topics: ["Maintenance CVC", "Atlas Services"], siteOrigin: "https://app.matricia.ma", payload: null });
    expect(value).toMatchObject({ source: "PROFILE", trackedUrl: "https://app.matricia.ma/ar/diagnostic", allowedHost: "app.matricia.ma", hashtags: "#AtlasServices, #MaintenanceCVC" });
  });

  it("never proposes a non-HTTPS tracked link", () => {
    expect(buildMarketingBrandDefaults({ locale: "fr", displayName: null, topics: [], siteOrigin: "http://localhost:5173", payload: null })).toMatchObject({ trackedUrl: "https://matricia.ma/fr/diagnostic", allowedHost: "matricia.ma", hashtags: "" });
    expect(buildMarketingBrandDefaults({ locale: "fr", displayName: "X Y", topics: [], siteOrigin: null, payload: { tracked_url: "http://atlas.ma" } }).source).toBe("PROFILE");
  });
});
