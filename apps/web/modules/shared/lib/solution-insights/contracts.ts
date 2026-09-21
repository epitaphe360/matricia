import type { Benchmark, SolutionBundle, SolutionDecision, SolutionLevel, SolutionSet } from "./model";
export type SolutionFailure = "UNAUTHENTICATED" | "INVALID_INPUT" | "INVALID_RESPONSE" | "UNAVAILABLE" | "FORBIDDEN" | "CONFLICT";
export type Result<T> = { status: "success"; value: T } | { status: "error"; reason: SolutionFailure };
export type RecordedDecision = { outcome: "SOLUTION_ACCEPTED" | "SOLUTION_REJECTED" | "SOLUTION_DEFERRED"; decisionId: string; solutionSetId: string; level: SolutionLevel };
export type SolutionInsightsRepository = {
  list(): Promise<Result<{ sets: SolutionSet[]; benchmarks: Benchmark[]; bundles: SolutionBundle[] }>>;
  decide(input: { solutionSetId: string; level: SolutionLevel; decision: SolutionDecision; reason: string; deferredUntil: string | null; idempotencyKey: string; correlationId: string }): Promise<Result<RecordedDecision>>;
};
