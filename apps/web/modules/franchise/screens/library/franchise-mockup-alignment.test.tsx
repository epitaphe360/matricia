import { readFile } from "node:fs/promises";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { FranchiseLibraryHomeBoard } from "./library-boards";
import { validationChipLabel } from "./library-chrome";
import { FranchiseQuestionnairesWorkbench, FranchiseRulesWorkbench, FranchiseServicesWorkbench } from "./library-workbenches";
import { FranchiseValidationsWorkbench } from "./validations-workbench";
import {
  DocumentsBoard,
  FollowupsBoard,
  FranchiseFinanceBoard,
  FranchiseRequestsBoard,
  GovernanceBoard,
  MessagesBoard,
  NetworkBoard,
  PerformanceBoard,
  QualityBoard,
} from "../spaces/boards";
import { resolveFranchiseNestedView, FRANCHISE_NESTED_NAV_PATHS } from "@/modules/franchise/data/spaces/nested-views";
import type { FranchiseLibraryWorkspace } from "@/modules/franchise/data/library/workspace";

const empty: FranchiseLibraryWorkspace = {
  mandate: {
    franchiseId: "11111111-1111-4111-8111-111111111111",
    operatorCode: "HATIM_AHMITECH",
    type: "IT",
    libraryId: "22222222-2222-4222-8222-222222222222",
    libraryCode: "IT",
    libraryName: "Informatique",
    libraryStatus: "PUBLISHED",
    libraryRowVersion: 1,
    currentReleaseId: null,
  },
  counts: { drafts: 0, inReview: 0, published: 0, returns: 0 },
  categories: [],
  services: [],
  questionnaires: [],
  rules: [],
  questions: [],
  releases: [],
};

const catalog: FranchiseLibraryWorkspace = {
  ...empty,
  counts: { drafts: 0, inReview: 1, published: 0, returns: 0 },
  services: [{
    id: "33333333-3333-4333-8333-333333333333",
    kind: "SERVICE",
    title: "Sauvegarde gérée",
    code: "IT-BACKUP",
    status: "IN_REVIEW",
    versionLabel: "v1",
    href: "/fr/franchise/services",
    category: "Infrastructure",
    subcategory: "Sauvegarde",
    subcategoryId: "sub-1",
    description: "Sauvegarde managée",
    nameFr: "Sauvegarde gérée",
    nameAr: "نسخ احتياطي مُدار",
  }],
};

const command = { idempotencyKey: "11111111-1111-4111-8111-111111111111", correlationId: "11111111-1111-4111-8111-111111111112" };
const splitPattern = /50\s*%|Hatim Ahmitech|Jalil-NEOXA/;

describe("alignement maquettes franchise (00–03)", () => {
  it("reproduit la structure accueil bibliothèque mandatée", () => {
    const html = renderToStaticMarkup(<FranchiseLibraryHomeBoard locale="fr" query="" workspace={catalog} />);
    expect(html).toContain("franchise-kpi-tile");
    expect(html).toContain("franchise-pipe-icon");
    expect(html).toContain("File de travail");
    expect(html).toContain("Soumise");
    expect(html).toContain("franchise-tool-primary");
    expect(html).toContain("franchise-mandate-ok");
    expect(html).not.toMatch(/exemple illustratif/i);
    expect(html).not.toMatch(splitPattern);
  });

  it("reproduit services, questionnaires et règles en trois colonnes", () => {
    const workspace = catalog;
    const services = renderToStaticMarkup(
      <FranchiseServicesWorkbench locale="fr" query="" workspace={workspace} selectedId={workspace.services[0]!.id} createMode={false} organizationId={null} commandIdentity={command} />,
    );
    const questionnaires = renderToStaticMarkup(
      <FranchiseQuestionnairesWorkbench locale="fr" query="" workspace={workspace} selectedId={null} createMode={false} commandIdentity={command} />,
    );
    const rules = renderToStaticMarkup(
      <FranchiseRulesWorkbench locale="fr" query="" workspace={workspace} selectedId={null} createMode={false} commandIdentity={command} />,
    );
    expect(services).toContain("franchise-workbench");
    expect(services).toContain("franchise-pagination");
    expect(services).toContain("franchise-scope-info");
    expect(services).toContain("Créer une catégorie");
    expect(services).toContain("Créer une sous-catégorie");
    expect(questionnaires).toContain("franchise-mini-pipe");
    expect(questionnaires).toContain("franchise-mandate-banner");
    expect(rules).toContain("#simulation");
    expect(rules).toContain("franchise-workbench");
    expect(rules).toContain("franchise-mandate-banner");
    expect(validationChipLabel("IN_REVIEW", "fr")).toBe("Soumise");
  });

  it("le shell franchise reprend le chrome Figma", async () => {
    const shell = await readFile(new URL("../../ui/franchise-app-shell.tsx", import.meta.url), "utf8");
    const css = await readFile(new URL("../../ui/franchise-experience.css", import.meta.url), "utf8");
    const nav = await readFile(new URL("../../ui/franchise-nav.ts", import.meta.url), "utf8");
    expect(shell).toContain("brandSpace");
    expect(shell).toContain("franchise-mandate-chip");
    expect(shell).not.toContain("franchise/finance");
    expect(nav).toContain("fournisseurs");
    expect(nav).toContain("documents");
    expect(nav).toContain("messages");
    expect(nav).not.toContain("franchise/finance");
    expect(css).toContain("franchise-security-panel");
    expect(css).toContain("franchise-mandate-ok");
    expect(css).toContain("franchise-workbench");
  });
});

describe("alignement visuel des autres écrans franchise", () => {
  it("compose demandes, fournisseurs, qualité, performance et relances en workbench mandatée", () => {
    const html = [
      renderToStaticMarkup(<FranchiseRequestsBoard locale="fr" query="" mandateName="Informatique" />),
      renderToStaticMarkup(<NetworkBoard locale="fr" query="" mandateName="Informatique" />),
      renderToStaticMarkup(<QualityBoard locale="fr" query="" mandateName="Informatique" />),
      renderToStaticMarkup(<PerformanceBoard locale="fr" query="" mandateName="Informatique" />),
      renderToStaticMarkup(<FollowupsBoard locale="fr" query="" mandateName="Informatique" />),
    ].join("\n");
    expect(html).toContain("franchise-workbench");
    expect(html).toContain("franchise-mandate-banner");
    expect(html).toContain("franchise-mandate-ok");
    expect(html).toContain("Vous voyez uniquement votre bibliothèque mandatée");
    expect(html).toContain("/fr/franchise/fournisseurs");
    expect(html).toContain("/fr/franchise/qualite/revues");
    expect(html).toContain("Matching");
    expect(html).not.toMatch(/exemple illustratif/i);
    expect(html).not.toMatch(splitPattern);
  });

  it("aligne validations, documents, messages et gouvernance sans affichage de répartition", () => {
    const html = [
      renderToStaticMarkup(<FranchiseValidationsWorkbench locale="fr" query="" workspace={catalog} commandIdentity={command} />),
      renderToStaticMarkup(<DocumentsBoard locale="fr" query="" mandateName="Informatique" />),
      renderToStaticMarkup(<MessagesBoard locale="fr" query="" mandateName="Informatique" />),
      renderToStaticMarkup(<GovernanceBoard locale="fr" query="" mandateName="Informatique" />),
      renderToStaticMarkup(<FranchiseFinanceBoard locale="fr" query="" mandateName="Informatique" />),
    ].join("\n");
    expect(html).toContain("franchise-workbench");
    expect(html).toContain("Brouillons à soumettre");
    expect(html).toContain("Renouvellements");
    expect(html).toContain("Notifications");
    expect(html).toContain("/fr/franchise/documents/renouvellements");
    expect(html).toContain("/fr/franchise/notifications");
    expect(html).toContain("Aucun montant, solde ou donnée financière");
    expect(html).toContain("Aucun service approuvé n’est prêt à publier");
    expect(html).not.toMatch(splitPattern);
  });

  it("résout toutes les destinations NAVIGATION imbriquées", () => {
    expect(resolveFranchiseNestedView(["bibliotheque", "categories"])?.kind).toBe("library");
    expect(resolveFranchiseNestedView(["demandes", "d1", "matching"])?.tool).toBe("matching");
    expect(resolveFranchiseNestedView(["notifications"])?.view).toBe("notifications");
    expect(FRANCHISE_NESTED_NAV_PATHS).toHaveLength(57);
    expect(resolveFranchiseNestedView(["clients", "inviter"])?.view).toBe("inviter");
    expect(resolveFranchiseNestedView(["demandes", "devis"])?.view).toBe("devis");
    expect(resolveFranchiseNestedView(["qualite", "anomalies"])?.view).toBe("anomalies");
    expect(resolveFranchiseNestedView(["qualite", "incidents"])?.view).toBe("incidents");
    expect(resolveFranchiseNestedView(["perimetre", "utilisateurs"])?.view).toBe("utilisateurs");
    expect(resolveFranchiseNestedView(["finance", "volume"])?.view).toBe("volume");
    expect(resolveFranchiseNestedView(["finance", "paiements"])?.view).toBe("paiements");
    for (const path of FRANCHISE_NESTED_NAV_PATHS) {
      expect(resolveFranchiseNestedView(path.split("/")), path).not.toBeNull();
    }
  });
});
