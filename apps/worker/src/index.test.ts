import { describe, expect, it, vi } from "vitest";
import { createWorkerRuntime, dispatchBatch, type OutboxEnvelope } from "./index";

const event = (id: string): OutboxEnvelope => ({
  id,
  eventType: "organization.created",
  aggregateId: `organization-${id}`,
  occurredAt: "2026-09-11T12:00:00.000Z",
  correlationId: `correlation-${id}`,
  payload: Object.freeze({ organizationId: `organization-${id}` }),
});

const fixedNow = () => new Date("2026-09-11T12:00:00.000Z");

describe("worker outbox dispatch", () => {
  it("conserve l'ordre du lot avec l'API de compatibilité", async () => {
    const calls: string[] = [];

    await dispatchBatch([event("1"), event("2")], {
      dispatch: async (envelope) => {
        calls.push(envelope.id);
      },
    });

    expect(calls).toEqual(["1", "2"]);
  });

  it("expose un état prêt et une readiness exploitable après succès", async () => {
    const dispatcher = { dispatch: vi.fn(async () => undefined) };
    const ticks = [100, 104, 109, 112];
    const runtime = createWorkerRuntime(dispatcher, fixedNow, () => ticks.shift() ?? 112);

    await runtime.dispatchBatch([event("1"), event("2")]);

    expect(dispatcher.dispatch).toHaveBeenCalledTimes(2);
    expect(runtime.getDispatchState()).toEqual({
      status: "ready",
      queued: 0,
      dispatched: 2,
      latencyMs: 12,
      completedAt: "2026-09-11T12:00:00.000Z",
    });
    expect(runtime.getReadiness()).toEqual({
      status: "ready",
      service: "matricia-worker",
      generated_at: "2026-09-11T12:00:00.000Z",
      checks: { outbox_dispatch: { status: "up", latencyMs: 12 } },
    });
  });

  it("arrête le lot et signale une readiness dégradée après échec", async () => {
    const dispatcher = {
      dispatch: vi.fn(async (envelope: OutboxEnvelope) => {
        if (envelope.id === "2") throw new Error("provider unavailable");
      }),
    };
    const ticks = [200, 203, 208];
    const runtime = createWorkerRuntime(dispatcher, fixedNow, () => ticks.shift() ?? 208);

    await expect(runtime.dispatchBatch([event("1"), event("2"), event("3")]))
      .rejects.toThrow("provider unavailable");

    expect(dispatcher.dispatch).toHaveBeenCalledTimes(2);
    expect(runtime.getDispatchState()).toEqual({
      status: "failed",
      queued: 2,
      dispatched: 1,
      latencyMs: 8,
      failedEventId: "2",
      errorCode: "OUTBOX_DISPATCH_FAILED",
      completedAt: "2026-09-11T12:00:00.000Z",
    });
    expect(runtime.getReadiness()).toMatchObject({
      status: "not_ready",
      checks: {
        outbox_dispatch: {
          status: "down",
          latencyMs: 8,
          code: "OUTBOX_DISPATCH_FAILED",
        },
      },
    });
  });
});
