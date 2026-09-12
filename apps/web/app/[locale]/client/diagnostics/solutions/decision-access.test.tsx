import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("./decision-form", () => ({
  DecisionForm: () => <form><button type="submit">submit</button></form>,
}));

import { SolutionDecisionAccess } from "./decision-access";
import { messages } from "./messages";

const props = {
  locale: "fr" as const,
  solutionSetId: "11111111-1111-4111-8111-111111111111",
  level: "ESSENTIAL" as const,
  idempotencyKey: "decision-command-123",
  messages: messages("fr"),
};

describe("SolutionDecisionAccess", () => {
  it("ne rend aucune mutation pour un CLIENT_VIEWER", () => {
    const html = renderToStaticMarkup(<SolutionDecisionAccess {...props} canDecide={false} />);
    expect(html).toContain("Consultation uniquement");
    expect(html).not.toContain("<form");
    expect(html).toContain('role="status"');
  });

  it("rend la décision pour un rôle client autorisé", () => {
    const html = renderToStaticMarkup(<SolutionDecisionAccess {...props} canDecide />);
    expect(html).toContain("<form");
  });
});
