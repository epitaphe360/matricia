import { describe, expect, it, vi } from "vitest";
import { createSupabaseDocumentScanRecorder, createSupabasePrivateDocumentStore, createSupabaseScanJobRepository } from "./supabase-adapters";
import type { SupabaseScanClient } from "./contracts";

const documentId = "a1111111-1111-4111-8111-111111111111";
const organizationId = "a2222222-2222-4222-8222-222222222222";
const complianceCaseId = "a3333333-3333-4333-8333-333333333333";
const correlationId = "a4444444-4444-4444-8444-444444444444";
const scanId = "a5555555-5555-4555-8555-555555555555";
const path = `${organizationId}/${complianceCaseId}/${documentId}.pdf`;

describe("Supabase document scan adapters", () => {
  it("loads only a bounded private scan-job DTO through the dedicated server RPC", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: {
      document_id: documentId,
      organization_id: organizationId,
      compliance_case_id: complianceCaseId,
      status: "PENDING_REVIEW",
      storage_bucket: "client-compliance",
      storage_object_path: path,
      declared_sha256: "a".repeat(64),
      detected_mime_type: "application/pdf",
      detected_size_bytes: 128,
    }, error: null });
    const client = { rpc } as unknown as SupabaseScanClient;

    await expect(createSupabaseScanJobRepository(client).load(documentId)).resolves.toMatchObject({
      documentId,
      organizationId,
      complianceCaseId,
      storageBucket: "client-compliance",
      storageObjectPath: path,
    });
    expect(rpc).toHaveBeenCalledWith("get_client_document_scan_job", { p_document_id: documentId });
  });

  it("rejects a storage path that is not the exact tenant/case/document layout", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: {
      document_id: documentId, organization_id: organizationId, compliance_case_id: complianceCaseId,
      status: "PENDING_REVIEW", storage_bucket: "client-compliance",
      storage_object_path: `${organizationId}/${complianceCaseId}/another-document.pdf`,
      declared_sha256: "a".repeat(64), detected_mime_type: "application/pdf", detected_size_bytes: 128,
    }, error: null });
    await expect(createSupabaseScanJobRepository({ rpc } as unknown as SupabaseScanClient).load(documentId))
      .rejects.toMatchObject({ code: "DOCUMENT_SCAN_JOB_INVALID" });
  });

  it("downloads from the exact private bucket and object path", async () => {
    const bytes = Buffer.from("%PDF-storage", "ascii");
    const download = vi.fn().mockResolvedValue({ data: new Blob([bytes]), error: null });
    const from = vi.fn().mockReturnValue({ download });
    const client = { storage: { from } } as unknown as SupabaseScanClient;
    const store = createSupabasePrivateDocumentStore(client);

    await expect(store.download({
      documentId, organizationId, complianceCaseId, status: "PENDING_REVIEW",
      storageBucket: "client-compliance", storageObjectPath: path,
      declaredSha256: "a".repeat(64), detectedMimeType: "application/pdf", detectedSizeBytes: bytes.length,
    })).resolves.toEqual(new Uint8Array(bytes));
    expect(from).toHaveBeenCalledWith("client-compliance");
    expect(download).toHaveBeenCalledWith(path);
  });

  it("rejects Blob size mismatch and over-limit before reading bytes", async () => {
    const arrayBuffer = vi.fn().mockResolvedValue(new ArrayBuffer(0));
    const oversizedBlob = { size: 129, arrayBuffer };
    const download = vi.fn().mockResolvedValue({ data: oversizedBlob, error: null });
    const client = { storage: { from: vi.fn().mockReturnValue({ download }) } } as unknown as SupabaseScanClient;
    const store = createSupabasePrivateDocumentStore(client, 128);
    const scanJob = {
      documentId, organizationId, complianceCaseId, status: "PENDING_REVIEW" as const,
      storageBucket: "client-compliance", storageObjectPath: path,
      declaredSha256: "a".repeat(64), detectedMimeType: "application/pdf", detectedSizeBytes: 128,
    };

    await expect(store.download(scanJob)).rejects.toMatchObject({ code: "DOCUMENT_TOO_LARGE" });
    expect(arrayBuffer).not.toHaveBeenCalled();

    oversizedBlob.size = 127;
    await expect(store.download(scanJob)).rejects.toMatchObject({ code: "DOCUMENT_EVIDENCE_MISMATCH" });
    expect(arrayBuffer).not.toHaveBeenCalled();
  });

  it("records the exact evidence with no extracted content or PII", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: {
      outcome: "DOCUMENT_SCAN_RECORDED", document_id: documentId, scan_id: scanId, result: "CLEAN",
    }, error: null });
    const client = { rpc } as unknown as SupabaseScanClient;

    await createSupabaseDocumentScanRecorder(client).record({
      documentId,
      result: { verdict: "CLEAN", engineCode: "CLAMAV_TCP", engineVersion: "1.4.2" },
      computedSha256: "a".repeat(64),
      detectedMimeType: "application/pdf",
      detectedSizeBytes: 128,
      idempotencyKey: "document-scan:42",
      correlationId,
    });

    expect(rpc).toHaveBeenCalledWith("record_client_document_scan_result", {
      p_document_id: documentId,
      p_result: "CLEAN",
      p_engine_code: "CLAMAV_TCP",
      p_engine_version: "1.4.2",
      p_computed_sha256: "a".repeat(64),
      p_detected_mime_type: "application/pdf",
      p_detected_size_bytes: 128,
      p_observed_claims: {},
      p_idempotency_key: "document-scan:42",
      p_correlation_id: correlationId,
    });
  });
});
