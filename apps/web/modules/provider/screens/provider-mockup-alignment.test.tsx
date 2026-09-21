import { readFileSync } from "node:fs";
import { join } from "node:path";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { providerDashboardCopy } from "@/modules/provider/data/home/copy";
import { demoProviderSpaces } from "@/modules/provider/data/spaces/demo";
import { providerWorkbenchCopy } from "@/modules/provider/data/spaces/workbench-copy";
import { buildProviderNav } from "@/modules/provider/ui/provider-nav";
import { ConsultationsBoard, QuotesBoard } from "@/modules/provider/screens/spaces/boards";

const mockupDir = join(process.cwd(), "..", "..", "docs", "design", "provider-dashboard-mockups");
const appDir = join(process.cwd(), "app", "[locale]", "sous-traitant");

describe("provider dashboard mockups", () => {
  it("documente la navigation prestataire", () => {
    const nav = readFileSync(join(mockupDir, "NAVIGATION.md"), "utf8");
    expect(nav).toContain("/sous-traitant/qualification");
    expect(nav).toContain("/messagerie");
  });

  it("aligne buildProviderNav sur les libellés produit", () => {
    const nav = buildProviderNav("fr", "");
    expect(providerDashboardCopy.fr.navServices).toBe("Services & capacité");
    expect(nav.find((item) => item.key === "services")?.label).toBe("Services & capacité");
    expect(nav.find((item) => item.key === "quotes")?.label).toBe("Mes devis");
    expect(nav.find((item) => item.key === "missions")?.label).toBe("Missions & livrables");
    expect(nav.find((item) => item.key === "planning")?.href).toContain("/sous-traitant/planning");
    expect(nav.find((item) => item.key === "planning")?.label).toBe("Planning");
    expect(nav.find((item) => item.key === "reputation")?.label).toBe("Réputation");
    expect(nav.find((item) => item.key === "messages")?.href).toContain("/sous-traitant/messages");
    expect(nav.find((item) => item.key === "company")?.href).toContain("/sous-traitant/entreprise");
    expect(nav.find((item) => item.key === "modeClient")?.href).toContain("/sous-traitant/mode-client");
    expect(nav.find((item) => item.key === "modeClient")?.label).toBe("Mode Client");
    expect(nav.find((item) => item.key === "disputes")?.href).toContain("/sous-traitant/litiges");
    expect(nav.find((item) => item.key === "disputes")?.label).toBe("Litiges");
    expect(nav.find((item) => item.key === "purchases")?.href).toContain("/sous-traitant/achats");
    expect(nav.find((item) => item.key === "purchases")?.label).toBe("Mes achats");
  });

  it("ouvre les listes vers des pages de détail 09-15", () => {
    const demo = demoProviderSpaces("fr", "");
    expect(demo.consultRows[0]?.href).toContain("/sous-traitant/consultations/cr1");
    expect(demo.quotes[0]?.href).toContain("/sous-traitant/devis/d1");
    expect(demo.quotes[1]?.href).toContain("/revision");
    expect(demo.missions[0]?.href).toContain("/sous-traitant/missions/m1");
    const lists = renderToStaticMarkup(<ConsultationsBoard locale="fr" query="" />) + renderToStaticMarkup(<QuotesBoard locale="fr" query="" />);
    expect(lists).toContain("/sous-traitant/consultations/cr1");
    expect(lists).toContain("/sous-traitant/devis/nouveau");
  });

  it("couvre les écrans imbriqués par des pages dédiées", () => {
    for (const relative of [
      "consultations/[consultationId]/page.tsx",
      "devis/nouveau/page.tsx",
      "devis/[quoteId]/page.tsx",
      "devis/[quoteId]/revision/page.tsx",
      "devis/[quoteId]/apercu/page.tsx",
      "missions/[missionId]/page.tsx",
      "facturation/[invoiceId]/page.tsx",
      "messages/page.tsx",
      "messages/[threadId]/page.tsx",
      "entreprise/page.tsx",
    ]) {
      expect(readFileSync(join(appDir, relative), "utf8")).toContain("nested-screens");
    }
    expect(Object.keys(providerWorkbenchCopy.ar)).toEqual(Object.keys(providerWorkbenchCopy.fr));
    expect(readFileSync(join(appDir, "qualification/certifications/page.tsx"), "utf8")).toContain("Certifications et références");
    expect(readFileSync(join(appDir, "entreprise/contrat/page.tsx"), "utf8")).toContain("Contrat partenaire");
    expect(readFileSync(join(appDir, "messages/page.tsx"), "utf8")).toContain("ProviderMessagesPage");
    expect(readFileSync(join(appDir, "litiges/page.tsx"), "utf8")).toContain("createServerDisputesRepository");
    expect(readFileSync(join(appDir, "achats/page.tsx"), "utf8")).toContain("ProviderPurchasesBoard");
    expect(readFileSync(join(appDir, "facturation/pre-releve/page.tsx"), "utf8")).toContain("pre-releve");
    expect(readFileSync(join(appDir, "facturation/factures-matricia/page.tsx"), "utf8")).toContain("factures");
    expect(readFileSync(join(appDir, "facturation/echeancier/page.tsx"), "utf8")).toContain("echeancier");
    expect(readFileSync(join(appDir, "facturation/commissions/page.tsx"), "utf8")).toContain("commissions");
  });
});
