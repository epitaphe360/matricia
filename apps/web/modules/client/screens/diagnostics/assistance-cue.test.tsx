import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AssistanceCue } from "./assistance-cue";

describe("AssistanceCue", () => {
  it("exposes a human confirmation path without claiming an autonomous action", () => {
    const html = renderToStaticMarkup(
      <AssistanceCue locale="fr" href="/fr/client/diagnostics/assistance" proposedCount={2} reassessmentCount={1} context="diagnostic" />,
    );
    expect(html).toContain("Assistance dans ce parcours");
    expect(html).toContain("2");
    expect(html).toContain("proposition");
    expect(html).toContain("changement");
    expect(html).toContain("Aucune proposition n’exécute une action métier");
    expect(html).toContain("/fr/client/diagnostics/assistance");
  });

  it("keeps quote and milestone copy from selecting or accepting on behalf of the client", () => {
    const quotes = renderToStaticMarkup(<AssistanceCue locale="fr" href="/fr/client/diagnostics/assistance" context="quotes" />);
    const jalons = renderToStaticMarkup(<AssistanceCue locale="ar" href="/ar/client/diagnostics/assistance" context="milestone" />);
    expect(quotes).toContain("ne sélectionne aucun devis");
    expect(jalons).toContain("لا تقبل ولا ترفض أي مخرج");
  });
});
