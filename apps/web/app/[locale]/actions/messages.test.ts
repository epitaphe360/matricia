import { describe, expect, it } from "vitest";
import { getActionCenterMessages } from "./messages";

describe("action center messages", () => {
  it("localise les actions et la règle anti-sanction en FR et AR", () => {
    const fr = getActionCenterMessages("fr"), ar = getActionCenterMessages("ar");
    expect(fr.kinds.RISK_REVIEW).toBe("Signal de risque");
    expect(ar.kinds.RISK_REVIEW).toBe("إشارة مخاطر");
    expect(fr.noAutomaticSanction).toContain("aucune sanction");
    expect(ar.noAutomaticSanction).toContain("عقوبة");
  });
});

