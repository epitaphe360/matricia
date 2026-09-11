import { buildReadinessReport } from "@matricia/observability";
import { createNonOverlappingTask } from "./poll-lock";

type DependencyCycle = Readonly<{ ok: boolean; latencyMs: number }>;

export type WorkerCycleState = Readonly<{
  antivirus: DependencyCycle | null;
  outbox: DependencyCycle | null;
}>;

export type WorkerCycle = Readonly<{
  run(): Promise<void>;
  getState(): WorkerCycleState;
}>;

export function createWorkerCycle(dependencies: Readonly<{
  checkAntivirus(): Promise<unknown>;
  pollOutbox(): Promise<Readonly<{ failed: number }>>;
  onFailure(dependency: "antivirus" | "outbox"): void;
  monotonicNow?: () => number;
}>): WorkerCycle {
  const monotonicNow = dependencies.monotonicNow ?? (() => performance.now());
  let state: WorkerCycleState = Object.freeze({ antivirus: null, outbox: null });

  const run = createNonOverlappingTask(async () => {
    const antivirusStarted = monotonicNow();
    try {
      await dependencies.checkAntivirus();
      state = Object.freeze({
        ...state,
        antivirus: { ok: true, latencyMs: Math.max(0, monotonicNow() - antivirusStarted) },
      });
    } catch {
      state = Object.freeze({
        antivirus: { ok: false, latencyMs: Math.max(0, monotonicNow() - antivirusStarted) },
        outbox: { ok: false, latencyMs: 0 },
      });
      dependencies.onFailure("antivirus");
      return;
    }

    const outboxStarted = monotonicNow();
    try {
      const result = await dependencies.pollOutbox();
      state = Object.freeze({
        ...state,
        outbox: { ok: result.failed === 0, latencyMs: Math.max(0, monotonicNow() - outboxStarted) },
      });
    } catch {
      state = Object.freeze({
        ...state,
        outbox: { ok: false, latencyMs: Math.max(0, monotonicNow() - outboxStarted) },
      });
      dependencies.onFailure("outbox");
    }
  });

  return Object.freeze({ run, getState: () => state });
}

export function buildWorkerReadiness(state: WorkerCycleState) {
  return buildReadinessReport("matricia-worker", {
    outbox: state.outbox?.ok
      ? { status: "up", latencyMs: state.outbox.latencyMs }
      : { status: "down", latencyMs: state.outbox?.latencyMs ?? 0, code: state.outbox ? "OUTBOX_POLL_FAILED" : "WORKER_NOT_STARTED" },
    antivirus: state.antivirus?.ok
      ? { status: "up", latencyMs: state.antivirus.latencyMs }
      : { status: "down", latencyMs: state.antivirus?.latencyMs ?? 0, code: state.antivirus ? "ANTIVIRUS_UNAVAILABLE" : "WORKER_NOT_STARTED" },
  });
}
