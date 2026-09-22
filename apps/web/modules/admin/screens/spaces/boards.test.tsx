import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AdminDirectoryBoard, OrganizationFicheBoard, OrganizationsBoard } from "./boards";

const row = {
  id: "11111111-1111-4111-8111-111111111111",
  name: "Client · Communication",
  legalName: "Client Communication SARL",
  type: "Client",
  status: "Active",
  statusTone: "mint" as const,
  compliance: "À jour",
  complianceTone: "mint" as const,
  plan: "Non affiché",
  lastAction: "Demande ouverte",
};

const fiche = {
  organization: {
    id: row.id,
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

describe("admin space boards", () => {
  it("compose l’annuaire, la liste et la fiche sans exemple illustratif", () => {
    const html = [
      renderToStaticMarkup(<AdminDirectoryBoard locale="fr" query="" />),
      renderToStaticMarkup(<OrganizationsBoard locale="fr" query="" rows={[row]} treat={[{ id: "t1", title: "Client · Communication", detail: "Demande ouverte", href: "/fr/administration/entreprises", tone: "sky" }]} />),
      renderToStaticMarkup(<OrganizationFicheBoard locale="fr" query="" fiche={fiche} />),
    ].join("\n");
    expect(html).toContain("Acteurs &amp; accès");
    expect(html).toContain("Actions sensibles");
    expect(html).toContain("Toutes les pages d’administration");
    expect(html).toContain("Créer");
    expect(html).toContain("Archiver / restaurer");
    expect(html).toContain("Client · Communication");
    expect(html).toContain("Studio Atlas");
    expect(html).toContain("Aucune suppression définitive");
    expect(html).toContain("À traiter");
    expect(html).toContain('data-tone="amber"');
    expect(html).toContain('data-tone="plum"');
    expect(html).not.toMatch(/exemple illustratif/i);
  });
});
