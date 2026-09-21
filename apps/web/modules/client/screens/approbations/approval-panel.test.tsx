import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { ClientApprovalsPanel } from "./approval-panel";
import { getApprovalMessages } from "./messages";

describe("ClientApprovalsPanel", () => {
  it("shows an empty state without inventing a pending approval", () => {
    const html = renderToStaticMarkup(<ClientApprovalsPanel locale="fr" items={[]} messages={getApprovalMessages("fr")} />);
    expect(html).toContain("Aucune demande d’approbation");
    expect(html).not.toContain("name=\"decision\"");
  });

  it("exposes a human decision on pending requests", () => {
    const html = renderToStaticMarkup(
      <ClientApprovalsPanel
        locale="fr"
        items={[{
          id: "11111111-1111-4111-8111-111111111111",
          status: "PENDING",
          rowVersion: 1,
          resourceType: "QUOTE",
          resourceId: "22222222-2222-4222-8222-222222222222",
          amountMinor: "10000",
          currency: "MAD",
          requestedAt: "2026-09-21T10:00:00.000Z",
        }]}
        messages={getApprovalMessages("fr")}
      />,
    );
    expect(html).toContain("QUOTE");
    expect(html).toContain("name=\"decision\"");
    expect(html).toContain("AAL2");
  });
});
