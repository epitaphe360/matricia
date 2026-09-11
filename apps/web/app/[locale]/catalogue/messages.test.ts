import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ list: vi.fn(), search: vi.fn(), get: vi.fn() }));
vi.mock("@/lib/catalogue/repository", () => ({ listPublishedLibraries: mocks.list, searchPublishedCatalog: mocks.search, getPublishedCatalogService: mocks.get }));
vi.mock("@/lib/i18n/locale", () => ({ isLocale: (value: string) => value === "fr" || value === "ar" }));
vi.mock("@/lib/catalogue/model", async () => await import("../../../lib/catalogue/model"));
vi.mock("@/lib/utils", () => ({ cn: (...values: unknown[]) => values.filter(Boolean).join(" ") }));
vi.mock("@/components/ui/button", () => ({ buttonVariants: () => "button" }));
vi.mock("@/components/ui/badge", async () => {
  const React = await import("react");
  return { Badge: ({ children, ...props }: React.ComponentProps<"span">) => React.createElement("span", props, children) };
});
vi.mock("@/components/ui/alert", async () => {
  const React = await import("react");
  const component = (tag: "div" | "strong") => {
    const TestComponent = ({ children, ...props }: React.ComponentProps<"div">) => React.createElement(tag, props, children);
    TestComponent.displayName = `Test${tag}`;
    return TestComponent;
  };
  return { Alert: component("div"), AlertTitle: component("strong"), AlertDescription: component("div") };
});
vi.mock("@/components/ui/card", async () => {
  const React = await import("react");
  const component = ({ children, ...props }: React.ComponentProps<"div">) => React.createElement("div", props, children);
  return { Card: component, CardContent: component, CardDescription: component, CardHeader: component, CardTitle: component };
});
vi.mock("next/navigation", () => ({ notFound: vi.fn(), redirect: vi.fn() }));

import CatalogPage from "./page";
import PublishedServicePage from "./[librarySlug]/[serviceSlug]/page";
import { getCatalogMessages } from "./messages";

const releaseId = "11111111-1111-4111-8111-111111111111";
const library = { id: "22222222-2222-4222-8222-222222222222", releaseId, code: "IT", slug: "it", name: "Informatique", description: "Services numériques", iconKey: "computer", sortOrder: 1, categoryCount: 4, serviceCount: 20 };
const service = { id: "33333333-3333-4333-8333-333333333333", code: "IT-AUDIT", slug: "audit-si", name: "Audit SI", shortDescription: "État des lieux", longDescription: "État des lieux détaillé", serviceType: "AUDIT", unitLabel: "mission", creditEligible: false, volumeEligible: false, recurringEligible: false, trialEligible: true, rfqRequired: true, sortOrder: 1 };

beforeEach(() => {
  mocks.list.mockReset().mockResolvedValue({ status: "success", libraries: [library] });
  mocks.search.mockReset().mockResolvedValue({ status: "success", page: { library, total: 1, hasMore: false, nextCursor: null, categories: [{ id: "category-1", slug: "governance", name: "Gouvernance", subcategories: [{ id: "subcategory-1", slug: "audit", name: "Audit", services: [service] }] }] } });
  mocks.get.mockReset().mockResolvedValue({ status: "success", detail: { library, categoryName: "Gouvernance", subcategoryName: "Audit", service } });
});

describe("catalog messages", () => {
  it.each(["fr", "ar"] as const)("couvre les libellés et formats essentiels en %s", (locale) => {
    const copy = getCatalogMessages(locale);
    expect(copy.title.length).toBeGreaterThan(10);
    expect(copy.emptyLibrariesDescription.length).toBeGreaterThan(20);
    expect(copy.libraryCount(10)).toContain("10");
    expect(copy.libraryContents(4, 20)).toContain("20");
    expect(copy.moreResults.length).toBeGreaterThan(5);
  });

  it("fournit une traduction arabe native", () => {
    expect(getCatalogMessages("ar").title).toMatch(/[\u0600-\u06ff]/u);
    expect(getCatalogMessages("ar").serviceDetails).not.toBe(getCatalogMessages("fr").serviceDetails);
  });
});

describe("catalogue Client rendu", () => {
  it("conserve la release exacte dans les liens et expose une recherche nommée au clavier", async () => {
    const element = await CatalogPage({
      params: Promise.resolve({ locale: "fr" }),
      searchParams: Promise.resolve({ bibliotheque: "it", release: releaseId, q: "audit" }),
    });
    const html = renderToStaticMarkup(element);
    expect(html).toContain(`release=${releaseId}`);
    expect(html).toContain(`audit-si?release=${releaseId}`);
    expect(html).toContain('role="search"');
    expect(html).toContain('for="catalog-search"');
    expect(html).toContain('id="catalog-search"');
    expect(html).toContain("min-h-11");
    expect(html).toContain("px-4");
    expect(html).not.toMatch(/min-w-\[(?:[3-9]\d\d|\d{4,})px\]/u);
  });

  it("rend le parcours arabe et ne requiert pas de chargement des questions", async () => {
    const element = await CatalogPage({ params: Promise.resolve({ locale: "ar" }), searchParams: Promise.resolve({ bibliotheque: "it", release: releaseId }) });
    const html = renderToStaticMarkup(element);
    expect(html).toMatch(/[\u0600-\u06ff]/u);
    expect(mocks.search).toHaveBeenCalledWith({ locale: "ar", releaseId, search: "", cursor: null });
    expect(html).not.toMatch(/questionnaire|6000|6 000/iu);
  });

  it("rend le détail arabe localisé pour le snapshot explicitement demandé", async () => {
    const element = await PublishedServicePage({
      params: Promise.resolve({ locale: "ar", librarySlug: "it", serviceSlug: "audit-si" }),
      searchParams: Promise.resolve({ release: releaseId }),
    });
    const html = renderToStaticMarkup(element);
    expect(mocks.get).toHaveBeenCalledWith({ locale: "ar", releaseId, librarySlug: "it", serviceSlug: "audit-si" });
    expect(html).toContain("تدقيق");
    expect(html).not.toContain(">AUDIT</dd>");
    expect(html).toContain("min-h-11");
  });
});
