import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { getPublicJourneyCopy } from "@/modules/public/data/journey/copy";
import { HonestStatesView, RecoveryStatesView } from "./prediagnostic-phases";

describe("états publics du prédiagnostic", () => {
  it("n’affiche qu’un constat réel quand aucune priorité n’est détectée", () => {
    const html = renderToStaticMarkup(<HonestStatesView locale="fr" onEdit={() => undefined} onAssist={() => undefined} />);
    expect(html).toContain("Aucune priorité majeure détectée");
    expect(html.match(/<h2/g)?.length).toBe(1);
    expect(html).not.toContain("92%");
    expect(html).not.toContain("44 / 48");
    expect(html).not.toContain("83%");
  });

  it("n’affiche pas trois pannes fictives quand le stockage local échoue", () => {
    const html = renderToStaticMarkup(<RecoveryStatesView locale="fr" onRetry={() => undefined} onContinue={() => undefined} onReconnect={() => undefined} />);
    expect(html).toContain("n’a pas pu être conservé");
    expect(html.match(/<h2/g)?.length).toBe(1);
    expect(html).not.toContain("Mise à jour disponible");
    expect(html).not.toContain("Session expirée");
  });

  it("propose uniquement les secteurs que le contrat d’enregistrement accepte", () => {
    const sectors = getPublicJourneyCopy("fr").diagnostic.questions[0]?.[2] ?? [];
    const arabic = getPublicJourneyCopy("ar").diagnostic.questions[0]?.[2] ?? [];
    expect(sectors).toEqual(["Industrie & production", "Commerce & distribution", "Services & conseil", "BTP, immobilier & aménagement", "Autre activité"]);
    expect(arabic).toHaveLength(sectors.length);
    expect(String(sectors)).not.toContain("Santé");
  });
});
