import { canApplyFranchiseSpaceDemo } from "@/modules/franchise/data/spaces/demo";
import type { FranchiseCatalogRow, FranchiseCategoryNode, FranchiseLibraryWorkspace, FranchiseQuestionRow } from "@/modules/franchise/data/library/workspace-model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

const draftStatuses = new Set(["DRAFT"]);
const reviewStatuses = new Set(["IN_REVIEW", "FRANCHISE_REVIEW", "CENTRAL_REVIEW", "LOCAL_TEST"]);
const publishedStatuses = new Set(["PUBLISHED", "APPROVED"]);

function bucket(status: string): "drafts" | "inReview" | "published" | "other" {
  if (draftStatuses.has(status)) return "drafts";
  if (reviewStatuses.has(status)) return "inReview";
  if (publishedStatuses.has(status)) return "published";
  return "other";
}

function demoCatalog(locale: Locale, query: string) {
  const fr = locale === "fr";
  const q = query;
  const categories: FranchiseCategoryNode[] = [
    { id: "demo-cat-infra", title: fr ? "Infrastructure" : "البنية التحتية", children: [{ id: "demo-sub-backup", title: fr ? "Sauvegarde" : "النسخ الاحتياطي" }] },
    { id: "demo-cat-apps", title: fr ? "Applications" : "التطبيقات", children: [{ id: "demo-sub-crm", title: fr ? "Relation client" : "علاقة الزبون" }] },
  ];
  const services: FranchiseCatalogRow[] = [
    {
      id: "33333333-3333-4333-8333-333333333333",
      kind: "SERVICE",
      title: fr ? "Sauvegarde gérée" : "نسخ احتياطي مُدار",
      code: "IT-BACKUP",
      status: "PUBLISHED",
      versionLabel: "v1",
      href: `/${locale}/franchise/services${q}?serviceId=33333333-3333-4333-8333-333333333333`,
      category: categories[0]?.title ?? null,
      subcategory: categories[0]?.children[0]?.title ?? null,
      subcategoryId: "demo-sub-backup",
      description: fr ? "Sauvegarde managée et restaurations testées." : "نسخ احتياطي مُدار واسترجاع مختبَر.",
      nameFr: "Sauvegarde gérée",
      nameAr: "نسخ احتياطي مُدار",
    },
    {
      id: "33333333-3333-4333-8333-333333333334",
      kind: "SERVICE",
      title: fr ? "Infogérance poste" : "إدارة محطات العمل",
      code: "IT-DESK",
      status: "DRAFT",
      versionLabel: "v1",
      href: `/${locale}/franchise/services${q}?serviceId=33333333-3333-4333-8333-333333333334`,
      category: categories[1]?.title ?? null,
      subcategory: categories[1]?.children[0]?.title ?? null,
      subcategoryId: "demo-sub-crm",
      description: fr ? "Supervision des postes et assistance de proximité." : "مراقبة المحطات ودعم ميداني.",
      nameFr: "Infogérance poste",
      nameAr: "إدارة محطات العمل",
    },
  ];
  const questionnaires: FranchiseCatalogRow[] = [
    {
      id: "44444444-4444-4444-8444-444444444444",
      kind: "QUESTIONNAIRE",
      title: fr ? "Diagnostic SI" : "تشخيص نظم المعلومات",
      code: "IT-DIAG",
      status: "IN_REVIEW",
      versionLabel: "v1",
      href: `/${locale}/franchise/questionnaires/44444444-4444-4444-8444-444444444444${q}`,
      category: null,
      subcategory: null,
      subcategoryId: null,
      description: null,
      nameFr: "Diagnostic SI",
      nameAr: "تشخيص نظم المعلومات",
    },
    {
      id: "44444444-4444-4444-8444-444444444445",
      kind: "QUESTIONNAIRE",
      title: fr ? "Satisfaction client" : "رضا العميل",
      code: "IT-SAT",
      status: "PUBLISHED",
      versionLabel: "v1",
      href: `/${locale}/franchise/questionnaires/44444444-4444-4444-8444-444444444445${q}`,
      category: null,
      subcategory: null,
      subcategoryId: null,
      description: null,
      nameFr: "Satisfaction client",
      nameAr: "رضا العميل",
    },
  ];
  const rules: FranchiseCatalogRow[] = [
    {
      id: "55555555-5555-4555-8555-555555555555",
      kind: "RULE",
      title: "BACKUP_TESTED",
      code: "BACKUP_TESTED",
      status: "CHANGES_REQUESTED",
      versionLabel: "v1",
      href: `/${locale}/franchise/regles${q}?ruleId=55555555-5555-4555-8555-555555555555`,
      category: null,
      subcategory: null,
      subcategoryId: null,
      description: fr ? "Propose la sauvegarde gérée si aucune restauration n’a été testée." : "يقترح النسخ الاحتياطي إذا لم يُختبر الاسترجاع.",
      nameFr: null,
      nameAr: null,
    },
    {
      id: "55555555-5555-4555-8555-555555555556",
      kind: "RULE",
      title: "HAS_CRM",
      code: "HAS_CRM",
      status: "PUBLISHED",
      versionLabel: "v1",
      href: `/${locale}/franchise/regles${q}?ruleId=55555555-5555-4555-8555-555555555556`,
      category: null,
      subcategory: null,
      subcategoryId: null,
      description: fr ? "Oriente vers la relation client si aucun outil n’est en place." : "يوجّه إلى علاقة الزبون إن لم توجد أداة.",
      nameFr: null,
      nameAr: null,
    },
  ];
  const questions: FranchiseQuestionRow[] = [
    { id: "66666666-6666-4666-8666-666666666661", key: "HAS_BACKUP", status: "DRAFT", label: fr ? "Disposez-vous d’une sauvegarde testée ?" : "هل لديكم نسخ احتياطي مختبَر؟", help: fr ? "La restauration doit avoir été prouvée." : "يجب إثبات الاسترجاع.", answerType: "YES_NO", required: true, questionnaireId: questionnaires[0]?.id ?? null },
    { id: "66666666-6666-4666-8666-666666666662", key: "RESTORE_COUNT", status: "DRAFT", label: fr ? "Combien de restaurations ont été testées ?" : "كم عملية استرجاع تم اختبارها؟", help: "", answerType: "INTEGER", required: true, questionnaireId: questionnaires[0]?.id ?? null },
    { id: "66666666-6666-4666-8666-666666666663", key: "BACKUP_PROOF", status: "DRAFT", label: fr ? "Joignez la preuve de restauration." : "أرفقوا دليل الاسترجاع.", help: "", answerType: "SHORT_TEXT", required: false, questionnaireId: questionnaires[0]?.id ?? null },
    { id: "66666666-6666-4666-8666-666666666664", key: "LAST_TEST", status: "DRAFT", label: fr ? "Date du dernier test de restauration" : "تاريخ آخر اختبار استرجاع", help: "", answerType: "DATE", required: true, questionnaireId: questionnaires[0]?.id ?? null },
  ];
  return { categories, services, questionnaires, rules, questions };
}

export function overlayFranchiseLibraryDemo(workspace: FranchiseLibraryWorkspace, locale: Locale, query = ""): FranchiseLibraryWorkspace {
  if (!canApplyFranchiseSpaceDemo()) return workspace;
  const demo = demoCatalog(locale, query);
  const categories = workspace.categories.length > 0 ? workspace.categories : demo.categories;
  const services = workspace.services.length > 0 ? workspace.services : demo.services;
  const questionnaires = workspace.questionnaires.length > 0 ? workspace.questionnaires : demo.questionnaires;
  const rules = workspace.rules.length > 0 ? workspace.rules : demo.rules;
  const questions = workspace.questions.length > 0 ? workspace.questions : demo.questions;
  const all = [...services, ...questionnaires, ...rules];
  return {
    ...workspace,
    categories,
    services,
    questionnaires,
    rules,
    questions,
    counts: {
      drafts: all.filter((item) => bucket(item.status) === "drafts").length,
      inReview: all.filter((item) => bucket(item.status) === "inReview").length,
      published: all.filter((item) => bucket(item.status) === "published").length,
      returns: workspace.counts.returns,
    },
  };
}
