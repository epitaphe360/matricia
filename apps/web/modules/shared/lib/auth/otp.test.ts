import { describe, expect, it } from "vitest";
import { normalizeEmail, normalizeOtp } from "./otp";
import { getDictionary } from "../i18n/dictionaries";

describe("OTP identity primitives", () => {
  it("normalizes a valid email without accepting malformed input", () => {
    expect(normalizeEmail("  User@Entreprise.MA ")).toBe("user@entreprise.ma");
    expect(normalizeEmail("missing-domain@" )).toBeNull();
  });

  it("accepts exactly six digits", () => {
    expect(normalizeOtp("123456")).toBe("123456");
    expect(normalizeOtp("12345x")).toBeNull();
  });

  it("keeps French and Arabic authentication keys aligned", () => {
    expect(Object.keys(getDictionary("ar").auth).sort()).toEqual(Object.keys(getDictionary("fr").auth).sort());
    expect(Object.keys(getDictionary("ar").dashboard).sort()).toEqual(Object.keys(getDictionary("fr").dashboard).sort());
  });
});
