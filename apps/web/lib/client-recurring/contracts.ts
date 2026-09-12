import type { RecurringDashboard } from "./model";

export type RecurringFailure = "UNAUTHENTICATED" | "FORBIDDEN" | "INVALID_INPUT" | "INVALID_RESPONSE" | "CONFLICT" | "NOT_ELIGIBLE" | "NOT_ACTIVE" | "INVALID_TRANSITION" | "BOUNDS_EXCEEDED" | "UNAVAILABLE";
export type RecurringResult<T> = { status: "success"; value: T } | { status: "error"; reason: RecurringFailure };
export type CommandIdentity = { idempotencyKey: string; correlationId: string };

export type ClientRecurringRepository = {
  load(): Promise<RecurringResult<RecurringDashboard>>;
  clone(input: CommandIdentity & { sourceRequestId: string; desiredDate: string | null; reason: string }): Promise<RecurringResult<{ requestId: string; requestVersionId: string; status: "DRAFT" }>>;
  createPlan(input: CommandIdentity & { templateRequestId: string; cadence: "MONTHLY" | "QUARTERLY" | "ANNUALLY"; startsOn: string; endsOn: string | null; reason: string }): Promise<RecurringResult<{ planId: string; planVersionId: string; status: "ACTIVE" }>>;
  transition(input: CommandIdentity & { planId: string; action: "PAUSE" | "RESUME" | "END"; expectedRowVersion: number; reason: string }): Promise<RecurringResult<{ planId: string; planVersionId: string; status: "ACTIVE" | "PAUSED" | "ENDED"; rowVersion: number }>>;
  generate(input: CommandIdentity & { planId: string; throughDate: string; maxOccurrences: number }): Promise<RecurringResult<{ planId: string; planVersionId: string; generatedCount: number; throughDate: string; autonomousInvitations: false; autonomousSpend: false }>>;
};

