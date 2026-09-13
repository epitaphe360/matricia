import { describe, expect, it } from "vitest";
import { formatBasisPointsExact, isTaxRuleApplicable, lines, quoteDraftInput, taxRulesForCategory } from "./model";

const valid = {
  locale: "fr", rfqProviderId: "11111111-1111-4111-8111-111111111111", currency: "USD", solutionFr: "Solution", solutionAr: "", deliverables: "Audit\nRapport", inclusions: "", exclusions: "", prerequisites: "", warrantyFr: "Douze mois", warrantyAr: "", correctionTermsFr: "Correction incluse", correctionTermsAr: "", proposedStartDate: "2026-10-01", durationDays: "10", validUntil: "2027-01-01T00:00:00.000Z", lineLabelFr: "Forfait", lineLabelAr: "", quantity: "1.2500", unitCode: "forfait", unitPriceMinor: "900719925474099300", taxRuleVersionId: "22222222-2222-4222-8222-222222222222", itemKind: "ONE_TIME", recurrenceInterval: "", changeReason: "Première offre", idempotencyKey: "33333333-3333-4333-8333-333333333333", correlationId: "44444444-4444-4444-8444-444444444444",
};

describe("provider quote contracts", () => {
  it("préserve les montants mineurs exacts au-delà de Number.MAX_SAFE_INTEGER", () => expect(quoteDraftInput.parse(valid).unitPriceMinor).toBe("900719925474099300"));
  it("refuse les décimales monétaires et les récurrences incohérentes", () => {
    expect(quoteDraftInput.safeParse({ ...valid, unitPriceMinor: "10.5" }).success).toBe(false);
    expect(quoteDraftInput.safeParse({ ...valid, itemKind: "RECURRING", recurrenceInterval: "" }).success).toBe(false);
  });
  it("normalise et borne les listes", () => expect(lines(Array.from({ length: 105 }, (_, index) => `L${index}`).join("\n"))).toHaveLength(100));
  it.each([[0,"0"],[5,"0.05"],[1950,"19.5"],[2000,"20"]] as const)("formate %i points de base sans float", (value, expected) => expect(formatBasisPointsExact(value)).toBe(expected));
  it("sélectionne une règle seulement dans sa fenêtre d'effet",()=>{const rule={id:"11111111-1111-4111-8111-111111111111",category:"STANDARD_SERVICE",rateBasisPoints:2000,effectiveFrom:"2026-10-01",effectiveTo:"2026-12-31"};expect(isTaxRuleApplicable(rule,"2026-10-01")).toBe(true);expect(isTaxRuleApplicable(rule,"2026-12-31")).toBe(true);expect(isTaxRuleApplicable(rule,"2026-09-30")).toBe(false);expect(isTaxRuleApplicable(rule,"2027-01-01")).toBe(false);});
  it("échoue fermé si la catégorie fiscale du snapshot est absente ou invalide",()=>{const rules=[{id:"11111111-1111-4111-8111-111111111111",category:"STANDARD_SERVICE",rateBasisPoints:2000,effectiveFrom:"2026-01-01",effectiveTo:null}];expect(taxRulesForCategory(rules,null)).toEqual([]);expect(taxRulesForCategory(rules,"invalid category")).toEqual([]);expect(taxRulesForCategory(rules,"OTHER_SERVICE")).toEqual([]);expect(taxRulesForCategory(rules,"STANDARD_SERVICE")).toEqual(rules);});
});
