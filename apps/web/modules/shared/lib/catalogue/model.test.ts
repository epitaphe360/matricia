import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ getUser: vi.fn(), rpc: vi.fn() }));
vi.mock("@/modules/shared/lib/supabase/server", () => ({
  getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, rpc: mocks.rpc }),
}));

import { decodeCatalogCursor, encodeCatalogCursor, parseCatalogQuery, serviceTypeLabel } from "./model";
import { getPublishedCatalogService, listPublishedLibraries, searchPublishedCatalog } from "./repository";

const releaseId = "11111111-1111-4111-8111-111111111111";
const libraryId = "22222222-2222-4222-8222-222222222222";
const serviceId = "33333333-3333-4333-8333-333333333333";
const categoryId = "44444444-4444-4444-8444-444444444444";
const subcategoryId = "55555555-5555-4555-8555-555555555555";
const library = { id: libraryId, code: "IT", slug: "it", name: "Informatique", description: "Services numériques", icon_key: "computer", sort_order: 1 };
const service = {
  id: serviceId, code: "IT-AUDIT", slug: "audit-si", name: "Audit SI", short_description: "État des lieux", long_description: "État des lieux détaillé",
  service_type: "AUDIT", unit_label: "mission", credit_eligible: false, volume_eligible: false, recurring_eligible: false, trial_eligible: true, rfq_required: true, sort_order: 1,
};
const listPayload = { locale: "fr", items: [{ release_id: releaseId, library, category_count: 4, service_count: 20 }] };
const searchItem = { service, category: { id: categoryId, slug: "gouvernance", name: "Gouvernance" }, subcategory: { id: subcategoryId, slug: "audit", name: "Audit" } };

beforeEach(() => {
  mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id: "user-1" } }, error: null });
  mocks.rpc.mockReset();
});

describe("catalog query", () => {
  it("normalise et borne les paramètres non fiables", () => {
    const cursor = encodeCatalogCursor({ sort_order: 1, name: "Audit SI", code: "IT-AUDIT", service_id: releaseId });
    const parsed = parseCatalogQuery({ releaseId: releaseId.toUpperCase(), librarySlug: ["it", "ignored"], search: `  ${"é".repeat(100)}   test `, cursor });
    expect(parsed).toMatchObject({ releaseId, librarySlug: "it", searchTooLong: true, cursorInvalid: false, cursor: { code: "IT-AUDIT" } });
    expect([...parsed.search]).toHaveLength(80);
  });

  it("rejette les identifiants non canoniques", () => {
    expect(parseCatalogQuery({ releaseId: "latest", librarySlug: "../draft", cursor: "%%%" })).toMatchObject({ releaseId: null, librarySlug: null, cursor: null, cursorInvalid: true });
    expect(decodeCatalogCursor("a".repeat(513))).toBeNull();
  });

  it("localise les types connus et masque les codes inconnus", () => {
    expect(serviceTypeLabel("MANAGED_SERVICE", "fr")).toBe("Service géré");
    expect(serviceTypeLabel("MANAGED_SERVICE", "ar")).toMatch(/[\u0600-\u06ff]/u);
    expect(serviceTypeLabel("FUTURE_INTERNAL_CODE", "ar")).toBe("خدمة متخصصة");
  });
});

describe("audience-strict catalog RPC repository", () => {
  it("n’appelle aucune RPC sans session authentifiée", async () => {
    mocks.getUser.mockResolvedValueOnce({ data: { user: null }, error: { message: "expired" } });
    await expect(listPublishedLibraries("fr")).resolves.toEqual({ status: "error", reason: "UNAUTHENTICATED" });
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("lit les bibliothèques uniquement par la RPC dédiée", async () => {
    mocks.rpc.mockResolvedValueOnce({ data: listPayload, error: null });
    await expect(listPublishedLibraries("fr")).resolves.toMatchObject({ status: "success", libraries: [{ releaseId, slug: "it", serviceCount: 20 }] });
    expect(mocks.rpc).toHaveBeenCalledWith("list_client_catalog_libraries", { p_locale: "fr" });
  });

  it("transmet la release exacte et impose une page de douze", async () => {
    mocks.rpc.mockResolvedValueOnce({ data: { locale: "fr", release_id: releaseId, page_size: 12, total: 1, has_more: false, next_cursor: null, library, category_count: 4, service_count: 20, services: [searchItem] }, error: null });
    const result = await searchPublishedCatalog({ locale: "fr", releaseId, search: "audit", cursor: null });
    expect(result).toMatchObject({ status: "success", page: { total: 1, categories: [{ subcategories: [{ services: [{ code: "IT-AUDIT" }] }] }] } });
    expect(mocks.rpc).toHaveBeenCalledWith("search_client_catalog_release", { p_release_id: releaseId, p_locale: "fr", p_search: "audit", p_cursor: null, p_page_size: 12 });
  });

  it("rejette une réponse qui change de snapshot ou dépasse douze services", async () => {
    mocks.rpc.mockResolvedValueOnce({ data: { locale: "fr", release_id: "22222222-2222-4222-8222-222222222222", page_size: 12, total: 13, has_more: true, next_cursor: { sort_order: 1, name: "Audit SI", code: "IT-AUDIT", service_id: releaseId }, library, category_count: 4, service_count: 20, services: Array.from({ length: 13 }, () => searchItem) }, error: null });
    await expect(searchPublishedCatalog({ locale: "fr", releaseId, search: "", cursor: null })).resolves.toEqual({ status: "error", reason: "INVALID_RESPONSE" });
  });

  it.each([
    { total: 0, has_more: false, next_cursor: null, label: "total inférieur aux services" },
    { total: 20, has_more: true, next_cursor: { sort_order: 1, name: "Audit SI", code: "IT-AUDIT", service_id: serviceId }, label: "suite annoncée avant une page pleine" },
    { total: 1, has_more: false, next_cursor: { sort_order: 1, name: "Audit SI", code: "IT-AUDIT", service_id: serviceId }, label: "curseur présent sans suite" },
  ])("rejette une cardinalité incohérente: $label", async ({ total, has_more, next_cursor }) => {
    mocks.rpc.mockResolvedValueOnce({ data: { locale: "fr", release_id: releaseId, page_size: 12, total, has_more, next_cursor, library, category_count: 4, service_count: 20, services: [searchItem] }, error: null });
    await expect(searchPublishedCatalog({ locale: "fr", releaseId, search: "", cursor: null })).resolves.toEqual({ status: "error", reason: "INVALID_RESPONSE" });
  });

  it("charge le détail dans la release demandée et vérifie le slug", async () => {
    mocks.rpc.mockResolvedValueOnce({ data: { locale: "ar", release_id: releaseId, library, category_count: 4, service_count: 20, service: { ...service, slug: "audit-si" }, category: searchItem.category, subcategory: searchItem.subcategory }, error: null });
    await expect(getPublishedCatalogService({ locale: "ar", releaseId, librarySlug: "it", serviceSlug: "audit-si" })).resolves.toMatchObject({ status: "success", detail: { library: { releaseId }, service: { slug: "audit-si" } } });
    expect(mocks.rpc).toHaveBeenCalledWith("get_client_catalog_service", { p_release_id: releaseId, p_locale: "ar", p_service_slug: "audit-si" });
  });
});
