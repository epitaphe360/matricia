import type { DocumentUploadedEvent, RecordedScan } from "./contracts";

type UnknownRecord = Record<string, unknown>;

function record(value: unknown): UnknownRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as UnknownRecord : {};
}

function text(value: unknown): string {
  return typeof value === "string" ? value : "";
}

export type DocumentScanOutboxConsumer = Readonly<{
  consume(envelope: unknown): Promise<RecordedScan | null>;
}>;

export function createDocumentScanOutboxConsumer(
  processDocument: (event: DocumentUploadedEvent) => Promise<RecordedScan>,
): DocumentScanOutboxConsumer {
  return Object.freeze({
    async consume(envelope) {
      const source = record(envelope);
      if (source.eventType !== "DocumentUploadedV1") return null;
      const payload = record(source.payload);
      return processDocument({
        id: text(source.id),
        eventType: "DocumentUploadedV1",
        aggregateId: text(source.aggregateId),
        correlationId: text(source.correlationId),
        payload: {
          document_id: text(payload.document_id),
          organization_id: text(payload.organization_id),
          compliance_case_id: text(payload.compliance_case_id),
          document_type: text(payload.document_type),
          scan_status: text(payload.scan_status) as "PENDING",
        },
      });
    },
  });
}
