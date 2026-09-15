import { describe, expect, it } from "vitest";
import { parseStoredDiagnostic } from "./diagnostic-storage";

describe("public diagnostic storage", () => {
  it("restores a valid versioned draft with stable identifiers", () => {
    const result = parseStoredDiagnostic(JSON.stringify({ version: 2, expiresAt: 2_000, step: 3, answers: { goals: ["grow_sales"], team_size: "small" } }), 1_000);
    expect(result).toMatchObject({ step: 3, answers: { goals: ["grow_sales"], team_size: "small" } });
  });

  it.each([
    "not-json",
    JSON.stringify({ version: 1, expiresAt: 2_000, step: 1, answers: {} }),
    JSON.stringify({ version: 2, expiresAt: 500, step: 1, answers: {} }),
    JSON.stringify({ version: 2, expiresAt: 2_000, step: 99, answers: {} }),
  ])("rejects corrupt, incompatible or expired drafts", (raw) => {
    expect(parseStoredDiagnostic(raw, 1_000)).toBeNull();
  });

  it("drops unknown answer keys instead of trusting them", () => {
    const result = parseStoredDiagnostic(JSON.stringify({ version: 2, expiresAt: 2_000, step: 1, answers: { goals: ["save_time"], secret: "value" } }), 1_000);
    expect(result?.answers).toEqual({ goals: ["save_time"] });
  });
});
