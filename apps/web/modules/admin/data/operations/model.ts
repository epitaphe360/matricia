export type OperationsCapability = {
  available: boolean;
  reason: "SAFE_PROJECTION_UNAVAILABLE" | null;
};

export type SafeAuditEvent = {
  id: string;
  actorType: "USER" | "SERVICE" | "SYSTEM";
  action: string;
  resourceType: string;
  correlationId: string;
  occurredAt: string;
  eventHash: string;
  signal: "GENERAL" | "NOTIFICATION" | "DEAD_LETTER" | "OUTBOX";
};

export type AdminOperationsDashboard = {
  capabilities: {
    audit: true;
    outbox: OperationsCapability;
    notificationDeliveries: OperationsCapability;
    actions: false;
  };
  summary: {
    auditedEvents: number;
    systemEvents: number;
    notificationSignals: number;
    deadLetterSignals: number;
    outboxSignals: number;
  };
  events: SafeAuditEvent[];
};

export type AdminOperationsResult =
  | { status: "success"; value: AdminOperationsDashboard }
  | { status: "error"; reason: "UNAUTHENTICATED" | "MFA_REQUIRED" | "FORBIDDEN" | "UNAVAILABLE" | "INVALID_RESPONSE" };
