import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  rpc: vi.fn(),
  deliver: vi.fn(),
}));

vi.mock("@/modules/shared/lib/supabase/admin", () => ({
  getSupabaseAdminClient: () => ({ rpc: mocks.rpc }),
}));
vi.mock("@/modules/shared/lib/notification-delivery/adapter", () => ({
  deliverNotification: mocks.deliver,
}));

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

const invitationEnvelope = {
  id: "77",
  eventType: "OrganizationEmailInvitationRequestedV1",
  aggregateId: "invitation:a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  occurredAt: "2026-09-14T20:00:00.000Z",
  correlationId: "179c0f83-b91e-46b2-a18d-5a9436c66cd4",
  payload: {
    invitation_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    organization_id: "58a947b1-a23f-4ad1-90e8-af68f65e12ee",
    locale: "fr-MA",
  },
};

function request(body: unknown = envelope, token = secret): Request {
  return new Request("https://matricia.vercel.app/api/internal/outbox", {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

describe("internal outbox receiver", () => {
  let write: ReturnType<typeof vi.spyOn>;
  beforeEach(() => {
    process.env.INTERNAL_WEBHOOK_SECRET = secret;
    write = vi.spyOn(process.stdout, "write").mockImplementation(() => true);
    mocks.rpc.mockReset();
    mocks.deliver.mockReset();
  });
  afterEach(() => write.mockRestore());

  it("rejects unauthorized dispatches", async () => {
    expect((await POST(request(envelope, "bad"))).status).toBe(401);
  });

  it("rejects malformed envelopes", async () => {
    expect((await POST(request({ ...envelope, correlationId: "invalid" }))).status).toBe(400);
  });

  it("observes a valid envelope through the explicit terminal consumer", async () => {
    const response = await POST(request());
    expect(response.status).toBe(202);
    expect(response.headers.get("x-matricia-outbox-consumer")).toBe("TERMINAL_OBSERVABILITY");
    await expect(response.json()).resolves.toEqual({ outcome: "OUTBOX_EVENT_OBSERVED", eventId: "42", consumer: "TERMINAL_OBSERVABILITY" });
    expect(write).toHaveBeenCalledOnce();
    const record = JSON.parse(String(write.mock.calls[0]?.[0]));
    expect(record).toMatchObject({ event: "outbox.event.observed", outcome: "success", aggregate_type: envelope.eventType, data: { eventId: "42", consumer: "TERMINAL_OBSERVABILITY" } });
    expect(JSON.stringify(record)).not.toContain("organization_id");
  });

  it("delivers organization invitation emails through the dedicated consumer", async () => {
    mocks.rpc.mockResolvedValue({
      data: {
        invitation_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        organization_id: "58a947b1-a23f-4ad1-90e8-af68f65e12ee",
        organization_name: "NeoXa Demo",
        invited_email: "invitee@example.com",
        expires_at: "2026-09-21T20:00:00+00:00",
        role_codes: ["ORG_ADMIN"],
      },
      error: null,
    });
    mocks.deliver.mockResolvedValue({ outcome: "DELIVERED" });

    const response = await POST(request(invitationEnvelope));
    expect(response.status).toBe(202);
    expect(response.headers.get("x-matricia-outbox-consumer")).toBe("ORGANIZATION_EMAIL_INVITATION");
    await expect(response.json()).resolves.toEqual({
      outcome: "ORGANIZATION_INVITATION_EMAIL_DELIVERED",
      eventId: "77",
      consumer: "ORGANIZATION_EMAIL_INVITATION",
    });
    expect(mocks.rpc).toHaveBeenCalledWith("load_organization_invitation_email_v1", {
      p_invitation_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    });
    expect(mocks.deliver).toHaveBeenCalledWith(
      expect.objectContaining({
        channel: "EMAIL",
        recipientEmail: "invitee@example.com",
        providerIdempotencyKey: "organization-invitation:a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      }),
      expect.any(Object),
    );
  });

  it("returns 503 when invitation email delivery fails", async () => {
    mocks.rpc.mockResolvedValue({
      data: {
        invitation_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        organization_id: "58a947b1-a23f-4ad1-90e8-af68f65e12ee",
        organization_name: "NeoXa Demo",
        invited_email: "invitee@example.com",
        expires_at: "2026-09-21T20:00:00+00:00",
        role_codes: ["ORG_ADMIN"],
      },
      error: null,
    });
    mocks.deliver.mockResolvedValue({ outcome: "FAILED", errorCode: "PROVIDER_REJECTED" });

    const response = await POST(request(invitationEnvelope));
    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({ code: "PROVIDER_REJECTED" });
  });
});
