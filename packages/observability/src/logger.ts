export type LogLevel = "debug" | "info" | "warn" | "error";
export type LogOutcome = "success" | "failure";

export type StructuredLogContext = Readonly<{
  requestId: string;
  correlationId: string;
  event: string;
  outcome: LogOutcome;
  actorId?: string;
  aggregateType?: string;
  aggregateId?: string;
  errorCode?: string;
  data?: Readonly<Record<string, unknown>>;
}>;

export type StructuredLogRecord = Readonly<{
  timestamp: string;
  level: LogLevel;
  request_id: string;
  correlation_id: string;
  event: string;
  outcome: LogOutcome;
  actor_id?: string;
  aggregate_type?: string;
  aggregate_id?: string;
  error_code?: string;
  data?: unknown;
}>;

export type LogSink = (serializedRecord: string) => void;

const REDACTED = "[REDACTED]";
const SENSITIVE_KEY = /(?:authorization|cookie|password|passwd|secret|token|api[_-]?key|email|phone|address|birth|national[_-]?id|document|evidence|payload)/i;
const SENSITIVE_VALUE = /(?:\bBearer\s+\S+|[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b)/i;

function redact(value: unknown, seen: WeakSet<object>): unknown {
  if (Array.isArray(value)) return value.map((entry) => redact(entry, seen));
  if (typeof value === "string" && SENSITIVE_VALUE.test(value)) return REDACTED;
  if (value === null || typeof value !== "object") return value;
  if (seen.has(value)) return "[CIRCULAR]";

  seen.add(value);
  const clean: Record<string, unknown> = {};
  for (const [key, entry] of Object.entries(value)) {
    clean[key] = SENSITIVE_KEY.test(key) ? REDACTED : redact(entry, seen);
  }
  return clean;
}

export function redactSensitiveData(value: unknown): unknown {
  return redact(value, new WeakSet<object>());
}

export function createLogRecord(
  level: LogLevel,
  context: StructuredLogContext,
  now: () => Date = () => new Date(),
): StructuredLogRecord {
  return {
    timestamp: now().toISOString(),
    level,
    request_id: context.requestId,
    correlation_id: context.correlationId,
    event: context.event,
    outcome: context.outcome,
    ...(context.actorId === undefined ? {} : { actor_id: context.actorId }),
    ...(context.aggregateType === undefined ? {} : { aggregate_type: context.aggregateType }),
    ...(context.aggregateId === undefined ? {} : { aggregate_id: context.aggregateId }),
    ...(context.errorCode === undefined ? {} : { error_code: context.errorCode }),
    ...(context.data === undefined ? {} : { data: redactSensitiveData(context.data) }),
  };
}

export function createJsonLogger(
  sink: LogSink = (serializedRecord) => console.log(serializedRecord),
  now: () => Date = () => new Date(),
) {
  return (level: LogLevel, context: StructuredLogContext): void => {
    sink(JSON.stringify(createLogRecord(level, context, now)));
  };
}
