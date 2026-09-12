import { z } from "zod";
import { uuidSchema } from "./model";

export const commandActions = ["CREATE_RELEASE", "ADD_RELEASE_ITEM", "SUBMIT_RELEASE", "CREATE_QUESTION"] as const;
export type CommandAction = (typeof commandActions)[number];
export type CommandIdentity = { idempotencyKey: string; correlationId: string };

const MAX_PAYLOAD_LENGTH = 10_000;
const MAX_AGE_MS = 24 * 60 * 60 * 1_000;
const storageEntrySchema = z.object({
  schemaVersion: z.literal(1),
  action: z.enum(commandActions),
  payload: z.string().min(2).max(MAX_PAYLOAD_LENGTH),
  idempotencyKey: uuidSchema,
  correlationId: uuidSchema,
  createdAt: z.number().int().nonnegative(),
}).strict();

type CommandStorage = Pick<Storage, "getItem" | "setItem" | "removeItem">;
const storageKey = (action: CommandAction) => `matricia:catalogue-command:v1:${action}`;

export function canonicalCommandPayload(formData: FormData): string {
  const entries = Array.from(formData.entries())
    .filter(([key]) => !key.startsWith("$ACTION_") && key !== "idempotencyKey" && key !== "correlationId" && key !== "confirmed")
    .map(([key, value]) => [key, typeof value === "string" ? value : value.name] as const)
    .sort(([leftKey, leftValue], [rightKey, rightValue]) => leftKey.localeCompare(rightKey) || leftValue.localeCompare(rightValue));
  const payload = JSON.stringify(entries);
  if (payload.length > MAX_PAYLOAD_LENGTH) throw new Error("CATALOGUE_COMMAND_PAYLOAD_TOO_LARGE");
  return payload;
}

export function resolveCommandIdentity(storage: CommandStorage, action: CommandAction, payload: string, fallback: CommandIdentity, now = Date.now()): CommandIdentity {
  if (payload.length < 2 || payload.length > MAX_PAYLOAD_LENGTH || !uuidSchema.safeParse(fallback.idempotencyKey).success || !uuidSchema.safeParse(fallback.correlationId).success) {
    throw new Error("INVALID_CATALOGUE_COMMAND_IDENTITY");
  }
  let parsed: ReturnType<typeof storageEntrySchema.safeParse> | null = null;
  try {
    parsed = storageEntrySchema.safeParse(JSON.parse(storage.getItem(storageKey(action)) ?? "null"));
    if (parsed.success && parsed.data.action === action && parsed.data.payload === payload
        && parsed.data.createdAt <= now + 5_000 && now - parsed.data.createdAt <= MAX_AGE_MS) {
      return { idempotencyKey: parsed.data.idempotencyKey, correlationId: parsed.data.correlationId };
    }
  } catch {
    parsed = null;
  }
  try {
    const entry = { schemaVersion: 1 as const, action, payload, ...fallback, createdAt: now };
    storage.setItem(storageKey(action), JSON.stringify(entry));
  } catch {
    // Storage can be unavailable in hardened browser contexts.
  }
  return fallback;
}

export function purgeConfirmedCommandIdentity(storage: CommandStorage, action: CommandAction, idempotencyKey: string): void {
  try {
    const parsed = storageEntrySchema.safeParse(JSON.parse(storage.getItem(storageKey(action)) ?? "null"));
    if (parsed.success && parsed.data.idempotencyKey === idempotencyKey) storage.removeItem(storageKey(action));
  } catch {
    // Storage is an availability enhancement; server-side idempotency remains authoritative.
  }
}
