import { randomUUID, timingSafeEqual } from "node:crypto";

import { getSupabaseAdminClient } from "@/modules/shared/lib/supabase/admin";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

const NO_STORE_HEADERS = { "cache-control": "no-store" } as const;
const MONTH_PATTERN = /^\d{4}-(0[1-9]|1[0-2])-01$/;

function isAuthorized(request: Request): boolean {
  const expected = process.env.CRON_SECRET ?? "";
  const match = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i);
  const supplied = match?.[1] ?? "";
  const expectedBuffer = Buffer.from(expected);
  const suppliedBuffer = Buffer.from(supplied);

  return (
    expectedBuffer.length >= 32 &&
    expectedBuffer.length === suppliedBuffer.length &&
    timingSafeEqual(expectedBuffer, suppliedBuffer)
  );
}

function requestedMonth(request: Request): string | null | undefined {
  const month = new URL(request.url).searchParams.get("month");
  if (month === null) return null;
  if (!MONTH_PATTERN.test(month)) return undefined;

  const parsed = new Date(`${month}T00:00:00.000Z`);
  return Number.isNaN(parsed.valueOf()) || parsed.toISOString().slice(0, 10) !== month
    ? undefined
    : month;
}

function nextMonthStartUtc(now = new Date()): string {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)).toISOString().slice(0, 10);
}

export async function POST(request: Request): Promise<Response> {
  const correlationId = randomUUID();
  const headers = { ...NO_STORE_HEADERS, "x-correlation-id": correlationId };

  if (!isAuthorized(request)) {
    return Response.json({ code: "UNAUTHORIZED" }, { status: 401, headers });
  }

  const monthStart = requestedMonth(request);
  if (monthStart === undefined) {
    return Response.json(
      { code: "INVALID_MONTH", message: "month must use YYYY-MM-01" },
      { status: 400, headers },
    );
  }

  try {
    const client = getSupabaseAdminClient();
    const { data, error } = await client.rpc("generate_due_marketing_calendars_v1", {
      p_month_start: monthStart,
      p_correlation_id: correlationId,
    });

    if (error) {
      return Response.json({ code: "MARKETING_CALENDAR_GENERATION_FAILED" }, { status: 503, headers });
    }

    const effectiveMonth = monthStart ?? nextMonthStartUtc();
    const shortages = await client.rpc("detect_marketing_calendar_shortages_v1", {
      p_month_start: effectiveMonth,
      p_correlation_id: correlationId,
    });
    if (shortages.error) {
      return Response.json({ code: "MARKETING_CALENDAR_SHORTAGE_CHECK_FAILED" }, { status: 503, headers });
    }

    const generation = data && typeof data === "object" && !Array.isArray(data) ? data : { generation: data };
    return Response.json({ ...generation, shortages: shortages.data }, { status: 200, headers });
  } catch {
    return Response.json({ code: "MARKETING_CALENDAR_GENERATION_FAILED" }, { status: 503, headers });
  }
}

// Vercel Cron invokes routes with GET and injects the same Bearer CRON_SECRET.
export const GET = POST;
