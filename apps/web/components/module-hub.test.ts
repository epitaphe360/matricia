import { describe, expect, it } from "vitest";
import { MODULE_ROUTE_REGISTRY, moduleHubCopy, resolveOrganizationContext, visibleModuleRoutes } from "./module-hub-copy";

describe("module hub registry", () => {
  it("déclare des identifiants et routes uniques avec des libellés FR/AR", () => {
    expect(new Set(MODULE_ROUTE_REGISTRY.map((route) => route.id)).size).toBe(MODULE_ROUTE_REGISTRY.length);
    expect(new Set(MODULE_ROUTE_REGISTRY.map((route) => route.path)).size).toBe(MODULE_ROUTE_REGISTRY.length);
    for (const route of MODULE_ROUTE_REGISTRY) {
      expect(moduleHubCopy.fr.links[route.id]).toBeTruthy();
      expect(moduleHubCopy.ar.links[route.id]).toBeTruthy();
    }
    expect(Object.values(moduleHubCopy.fr.links).join(" ")).not.toMatch(/\b(?:RFQ|Outbox|RLS|snapshot|V4\.1)\b/i);
  });

  it("distingue Documents, Portefeuille, Clonage, Publications, Abus et Opérations", () => {
    const byId = new Map(MODULE_ROUTE_REGISTRY.map((route) => [route.id, route.path]));
    expect(byId.get("client-documents")).not.toBe(byId.get("client-portfolio"));
    expect(byId.get("admin-cloning")).not.toBe(byId.get("admin-catalogue-publications"));
    expect(byId.get("admin-abuse")).not.toBe(byId.get("admin-operations"));
  });

  it("filtre les espaces selon les rôles", () => {
    const client = visibleModuleRoutes({ membershipCount: 1, membershipRoles: new Set(["CLIENT_VIEWER"]), platformRoles: new Set() });
    expect(client.map((route) => route.id)).toContain("client-home");
    expect(client.map((route) => route.id)).not.toContain("admin-command");
    const auditor = visibleModuleRoutes({ membershipCount: 0, membershipRoles: new Set(), platformRoles: new Set(["READ_ONLY_AUDITOR"]) });
    expect(auditor.map((route) => route.id)).toContain("admin-command");
    expect(auditor.map((route) => route.id)).not.toContain("client-requests");
  });

  it("rejette une organisation injectée et ne sélectionne qu’une adhésion autorisée", () => {
    const memberships = [
      { membershipId: "membership-a", organizationId: "organization-a" },
      { membershipId: "membership-b", organizationId: "organization-b" },
    ];
    expect(resolveOrganizationContext(memberships, "organization-b")).toEqual({ selected: memberships[1], rejected: false });
    expect(resolveOrganizationContext(memberships, "organization-attacker")).toEqual({ selected: memberships[0], rejected: true });
  });

  it("n’additionne pas les rôles de deux organisations", () => {
    const organizationA = visibleModuleRoutes({ membershipCount: 1, membershipRoles: new Set(["CLIENT_VIEWER"]), platformRoles: new Set() });
    const organizationB = visibleModuleRoutes({ membershipCount: 1, membershipRoles: new Set(["PROVIDER_VIEWER"]), platformRoles: new Set() });
    expect(organizationA.some((route) => route.space === "provider")).toBe(false);
    expect(organizationB.some((route) => route.space === "client")).toBe(false);
  });
});
