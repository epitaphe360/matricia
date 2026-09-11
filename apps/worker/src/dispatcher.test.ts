import { describe, expect, it, vi } from "vitest";
import { createWorkerDispatcher } from "./dispatcher";
import type { OutboxEnvelope } from "./index";

const envelope: OutboxEnvelope = {
  id: "42",
  eventType: "DocumentUploadedV1",
  aggregateId: "a1111111-1111-4111-8111-111111111111",
  occurredAt: "2026-09-11T00:00:00.000Z",
  correlationId: "a4444444-4444-4444-8444-444444444444",
  payload: {},
};

describe("worker dispatcher", () => {
  it("handles document uploads locally without exposing them to the webhook", async () => {
    const consume = vi.fn().mockResolvedValue({ outcome: "DOCUMENT_SCAN_RECORDED" });
    const fetcher = vi.fn();
    const dispatcher = createWorkerDispatcher({
      documentScanConsumer: { consume },
      dispatchUrl: new URL("https://internal.example.test/events"),
      webhookSecret: "test-secret",
      fetcher,
    });

    await dispatcher.dispatch(envelope);

    expect(consume).toHaveBeenCalledWith(envelope);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("forwards unrelated events through the existing authenticated webhook", async () => {
    const consume = vi.fn().mockResolvedValue(null);
    const fetcher = vi.fn().mockResolvedValue({ ok: true });
    const dispatcher = createWorkerDispatcher({
      documentScanConsumer: { consume },
      dispatchUrl: new URL("https://internal.example.test/events"),
      webhookSecret: "test-secret",
      fetcher,
    });
    const event = { ...envelope, eventType: "OrganizationCreatedV1" };

    await dispatcher.dispatch(event);

    expect(fetcher).toHaveBeenCalledOnce();
    expect(fetcher).toHaveBeenCalledWith(
      new URL("https://internal.example.test/events"),
      expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({ authorization: "Bearer test-secret" }),
        body: JSON.stringify(event),
      }),
    );
  });

  it("fails closed when document scanning fails", async () => {
    const fetcher = vi.fn();
    const dispatcher = createWorkerDispatcher({
      documentScanConsumer: { consume: vi.fn().mockRejectedValue(new Error("scan unavailable")) },
      dispatchUrl: new URL("https://internal.example.test/events"),
      webhookSecret: "test-secret",
      fetcher,
    });

    await expect(dispatcher.dispatch(envelope)).rejects.toThrow("scan unavailable");
    expect(fetcher).not.toHaveBeenCalled();
  });
});
