import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { clientDashboardCopy } from "@/modules/client/data/home/copy";

const mockupDir = join(process.cwd(), "..", "..", "docs", "design", "client-dashboard-mockups");

describe("client dashboard mockups", () => {
  it("référence les PNG attendus et la navigation documentée", () => {
    const nav = readFileSync(join(mockupDir, "NAVIGATION.md"), "utf8");
    expect(nav).toContain("/client/diagnostics");
    expect(nav).toContain("/client/recompenses");
    expect(readFileSync(join(mockupDir, "00-accueil-client.png"))).toBeDefined();
  });

  it("aligne les libellés de navigation sur les maquettes", () => {
    expect(clientDashboardCopy.fr.navNeeds).toBe("Bilan & besoins");
    expect(clientDashboardCopy.fr.navRewards).toBe("Récompenses");
    expect(clientDashboardCopy.fr.helloBonjour).toBe("Bonjour");
    expect(clientDashboardCopy.fr.projectProgress).toBe("L’avancement de vos projets");
    expect(clientDashboardCopy.fr.compareWhatMatters).toBe("Comparer ce qui compte");
    expect(clientDashboardCopy.fr.unreadMessages).toBe("Messages non lus");
    expect(clientDashboardCopy.fr.nextMilestone).toBe("Prochain jalon");
  });
});
