import { randomUUID } from "node:crypto";

export function GET() {
  return Response.json(
    { status: "ok", service: "matricia-web", timestamp: new Date().toISOString() },
    { headers: { "x-correlation-id": randomUUID(), "cache-control": "no-store" } },
  );
}
