import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Locator, type Page } from "@playwright/test";

type Locale = "fr" | "ar";

const login = {
  fr: {
    title: "Connectez-vous à Matricia",
    email: "Adresse courriel professionnelle",
    submit: "Recevoir mon code",
  },
  ar: {
    title: "تسجيل الدخول إلى ماتريسيا",
    email: "البريد الإلكتروني المهني",
    submit: "إرسال الرمز",
  },
} as const;

const roleRoutes = [
  { role: "client", path: "client/missions" },
  { role: "sous-traitant", path: "sous-traitant/missions" },
  { role: "franchise", path: "franchise/gouvernance" },
  { role: "administration", path: "administration/command-center" },
] as const;

async function tabUntilFocused(page: Page, target: Locator, maximumTabs = 20) {
  for (let index = 0; index < maximumTabs; index += 1) {
    await page.keyboard.press("Tab");
    if (await target.evaluate((element) => element === document.activeElement)) return;
  }
  throw new Error(`Keyboard target was not reached after ${maximumTabs} Tab presses`);
}

async function expectAccessibleAt360(page: Page) {
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

for (const locale of ["fr", "ar"] as const) {
  for (const route of roleRoutes) {
    test(`${locale.toUpperCase()} protects the ${route.role} portal at 360 px`, async ({ page }) => {
      await page.setViewportSize({ width: 360, height: 800 });
      await page.goto(`/${locale}/${route.path}`);

      await expect(page).toHaveURL(new RegExp(`/${locale}/connexion/?$`));
      await expect(page.locator("html")).toHaveAttribute("lang", locale);
      await expect(page.locator("html")).toHaveAttribute("dir", locale === "ar" ? "rtl" : "ltr");
      await expect(page.getByRole("heading", { level: 1, name: login[locale].title })).toBeVisible();

      const email = page.getByRole("textbox", { name: login[locale].email });
      const submit = page.getByRole("button", { name: login[locale].submit });
      await tabUntilFocused(page, email);
      await expect(email).toBeFocused();
      await page.keyboard.press("Tab");
      await expect(submit).toBeFocused();

      await expectAccessibleAt360(page);
    });
  }
}
