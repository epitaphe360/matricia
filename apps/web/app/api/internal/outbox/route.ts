import { timingSafeEqual } from "node:crypto";
import { createJsonLogger } from "@matricia/observability";
import { z } from "zod";
import { deliverNotification } from "@/modules/shared/lib/notification-delivery/adapter";
import { getSupabaseAdminClient } from "@/modules/shared/lib/supabase/admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const headers = { "cache-control": "no-store" } as const;
const MAX_BODY_BYTES = 128 * 1024;
const CONSUMER_CODE = "TERMINAL_OBSERVABILITY";
const INVITATION_CONSUMER = "ORGANIZATION_EMAIL_INVITATION";
const log = createJsonLogger((record) => process.stdout.write(`${record}\n`));

const envelopeSchema = z.object({
  id: z.string().regex(/^[0-9]+$/),
  eventType: z.string().min(3).max(160),
  aggregateId: z.string().min(1).max(240),
  occurredAt: z.string().datetime({ offset: true }),
  correlationId: z.string().uuid(),
  payload: z.record(z.string(), z.unknown()),
}).strict();

const invitationPayload = z.object({
  invitation_id: z.string().uuid(),
  organization_id: z.string().uuid(),
  invited_email: z.string().email().optional(),
  organization_name: z.string().min(1).max(200).optional(),
  locale: z.enum(["fr-MA", "ar-MA"]).optional(),
  expires_at: z.string().optional(),
  role_codes: z.array(z.string()).optional(),
}).passthrough();

const loadedInvitation = z.object({
  invitation_id: z.string().uuid(),
  organization_id: z.string().uuid(),
  organization_name: z.string().min(1).max(200),
  invited_email: z.string().email(),
  expires_at: z.string(),
  role_codes: z.array(z.string()),
}).strict();

function authorized(request: Request): boolean {
  const expected = process.env.INTERNAL_WEBHOOK_SECRET?.trim() ?? "";
  const supplied = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1] ?? "";
  const expectedBytes = Buffer.from(expected);
  const suppliedBytes = Buffer.from(supplied);
  return expectedBytes.length >= 32
    && expectedBytes.length === suppliedBytes.length
    && timingSafeEqual(expectedBytes, suppliedBytes);
}

function invitationCopy(locale: "fr-MA" | "ar-MA", organizationName: string) {
  if (locale === "ar-MA") {
    return {
      subject: `دعوة للانضمام إلى ${organizationName} على ماتريسيا`,
      body: `تمت دعوتك للانضمام إلى مؤسسة ${organizationName} على منصة ماتريسيا.\n\nأنشئ حساباً أو سجّل الدخول ثم افتح صفحة الدعوات لقبول الدعوة.`,
      ctaPath: "/ar/invitations",
    };
  }
  return {
    subject: `Invitation à rejoindre ${organizationName} sur Matricia`,
    body: `Vous êtes invité(e) à rejoindre l’organisation ${organizationName} sur Matricia.\n\nCréez un compte ou connectez-vous, puis ouvrez la page Invitations pour accepter.`,
    ctaPath: "/fr/invitations",
  };
}

async function deliverOrganizationInvitation(envelope: z.infer<typeof envelopeSchema>) {
  const parsedPayload = invitationPayload.safeParse(envelope.payload);
  if (!parsedPayload.success) return { ok: false as const, code: "INVITATION_PAYLOAD_INVALID" };

  const admin = getSupabaseAdminClient();
  const loaded = await admin.rpc("load_organization_invitation_email_v1", {
    p_invitation_id: parsedPayload.data.invitation_id,
  });
  if (loaded.error) return { ok: false as const, code: "INVITATION_LOAD_FAILED" };
  const invitation = loadedInvitation.safeParse(loaded.data);
  if (!invitation.success) return { ok: false as const, code: "INVITATION_LOAD_INVALID" };

  const locale = parsedPayload.data.locale === "ar-MA" ? "ar-MA" : "fr-MA";
  const copy = invitationCopy(locale, invitation.data.organization_name);
  const result = await deliverNotification({
    deliveryId: envelope.id,
    channel: "EMAIL",
    recipientEmail: invitation.data.invited_email,
    locale,
    subject: copy.subject,
    body: copy.body,
    ctaPath: copy.ctaPath,
    providerIdempotencyKey: `organization-invitation:${invitation.data.invitation_id}`,
  }, { env: process.env, fetch });

  if (result.outcome !== "DELIVERED") {
    return { ok: false as const, code: result.errorCode };
  }
  return { ok: true as const, invitationId: invitation.data.invitation_id };
}

export async function POST(request: Request): Promise<Response> {
  if (!authorized(request)) {
    return Response.json({ code: "UNAUTHORIZED" }, { status: 401, headers });
  }

  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) {
    return Response.json({ code: "PAYLOAD_TOO_LARGE" }, { status: 413, headers });
  }

  const raw = await request.text();
  if (Buffer.byteLength(raw, "utf8") > MAX_BODY_BYTES) {
    return Response.json({ code: "PAYLOAD_TOO_LARGE" }, { status: 413, headers });
  }

  let body: unknown;
  try {
    body = JSON.parse(raw);
  } catch {
    return Response.json({ code: "INVALID_REQUEST" }, { status: 400, headers });
  }

  const parsed = envelopeSchema.safeParse(body);
  if (!parsed.success) {
    return Response.json({ code: "INVALID_REQUEST" }, { status: 400, headers });
  }

  if (parsed.data.eventType === "OrganizationEmailInvitationRequestedV1") {
    const delivery = await deliverOrganizationInvitation(parsed.data);
    if (!delivery.ok) {
      return Response.json({ code: delivery.code }, { status: 503, headers });
    }
    log("info", {
      requestId: request.headers.get("x-request-id") ?? parsed.data.correlationId,
      correlationId: parsed.data.correlationId,
      event: "outbox.invitation.email.delivered",
      outcome: "success",
      aggregateType: parsed.data.eventType,
      aggregateId: parsed.data.aggregateId,
      data: { eventId: parsed.data.id, consumer: INVITATION_CONSUMER, invitationId: delivery.invitationId },
    });
    return Response.json(
      { outcome: "ORGANIZATION_INVITATION_EMAIL_DELIVERED", eventId: parsed.data.id, consumer: INVITATION_CONSUMER },
      { status: 202, headers: { ...headers, "x-matricia-outbox-consumer": INVITATION_CONSUMER } },
    );
  }

  // Terminal observer for events without a dedicated consumer.
  // Payloads can contain tenant data and must never be copied to application logs.
  log("info", {
    requestId: request.headers.get("x-request-id") ?? parsed.data.correlationId,
    correlationId: parsed.data.correlationId,
    event: "outbox.event.observed",
    outcome: "success",
    aggregateType: parsed.data.eventType,
    aggregateId: parsed.data.aggregateId,
    data: { eventId: parsed.data.id, consumer: CONSUMER_CODE },
  });

  return Response.json(
    { outcome: "OUTBOX_EVENT_OBSERVED", eventId: parsed.data.id, consumer: CONSUMER_CODE },
    { status: 202, headers: { ...headers, "x-matricia-outbox-consumer": CONSUMER_CODE } },
  );
}
