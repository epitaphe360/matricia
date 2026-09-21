import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import type { CatalogCursor, CatalogSearchPage, PublishedCategoryGroup, PublishedLibrary, PublishedService, PublishedServiceDetail } from "./model";

type CatalogErrorCode = "UNAUTHENTICATED" | "CATALOG_UNAVAILABLE" | "INVALID_RESPONSE";
export type CatalogLibrariesResult = { status: "success"; libraries: PublishedLibrary[] } | { status: "error"; reason: CatalogErrorCode };
export type CatalogSearchResult = { status: "success"; page: CatalogSearchPage | null } | { status: "error"; reason: CatalogErrorCode };
export type CatalogServiceResult = { status: "success"; detail: PublishedServiceDetail | null } | { status: "error"; reason: CatalogErrorCode };

// Additive SQL contract: authenticated-only SECURITY DEFINER functions must call
// private.can_read_catalog_release(release_id, auth.uid()), with no draft-scope alternative.
// Search limits page_size to 12/search to 80 code points, uses a validated keyset cursor,
// and reads each object_type separately.
const RPC = { libraries: "list_client_catalog_libraries", search: "search_client_catalog_release", service: "get_client_catalog_service" } as const;

function isRecord(value: unknown): value is Record<string, unknown> { return Boolean(value) && typeof value === "object" && !Array.isArray(value); }
function string(value: unknown): string | null { return typeof value === "string" ? value : null; }
function integer(value: unknown): number | null { return Number.isSafeInteger(value) ? value as number : null; }
function boolean(value: unknown): boolean | null { return typeof value === "boolean" ? value : null; }
function isUuid(value: string): boolean { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(value); }

function parseLibrary(value: unknown, releaseId: unknown, categoryCount: unknown, serviceCount: unknown): PublishedLibrary | null {
  if (!isRecord(value)) return null;
  const id = string(value.id); const parsedReleaseId = string(releaseId); const code = string(value.code); const slug = string(value.slug); const name = string(value.name);
  const description = string(value.description); const iconKey = string(value.icon_key); const sortOrder = integer(value.sort_order); const parsedCategoryCount = integer(categoryCount); const parsedServiceCount = integer(serviceCount);
  if (!id || !isUuid(id) || !parsedReleaseId || !isUuid(parsedReleaseId) || !code || !slug || !name || !description || !iconKey || sortOrder === null || parsedCategoryCount === null || parsedServiceCount === null || parsedCategoryCount < 0 || parsedServiceCount < 0) return null;
  return { id, releaseId: parsedReleaseId, code, slug, name, description, iconKey, sortOrder, categoryCount: parsedCategoryCount, serviceCount: parsedServiceCount };
}

function parseService(value: unknown): PublishedService | null {
  if (!isRecord(value)) return null;
  const id = string(value.id); const code = string(value.code); const slug = string(value.slug); const name = string(value.name); const shortDescription = string(value.short_description); const longDescription = string(value.long_description);
  const serviceType = string(value.service_type); const unitLabel = string(value.unit_label); const creditEligible = boolean(value.credit_eligible); const volumeEligible = boolean(value.volume_eligible);
  const recurringEligible = boolean(value.recurring_eligible); const trialEligible = boolean(value.trial_eligible); const rfqRequired = boolean(value.rfq_required);
  const sortOrder = integer(value.sort_order);
  if (!id || !isUuid(id) || !code || !slug || !name || !shortDescription || !longDescription || !serviceType || !unitLabel || creditEligible === null || volumeEligible === null || recurringEligible === null || trialEligible === null || rfqRequired === null || sortOrder === null || sortOrder < 1) return null;
  return { id, code, slug, name, shortDescription, longDescription, serviceType, unitLabel, creditEligible, volumeEligible, recurringEligible, trialEligible, rfqRequired, sortOrder };
}

function parseCursor(value: unknown): CatalogCursor | null {
  if (!isRecord(value)) return null;
  const sortOrder = integer(value.sort_order); const name = string(value.name); const code = string(value.code); const serviceId = string(value.service_id);
  if (sortOrder === null || sortOrder < 1 || !name || !code || !serviceId || !isUuid(serviceId) || Object.keys(value).sort().join(",") !== "code,name,service_id,sort_order") return null;
  return { sort_order: sortOrder, name, code, service_id: serviceId };
}

function groupSearchItems(value: unknown): { categories: PublishedCategoryGroup[]; orderedServices: PublishedService[] } | null {
  if (!Array.isArray(value)) return null;
  const categories = new Map<string, PublishedCategoryGroup>();
  const orderedServices: PublishedService[] = [];
  for (const item of value) {
    if (!isRecord(item) || !isRecord(item.category) || !isRecord(item.subcategory)) return null;
    const service = parseService(item.service); const categoryId = string(item.category.id); const categorySlug = string(item.category.slug); const categoryName = string(item.category.name);
    const subcategoryId = string(item.subcategory.id); const subcategorySlug = string(item.subcategory.slug); const subcategoryName = string(item.subcategory.name);
    if (!service || !categoryId || !isUuid(categoryId) || !categorySlug || !categoryName || !subcategoryId || !isUuid(subcategoryId) || !subcategorySlug || !subcategoryName) return null;
    orderedServices.push(service);
    let category = categories.get(categoryId);
    if (!category) { category = { id: categoryId, slug: categorySlug, name: categoryName, subcategories: [] }; categories.set(categoryId, category); }
    let subcategory = category.subcategories.find((candidate) => candidate.id === subcategoryId);
    if (!subcategory) { subcategory = { id: subcategoryId, slug: subcategorySlug, name: subcategoryName, services: [] }; category.subcategories.push(subcategory); }
    subcategory.services.push(service);
  }
  return { categories: [...categories.values()], orderedServices };
}

async function authenticatedClient() {
  const client = await getSupabaseServerClient();
  const { data, error } = await client.auth.getUser();
  return { client, authenticated: !error && Boolean(data.user) };
}

export async function listPublishedLibraries(locale: Locale): Promise<CatalogLibrariesResult> {
  const { client, authenticated } = await authenticatedClient();
  if (!authenticated) return { status: "error", reason: "UNAUTHENTICATED" };
  const { data, error } = await client.rpc(RPC.libraries, { p_locale: locale });
  if (error) return { status: "error", reason: "CATALOG_UNAVAILABLE" };
  if (!isRecord(data) || data.locale !== locale || !Array.isArray(data.items)) return { status: "error", reason: "INVALID_RESPONSE" };
  const libraries = data.items.map((item) => isRecord(item) ? parseLibrary(item.library, item.release_id, item.category_count, item.service_count) : null);
  if (libraries.some((library) => !library) || libraries.length > 10) return { status: "error", reason: "INVALID_RESPONSE" };
  return { status: "success", libraries: libraries as PublishedLibrary[] };
}

export async function searchPublishedCatalog(input: { locale: Locale; releaseId: string; search: string; cursor: CatalogCursor | null }): Promise<CatalogSearchResult> {
  const { client, authenticated } = await authenticatedClient();
  if (!authenticated) return { status: "error", reason: "UNAUTHENTICATED" };
  const { data, error } = await client.rpc(RPC.search, { p_release_id: input.releaseId, p_locale: input.locale, p_search: input.search, p_cursor: input.cursor, p_page_size: 12 });
  if (error) return { status: "error", reason: "CATALOG_UNAVAILABLE" };
  if (data === null) return { status: "success", page: null };
  if (!isRecord(data)) return { status: "error", reason: "INVALID_RESPONSE" };
  const releaseId = string(data.release_id); const pageSize = integer(data.page_size); const total = integer(data.total); const hasMore = boolean(data.has_more);
  const library = parseLibrary(data.library, releaseId, data.category_count, data.service_count); const grouped = groupSearchItems(data.services);
  const nextCursor = data.next_cursor === null ? null : parseCursor(data.next_cursor);
  if (data.locale !== input.locale || !library || !grouped || total === null || pageSize !== 12 || hasMore === null || total < 0 || (data.next_cursor !== null && !nextCursor)) return { status: "error", reason: "INVALID_RESPONSE" };
  const returned = grouped.orderedServices.length; const returnedIds = grouped.orderedServices.map((service) => service.id);
  const last = grouped.orderedServices.at(-1);
  const cursorMatchesLast = !nextCursor || Boolean(last && nextCursor.sort_order === last.sortOrder && nextCursor.name === last.name && nextCursor.code === last.code && nextCursor.service_id === last.id);
  if (returned > 12 || total < returned || new Set(returnedIds).size !== returnedIds.length || (total === 0 && returned !== 0)
    || hasMore !== Boolean(nextCursor) || (hasMore && returned !== 12) || !cursorMatchesLast || library.releaseId !== input.releaseId) return { status: "error", reason: "INVALID_RESPONSE" };
  return { status: "success", page: { library, categories: grouped.categories, total, hasMore, nextCursor } };
}

export async function getPublishedCatalogService(input: { locale: Locale; releaseId: string; librarySlug: string; serviceSlug: string }): Promise<CatalogServiceResult> {
  const { client, authenticated } = await authenticatedClient();
  if (!authenticated) return { status: "error", reason: "UNAUTHENTICATED" };
  const { data, error } = await client.rpc(RPC.service, { p_release_id: input.releaseId, p_locale: input.locale, p_service_slug: input.serviceSlug });
  if (error) return { status: "error", reason: "CATALOG_UNAVAILABLE" };
  if (data === null) return { status: "success", detail: null };
  if (!isRecord(data)) return { status: "error", reason: "INVALID_RESPONSE" };
  const releaseId = string(data.release_id); const library = parseLibrary(data.library, releaseId, data.category_count, data.service_count); const service = parseService(data.service);
  const categoryName = isRecord(data.category) ? string(data.category.name) : null; const subcategoryName = isRecord(data.subcategory) ? string(data.subcategory.name) : null;
  if (data.locale !== input.locale || !library || !service || !categoryName || !subcategoryName || library.releaseId !== input.releaseId || library.slug !== input.librarySlug || service.slug !== input.serviceSlug) return { status: "error", reason: "INVALID_RESPONSE" };
  return { status: "success", detail: { library, categoryName, subcategoryName, service } };
}
