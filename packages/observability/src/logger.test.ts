import { describe, expect, it, vi } from "vitest";
import { createJsonLogger, createLogRecord, redactSensitiveData } from "./logger";

const instant = () => new Date("2026-09-11T12:00:00.000Z");

describe("structured JSON logger", () => {
  it("produit les champs de corrélation obligatoires sans message libre", () => {
    expect(createLogRecord("error", {
      requestId: "req-1",
      correlationId: "corr-1",
      event: "outbox.dispatch",
      outcome: "failure",
      actorId: "actor-1",
      aggregateType: "outbox_event",
      aggregateId: "event-1",
      errorCode: "OUTBOX_DELIVERY_FAILED",
    }, instant)).toEqual({
      timestamp: "2026-09-11T12:00:00.000Z",
      level: "error",
      request_id: "req-1",
      correlation_id: "corr-1",
      event: "outbox.dispatch",
      outcome: "failure",
      actor_id: "actor-1",
      aggregate_type: "outbox_event",
      aggregate_id: "event-1",
      error_code: "OUTBOX_DELIVERY_FAILED",
    });
  });

  it("caviarde récursivement secrets et PII", () => {
    expect(redactSensitiveData({
      authorization: "Bearer value",
      nested: { email: "person@example.test", safe_count: 3, note: "Bearer secret-value" },
      accessToken: "value",
    })).toEqual({
      authorization: "[REDACTED]",
      nested: { email: "[REDACTED]", safe_count: 3, note: "[REDACTED]" },
      accessToken: "[REDACTED]",
    });
  });

  it.each([
    "clientName",
    "customer_name",
    "person-name",
    "ice",
    "taxIdentifier",
    "fiscal_id",
    "iban",
    "bankAccountNumber",
    "ipAddress",
    "xForwardedFor",
    "privateKey",
    "service_role_key",
    "supabaseServiceRoleKey",
  ])("caviarde la clé sensible %s", (key) => {
    expect(redactSensitiveData({ [key]: "sensitive-value", safe_count: 3 })).toEqual({
      [key]: "[REDACTED]",
      safe_count: 3,
    });
  });

  it.each([
    "customer_name=Acme Direction",
    "ICE: 001234567890123",
    "MA64011519000001205000534921",
    "source 203.0.113.42",
    "source 2001:db8:85a3::8a2e:370:7334",
    "service_role=super-secret-value",
    "sb_secret_a1b2c3d4e5f6g7h8",
    "-----BEGIN PRIVATE KEY----- contents",
    "github_pat_11AA22BB33CC44DD",
    "+212 6 12 34 56 78",
    "AB123456",
    "password=hunter-value",
    "access_token=opaque-value",
  ])("caviarde une valeur sensible même sous une clé neutre", (value) => {
    expect(redactSensitiveData({ note: value })).toEqual({ note: "[REDACTED]" });
  });

  it("caviarde les secrets imbriqués dans des tableaux sans altérer les données sûres", () => {
    expect(redactSensitiveData({
      attempts: [
        { remoteAddress: "198.51.100.10", result: "denied" },
        { bank_details: "MA64011519000001205000534921", count: 2 },
      ],
    })).toEqual({
      attempts: [
        { remoteAddress: "[REDACTED]", result: "denied" },
        { bank_details: "[REDACTED]", count: 2 },
      ],
    });
  });

  it("écrit une ligne JSON exploitable", () => {
    const sink = vi.fn();
    createJsonLogger(sink, instant)("info", {
      requestId: "req-2",
      correlationId: "corr-2",
      event: "health.checked",
      outcome: "success",
    });
    expect(JSON.parse(sink.mock.calls[0]?.[0] as string)).toMatchObject({
      level: "info",
      request_id: "req-2",
      correlation_id: "corr-2",
    });
  });
});
