import { QuestionEngineError } from "./errors";
import type { NumericRounding } from "./types";

const DECIMAL = /^-?(?:0|[1-9]\d*)(?:\.\d+)?$/;

export function normalizeDecimal(input: string): string {
  if (!DECIMAL.test(input)) throw new QuestionEngineError("INVALID_TYPE");
  const negative = input.startsWith("-");
  const unsigned = negative ? input.slice(1) : input;
  const [integer = "0", fraction = ""] = unsigned.split(".");
  const normalizedInteger = integer.replace(/^0+(?=\d)/, "");
  const normalizedFraction = fraction.replace(/0+$/, "");
  const magnitude = normalizedFraction ? `${normalizedInteger}.${normalizedFraction}` : normalizedInteger;
  return negative && magnitude !== "0" ? `-${magnitude}` : magnitude;
}

function parts(input: string): { coefficient: bigint; scale: number } {
  const normalized = normalizeDecimal(input);
  const negative = normalized.startsWith("-");
  const unsigned = negative ? normalized.slice(1) : normalized;
  const [integer = "0", fraction = ""] = unsigned.split(".");
  const coefficient = BigInt(`${integer}${fraction}`) * (negative ? -1n : 1n);
  return { coefficient, scale: fraction.length };
}

function align(left: string, right: string): [bigint, bigint, number] {
  const a = parts(left);
  const b = parts(right);
  const scale = Math.max(a.scale, b.scale);
  return [a.coefficient * 10n ** BigInt(scale - a.scale), b.coefficient * 10n ** BigInt(scale - b.scale), scale];
}

export function compareDecimal(left: string, right: string): number {
  const [a, b] = align(left, right);
  return a === b ? 0 : a < b ? -1 : 1;
}

export function addDecimal(left: string, right: string): string {
  const [a, b, scale] = align(left, right);
  const sum = a + b;
  const negative = sum < 0n;
  const digits = (negative ? -sum : sum).toString().padStart(scale + 1, "0");
  const raw = scale === 0 ? digits : `${digits.slice(0, -scale)}.${digits.slice(-scale)}`;
  return normalizeDecimal(negative ? `-${raw}` : raw);
}

export function exactInteger(input: string): boolean {
  return /^-?(?:0|[1-9]\d*)$/.test(input);
}

export function roundDecimal(input: string, scale: number, mode: NumericRounding): string {
  if (!Number.isSafeInteger(scale) || scale < 0) throw new QuestionEngineError("INVALID_TYPE");
  const parsed = parts(input);
  if (parsed.scale <= scale) return normalizeDecimal(input);
  const divisor = 10n ** BigInt(parsed.scale - scale);
  const negative = parsed.coefficient < 0n;
  const magnitude = negative ? -parsed.coefficient : parsed.coefficient;
  let quotient = magnitude / divisor;
  const remainder = magnitude % divisor;
  const twice = remainder * 2n;
  const increment = mode === "UP" ? remainder > 0n
    : mode === "DOWN" ? false
      : mode === "HALF_UP" ? twice >= divisor
        : twice > divisor || (twice === divisor && quotient % 2n === 1n);
  if (increment) quotient += 1n;
  const signed = negative ? -quotient : quotient;
  const digits = (signed < 0n ? -signed : signed).toString().padStart(scale + 1, "0");
  const raw = scale === 0 ? digits : `${digits.slice(0, -scale)}.${digits.slice(-scale)}`;
  return normalizeDecimal(signed < 0n ? `-${raw}` : raw);
}
