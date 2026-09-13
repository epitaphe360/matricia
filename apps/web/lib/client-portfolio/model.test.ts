import { describe, expect, it } from "vitest";
import { exactMoney, moneyToMinor } from "./model";

describe("client portfolio exact money", () => {
  it.each([
    ["0", "MAD", "0.00 MAD"],
    ["125005", "MAD", "1250.05 MAD"],
    ["900719925474099312345", "MAD", "9007199254740993123.45 MAD"],
  ])("formats %s without floating point", (minor, currency, expected) => expect(exactMoney(minor, currency)).toBe(expected));

  it.each([["1250", "125000"], ["1250,5", "125050"], ["1250.05", "125005"]])("parses %s exactly", (input, expected) => expect(moneyToMinor(input)).toBe(expected));
  it.each(["-1", "1.001", "NaN", "1e3", "", "12,345"])("rejects malformed amount %s", input => expect(moneyToMinor(input)).toBeNull());
});
