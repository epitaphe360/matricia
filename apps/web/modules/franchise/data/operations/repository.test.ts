import { describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ from: vi.fn(), getUser: vi.fn() }));

vi.mock("@/modules/shared/lib/supabase/server", () => ({
  getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, from: mocks.from }),
}));

import { loadFranchiseOperations } from "./repository";

const libraryId = "22222222-2222-4222-8222-222222222222";
const requestId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const serviceId = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee";

function chain(data: unknown) {
  const value = {
    select: vi.fn(() => value),
    eq: vi.fn(() => value),
    in: vi.fn(() => value),
    not: vi.fn(() => value),
    order: vi.fn(() => value),
    limit: vi.fn(async () => ({ data, error: null })),
  };
  return value;
}

describe("franchise operations repository", () => {
  it("ne charge rien hors session", async () => {
    mocks.getUser.mockResolvedValue({ data: { user: null } });
    await expect(loadFranchiseOperations({ libraryId })).resolves.toMatchObject({ requests: [], quotes: [], missions: [] });
    expect(mocks.from).not.toHaveBeenCalled();
  });

  it("agrège les dossiers de la bibliothèque mandatée sans identifiant d’organisation prestataire", async () => {
    mocks.getUser.mockResolvedValue({ data: { user: { id: "11111111-1111-4111-8111-111111111111" } } });
    mocks.from.mockImplementation((table: string) => {
      if (table === "service_requests") return chain([{ id: requestId, status: "MATCHING", service_id: serviceId, library_id: libraryId }]);
      if (table === "catalog_services") return chain([{ id: serviceId, code: "IT_BACKUP" }]);
      if (table === "service_request_versions") return chain([{ request_id: requestId, urgency: "HIGH" }]);
      if (table === "matching_runs") return chain([{ id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", request_id: requestId }]);
      if (table === "matching_candidates") return chain([{ id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc", matching_run_id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", eligible: true, score_basis_points: 4200 }]);
      if (table === "rfqs") return chain([{ id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd", request_id: requestId }]);
      if (table === "quotes") return chain([{ id: "ffffffff-ffff-4fff-8fff-ffffffffffff", status: "SUBMITTED", rfq_id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd" }]);
      if (table === "quote_versions") return chain([{ quote_id: "ffffffff-ffff-4fff-8fff-ffffffffffff", total_minor: "125000", currency: "MAD", version_number: 1 }]);
      if (table === "diagnostic_anomalies") return chain([{ id: "99999999-9999-4999-8999-999999999999", title_fr: "Score critique", title_ar: "درجة حرجة", severity: "HIGH", status: "OPEN", anomaly_code: "HEALTH_SCORE_IMPORTANT", blocking: false }]);
      return chain([]);
    });
    const snapshot = await loadFranchiseOperations({ libraryId });
    expect(snapshot.requests[0]).toMatchObject({ title: "IT_BACKUP", status: "MATCHING", urgency: "HIGH" });
    expect(snapshot.matching[0]).toMatchObject({ eligible: true, scoreBps: 4200, requestId });
    expect(snapshot.quotes[0]).toMatchObject({ totalMinor: "125000", currency: "MAD", requestId });
    expect(snapshot.anomalies[0]?.titleFr).toBe("Score critique");
    expect(snapshot.disputes).toEqual([]);
    expect(snapshot.skus).toEqual([]);
    expect(snapshot.anomalyDefinitions).toEqual([]);
    expect(snapshot.volumeProposals).toEqual([]);
    expect(JSON.stringify(snapshot)).not.toMatch(/Hatim|Jalil-NEOXA|50\s*%/);
  });

  it("projette les définitions et propositions volume de la bibliothèque mandatée", async () => {
    const definitionId = "31313131-3131-4313-8313-313131313131";
    mocks.getUser.mockResolvedValue({ data: { user: { id: "11111111-1111-4111-8111-111111111111" } } });
    mocks.from.mockImplementation((table: string) => {
      if (table === "anomaly_definition_versions") return chain([{ id: "41414141-4141-4414-8414-414141414141", definition_id: definitionId, severity: "CRITICAL", title_fr: "Score critique", title_ar: "درجة حرجة", version: 2 }]);
      if (table === "franchise_volume_proposals") return chain([{ id: "51515151-5151-4515-8515-515151515151", sku_id: serviceId, status: "PROPOSED", payment_model: "PAY_PER_USE" }]);
      if (table === "provider_qualifications") return chain([{ id: "61616161-6161-4616-8616-616161616161", service_id: serviceId, row_version: 3, current_decision_id: null }]);
      return chain([]);
    });
    const snapshot = await loadFranchiseOperations({ libraryId });
    expect(snapshot.anomalyDefinitions).toEqual([expect.objectContaining({ id: definitionId, titleFr: "Score critique", severity: "CRITICAL" })]);
    expect(snapshot.volumeProposals).toEqual([expect.objectContaining({ status: "PROPOSED", paymentModel: "PAY_PER_USE" })]);
    expect(snapshot.qualifications[0]).toMatchObject({ serviceId, status: "PENDING", rowVersion: 3 });
  });
});
