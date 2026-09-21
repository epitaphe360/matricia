import { describe, expect, it } from "vitest";
import { documentKind, formatExactQuantity, formatTaxRate, offerLabel, textList } from "./quote-detail-model";

describe("quote detail model", () => {
  it("formate la TVA en points de base sans flottant", () => {
    expect(formatTaxRate(2000)).toBe("20 %");
    expect(formatTaxRate(1000)).toBe("10 %");
    expect(formatTaxRate(550)).toBe("5,50 %");
    expect(formatTaxRate(-1)).toBe("—");
  });

  it("conserve une quantité exacte", () => {
    expect(formatExactQuantity("1.0000")).toBe("1");
    expect(formatExactQuantity("1.2500")).toBe("1.25");
    expect(formatExactQuantity("2")).toBe("2");
  });

  it("étiquette les offres sans identité prestataire", () => {
    expect(offerLabel(0, "fr")).toBe("Offre A");
    expect(offerLabel(1, "ar")).toBe("العرض B");
    expect(textList(["  Cadrage ", "", "Identité"])).toEqual(["Cadrage", "Identité"]);
    expect(documentKind("Planning.xlsx")).toBe("xlsx");
  });
});
