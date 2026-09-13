export type ExternalEvidenceStatus =
  | "PASSED"
  | "FAILED"
  | "ACCEPTED_RISK"
  | "REQUIRED_NOT_COMPLETED";

export type DependencyCriticality = "LOW" | "MEDIUM" | "HIGH" | "CRITICAL";

export interface ThirdPartyServiceVersion {
  readonly serviceCode: string;
  readonly version: number;
  readonly providerName: string;
  readonly purpose: string;
  readonly processedDataCategories: readonly string[];
  readonly processingRegions: readonly string[];
  readonly criticality: DependencyCriticality;
  readonly dpaStatus: ExternalEvidenceStatus | "NOT_REQUIRED" | "VERIFIED" | "EXPIRED";
  readonly securityReviewStatus: ExternalEvidenceStatus | "ACCEPTED" | "REJECTED" | "EXPIRED";
  readonly secretNames: readonly string[];
  readonly exitPlan: string;
  readonly alternativeProvider: string;
}

export interface ContinuityObjective {
  readonly serviceCode: string;
  readonly rpoMinutes: number;
  readonly rtoMinutes: number;
  readonly degradationMode: "READ_ONLY" | "QUEUE_AND_RETRY" | "FEATURE_DISABLED" | "MANUAL_FALLBACK";
}

export interface RedactedOperationalJob {
  readonly jobType: string;
  readonly requestId: string;
  readonly eventId?: string;
  readonly payload: Readonly<Record<string, unknown>>;
  readonly maxAttempts: number;
}

const FORBIDDEN_KEYS = new Set(["secret", "password", "token", "credential", "api_key", "email", "phone", "prompt"]);

function assertRedactedValue(value: unknown): void {
  if (Array.isArray(value)) {
    for (const item of value) assertRedactedValue(item);
    return;
  }
  if (value === null || typeof value !== "object") return;
  for (const [key, nested] of Object.entries(value)) {
    if (FORBIDDEN_KEYS.has(key.toLowerCase())) throw new Error(`SENSITIVE_OPERATIONAL_FIELD:${key.toLowerCase()}`);
    assertRedactedValue(nested);
  }
}

export function assertRedactedPayload(payload: Readonly<Record<string, unknown>>): void {
  assertRedactedValue(payload);
}

export function assertContinuityObjective(objective: ContinuityObjective): void {
  if (!Number.isSafeInteger(objective.rpoMinutes) || !Number.isSafeInteger(objective.rtoMinutes)) {
    throw new Error("CONTINUITY_OBJECTIVE_INTEGER_REQUIRED");
  }
  if (objective.rpoMinutes <= 0 || objective.rtoMinutes < objective.rpoMinutes) {
    throw new Error("CONTINUITY_OBJECTIVE_INVALID");
  }
}

export function mayClaimRestoreExecuted(
  status: ExternalEvidenceStatus,
  evidence: { readonly executedAt?: string; readonly evidenceHash?: string },
): boolean {
  if (status === "REQUIRED_NOT_COMPLETED") return !evidence.executedAt && !evidence.evidenceHash;
  if (status === "PASSED" || status === "FAILED") return Boolean(evidence.executedAt && /^[0-9a-f]{64}$/.test(evidence.evidenceHash ?? ""));
  return true;
}
