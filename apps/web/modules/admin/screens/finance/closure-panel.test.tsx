import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
import type { AdminClosureDashboard } from "@/modules/admin/data/closure/model";
import { ClosurePanel } from "./closure-panel";
import { getCommerceMessages } from "./commerce-messages";

vi.mock("./commerce-actions", () => ({
  commerceIdle: { status: "idle" },
  issueStatementAction: async () => ({ status: "idle" }),
}));

const dashboard: AdminClosureDashboard = {
  generated_at: "2026-09-21T12:00:00.000Z",
  capabilities: { can_issue_statement: false },
  unstatemented: [],
  statements: [],
  overdue_invoices: [{
    id: "11111111-1111-4111-8111-111111111111",
    provider_organization_id: "22222222-2222-4222-8222-222222222222",
    organization_name: "Prestataire 167",
    invoice_number: "INV-OVERDUE-167",
    due_on: "2026-09-13",
    currency: "MAD",
    outstanding_minor: "1200",
    blocks_new_opportunities: true,
  }],
};

describe("ClosurePanel overdue hold", () => {
  it("montre que la facture échue bloque les nouvelles consultations", () => {
    const html = renderToStaticMarkup(
      <ClosurePanel locale="fr" dashboard={dashboard} m={getCommerceMessages("fr")} keyValue="key-167" />,
    );
    expect(html).toContain("INV-OVERDUE-167");
    expect(html).toContain("Nouvelles consultations bloquées");
    expect(html).toContain("missions déjà ouvertes");
    expect(html).not.toMatch(/\bTODO\b|\bFIXME\b/);
  });

  it("keeps native Arabic copy for the same hold", () => {
    const html = renderToStaticMarkup(
      <ClosurePanel locale="ar" dashboard={dashboard} m={getCommerceMessages("ar")} keyValue="key-167" />,
    );
    expect(html).toMatch(/[\u0600-\u06ff]/u);
    expect(html).toContain("الاستشارات الجديدة محظورة");
  });
});
