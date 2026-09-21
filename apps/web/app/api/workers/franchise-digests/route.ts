import { randomUUID, timingSafeEqual } from "node:crypto";

import { getSupabaseAdminClient } from "@/modules/shared/lib/supabase/admin";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

const headers = { "cache-control": "no-store" } as const;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function authorized(request: Request) {
  const expected = process.env.CRON_SECRET ?? "";
  const supplied = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1] ?? "";
  const a = Buffer.from(expected), b = Buffer.from(supplied);
  return a.length >= 32 && a.length === b.length && timingSafeEqual(a, b);
}

function requestedLimit(request: Request) {
  const raw = new URL(request.url).searchParams.get("limit") ?? "20";
  if (!/^\d{1,3}$/.test(raw)) return null;
  const limit = Number(raw);
  return Number.isSafeInteger(limit) && limit >= 1 && limit <= 100 ? limit : null;
}

type Claim = { job_id?: unknown; lease_token?: unknown; worker_id?: unknown; row_version?: unknown };

export async function POST(request: Request) {
  if (!authorized(request)) return Response.json({ code: "UNAUTHORIZED" }, { status: 401, headers });
  const limit = requestedLimit(request);
  if (!limit) return Response.json({ code: "INVALID_LIMIT" }, { status: 400, headers });

  const client = getSupabaseAdminClient();
  const workerId = randomUUID();
  const correlationId = randomUUID();
  try {
    const scheduled = await client.rpc("schedule_franchise_daily_digests", { p_limit: limit });
    if (scheduled.error || !Array.isArray(scheduled.data)) {
      return Response.json({ code: "FRANCHISE_DIGEST_SCHEDULING_FAILED" }, { status: 503, headers });
    }

    const claimed = await client.rpc("claim_franchise_daily_digest_jobs", {
      p_worker_id: workerId, p_limit: limit, p_lease_seconds: 300,
    });
    if (claimed.error || !Array.isArray(claimed.data)) {
      return Response.json({ code: "FRANCHISE_DIGEST_CLAIM_FAILED" }, { status: 503, headers });
    }

    let completed = 0;
    for (const rawClaim of claimed.data as Claim[]) {
      const jobId = rawClaim.job_id, leaseToken = rawClaim.lease_token, claimWorkerId = rawClaim.worker_id;
      const rowVersion = rawClaim.row_version;
      if (typeof jobId !== "string" || !UUID_PATTERN.test(jobId)
        || typeof leaseToken !== "string" || !UUID_PATTERN.test(leaseToken)
        || claimWorkerId !== workerId || !Number.isSafeInteger(rowVersion) || (rowVersion as number) < 1) {
        return Response.json({ code: "FRANCHISE_DIGEST_INVALID_CLAIM" }, { status: 503, headers });
      }
      const result = await client.rpc("complete_franchise_daily_digest_job", {
        p_job_id: jobId,
        p_lease_token: leaseToken,
        p_worker_id: workerId,
        p_expected_row_version: rowVersion,
        p_idempotency_key: `franchise-digest:${jobId}:${rowVersion}`,
        p_correlation_id: correlationId,
      });
      if (result.error) return Response.json({ code: "FRANCHISE_DIGEST_COMPLETION_FAILED" }, { status: 503, headers });
      completed++;
    }

    return Response.json({ outcome: "FRANCHISE_DIGESTS_PROCESSED", scheduled: scheduled.data.length, claimed: claimed.data.length, completed }, {
      headers: { ...headers, "x-correlation-id": correlationId },
    });
  } catch {
    return Response.json({ code: "FRANCHISE_DIGEST_WORKER_FAILED" }, { status: 503, headers });
  }
}

export const GET = POST;
