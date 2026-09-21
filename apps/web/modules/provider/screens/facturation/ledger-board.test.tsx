import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
import type { BillingDashboard } from "@/modules/provider/data/billing/model";
import { ProviderLedgerBoard } from "./ledger-board";

vi.mock("./actions", () => ({
  requestPaymentPlan: async () => ({ status: "idle" }),
}));

const dashboard: BillingDashboard = {
  organizationId: "11111111-1111-4111-8111-111111111111",
  organizationName: "Atlas",
  payables: [{ id: "p1", occurredOn: "2026-09-01", eventType: "COMMISSION_ACCRUAL", currency: "MAD", totalDueMinor: "125050" }],
  statements: [{ id: "s1", number: "REL-1", periodStart: "2026-09-01", periodEnd: "2026-09-30", currency: "MAD", totalMinor: "125050" }],
  invoices: [{ id: "i1", number: "F-1", currency: "MAD", totalMinor: "125050", paidMinor: "0", outstandingMinor: "125050", creditedMinor: "0", paymentStatus: "ISSUED", dueOn: "2026-10-15" }],
  payments: [],
  allocations: [],
  accounts: [],
  creditNotes: [],
  paymentPlans: [],
};

describe("provider ledger boards", () => {
  it("affiche le pré-relevé depuis les payables serveur", () => {
    const html = renderToStaticMarkup(<ProviderLedgerBoard locale="fr" query="" kind="pre-releve" dashboard={dashboard} />);
    expect(html).toContain("Pré-relevé Matricia");
    expect(html).toContain("Commission à constater");
    expect(html).toContain("1");
    expect(html).not.toContain("77500");
  });

  it("laisse le tableau vide sans inventer de reçu", () => {
    const html = renderToStaticMarkup(<ProviderLedgerBoard locale="fr" query="" kind="commissions" dashboard={dashboard} receipts={[]} />);
    expect(html).toContain("Historique des commissions");
    expect(html).toContain("Aucune donnée enregistrée.");
  });

  it("propose un échéancier sans inventer de dates", () => {
    const html = renderToStaticMarkup(<ProviderLedgerBoard locale="fr" query="" kind="echeancier" dashboard={dashboard} planKey="11111111-1111-4111-8111-111111111111" />);
    expect(html).toContain("Demander un échéancier");
    expect(html).toContain("Deux échéances après aujourd’hui");
    expect(html).not.toMatch(/\bTODO\b|\bFIXME\b/);
  });
});
