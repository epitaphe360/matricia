import { describe, expect, it, vi } from "vitest";
import { buildWorkerReadiness, createWorkerCycle } from "./worker-cycle";

describe("worker dependency cycle", () => {
  it("continues independent Outbox work while reporting antivirus unavailable", async () => {
    const pollOutbox = vi.fn().mockResolvedValue({ failed: 0 });
    const onFailure = vi.fn();
    const cycle = createWorkerCycle({
      checkAntivirus: vi.fn().mockRejectedValue(new Error("unavailable")),
      pollOutbox,
      onFailure,
      monotonicNow: () => 10,
    });

    await cycle.run();

    expect(pollOutbox).toHaveBeenCalledOnce();
    expect(onFailure).toHaveBeenCalledWith("antivirus");
    expect(cycle.getState()).toEqual({
      antivirus: { ok: false, latencyMs: 0 },
      outbox: { ok: true, latencyMs: 0 },
    });
    expect(buildWorkerReadiness(cycle.getState()).status).not.toBe("ready");
  });

  it("reports ready only after antivirus and Outbox both pass", async () => {
    const cycle = createWorkerCycle({
      checkAntivirus: vi.fn().mockResolvedValue({ status: "up" }),
      pollOutbox: vi.fn().mockResolvedValue({ failed: 0 }),
      onFailure: vi.fn(),
      monotonicNow: () => 10,
    });

    await cycle.run();

    expect(buildWorkerReadiness(cycle.getState()).status).toBe("ready");
  });
});

it("polls unrelated events while the antivirus health check is still waiting", async () => {
  let resolveHealth: () => void = () => {};
  const health = new Promise<void>(resolve => { resolveHealth = resolve; });
  const pollOutbox = vi.fn(async () => ({ failed: 0 }));
  const cycle = createWorkerCycle({ checkAntivirus: () => health, pollOutbox, onFailure: vi.fn() });
  const running = cycle.run();
  expect(pollOutbox).toHaveBeenCalledOnce();
  resolveHealth(); await running;
  expect(buildWorkerReadiness(cycle.getState()).status).toBe("ready");
});

it("does not report financial readiness before the first two durable billing pages", () => {
  const healthy = { antivirus: { ok: true, latencyMs: 2 }, outbox: { ok: true, latencyMs: 3 } };
  expect(buildWorkerReadiness(healthy, { closing: null, reminders: null })).toMatchObject({
    status: "not_ready", checks: {
      provider_billing: { status: "down", code: "PROVIDER_BILLING_NOT_STARTED" },
      provider_billing_reminders: { status: "down", code: "PROVIDER_BILLING_NOT_STARTED" },
    },
  });
});

it.each(["closing", "reminders"] as const)("reports a %s outage despite healthy Outbox and scanner", (failed) => {
  const healthy = { antivirus: { ok: true, latencyMs: 2 }, outbox: { ok: true, latencyMs: 3 } };
  const billing = { closing: { ok: true, latencyMs: 4 }, reminders: { ok: true, latencyMs: 5 }, [failed]: { ok: false, latencyMs: 6 } };
  expect(buildWorkerReadiness(healthy, billing).status).toBe("not_ready");
});

it("reports ready with both verified billing pages and healthy Outbox/scanner", () => {
  const healthy = { antivirus: { ok: true, latencyMs: 2 }, outbox: { ok: true, latencyMs: 3 } };
  expect(buildWorkerReadiness(healthy, { closing: { ok: true, latencyMs: 4 }, reminders: { ok: true, latencyMs: 5 } })).toMatchObject({
    status: "ready", checks: { provider_billing: { status: "up" }, provider_billing_reminders: { status: "up" } },
  });
});
