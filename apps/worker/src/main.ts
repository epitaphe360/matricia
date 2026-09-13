import { randomUUID } from "node:crypto";
import { createServer } from "node:http";
import { createClient } from "@supabase/supabase-js";
import { buildHealthReport, createJsonLogger } from "@matricia/observability";
import {
  createClamAvTcpScanner,
  createClamAvTcpHealthCheck,
  createDocumentScanLogger,
  createDocumentScanOutboxConsumer,
  createDocumentScanProcessor,
  createSupabaseDocumentScanRecorder,
  createSupabasePrivateDocumentStore,
  createSupabaseScanJobRepository,
  readClamAvTcpConfig,
} from "./client-compliance";
import { createWorkerDispatcher } from "./dispatcher";
import { createSupabaseOutboxRepository } from "./outbox-repository";
import { pollOutboxOnce } from "./poller";
import { readWorkerRuntimeConfig } from "./worker-config";
import { buildWorkerReadiness, createWorkerCycle } from "./worker-cycle";
import { createFranchiseFollowupScheduler } from "./franchise-followups";

async function start(): Promise<void> {
  const config = readWorkerRuntimeConfig(process.env);
  const workerId = randomUUID();
  const log = createJsonLogger((record) => process.stderr.write(`${record}\n`));
  const serviceClient = createClient(config.supabaseUrl, config.supabaseServiceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const repository = createSupabaseOutboxRepository(serviceClient);
  const documentScanConsumer = createDocumentScanOutboxConsumer(createDocumentScanProcessor({
    jobs: createSupabaseScanJobRepository(serviceClient),
    documents: createSupabasePrivateDocumentStore(serviceClient),
    antivirus: createClamAvTcpScanner(readClamAvTcpConfig(process.env)),
    recorder: createSupabaseDocumentScanRecorder(serviceClient),
    log: createDocumentScanLogger((record) => process.stderr.write(`${record}\n`)),
  }));
  const antivirusHealth = createClamAvTcpHealthCheck(readClamAvTcpConfig(process.env));
  const runFranchiseFollowups = createFranchiseFollowupScheduler(serviceClient, workerId);

  const dispatcher = createWorkerDispatcher({
    documentScanConsumer,
    dispatchUrl: config.dispatchUrl,
    webhookSecret: config.webhookSecret,
  });

  const cycle = createWorkerCycle({
    checkAntivirus: () => antivirusHealth.check(),
    pollOutbox: () => pollOutboxOnce(repository, dispatcher, workerId),
    onFailure: (dependency) => log("error", {
      requestId: randomUUID(),
      correlationId: randomUUID(),
      event: dependency === "antivirus" ? "antivirus.health" : "outbox.poll",
      outcome: "failure",
      actorId: workerId,
      errorCode: dependency === "antivirus" ? "ANTIVIRUS_UNAVAILABLE" : "OUTBOX_POLL_FAILED",
    }),
  });

  const server = createServer((request, response) => {
    response.setHeader("content-type", "application/json");
    response.setHeader("cache-control", "no-store");
    if (request.url === "/health") {
      response.end(JSON.stringify(buildHealthReport("matricia-worker")));
      return;
    }
    if (request.url === "/readiness") {
      const report = buildWorkerReadiness(cycle.getState());
      response.statusCode = report.status === "ready" ? 200 : 503;
      response.end(JSON.stringify(report));
      return;
    }
    response.statusCode = 404;
    response.end(JSON.stringify({ status: "not_found" }));
  });
  server.listen(config.port);
  void cycle.run();
  void runFranchiseFollowups().catch(() => log("error", { requestId: randomUUID(), correlationId: randomUUID(), event: "franchise.followup.scheduler", outcome: "failure", actorId: workerId, errorCode: "FRANCHISE_FOLLOWUP_CYCLE_FAILED" }));
  const timer = setInterval(() => void cycle.run(), 5_000);
  timer.unref();
  const followupTimer = setInterval(() => void runFranchiseFollowups().catch(() => log("error", { requestId: randomUUID(), correlationId: randomUUID(), event: "franchise.followup.scheduler", outcome: "failure", actorId: workerId, errorCode: "FRANCHISE_FOLLOWUP_CYCLE_FAILED" })), 30_000);
  followupTimer.unref();
}

void start().catch(() => {
  createJsonLogger((record) => process.stderr.write(`${record}\n`))("error", {
    requestId: randomUUID(), correlationId: randomUUID(), event: "worker.start", outcome: "failure", errorCode: "WORKER_START_FAILED",
  });
  process.exitCode = 1;
});
