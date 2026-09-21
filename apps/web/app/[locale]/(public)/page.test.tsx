import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("next/navigation", () => ({ notFound: vi.fn(() => { throw new Error("NOT_FOUND"); }) }));
vi.mock("@/modules/shared/lib/i18n/locale", async () => await import("@/modules/shared/lib/i18n/locale"));
vi.mock("@/modules/public/data/journey/copy", async () => await import("@/modules/public/data/journey/copy"));

import PublicHomePage from "./page";

describe("PublicHomePage", () => {
  it("présente les trois intentions, sept étapes et l’exemple illustratif en français", async () => {
    const html = renderToStaticMarkup(await PublicHomePage({ params: Promise.resolve({ locale: "fr" }) }));
    for (const label of ["Comprendre", "Structurer", "Matcher", "Comparer", "Contractualiser", "Exécuter", "Suivre"]) expect(html).toContain(label);
    expect(html).toContain("Découvrez ce qui freine votre entreprise.");
    expect(html).toContain("Passez aux bonnes solutions.");
    expect(html).toContain('href="/fr/diagnostic"');
    expect(html).toContain('href="/fr/fournisseur"');
    expect(html).toContain('href="/fr/besoin"');
    expect(html).toContain("Exemple illustratif");
    expect(html).toContain("is-coral");
    expect(html).toContain("De la réflexion à l’impact");
    expect(html).toContain("/scenes/arch-city.png");
    expect(html).not.toContain("200 services");
    expect((html.match(/<section/g) ?? []).length).toBeGreaterThanOrEqual(4);
    expect(html).toContain("Organisation interne");
    expect(html).toContain("journey-outcomes-board");
    expect(html).toContain("journey-faq-board");
  });

  it("présente le même parcours, la photo RTL et les routes localisées en arabe", async () => {
    const html = renderToStaticMarkup(await PublicHomePage({ params: Promise.resolve({ locale: "ar" }) }));
    for (const label of ["الفهم", "الهيكلة", "المطابقة", "المقارنة", "التعاقد", "التنفيذ", "المتابعة"]) expect(html).toContain(label);
    expect(html).toContain('href="/ar/diagnostic"');
    expect(html).toContain("rtl-mirror");
    expect(html).toContain("اكتشفوا ما يبطئ شركتكم");
    expect(html).toContain("دورة ماتريسيا في سبع خطوات");
    expect(html).toContain("تنفيذ أسرع من التشخيص إلى الإنجاز");
    expect(html).toContain("is-coral");
    expect(html).toContain("/scenes/window-medina.png");
  });
});
