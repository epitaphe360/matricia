import { z } from "zod";

export const uuid = z.string().uuid();
export const locale = z.enum(["fr", "ar"]);
export const code = z.string().trim().min(2).max(40).regex(/^[A-Z][A-Z0-9_-]+$/u);
export const minorAmount = z.string().trim().regex(/^\d+$/u);
export const sha256 = z.string().regex(/^[0-9a-f]{64}$/u);
export type Capability = "READ" | "MANAGE_PORTFOLIO" | "MANAGE_BUDGET";
export type Organization = { id: string; name: string; capabilities: Capability[] };
export type Site = { id: string; organizationId: string; code: string; nameFr: string; nameAr: string };
export type Project = { id: string; organizationId: string; code: string; siteId: string | null; status: string; version: number; rowVersion: number; progressBasisPoints: number; nameFr: string; nameAr: string; descriptionFr: string; descriptionAr: string; startedOn: string | null; targetEndOn: string | null };
export type Task = { id: string; projectId: string; key: string; type: string; status: string; dueAt: string | null; rowVersion: number; titleFr: string; titleAr: string };
export type Budget = { id: string; organizationId: string; fiscalYear: number; currency: string; libraryId: string | null; siteId: string | null; projectId: string | null; status: string; version: number; amountMinor: string; approvedAmountMinor: string | null };
export type CostCenter = { id: string; organizationId: string; code: string; status: string; version: number; nameFr: string; nameAr: string };
export type Allocation = { id: string; organizationId: string; costCenterId: string; budgetId: string; projectId: string | null; type: string; amountMinor: string; currency: string; createdAt: string };
export type CalendarItem = { organizationId: string; projectId: string | null; itemId: string; sourceKind: string; eventType: string; titleFr: string; titleAr: string; startsAt: string; endsAt: string | null; status: string };
export type Library = { id: string; nameFr: string; nameAr: string };
export type Portfolio = { organizations: Organization[]; sites: Site[]; projects: Project[]; tasks: Task[]; budgets: Budget[]; costCenters: CostCenter[]; allocations: Allocation[]; calendar: CalendarItem[]; libraries: Library[] };

export type RepoResult<T> = { status: "success"; value: T } | { status: "error"; reason: "UNAUTHENTICATED" | "FORBIDDEN" | "UNAVAILABLE" };

export function exactMoney(minor: string, currency: string) {
  const value = BigInt(minor);
  const whole = value / BigInt(100);
  const fraction = (value % BigInt(100)).toString().padStart(2, "0");
  return `${whole}.${fraction} ${currency}`;
}

export function moneyToMinor(value: string): string | null {
  const match = /^(\d+)(?:[.,](\d{1,2}))?$/u.exec(value.trim());
  if (!match) return null;
  const whole = match[1] ?? "0";
  const fraction = (match[2] ?? "").padEnd(2, "0");
  return (BigInt(whole) * BigInt(100) + BigInt(fraction || "0")).toString();
}
