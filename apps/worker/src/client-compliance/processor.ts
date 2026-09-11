import { computeDocumentEvidence } from "./evidence";
import { DocumentScanError, isRetryableScanError, scanErrorCode } from "./errors";
import type { AntivirusScanner, DocumentScanJob, DocumentScanJobRepository, DocumentScanLogger, DocumentScanRecorder, DocumentUploadedEvent, PrivateDocumentStore, RecordedScan } from "./contracts";

export type RetryPolicy = Readonly<{
  maximumAttempts: number;
  delayMs: number;
}>;

export type DocumentScanProcessorDependencies = Readonly<{
  jobs: DocumentScanJobRepository;
  documents: PrivateDocumentStore;
  antivirus: AntivirusScanner;
  recorder: DocumentScanRecorder;
  log: DocumentScanLogger;
  maximumDocumentBytes?: number;
  retryPolicy?: RetryPolicy;
  wait?: (delayMs: number) => Promise<void>;
}>;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const EVENT_ID = /^[1-9][0-9]{0,18}$/;
const DOCUMENT_TYPES = new Set(["REGISTRATION_DOCUMENT", "REPRESENTATIVE_AUTHORITY", "TAX_DOCUMENT"]);
const DEFAULT_RETRY = Object.freeze({ maximumAttempts: 3, delayMs: 200 });

function validateEvent(event: DocumentUploadedEvent): void {
  if (event.eventType !== "DocumentUploadedV1" || !EVENT_ID.test(event.id) || !UUID.test(event.aggregateId)
    || !UUID.test(event.correlationId) || event.aggregateId !== event.payload.document_id
    || event.payload.scan_status !== "PENDING" || !UUID.test(event.payload.organization_id)
    || !UUID.test(event.payload.compliance_case_id) || !DOCUMENT_TYPES.has(event.payload.document_type)) {
    throw new DocumentScanError("DOCUMENT_SCAN_EVENT_INVALID");
  }
}

function validateJobScope(job: DocumentScanJob, event: DocumentUploadedEvent): void {
  if (job.documentId !== event.payload.document_id || job.organizationId !== event.payload.organization_id
    || job.complianceCaseId !== event.payload.compliance_case_id) {
    throw new DocumentScanError("DOCUMENT_SCAN_JOB_INVALID");
  }
}

async function retry<T>(operation: () => Promise<T>, policy: RetryPolicy, wait: (delayMs: number) => Promise<void>): Promise<T> {
  let lastError: unknown;
  for (let attempt = 1; attempt <= policy.maximumAttempts; attempt += 1) {
    try {
      return await operation();
    } catch (error: unknown) {
      lastError = error;
      if (!isRetryableScanError(error) || attempt === policy.maximumAttempts) throw error;
      await wait(policy.delayMs * attempt);
    }
  }
  throw lastError;
}

export function createDocumentScanProcessor(dependencies: DocumentScanProcessorDependencies) {
  const maximumDocumentBytes = dependencies.maximumDocumentBytes ?? 10 * 1024 * 1024;
  const retryPolicy = dependencies.retryPolicy ?? DEFAULT_RETRY;
  const wait = dependencies.wait ?? ((delayMs) => new Promise((resolve) => setTimeout(resolve, delayMs)));
  if (!Number.isSafeInteger(retryPolicy.maximumAttempts) || retryPolicy.maximumAttempts < 1 || retryPolicy.maximumAttempts > 10
    || !Number.isSafeInteger(retryPolicy.delayMs) || retryPolicy.delayMs < 0 || retryPolicy.delayMs > 60_000) {
    throw new DocumentScanError("DOCUMENT_SCAN_EVENT_INVALID");
  }

  return async (event: DocumentUploadedEvent): Promise<RecordedScan> => {
    try {
      validateEvent(event);
      const job = await retry(() => dependencies.jobs.load(event.payload.document_id), retryPolicy, wait);
      validateJobScope(job, event);
      if (job.detectedSizeBytes > maximumDocumentBytes) throw new DocumentScanError("DOCUMENT_TOO_LARGE");
      const content = await retry(() => dependencies.documents.download(job), retryPolicy, wait);
      const evidence = computeDocumentEvidence(content, maximumDocumentBytes);
      if (evidence.sha256 !== job.declaredSha256 || evidence.mimeType !== job.detectedMimeType
        || evidence.sizeBytes !== job.detectedSizeBytes) {
        throw new DocumentScanError("DOCUMENT_EVIDENCE_MISMATCH");
      }
      const result = await retry(() => dependencies.antivirus.scan(content), retryPolicy, wait);
      const recorded = await retry(() => dependencies.recorder.record({
        documentId: job.documentId,
        result,
        computedSha256: evidence.sha256,
        detectedMimeType: evidence.mimeType,
        detectedSizeBytes: evidence.sizeBytes,
        idempotencyKey: `document-scan:${event.id}`,
        correlationId: event.correlationId,
      }), retryPolicy, wait);
      dependencies.log({
        level: result.verdict === "ERROR" ? "warn" : "info",
        event: "client.document.scan",
        outcome: result.verdict === "ERROR" ? "failure" : "success",
        correlationId: event.correlationId,
        documentId: job.documentId,
        result: result.verdict,
        ...(result.verdict === "ERROR" ? { errorCode: "ANTIVIRUS_SCAN_REPORTED_ERROR" } : {}),
      });
      return recorded;
    } catch (error: unknown) {
      dependencies.log({
        level: "error",
        event: "client.document.scan",
        outcome: "failure",
        correlationId: UUID.test(event.correlationId) ? event.correlationId : "invalid-correlation",
        documentId: UUID.test(event.aggregateId) ? event.aggregateId : "invalid-document",
        errorCode: scanErrorCode(error),
      });
      throw error;
    }
  };
}
