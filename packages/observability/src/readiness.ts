export type DependencyStatus = "up" | "down";

export type DependencyReadiness = Readonly<{
  status: DependencyStatus;
  latencyMs: number;
  code?: string;
}>;

export type ReadinessReport = Readonly<{
  status: "ready" | "not_ready";
  service: string;
  generated_at: string;
  checks: Readonly<Record<string, DependencyReadiness>>;
}>;

export type HealthReport = Readonly<{
  status: "ok";
  service: string;
  timestamp: string;
}>;

function assertValidCheck(name: string, check: DependencyReadiness): void {
  if (!name.trim()) throw new Error("READINESS_CHECK_NAME_REQUIRED");
  if (!Number.isFinite(check.latencyMs) || check.latencyMs < 0) {
    throw new Error("READINESS_LATENCY_INVALID");
  }
  if (check.status === "down" && !check.code) throw new Error("READINESS_FAILURE_CODE_REQUIRED");
  if (check.code && !/^[A-Z][A-Z0-9_]{2,63}$/.test(check.code)) {
    throw new Error("READINESS_FAILURE_CODE_INVALID");
  }
}

export function buildReadinessReport(
  service: string,
  checks: Readonly<Record<string, DependencyReadiness>>,
  now: () => Date = () => new Date(),
): ReadinessReport {
  if (!service.trim()) throw new Error("READINESS_SERVICE_REQUIRED");
  const entries = Object.entries(checks);
  if (entries.length === 0) throw new Error("READINESS_CHECK_REQUIRED");
  for (const [name, check] of entries) assertValidCheck(name, check);

  return Object.freeze({
    status: entries.every(([, check]) => check.status === "up") ? "ready" : "not_ready",
    service,
    generated_at: now().toISOString(),
    checks: Object.freeze(Object.fromEntries(entries.map(([name, check]) => [name, Object.freeze({ ...check })]))),
  });
}

export function buildHealthReport(
  service: string,
  now: () => Date = () => new Date(),
): HealthReport {
  if (!service.trim()) throw new Error("HEALTH_SERVICE_REQUIRED");
  return Object.freeze({ status: "ok", service, timestamp: now().toISOString() });
}
