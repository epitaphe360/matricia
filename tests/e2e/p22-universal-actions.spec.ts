import { existsSync } from "node:fs";
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

const actors = [
  { name: "client", state: "E2E_CLIENT_STORAGE_STATE" },
  { name: "admin", state: "E2E_ADMIN_STORAGE_STATE" },
] as const;

for (const actor of actors) {
  for (const locale of ["fr", "ar"] as const) {
    test(`${actor.name} universal actions ${locale.toUpperCase()} is accessible and RTL-safe`, async ({ browser }, testInfo) => {
      const statePath = process.env[actor.state];
      test.skip(!statePath || !existsSync(statePath), `${actor.state} must reference a generated authenticated Playwright state`);
      const viewport = testInfo.project.name.includes("mobile") ? { width: 360, height: 800 } : { width: 1280, height: 900 };
      const context = await browser.newContext({ baseURL: process.env.E2E_BASE_URL ?? "http://localhost:5173", storageState: statePath!, viewport, locale: locale === "ar" ? "ar-MA" : "fr-MA", timezoneId: "Africa/Casablanca" });
      const page = await context.newPage();
      await page.goto(`/${locale}/actions`);
      await expect(page).toHaveURL(new RegExp(`/${locale}/actions/?$`));
      await expect(page.locator("html")).toHaveAttribute("lang", locale);
      await expect(page.locator("html")).toHaveAttribute("dir", locale === "ar" ? "rtl" : "ltr");
      await expect(page.getByRole("heading", { level: 1, name: locale === "ar" ? "الإجراءات المطلوبة" : "Actions requises" })).toBeVisible();
      await expect(page.getByRole("note")).toContainText(locale === "ar" ? "لا تطبق أي عقوبة تلقائياً" : "aucune sanction n’est appliquée automatiquement");
      await page.keyboard.press("Tab");
      await expect(page.locator(":focus")).toBeVisible();
      const size = await page.evaluate(() => ({ viewport: document.documentElement.clientWidth, content: document.documentElement.scrollWidth }));
      expect(size.content).toBeLessThanOrEqual(size.viewport);
      const audit = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"]).analyze();
      expect(audit.violations.map(({ id, impact, nodes }) => ({ id, impact, targets: nodes.flatMap((node) => node.target) }))).toEqual([]);
      await context.close();
    });
  }
}

