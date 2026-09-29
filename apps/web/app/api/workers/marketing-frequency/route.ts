import { randomUUID, timingSafeEqual } from "node:crypto";

import { getSupabaseAdminClient } from "@/modules/shared/lib/supabase/admin";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

const headers = { "cache-control": "no-store" } as const;
const DATE_PATTERN = /^\d{4}-(0[1-9]|1[0-2])-([0-2]\d|3[01])$/;

function authorized(request: Request) {
  const expected = process.env.CRON_SECRET ?? "";
  const supplied = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1] ?? "";
  const a = Buffer.from(expected), b = Buffer.from(supplied);
  return a.length >= 32 && a.length === b.length && timingSafeEqual(a, b);
}

function currentWeekMonday(now = new Date()) {
  const day = now.getUTCDay() || 7;
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - day + 1)).toISOString().slice(0, 10);
}

function requestedWeek(request: Request) {
  const raw = new URL(request.url).searchParams.get("week") ?? currentWeekMonday();
  if (!DATE_PATTERN.test(raw)) return null;
  const parsed = new Date(`${raw}T00:00:00.000Z`);
  if (Number.isNaN(parsed.valueOf()) || parsed.toISOString().slice(0, 10) !== raw || parsed.getUTCDay() !== 1 || raw > currentWeekMonday()) return null;
  return raw;
}

export async function POST(request: Request) {
  if (!authorized(request)) return Response.json({ code: "UNAUTHORIZED" }, { status: 401, headers });
  const weekStart = requestedWeek(request);
  if (!weekStart) return Response.json({ code: "INVALID_WEEK" }, { status: 400, headers });
  const correlationId = randomUUID();
  try {
    const { data, error } = await getSupabaseAdminClient().rpc("apply_marketing_weekly_frequency_v1", {
      p_week_start: weekStart,
      p_idempotency_key: `marketing-frequency:${weekStart}`,
      p_correlation_id: correlationId,
    });
    const value = data as { outcome?: unknown; applied?: unknown; human_review_required?: unknown; at_limit?: unknown } | null;
    if (error || !value || value.outcome !== "MARKETING_WEEKLY_FREQUENCY_APPLIED" || ![value.applied, value.human_review_required, value.at_limit].every(Number.isSafeInteger)) {
      return Response.json({ code: "MARKETING_FREQUENCY_FAILED" }, { status: 503, headers });
    }
    return Response.json({ outcome: value.outcome, weekStart, applied: value.applied, humanReviewRequired: value.human_review_required, atLimit: value.at_limit }, { headers: { ...headers, "x-correlation-id": correlationId } });
  } catch {
    return Response.json({ code: "MARKETING_FREQUENCY_FAILED" }, { status: 503, headers });
  }
}

export const GET = POST;
