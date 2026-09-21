import { describe, expect, it } from "vitest";
import { consultationRowsFromInvitations, filterInvitationsByConsultTab, filterInvitationsByQuoteTab, filterListRows, quoteRowsFromInvitations } from "./list-rows";

const id = (value: number) => `${String(value).padStart(8, "0")}-0000-4000-8000-000000000000`;

const invitation = {
  id: id(1),
  status: "ACCEPTED" as const,
  rowVersion: 1,
  rfqId: id(2),
  deadline: "2027-01-15T12:00:00.000Z",
  requestId: id(3),
  description: "Lot CVC Rabat",
  regionCode: "RABAT",
  currency: "MAD",
  taxCategoryCode: null,
  quote: { id: id(4), status: "DRAFT", currentVersionId: id(5), versionNumber: 1, currency: "MAD", subtotalMinor: "100", taxMinor: "20", totalMinor: "120" },
};

describe("provider list rows", () => {
  it("ouvre les invitations et devis réels sans identifiants de démo", () => {
    const consultations = consultationRowsFromInvitations([invitation], "fr", "");
    const quotes = quoteRowsFromInvitations([invitation], "fr", "");
    expect(consultations[0]?.href).toContain(`/sous-traitant/consultations/${invitation.id}`);
    expect(quotes[0]?.href).toContain(`/sous-traitant/devis/${invitation.quote!.id}`);
    expect(filterListRows(consultations, "cvc")[0]?.title).toBe("Lot CVC Rabat");
    expect(filterListRows(consultations, "casablanca")).toEqual([]);
  });

  it("filtre les onglets consultation et devis sans inventer de dossiers", () => {
    expect(filterInvitationsByConsultTab([invitation], "preparing")).toHaveLength(1);
    expect(filterInvitationsByConsultTab([invitation], "answer")).toHaveLength(0);
    expect(quoteRowsFromInvitations(filterInvitationsByQuoteTab([invitation], "drafts") as typeof invitation[], "fr", "")).toHaveLength(1);
    expect(quoteRowsFromInvitations(filterInvitationsByQuoteTab([invitation], "submitted") as typeof invitation[], "fr", "")).toHaveLength(0);
  });
});
