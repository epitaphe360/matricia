import { describe, expect, it } from "vitest";
import { formatMinor, planChangeMode, planChangeSchema } from "./model";

describe("subscriptions", () => {
  it("formate les unités mineures sans conversion flottante", () => {
    expect(formatMinor("123456789012345678", "MAD", "fr").replaceAll("\u00a0", " ")).toContain(",78 MAD");
  });

  it("refuse un mode de changement inconnu", () => {
    expect(planChangeSchema.safeParse({
      locale: "fr",
      organizationId: crypto.randomUUID(),
      subscriptionId: crypto.randomUUID(),
      targetPlanVersionId: crypto.randomUUID(),
      changeMode: "IMMEDIATE",
      idempotencyKey: crypto.randomUUID(),
    }).success).toBe(false);
  });

  it("compare les prix historiques exacts sans conversion flottante", () => {
    expect(planChangeMode("9007199254740993", "9007199254740994")).toBe("UPGRADE_IMMEDIATE");
  });
});
