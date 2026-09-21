import { describe, expect, it } from "vitest";
import { getLegalDocument, legalDocumentIds } from "./documents";

describe("public legal documents", () => {
  it("expose les trois documents FR/AR avec chemins stables", () => {
    expect(legalDocumentIds).toEqual(["mentions", "confidentialite", "conditions", "cookies"]);
    expect(getLegalDocument("fr", "mentions").path).toBe("/mentions-legales");
    expect(getLegalDocument("ar", "confidentialite").title).toContain("الخصوصية");
    expect(getLegalDocument("fr", "conditions").sections.length).toBeGreaterThan(0);
  });
});
