import { describe, expect, it } from "vitest";
import { supervisionChartSeries } from "./series";
import type { AdminSupervisionDashboard } from "./types";

const sample: AdminSupervisionDashboard = {
  as_of: "2026-09-16T12:00:00Z",
  read_only: false,
  organizations: [
    { id: "11111111-1111-4111-8111-111111111111", display_name: "A", legal_name: "A SA", status: "ACTIVE", created_at: "2026-09-01T00:00:00Z", member_count: 2, open_requests: 1, open_disputes: 1 },
  ],
  requests: [
    { id: "22222222-2222-4222-8222-222222222222", organization_id: "11111111-1111-4111-8111-111111111111", organization_name: "A", status: "OPEN", library_id: "33333333-3333-4333-8333-333333333333", service_id: "44444444-4444-4444-8444-444444444444", created_at: "2026-09-10T00:00:00Z", matching_runs: 1, rfq_count: 1, quote_count: 2 },
    { id: "55555555-5555-4555-8555-555555555555", organization_id: "11111111-1111-4111-8111-111111111111", organization_name: "A", status: "OPEN", library_id: "33333333-3333-4333-8333-333333333333", service_id: "44444444-4444-4444-8444-444444444444", created_at: "2026-09-11T00:00:00Z", matching_runs: 0, rfq_count: 0, quote_count: 0 },
  ],
  quotes: [
    { id: "66666666-6666-4666-8666-666666666666", rfq_id: "77777777-7777-4777-8777-777777777777", request_id: "22222222-2222-4222-8222-222222222222", provider_organization_id: "88888888-8888-4888-8888-888888888888", provider_name: "P", client_name: "A", status: "SUBMITTED", updated_at: "2026-09-12T00:00:00Z" },
  ],
  missions: [
    { id: "99999999-9999-4999-8999-999999999999", contract_id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", status: "ACTIVE", client_organization_id: "11111111-1111-4111-8111-111111111111", provider_organization_id: "88888888-8888-4888-8888-888888888888", client_name: "A", provider_name: "P", updated_at: "2026-09-13T00:00:00Z", milestone_count: 3, deliverable_count: 2 },
  ],
  diagnostics: [],
  work_enrichment: {},
  matching: [],
  contracts: [],
  amendments: [],
  documents: [],
  messages: [],
  exceptions: [],
  templates: [],
};

describe("supervisionChartSeries", () => {
  it("agrège les compteurs colorés du parcours", () => {
    const series = supervisionChartSeries(sample);
    expect(series.totals.organizations).toBe(1);
    expect(series.totals.requests).toBe(2);
    expect(series.totals.blocked).toBe(1);
    expect(series.requests.find((item) => item.name === "OPEN")?.value).toBe(2);
    expect(series.missions[0]?.name).toBe("ACTIVE");
  });
});
