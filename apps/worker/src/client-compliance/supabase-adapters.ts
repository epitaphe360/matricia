import type { DocumentScanJob, DocumentScanJobRepository, DocumentScanRecorder, PrivateDocumentStore, RecordedScan, SupabaseScanClient } from "./contracts";
import { DocumentScanError } from "./errors";

type ScanJobRow = {
  document_id: unknown;
  organization_id: unknown;
  compliance_case_id: unknown;
  status: unknown;
  storage_bucket: unknown;
  storage_object_path: unknown;
  declared_sha256: unknown;
  detected_mime_type: unknown;
  detected_size_bytes: unknown;
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SHA256 = /^[0-9a-f]{64}$/;
const DOCUMENT_EXTENSION = "(?:pdf|jpe?g|png)";

function asJob(value: unknown): DocumentScanJob {
  const row = (Array.isArray(value) ? value[0] : value) as ScanJobRow | null | undefined;
  if (!row || typeof row.document_id !== "string" || !UUID.test(row.document_id)
    || typeof row.organization_id !== "string" || !UUID.test(row.organization_id)
    || typeof row.compliance_case_id !== "string" || !UUID.test(row.compliance_case_id)
    || !["PENDING_REVIEW", "VERIFIED", "QUARANTINED"].includes(String(row.status))
    || row.storage_bucket !== "client-compliance"
    || typeof row.storage_object_path !== "string" || row.storage_object_path.length > 500
    || typeof row.declared_sha256 !== "string" || !SHA256.test(row.declared_sha256)
    || typeof row.detected_mime_type !== "string"
    || typeof row.detected_size_bytes !== "number" || !Number.isSafeInteger(row.detected_size_bytes) || row.detected_size_bytes < 1) {
    throw new DocumentScanError("DOCUMENT_SCAN_JOB_INVALID");
  }
  const expectedPath = new RegExp(`^${row.organization_id}/${row.compliance_case_id}/${row.document_id}\\.${DOCUMENT_EXTENSION}$`);
  if (!expectedPath.test(row.storage_object_path)) throw new DocumentScanError("DOCUMENT_SCAN_JOB_INVALID");
  return Object.freeze({
    documentId: row.document_id,
    organizationId: row.organization_id,
    complianceCaseId: row.compliance_case_id,
    status: row.status as DocumentScanJob["status"],
    storageBucket: row.storage_bucket,
    storageObjectPath: row.storage_object_path,
    declaredSha256: row.declared_sha256,
    detectedMimeType: row.detected_mime_type.toLowerCase(),
    detectedSizeBytes: row.detected_size_bytes,
  });
}

export function createSupabaseScanJobRepository(client: SupabaseScanClient, rpcName = "get_client_document_scan_job"): DocumentScanJobRepository {
  if (!/^get_[a-z0-9_]{3,80}$/.test(rpcName)) throw new DocumentScanError("DOCUMENT_SCAN_JOB_INVALID");
  return Object.freeze({
    async load(documentId: string) {
      const { data, error } = await client.rpc(rpcName, { p_document_id: documentId });
      if (error) throw new DocumentScanError("DOCUMENT_SCAN_JOB_UNAVAILABLE", true);
      return asJob(data);
    },
  });
}

export function createSupabasePrivateDocumentStore(client: SupabaseScanClient, maximumDocumentBytes = 10 * 1024 * 1024): PrivateDocumentStore {
  if (!Number.isSafeInteger(maximumDocumentBytes) || maximumDocumentBytes < 1) throw new DocumentScanError("DOCUMENT_TOO_LARGE");
  return Object.freeze({
    async download(job: DocumentScanJob) {
      const { data, error } = await client.storage.from(job.storageBucket).download(job.storageObjectPath);
      if (error || !data) throw new DocumentScanError("DOCUMENT_DOWNLOAD_FAILED", true);
      if (typeof data.size === "number" && (data.size > maximumDocumentBytes || data.size !== job.detectedSizeBytes)) {
        throw new DocumentScanError(data.size > maximumDocumentBytes ? "DOCUMENT_TOO_LARGE" : "DOCUMENT_EVIDENCE_MISMATCH");
      }
      return new Uint8Array(await data.arrayBuffer());
    },
  });
}

function asRecordedScan(value: unknown): RecordedScan {
  const row = value as Partial<RecordedScan> | null;
  if (!row || row.outcome !== "DOCUMENT_SCAN_RECORDED" || typeof row.document_id !== "string"
    || typeof row.scan_id !== "string" || !UUID.test(row.scan_id)
    || !["CLEAN", "INFECTED", "ERROR"].includes(String(row.result))) {
    throw new DocumentScanError("DOCUMENT_SCAN_RECORD_FAILED");
  }
  return Object.freeze(row as RecordedScan);
}

export function createSupabaseDocumentScanRecorder(client: SupabaseScanClient): DocumentScanRecorder {
  return Object.freeze({
    async record(input: Parameters<DocumentScanRecorder["record"]>[0]) {
      const { data, error } = await client.rpc("record_client_document_scan_result", {
        p_document_id: input.documentId,
        p_result: input.result.verdict,
        p_engine_code: input.result.engineCode,
        p_engine_version: input.result.engineVersion,
        p_computed_sha256: input.computedSha256,
        p_detected_mime_type: input.detectedMimeType,
        p_detected_size_bytes: input.detectedSizeBytes,
        p_observed_claims: {},
        p_idempotency_key: input.idempotencyKey,
        p_correlation_id: input.correlationId,
      });
      if (error) {
        const retryable = !["22000", "22023", "42501", "55000"].includes(String(error.code));
        throw new DocumentScanError("DOCUMENT_SCAN_RECORD_FAILED", retryable);
      }
      return asRecordedScan(data);
    },
  });
}
