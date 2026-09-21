import { describe, expect, it } from "vitest";
import type { FranchiseCrmDashboard } from "@/modules/franchise/data/crm/model";
import { buildFranchiseHomeFeed, computeFranchiseHomeCounts, unavailableFranchiseHomeCounts } from "./view-model";

const NOW = "2026-09-18T12:00:00.000Z";

function dashboard(overrides: Partial<FranchiseCrmDashboard> = {}): FranchiseCrmDashboard {
  return {
    currentUserId: "11111111-1111-4111-8111-111111111111",
    canWrite: true,
    canRecordPerformance: false,
    franchises: [
      {
        id: "22222222-2222-4222-8222-222222222222",
        operatorCode: "FR-AGD-01",
        type: "STANDARD",
        canWrite: true,
        territory: null,
      },
    ],
    prospects: [],
    metrics: [],
    snapshots: [],
    alerts: [],
    objectives: [],
    ...overrides,
  };
}

function prospect(overrides: Partial<FranchiseCrmDashboard["prospects"][number]> = {}): FranchiseCrmDashboard["prospects"][number] {
  return {
    id: "33333333-3333-4333-8333-333333333333",
    franchiseId: "22222222-2222-4222-8222-222222222222",
    territoryVersionId: "44444444-4444-4444-8444-444444444444",
    type: "CLIENT",
    displayName: "Atlas Pêche",
    contactEmail: "contact@example.ma",
    organizationName: null,
    sourceCode: "TERRAIN",
    stage: "REGISTERED",
    nextFollowupAt: null,
    rowVersion: 1,
    activities: [],
    pipelineEvents: [],
    ...overrides,
  };
}

function alert(overrides: Partial<FranchiseCrmDashboard["alerts"][number]> = {}): FranchiseCrmDashboard["alerts"][number] {
  return {
    id: "55555555-5555-4555-8555-555555555555",
    franchiseId: "22222222-2222-4222-8222-222222222222",
    snapshotId: "66666666-6666-4666-8666-666666666666",
    type: "KPI_THRESHOLD",
    severity: "WARNING",
    status: "OPEN",
    metricCode: "CLIENT_NETWORK",
    explanationFr: "Score réseau clients sous le seuil",
    explanationAr: "درجة شبكة العملاء تحت العتبة",
    evidenceRefs: [],
    ruleVersion: "v1",
    ...overrides,
  };
}

describe("franchise-home view-model", () => {
  it("n’invente pas de zéro lorsque le dashboard est indisponible", () => {
    const counts = unavailableFranchiseHomeCounts();
    expect(counts.activeProspects).toBeNull();
    expect(counts.overdueFollowups).toBeNull();
    expect(counts.openAlerts).toBeNull();
    expect(counts.criticalAlerts).toBeNull();
    expect(counts.activeObjectives).toBeNull();
  });

  it("compte uniquement les données réelles du périmètre autorisé", () => {
    const counts = computeFranchiseHomeCounts(
      dashboard({
        prospects: [
          prospect({ id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", stage: "REGISTERED", nextFollowupAt: "2026-09-17T09:00:00.000Z" }),
          prospect({ id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", stage: "CONTRACT_SIGNED", nextFollowupAt: "2026-09-30T09:00:00.000Z" }),
          prospect({ id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc", stage: "VERIFIED", nextFollowupAt: "2026-10-02T09:00:00.000Z" }),
        ],
        alerts: [
          alert({ id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd", severity: "CRITICAL" }),
          alert({ id: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee", status: "RESOLVED" }),
        ],
        objectives: [
          {
            id: "ffffffff-ffff-4fff-8fff-ffffffffffff",
            franchiseId: "22222222-2222-4222-8222-222222222222",
            code: "OBJ",
            version: 1,
            titleFr: "Objectif",
            titleAr: "هدف",
            targetValue: "10",
            currentValue: "4",
            unitCode: "COUNT",
            status: "ACTIVE",
            startsOn: "2026-09-01",
            dueOn: "2026-12-31",
            ruleVersion: "v1",
          },
        ],
      }),
      NOW,
    );
    expect(counts.activeProspects).toBe(2);
    expect(counts.overdueFollowups).toBe(1);
    expect(counts.openAlerts).toBe(1);
    expect(counts.criticalAlerts).toBe(1);
    expect(counts.activeObjectives).toBe(1);
  });

  it("ordonne le flux : alertes critiques d’abord, puis relances par échéance", () => {
    const feed = buildFranchiseHomeFeed(
      dashboard({
        prospects: [
          prospect({ id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", displayName: "Relance future", nextFollowupAt: "2026-09-25T09:00:00.000Z" }),
          prospect({ id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", displayName: "Relance en retard", nextFollowupAt: "2026-09-17T09:00:00.000Z" }),
        ],
        alerts: [
          alert({ id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc", severity: "INFO" }),
          alert({ id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd", severity: "CRITICAL" }),
        ],
      }),
      "fr",
      NOW,
    );
    expect(feed.map((item) => item.id)).toEqual([
      "alert:dddddddd-dddd-4ddd-8ddd-dddddddddddd",
      "alert:cccccccc-cccc-4ccc-8ccc-cccccccccccc",
      "followup:bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "followup:aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    ]);
    expect(feed[0]?.tone).toBe("critical");
    expect(feed[2]?.tone).toBe("high");
    expect(feed[3]?.tone).toBe("default");
  });

  it("utilise l’explication localisée et le code opérateur réel", () => {
    const feed = buildFranchiseHomeFeed(dashboard({ alerts: [alert()] }), "ar", NOW);
    expect(feed[0]?.dossier).toBe("درجة شبكة العملاء تحت العتبة");
    expect(feed[0]?.owner).toBe("FR-AGD-01");
  });

  it("borne le flux sans inventer de ligne", () => {
    const feed = buildFranchiseHomeFeed(
      dashboard({
        prospects: Array.from({ length: 12 }, (_, index) =>
          prospect({ id: `aaaaaaaa-aaaa-4aaa-8aaa-${String(index).padStart(12, "0")}`, nextFollowupAt: `2026-09-${String(19 + (index % 9)).padStart(2, "0")}T09:00:00.000Z` })),
      }),
      "fr",
      NOW,
    );
    expect(feed).toHaveLength(8);
    expect(feed.every((item) => item.kind === "FOLLOWUP")).toBe(true);
  });
});
