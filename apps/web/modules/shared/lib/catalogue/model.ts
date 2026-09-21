import { Buffer } from "node:buffer";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

export const CATALOG_SEARCH_MAX_LENGTH = 80;
export const CATALOG_PAGE_SIZE = 12;
export const CATALOG_CURSOR_MAX_LENGTH = 512;

export type PublishedLibrary = {
  id: string; releaseId: string; code: string; slug: string; name: string; description: string;
  iconKey: string; sortOrder: number; categoryCount: number; serviceCount: number;
};

export type PublishedService = {
  id: string; code: string; slug: string; name: string; shortDescription: string; longDescription: string;
  serviceType: string; unitLabel: string; creditEligible: boolean; volumeEligible: boolean;
  recurringEligible: boolean; trialEligible: boolean; rfqRequired: boolean; sortOrder: number;
};

export type PublishedSubcategoryGroup = { id: string; slug: string; name: string; services: PublishedService[] };
export type PublishedCategoryGroup = { id: string; slug: string; name: string; subcategories: PublishedSubcategoryGroup[] };
export type CatalogCursor = { sort_order: number; name: string; code: string; service_id: string };
export type CatalogSearchPage = { library: PublishedLibrary; categories: PublishedCategoryGroup[]; total: number; hasMore: boolean; nextCursor: CatalogCursor | null };
export type PublishedServiceDetail = { library: PublishedLibrary; categoryName: string; subcategoryName: string; service: PublishedService };
export type CatalogQuery = { releaseId: string | null; librarySlug: string | null; search: string; searchTooLong: boolean; cursor: CatalogCursor | null; cursorInvalid: boolean };

export function parseCatalogQuery(input: { releaseId?: string | string[]; librarySlug?: string | string[]; search?: string | string[]; cursor?: string | string[] }): CatalogQuery {
  const releaseCandidate = Array.isArray(input.releaseId) ? input.releaseId[0] : input.releaseId;
  const libraryCandidate = Array.isArray(input.librarySlug) ? input.librarySlug[0] : input.librarySlug;
  const rawSearch = Array.isArray(input.search) ? input.search[0] : input.search;
  const rawCursor = Array.isArray(input.cursor) ? input.cursor[0] : input.cursor;
  const normalizedSearch = (rawSearch ?? "").trim().replace(/\s+/gu, " ");
  const cursor = decodeCatalogCursor(rawCursor);
  return {
    releaseId: releaseCandidate && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(releaseCandidate) ? releaseCandidate.toLowerCase() : null,
    librarySlug: libraryCandidate && /^[a-z0-9]+(?:-[a-z0-9]+)*$/u.test(libraryCandidate) && libraryCandidate.length <= 80 ? libraryCandidate : null,
    search: [...normalizedSearch].slice(0, CATALOG_SEARCH_MAX_LENGTH).join(""),
    searchTooLong: [...normalizedSearch].length > CATALOG_SEARCH_MAX_LENGTH,
    cursor,
    cursorInvalid: Boolean(rawCursor) && cursor === null,
  };
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(value);
}

export function decodeCatalogCursor(value: string | null | undefined): CatalogCursor | null {
  if (!value || value.length > CATALOG_CURSOR_MAX_LENGTH || !/^[A-Za-z0-9_-]+$/u.test(value)) return null;
  try {
    const parsed = JSON.parse(Buffer.from(value, "base64url").toString("utf8")) as unknown;
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
    const cursor = parsed as Record<string, unknown>;
    if (!Number.isSafeInteger(cursor.sort_order) || (cursor.sort_order as number) < 1 || (cursor.sort_order as number) > 2_147_483_647
      || typeof cursor.name !== "string" || [...cursor.name].length < 1 || [...cursor.name].length > 240
      || typeof cursor.code !== "string" || !/^[A-Z][A-Z0-9_-]{1,79}$/u.test(cursor.code)
      || typeof cursor.service_id !== "string" || !isUuid(cursor.service_id)
      || Object.keys(cursor).sort().join(",") !== "code,name,service_id,sort_order") return null;
    return { sort_order: cursor.sort_order as number, name: cursor.name, code: cursor.code, service_id: cursor.service_id };
  } catch { return null; }
}

export function encodeCatalogCursor(cursor: CatalogCursor): string {
  return Buffer.from(JSON.stringify(cursor), "utf8").toString("base64url");
}

const serviceTypes = {
  ADVISORY: ["Conseil", "استشارة"], AUDIT: ["Audit", "تدقيق"], IMPLEMENTATION: ["Mise en œuvre", "تنفيذ"], MANAGED_SERVICE: ["Service géré", "خدمة مُدارة"],
  CREATIVE_TECH: ["Création numérique", "إبداع رقمي"], SOFTWARE_PROJECT: ["Projet logiciel", "مشروع برمجي"], DATA_PROJECT: ["Projet données", "مشروع بيانات"], AI_PROJECT: ["Projet IA", "مشروع ذكاء اصطناعي"],
  CREATIVE_STRATEGY: ["Stratégie créative", "استراتيجية إبداعية"], CREATIVE: ["Création", "إبداع"], CONTENT: ["Contenu", "محتوى"], CONTENT_STRATEGY: ["Stratégie de contenu", "استراتيجية محتوى"],
  CAMPAIGN: ["Campagne", "حملة"], CREATIVE_PRODUCTION: ["Production créative", "إنتاج إبداعي"], EVENT: ["Événement", "فعالية"], PRODUCTION: ["Production", "إنتاج"],
  OUTSOURCING: ["Externalisation", "استعانة خارجية"], PROJECT: ["Projet", "مشروع"], AUDIT_SUPPORT: ["Accompagnement d’audit", "مواكبة التدقيق"], LEGAL_ADVISORY: ["Conseil juridique", "استشارة قانونية"],
  LEGAL_SERVICE: ["Service juridique", "خدمة قانونية"], COMPLIANCE: ["Conformité", "امتثال"], RECRUITMENT: ["Recrutement", "توظيف"], TRAINING: ["Formation", "تدريب"], SURVEY: ["Enquête", "استبيان"],
  RISK_AUDIT: ["Audit des risques", "تدقيق المخاطر"], INSURANCE_PLACEMENT: ["Placement d’assurance", "وساطة تأمين"], CLAIMS_MANAGEMENT: ["Gestion des sinistres", "إدارة المطالبات"], RISK_ADVISORY: ["Conseil en risques", "استشارة مخاطر"],
  PROCUREMENT: ["Achats", "مشتريات"], SOURCING: ["Sourcing", "بحث عن الموردين"], ENGINEERING: ["Ingénierie", "هندسة"], DESIGN_ENGINEERING: ["Conception et ingénierie", "تصميم وهندسة"],
  PROJECT_MANAGEMENT: ["Gestion de projet", "إدارة مشروع"], CONSTRUCTION: ["Construction", "بناء"], ENERGY_PROJECT: ["Projet énergétique", "مشروع طاقي"], COMPLIANCE_PROJECT: ["Projet de conformité", "مشروع امتثال"], RESEARCH: ["Étude", "دراسة"],
} as const;

export function serviceTypeLabel(serviceType: string, locale: Locale): string {
  const labels = serviceTypes[serviceType as keyof typeof serviceTypes];
  return labels?.[locale === "ar" ? 1 : 0] ?? (locale === "ar" ? "خدمة متخصصة" : "Service spécialisé");
}
