import { describe, expect, it } from "vitest";
import { regionCodeFromLocation } from "./need-context";

describe("need request context", () => {
  it("accepte seulement un code région déjà canonique", () => {
    expect(regionCodeFromLocation("MA-CASABLANCA")).toBe("MA-CASABLANCA");
    expect(regionCodeFromLocation("  ma-rabat  ")).toBe("MA-RABAT");
    expect(regionCodeFromLocation("Casablanca")).toBe("");
  });
});
