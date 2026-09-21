import type { UserActionItem } from "./model";

export type DashboardActionSummary = {
  total: number;
  overdue: number;
  mandatory: number;
  humanReview: number;
  dueToday: number;
  byPriority: Record<UserActionItem["priority"], number>;
  byKind: Record<UserActionItem["kind"], number>;
  /** Score de suivi 0–100 : plus haut = moins de pression critique. */
  followUpScore: number;
};

function startOfDay(iso: string): number {
  const date = new Date(iso);
  return Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
}

function endOfDay(iso: string): number {
  return startOfDay(iso) + 86_400_000 - 1;
}

export function filterDashboardActions(items: readonly UserActionItem[], selectedOrganizationId: string | null): UserActionItem[] {
  if (!selectedOrganizationId) return [...items];
  return items.filter((item) => item.organizationId === selectedOrganizationId || item.organizationId === null);
}

export function summarizeDashboardActions(items: readonly UserActionItem[], now: string): DashboardActionSummary {
  const current = Date.parse(now);
  const dayStart = startOfDay(now);
  const dayEnd = endOfDay(now);
  const byPriority: DashboardActionSummary["byPriority"] = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0 };
  const byKind: DashboardActionSummary["byKind"] = { NOTIFICATION: 0, MESSAGE: 0, APPROVAL: 0, EXCEPTION: 0, RISK_REVIEW: 0, WORK_ITEM: 0 };
  let overdue = 0;
  let mandatory = 0;
  let humanReview = 0;
  let dueToday = 0;

  for (const item of items) {
    byPriority[item.priority] += 1;
    byKind[item.kind] += 1;
    if (item.mandatory) mandatory += 1;
    if (item.requiresHumanReview) humanReview += 1;
    if (item.dueAt) {
      const due = Date.parse(item.dueAt);
      if (due <= current) overdue += 1;
      if (due >= dayStart && due <= dayEnd) dueToday += 1;
    }
  }

  const total = items.length;
  const pressure = byPriority.CRITICAL * 28 + byPriority.HIGH * 14 + overdue * 18 + mandatory * 8;
  const followUpScore = total === 0 ? 100 : Math.max(12, Math.min(100, Math.round(100 - pressure / Math.max(total * 1.35, 1))));

  return { total, overdue, mandatory, humanReview, dueToday, byPriority, byKind, followUpScore };
}
