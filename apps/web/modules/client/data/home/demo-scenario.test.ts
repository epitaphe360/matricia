import { afterEach, describe, expect, it } from "vitest";
import { applyDemoClientHome, isDemoClientOrganization } from "./demo-scenario";

const snapshot = {
  status: "success" as const,
  stage: "active" as const,
  counts: { openRequests: 1, quotesToReview: 0, activeMissions: 0, pendingDecisions: 0, upcomingDue: 0 },
  lastRequestId: "11111111-1111-4111-8111-111111111111",
  organizationName: "Client · Communication, marketing et création",
  featuredProject: null,
  comparison: null,
  insights: { documentsToReview: 0, nextMilestoneTitle: null, nextMilestoneDue: null, messagesToHandle: 0 },
};

describe("demo client home scenario", () => {
  afterEach(() => {
    delete process.env.MATRICIA_DEMO_ACCESS_ENABLED;
    delete process.env.APP_ENV;
  });

  it("ne s’applique qu’aux organisations Client démo hors production", () => {
    expect(isDemoClientOrganization("Client · Communication, marketing et création")).toBe(true);
    expect(isDemoClientOrganization("Epitaphe Market")).toBe(false);
    process.env.MATRICIA_DEMO_ACCESS_ENABLED = "true";
    process.env.APP_ENV = "development";
    const filled = applyDemoClientHome({
      locale: "fr",
      organizationId: "11111111-1111-4111-8111-111111111111",
      organizationName: "Client · Communication, marketing et création",
      selectedQuery: "?organizationId=11111111-1111-4111-8111-111111111111",
      now: "2026-09-19T10:00:00Z",
      items: [],
      snapshot,
    });
    expect(filled.items.length).toBeGreaterThan(3);
    expect(filled.snapshot.status === "success" && filled.snapshot.comparison?.columns).toHaveLength(2);
    expect(filled.items.some((item) => item.title.includes("Comparer"))).toBe(true);
    expect(JSON.stringify(filled)).not.toMatch(/exemple illustratif/i);
  });

  it("laisse un espace réel inchangé", () => {
    process.env.MATRICIA_DEMO_ACCESS_ENABLED = "true";
    process.env.APP_ENV = "development";
    const filled = applyDemoClientHome({
      locale: "fr",
      organizationId: "11111111-1111-4111-8111-111111111111",
      organizationName: "Epitaphe Market",
      selectedQuery: "",
      now: "2026-09-19T10:00:00Z",
      items: [],
      snapshot: { ...snapshot, organizationName: "Epitaphe Market" },
    });
    expect(filled.items).toHaveLength(0);
    expect(filled.snapshot.status === "success" && filled.snapshot.comparison).toBeNull();
  });
});
