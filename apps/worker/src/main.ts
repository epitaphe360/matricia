import { randomUUID } from "node:crypto";
import { createServer } from "node:http";
import { createClient } from "@supabase/supabase-js";
import { buildHealthReport, buildReadinessReport } from "@matricia/observability";
import type { OutboxDispatcher, OutboxEnvelope } from "./index";
import { createSupabaseOutboxRepository } from "./outbox-repository";
import { pollOutboxOnce } from "./poller";

const required = (name: string): string => {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`WORKER_CONFIG_${name}_REQUIRED`);
  return value;
};

async function start(): Promise<void> {
  const supabaseUrl = required("NEXT_PUBLIC_SUPABASE_URL");
  const serviceKey = required("SUPABASE_SERVICE_ROLE_KEY");
  const dispatchUrl = new URL(required("WORKER_DISPATCH_URL"));
  const webhookSecret = required("INTERNAL_WEBHOOK_SECRET");
  const workerId = randomUUID();
  const repository = createSupabaseOutboxRepository(createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } }));
  let lastCycle: { ok: boolean; latencyMs: number } | null = null;

  const dispatcher: OutboxDispatcher = {
    async dispatch(event: OutboxEnvelope) {
      const response = await fetch(dispatchUrl, {
        method: "POST",
        headers: { authorization: `Bearer ${webhookSecret}`, "content-type": "application/json", "x-correlation-id": event.correlationId },
        body: JSON.stringify(event),
        signal: AbortSignal.timeout(10_000),
      });
      if (!response.ok) throw new Error("OUTBOX_DISPATCH_REJECTED");
    },
  };

  const poll = async () => {
    const started = performance.now();
    try {
      const result = await pollOutboxOnce(repository, dispatcher, workerId);
      lastCycle = { ok: result.failed === 0, latencyMs: performance.now() - started };
    } catch {
      lastCycle = { ok: false, latencyMs: performance.now() - started };
    }
  };
  await poll();
  const timer = setInterval(() => void poll(), 5_000);
  timer.unref();

  const port = Number.parseInt(process.env.PORT ?? "8080", 10);
  createServer((request, response) => {
    response.setHeader("content-type", "application/json");
    response.setHeader("cache-control", "no-store");
    if (request.url === "/health") {
      response.end(JSON.stringify(buildHealthReport("matricia-worker")));
      return;
    }
    if (request.url === "/readiness") {
      const report = buildReadinessReport("matricia-worker", {
        outbox: lastCycle?.ok
          ? { status: "up", latencyMs: lastCycle.latencyMs }
          : { status: "down", latencyMs: lastCycle?.latencyMs ?? 0, code: lastCycle ? "OUTBOX_POLL_FAILED" : "WORKER_NOT_STARTED" },
      });
      response.statusCode = report.status === "ready" ? 200 : 503;
      response.end(JSON.stringify(report));
      return;
    }
    response.statusCode = 404;
    response.end(JSON.stringify({ status: "not_found" }));
  }).listen(port);
}

void start().catch(() => {
  process.exitCode = 1;
});
