import { describe, expect, it } from "vitest";
import type { AdminWorkItem } from "./model";
import { summarizeAdminWork } from "./view-model";
const base: AdminWorkItem = { id: "1", queueKey: "OPS", queueLabelFr: "Ops", queueLabelAr: "عمليات", organizationId: null, sourceKind: "EXCEPTION", resourceType: "case", resourceId: "1", titleFr: "Cas", titleAr: "حالة", priority: "LOW", status: "OPEN", dueAt: "2026-09-13T12:00:00Z", assignedTo: null, rowVersion: 1 };
describe("summarizeAdminWork", () => { it("priorise le jour et la criticité", () => { const summary = summarizeAdminWork([base, { ...base, id: "2", priority: "CRITICAL", sourceKind: "RISK_FLAG", dueAt: "2026-09-12T11:00:00Z" }, { ...base, id: "3", priority: "HIGH", dueAt: "2026-09-12T15:00:00Z" }], "2026-09-12T14:00:00Z"); expect(summary.ordered.map(item => item.id)).toEqual(["2", "3", "1"]); expect(summary).toMatchObject({ critical: 1, overdue: 1, dueToday: 2, humanReview: 1, exceptions: 2 }) }) });
