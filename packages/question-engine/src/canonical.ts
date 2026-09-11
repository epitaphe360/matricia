import { createHash } from "node:crypto";
import { QuestionEngineError } from "./errors";

const NON_SEMANTIC_KEYS = new Set(["metadata", "createdAt", "updatedAt"]);

export function compareCodePoints(left: string, right: string): number {
  const a = left.normalize("NFC");
  const b = right.normalize("NFC");
  const aCodePoints = Array.from(a, (character) => character.codePointAt(0)!);
  const bCodePoints = Array.from(b, (character) => character.codePointAt(0)!);
  const length = Math.min(aCodePoints.length, bCodePoints.length);
  for (let index = 0; index < length; index += 1) {
    const difference = aCodePoints[index]! - bCodePoints[index]!;
    if (difference !== 0) return difference < 0 ? -1 : 1;
  }
  return aCodePoints.length === bCodePoints.length ? 0 : aCodePoints.length < bCodePoints.length ? -1 : 1;
}

function canonicalizeInner(value: unknown, ancestors: WeakSet<object>): string {
  if (value === null) return "null";
  if (typeof value === "string") return JSON.stringify(value.normalize("NFC"));
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "bigint") return JSON.stringify(value.toString());
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value)) throw new QuestionEngineError("INVALID_INPUT");
    return String(value);
  }
  if (Array.isArray(value)) {
    if (ancestors.has(value)) throw new QuestionEngineError("INVALID_INPUT");
    ancestors.add(value);
    const result = `[${value.map((item) => canonicalizeInner(item, ancestors)).join(",")}]`;
    ancestors.delete(value);
    return result;
  }
  if (typeof value === "object" && value !== undefined) {
    const prototype = Object.getPrototypeOf(value) as unknown;
    if (prototype !== Object.prototype && prototype !== null) throw new QuestionEngineError("INVALID_INPUT");
    if (ancestors.has(value)) throw new QuestionEngineError("INVALID_INPUT");
    ancestors.add(value);
    const record = value as Record<string, unknown>;
    const entries = Object.keys(record).filter((key) => !NON_SEMANTIC_KEYS.has(key)).map((key) => ({ key, normalized: key.normalize("NFC") })).sort((a, b) => compareCodePoints(a.normalized, b.normalized));
    if (new Set(entries.map((entry) => entry.normalized)).size !== entries.length) throw new QuestionEngineError("INVALID_INPUT");
    const result = `{${entries.map(({ key, normalized }) => `${JSON.stringify(normalized)}:${canonicalizeInner(record[key], ancestors)}`).join(",")}}`;
    ancestors.delete(value);
    return result;
  }
  throw new QuestionEngineError("INVALID_INPUT");
}

export function canonicalize(value: unknown): string {
  return canonicalizeInner(value, new WeakSet());
}

export function canonicalHash(value: unknown): string {
  return createHash("sha256").update(canonicalize(value), "utf8").digest("hex");
}
