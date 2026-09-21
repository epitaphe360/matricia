import { describe, expect, it } from "vitest";
import { PROVIDER_NESTED_NAV_PATHS, resolveProviderNestedView } from "./nested-views";

describe("resolveProviderNestedView", () => {
  it("résout les vues imbriquées documentées sans les replier", () => {
    expect(resolveProviderNestedView(["consultations", "cr1", "documents"])).toEqual({
      kind: "consultations",
      active: "consult",
      itemId: "cr1",
      view: "documents",
      create: false,
    });
    expect(resolveProviderNestedView(["devis", "d1", "revision"])?.view).toBe("revision");
    expect(resolveProviderNestedView(["devis", "nouveau"])?.create).toBe(true);
    expect(resolveProviderNestedView(["notifications"])?.kind).toBe("messages");
    expect(resolveProviderNestedView(["inconnu"])).toBeNull();
    for (const path of PROVIDER_NESTED_NAV_PATHS) {
      expect(resolveProviderNestedView(path.split("/")), path).not.toBeNull();
    }
  });
});
