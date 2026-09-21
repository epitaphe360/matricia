import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { ClientFicheBoard, ClientsBoard, ComplianceBoard, ComplianceDecisionBoard } from "./actor-boards";

const orgId = "11111111-1111-4111-8111-111111111111";
const caseId = "77777777-7777-4777-8777-777777777777";

const organization = {
  id: orgId,
  display_name: "Studio Atlas",
  legal_name: "Studio Atlas SARL",
  status: "ACTIVE",
  created_at: "2026-09-01T10:00:00.000Z",
  member_count: 2,
  open_requests: 1,
  open_disputes: 0,
};

const fiche = {
  organization: {
    id: orgId,
    display_name: "Studio Atlas",
    legal_name: "Studio Atlas SARL",
    status: "ACTIVE",
    country_code: "MA",
    created_at: "2026-09-01T10:00:00.000Z",
    updated_at: "2026-09-18T10:00:00.000Z",
  },
  memberships: [{ id: "22222222-2222-4222-8222-222222222222", user_id: "33333333-3333-4333-8333-333333333333", status: "ACTIVE", roles: ["CLIENT_OWNER"] }],
  requests: [{ id: "44444444-4444-4444-8444-444444444444", status: "OPEN", created_at: "2026-09-18T10:00:00.000Z", service_id: "55555555-5555-4555-8555-555555555555" }],
  missions: [],
  disputes: [],
  diagnostics: [],
  subscriptions: [{ id: "66666666-6666-4666-8666-666666666666", status: "TRIAL", plan_version_id: null, current_period_end: null }],
  timeline: [{ at: "2026-09-18T10:00:00.000Z", kind: "REQUEST", label: "Demande ouverte", ref: "r1" }],
};

const complianceCase = {
  id: caseId,
  organizationName: "Studio Atlas",
  status: "UNDER_REVIEW" as const,
  profileVersion: 1,
  submittedAt: "2026-09-18T10:00:00.000Z",
  publicReason: null,
  createdAt: "2026-09-10T10:00:00.000Z",
  updatedAt: "2026-09-18T10:00:00.000Z",
  evidence: [{ type: "REGISTRATION_DOCUMENT" as const, status: "VERIFIED" as const }],
  anomalies: [],
  questions: [],
};

describe("admin actor boards", () => {
  it("compose clients, conformité et fiches sans exemple illustratif", () => {
    const html = [
      renderToStaticMarkup(<ClientsBoard locale="fr" query="" organizations={[organization]} cases={[]} diagnostics={[]} />),
      renderToStaticMarkup(<ClientFicheBoard locale="fr" query="" fiche={fiche} />),
      renderToStaticMarkup(<ComplianceBoard locale="fr" query="" cases={[complianceCase]} />),
      renderToStaticMarkup(<ComplianceDecisionBoard locale="fr" query="" item={complianceCase} form={<p>Formulaire réel</p>} />),
    ].join("\n");
    expect(html).toContain("Studio Atlas");
    expect(html).toContain("Parcours client");
    expect(html).toContain("Décision de conformité client");
    expect(html).toContain("/fr/administration/clients/" + orgId);
    expect(html).toContain("/fr/administration/conformite-clients/" + caseId);
    expect(html).toContain("/fr/administration/entreprises/" + orgId + "/modifier");
    expect(html).not.toMatch(/exemple illustratif/i);
  });
});
