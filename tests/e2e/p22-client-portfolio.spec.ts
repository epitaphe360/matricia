import { existsSync } from "node:fs";
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

const headings = { fr: "Portefeuille Client", ar: "محفظة العميل" } as const;

for (const locale of ["fr", "ar"] as const) {
  test(`${locale.toUpperCase()} Client portfolio is isolated, keyboard reachable and accessible`, async ({ browser }, testInfo) => {
    const storageState = process.env.E2E_CLIENT_STORAGE_STATE;
    test.skip(!storageState || !existsSync(storageState), "E2E_CLIENT_STORAGE_STATE must reference a generated authenticated state");
    const viewport = testInfo.project.name.includes("mobile") ? { width: 360, height: 800 } : { width: 1280, height: 900 };
    const context = await browser.newContext({ baseURL: process.env.E2E_BASE_URL ?? "http://localhost:5173", storageState: storageState!, viewport, locale: locale === "ar" ? "ar-MA" : "fr-MA", timezoneId: "Africa/Casablanca" });
    const page = await context.newPage();
    try {
      await page.goto(`/${locale}/client/portefeuille`);
      await expect(page).toHaveURL(new RegExp(`/${locale}/client/portefeuille/?$`));
      await expect(page.locator("html")).toHaveAttribute("lang", locale);
      await expect(page.locator("html")).toHaveAttribute("dir", locale === "ar" ? "rtl" : "ltr");
      await expect(page.getByRole("heading", { level: 1, name: headings[locale] })).toBeVisible();
      const foreignOrganization = process.env.E2E_FOREIGN_ORGANIZATION_NAME;
      if (foreignOrganization) await expect(page.locator("body")).not.toContainText(foreignOrganization);
      const size = await page.evaluate(() => ({ viewport: document.documentElement.clientWidth, content: document.documentElement.scrollWidth }));
      expect(size.content).toBeLessThanOrEqual(size.viewport);
      await page.keyboard.press("Tab");
      await expect(page.locator(":focus")).toBeVisible();
      const audit = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"]).analyze();
      expect(audit.violations.map(({ id, impact, nodes }) => ({ id, impact, targets: nodes.flatMap(node => node.target) }))).toEqual([]);
    } finally { await context.close(); }
  });
}
