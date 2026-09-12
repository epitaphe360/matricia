import { describe, expect, it } from "vitest";
import { campaignInput, consentInput, formatMinor, parseJsonObject, scheduleInput } from "./model";
const id = "11111111-1111-4111-8111-111111111111";
describe("marketing autopilot model", () => {
  it("refuse les consentements sans preuve SHA-256", () => expect(consentInput.safeParse({ organizationId:id,purpose:"SOCIAL_PUBLISHING",decision:"GRANTED",policyVersion:"P18-1",evidenceHash:"secret",idempotencyKey:id }).success).toBe(false));
  it("borne fréquence et risque sans flottants financiers", () => expect(campaignInput.safeParse({ organizationId:id,brandKitVersionId:id,mode:"ASSISTED",titleFr:"Campagne",titleAr:"حملة",frequencyMaxWeekly:8,riskThreshold:20,audienceSnapshot:{segment:"PME"},sourceSnapshot:{version:1},idempotencyKey:id }).success).toBe(true));
  it("impose une date planifiée avec fuseau", () => expect(scheduleInput.safeParse({ campaignId:id,contentVersionId:id,socialConnectionId:id,scheduledAt:"2026-09-13T10:00:00",rowVersion:1,idempotencyKey:id }).success).toBe(false));
  it("rejette les tableaux JSON", () => expect(parseJsonObject("[]").success).toBe(false));
  it("formate les unités mineures exactement", () => expect(formatMinor("12345","MAD","fr")).toContain("123,45"));
});
