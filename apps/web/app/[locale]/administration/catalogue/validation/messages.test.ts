import { describe, expect, it } from "vitest";
import { getRuleValidationMessages } from "./messages";

describe("rule validation messages", () => {
  it("garde les contrats de traduction FR et AR synchronisés", () => {
    const fr = getRuleValidationMessages("fr");
    const ar = getRuleValidationMessages("ar");
    expect(Object.keys(fr).sort()).toEqual(Object.keys(ar).sort());
    expect(Object.keys(fr.operators).sort()).toEqual(Object.keys(ar.operators).sort());
    expect(Object.keys(fr.actions).sort()).toEqual(Object.keys(ar.actions).sort());
    expect(Object.keys(fr.answerTypes).sort()).toEqual(Object.keys(ar.answerTypes).sort());
    expect(Object.keys(fr.validationCodes).sort()).toEqual(Object.keys(ar.validationCodes).sort());
  });

  it("explique explicitement l’isolation de la simulation", () => {
    expect(getRuleValidationMessages("fr").pureSimulation).toContain("lecture seule");
    expect(getRuleValidationMessages("ar").pureSimulation).toContain("للقراءة فقط");
  });
});
