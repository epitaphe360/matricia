import type { ReactNode } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("next/link", () => ({
  default: ({ children, href, ...props }: { children?: ReactNode; href: string }) => <a href={href} {...props}>{children}</a>,
}));

import { AdminModuleChrome } from "./admin-module-chrome";

describe("AdminModuleChrome", () => {
  it("pose le shell forêt/or et le bandeau d’état en FR et AR", () => {
    const fr = renderToStaticMarkup(
      <AdminModuleChrome
        locale="fr"
        title="Clients"
        eyebrow="Administration"
        lead="Dossiers"
        backHref="/fr/administration/command-center"
        backLabel="Retour"
        languageHref="/ar/administration/clients"
        languageLabel="العربية"
        owner="Conformité"
        nextAction="Décider"
        steps={[{ id: "review", label: "Revue", state: "current" }]}
      >
        <p>liste</p>
      </AdminModuleChrome>,
    );
    expect(fr).toContain("admin-shell");
    expect(fr).toContain("Clients");
    expect(fr).toContain("liste");
    expect(fr).not.toContain("bg-muted/40");

    const ar = renderToStaticMarkup(
      <AdminModuleChrome
        locale="ar"
        title="العملاء"
        eyebrow="إدارة"
        lead="الملفات"
        backHref="/ar/administration/command-center"
        backLabel="عودة"
        languageHref="/fr/administration/clients"
        languageLabel="Français"
        owner="الامتثال"
        nextAction="قرر"
        steps={[{ id: "review", label: "مراجعة", state: "current" }]}
      >
        <p>قائمة</p>
      </AdminModuleChrome>,
    );
    expect(ar).toContain('dir="rtl"');
    expect(ar).toContain("العملاء");
    expect(ar).toContain("قائمة");
  });
});
