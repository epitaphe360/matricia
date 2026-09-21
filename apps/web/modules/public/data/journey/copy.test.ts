import { describe, expect, it } from "vitest";
import { getPublicJourneyCopy } from "./copy";

describe("public diagnostic copy", () => {
  it("ne présente pas le prédiagnostic comme une santé globale", () => {
    const fr = getPublicJourneyCopy("fr").diagnostic;
    const ar = getPublicJourneyCopy("ar").diagnostic;
    expect(fr.intro).toContain("préparent le diagnostic Matricia");
    expect(fr.loginNote).toContain("diagnostic versionné");
    expect(fr.saveOrientation).toContain("orientation");
    expect(fr.continueQuestionnaire).toContain("questionnaire versionné");
    expect(ar.loginNote).toContain("للتشخيص");
    expect(ar.continueQuestionnaire).toContain("الاستبيان");
    expect(fr.resultTitle).toContain("priorités");
  });
});
