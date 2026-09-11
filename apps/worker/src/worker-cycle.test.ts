import { describe, expect, it, vi } from "vitest";
import { buildWorkerReadiness, createWorkerCycle } from "./worker-cycle";

describe("worker dependency cycle", () => {
  it("does not claim Outbox work and reports not ready when antivirus is unavailable", async () => {
    const pollOutbox = vi.fn();
    const onFailure = vi.fn();
    const cycle = createWorkerCycle({
      checkAntivirus: vi.fn().mockRejectedValue(new Error("unavailable")),
      pollOutbox,
      onFailure,
      monotonicNow: () => 10,
    });

    await cycle.run();

    expect(pollOutbox).not.toHaveBeenCalled();
    expect(onFailure).toHaveBeenCalledWith("antivirus");
    expect(cycle.getState()).toEqual({
      antivirus: { ok: false, latencyMs: 0 },
      outbox: { ok: false, latencyMs: 0 },
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
