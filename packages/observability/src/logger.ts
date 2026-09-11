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

const SENSITIVE_KEY_PATTERNS = [
  /^(?:authorization|proxyauthorization|cookie|setcookie)$/,
  /(?:password|passwd|passphrase|secret|token|apikey|privatekey|servicerole(?:key)?|servicekey)/,
  /(?:email|phone|mobile|address|birth|dateofbirth|nationalid|passport|document|evidence|payload)/,
  /(?:(?:client|customer|person|contact|legal|first|last|full)name|name(?:client|customer|person))/,
  /(?:^ice$|icenumber|iceidentifier|taxid|taxidentifier|fiscalid|vatnumber|taxnumber)/,
  /(?:^iban$|bankaccount|accountnumber|routingnumber|swiftcode|biccode|bankdetails)/,
  /(?:^ip$|ipaddress|clientip|remoteaddress|forwardedfor)/,
] as const;

const SENSITIVE_VALUE_PATTERNS = [
  /\bBearer\s+\S+/i,
  /[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/,
  /\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/,
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,
  /\b(?:sb_secret_|sk_live_|gh[oprsu]_)[A-Za-z0-9_-]{8,}\b/,
  /\b(?:service[_ -]?role|private[_ -]?key|api[_ -]?key)\s*[:=]\s*\S+/i,
  /\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]){11,30}\b/i,
  /\b(?:ICE|tax[_ -]?id|tax[_ -]?identifier|fiscal[_ -]?id|VAT)\s*[:=]\s*[A-Z0-9-]{5,}\b/i,
  /\b(?:client|customer|person)[_ -]?name\s*[:=]\s*[^,;]+/i,
  /\b(?:\d{1,3}\.){3}\d{1,3}\b/,
  /(?:^|\s)[A-F0-9]*:[A-F0-9:]+(?:\s|$)/i,
  /(?:^|[\s[(])(?:[A-F0-9]{1,4}:){2,7}[A-F0-9]{0,4}(?:$|[\s\])])/i,
] as const;

function isSensitiveKey(key: string): boolean {
  const normalized = key.toLowerCase().replace(/[^a-z0-9]/g, "");
  return SENSITIVE_KEY_PATTERNS.some((pattern) => pattern.test(normalized));
}

function isSensitiveValue(value: string): boolean {
  return SENSITIVE_VALUE_PATTERNS.some((pattern) => pattern.test(value));
}

function redact(value: unknown, seen: WeakSet<object>): unknown {
  if (Array.isArray(value)) return value.map((entry) => redact(entry, seen));
  if (typeof value === "string" && isSensitiveValue(value)) return REDACTED;
  if (value === null || typeof value !== "object") return value;
  if (seen.has(value)) return "[CIRCULAR]";

  seen.add(value);
  const clean: Record<string, unknown> = {};
  for (const [key, entry] of Object.entries(value)) {
    clean[key] = isSensitiveKey(key) ? REDACTED : redact(entry, seen);
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
