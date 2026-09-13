import { randomUUID, timingSafeEqual } from "node:crypto";

import { getSupabaseAdminClient } from "@/lib/supabase/admin";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

const headers = { "cache-control": "no-store" } as const;
const DATE_PATTERN = /^\d{4}-(0[1-9]|1[0-2])-([0-2]\d|3[01])$/;
const MAX_PAGES = 20;

function authorized(request: Request) {
  const expected = process.env.CRON_SECRET ?? "";
  const supplied = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1] ?? "";
  const a = Buffer.from(expected), b = Buffer.from(supplied);
  return a.length >= 32 && a.length === b.length && timingSafeEqual(a, b);
}

function previousWeekMonday(now = new Date()) {
  const day = now.getUTCDay() || 7;
  const monday = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - day + 1 - 7));
  return monday.toISOString().slice(0, 10);
}

function requestedWeek(request: Request) {
  const raw = new URL(request.url).searchParams.get("week") ?? previousWeekMonday();
  if (!DATE_PATTERN.test(raw)) return null;
  const parsed = new Date(`${raw}T00:00:00.000Z`);
  if (Number.isNaN(parsed.valueOf()) || parsed.toISOString().slice(0, 10) !== raw || parsed.getUTCDay() !== 1) return null;
  return raw;
}

export async function POST(request: Request) {
  if (!authorized(request)) return Response.json({ code: "UNAUTHORIZED" }, { status: 401, headers });
  const weekStart = requestedWeek(request);
  if (!weekStart) return Response.json({ code: "INVALID_WEEK" }, { status: 400, headers });
  const correlationId = randomUUID();
  try {
    const client = getSupabaseAdminClient();
    let cursor: string | null = null;
    let generatedSnapshots = 0, proposedSuggestions = 0, skippedSuggestions = 0;
    for (let page = 0; page < MAX_PAGES; page++) {
      const { data, error } = await client.rpc("generate_weekly_marketing_trends_v1", {
        p_idempotency_key: `marketing-trends:${weekStart}:page:${page}`,
        p_week_start: weekStart,
        p_limit: 500,
        p_correlation_id: correlationId,
        p_cursor: cursor,
      });
      const value = data as { generatedSnapshots?: unknown; proposedSuggestions?: unknown; skippedSuggestions?: unknown; hasMore?: unknown; nextCursor?: unknown } | null;
      if (error || !value || ![value.generatedSnapshots, value.proposedSuggestions, value.skippedSuggestions].every(Number.isSafeInteger)
        || typeof value.hasMore !== "boolean" || (value.nextCursor !== null && typeof value.nextCursor !== "string")) {
        return Response.json({ code: "MARKETING_TRENDS_FAILED" }, { status: 503, headers });
      }
      generatedSnapshots += value.generatedSnapshots as number;
      proposedSuggestions += value.proposedSuggestions as number;
      skippedSuggestions += value.skippedSuggestions as number;
      if (!value.hasMore) return Response.json({ outcome: "MARKETING_WEEKLY_TRENDS_GENERATED", weekStart, generatedSnapshots, proposedSuggestions, skippedSuggestions, pages: page + 1 }, { headers: { ...headers, "x-correlation-id": correlationId } });
      if (typeof value.nextCursor !== "string" || value.nextCursor.length < 10 || value.nextCursor.length > 200 || value.nextCursor === cursor) {
        return Response.json({ code: "MARKETING_TRENDS_FAILED" }, { status: 503, headers });
      }
      cursor = value.nextCursor;
    }
    return Response.json({ code: "MARKETING_TRENDS_INCOMPLETE" }, { status: 503, headers });
  } catch {
    return Response.json({ code: "MARKETING_TRENDS_FAILED" }, { status: 503, headers });
  }
}

export const GET = POST;
