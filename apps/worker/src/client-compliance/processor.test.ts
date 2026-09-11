import { createHash } from "node:crypto";
import { describe, expect, it, vi } from "vitest";
import { DocumentScanError } from "./errors";
import { createDocumentScanLogger } from "./logger";
import { createDocumentScanProcessor } from "./processor";
import type { AntivirusResult, DocumentScanJob, DocumentUploadedEvent, RecordedScan } from "./contracts";

const documentId = "a1111111-1111-4111-8111-111111111111";
const organizationId = "a2222222-2222-4222-8222-222222222222";
const complianceCaseId = "a3333333-3333-4333-8333-333333333333";
const correlationId = "a4444444-4444-4444-8444-444444444444";
const scanId = "a5555555-5555-4555-8555-555555555555";
const content = new Uint8Array(Buffer.from("%PDF-1.7\nprivate test bytes", "ascii"));
const sha256 = createHash("sha256").update(content).digest("hex");

const event: DocumentUploadedEvent = Object.freeze({
  id: "42",
  eventType: "DocumentUploadedV1",
  aggregateId: documentId,
  correlationId,
  payload: Object.freeze({
    document_id: documentId,
    organization_id: organizationId,
    compliance_case_id: complianceCaseId,
    document_type: "REGISTRATION_DOCUMENT",
    scan_status: "PENDING",
  }),
});

const job: DocumentScanJob = Object.freeze({
  documentId,
  organizationId,
  complianceCaseId,
  status: "PENDING_REVIEW",
  storageBucket: "client-compliance",
  storageObjectPath: `${organizationId}/${complianceCaseId}/${documentId}.pdf`,
  declaredSha256: sha256,
  detectedMimeType: "application/pdf",
  detectedSizeBytes: content.byteLength,
});

function result(verdict: AntivirusResult["verdict"]): AntivirusResult {
  return Object.freeze({ verdict, engineCode: "TEST_ENGINE", engineVersion: "1.0" });
}

function recorded(verdict: AntivirusResult["verdict"]): RecordedScan {
  return Object.freeze({ outcome: "DOCUMENT_SCAN_RECORDED", document_id: documentId, scan_id: scanId, result: verdict });
}

function dependencies(verdict: AntivirusResult["verdict"] = "CLEAN") {
  const record = vi.fn().mockResolvedValue(recorded(verdict));
  const log = vi.fn();
  return {
    record,
    log,
    value: {
      jobs: { load: vi.fn().mockResolvedValue(job) },
      documents: { download: vi.fn().mockResolvedValue(content) },
      antivirus: { scan: vi.fn().mockResolvedValue(result(verdict)) },
      recorder: { record },
      log,
      retryPolicy: { maximumAttempts: 3, delayMs: 0 },
      wait: vi.fn().mockResolvedValue(undefined),
    },
  };
}

describe("client compliance document scan processor", () => {
  it.each(["CLEAN", "INFECTED", "ERROR"] as const)("records a %s verdict using server evidence", async (verdict) => {
    const fixture = dependencies(verdict);
    const processDocument = createDocumentScanProcessor(fixture.value);

    await expect(processDocument(event)).resolves.toEqual(recorded(verdict));
    expect(fixture.record).toHaveBeenCalledWith(expect.objectContaining({
      documentId,
      result: result(verdict),
      computedSha256: sha256,
      detectedMimeType: "application/pdf",
      detectedSizeBytes: content.byteLength,
      idempotencyKey: "document-scan:42",
      correlationId,
    }));
    expect(fixture.log).toHaveBeenCalledWith(expect.objectContaining({ result: verdict }));
  });

  it("fails closed before antivirus and RPC when downloaded evidence differs", async () => {
    const fixture = dependencies();
    fixture.value.jobs.load.mockResolvedValue({ ...job, declaredSha256: "0".repeat(64) });
    const processDocument = createDocumentScanProcessor(fixture.value);

    await expect(processDocument(event)).rejects.toMatchObject({ code: "DOCUMENT_EVIDENCE_MISMATCH" });
    expect(fixture.value.antivirus.scan).not.toHaveBeenCalled();
    expect(fixture.record).not.toHaveBeenCalled();
  });

  it("refuses a confused-deputy job from another organization", async () => {
    const fixture = dependencies();
    fixture.value.jobs.load.mockResolvedValue({ ...job, organizationId: "b2222222-2222-4222-8222-222222222222" });

    await expect(createDocumentScanProcessor(fixture.value)(event)).rejects.toMatchObject({ code: "DOCUMENT_SCAN_JOB_INVALID" });
    expect(fixture.value.documents.download).not.toHaveBeenCalled();
  });

  it("retries transient operations and keeps one stable idempotency key", async () => {
    const fixture = dependencies();
    fixture.value.antivirus.scan
      .mockRejectedValueOnce(new DocumentScanError("ANTIVIRUS_UNAVAILABLE", true))
      .mockResolvedValueOnce(result("CLEAN"));
    fixture.record
      .mockRejectedValueOnce(new DocumentScanError("DOCUMENT_SCAN_RECORD_FAILED", true))
      .mockResolvedValueOnce(recorded("CLEAN"));

    await expect(createDocumentScanProcessor(fixture.value)(event)).resolves.toEqual(recorded("CLEAN"));
    expect(fixture.value.antivirus.scan).toHaveBeenCalledTimes(2);
    expect(fixture.record).toHaveBeenCalledTimes(2);
    expect(fixture.record.mock.calls[0]?.[0].idempotencyKey).toBe("document-scan:42");
    expect(fixture.record.mock.calls[1]?.[0].idempotencyKey).toBe("document-scan:42");
  });

  it("never serializes document content, storage paths, PII or thrown secrets", async () => {
    const lines: string[] = [];
    const fixture = dependencies();
    fixture.value.antivirus.scan.mockRejectedValue(new Error("Bearer secret-token private@example.invalid"));
    const value = {
      ...fixture.value,
      log: createDocumentScanLogger((line) => lines.push(line), () => new Date("2026-09-11T12:00:00.000Z")),
    };

    await expect(createDocumentScanProcessor(value)(event)).rejects.toThrow();
    const serialized = lines.join("\n");
    expect(serialized).not.toContain("secret-token");
    expect(serialized).not.toContain("private@example.invalid");
    expect(serialized).not.toContain(job.storageObjectPath);
    expect(serialized).not.toContain(Buffer.from(content).toString("ascii"));
    expect(serialized).toContain("DOCUMENT_SCAN_RECORD_FAILED");
  });
});
