type RpcResult = { data: unknown; error: unknown };
export type FranchisePerformanceRpcClient = { rpc(name: string, parameters: Record<string, unknown>): PromiseLike<RpcResult> };

/** Database owns periods, source facts, locks, immutable reports and bounded resume. */
export function createFranchisePerformanceScheduler(client: FranchisePerformanceRpcClient) {
  let running = false;
  return async () => {
    if (running) return;
    running = true;
    try {
      const result = await client.rpc("run_franchise_performance_control_v1", { p_limit: 25 });
      if (result.error || !result.data || typeof result.data !== "object") throw new Error("FRANCHISE_CONTROL_SCHEDULER_FAILED");
      const receipt = result.data as Record<string, unknown>;
      if (!["FRANCHISE_CONTROL_COMPLETED", "FRANCHISE_CONTROL_BUSY"].includes(String(receipt.outcome))
        || !Number.isSafeInteger(receipt.processed) || Number(receipt.processed) < 0 || Number(receipt.processed) > 25
        || !Number.isSafeInteger(receipt.failed) || Number(receipt.failed) < 0 || Number(receipt.failed) > 25
        || Number(receipt.failed) > 0
        || receipt.outcome === "FRANCHISE_CONTROL_BUSY" && (receipt.processed !== 0 || receipt.failed !== 0)) {
        throw new Error("FRANCHISE_CONTROL_SCHEDULER_FAILED");
      }
    } finally {
      running = false;
    }
  };
}
