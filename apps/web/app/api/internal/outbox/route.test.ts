import { beforeEach, describe, expect, it } from "vitest";
import { POST } from "./route";

const secret = "s".repeat(32);
const envelope = {
  id: "42",
  eventType: "OrganizationCreatedV1",
  aggregateId: "58a947b1-a23f-4ad1-90e8-af68f65e12ee",
  occurredAt: "2026-09-14T20:00:00.000Z",
  correlationId: "179c0f83-b91e-46b2-a18d-5a9436c66cd4",
  payload: { organization_id: "58a947b1-a23f-4ad1-90e8-af68f65e12ee" },
};

function request(body: unknown = envelope, token = secret): Request {
  return new Request("https://matricia.vercel.app/api/internal/outbox", {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

describe("internal outbox receiver", () => {
  beforeEach(() => { process.env.INTERNAL_WEBHOOK_SECRET = secret; });

  it("rejects unauthorized dispatches", async () => {
    expect((await POST(request(envelope, "bad"))).status).toBe(401);
  });

  it("rejects malformed envelopes", async () => {
    expect((await POST(request({ ...envelope, correlationId: "invalid" }))).status).toBe(400);
  });

  it("accepts a valid envelope idempotently", async () => {
    const response = await POST(request());
    expect(response.status).toBe(202);
    await expect(response.json()).resolves.toEqual({ outcome: "OUTBOX_EVENT_ACCEPTED", eventId: "42" });
  });
});
