import { describe, expect, it } from "vitest";
import { buildMarketingDemoPlan } from "../../../../../scripts/provision-marketing-demo.mjs";

type Plan = {
  orgs: Array<{ kind: string; id: string; analyticsWithdrawn: boolean; payload: { tracked_url: string } }>;
  campaigns: Array<{ id: string; mode: string; status: string }>;
  contents: Array<{ id: string; campaign: { id: string }; channel: string; template: string; version: { status: string } }>;
  items: Array<{ status: string; scheduledAt: string }>;
  metrics: Array<{ metric: string; quantity: number }>;
  exceptions: unknown[];
};

const services = Array.from({ length: 12 }, (_, index) => ({ id: `service-${index}`, libraryId: `library-${index % 3}` }));
const templates = ["BEFORE_AFTER", "EXPERT_TIP", "PROBLEM_SOLUTION", "PROVIDER_INTRO", "SERVICE_OF_MONTH", "SUCCESS_CASE"].map((key, index) => ({ key, versionId: `template-${index}` }));

describe("plan de démonstration marketing", () => {
  const plan = buildMarketingDemoPlan({ projectRef: "demo-ref", services, templates }) as Plan;

  it("respecte les volumes annoncés", () => {
    expect(plan.orgs.filter((org) => org.kind === "FRANCHISE")).toHaveLength(10);
    expect(plan.orgs.filter((org) => org.kind === "PROVIDER")).toHaveLength(20);
    expect(plan.campaigns).toHaveLength(50);
    expect(plan.contents).toHaveLength(300);
    expect(plan.items).toHaveLength(100);
  });

  it("couvre les cas réussis, échoués, bloqués et sans consentement analytique", () => {
    expect(plan.items.some((item) => item.status === "PUBLISHED")).toBe(true);
    expect(plan.items.some((item) => item.status === "FAILED")).toBe(true);
    expect(plan.items.some((item) => item.status === "SCHEDULED")).toBe(true);
    expect(plan.contents.some((content) => content.version.status === "BLOCKED")).toBe(true);
    expect(plan.exceptions.length).toBeGreaterThan(0);
    expect(plan.orgs.some((org) => org.analyticsWithdrawn)).toBe(true);
    expect(new Set(plan.campaigns.map((campaign) => campaign.mode))).toEqual(new Set(["AUTOPILOT", "ASSISTED", "MANUAL"]));
    expect(plan.metrics.some((metric) => metric.metric === "CLICK" && metric.quantity > 20)).toBe(true);
  });

  it("est déterministe et respecte les contraintes d'unicité et de dates", () => {
    const again = buildMarketingDemoPlan({ projectRef: "demo-ref", services, templates }) as Plan;
    expect(again.campaigns.map((campaign) => campaign.id)).toEqual(plan.campaigns.map((campaign) => campaign.id));
    expect(new Set(plan.contents.map((content) => `${content.campaign.id}|${content.channel}|${content.template}`)).size).toBe(300);
    for (const item of plan.items) expect(item.status === "SCHEDULED" ? item.scheduledAt.startsWith("2026-10") : item.scheduledAt.startsWith("2026-09")).toBe(true);
    expect(plan.orgs.every((org) => org.payload.tracked_url.startsWith("https://"))).toBe(true);
  });
});
