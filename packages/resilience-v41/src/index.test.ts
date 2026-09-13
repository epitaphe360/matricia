import { describe, expect, it } from "vitest";
import { assertContinuityObjective, assertRedactedPayload, mayClaimRestoreExecuted } from "./index";

describe("V4.1 resilience invariants", () => {
  it("rejects secret and PII keys in operational payloads", () => {
    expect(() => assertRedactedPayload({ token: "masked" })).toThrow("SENSITIVE_OPERATIONAL_FIELD:token");
    expect(() => assertRedactedPayload({ email: "masked" })).toThrow("SENSITIVE_OPERATIONAL_FIELD:email");
    expect(() => assertRedactedPayload({ safe: [{ nested: { prompt: "masked" } }] })).toThrow("SENSITIVE_OPERATIONAL_FIELD:prompt");
    expect(() => assertRedactedPayload({ aggregate_id: "safe" })).not.toThrow();
  });

  it("requires exact positive RPO/RTO objectives", () => {
    expect(() => assertContinuityObjective({ serviceCode: "DB", rpoMinutes: 60, rtoMinutes: 240, degradationMode: "READ_ONLY" })).not.toThrow();
    expect(() => assertContinuityObjective({ serviceCode: "DB", rpoMinutes: 241, rtoMinutes: 240, degradationMode: "READ_ONLY" })).toThrow("CONTINUITY_OBJECTIVE_INVALID");
    expect(() => assertContinuityObjective({ serviceCode: "DB", rpoMinutes: 1.5, rtoMinutes: 2, degradationMode: "READ_ONLY" })).toThrow("CONTINUITY_OBJECTIVE_INTEGER_REQUIRED");
  });

  it("never turns missing external restore work into passed evidence", () => {
    expect(mayClaimRestoreExecuted("REQUIRED_NOT_COMPLETED", {})).toBe(true);
    expect(mayClaimRestoreExecuted("REQUIRED_NOT_COMPLETED", { executedAt: "2026-09-13T00:00:00Z" })).toBe(false);
    expect(mayClaimRestoreExecuted("PASSED", { executedAt: "2026-09-13T00:00:00Z", evidenceHash: "a".repeat(64) })).toBe(true);
    expect(mayClaimRestoreExecuted("PASSED", {})).toBe(false);
  });
});
