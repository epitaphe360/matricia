import { describe, expect, it, vi } from "vitest";
import { createNonOverlappingTask } from "./poll-lock";

describe("non-overlapping worker task", () => {
  it("shares one in-flight execution and permits the next cycle after completion", async () => {
    let release: (() => void) | undefined;
    const task = vi.fn(() => new Promise<void>((resolve) => { release = resolve; }));
    const run = createNonOverlappingTask(task);

    const first = run();
    const overlapping = run();
    expect(overlapping).toBe(first);
    expect(task).toHaveBeenCalledOnce();

    release?.();
    await first;
    const next = run();
    expect(task).toHaveBeenCalledTimes(2);
    release?.();
    await next;
  });
});
