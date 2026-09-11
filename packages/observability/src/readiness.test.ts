import { describe, expect, it } from "vitest";
import { buildHealthReport, buildReadinessReport } from "./readiness";

const instant = () => new Date("2026-09-11T12:00:00.000Z");

describe("health and readiness contracts", () => {
  it("sépare la vivacité de la disponibilité des dépendances", () => {
    expect(buildHealthReport("matricia-web", instant)).toEqual({
      status: "ok",
      service: "matricia-web",
      timestamp: "2026-09-11T12:00:00.000Z",
    });
    expect(buildReadinessReport("matricia-web", {
      database: { status: "up", latencyMs: 12 },
      outbox: { status: "up", latencyMs: 2 },
    }, instant).status).toBe("ready");
  });

  it("refuse readiness si une dépendance est indisponible", () => {
    const report = buildReadinessReport("matricia-worker", {
      database: { status: "down", latencyMs: 500, code: "DATABASE_UNREACHABLE" },
    }, instant);
    expect(report.status).toBe("not_ready");
    expect(report.checks.database?.code).toBe("DATABASE_UNREACHABLE");
  });

  it("exige une mesure et un code d'échec sûrs", () => {
    expect(() => buildReadinessReport("service", {}, instant)).toThrow("READINESS_CHECK_REQUIRED");
    expect(() => buildReadinessReport("service", {
      database: { status: "down", latencyMs: 10 },
    }, instant)).toThrow("READINESS_FAILURE_CODE_REQUIRED");
    expect(() => buildReadinessReport("service", {
      database: { status: "up", latencyMs: -1 },
    }, instant)).toThrow("READINESS_LATENCY_INVALID");
    expect(() => buildReadinessReport("service", {
      database: { status: "down", latencyMs: 1, code: "free text" },
    }, instant)).toThrow("READINESS_FAILURE_CODE_INVALID");
  });
});
