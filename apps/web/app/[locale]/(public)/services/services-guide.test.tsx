import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("next/link", () => ({ default: ({ children, href, ...props }: React.ComponentPropsWithoutRef<"a"> & { href: string }) => <a href={href} {...props}>{children}</a> }));
vi.mock("@/modules/public/data/provider-intent/messages", async () => await import("@/modules/public/data/provider-intent/messages"));

import { ServicesGuide } from "./services-guide";

const libraries = [{ code: "IT", name: "Informatique", categories: [{ code: "IT-GOV", name: "Gouvernance SI", services: [{ code: "IT-AUDIT-SI", libraryCode: "IT", name: "Audit du SI", description: "Diagnostic et feuille de route" }] }] }];

describe("ServicesGuide", () => {
  it("transporte les identifiants structurés vers le parcours besoin", () => {
    const html = renderToStaticMarkup(<ServicesGuide locale="fr" libraries={libraries} initialQuery="" initialLibrary="IT"/>);
    expect(html).toContain("Audit du SI");
    expect(html).toContain("serviceCode=IT-AUDIT-SI");
    expect(html).toContain("library=IT");
    expect(html).not.toContain("Acheter");
  });

  it("préserve une ancienne recherche et rend le parcours arabe RTL", () => {
    const html = renderToStaticMarkup(<ServicesGuide locale="ar" libraries={libraries} initialQuery="Audit" initialLibrary="IT"/>);
    expect(html).toContain('dir="rtl"');
    expect(html).toContain('value="Audit"');
    expect(html).toContain("q=Audit");
    expect(html).toContain("الخدمات المطابقة");
  });
});

