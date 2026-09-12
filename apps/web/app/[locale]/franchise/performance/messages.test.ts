import { describe, expect, it } from "vitest";
import { getFranchiseCrmMessages, localizeFranchiseCrmValue, type FranchiseCrmValueGroup } from "./messages";

const visibleCodes: Record<FranchiseCrmValueGroup, readonly string[]> = {
  activity: ["CALL", "EMAIL", "MEETING", "NOTE", "FOLLOW_UP", "INVITATION"],
  severity: ["INFO", "WARNING", "CRITICAL"],
  alertStatus: ["OPEN", "ACKNOWLEDGED", "RESOLVED"],
  objectiveStatus: ["ACTIVE", "ACHIEVED", "CANCELLED"],
  axis: ["CLIENT_NETWORK", "LIBRARY_QUALITY", "PROVIDER_NETWORK", "DELIVERY_PERFORMANCE", "CLIENT_SATISFACTION", "COMPLIANCE_FINANCE"],
  alertType: ["KPI_THRESHOLD", "LIBRARY_QUALITY", "SLA", "FAVORITISM_RISK", "COMPLIANCE", "FINANCE"],
  franchiseType: ["IT", "STANDARD"],
};

describe("franchise CRM translations", () => {
  it("keeps FR/AR contracts aligned", () => expect(Object.keys(getFranchiseCrmMessages("ar")).sort()).toEqual(Object.keys(getFranchiseCrmMessages("fr")).sort()));
  it("localizes all nine pipeline states", () => expect(Object.keys(getFranchiseCrmMessages("ar").pipeline)).toHaveLength(9));
  it("localizes every visible business code in both languages", () => {
    for (const locale of ["fr", "ar"] as const) for (const [group, codes] of Object.entries(visibleCodes) as [FranchiseCrmValueGroup, readonly string[]][]) for (const code of codes) expect(localizeFranchiseCrmValue(locale, group, code)).not.toBe(code);
  });
  it("provides native Arabic activity, severity, status and axis labels", () => {
    for (const [group, code] of [["activity", "CALL"], ["severity", "CRITICAL"], ["objectiveStatus", "ACTIVE"], ["axis", "CLIENT_NETWORK"]] as const) expect(localizeFranchiseCrmValue("ar", group, code)).toMatch(/[\u0600-\u06ff]/u);
  });
  it("preserves unknown administrable identifiers for auditability", () => expect(localizeFranchiseCrmValue("fr", "axis", "FUTURE_AXIS")).toBe("FUTURE_AXIS"));
});
