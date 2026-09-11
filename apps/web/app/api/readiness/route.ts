import { randomUUID } from "node:crypto";
import { buildReadinessReport, type DependencyReadiness } from "@matricia/observability";
import { getSupabaseAdminClient } from "@/lib/supabase/admin";

export const dynamic = "force-dynamic";

export async function GET() {
  const startedAt = performance.now();
  let database: DependencyReadiness;
  try {
    const { data, error } = await getSupabaseAdminClient().rpc("readiness_status");
    const probe = Array.isArray(data) ? data[0] : data;
    database = error || probe?.database_ok !== true || probe?.outbox_ok !== true
      ? { status: "down", latencyMs: performance.now() - startedAt, code: "DATABASE_UNAVAILABLE" }
      : { status: "up", latencyMs: performance.now() - startedAt };
  } catch {
    database = { status: "down", latencyMs: performance.now() - startedAt, code: "DATABASE_UNAVAILABLE" };
  }

  const report = buildReadinessReport("matricia-web", { database });
  return Response.json(report, {
    status: report.status === "ready" ? 200 : 503,
    headers: { "x-correlation-id": randomUUID(), "cache-control": "no-store" },
  });
}
