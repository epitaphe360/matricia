import { describe, expect, it } from "vitest";
import { formatMinor, planChangeSchema } from "./model";

describe("subscriptions", () => {
  it("formate les unités mineures sans conversion flottante", () => {
    expect(formatMinor("123456789012345678", "MAD", "fr")).toContain(",78 MAD");
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
});
