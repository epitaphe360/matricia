import { describe, expect, it } from "vitest";
import { analysisInputSchema, parseKnownKeys, parseUuidLines, similarityInputSchema } from "./model";

const id = (n: number) => `${String(n).padStart(8, "0")}-0000-4000-8000-000000000000`;

describe("assisted intelligence model", () => {
  it("déduplique et borne les UUID ciblés sans charger le catalogue", () => {
    expect(parseUuidLines(`${id(1)}\n${id(1)}, ${id(2)}`)).toEqual([id(1), id(2)]);
    expect(parseUuidLines(Array.from({ length: 51 }, (_, index) => id(index + 1)).join("\n"))).toBeNull();
  });

  it("exige un texte borné pour NEED_TEXT", () => {
    const input = { organizationId: id(1), context: "NEED_TEXT", inputText: "x", serviceVersionIds: [], questionVersionIds: [], knownDataKeys: [], modelVersionId: id(2), profileReassessmentId: null, idempotencyKey: id(3), correlationId: id(4) };
    expect(analysisInputSchema.safeParse(input).success).toBe(false);
    expect(analysisInputSchema.safeParse({ ...input, inputText: "Besoin de sauvegarde" }).success).toBe(true);
  });

  it("refuse une similarité hors de la plage 2–50", () => {
    expect(similarityInputSchema.safeParse({ organizationId: id(1), anomalyIds: [id(2)], modelVersionId: id(3), idempotencyKey: id(4), correlationId: id(5) }).success).toBe(false);
    expect(parseKnownKeys("sector.code, sector.code;staff_count")).toEqual(["sector.code", "staff_count"]);
  });
});
