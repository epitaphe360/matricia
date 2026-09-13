import { describe, expect, it } from "vitest";
import { formatExactDecimal, formatMinorExact, formatScoreBps, narrativeText } from "./model";
const digits = (value: string) => value.replace(/[^0-9]/gu, "");
describe("solution insight formatters", () => {
  it.each([["MAD", "12345"], ["JPY", "900719925474099312345"], ["KWD", "123456789012345678901"]])("préserve exactement les unités mineures %s", (currency, value) => { expect(digits(formatMinorExact(value, currency, "fr"))).toBe(value); });
  it("localise score et benchmark sans perdre leur contrat", () => { expect(formatScoreBps(7550, "fr")).toContain("75"); expect(formatExactDecimal("900719925474099312345.125", "fr").replace(/[^0-9]/gu, "")).toBe("900719925474099312345125"); });
  it("sélectionne strictement le texte localisé", () => { expect(narrativeText({ fr: "Bénéfice", ar: "فائدة" }, "ar")).toBe("فائدة"); });
});
