import { describe, expect, it } from "vitest";
import { regionCodeFromLocation } from "./need-context";

describe("need request context", () => {
  it("déduit la région officielle depuis le lieu saisi en langage courant", () => {
    expect(regionCodeFromLocation("Casablanca, Maârif")).toBe("CASABLANCA_SETTAT");
    expect(regionCodeFromLocation("  rabat_sale_kenitra ")).toBe("RABAT_SALE_KENITRA");
    expect(regionCodeFromLocation("Fès")).toBe("FES_MEKNES");
    expect(regionCodeFromLocation("مراكش")).toBe("MARRAKECH_SAFI");
  });

  it("laisse le choix au client quand le lieu est inconnu ou ambigu", () => {
    expect(regionCodeFromLocation("")).toBe("");
    expect(regionCodeFromLocation("Sur site")).toBe("");
    expect(regionCodeFromLocation("Casablanca ou Rabat")).toBe("");
  });
});
