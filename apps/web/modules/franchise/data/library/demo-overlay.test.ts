import { afterEach, describe, expect, it } from "vitest";
import { overlayFranchiseLibraryDemo } from "./demo-overlay";
import type { FranchiseLibraryWorkspace } from "./workspace";

const empty: FranchiseLibraryWorkspace = {
  mandate: {
    franchiseId: "11111111-1111-4111-8111-111111111111",
    operatorCode: "HATIM_AHMITECH",
    type: "IT",
    libraryId: "22222222-2222-4222-8222-222222222222",
    libraryCode: "IT",
    libraryName: "Informatique",
    libraryStatus: "PUBLISHED",
    libraryRowVersion: 1,
    currentReleaseId: null,
  },
  counts: { drafts: 0, inReview: 0, published: 0, returns: 0 },
  categories: [],
  services: [],
  questionnaires: [],
  rules: [],
  questions: [],
  releases: [],
};

describe("overlayFranchiseLibraryDemo", () => {
  afterEach(() => {
    delete process.env.MATRICIA_DEMO_ACCESS_ENABLED;
    delete process.env.APP_ENV;
  });

  it("remplit la bibliothèque mandatée vide en démo, sans exemple illustratif", () => {
    process.env.MATRICIA_DEMO_ACCESS_ENABLED = "true";
    process.env.APP_ENV = "development";
    const filled = overlayFranchiseLibraryDemo(empty, "fr");
    expect(filled.services.length).toBeGreaterThan(0);
    expect(filled.questionnaires[0]?.title).toBe("Diagnostic SI");
    expect(filled.counts.drafts).toBeGreaterThan(0);
    expect(JSON.stringify(filled)).not.toMatch(/exemple illustratif/i);
  });

  it("laisse une bibliothèque réelle inchangée", () => {
    process.env.MATRICIA_DEMO_ACCESS_ENABLED = "true";
    process.env.APP_ENV = "development";
    const real: FranchiseLibraryWorkspace = {
      ...empty,
      services: [{ id: "s1", kind: "SERVICE", title: "Audit réseau", code: "IT-NET", status: "DRAFT", versionLabel: "v1", href: "/fr/franchise/services", category: "Infra", subcategory: "Réseau", subcategoryId: "sub", description: "Audit", nameFr: "Audit réseau", nameAr: "تدقيق الشبكة" }],
    };
    expect(overlayFranchiseLibraryDemo(real, "fr").services[0]?.title).toBe("Audit réseau");
  });
});
