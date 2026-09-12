import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";

type Locale = "fr" | "ar";

const login = {
  fr: { title: "Connectez-vous à Matricia", email: "Adresse courriel professionnelle" },
  ar: { title: "تسجيل الدخول إلى ماتريسيا", email: "البريد الإلكتروني المهني" },
} as const;

const routes = [
  "administration/marketing-autopilot",
  "franchise/performance",
  "administration/fiscalite-maroc",
] as const;

async function expectMobileAccessible(page: Page) {
  const dimensions = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    content: document.documentElement.scrollWidth,
  }));
  expect(dimensions.content).toBeLessThanOrEqual(dimensions.viewport);
  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
    .analyze();
  expect(results.violations.map(({ id, impact, nodes }) => ({
    id,
    impact,
    targets: nodes.flatMap((node) => node.target),
  })), "Automated accessibility violations").toEqual([]);
}

async function tabUntilFocused(page: Page, target: ReturnType<Page["locator"]>, maximumTabs = 12) {
  for (let index = 0; index < maximumTabs; index += 1) {
    await page.keyboard.press("Tab");
    if (await target.evaluate((element) => element === document.activeElement)) return;
  }
  throw new Error(`Keyboard target was not reached after ${maximumTabs} Tab presses`);
}

for (const locale of ["fr", "ar"] as const) {
  for (const route of routes) {
    test(`${locale.toUpperCase()} redirects anonymous ${route} at 360 px with keyboard and axe proof`, async ({ page }) => {
      await page.setViewportSize({ width: 360, height: 800 });
      await page.goto(`/${locale}/${route}`);

      await expect(page).toHaveURL(new RegExp(`/${locale}/connexion/?$`));
      await expect(page.locator("html")).toHaveAttribute("lang", locale);
      await expect(page.locator("html")).toHaveAttribute("dir", locale === "ar" ? "rtl" : "ltr");
      await expect(page.getByRole("heading", { level: 1, name: login[locale].title })).toBeVisible();
      const email = page.getByRole("textbox", { name: login[locale].email });
      await tabUntilFocused(page, email);
      await expect(email).toBeFocused();
      await page.keyboard.type("agent@example.invalid");
      await expect(email).toHaveValue("agent@example.invalid");
      await expectMobileAccessible(page);
    });
  }
}
