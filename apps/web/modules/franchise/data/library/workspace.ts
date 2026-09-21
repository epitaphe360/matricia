import { z } from "zod";
import { overlayFranchiseLibraryDemo } from "@/modules/franchise/data/library/demo-overlay";
import {
  draftStatuses,
  publishedStatuses,
  reviewStatuses,
  type FranchiseCatalogRow,
  type FranchiseCategoryNode,
  type FranchiseLibraryLoadResult,
  type FranchiseQuestionRow,
} from "@/modules/franchise/data/library/workspace-model";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";

export type {
  FranchiseCatalogKind,
  FranchiseCatalogRow,
  FranchiseCategoryNode,
  FranchiseHierarchyNode,
  FranchiseLibraryLoadResult,
  FranchiseLibraryWorkspace,
  FranchiseQuestionRow,
  FranchiseServiceCommand,
} from "@/modules/franchise/data/library/workspace-model";
export { catalogStatusLabel, catalogStatusTone } from "@/modules/franchise/data/library/workspace-model";

const id = z.string().uuid();
const franchiseRow = z.object({
  id,
  library_id: id,
  operator_organization_id: id,
  franchise_type: z.enum(["IT", "STANDARD"]),
  operator_code: z.string(),
  status: z.string(),
});
const membershipRow = z.object({
  organization_id: id,
  organization_member_roles: z.array(z.object({ role_code: z.string(), franchise_id: id.nullable(), revoked_at: z.string().nullable() })),
});
const libraryRow = z.object({
  id,
  code: z.string(),
  status: z.string(),
  row_version: z.number().int().positive(),
  current_draft_version_id: id.nullable(),
  current_published_version_id: id.nullable(),
  current_release_id: id.nullable(),
});
const libraryVersionRow = z.object({ id, library_id: id, name_fr: z.string(), name_ar: z.string(), version: z.number().int() });
const jsonObject = z.record(z.string(), z.unknown());
const serviceRow = z.object({
  id,
  library_id: id,
  primary_subcategory_id: id,
  code: z.string(),
  slug: z.string(),
  status: z.string(),
  row_version: z.number().int().positive(),
  current_draft_version_id: id.nullable(),
  current_published_version_id: id.nullable(),
});
const serviceVersionRow = z.object({
  id,
  service_id: id,
  version: z.number().int(),
  status: z.string(),
  row_version: z.number().int().positive(),
  name_fr: z.string(),
  name_ar: z.string(),
  short_description_fr: z.string(),
  short_description_ar: z.string(),
  long_description_fr: z.string(),
  long_description_ar: z.string(),
  service_type: z.string(),
  unit_label_fr: z.string(),
  unit_label_ar: z.string(),
  credit_eligible: z.boolean(),
  volume_eligible: z.boolean(),
  recurring_eligible: z.boolean(),
  trial_eligible: z.boolean(),
  rfq_required: z.boolean(),
  fixed_fulfillment_allowed: z.boolean(),
  base_currency: z.string(),
  sort_order: z.number().int(),
  fulfillment_config: jsonObject,
  visibility_rules: jsonObject,
  sensitive: z.boolean(),
  slug: z.string(),
});
const questionnaireRow = z.object({
  id,
  library_id: id,
  code: z.string(),
  status: z.string(),
  row_version: z.number().int().positive(),
  current_draft_version_id: id.nullable(),
  current_published_version_id: id.nullable(),
});
const questionnaireVersionRow = z.object({
  id,
  questionnaire_id: id,
  version: z.number().int(),
  status: z.string(),
  row_version: z.number().int().positive(),
  title_fr: z.string(),
  title_ar: z.string(),
});
const ruleRow = z.object({
  id,
  library_id: id,
  rule_key: z.string(),
  status: z.string(),
  row_version: z.number().int().positive(),
  current_draft_version_id: id.nullable(),
  current_published_version_id: id.nullable(),
});
const ruleVersionRow = z.object({
  id,
  rule_id: id,
  version: z.number().int(),
  status: z.string(),
  row_version: z.number().int().positive(),
  actions: z.array(z.object({ type: z.string(), target: z.string().optional() }).passthrough()).catch([]),
});
const questionRow = z.object({ id, library_id: id, question_key: z.string(), status: z.string(), current_draft_version_id: id.nullable(), current_published_version_id: id.nullable() });
const questionVersionRow = z.object({
  id,
  question_id: id,
  version: z.number().int(),
  status: z.string(),
  label_fr: z.string(),
  label_ar: z.string(),
  help_fr: z.string().nullable(),
  help_ar: z.string().nullable(),
  answer_type: z.string(),
  required_by_default: z.boolean(),
  source_service_id: id.nullable(),
});
const questionnaireQuestionRow = z.object({ questionnaire_version_id: id, question_version_id: id, sort_order: z.number().int() });
const categoryRow = z.object({ id, library_id: id, code: z.string(), status: z.string(), row_version: z.number().int().positive(), current_draft_version_id: id.nullable(), current_published_version_id: id.nullable() });
const categoryVersionRow = z.object({ id, category_id: id, name_fr: z.string(), name_ar: z.string(), status: z.string().optional(), row_version: z.number().int().positive().optional() });
const subcategoryRow = z.object({ id, library_id: id, category_id: id, code: z.string(), status: z.string(), row_version: z.number().int().positive(), current_draft_version_id: id.nullable(), current_published_version_id: id.nullable() });
const subcategoryVersionRow = z.object({ id, subcategory_id: id, name_fr: z.string(), name_ar: z.string(), status: z.string().optional(), row_version: z.number().int().positive().optional() });
const releaseRow = z.object({ id, library_id: id, release_key: z.string(), status: z.string() });
const changeRow = z.object({ id, status: z.string() });

const franchiseRoles = ["FRANCHISE_OWNER", "FRANCHISE_MANAGER", "FRANCHISE_EXPERT", "FRANCHISE_PROVIDER_MANAGER", "FRANCHISE_VIEWER"] as const;

function bucket(status: string): "drafts" | "inReview" | "published" | "other" {
  if (draftStatuses.has(status)) return "drafts";
  if (reviewStatuses.has(status)) return "inReview";
  if (publishedStatuses.has(status)) return "published";
  return "other";
}

export async function loadFranchiseLibraryWorkspace(input: { locale: "fr" | "ar"; organizationId?: string }): Promise<FranchiseLibraryLoadResult> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const [franchisesResult, membershipsResult] = await Promise.all([
    client.from("franchises").select("id,library_id,operator_organization_id,franchise_type,operator_code,status").eq("status", "ACTIVE").order("created_at", { ascending: false }).limit(20),
    client.from("organization_memberships").select("organization_id,organization_member_roles(role_code,franchise_id,revoked_at)").eq("user_id", auth.user.id).eq("status", "ACTIVE").limit(100),
  ]);
  if (franchisesResult.error || membershipsResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const franchises = z.array(franchiseRow).safeParse(franchisesResult.data);
  const memberships = z.array(membershipRow).safeParse(membershipsResult.data);
  if (!franchises.success || !memberships.success) return { status: "error", reason: "INVALID_RESPONSE" };
  const roles = memberships.data.flatMap((member) => member.organization_member_roles
    .filter((role) => role.revoked_at === null && franchiseRoles.includes(role.role_code as (typeof franchiseRoles)[number]))
    .map((role) => ({ organizationId: member.organization_id, franchiseId: role.franchise_id })));
  const allowed = franchises.data.filter((item) => roles.some((role) => role.organizationId === item.operator_organization_id && (role.franchiseId === item.id || role.franchiseId === null)));
  if (!allowed.length) return { status: "error", reason: "FORBIDDEN" };
  const selected = (input.organizationId ? allowed.find((item) => item.operator_organization_id === input.organizationId) : null) ?? allowed[0];
  if (!selected) return { status: "error", reason: "NO_MANDATE" };
  const libraryId = selected.library_id;
  const [libraryResult, libraryVersionsResult, servicesResult, serviceVersionsResult, questionnairesResult, questionnaireVersionsResult, rulesResult, ruleVersionsResult, questionsResult, questionVersionsResult, questionnaireQuestionsResult, categoriesResult, categoryVersionsResult, subcategoriesResult, subcategoryVersionsResult, releasesResult, changesResult] = await Promise.all([
    client.from("catalog_libraries").select("id,code,status,row_version,current_draft_version_id,current_published_version_id,current_release_id").eq("id", libraryId).limit(1),
    client.from("catalog_library_versions").select("id,library_id,name_fr,name_ar,version").eq("library_id", libraryId).order("version", { ascending: false }).limit(20),
    client.from("catalog_services").select("id,library_id,primary_subcategory_id,code,slug,status,row_version,current_draft_version_id,current_published_version_id").eq("library_id", libraryId).order("code").limit(200),
    client.from("catalog_service_versions").select("id,service_id,version,status,row_version,name_fr,name_ar,short_description_fr,short_description_ar,long_description_fr,long_description_ar,service_type,unit_label_fr,unit_label_ar,credit_eligible,volume_eligible,recurring_eligible,trial_eligible,rfq_required,fixed_fulfillment_allowed,base_currency,sort_order,fulfillment_config,visibility_rules,sensitive,slug").eq("library_id", libraryId).order("version", { ascending: false }).limit(500),
    client.from("questionnaires").select("id,library_id,code,status,row_version,current_draft_version_id,current_published_version_id").eq("library_id", libraryId).order("code").limit(100),
    client.from("questionnaire_versions").select("id,questionnaire_id,version,status,row_version,title_fr,title_ar").eq("library_id", libraryId).order("version", { ascending: false }).limit(300),
    client.from("question_rules").select("id,library_id,rule_key,status,row_version,current_draft_version_id,current_published_version_id").eq("library_id", libraryId).order("rule_key").limit(200),
    client.from("question_rule_versions").select("id,rule_id,version,status,row_version,actions").eq("library_id", libraryId).order("version", { ascending: false }).limit(400),
    client.from("question_bank_questions").select("id,library_id,question_key,status,current_draft_version_id,current_published_version_id").eq("library_id", libraryId).order("question_key").limit(200),
    client.from("question_versions").select("id,question_id,version,status,label_fr,label_ar,help_fr,help_ar,answer_type,required_by_default,source_service_id").eq("library_id", libraryId).order("version", { ascending: false }).limit(400),
    client.from("questionnaire_version_questions").select("questionnaire_version_id,question_version_id,sort_order").eq("library_id", libraryId).order("sort_order").limit(800),
    client.from("catalog_categories").select("id,library_id,code,status,row_version,current_draft_version_id,current_published_version_id").eq("library_id", libraryId).order("code").limit(100),
    client.from("catalog_category_versions").select("id,category_id,name_fr,name_ar,status,row_version").eq("library_id", libraryId).limit(200),
    client.from("catalog_subcategories").select("id,library_id,category_id,code,status,row_version,current_draft_version_id,current_published_version_id").eq("library_id", libraryId).order("code").limit(200),
    client.from("catalog_subcategory_versions").select("id,subcategory_id,name_fr,name_ar,status,row_version").eq("library_id", libraryId).limit(400),
    client.from("catalog_releases").select("id,library_id,release_key,status").eq("library_id", libraryId).order("created_at", { ascending: false }).limit(50),
    client.from("catalog_change_requests").select("id,status").eq("library_id", libraryId).eq("status", "REJECTED").limit(50),
  ]);
  if (libraryResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const library = z.array(libraryRow).max(1).safeParse(libraryResult.data ?? []);
  if (!library.success || !library.data[0]) return { status: "error", reason: "FORBIDDEN" };
  if (library.data[0].id !== libraryId) return { status: "error", reason: "FORBIDDEN" };
  const optional = <T,>(result: { data: unknown; error: unknown }, schema: z.ZodType<T[]>) => {
    if (result.error) return [] as T[];
    const parsed = schema.safeParse(result.data ?? []);
    return parsed.success ? parsed.data : [];
  };
  const libraryVersions = optional(libraryVersionsResult, z.array(libraryVersionRow));
  const services = optional(servicesResult, z.array(serviceRow));
  const serviceVersions = optional(serviceVersionsResult, z.array(serviceVersionRow));
  const questionnaires = optional(questionnairesResult, z.array(questionnaireRow));
  const questionnaireVersions = optional(questionnaireVersionsResult, z.array(questionnaireVersionRow));
  const rules = optional(rulesResult, z.array(ruleRow));
  const ruleVersions = optional(ruleVersionsResult, z.array(ruleVersionRow));
  const questions = optional(questionsResult, z.array(questionRow));
  const questionVersions = optional(questionVersionsResult, z.array(questionVersionRow));
  const questionnaireQuestions = optional(questionnaireQuestionsResult, z.array(questionnaireQuestionRow));
  const categoryItems = optional(categoriesResult, z.array(categoryRow));
  const categoryVersions = optional(categoryVersionsResult, z.array(categoryVersionRow));
  const subcategoryItems = optional(subcategoriesResult, z.array(subcategoryRow));
  const subcategoryVersions = optional(subcategoryVersionsResult, z.array(subcategoryVersionRow));
  const releases = optional(releasesResult, z.array(releaseRow));
  const changes = optional(changesResult, z.array(changeRow));
  const locale = input.locale;
  const namedLibrary = libraryVersions.find((item) => item.id === library.data[0]!.current_published_version_id) ?? libraryVersions.find((item) => item.id === library.data[0]!.current_draft_version_id) ?? libraryVersions[0];
  const q = "";
  const pickName = (version: { name_fr: string; name_ar: string } | undefined, fallback: string) => version ? (locale === "ar" ? version.name_ar : version.name_fr) : fallback;
  const namedCategory = (item: z.infer<typeof categoryRow>) => pickName(categoryVersions.find((value) => value.id === item.current_published_version_id) ?? categoryVersions.find((value) => value.id === item.current_draft_version_id), item.code);
  const namedSubcategory = (item: z.infer<typeof subcategoryRow>) => pickName(subcategoryVersions.find((value) => value.id === item.current_published_version_id) ?? subcategoryVersions.find((value) => value.id === item.current_draft_version_id), item.code);
  const categories: FranchiseCategoryNode[] = categoryItems.filter((item) => item.library_id === libraryId).map((item) => {
    const version = categoryVersions.find((value) => value.id === item.current_draft_version_id) ?? categoryVersions.find((value) => value.id === item.current_published_version_id);
    return {
      id: item.id,
      title: namedCategory(item),
      status: version?.status ?? item.status,
      draftVersionId: item.current_draft_version_id,
      identityRowVersion: item.row_version,
      versionRowVersion: version?.row_version,
      children: subcategoryItems.filter((child) => child.category_id === item.id && child.library_id === libraryId).map((child) => {
        const childVersion = subcategoryVersions.find((value) => value.id === child.current_draft_version_id) ?? subcategoryVersions.find((value) => value.id === child.current_published_version_id);
        return {
          id: child.id,
          title: namedSubcategory(child),
          status: childVersion?.status ?? child.status,
          draftVersionId: child.current_draft_version_id,
          identityRowVersion: child.row_version,
          versionRowVersion: childVersion?.row_version,
        };
      }),
    };
  });
  const serviceRows: FranchiseCatalogRow[] = services.filter((item) => item.library_id === libraryId).map((item) => {
    const version = serviceVersions.find((value) => value.id === item.current_draft_version_id) ?? serviceVersions.find((value) => value.id === item.current_published_version_id);
    const subcategory = subcategoryItems.find((value) => value.id === item.primary_subcategory_id);
    const category = subcategory ? categoryItems.find((value) => value.id === subcategory.category_id) : undefined;
    return {
      id: item.id,
      kind: "SERVICE",
      title: version ? (locale === "ar" ? version.name_ar : version.name_fr) : item.code,
      code: item.code,
      status: version?.status ?? item.status,
      versionLabel: version ? `v${version.version}` : null,
      href: `/${locale}/franchise/services/${item.id}${q}`,
      category: category ? namedCategory(category) : null,
      subcategory: subcategory ? namedSubcategory(subcategory) : null,
      subcategoryId: item.primary_subcategory_id,
      description: version ? (locale === "ar" ? version.short_description_ar : version.short_description_fr) : null,
      nameFr: version?.name_fr ?? null,
      nameAr: version?.name_ar ?? null,
      command: version ? {
        draftVersionId: version.id,
        identityRowVersion: item.row_version,
        versionRowVersion: version.row_version,
        slug: version.slug || item.slug,
        descriptionFr: version.short_description_fr,
        descriptionAr: version.short_description_ar,
        longDescriptionFr: version.long_description_fr,
        longDescriptionAr: version.long_description_ar,
        serviceType: version.service_type,
        unitLabelFr: version.unit_label_fr,
        unitLabelAr: version.unit_label_ar,
        creditEligible: version.credit_eligible,
        volumeEligible: version.volume_eligible,
        recurringEligible: version.recurring_eligible,
        trialEligible: version.trial_eligible,
        rfqRequired: version.rfq_required,
        fixedFulfillmentAllowed: version.fixed_fulfillment_allowed,
        baseCurrency: version.base_currency,
        sortOrder: version.sort_order,
        fulfillmentConfig: version.fulfillment_config,
        visibilityRules: version.visibility_rules,
        sensitive: version.sensitive,
      } : null,
    };
  });
  const questionnaireRows: FranchiseCatalogRow[] = questionnaires.filter((item) => item.library_id === libraryId).map((item) => {
    const version = questionnaireVersions.find((value) => value.id === item.current_published_version_id) ?? questionnaireVersions.find((value) => value.id === item.current_draft_version_id);
    return {
      id: item.id,
      kind: "QUESTIONNAIRE",
      title: version ? (locale === "ar" ? version.title_ar : version.title_fr) : item.code,
      code: item.code,
      status: version?.status ?? item.status,
      versionLabel: version ? `v${version.version}` : null,
      href: `/${locale}/franchise/questionnaires/${item.id}${q}`,
      category: null,
      subcategory: null,
      subcategoryId: null,
      description: null,
      nameFr: version?.title_fr ?? null,
      nameAr: version?.title_ar ?? null,
      questionnaireVersionId: version?.id ?? null,
      draftVersionId: version?.id ?? null,
      identityRowVersion: item.row_version,
      versionRowVersion: version?.row_version ?? null,
    };
  });
  const ruleRows: FranchiseCatalogRow[] = rules.filter((item) => item.library_id === libraryId).map((item) => {
    const version = ruleVersions.find((value) => value.id === item.current_published_version_id) ?? ruleVersions.find((value) => value.id === item.current_draft_version_id);
    return {
      id: item.id,
      kind: "RULE",
      title: item.rule_key,
      code: item.rule_key,
      status: version?.status ?? item.status,
      versionLabel: version ? `v${version.version}` : null,
      href: `/${locale}/franchise/regles/${item.id}${q}`,
      category: null,
      subcategory: null,
      subcategoryId: null,
      description: null,
      nameFr: null,
      nameAr: null,
      draftVersionId: version?.id ?? null,
      identityRowVersion: item.row_version,
      versionRowVersion: version?.row_version ?? null,
      ruleActions: Array.isArray(version?.actions) ? version.actions : [],
    };
  });
  const questionByVersion = new Map(questionVersions.map((item) => [item.id, item]));
  const questionnaireByVersion = new Map(questionnaireVersions.map((item) => [item.id, item.questionnaire_id]));
  const questionRows: FranchiseQuestionRow[] = questions.filter((item) => item.library_id === libraryId).map((item) => {
    const version = questionVersions.find((value) => value.id === item.current_published_version_id) ?? questionVersions.find((value) => value.id === item.current_draft_version_id);
    const linked = questionnaireQuestions.find((link) => questionByVersion.get(link.question_version_id)?.question_id === item.id);
    return {
      id: item.id,
      key: item.question_key,
      status: version?.status ?? item.status,
      label: version ? (locale === "ar" ? version.label_ar : version.label_fr) : item.question_key,
      help: version ? ((locale === "ar" ? version.help_ar : version.help_fr) ?? "") : "",
      labelFr: version?.label_fr,
      labelAr: version?.label_ar,
      helpFr: version?.help_fr ?? "",
      helpAr: version?.help_ar ?? "",
      versionId: version?.id ?? null,
      answerType: version?.answer_type ?? null,
      required: version?.required_by_default ?? false,
      questionnaireId: linked ? questionnaireByVersion.get(linked.questionnaire_version_id) ?? null : null,
    };
  });
  const all = [...serviceRows, ...questionnaireRows, ...ruleRows];
  const counts = {
    drafts: all.filter((item) => bucket(item.status) === "drafts").length,
    inReview: all.filter((item) => bucket(item.status) === "inReview").length,
    published: all.filter((item) => bucket(item.status) === "published").length,
    returns: changes.length,
  };
  return {
    status: "success",
    workspace: overlayFranchiseLibraryDemo({
      mandate: {
        franchiseId: selected.id,
        operatorCode: selected.operator_code,
        type: selected.franchise_type,
        libraryId,
        libraryCode: library.data[0].code,
        libraryName: namedLibrary ? (locale === "ar" ? namedLibrary.name_ar : namedLibrary.name_fr) : library.data[0].code,
        libraryStatus: library.data[0].status,
        libraryRowVersion: library.data[0].row_version,
        currentReleaseId: library.data[0].current_release_id,
        operatorOrganizationId: selected.operator_organization_id,
      },
      counts,
      categories,
      services: serviceRows,
      questionnaires: questionnaireRows,
      rules: ruleRows,
      questions: questionRows,
      releases: releases.filter((item) => item.library_id === libraryId).map((item) => ({ id: item.id, key: item.release_key, status: item.status })),
    }, locale, q),
  };
}
