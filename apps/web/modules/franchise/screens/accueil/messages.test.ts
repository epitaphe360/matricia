import { describe, expect, it } from "vitest";
import { getFranchiseHomeMessages } from "./messages";

describe("franchise home messages", () => {
  it("keeps the same FR and AR contract", () => {
    expect(Object.keys(getFranchiseHomeMessages("ar")).sort()).toEqual(Object.keys(getFranchiseHomeMessages("fr")).sort());
  });

  it("provides native Arabic labels for the cockpit sections", () => {
    const ar = getFranchiseHomeMessages("ar");
    for (const key of ["title", "synthesisTitle", "quickActions", "prioritiesTitle", "kpiFollowups"] as const) {
      expect(ar[key]).toMatch(/[\u0600-\u06ff]/u);
    }
  });

  it("never presents an unavailable metric as zero", () => {
    expect(getFranchiseHomeMessages("fr").synthesisHint).toContain("jamais remplacée par zéro");
    expect(getFranchiseHomeMessages("fr").errorBody).toContain("pas une liste vide");
  });
});
