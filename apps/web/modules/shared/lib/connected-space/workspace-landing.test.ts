import { describe, expect, it } from "vitest";
import { resolveWorkspaceLanding, workspaceLandingPath } from "./workspace-landing";

describe("atterrissage après connexion", () => {
  it("envoie un administrateur sans organisation vers l’administration", () => {
    expect(resolveWorkspaceLanding({ membershipRoleCodes: [], platformRoleCodes: ["MATRICIA_ADMIN"] })).toBe("administration");
    expect(resolveWorkspaceLanding({ membershipRoleCodes: [], platformRoleCodes: ["READ_ONLY_AUDITOR"] })).toBe("administration");
  });

  it("garde l’espace de l’organisation quand l’administrateur y est aussi membre", () => {
    expect(resolveWorkspaceLanding({ membershipRoleCodes: ["CLIENT_OWNER"], platformRoleCodes: ["SUPER_ADMIN"] })).toBe("client");
  });

  it("dirige les rôles franchise et sous-traitant vers leur propre espace", () => {
    expect(resolveWorkspaceLanding({ membershipRoleCodes: ["FRANCHISE_OWNER"], platformRoleCodes: [] })).toBe("franchise");
    expect(resolveWorkspaceLanding({ membershipRoleCodes: ["PROVIDER_OWNER"], platformRoleCodes: [] })).toBe("provider");
  });

  it("reste sur l’espace client quand aucun rôle ne qualifie", () => {
    expect(resolveWorkspaceLanding({ membershipRoleCodes: [], platformRoleCodes: [] })).toBe("client");
  });

  it("construit les chemins localisés de chaque espace", () => {
    expect(workspaceLandingPath("fr", "administration")).toBe("/fr/administration/command-center");
    expect(workspaceLandingPath("ar", "franchise", "?organizationId=abc")).toBe("/ar/franchise/accueil?organizationId=abc");
    expect(workspaceLandingPath("fr", "provider")).toBe("/fr/tableau-de-bord");
  });
});
