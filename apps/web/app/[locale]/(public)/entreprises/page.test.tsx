import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("next/navigation", () => ({ notFound: vi.fn(() => { throw new Error("NOT_FOUND"); }) }));
vi.mock("@/modules/shared/lib/i18n/locale", async () => await import("@/modules/shared/lib/i18n/locale"));
vi.mock("@/modules/shared/lib/seo/metadata", () => ({ localizedRouteMetadata: () => ({ title: "Entreprises" }) }));

import PublicEntreprisesPage from "./page";

describe("PublicEntreprisesPage", () => {
  it("oriente selon la situation du visiteur", async () => {
    const html = renderToStaticMarkup(await PublicEntreprisesPage({ params: Promise.resolve({ locale: "fr" }) }));
    expect(html).toContain("Où en êtes-vous ?");
    expect(html).toContain('href="/fr/diagnostic"');
    expect(html).toContain('href="/fr/besoin"');
    expect(html).toContain('href="/fr/abonnements"');
    expect(html).toContain('href="/fr/connexion"');
    expect(html).toContain("illustratif");
  });
});
