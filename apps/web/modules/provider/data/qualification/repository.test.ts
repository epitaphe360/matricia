import { describe, expect, it, vi } from "vitest";

vi.mock("@/modules/shared/lib/supabase/server", () => ({ getSupabaseServerClient: vi.fn() }));

import { diagnoseProviderDashboardProjection, diagnoseProviderServiceLabelCoverage } from "./repository";

const organizationId = "11111111-1111-4111-8111-111111111111";
const serviceId = "22222222-2222-4222-8222-222222222222";
const providerServiceId = "33333333-3333-4333-8333-333333333333";
const qualificationId = "44444444-4444-4444-8444-444444444444";
const versionId = "55555555-5555-4555-8555-555555555555";

const fixtureProjection = {
  profile: {
    company_status: "VERIFIED", overall_status: "ACTIVE", activity_summary: "Prestation de qualification E2E contrôlée",
    team_size: 4, years_experience: 6, secondary_subcontracting_allowed: false, accounting_contact_email: null,
    partner_contract_status: "SIGNED", row_version: 1,
  },
  services: [{
    id: providerServiceId, service_id: serviceId, request_status: "DECIDED", catalog_services: { code: "E2E_SERVICE" },
    provider_qualifications: [{ id: qualificationId, provider_qualification_decisions: { status: "APPROVED" } }],
    provider_capacity_versions: [],
  }],
  documents: [{
    id: versionId, version_number: 1, status: "VERIFIED", expires_on: null,
    provider_document_families: { document_kind: "LEGAL", code: "E2E_LEGAL" },
  }],
  catalog: [{
    id: serviceId, code: "E2E_SERVICE", library_id: organizationId, primary_subcategory_id: providerServiceId,
    current_published_version_id: versionId,
  }],
};

describe("provider dashboard projection diagnostics", () => {
  it("accepts the fully qualified MAT-FUNC-020 fixture before capacity is declared", () => {
    expect(diagnoseProviderDashboardProjection(fixtureProjection)).toBeNull();
    expect(diagnoseProviderServiceLabelCoverage([serviceId], new Set([serviceId]))).toBeNull();
  });

  it("reports the exact safe projection boundary instead of leaking response content", () => {
    expect(diagnoseProviderDashboardProjection({ ...fixtureProjection, services: [{ ...fixtureProjection.services[0], provider_capacity_versions: [{ capacity_status: "AVAILABLE", available_units: "8", lead_time_days: 3 }] }] })).toBe("SERVICES_SHAPE_INVALID");
    expect(diagnoseProviderServiceLabelCoverage([serviceId], new Set())).toBe("PROVIDER_SERVICE_LABEL_MISSING");
  });
});
