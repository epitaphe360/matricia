import type { SupabaseClient } from "@supabase/supabase-js";

export type DocumentScanVerdict = "CLEAN" | "INFECTED" | "ERROR";

export type DocumentUploadedEvent = Readonly<{
  id: string;
  eventType: "DocumentUploadedV1";
  aggregateId: string;
  correlationId: string;
  payload: Readonly<{
    document_id: string;
    organization_id: string;
    compliance_case_id: string;
    document_type: string;
    scan_status: "PENDING";
  }>;
}>;

export type DocumentScanJob = Readonly<{
  documentId: string;
  organizationId: string;
  complianceCaseId: string;
  status: "PENDING_REVIEW" | "VERIFIED" | "QUARANTINED";
  storageBucket: string;
  storageObjectPath: string;
  declaredSha256: string;
  detectedMimeType: string;
  detectedSizeBytes: number;
}>;

export interface DocumentScanJobRepository {
  load(documentId: string): Promise<DocumentScanJob>;
}

export interface PrivateDocumentStore {
  download(job: DocumentScanJob): Promise<Uint8Array>;
}

export type AntivirusResult = Readonly<{
  verdict: DocumentScanVerdict;
  engineCode: string;
  engineVersion: string;
}>;

export interface AntivirusScanner {
  scan(content: Uint8Array): Promise<AntivirusResult>;
}

export type RecordedScan = Readonly<{
  outcome: "DOCUMENT_SCAN_RECORDED";
  document_id: string;
  scan_id: string;
  result: DocumentScanVerdict;
}>;

export interface DocumentScanRecorder {
  record(input: Readonly<{
    documentId: string;
    result: AntivirusResult;
    computedSha256: string;
    detectedMimeType: string;
    detectedSizeBytes: number;
    idempotencyKey: string;
    correlationId: string;
  }>): Promise<RecordedScan>;
}

export type DocumentScanLog = Readonly<{
  level: "info" | "warn" | "error";
  event: "client.document.scan";
  outcome: "success" | "failure";
  correlationId: string;
  documentId: string;
  result?: DocumentScanVerdict;
  errorCode?: string;
}>;

export type DocumentScanLogger = (entry: DocumentScanLog) => void;

export type SupabaseScanClient = SupabaseClient;
