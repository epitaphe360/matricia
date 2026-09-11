import { describe, expect, it, vi } from "vitest";
import { createDocumentScanOutboxConsumer } from "./outbox-consumer";

describe("document scan outbox consumer", () => {
  it("ignores unrelated events without side effects", async () => {
    const processDocument = vi.fn();
    await expect(createDocumentScanOutboxConsumer(processDocument).consume({ eventType: "OtherEventV1" })).resolves.toBeNull();
    expect(processDocument).not.toHaveBeenCalled();
  });

  it("maps DocumentUploadedV1 without adding document data", async () => {
    const response = { outcome: "DOCUMENT_SCAN_RECORDED", document_id: "a1111111-1111-4111-8111-111111111111", scan_id: "a5555555-5555-4555-8555-555555555555", result: "CLEAN" } as const;
    const processDocument = vi.fn().mockResolvedValue(response);
    const envelope = {
      id: "42",
      eventType: "DocumentUploadedV1",
      aggregateId: "a1111111-1111-4111-8111-111111111111",
      correlationId: "a4444444-4444-4444-8444-444444444444",
      payload: {
        document_id: "a1111111-1111-4111-8111-111111111111",
        organization_id: "a2222222-2222-4222-8222-222222222222",
        compliance_case_id: "a3333333-3333-4333-8333-333333333333",
        document_type: "REGISTRATION_DOCUMENT",
        scan_status: "PENDING",
      },
    };

    await expect(createDocumentScanOutboxConsumer(processDocument).consume(envelope)).resolves.toEqual(response);
    expect(processDocument).toHaveBeenCalledWith(envelope);
  });
});
