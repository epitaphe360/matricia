import { existsSync } from "node:fs";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Browser, type Page } from "@playwright/test";

type Locale = "fr" | "ar";
type Surface = { route: string; heading: Record<Locale, string>; evidence?: Record<Locale, string> };

const clientSurfaces: Surface[] = [
  { route: "client/documents", heading: { fr: "Coffre documentaire transversal", ar: "خزنة المستندات المشتركة" }, evidence: { fr: "Chaque liaison exige une authentification renforcée", ar: "تتطلب كل وصلة مصادقة قوية" } },
  { route: "client/portefeuille", heading: { fr: "Portefeuille Client", ar: "محفظة العميل" }, evidence: { fr: "Centres de coûts", ar: "مراكز التكلفة" } },
  { route: "client/recompenses", heading: { fr: "Récompenses, parrainage et ROI", ar: "المكافآت والإحالة والعائد" }, evidence: { fr: "Tous les montants et crédits restent en entiers exacts", ar: "تبقى جميع المبالغ والأرصدة أعداداً صحيحة دقيقة" } },
  { route: "client/questionnaires", heading: { fr: "Mes questionnaires", ar: "استبياناتي" }, evidence: { fr: "Enregistrement sécurisé", ar: "حفظ آمن" } },
];

const franchiseSurfaces: Surface[] = [
  { route: "franchise/relances", heading: { fr: "Relances automatiques", ar: "المتابعات التلقائية" }, evidence: { fr: "Ce moteur ne change jamais le pipeline", ar: "لا يغيّر هذا المحرك مسار التحويل" } },
  { route: "franchise/digest", heading: { fr: "Résumé quotidien", ar: "الملخص اليومي" }, evidence: { fr: "Ce résumé n’affiche aucun nom", ar: "لا يعرض هذا الملخص أي اسم" } },
];

const adminSurfaces: Surface[] = [
  { route: "administration/command-center", heading: { fr: "Toutes les pages d’administration", ar: "كل صفحات الإدارة" }, evidence: { fr: "Actions sensibles", ar: "إجراءات حسّاسة" } },
  { route: "administration/approbations-finance", heading: { fr: "Approbations métier et commissions", ar: "موافقات الأعمال والعمولات" }, evidence: { fr: "réconciliation strictement un-à-un", ar: "مطابقة واحد لواحد" } },
  { route: "administration/finance", heading: { fr: "Paiements et abonnements", ar: "المدفوعات والاشتراكات" }, evidence: { fr: "À traiter", ar: "يتطلب المعالجة" } },
  { route: "administration/incitations", heading: { fr: "Récompenses, badges et parrainage", ar: "المكافآت والشارات والإحالة" }, evidence: { fr: "Contrôle sensible", ar: "التحكم الحساس" } },
  { route: "administration/clonage", heading: { fr: "Clonage de contenu avec provenance", ar: "استنساخ المحتوى مع المصدر" }, evidence: { fr: "sans modifier la source", ar: "دون تعديل المصدر" } },
  { route: "administration/questionnaires/analytique", heading: { fr: "Abandons des questionnaires", ar: "التخلي عن الاستبيانات" }, evidence: { fr: "Confidentialité garantie", ar: "خصوصية مضمونة" } },
  { route: "administration/anti-abus", heading: { fr: "Détection transversale des abus", ar: "مكافحة إساءة الاستخدام" }, evidence: { fr: "revue humaine avant décision", ar: "مراجعة بشرية قبل القرار" } },
  { route: "administration/operations", heading: { fr: "Notifications, audit et Outbox", ar: "الإشعارات والتدقيق وصندوق الأحداث" } },
];

async function openAuthenticated(browser: Browser, storageState: string, locale: Locale, mobile: boolean) {
  const context = await browser.newContext({
    baseURL: process.env.E2E_BASE_URL ?? "http://localhost:5173",
    storageState,
    locale: locale === "ar" ? "ar-MA" : "fr-MA",
    timezoneId: "Africa/Casablanca",
    viewport: mobile ? { width: 360, height: 800 } : { width: 1280, height: 900 },
  });
  return { context, page: await context.newPage() };
}

async function assertSurface(page: Page, locale: Locale, surface: Surface) {
  await page.goto(`/${locale}/${surface.route}`);
  await expect(page).toHaveURL(new RegExp(`/${locale}/${surface.route}/?$`));
  await expect(page.locator("html")).toHaveAttribute("lang", locale);
  await expect(page.locator("html")).toHaveAttribute("dir", locale === "ar" ? "rtl" : "ltr");
  await expect(page.getByRole("heading", { level: 1, name: surface.heading[locale] })).toBeVisible();
  if (surface.evidence) await expect(page.getByText(surface.evidence[locale], { exact: false }).first()).toBeVisible();
  const foreignOrganization = process.env.E2E_FOREIGN_ORGANIZATION_NAME;
  if (foreignOrganization) await expect(page.locator("body")).not.toContainText(foreignOrganization);
  const dimensions = await page.evaluate(() => ({ viewport: document.documentElement.clientWidth, content: document.documentElement.scrollWidth }));
  expect(dimensions.content).toBeLessThanOrEqual(dimensions.viewport);
  await page.keyboard.press("Tab");
  await expect(page.locator(":focus")).toBeVisible();
  const audit = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"]).analyze();
  expect(audit.violations.map(({ id, impact, nodes }) => ({ id, impact, targets: nodes.flatMap((node) => node.target) }))).toEqual([]);
}

for (const locale of ["fr", "ar"] as const) {
  test(`${locale.toUpperCase()} Client transversal controls are isolated, responsive and accessible`, async ({ browser }, testInfo) => {
    const state = process.env.E2E_CLIENT_STORAGE_STATE;
    test.skip(!state || !existsSync(state), "E2E_CLIENT_STORAGE_STATE must reference a generated authenticated state");
    const { context, page } = await openAuthenticated(browser, state!, locale, testInfo.project.name.includes("mobile"));
    try { for (const surface of clientSurfaces) await test.step(surface.route, () => assertSurface(page, locale, surface)); }
    finally { await context.close(); }
  });

  test(`${locale.toUpperCase()} Franchise CRM and digest are isolated, responsive and accessible`, async ({ browser }, testInfo) => {
    const state = process.env.E2E_FRANCHISE_STORAGE_STATE;
    test.skip(!state || !existsSync(state), "E2E_FRANCHISE_STORAGE_STATE must reference a generated authenticated state");
    const { context, page } = await openAuthenticated(browser, state!, locale, testInfo.project.name.includes("mobile"));
    try { for (const surface of franchiseSurfaces) await test.step(surface.route, () => assertSurface(page, locale, surface)); }
    finally { await context.close(); }
  });

  test(`${locale.toUpperCase()} Admin transversal queues are least-privilege, responsive and accessible`, async ({ browser }, testInfo) => {
    const state = process.env.E2E_ADMIN_STORAGE_STATE;
    test.skip(!state || !existsSync(state), "E2E_ADMIN_STORAGE_STATE must reference a generated authenticated state");
    const { context, page } = await openAuthenticated(browser, state!, locale, testInfo.project.name.includes("mobile"));
    try { for (const surface of adminSurfaces) await test.step(surface.route, () => assertSurface(page, locale, surface)); }
    finally { await context.close(); }
  });
}
