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
