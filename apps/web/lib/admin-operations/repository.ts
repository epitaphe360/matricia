import { z } from "zod";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import type { AdminOperationsResult, SafeAuditEvent } from "./model";

const allowedRoles = ["SUPER_ADMIN", "MATRICIA_ADMIN", "READ_ONLY_AUDITOR"] as const;
const roleRow = z.object({ role_code: z.enum(allowedRoles) }).strict();
const bigintId = z.union([z.string().regex(/^\d+$/), z.number().int().nonnegative()]).transform(String);
const auditRow = z.object({
  id: bigintId,
  actor_type: z.enum(["USER", "SERVICE", "SYSTEM"]),
  action: z.string().min(1).max(160),
  resource_type: z.string().min(1).max(160),
  correlation_id: z.string().uuid(),
  occurred_at: z.string(),
  event_hash: z.string().regex(/^[0-9a-f]{64}$/),
}).strict();

function classify(action: string): SafeAuditEvent["signal"] {
  const normalized = action.toLowerCase();
  if (normalized.includes("dead_letter")) return "DEAD_LETTER";
  if (normalized.startsWith("notification.")) return "NOTIFICATION";
  if (normalized.includes("outbox")) return "OUTBOX";
  return "GENERAL";
}

export async function loadAdminOperationsDashboard(): Promise<AdminOperationsResult> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };

  const rolesQuery = await client.from("platform_user_roles").select("role_code")
    .eq("user_id", auth.user.id).is("revoked_at", null).in("role_code", [...allowedRoles]).limit(3);
  if (rolesQuery.error) return { status: "error", reason: "UNAVAILABLE" };
  const roles = z.array(roleRow).safeParse(rolesQuery.data);
  if (!roles.success) return { status: "error", reason: "INVALID_RESPONSE" };
  if (roles.data.length === 0) return { status: "error", reason: "FORBIDDEN" };

  // Deliberately excludes organization/user identifiers, IP, user-agent and metadata/payload.
  const eventsQuery = await client.from("audit_events")
    .select("id,actor_type,action,resource_type,correlation_id,occurred_at,event_hash")
    .order("occurred_at", { ascending: false }).order("id", { ascending: false }).limit(200);
  if (eventsQuery.error) return { status: "error", reason: "UNAVAILABLE" };
  const rows = z.array(auditRow).safeParse(eventsQuery.data);
  if (!rows.success) return { status: "error", reason: "INVALID_RESPONSE" };

  const events: SafeAuditEvent[] = rows.data.map((event) => ({
    id: event.id,
    actorType: event.actor_type,
    action: event.action,
    resourceType: event.resource_type,
    correlationId: event.correlation_id,
    occurredAt: event.occurred_at,
    eventHash: event.event_hash,
    signal: classify(event.action),
  }));
  const count = (signal: SafeAuditEvent["signal"]) => events.filter((event) => event.signal === signal).length;

  return { status: "success", value: {
    capabilities: {
      audit: true,
      outbox: { available: false, reason: "SAFE_PROJECTION_UNAVAILABLE" },
      notificationDeliveries: { available: false, reason: "SAFE_PROJECTION_UNAVAILABLE" },
      actions: false,
    },
    summary: {
      auditedEvents: events.length,
      systemEvents: events.filter((event) => event.actorType !== "USER").length,
      notificationSignals: count("NOTIFICATION"),
      deadLetterSignals: count("DEAD_LETTER"),
      outboxSignals: count("OUTBOX"),
    },
    events,
  } };
}
