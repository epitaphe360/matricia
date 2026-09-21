import { existsSync } from "node:fs";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Browser, type Page, type TestInfo } from "@playwright/test";

type Locale = "fr" | "ar";
type Role = "client" | "provider" | "franchise" | "admin";
type Surface = {
  route: string;
  heading: Record<Locale, string>;
};

const surfaces: Record<Role, readonly Surface[]> = {
  client: [
    { route: "client/diagnostics", heading: { fr: "Comprendre vos priorités", ar: "فهم أولوياتكم" } },
    { route: "client/demandes", heading: { fr: "Demandes et devis", ar: "الطلبات والعروض" } },
    { route: "client/missions", heading: { fr: "Contrats et missions", ar: "العقود والمهام" } },
    { route: "client/finances", heading: { fr: "Finances", ar: "المالية" } },
  ],
  provider: [
    { route: "sous-traitant/qualification", heading: { fr: "Qualification et capacité", ar: "التأهيل والقدرة" } },
    { route: "sous-traitant/devis", heading: { fr: "Invitations et devis", ar: "الدعوات وعروض الأسعار" } },
    { route: "sous-traitant/missions", heading: { fr: "Missions et livrables", ar: "المهام والتسليمات" } },
  ],
  franchise: [
    { route: "franchise/performance", heading: { fr: "CRM et performance", ar: "إدارة العلاقات والأداء" } },
    { route: "franchise/relances", heading: { fr: "Relances automatiques", ar: "المتابعات التلقائية" } },
    { route: "franchise/digest", heading: { fr: "Résumé quotidien", ar: "الملخص اليومي" } },
  ],
  admin: [
    { route: "administration/command-center", heading: { fr: "Toutes les pages d’administration", ar: "كل صفحات الإدارة" } },
    { route: "administration/parcours", heading: { fr: "Diagnostics", ar: "التشخيصات" } },
    { route: "administration/entreprises", heading: { fr: "Organisations", ar: "المؤسسات" } },
    { route: "administration/finance", heading: { fr: "Paiements et abonnements", ar: "المدفوعات والاشتراكات" } },
    { route: "administration/operations", heading: { fr: "Notifications, audit et Outbox", ar: "الإشعارات والتدقيق وصندوق الأحداث" } },
  ],
};

const deniedSurfaces: Record<Role, readonly Surface[]> = {
  client: [surfaces.provider[0], surfaces.franchise[2], surfaces.admin[0]],
  provider: [surfaces.client[0], surfaces.admin[0]],
  franchise: [surfaces.client[1], surfaces.admin[1]],
  admin: [],
};

const stateVariables: Record<Role, string> = {
  client: "E2E_CLIENT_STORAGE_STATE",
  provider: "E2E_PROVIDER_STORAGE_STATE",
  franchise: "E2E_FRANCHISE_STORAGE_STATE",
  admin: "E2E_ADMIN_STORAGE_STATE",
};

function requireState(role: Role): string {
  const variable = stateVariables[role];
  const path = process.env[variable];
  if (!path || !existsSync(path)) {
    throw new Error(`${variable} must reference a generated sandbox authentication state`);
  }
  return path;
}

const states = Object.fromEntries(
  (Object.keys(stateVariables) as Role[]).map((role) => [role, requireState(role)]),
) as Record<Role, string>;

const baseURL = process.env.E2E_BASE_URL ?? "http://localhost:5173";
const target = new URL(baseURL);
if (!["localhost", "127.0.0.1", "::1"].includes(target.hostname)) {
  throw new Error("Authenticated route smoke is restricted to a local sandbox application URL");
}

async function createSession(browser: Browser, role: Role, locale: Locale, mobile: boolean) {
  const context = await browser.newContext({
    baseURL,
    storageState: states[role],
    locale: locale === "ar" ? "ar-MA" : "fr-MA",
    timezoneId: "Africa/Casablanca",
    viewport: mobile ? { width: 360, height: 800 } : { width: 1280, height: 900 },
  });
  return { context, page: await context.newPage() };
}

async function assertHealthyDocument(page: Page, locale: Locale, surface: Surface) {
  const pageErrors: string[] = [];
  const recordPageError = (error: Error) => pageErrors.push(error.message);
  page.on("pageerror", recordPageError);
  try {
    const response = await page.goto(`/${locale}/${surface.route}`, { waitUntil: "domcontentloaded" });
    expect(response, `No document response for /${locale}/${surface.route}`).not.toBeNull();
    expect(response!.status(), `Unexpected HTTP status for /${locale}/${surface.route}`).toBeLessThan(500);
    await expect(page).toHaveURL(new RegExp(`/${locale}/${surface.route}/?$`));
    await expect(page.locator("html")).toHaveAttribute("lang", locale);
    await expect(page.locator("html")).toHaveAttribute("dir", locale === "ar" ? "rtl" : "ltr");
    await expect(page.getByRole("heading", { level: 1, name: surface.heading[locale] })).toBeVisible();
    await expect(page.locator("body")).not.toContainText(/Application error|Internal Server Error|ChunkLoadError/u);
    expect((await page.locator("body").innerText()).trim().length).toBeGreaterThan(20);
    const dimensions = await page.evaluate(() => ({
      viewport: document.documentElement.clientWidth,
      content: document.documentElement.scrollWidth,
    }));
    expect(dimensions.content, `Horizontal overflow on /${locale}/${surface.route}`).toBeLessThanOrEqual(dimensions.viewport);
    expect(pageErrors, `Unhandled browser error on /${locale}/${surface.route}`).toEqual([]);
  } finally {
    page.off("pageerror", recordPageError);
  }
}

async function assertAllowed(page: Page, locale: Locale, surface: Surface) {
  await assertHealthyDocument(page, locale, surface);
  await expect(page.locator('[data-slot="alert"].text-destructive')).toHaveCount(0);
  const foreignOrganization = process.env.E2E_FOREIGN_ORGANIZATION_NAME;
  if (foreignOrganization) await expect(page.locator("body")).not.toContainText(foreignOrganization);
}

async function assertDenied(page: Page, locale: Locale, surface: Surface) {
  await assertHealthyDocument(page, locale, surface);
  await expect(page.locator('[data-slot="alert"].text-destructive')).toBeVisible();
  const foreignOrganization = process.env.E2E_FOREIGN_ORGANIZATION_NAME;
  if (foreignOrganization) await expect(page.locator("body")).not.toContainText(foreignOrganization);
}

async function attachSanitizedEvidence(
  testInfo: TestInfo,
  role: Role,
  locale: Locale,
  mobile: boolean,
) {
  await testInfo.attach("authenticated-route-smoke.json", {
    contentType: "application/json",
    body: Buffer.from(JSON.stringify({
      schemaVersion: 1,
      environment: "SANDBOX",
      role,
      locale,
      viewport: mobile ? { width: 360, height: 800 } : { width: 1280, height: 900 },
      allowedRoutes: surfaces[role].map(({ route }) => route),
      deniedRoutes: deniedSurfaces[role].map(({ route }) => route),
      assertions: ["authenticated", "localized-h1", "no-server-error", "no-blank-page", "no-horizontal-overflow", "cross-role-deny"],
    }, null, 2)),
  });
}

for (const locale of ["fr", "ar"] as const) {
  for (const role of Object.keys(surfaces) as Role[]) {
    test(`${locale.toUpperCase()} ${role} authenticated route smoke is responsive and role-isolated`, async ({ browser }, testInfo) => {
      const mobile = testInfo.project.name.includes("mobile");
      const { context, page } = await createSession(browser, role, locale, mobile);
      try {
        for (const surface of surfaces[role]) {
          await test.step(`ALLOW ${surface.route}`, () => assertAllowed(page, locale, surface));
        }
        for (const surface of deniedSurfaces[role]) {
          await test.step(`DENY ${surface.route}`, () => assertDenied(page, locale, surface));
        }
        const audit = await new AxeBuilder({ page })
          .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
          .analyze();
        expect(audit.violations.map(({ id, impact, nodes }) => ({
          id,
          impact,
          targets: nodes.flatMap((node) => node.target),
        })), "Automated accessibility violations").toEqual([]);
        await attachSanitizedEvidence(testInfo, role, locale, mobile);
      } finally {
        await context.close();
      }
    });
  }
}
