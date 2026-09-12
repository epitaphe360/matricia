import { describe, expect, it } from "vitest";
import { createPlanInput, generateInput, transitionPlanInput } from "./model";

const id = "11111111-1111-4111-8111-111111111111";
const identity = { idempotencyKey: id, correlationId: id };
describe("client recurring command models", () => {
  it("limite les cadences au contrat serveur", () => {
    expect(createPlanInput.safeParse({ ...identity, templateRequestId: id, cadence: "MONTHLY", startsOn: "2026-10-01", endsOn: "2027-10-01", reason: "Cycle comptable" }).success).toBe(true);
    expect(createPlanInput.safeParse({ ...identity, templateRequestId: id, cadence: "WEEKLY", startsOn: "2026-10-01", endsOn: "", reason: "Cycle interdit" }).success).toBe(false);
  });
  it("refuse une fin antérieure et plus de 24 occurrences", () => {
    expect(createPlanInput.safeParse({ ...identity, templateRequestId: id, cadence: "ANNUALLY", startsOn: "2026-10-02", endsOn: "2026-10-01", reason: "Dates invalides" }).success).toBe(false);
    expect(generateInput.safeParse({ ...identity, planId: id, throughDate: "2027-01-01", maxOccurrences: 25 }).success).toBe(false);
  });
  it("exige la version optimiste et une transition connue", () => {
    expect(transitionPlanInput.safeParse({ ...identity, planId: id, action: "PAUSE", expectedRowVersion: 2, reason: "Pause demandée" }).success).toBe(true);
    expect(transitionPlanInput.safeParse({ ...identity, planId: id, action: "DELETE", expectedRowVersion: 2, reason: "Action inconnue" }).success).toBe(false);
  });
});

