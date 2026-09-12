import { z } from "zod";

export const uuidSchema = z.string().uuid();
export const hashSchema = z.string().regex(/^[0-9a-f]{64}$/u);
export const localeSchema = z.enum(["fr", "ar"]);
export const requestStatusSchema = z.enum(["DRAFT", "INFORMATION_REQUIRED", "READY", "MATCHING", "RFQ_OPEN", "QUOTES_RECEIVED", "CLIENT_REVIEW", "PROVIDER_SELECTED", "CONTRACT_PENDING", "CONTRACTED", "CANCELLED", "EXPIRED", "NO_PROVIDER_AVAILABLE"]);
export const quoteStatusSchema = z.enum(["DRAFT", "SUBMITTED", "REVISION_REQUESTED", "REVISED", "SELECTED", "NOT_SELECTED", "WITHDRAWN", "EXPIRED"]);

export function moneyToMinor(value: string): string | null {
  const normalized = value.trim().replace(",", ".");
  if (!/^\d{1,15}(?:\.\d{1,2})?$/u.test(normalized)) return null;
  const [whole, fraction = ""] = normalized.split(".");
  return (BigInt(whole) * BigInt(100) + BigInt(fraction.padEnd(2, "0"))).toString();
}

export type ClientOrganization = { id: string; name: string };
export type ClientRequestSummary = {
  id: string; organizationId: string; libraryId: string; serviceId: string; status: z.infer<typeof requestStatusSchema>;
  rowVersion: number; description: string; urgency: "LOW" | "NORMAL" | "HIGH" | "CRITICAL"; desiredDate: string | null;
  budgetMinor: string | null; currency: string; createdAt: string; matchingRunId: string | null; eligibleCount: number | null; rfqId: string | null; rfqDeadline: string | null; quoteCount: number;
};
export type QuoteComparisonRow = {
  quoteId: string; quoteVersionId: string; versionNumber: number; currency: string; subtotalMinor: string; taxMinor: string;
  totalMinor: string; recurringSubtotalMinor: string; durationDays: number; deliverablesCount: number; validUntil: string; priceRank: number;
};
