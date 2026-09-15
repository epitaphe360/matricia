import { describe, expect, it } from "vitest";
import { minorToMoneyInput, parseMoneyToMinor } from "./money";

describe("provider quote money input", () => {
  it.each([["1 250,50","125050"],["1250.5","125050"],["١٢٥٠٫٥٠","125050"]])("convertit %s en unités mineures exactes", (value, expected) => expect(parseMoneyToMinor(value, "MAD")).toBe(expected));
  it.each(["1.250", "1,2,3", "12.3456", "-2", "2 MAD"])("refuse la saisie ambiguë %s", (value) => expect(parseMoneyToMinor(value, "MAD")).toBeNull());
  it("préserve les montants supérieurs à Number.MAX_SAFE_INTEGER", () => expect(parseMoneyToMinor("90 071 992 547 409,93", "MAD")).toBe("9007199254740993"));
  it("recharge une valeur serveur exacte dans le champ utilisateur", () => expect(minorToMoneyInput("125050", "MAD")).toBe("1250.50"));
  it("respecte les devises à trois décimales", () => expect(parseMoneyToMinor("1,234", "KWD")).toBe("1234"));
});
