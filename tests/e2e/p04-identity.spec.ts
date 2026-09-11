import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

type Locale = "fr" | "ar";

const copy = {
  fr: {
    loginTitle: "Connectez-vous à Matricia",
    emailLabel: "Adresse courriel professionnelle",
    requestCode: "Recevoir mon code",
    invalidEmail: "Saisissez une adresse courriel valide.",
    codeLabel: "Code à 6 chiffres",
    sent: "Si cette adresse est admissible, un code vient d’être envoyé.",
    language: "العربية",
  },
  ar: {
    loginTitle: "تسجيل الدخول إلى ماتريسيا",
    emailLabel: "البريد الإلكتروني المهني",
    requestCode: "إرسال الرمز",
    invalidEmail: "أدخل عنوان بريد إلكتروني صالحاً.",
    codeLabel: "رمز من 6 أرقام",
    sent: "إذا كان العنوان مؤهلاً، فقد تم إرسال رمز إليه.",
    language: "Français",
  },
} as const;

function unknownEmail() {
  return `matricia-e2e-${Date.now()}-${Math.random().toString(36).slice(2)}@example.invalid`;
}

async function requestCode(page: Page, locale: Locale, email: string) {
  const messages = copy[locale];
  await page.goto(`/${locale}/connexion`);
  await page.getByRole("textbox", { name: messages.emailLabel }).fill(email);
  await page.getByRole("button", { name: messages.requestCode }).click();
  const status = page.getByRole("status");
  await expect(status).toHaveText(messages.sent);
  await expect(page.getByRole("textbox", { name: messages.codeLabel })).toBeVisible();
  return (await status.textContent())?.trim();
}

async function wcagViolationSummary(page: Page) {
  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
    .analyze();
  return results.violations.map((violation) => ({
    id: violation.id,
    impact: violation.impact,
    targets: violation.nodes.flatMap((node) => node.target),
  }));
}

for (const locale of ["fr", "ar"] as const) {
  const messages = copy[locale];
  const direction = locale === "ar" ? "rtl" : "ltr";

  test.describe(`${locale.toUpperCase()} identity entry`, () => {
    test(`uses ${direction.toUpperCase()} semantics and localized accessible names`, async ({ page }) => {
      await page.goto(`/${locale}/connexion`);

      await expect(page.locator("html")).toHaveAttribute("lang", locale);
      await expect(page.locator("html")).toHaveAttribute("dir", direction);
      await expect(page.getByRole("heading", { level: 1, name: messages.loginTitle })).toBeVisible();
      await expect(page.getByRole("link", { name: messages.language })).toHaveAttribute(
        "href",
        locale === "fr" ? "/ar/connexion" : "/fr/connexion",
      );
      await expect(page.getByRole("textbox", { name: messages.emailLabel })).toHaveAttribute("autocomplete", "email");
    });

    test("supports keyboard navigation and announces localized validation", async ({ page }) => {
      await page.goto(`/${locale}/connexion`);
      const email = page.getByRole("textbox", { name: messages.emailLabel });
      const submit = page.getByRole("button", { name: messages.requestCode });

      await page.getByRole("link", { name: messages.language }).focus();
      await page.keyboard.press("Tab");
      await expect(email).toBeFocused();
      await page.keyboard.press("Tab");
      await expect(submit).toBeFocused();
      await page.keyboard.press("Enter");

      await expect(page.getByRole("status")).toHaveText(messages.invalidEmail);
      await expect(email).toHaveAttribute("aria-describedby", "auth-status");
    });

    test("does not reveal whether a syntactically valid account exists", async ({ page }) => {
      const email = unknownEmail();
      const status = await requestCode(page, locale, email);

      expect(status).toBe(messages.sent);
      await expect(page.locator("body")).not.toContainText(email);
    });

    test("does not overflow horizontally at 360 px", async ({ page }) => {
      await page.setViewportSize({ width: 360, height: 800 });
      await page.goto(`/${locale}/connexion`);

      const sizes = await page.evaluate(() => ({
        viewport: document.documentElement.clientWidth,
        content: document.documentElement.scrollWidth,
      }));
      expect(sizes.content).toBeLessThanOrEqual(sizes.viewport);
    });

    test("has no automated WCAG 2.1 A or AA violation at 360 px", async ({ page }) => {
      await page.setViewportSize({ width: 360, height: 800 });
      await page.goto(`/${locale}/connexion`);

      const summary = await wcagViolationSummary(page);
      expect(summary, "Automated accessibility violations").toEqual([]);
    });
  });
}

test.describe("authentication boundaries", () => {
  for (const locale of ["fr", "ar"] as const) {
    for (const privatePath of ["tableau-de-bord", "organisation", "organisation/roles", "invitations", "securite/compte", "securite/sessions"] as const) {
      test(`redirects an anonymous visitor from /${locale}/${privatePath}`, async ({ page }) => {
        await page.goto(`/${locale}/${privatePath}`);
        await expect(page).toHaveURL(new RegExp(`/${locale}/connexion/?$`));
        await expect(page.getByRole("textbox", { name: copy[locale].emailLabel })).toBeVisible();
      });
    }

    for (const privatePath of ["invitations", "organisation/roles", "securite/compte"] as const) {
      test(`keeps the anonymous /${locale}/${privatePath} redirect localized and accessible at 360 px`, async ({ page }) => {
        await page.setViewportSize({ width: 360, height: 800 });
        await page.goto(`/${locale}/${privatePath}`);

        await expect(page).toHaveURL(new RegExp(`/${locale}/connexion/?$`));
        await expect(page.locator("html")).toHaveAttribute("lang", locale);
        await expect(page.locator("html")).toHaveAttribute("dir", locale === "ar" ? "rtl" : "ltr");
        const sizes = await page.evaluate(() => ({
          viewport: document.documentElement.clientWidth,
          content: document.documentElement.scrollWidth,
        }));
        expect(sizes.content).toBeLessThanOrEqual(sizes.viewport);
        expect(await wcagViolationSummary(page), "Automated accessibility violations").toEqual([]);
      });
    }
  }

  test("rejects a malformed authentication callback without creating a session", async ({ page }) => {
    await page.goto("/fr/auth/callback?code=invalid-e2e-code");
    await expect(page).toHaveURL(/\/fr\/connexion\/?$/);
    await page.goto("/fr/tableau-de-bord");
    await expect(page).toHaveURL(/\/fr\/connexion\/?$/);
  });
});

test("returns the same public result for a configured account and an unknown account", async ({ page }) => {
  const knownAccount = process.env.E2E_EXISTING_ACCOUNT_EMAIL;
  test.skip(!knownAccount, "E2E_EXISTING_ACCOUNT_EMAIL is required for the paired anti-enumeration proof");

  const knownResult = await requestCode(page, "fr", knownAccount as string);
  const unknownResult = await requestCode(page, "fr", unknownEmail());
  expect(knownResult).toBe(unknownResult);
});
