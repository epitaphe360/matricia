import { describe, expect, it } from "vitest";
import { organizationReturnPath } from "./return-path";

describe("organizationReturnPath", () => {
  it("keeps the diagnostic save resume path for the same locale", () => {
    expect(organizationReturnPath("fr", "/fr/diagnostic?reprendre=enregistrer")).toBe("/fr/diagnostic?reprendre=enregistrer");
    expect(organizationReturnPath("ar", "/ar/diagnostic?reprendre=enregistrer")).toBe("/ar/diagnostic?reprendre=enregistrer");
  });

  it("drops external, cross-locale and arbitrary destinations", () => {
    for (const value of [undefined, "", "https://evil.example", "//evil.example", "/ar/diagnostic?reprendre=enregistrer", "/fr/admin", "/fr/diagnostic"]) {
      expect(organizationReturnPath("fr", value)).toBeNull();
    }
  });
});
