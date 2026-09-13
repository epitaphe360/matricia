import { randomUUID, timingSafeEqual } from "node:crypto";
import { resolveSocialCredentialReference } from "@/lib/marketing-autopilot/credential-resolver";
import { publicationJobSchema, publishScheduledSocial, type PublicationResult } from "@/lib/marketing-autopilot/publisher";
import { getSupabaseAdminClient } from "@/lib/supabase/admin";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

const headers = { "cache-control": "no-store" } as const;
type Summary = { processed: number; published: number; sandboxed: number; retried: number; failed: number; skipped: number; reconciliationRequired: number; timedOutMarked: number; timeoutSweepFailed: boolean };

function authorized(request: Request) {
  const expected = process.env.CRON_SECRET ?? "";
  const match = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i);
  const supplied = match?.[1] ?? "";
  const a = Buffer.from(expected), b = Buffer.from(supplied);
  return a.length >= 32 && a.length === b.length && timingSafeEqual(a, b);
}

function requestedLimit(request: Request) {
  const parsed = Number(new URL(request.url).searchParams.get("limit") ?? 5);
  return Number.isInteger(parsed) ? Math.min(10, Math.max(1, parsed)) : 5;
}

function countResult(summary: Summary, result: PublicationResult) {
  if (result.outcome === "PUBLISHED") summary.published++;
  else if (result.outcome === "RETRYABLE_FAILURE") summary.retried++;
  else if (result.outcome === "SANDBOXED") summary.sandboxed++;
  else summary.failed++;
}

export async function POST(request: Request) {
  if (!authorized(request)) return Response.json({ code: "UNAUTHORIZED" }, { status: 401, headers });
  const client = getSupabaseAdminClient();
  const workerId = `web-${randomUUID()}`;
  const limit = requestedLimit(request);
  const summary: Summary = { processed: 0, published: 0, sandboxed: 0, retried: 0, failed: 0, skipped: 0, reconciliationRequired: 0, timedOutMarked: 0, timeoutSweepFailed: false };
  const timeoutSweep = await client.rpc("mark_timed_out_social_publication_attempts_v1", { p_limit: 100, p_correlation_id: randomUUID() });
  const marked = (timeoutSweep.data as { marked?: unknown } | null)?.marked;
  if (timeoutSweep.error || typeof marked !== "number" || !Number.isInteger(marked) || marked < 0) summary.timeoutSweepFailed = true;
  else summary.timedOutMarked = marked;

  for (let index = 0; index < limit; index++) {
    const claim = await client.rpc("claim_next_social_publication_job_v41", { p_worker_id: workerId, p_correlation_id: randomUUID() });
    if (claim.error) return Response.json({ code: "CLAIM_FAILED", summary }, { status: 503, headers });
    const raw = claim.data as unknown;
    const outcome = (raw as { outcome?: string } | null)?.outcome;
    if (outcome === "NO_JOB") break;
    if (outcome === "SKIPPED_POLICY") { summary.skipped++; continue; }
    if (outcome === "PROVIDER_QUOTA_EXHAUSTED") { summary.skipped++; break; }

    const parsed = publicationJobSchema.safeParse(raw);
    if (!parsed.success) { summary.failed++; summary.reconciliationRequired++; continue; }
    const job = parsed.data;
    let result: PublicationResult;
    try {
      result = await publishScheduledSocial(job, {
        mode: process.env.MARKETING_PUBLISH_MODE === "live" ? "live" : "sandbox",
        liveEnabled: process.env.MARKETING_LIVE_PUBLISHING_ENABLED === "true",
        resolveCredential: (reference) => resolveSocialCredentialReference(reference, process.env),
        fetch,
      });
    } catch {
      result = { outcome: "RECONCILIATION_REQUIRED", errorCode: "WORKER_PROCESSING_UNKNOWN" };
    }

    summary.processed++;
    if (result.outcome === "RECONCILIATION_REQUIRED") {
      // Leave the lease untouched: migration 185 moves the timed-out attempt to
      // RECONCILIATION_REQUIRED, preserving ambiguity instead of retrying a send.
      summary.failed++;
      summary.reconciliationRequired++;
      continue;
    }
    const record = await client.rpc("record_social_publication_worker_result_v42", {
      p_job_id: job.job_id,
      p_lease_token: job.lease_token,
      p_outcome: result.outcome,
      p_provider_publication_id: result.outcome === "PUBLISHED" ? result.providerPublicationId : null,
      p_error_code: result.outcome === "RETRYABLE_FAILURE" || result.outcome === "PERMANENT_FAILURE" ? result.errorCode : null,
      p_idempotency_key: `worker-result:${job.job_id}:${job.attempt}`,
      p_correlation_id: randomUUID(),
    });
    if (record.error) { summary.failed++; summary.reconciliationRequired++; continue; }
    countResult(summary, result);
  }

  return Response.json(summary, { headers });
}

export const GET = POST;
