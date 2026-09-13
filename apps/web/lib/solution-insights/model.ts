import { z } from "zod";
export const uuid = z.string().uuid();
export const solutionLevel = z.enum(["ESSENTIAL", "STANDARD", "ADVANCED"]);
export const solutionDecision = z.enum(["ACCEPTED", "REJECTED", "DEFERRED"]);
export const localizedNarrative = z.object({ fr: z.string().optional(), ar: z.string().optional(), label: z.string().optional() }).strict();
export const solutionNarrative = z.union([z.string(), localizedNarrative]);
export const explanationValue = z.union([z.string(), z.number().finite(), z.boolean(), localizedNarrative]);

export type SolutionLevel = z.infer<typeof solutionLevel>;
export type SolutionDecision = z.infer<typeof solutionDecision>;
export type SolutionNarrative = z.infer<typeof solutionNarrative>;
export type ExplanationValue = z.infer<typeof explanationValue>;
export type SolutionOption = {
  id: string;
  level: SolutionLevel;
  expectedScoreBps: number;
  estimatedAmountMinor: string | null;
  currency: string | null;
  benefits: SolutionNarrative[];
  tradeoffs: SolutionNarrative[];
  explanation: Record<string, ExplanationValue>;
};
export type SolutionSet = {
  id: string;
  anomalyId: string;
  canDecide: boolean;
  version: number;
  rationaleFr: string;
  rationaleAr: string;
  createdAt: string;
  options: SolutionOption[];
  decisions: { id: string; level: SolutionLevel; decision: SolutionDecision; reason: string; deferredUntil: string | null; decidedAt: string }[];
};
export type Benchmark = { id: string; metricCode: string; segmentKey: string; periodStart: string; periodEnd: string; groupSizeBand: string; roundedMean: string; publishedAt: string };
export type SolutionBundleItem = { id: string; serviceId: string; serviceVersionId: string; libraryId: string; dedupeKey: string; fusionStrategy: "KEEP_PRIMARY" | "MERGE_SCOPE" | "SEQUENCE"; sourceCount: number; provenance: unknown[]; amountMinor: string; sortOrder: number };
export type SolutionBundle = { id: string; organizationId: string; key: string; version: number; titleFr: string; titleAr: string; descriptionFr: string; descriptionAr: string; sourceManifestHash: string; fusionPolicySnapshot: Record<string, unknown>; libraryCodes: string[]; totalAmountMinor: string; currency: string; createdAt: string; items: SolutionBundleItem[] };

const localeTag = (locale: "fr" | "ar") => locale === "ar" ? "ar-MA" : "fr-MA";

export function formatMinorExact(value: string, currency: string, locale: "fr" | "ar") {
  const formatter = new Intl.NumberFormat(localeTag(locale), { style: "currency", currency });
  const digits = formatter.resolvedOptions().maximumFractionDigits ?? 2;
  const scale = BigInt(10) ** BigInt(digits);
  const amount = BigInt(value);
  const whole = amount / scale;
  const fraction = (amount % scale).toString().padStart(digits, "0");
  const integer = new Intl.NumberFormat(localeTag(locale), { maximumFractionDigits: 0 }).format(whole);
  return formatter.formatToParts(0).map((part) => part.type === "integer" ? integer : part.type === "fraction" ? fraction : part.value).join("");
}

export function formatScoreBps(value: number, locale: "fr" | "ar") {
  return new Intl.NumberFormat(localeTag(locale), { style: "percent", minimumFractionDigits: 0, maximumFractionDigits: 2 }).format(value / 10_000);
}

export function formatExactDecimal(value: string, locale: "fr" | "ar") {
  if (!/^-?\d+(?:\.\d+)?$/u.test(value)) return value;
  const negative = value.startsWith("-");
  const [integerPart, fractionPart] = (negative ? value.slice(1) : value).split(".");
  const integer = new Intl.NumberFormat(localeTag(locale), { maximumFractionDigits: 0 }).format(BigInt(integerPart ?? "0"));
  const decimal = new Intl.NumberFormat(localeTag(locale)).formatToParts(1.1).find((part) => part.type === "decimal")?.value ?? ",";
  return `${negative ? "-" : ""}${integer}${fractionPart ? `${decimal}${fractionPart}` : ""}`;
}

export function formatSolutionDate(value: string, locale: "fr" | "ar") {
  return new Intl.DateTimeFormat(localeTag(locale), { dateStyle: "medium", timeZone: "UTC" }).format(new Date(`${value.slice(0, 10)}T00:00:00Z`));
}

export function narrativeText(value: SolutionNarrative | ExplanationValue, locale: "fr" | "ar") {
  if (typeof value === "string") return value;
  if (typeof value === "number" || typeof value === "boolean") return String(value);
  return value[locale] ?? value.label ?? value.fr ?? value.ar ?? "—";
}
