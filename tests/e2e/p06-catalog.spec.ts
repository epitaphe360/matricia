import { createHash, createHmac, timingSafeEqual } from "node:crypto";
import { readFileSync } from "node:fs";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Locator, type Page } from "@playwright/test";

type Manifest = {
  schemaVersion: number;
  environment: string;
  projectRef: string;
  runId: string;
  createdAt: string;
  expiresAt: string;
  state: { path: string; sha256: string };
  fixture: { libraryNameFr: string; libraryNameAr: string; firstCode: string; secondCode: string };
  signature: string;
  childSignature: string;
};

function signaturesMatch(actual: string | undefined, expected: string) {
  if (!/^[0-9a-f]{64}$/u.test(actual ?? "") || !/^[0-9a-f]{64}$/u.test(expected)) return false;
  return timingSafeEqual(Buffer.from(actual!, "hex"), Buffer.from(expected, "hex"));
}

const copy = {
  fr: {
    title: "Trouvez le service adapté à votre besoin",
    explore: "Explorer la bibliothèque",
    search: "Rechercher un service dans cette bibliothèque",
    action: "Rechercher",
    detail: "Voir le détail du service",
    characteristics: "Caractéristiques",
  },
  ar: {
    title: "اعثر على الخدمة المناسبة لاحتياجك",
    explore: "استكشاف المكتبة",
    search: "البحث عن خدمة في هذه المكتبة",
    action: "بحث",
    detail: "عرض تفاصيل الخدمة",
    characteristics: "الخصائص",
  },
} as const;

function authenticatedFixture(): { statePath: string; manifest: Manifest } {
  const manifestPath = process.env.E2E_P06_MANIFEST;
  const statePath = process.env.E2E_P06_STORAGE_STATE;
  const manifestKey = process.env.E2E_P06_MANIFEST_KEY;
  if (!manifestPath || !statePath || !manifestKey) {
    throw new Error("Authenticated P06 E2E state is required; use tests/e2e/helpers/p06-authenticated-run.mjs");
  }
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8")) as Manifest;
  const stateBytes = readFileSync(statePath);
  const now = Date.now();
  const createdAt = Date.parse(manifest.createdAt);
  const expiresAt = Date.parse(manifest.expiresAt);
  const signedPayload = Object.fromEntries(Object.entries(manifest)
    .filter(([key]) => key !== "signature" && key !== "childSignature"));
  const expectedChildSignature = createHmac("sha256", manifestKey)
    .update(JSON.stringify(signedPayload))
    .digest("hex");
  if (manifest.schemaVersion !== 2 || manifest.state.path !== statePath
      || manifest.environment !== process.env.E2E_P06_ENVIRONMENT
      || manifest.projectRef !== process.env.E2E_P06_PROJECT_REF
      || !/^[a-f0-9-]{36}$/u.test(manifest.runId)
      || !Number.isFinite(createdAt) || !Number.isFinite(expiresAt)
      || createdAt > now + 5_000 || now - createdAt > 120_000
      || expiresAt <= now || expiresAt - createdAt > 30 * 60_000
      || !/^[0-9a-f]{64}$/u.test(manifest.signature)
      || !signaturesMatch(manifest.childSignature, expectedChildSignature)
      || createHash("sha256").update(stateBytes).digest("hex") !== manifest.state.sha256) {
    throw new Error("Authenticated P06 E2E state is invalid, stale, or not bound to its manifest");
  }
  if (!manifest.fixture?.libraryNameFr || !manifest.fixture.libraryNameAr
      || !manifest.fixture.firstCode || !manifest.fixture.secondCode) {
    throw new Error("Authenticated P06 E2E catalogue fixture is incomplete");
  }
  return { statePath, manifest };
}

const authenticated = authenticatedFixture();
test.use({ storageState: authenticated.statePath });

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

async function tabUntil(page: Page, target: Locator, maximumTabs = 40) {
  for (let index = 0; index < maximumTabs; index += 1) {
    await page.keyboard.press("Tab");
    if (await target.evaluate((element) => element === document.activeElement)) return;
  }
  throw new Error(`Keyboard target was not reached after ${maximumTabs} Tab presses`);
}

for (const locale of ["fr", "ar"] as const) {
  test(`${locale.toUpperCase()} traverses the real published catalogue by keyboard at 360px`, async ({ page }) => {
    const messages = copy[locale];
    await page.setViewportSize({ width: 360, height: 800 });
    await page.goto(`/${locale}/catalogue`);
    if (process.env.E2E_P06_FORCE_FAILURE === "1") {
      throw new Error("Intentional P06 cleanup verification failure");
    }

    await expect(page).toHaveURL(new RegExp(`/${locale}/catalogue/?$`));
    await expect(page.locator("html")).toHaveAttribute("lang", locale);
    await expect(page.locator("html")).toHaveAttribute("dir", locale === "ar" ? "rtl" : "ltr");
    await expect(page.getByRole("heading", { level: 1, name: messages.title })).toBeVisible();
    const fixtureLibraryName = locale === "ar"
      ? authenticated.manifest.fixture.libraryNameAr
      : authenticated.manifest.fixture.libraryNameFr;
    const fixtureLibrary = page.getByRole("heading", { level: 3, name: fixtureLibraryName }).locator("xpath=ancestor::li[1]");
    await expect(fixtureLibrary.getByRole("link", { name: messages.explore })).toBeVisible();
    await expect(page.locator("body")).not.toContainText(/questionnaire|6\s*000/iu);
    await expectAccessibleAt360(page);

    const explore = fixtureLibrary.getByRole("link", { name: messages.explore });
    await tabUntil(page, explore);
    await expect(explore).toBeFocused();
    await page.keyboard.press("Enter");
    await expect(page).toHaveURL(/\/catalogue\?bibliotheque=[a-z0-9-]+&release=[0-9a-f-]+/u);

    const { firstCode, secondCode } = authenticated.manifest.fixture;
    await expect(page.getByText(firstCode, { exact: true })).toBeVisible();
    await expect(page.getByText(secondCode, { exact: true })).toBeVisible();
    const search = page.getByRole("searchbox", { name: messages.search });
    await tabUntil(page, search);
    await expect(search).toBeFocused();
    await search.fill(firstCode);
    await page.keyboard.press("Tab");
    const searchButton = page.getByRole("button", { name: messages.action });
    await expect(searchButton).toBeFocused();
    await page.keyboard.press("Enter");
    await expect(page).toHaveURL(/(?:\?|&)q=[^&]+/u);
    await expect(page.getByRole("searchbox", { name: messages.search })).toHaveValue(firstCode);
    await expect(page.getByRole("heading", { level: 5 })).toHaveCount(1);
    await expect(page.getByText(firstCode, { exact: true })).toBeVisible();
    await expect(page.getByText(secondCode, { exact: true })).toHaveCount(0);
    await expect(page.getByRole("link", { name: messages.detail }).first()).toBeVisible();
    await expectAccessibleAt360(page);

    const detail = page.getByRole("link", { name: messages.detail }).first();
    await tabUntil(page, detail);
    await expect(detail).toBeFocused();
    await page.keyboard.press("Enter");
    await expect(page).toHaveURL(/\/catalogue\/[a-z0-9-]+\/[a-z0-9-]+\?release=[0-9a-f-]+/u);
    await expect(page.getByRole("heading", { level: 2, name: messages.characteristics })).toBeVisible();
    await expectAccessibleAt360(page);
  });
}
