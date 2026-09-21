import { timingSafeEqual } from "node:crypto";
import { createJsonLogger } from "@matricia/observability";
import { z } from "zod";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const headers = { "cache-control": "no-store" } as const;
const MAX_BODY_BYTES = 128 * 1024;
const CONSUMER_CODE = "TERMINAL_OBSERVABILITY";
const log = createJsonLogger((record) => process.stdout.write(`${record}\n`));

const envelopeSchema = z.object({
  id: z.string().regex(/^[0-9]+$/),
  eventType: z.string().min(3).max(160),
  aggregateId: z.string().min(1).max(240),
  occurredAt: z.string().datetime({ offset: true }),
  correlationId: z.string().uuid(),
  payload: z.record(z.string(), z.unknown()),
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

  // This endpoint is deliberately a terminal observer for events without a
  // dedicated worker consumer. It records envelope metadata only; payloads can
  // contain tenant data and must never be copied to application logs.
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
