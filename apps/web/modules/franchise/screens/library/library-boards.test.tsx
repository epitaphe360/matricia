import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { FranchiseCatalogListBoard, FranchiseLibraryHomeBoard, FranchiseLibraryStructureBoard } from "./library-boards";
import type { FranchiseLibraryWorkspace } from "@/modules/franchise/data/library/workspace";

const workspace: FranchiseLibraryWorkspace = {
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
  counts: { drafts: 1, inReview: 0, published: 1, returns: 0 },
  categories: [{ id: "cat-1", title: "Infrastructure", children: [{ id: "sub-1", title: "Sauvegarde" }] }],
  services: [{ id: "33333333-3333-4333-8333-333333333333", kind: "SERVICE", title: "Sauvegarde gérée", code: "IT-BACKUP", status: "PUBLISHED", versionLabel: "v1", href: "/fr/franchise/services?serviceId=s1", category: "Infrastructure", subcategory: "Sauvegarde", subcategoryId: "sub-1", description: "Sauvegarde managée", nameFr: "Sauvegarde gérée", nameAr: "نسخ احتياطي" }],
  questionnaires: [{ id: "44444444-4444-4444-8444-444444444444", kind: "QUESTIONNAIRE", title: "Diagnostic SI", code: "IT-DIAG", status: "DRAFT", versionLabel: "v1", href: "/fr/franchise/questionnaires/q1", category: null, subcategory: null, subcategoryId: null, description: null, nameFr: "Diagnostic SI", nameAr: "تشخيص نظم المعلومات" }],
  rules: [{ id: "55555555-5555-4555-8555-555555555555", kind: "RULE", title: "BACKUP_TESTED", code: "BACKUP_TESTED", status: "DRAFT", versionLabel: "v1", href: "/fr/franchise/regles?ruleId=r1", category: null, subcategory: null, subcategoryId: null, description: null, nameFr: null, nameAr: null }],
  questions: [{ id: "66666666-6666-4666-8666-666666666666", key: "HAS_BACKUP", status: "DRAFT", label: "Disposez-vous d’une sauvegarde testée ?", help: "", answerType: "YES_NO", required: true, questionnaireId: "44444444-4444-4444-8444-444444444444" }],
  releases: [],
};

describe("franchise library boards", () => {
  it("affiche la bibliothèque mandatée réelle, sans exemple illustratif", () => {
    const html = renderToStaticMarkup(<FranchiseLibraryHomeBoard locale="fr" query="" workspace={workspace} />);
    expect(html).toContain("Informatique");
    expect(html).toContain("Vous voyez uniquement votre bibliothèque mandatée");
    expect(html).toContain("Diagnostic SI");
    expect(html).toContain("Soumettre pour validation");
    expect(html).not.toMatch(/exemple illustratif/i);
  });

  it("liste les questionnaires préparés par le franchisé", () => {
    const html = renderToStaticMarkup(
      <FranchiseCatalogListBoard locale="fr" title="Questions & questionnaires" empty="Aucun" rows={workspace.questionnaires} createHref="/fr/franchise/questionnaires#nouveau" createLabel="Ajouter un questionnaire" />,
    );
    expect(html).toContain("Diagnostic SI");
    expect(html).toContain("IT-DIAG");
    expect(html).not.toMatch(/exemple illustratif/i);
  });

  it("aligne l’accueil sur la file de travail de la maquette", () => {
    const html = renderToStaticMarkup(<FranchiseLibraryHomeBoard locale="fr" query="" workspace={workspace} />);
    expect(html).toContain("File de travail");
    expect(html).toContain("Finaliser les champs");
    expect(html).toContain("Créer un service");
    expect(html).toContain("franchise-pipe-icon");
    expect(html).toContain("franchise-kpi-tile");
    expect(html).toContain("franchise-tool-primary");
    expect(html).toContain("franchise-tool-peach");
    expect(html).toContain("franchise-tool-mint");
    expect(html).toContain("1. Préparer les services");
    expect(html).toContain("Périmètre du mandat");
    expect(html).toContain("Versions publiées");
  });

  it("permet de créer et soumettre l’arborescence de catégories", () => {
    const html = renderToStaticMarkup(
      <FranchiseLibraryStructureBoard locale="fr" query="" workspace={workspace} view="categories" commandIdentity={{ idempotencyKey: "11111111-1111-4111-8111-111111111111", correlationId: "11111111-1111-4111-8111-111111111112" }} organizationId={null} />,
    );
    expect(html).toContain("Infrastructure");
    expect(html).toContain("Créer une catégorie");
    expect(html).toContain("Créer une sous-catégorie");
    expect(html).toContain("name=\"code\"");
    expect(html).not.toMatch(/exemple illustratif/i);
  });
});
