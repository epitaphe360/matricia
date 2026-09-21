import { describe, expect, it } from "vitest";
import { formatPublicMoney } from "./money";

describe("public subscription money", () => {
  it("formats exact minor units without binary floating point", () => {
    expect(formatPublicMoney("125050", "MAD", "fr")).toContain("1.250,50");
  });

  it("keeps very large exact amounts", () => {
    expect(formatPublicMoney("900719925474099301", "MAD", "fr")).toContain("9.007.199.254.740.993,01");
  });

  it("uses the currency exponent instead of assuming two decimals", () => {
    expect(formatPublicMoney("1234", "KWD", "fr")).toContain("1,234");
  });
});
