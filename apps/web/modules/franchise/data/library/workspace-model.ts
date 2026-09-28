export type FranchiseCatalogKind = "SERVICE" | "QUESTIONNAIRE" | "RULE";
export type FranchiseServiceCommand = {
  draftVersionId: string;
  identityRowVersion: number;
  versionRowVersion: number;
  slug: string;
  descriptionFr: string;
  descriptionAr: string;
  longDescriptionFr: string;
  longDescriptionAr: string;
  serviceType: string;
  unitLabelFr: string;
  unitLabelAr: string;
  creditEligible: boolean;
  volumeEligible: boolean;
  recurringEligible: boolean;
  trialEligible: boolean;
  rfqRequired: boolean;
  fixedFulfillmentAllowed: boolean;
  baseCurrency: string;
  sortOrder: number;
  fulfillmentConfig: Record<string, unknown>;
  visibilityRules: Record<string, unknown>;
  sensitive: boolean;
};
export type FranchiseCatalogRow = {
  id: string;
  kind: FranchiseCatalogKind;
  title: string;
  code: string;
  status: string;
  versionLabel: string | null;
  href: string;
  category: string | null;
  subcategory: string | null;
  subcategoryId: string | null;
  description: string | null;
  nameFr: string | null;
  nameAr: string | null;
  questionnaireVersionId?: string | null;
  draftVersionId?: string | null;
  identityRowVersion?: number | null;
  versionRowVersion?: number | null;
  command?: FranchiseServiceCommand | null;
  ruleActions?: Array<{ type: string; target?: string }>;
};

export type FranchiseQuestionRow = {
  id: string;
  key: string;
  status: string;
  label: string;
  help: string;
  labelFr?: string;
  labelAr?: string;
  helpFr?: string;
  helpAr?: string;
  versionId?: string | null;
  answerType: string | null;
  required: boolean;
  questionnaireId: string | null;
};

export type FranchiseHierarchyNode = {
  id: string;
  title: string;
  status?: string;
  draftVersionId?: string | null;
  identityRowVersion?: number;
  versionRowVersion?: number;
};

export type FranchiseCategoryNode = FranchiseHierarchyNode & {
  children: FranchiseHierarchyNode[];
};

export type FranchiseLibraryWorkspace = {
  mandate: {
    franchiseId: string;
    operatorCode: string;
    type: "IT" | "STANDARD";
    libraryId: string;
    libraryCode: string;
    libraryName: string;
    libraryStatus: string;
    libraryRowVersion: number;
    currentReleaseId: string | null;
    operatorOrganizationId?: string;
  };
  counts: { drafts: number; inReview: number; published: number; returns: number };
  categories: FranchiseCategoryNode[];
  services: FranchiseCatalogRow[];
  questionnaires: FranchiseCatalogRow[];
  rules: FranchiseCatalogRow[];
  questions: FranchiseQuestionRow[];
  releases: Array<{ id: string; key: string; status: string }>;
};

export type FranchiseLibraryLoadResult =
  | { status: "success"; workspace: FranchiseLibraryWorkspace }
  | { status: "error"; reason: "UNAUTHENTICATED" | "FORBIDDEN" | "NO_MANDATE" | "QUERY_FAILED" | "INVALID_RESPONSE" };

export const reviewStatuses = new Set(["IN_REVIEW", "FRANCHISE_REVIEW", "CENTRAL_REVIEW", "LOCAL_TEST"]);
export const draftStatuses = new Set(["DRAFT"]);
export const publishedStatuses = new Set(["PUBLISHED", "APPROVED"]);

export function catalogStatusLabel(status: string, locale: "fr" | "ar") {
  const fr: Record<string, string> = {
    DRAFT: "Brouillon",
    IN_REVIEW: "En validation",
    FRANCHISE_REVIEW: "Revue interne",
    CENTRAL_REVIEW: "Revue Matricia",
    LOCAL_TEST: "Simulation",
    APPROVED: "Validé",
    PUBLISHED: "Publié",
    SCHEDULED: "Planifié",
    SUPERSEDED: "Remplacé",
    RETIRED: "Retiré",
    ARCHIVED: "Archivé",
    REJECTED: "Retours Matricia",
    CHANGES_REQUESTED: "Correction demandée",
  };
  const ar: Record<string, string> = {
    DRAFT: "مسودة",
    IN_REVIEW: "قيد الاعتماد",
    FRANCHISE_REVIEW: "مراجعة داخلية",
    CENTRAL_REVIEW: "مراجعة ماتريسيا",
    LOCAL_TEST: "محاكاة",
    APPROVED: "معتمد",
    PUBLISHED: "منشور",
    SCHEDULED: "مجدول",
    SUPERSEDED: "مستبدل",
    RETIRED: "مسحوب",
    ARCHIVED: "مؤرشف",
    REJECTED: "ملاحظات ماتريسيا",
    CHANGES_REQUESTED: "تصحيح مطلوب",
  };
  return (locale === "ar" ? ar : fr)[status] ?? status;
}

export function catalogStatusTone(status: string): "violet" | "sky" | "mint" | "peach" {
  if (draftStatuses.has(status) || status === "REJECTED" || status === "CHANGES_REQUESTED") return "peach";
  if (reviewStatuses.has(status)) return "sky";
  if (publishedStatuses.has(status)) return "mint";
  return "violet";
}
