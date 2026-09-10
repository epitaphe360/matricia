import { describe, expect, it } from "vitest";
import { addMoney, applyBasisPoints, money } from "./money";

describe("money", () => {
  it("additionne uniquement une même devise", () => {
    expect(addMoney(money(10_000n, "MAD"), money(2_500n, "MAD"))).toEqual(money(12_500n, "MAD"));
    expect(() => addMoney(money(1n, "MAD"), money(1n, "EUR"))).toThrow("CURRENCY_MISMATCH");
  });

  it("calcule un taux exact en points de base", () => {
    expect(applyBasisPoints(money(10_001n, "MAD"), 2_000)).toEqual(money(2_000n, "MAD"));
    expect(applyBasisPoints(money(100_005n, "MAD"), 5_000)).toEqual(money(50_003n, "MAD"));
  });
});
