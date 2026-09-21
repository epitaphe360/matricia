import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

let currentPathname = "/fr";
vi.mock("next/navigation", () => ({ usePathname: () => currentPathname }));
vi.mock("@/modules/shared/ui/button", () => ({ buttonVariants: () => "button" }));
vi.mock("@/modules/shared/lib/utils", () => ({ cn: (...values: Array<string | undefined>) => values.filter(Boolean).join(" ") }));
vi.mock("@/modules/public/data/journey/copy", async () => await import("@/modules/public/data/journey/copy"));

import { isPublicNavLinkActive, nextMenuFocusIndex, PublicNavigation } from "./public-navigation";

describe("PublicNavigation", () => {
  it("expose Comment ça marche, Professionnels, Franchise, Abonnements et À propos", () => {
    currentPathname = "/fr/fournisseur";
    const html = renderToStaticMarkup(<PublicNavigation locale="fr" />);
    expect(html).toContain("Comment ça marche");
    expect(html).toContain("Professionnels");
    expect(html).toContain("Abonnements");
    expect(html).toContain("Franchise");
    expect(html).toContain("À propos");
    expect(html).toContain("Créer un compte");
    expect(html).toContain('href="/fr/inscription"');
    expect(html).toContain("Se connecter");
    expect(html).toMatch(/aria-current="page"[^>]+href="\/fr\/fournisseur"/u);
    expect(html).toContain('aria-label="Ouvrir le menu"');
    expect(html).toContain("premium-nav-account");
    expect(html).toContain("premium-mobile-cluster");
    expect(html).not.toContain(">Fournisseurs<");
  });

  it("rend la navigation arabe en RTL et conserve les destinations localisées", () => {
    currentPathname = "/ar/fournisseur";
    const html = renderToStaticMarkup(<PublicNavigation locale="ar" />);
    expect(html).toContain('dir="rtl"');
    expect(html).toContain("المهنيون");
    expect(html).toContain("الاشتراكات");
    expect(html).toMatch(/aria-current="page"[^>]+href="\/ar\/fournisseur"/u);
    expect(html).toContain("rtl-mirror");
  });

  it("résout strictement les routes actives", () => {
    expect(isPublicNavLinkActive("/fr/services/IT-001", "/fr/services")).toBe(true);
    expect(isPublicNavLinkActive("/fr/fournisseur", "/fr/services")).toBe(false);
    expect(isPublicNavLinkActive("/fr", "/fr#comment-ca-marche")).toBe(true);
    expect(isPublicNavLinkActive("/franchise", "/fr")).toBe(false);
  });

  it("boucle le focus clavier dans les deux directions", () => {
    expect(nextMenuFocusIndex(-1, 4, false)).toBe(0);
    expect(nextMenuFocusIndex(-1, 4, true)).toBe(3);
    expect(nextMenuFocusIndex(3, 4, false)).toBe(0);
    expect(nextMenuFocusIndex(0, 4, true)).toBe(3);
    expect(nextMenuFocusIndex(0, 0, false)).toBeNull();
  });

  it("expose les destinations footer-critiques via la navigation principale", () => {
    currentPathname = "/fr";
    const html = renderToStaticMarkup(<PublicNavigation locale="fr" />);
    expect(html).toContain('href="/fr/abonnements"');
    expect(html).toContain('href="/fr/franchise"');
    expect(html).toContain('href="/fr/a-propos"');
    expect(html).toContain("#comment-ca-marche");
  });
});
