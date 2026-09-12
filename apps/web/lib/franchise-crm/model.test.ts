import { describe, expect, it } from "vitest";
import { formatBasisPoints, nextPipelineStage, PIPELINE_STAGES, snapshotSchema } from "./model";
const id = "11111111-1111-4111-8111-111111111111";
describe("franchise CRM model", () => {
  it("covers the nine ordered pipeline states without skipping", () => { expect(PIPELINE_STAGES).toHaveLength(9); expect(nextPipelineStage("SENT")).toBe("OPENED"); expect(nextPipelineStage("RFQ_STARTED")).toBe("CONTRACT_SIGNED"); expect(nextPipelineStage("CONTRACT_SIGNED")).toBeNull(); });
  it("keeps performance ratios as exact integer strings", () => expect(snapshotSchema.safeParse({ franchiseId: id, metricVersionId: id, periodStart: "2026-09-01", periodEnd: "2026-09-30", modelVersion: "P10-V1", numerator: "9007199254740993", denominator: "10000000000000000", evidenceReference: "audit://period/09", sourceEvidenceHash: "a".repeat(64), idempotencyKey: id }).success).toBe(true));
  it("formats basis points as localized percentages", () => expect(formatBasisPoints(5050, "fr")).toContain("50,5"));
});
