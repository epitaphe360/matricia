import { describe, expect, it } from "vitest";
import { checklistCompletionSchema,deliverySubmissionSchema, formatExactMinor } from "./model";
const deliverableId = "11111111-1111-4111-8111-111111111111", idempotencyKey = "22222222-2222-4222-8222-222222222222";
const evidenceHash = "a".repeat(64);
describe("provider mission contracts", () => {
  it("accepts a bounded delivery with HTTPS links and a storage proof", () => expect(deliverySubmissionSchema.safeParse({ deliverableId, description: "Livrable vérifié", linksText: "https://example.test/resultat", proofType: "DOCUMENT", proofLocation: "missions/proofs/report.pdf", evidenceHash, proofNote: "Rapport final", idempotencyKey }).success).toBe(true));
  it("rejects traversal and insecure links", () => { expect(deliverySubmissionSchema.safeParse({ deliverableId, description: "Livrable", linksText: "http://example.test", proofType: "DOCUMENT", proofLocation: "../secret.pdf", evidenceHash, proofNote: "", idempotencyKey }).success).toBe(false); });
  it("formats bigint minor units without Number conversion", () => expect(formatExactMinor("900719925474099312", "MAD", "fr")).toContain("9"));
  it("requires a pending checklist item and a UUID proof when supplied",()=>{expect(checklistCompletionSchema.safeParse({itemId:deliverableId,expectedStatus:"PENDING",proofId:"",idempotencyKey}).success).toBe(true);expect(checklistCompletionSchema.safeParse({itemId:deliverableId,expectedStatus:"COMPLETED",proofId:"unsafe",idempotencyKey}).success).toBe(false)});
});
