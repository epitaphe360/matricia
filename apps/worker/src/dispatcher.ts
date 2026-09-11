import type { DocumentScanOutboxConsumer } from "./client-compliance";
import type { OutboxDispatcher, OutboxEnvelope } from "./index";

type Fetch = typeof fetch;

export type WorkerDispatcherDependencies = Readonly<{
  documentScanConsumer: DocumentScanOutboxConsumer;
  dispatchUrl: URL;
  webhookSecret: string;
  fetcher?: Fetch;
}>;

export function createWorkerDispatcher(dependencies: WorkerDispatcherDependencies): OutboxDispatcher {
  const fetcher = dependencies.fetcher ?? fetch;
  return Object.freeze({
    async dispatch(event: OutboxEnvelope) {
      const scan = await dependencies.documentScanConsumer.consume(event);
      if (scan !== null) return;

      const response = await fetcher(dependencies.dispatchUrl, {
        method: "POST",
        headers: {
          authorization: `Bearer ${dependencies.webhookSecret}`,
          "content-type": "application/json",
          "x-correlation-id": event.correlationId,
        },
        body: JSON.stringify(event),
        signal: AbortSignal.timeout(10_000),
      });
      if (!response.ok) throw new Error("OUTBOX_DISPATCH_REJECTED");
    },
  });
}
