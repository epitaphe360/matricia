import type { DocumentScanLogger } from "./contracts";

export function createDocumentScanLogger(sink: (serialized: string) => void, now: () => Date = () => new Date()): DocumentScanLogger {
  return (entry) => {
    sink(JSON.stringify({
      timestamp: now().toISOString(),
      level: entry.level,
      event: entry.event,
      outcome: entry.outcome,
      correlation_id: entry.correlationId.slice(0, 64),
      aggregate_type: "client_compliance_document",
      aggregate_id: entry.documentId.slice(0, 64),
      ...(entry.result === undefined ? {} : { result: entry.result }),
      ...(entry.errorCode === undefined ? {} : { error_code: entry.errorCode }),
    }));
  };
}
