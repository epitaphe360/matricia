import { describe, expect, it } from "vitest";
import { getProviderQuoteMessages } from "./messages";
import { quoteStatusLabel } from "./status-labels";

describe("provider quote localization", () => {
  it("garde les dictionnaires FR et AR alignés", () => expect(Object.keys(getProviderQuoteMessages("ar"))).toEqual(Object.keys(getProviderQuoteMessages("fr"))));
  it("localise les statuts persistés", () => { expect(quoteStatusLabel("SUBMITTED", "fr")).toBe("Soumise"); expect(quoteStatusLabel("SUBMITTED", "ar")).toMatch(/[\u0600-\u06ff]/u); });
  it("localise l'erreur bloquante de configuration fiscale",()=>{expect(getProviderQuoteMessages("fr").taxConfigurationMissing).toContain("ne peut pas être soumis");expect(getProviderQuoteMessages("ar").taxConfigurationMissing).toMatch(/[\u0600-\u06ff]/u);});
});
