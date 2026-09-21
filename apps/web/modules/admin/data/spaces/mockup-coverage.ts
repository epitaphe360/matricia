import type { AdminSpaceId } from "./admin-nav";

export type AdminMockupFit = "matching" | "generic";
export type AdminMockupLayout = "directory" | "list" | "detail" | "decision" | "wizard" | "compare";

export type AdminMockupScreen = {
  id: string;
  file: string;
  route: string;
  layout: AdminMockupLayout;
  fit: AdminMockupFit;
  space?: AdminSpaceId | "home" | "orgs" | "users" | "clients" | "compliance";
};

export const ADMIN_MOCKUP_SCREENS: AdminMockupScreen[] = [
  { id: "00", file: "00-admin-vue-ensemble.png", route: "/administration/command-center", layout: "directory", fit: "matching", space: "home" },
  { id: "01", file: "01-organisations-liste.png", route: "/administration/entreprises", layout: "list", fit: "matching", space: "orgs" },
  { id: "02", file: "02-organisation-detail.png", route: "/administration/entreprises/[organizationId]", layout: "detail", fit: "matching", space: "orgs" },
  { id: "03", file: "03-organisation-modifier.png", route: "/administration/entreprises/[organizationId]/modifier", layout: "wizard", fit: "matching", space: "orgs" },
  { id: "04", file: "04-organisation-archiver-restaurer.png", route: "/administration/entreprises/[organizationId]/archiver", layout: "decision", fit: "matching", space: "orgs" },
  { id: "05", file: "05-utilisateurs-liste.png", route: "/administration/utilisateurs", layout: "list", fit: "matching", space: "users" },
  { id: "06", file: "06-utilisateur-inviter.png", route: "/administration/utilisateurs/inviter", layout: "wizard", fit: "matching", space: "users" },
  { id: "07", file: "07-utilisateur-acces-detail.png", route: "/administration/utilisateurs/[userId]", layout: "detail", fit: "matching", space: "users" },
  { id: "08", file: "08-utilisateur-roles-revoquer.png", route: "/administration/utilisateurs/[userId]/roles", layout: "decision", fit: "matching", space: "users" },
  { id: "09", file: "09-clients-liste.png", route: "/administration/clients", layout: "list", fit: "matching", space: "clients" },
  { id: "10", file: "10-client-detail.png", route: "/administration/clients/[organizationId]", layout: "detail", fit: "matching", space: "clients" },
  { id: "11", file: "11-conformite-clients-file.png", route: "/administration/conformite-clients", layout: "list", fit: "matching", space: "compliance" },
  { id: "12", file: "12-conformite-client-decision.png", route: "/administration/conformite-clients/[caseId]", layout: "decision", fit: "matching", space: "compliance" },
  { id: "13", file: "13-prestataires-liste.png", route: "/administration/providers", layout: "list", fit: "matching", space: "providers" },
  { id: "14", file: "14-prestataire-detail.png", route: "/administration/providers/[organizationId]", layout: "detail", fit: "matching", space: "providers" },
  { id: "15", file: "15-qualification-prestataires-file.png", route: "/administration/qualification", layout: "list", fit: "matching", space: "qualification" },
  { id: "16", file: "16-qualification-prestataire-decision.png", route: "/administration/qualification/[itemId]/decision", layout: "decision", fit: "matching", space: "qualification" },
  { id: "17", file: "17-capacite-documents-prestataires.png", route: "/administration/capacite", layout: "list", fit: "matching", space: "capacite" },
  { id: "18", file: "18-franchises-liste.png", route: "/administration/franchises", layout: "list", fit: "matching", space: "franchises" },
  { id: "19", file: "19-franchise-detail.png", route: "/administration/franchises/[itemId]", layout: "detail", fit: "matching", space: "franchises" },
  { id: "20", file: "20-territoires-mandats.png", route: "/administration/territoires", layout: "list", fit: "matching", space: "territoires" },
  { id: "21", file: "21-mandat-detail.png", route: "/administration/territoires/[itemId]", layout: "detail", fit: "matching", space: "territoires" },
  { id: "22", file: "22-gouvernance-franchise-validations.png", route: "/administration/gouvernance", layout: "list", fit: "matching", space: "gouvernance" },
  { id: "23", file: "23-gouvernance-franchise-decision.png", route: "/administration/gouvernance/[itemId]/decision", layout: "decision", fit: "matching", space: "gouvernance" },
  { id: "24", file: "24-diagnostics-liste.png", route: "/administration/diagnostics", layout: "list", fit: "matching", space: "diagnostics" },
  { id: "25", file: "25-diagnostic-detail.png", route: "/administration/diagnostics/[itemId]", layout: "detail", fit: "matching", space: "diagnostics" },
  { id: "26", file: "26-diagnostic-revue-version.png", route: "/administration/diagnostics/[itemId]/revue", layout: "decision", fit: "matching", space: "diagnostics" },
  { id: "27", file: "27-besoins-demandes-liste.png", route: "/administration/demandes", layout: "list", fit: "matching", space: "demandes" },
  { id: "28", file: "28-demande-detail.png", route: "/administration/demandes/[itemId]", layout: "detail", fit: "matching", space: "demandes" },
  { id: "29", file: "29-demande-creer-modifier.png", route: "/administration/demandes/nouvelle", layout: "wizard", fit: "matching", space: "demandes" },
  { id: "30", file: "30-matching-consultations-liste.png", route: "/administration/matching", layout: "list", fit: "matching", space: "matching" },
  { id: "31", file: "31-matching-detail-explicable.png", route: "/administration/matching/[itemId]", layout: "detail", fit: "matching", space: "matching" },
  { id: "32", file: "32-consultation-preparer-envoyer.png", route: "/administration/matching/[itemId]/consultation", layout: "decision", fit: "matching", space: "matching" },
  { id: "33", file: "33-devis-comparaison-liste.png", route: "/administration/devis", layout: "list", fit: "matching", space: "devis" },
  { id: "34", file: "34-devis-detail-versions.png", route: "/administration/devis/[itemId]", layout: "detail", fit: "matching", space: "devis" },
  { id: "35", file: "35-offres-comparer.png", route: "/administration/devis/comparer", layout: "compare", fit: "matching", space: "devis" },
  { id: "36", file: "36-contrats-signatures-liste.png", route: "/administration/contrats", layout: "list", fit: "matching", space: "contrats" },
  { id: "37", file: "37-contrat-dossier.png", route: "/administration/contrats/[itemId]", layout: "detail", fit: "matching", space: "contrats" },
  { id: "38", file: "38-contrat-validation-activation.png", route: "/administration/contrats/[itemId]/activation", layout: "decision", fit: "matching", space: "contrats" },
  { id: "39", file: "39-avenants-liste.png", route: "/administration/avenants", layout: "list", fit: "matching", space: "avenants" },
  { id: "40", file: "40-avenant-preparer.png", route: "/administration/avenants/preparer", layout: "wizard", fit: "matching", space: "avenants" },
  { id: "41", file: "41-avenant-activer.png", route: "/administration/avenants/[itemId]/activer", layout: "decision", fit: "matching", space: "avenants" },
  { id: "42", file: "42-missions-liste.png", route: "/administration/missions", layout: "list", fit: "matching", space: "missions" },
  { id: "43", file: "43-mission-detail.png", route: "/administration/missions/[itemId]", layout: "detail", fit: "matching", space: "missions" },
  { id: "44", file: "44-mission-demarrage-cloture.png", route: "/administration/missions/[itemId]/cycle", layout: "decision", fit: "matching", space: "missions" },
  { id: "45", file: "45-jalons-livrables-preuves-liste.png", route: "/administration/jalons", layout: "list", fit: "matching", space: "jalons" },
  { id: "46", file: "46-jalon-livrable-detail.png", route: "/administration/jalons/[itemId]", layout: "detail", fit: "matching", space: "jalons" },
  { id: "47", file: "47-livrable-revue-decision.png", route: "/administration/jalons/[itemId]/revue", layout: "decision", fit: "matching", space: "jalons" },
  { id: "48", file: "48-documents-coffre-liste.png", route: "/administration/documents", layout: "list", fit: "matching", space: "documents" },
  { id: "49", file: "49-document-detail-versions.png", route: "/administration/documents/[itemId]", layout: "detail", fit: "matching", space: "documents" },
  { id: "50", file: "50-document-reutilisation-partage.png", route: "/administration/documents/[itemId]/reutilisation", layout: "wizard", fit: "matching", space: "documents" },
  { id: "51", file: "51-messagerie-notifications-liste.png", route: "/administration/messagerie", layout: "list", fit: "matching", space: "messagerie" },
  { id: "52", file: "52-conversation-dossier.png", route: "/administration/messagerie/[itemId]", layout: "detail", fit: "matching", space: "messagerie" },
  { id: "53", file: "53-notifications-preferences.png", route: "/administration/messagerie/preferences", layout: "wizard", fit: "matching", space: "messagerie" },
  { id: "54", file: "54-litiges-reaffectations-liste.png", route: "/administration/litiges", layout: "list", fit: "matching", space: "litiges" },
  { id: "55", file: "55-litige-dossier-contradictoire.png", route: "/administration/litiges/[itemId]", layout: "detail", fit: "matching", space: "litiges" },
  { id: "56", file: "56-litige-decision-reaffectation.png", route: "/administration/litiges/[itemId]/decision", layout: "decision", fit: "matching", space: "litiges" },
];

export function matchingMockups() {
  return ADMIN_MOCKUP_SCREENS.filter((item) => item.fit === "matching");
}

export function genericMockups() {
  return ADMIN_MOCKUP_SCREENS.filter((item) => item.fit === "generic");
}
