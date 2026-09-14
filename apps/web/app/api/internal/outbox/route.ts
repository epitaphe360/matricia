import { timingSafeEqual } from "node:crypto";
import { z } from "zod";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const headers = { "cache-control": "no-store" } as const;
const MAX_BODY_BYTES = 128 * 1024;

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

  return Response.json(
    { outcome: "OUTBOX_EVENT_ACCEPTED", eventId: parsed.data.id },
    { status: 202, headers },
  );
}
