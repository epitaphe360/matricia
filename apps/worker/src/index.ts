import { buildReadinessReport, type ReadinessReport } from "@matricia/observability";

export type OutboxEnvelope = Readonly<{
  id: string;
  eventType: string;
  aggregateId: string;
  occurredAt: string;
  correlationId: string;
  payload: Readonly<Record<string, unknown>>;
}>;

export interface OutboxDispatcher {
  dispatch(event: OutboxEnvelope): Promise<void>;
}

export type DispatchStatus = "idle" | "dispatching" | "ready" | "failed";

export type WorkerDispatchState = Readonly<{
  status: DispatchStatus;
  queued: number;
  dispatched: number;
  latencyMs: number;
  failedEventId?: string;
  errorCode?: "OUTBOX_DISPATCH_FAILED";
  completedAt?: string;
}>;

export type WorkerRuntime = Readonly<{
  dispatchBatch(events: readonly OutboxEnvelope[]): Promise<void>;
  getDispatchState(): WorkerDispatchState;
  getReadiness(): ReadinessReport;
}>;

export function createWorkerRuntime(
  dispatcher: OutboxDispatcher,
  now: () => Date = () => new Date(),
  monotonicNow: () => number = () => performance.now(),
): WorkerRuntime {
  let state: WorkerDispatchState = Object.freeze({
    status: "idle",
    queued: 0,
    dispatched: 0,
    latencyMs: 0,
  });

  const dispatch = async (events: readonly OutboxEnvelope[]): Promise<void> => {
    const startedAt = monotonicNow();
    let dispatched = 0;
    state = Object.freeze({
      status: "dispatching",
      queued: events.length,
      dispatched,
      latencyMs: 0,
    });

    for (const event of events) {
      try {
        await dispatcher.dispatch(event);
        dispatched += 1;
        state = Object.freeze({
          status: "dispatching",
          queued: events.length - dispatched,
          dispatched,
          latencyMs: Math.max(0, monotonicNow() - startedAt),
        });
      } catch (error: unknown) {
        state = Object.freeze({
          status: "failed",
          queued: events.length - dispatched,
          dispatched,
          latencyMs: Math.max(0, monotonicNow() - startedAt),
          failedEventId: event.id,
          errorCode: "OUTBOX_DISPATCH_FAILED",
          completedAt: now().toISOString(),
        });
        throw error;
      }
    }

    state = Object.freeze({
      status: "ready",
      queued: 0,
      dispatched,
      latencyMs: Math.max(0, monotonicNow() - startedAt),
      completedAt: now().toISOString(),
    });
  };

  return Object.freeze({
    dispatchBatch: dispatch,
    getDispatchState: () => state,
    getReadiness: () => buildReadinessReport(
      "matricia-worker",
      state.status === "failed"
        ? { outbox_dispatch: { status: "down", latencyMs: state.latencyMs, code: "OUTBOX_DISPATCH_FAILED" } }
        : { outbox_dispatch: { status: "up", latencyMs: state.latencyMs } },
      now,
    ),
  });
}

export async function dispatchBatch(
  events: readonly OutboxEnvelope[],
  dispatcher: OutboxDispatcher,
): Promise<void> {
  await createWorkerRuntime(dispatcher).dispatchBatch(events);
}
