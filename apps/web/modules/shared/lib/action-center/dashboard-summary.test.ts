import { describe, expect, it } from "vitest";
import { filterDashboardActions, summarizeDashboardActions, type DashboardActionSummary } from "./dashboard-summary";
import type { UserActionItem } from "./model";

const item = (partial: Partial<UserActionItem> & Pick<UserActionItem, "id">): UserActionItem => ({
  kind: "MESSAGE",
  title: "t",
  detail: "d",
  organizationName: null,
  organizationId: null,
  priority: "LOW",
  mandatory: false,
  href: "/fr/actions",
  occurredAt: "2026-09-16T10:00:00Z",
  dueAt: null,
  requiresHumanReview: false,
  ...partial,
});

describe("dashboard summary", () => {
  it("filtre les actions par organisation tout en gardant le périmètre plateforme", () => {
    const items = [
      item({ id: "org", organizationId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" }),
      item({ id: "other", organizationId: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb" }),
      item({ id: "platform", organizationId: null }),
    ];
    expect(filterDashboardActions(items, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa").map((entry) => entry.id)).toEqual(["org", "platform"]);
    expect(filterDashboardActions(items, null).map((entry) => entry.id)).toEqual(["org", "other", "platform"]);
  });

  it("calcule les compteurs colorés et un score de suivi", () => {
    const summary: DashboardActionSummary = summarizeDashboardActions(
      [
        item({ id: "c", priority: "CRITICAL", dueAt: "2026-09-15T09:00:00Z", mandatory: true, requiresHumanReview: true, kind: "APPROVAL" }),
        item({ id: "h", priority: "HIGH", dueAt: "2026-09-16T18:00:00Z", kind: "NOTIFICATION" }),
        item({ id: "m", priority: "MEDIUM", kind: "MESSAGE" }),
      ],
      "2026-09-16T12:00:00Z",
    );
    expect(summary.total).toBe(3);
    expect(summary.overdue).toBe(1);
    expect(summary.dueToday).toBe(1);
    expect(summary.mandatory).toBe(1);
    expect(summary.humanReview).toBe(1);
    expect(summary.byPriority.CRITICAL).toBe(1);
    expect(summary.byKind.APPROVAL).toBe(1);
    expect(summary.followUpScore).toBeLessThan(100);
    expect(summary.followUpScore).toBeGreaterThan(0);
  });
});
