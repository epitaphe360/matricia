import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("next/link", () => ({ default: ({ children, href, ...props }: React.ComponentPropsWithoutRef<"a"> & { href: string }) => <a href={href} {...props}>{children}</a> }));
vi.mock("@/modules/public/data/provider-intent/model", async () => await import("@/modules/public/data/provider-intent/model"));
vi.mock("@/modules/public/data/provider-intent/messages", async () => await import("@/modules/public/data/provider-intent/messages"));

import { ProviderTaxonomySelector } from "./provider-taxonomy-selector";

const libraries = [{ code: "IT", name: "Informatique", categories: [{ code: "IT-GOV", name: "Gouvernance SI", services: [{ code: "IT-AUDIT-SI", libraryCode: "IT", name: "Audit du SI", description: "Diagnostic et feuille de route" }] }] }];

describe("ProviderTaxonomySelector", () => {
  it("expose une sélection structurée et les deux parcours d’authentification", () => {
    const html = renderToStaticMarkup(<ProviderTaxonomySelector locale="fr" libraries={libraries}/>);
    expect(html).toContain("Quels services proposez-vous");
    expect(html).toContain('type="checkbox"');
    expect(html).toContain("Audit du SI");
    expect(html).toContain("Gouvernance SI");
    expect(html).toContain("mode=inscription&amp;role=fournisseur&amp;next=");
    expect(html).toContain("connexion?next=");
    expect(html).toContain('aria-disabled="true"');
  });

  it("rend les instructions arabes dans un conteneur RTL sans largeur fixe", () => {
    const html = renderToStaticMarkup(<div dir="rtl" lang="ar"><ProviderTaxonomySelector locale="ar" libraries={libraries}/></div>);
    expect(html).toContain('dir="rtl"');
    expect(html).toContain("ما الخدمات التي تقدمها؟");
    expect(html).not.toMatch(/(?:min-w|max-w|w)-\[(?:[4-9]\d\d|\d{4,})px\]/);
  });

  it("laisse le fieldset et le sélecteur de domaines rétrécir sans élargir la page", () => {
    const html = renderToStaticMarkup(<ProviderTaxonomySelector locale="fr" libraries={libraries}/>);
    expect(html).toContain('<fieldset class="mt-5 min-w-0">');
    expect(html).toContain('class="mt-2 flex max-w-full gap-2 overflow-x-auto pb-2"');
    expect(html).not.toContain("overflow-x-hidden");
  });
});
