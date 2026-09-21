import { describe, expect, it } from "vitest";
import { orderUserActions, type UserActionItem } from "./model";

const base: UserActionItem = { id: "a", kind: "MESSAGE", title: "A", detail: "A", organizationName: null, organizationId:null, priority: "LOW", mandatory: false, href: "/fr/messagerie", occurredAt: "2026-09-12T10:00:00Z", dueAt: null, requiresHumanReview: false };

describe("orderUserActions", () => {
  it("place les obligations puis les échéances et priorités avant la récence", () => {
    const ordered = orderUserActions([
      base,
      { ...base, id: "critical", priority: "CRITICAL" },
      { ...base, id: "overdue", dueAt: "2026-09-11T10:00:00Z" },
      { ...base, id: "mandatory", mandatory: true },
    ], "2026-09-12T12:00:00Z");
    expect(ordered.map((item) => item.id)).toEqual(["mandatory", "overdue", "critical", "a"]);
  });
});
