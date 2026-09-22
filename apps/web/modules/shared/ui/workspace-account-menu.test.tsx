import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("@/modules/shared/lib/account-security/sign-out-action", () => ({ signOutOfWorkspace: vi.fn() }));

import { WorkspaceAccountMenu } from "./workspace-account-menu";

describe("menu de compte des espaces connectés", () => {
  it("offre la déconnexion et le retour de secours en français", () => {
    const html = renderToStaticMarkup(
      <WorkspaceAccountMenu
        locale="fr"
        userEmail="demo.admin@matricia.test"
        returnTo="/fr/administration/command-center"
        fallbackInitial="A"
        label="Administration"
      />,
    );
    expect(html).toContain("Se déconnecter");
    expect(html).toContain("demo.admin@matricia.test");
    expect(html).toContain('name="returnTo" value="/fr/administration/command-center"');
    expect(html).toContain('name="locale" value="fr"');
    expect(html).toContain('href="/fr/securite/sessions"');
  });

  it("traduit la déconnexion en arabe", () => {
    const html = renderToStaticMarkup(
      <WorkspaceAccountMenu
        locale="ar"
        userEmail={null}
        returnTo="/ar/franchise/accueil"
        fallbackInitial="F"
        label="الحساب"
      />,
    );
    expect(html).toContain("تسجيل الخروج");
    expect(html).toContain('name="returnTo" value="/ar/franchise/accueil"');
  });

  it("affiche le libellé nommé du chrome client", () => {
    const html = renderToStaticMarkup(
      <WorkspaceAccountMenu
        locale="fr"
        userEmail="client@example.invalid"
        returnTo="/fr/tableau-de-bord"
        fallbackInitial="C"
        label="Mon compte"
        displayName="Espace client"
        className="client-account client-account-named"
      />,
    );
    expect(html).toContain("client-account-named");
    expect(html).toContain("client-account-avatar");
    expect(html).toContain("Espace client");
    expect(html).toContain("C");
  });
});
