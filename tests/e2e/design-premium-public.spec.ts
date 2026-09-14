import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

const viewports = [
  { width: 1440, height: 1000 },
  { width: 768, height: 1024 },
  { width: 390, height: 844 },
  { width: 360, height: 800 },
];

for (const locale of ["fr", "ar"] as const) {
  for (const viewport of viewports) {
    test(`${locale} premium ${viewport.width}px reste lisible et accessible`, async ({ page }) => {
      await page.setViewportSize(viewport);
      for (const route of ["", "/diagnostic", "/besoin", "/fournisseur", "/connexion", "/a-propos", "/franchise", "/contact"]) {
        await page.goto(`/${locale}${route}`);
        await expect(page.locator("h1")).toHaveCount(1);
        const width = await page.evaluate(() => ({ client: document.documentElement.clientWidth, scroll: document.documentElement.scrollWidth }));
        expect(width.scroll).toBeLessThanOrEqual(width.client);
        const audit = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze();
        expect(audit.violations.map(item => item.id)).toEqual([]);
      }
    });
  }
}

test("le menu mobile se ferme avec Escape et rend le focus au déclencheur", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/fr");
  const trigger = page.locator('button[aria-controls="public-mobile-navigation"]');
  await trigger.click();
  await expect(trigger).toHaveAttribute("aria-expanded", "true");
  await page.keyboard.press("Escape");
  await expect(trigger).toHaveAttribute("aria-expanded", "false");
  await expect(trigger).toBeFocused();
});

test("le changement de langue conserve la route, les paramètres et le brouillon", async ({ page }) => {
  await page.setViewportSize({ width: 1200, height: 900 });
  await page.goto("/fr/diagnostic?source=design-test");
  await page.locator(".journey-choices button").first().click();
  await page.getByRole("button", { name: "Continuer" }).click();
  await page.getByRole("link", { name: /AR|العربية/ }).first().click();
  await expect(page).toHaveURL(/\/ar\/diagnostic\?source=design-test/);
  await expect(page.locator(".journey-progress")).toContainText(/2.*7/);
});

test("les choix simples et les champs libres exposent leur sémantique", async ({ page }) => {
  await page.goto("/fr/diagnostic");
  await page.evaluate(() => localStorage.removeItem("matricia.public-diagnostic"));
  await page.reload();
  await page.locator(".journey-choices button").first().click();
  await page.getByRole("button", { name: "Continuer" }).click();
  const group = page.getByRole("radiogroup");
  await expect(group).toHaveAccessibleName(/secteur/i);
  await expect(group.getByRole("radio").first()).toHaveAttribute("aria-checked", /true|false/);
  await page.goto("/fr/besoin");
  await expect(page.locator("textarea")).toHaveAttribute("aria-labelledby", "need-question");
});
