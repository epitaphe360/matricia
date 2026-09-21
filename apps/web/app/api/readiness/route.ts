import { randomUUID } from "node:crypto";
import { buildReadinessReport, type DependencyReadiness } from "@matricia/observability";
import { getSupabaseAdminClient } from "@/modules/shared/lib/supabase/admin";

export const dynamic = "force-dynamic";

export async function GET() {
  const startedAt = performance.now();
  let database: DependencyReadiness;
  let outbox: DependencyReadiness;
  try {
    const { data, error } = await getSupabaseAdminClient().rpc("readiness_status");
    const probe = Array.isArray(data) ? data[0] : data;
    const latencyMs = performance.now() - startedAt;
    database = error || probe?.database_ok !== true
      ? { status: "down", latencyMs, code: "DATABASE_UNAVAILABLE" }
      : { status: "up", latencyMs };
    outbox = !error && probe?.database_ok === true && probe?.outbox_ok === true
      ? { status: "up", latencyMs }
      : { status: "down", latencyMs, code: error || probe?.database_ok !== true ? "OUTBOX_STATUS_UNAVAILABLE" : "OUTBOX_BACKLOG" };
  } catch {
    database = { status: "down", latencyMs: performance.now() - startedAt, code: "DATABASE_UNAVAILABLE" };
    outbox = { status: "down", latencyMs: performance.now() - startedAt, code: "OUTBOX_STATUS_UNAVAILABLE" };
  }

  const report = buildReadinessReport("matricia-web", { database, outbox });
  return Response.json(report, {
    status: report.status === "ready" ? 200 : 503,
    headers: { "x-correlation-id": randomUUID(), "cache-control": "no-store" },
  });
}
