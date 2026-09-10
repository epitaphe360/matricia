export type OutboxEnvelope = Readonly<{ id: string; eventType: string; aggregateId: string; occurredAt: string; correlationId: string; payload: Readonly<Record<string, unknown>> }>;
export interface OutboxDispatcher { dispatch(event: OutboxEnvelope): Promise<void> }
export async function dispatchBatch(events: readonly OutboxEnvelope[], dispatcher: OutboxDispatcher) {
  for (const event of events) await dispatcher.dispatch(event);
}
