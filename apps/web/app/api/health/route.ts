import { randomUUID } from "node:crypto";
import { buildHealthReport } from "@matricia/observability";

export function GET() {
  return Response.json(
    buildHealthReport("matricia-web"),
    { headers: { "x-correlation-id": randomUUID(), "cache-control": "no-store" } },
  );
}
