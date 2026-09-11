import { createHash, createHmac, timingSafeEqual } from "node:crypto";
import { readFileSync } from "node:fs";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Locator, type Page } from "@playwright/test";

type AdminManifest = {
  schemaVersion: number; environment: string; projectRef: string; runId: string; createdAt: string; expiresAt: string;
  state: { path: string; sha256: string };
  fixture: {
    libraryId: string; serviceId: string; serviceVersionId: string; serviceContentHash: string;
    adminItems: Array<{ objectType: "LIBRARY" | "CATEGORY" | "SUBCATEGORY" | "SERVICE" | "SERVICE_SUBCATEGORY_LINK"; objectId: string; versionId: string; contentHash: string }>;
    adminSourceHash: string; adminReleaseKey: string; firstCode: string;
  };
  signature: string; childSignature: string;
};

function signaturesMatch(actual: string | undefined, expected: string) {
  if (!/^[0-9a-f]{64}$/u.test(actual ?? "") || !/^[0-9a-f]{64}$/u.test(expected)) return false;
  return timingSafeEqual(Buffer.from(actual!, "hex"), Buffer.from(expected, "hex"));
}

function authenticatedAdminFixture(): { statePath: string; manifest: AdminManifest } {
  const manifestPath = process.env.E2E_P06_MANIFEST;
  const statePath = process.env.E2E_P06_STORAGE_STATE;
  const key = process.env.E2E_P06_MANIFEST_KEY;
  if (!manifestPath || !statePath || !key) throw new Error("Authenticated P06 admin E2E fixture is required");
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8")) as AdminManifest;
  const stateBytes = readFileSync(statePath);
  const payload = Object.fromEntries(Object.entries(manifest).filter(([name]) => name !== "signature" && name !== "childSignature"));
  const expected = createHmac("sha256", key).update(JSON.stringify(payload)).digest("hex");
  const createdAt = Date.parse(manifest.createdAt);
  const expiresAt = Date.parse(manifest.expiresAt);
  const now = Date.now();
  const uuid = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/u;
  const fixture = manifest.fixture;
  if (manifest.schemaVersion !== 2 || manifest.environment !== process.env.E2E_P06_ENVIRONMENT
      || manifest.projectRef !== process.env.E2E_P06_PROJECT_REF || manifest.state.path !== statePath
      || !Number.isFinite(createdAt) || !Number.isFinite(expiresAt) || createdAt > now + 5_000
      || now - createdAt > 120_000 || expiresAt <= now || expiresAt - createdAt > 30 * 60_000
      || !signaturesMatch(manifest.childSignature, expected)
      || createHash("sha256").update(stateBytes).digest("hex") !== manifest.state.sha256
      || !fixture || !uuid.test(fixture.libraryId) || !uuid.test(fixture.serviceId) || !uuid.test(fixture.serviceVersionId)
      || !/^[0-9a-f]{64}$/u.test(fixture.serviceContentHash) || !Array.isArray(fixture.adminItems) || fixture.adminItems.length !== 7
      || fixture.adminItems.some((item) => !["LIBRARY", "CATEGORY", "SUBCATEGORY", "SERVICE", "SERVICE_SUBCATEGORY_LINK"].includes(item.objectType)
        || !uuid.test(item.objectId) || !uuid.test(item.versionId) || !/^[0-9a-f]{64}$/u.test(item.contentHash))
      || !/^[0-9a-f]{64}$/u.test(fixture.adminSourceHash)
      || !/^P06\.ADMIN\.[A-Z0-9]+$/u.test(fixture.adminReleaseKey) || !fixture.firstCode) {
    throw new Error("Authenticated P06 admin E2E manifest is invalid or stale");
  }
  return { statePath, manifest };
}

const authenticated = authenticatedAdminFixture();
test.use({ storageState: authenticated.statePath });

async function tabUntil(page: Page, target: Locator, maximumTabs = 80) {
  for (let index = 0; index < maximumTabs; index += 1) {
    await page.keyboard.press("Tab");
    if (await target.evaluate((element) => element === document.activeElement)) return;
  }
  throw new Error(`Keyboard target was not reached after ${maximumTabs} Tab presses`);
}

async function expectAccessibleAt360(page: Page) {
  const dimensions = await page.evaluate(() => ({ viewport: document.documentElement.clientWidth, content: document.documentElement.scrollWidth }));
  expect(dimensions.content).toBeLessThanOrEqual(dimensions.viewport);
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"]).analyze();
  expect(results.violations.map(({ id, impact, nodes }) => ({ id, impact, targets: nodes.flatMap((node) => node.target) }))).toEqual([]);
}

function cardForHeading(page: Page, name: string) {
  return page.getByRole("heading", { name }).locator("xpath=ancestor::div[@data-slot='card'][1]");
}

test("authenticated catalogue administrator creates, replays, adds and submits a release", async ({ browser, page }, testInfo) => {
  test.skip(testInfo.project.name !== "chromium-desktop", "The mutation workflow runs once against the isolated fixture");
  test.setTimeout(120_000);
  const fixture = authenticated.manifest.fixture;

  const anonymous = await browser.newContext({
    baseURL: process.env.E2E_BASE_URL ?? "http://localhost:5173",
    storageState: { cookies: [], origins: [] },
  });
  const anonymousPage = await anonymous.newPage();
  await anonymousPage.goto("/fr/administration/catalogue");
  await expect(anonymousPage).toHaveURL(/\/fr\/connexion/u);
  await anonymous.close();

  await page.setViewportSize({ width: 360, height: 800 });
  await page.goto(`/fr/administration/catalogue?library=${fixture.libraryId}&service=${fixture.serviceId}`);
  await expect(page).toHaveURL(/\/fr\/administration\/catalogue/u);
  await expect(page.locator("html")).toHaveAttribute("dir", "ltr");
  await expect(page.getByRole("heading", { level: 1, name: "Gestion des releases catalogue" })).toBeVisible();
  await expect(page.getByLabel("Bibliothèque", { exact: true })).toHaveValue(fixture.libraryId);
  await expect(page.getByLabel("Service ciblé", { exact: true })).toHaveValue(fixture.serviceId);
  await expect(page.locator('bdi[dir="ltr"]', { hasText: fixture.firstCode }).first()).toBeVisible();
  await expectAccessibleAt360(page);

  const createCard = cardForHeading(page, "1. Créer le brouillon");
  await createCard.getByLabel("Clé de release").fill(fixture.adminReleaseKey);
  await createCard.getByLabel("Empreinte SHA-256 du bundle").fill(fixture.adminSourceHash);
  await createCard.getByLabel("Approbation centrale requise").selectOption("no");
  await createCard.getByLabel("Je confirme créer une release DRAFT pour cette bibliothèque.").check();
  const originalIdentity = await createCard.locator('input[name="idempotencyKey"],input[name="correlationId"]').evaluateAll((inputs) => Object.fromEntries(inputs.map((input) => [(input as HTMLInputElement).name, (input as HTMLInputElement).value])));
  const originalLibraryRowVersion = await createCard.locator('input[name="expectedLibraryRowVersion"]').inputValue();
  const createButton = createCard.getByRole("button", { name: "Créer la release" });
  await tabUntil(page, createButton);
  await page.keyboard.press("Enter");
  const createStatus = createCard.getByRole("status");
  await expect(createStatus).toContainText("Release DRAFT créée.");
  const releaseId = (await createStatus.textContent())?.match(/[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}/u)?.[0];
  expect(releaseId).toBeTruthy();
  await expect.poll(() => page.evaluate(() => sessionStorage.getItem("matricia:catalogue-command:v1:CREATE_RELEASE"))).toBeNull();
  await createCard.getByLabel("Clé de release").fill(fixture.adminReleaseKey);
  await createCard.getByLabel("Empreinte SHA-256 du bundle").fill(fixture.adminSourceHash);
  await createCard.getByLabel("Approbation centrale requise").selectOption("no");
  await createCard.getByLabel("Je confirme créer une release DRAFT pour cette bibliothèque.").check();
  await createCard.locator('input[name="expectedLibraryRowVersion"]').evaluate((input, value) => { (input as HTMLInputElement).value = value; }, originalLibraryRowVersion);
  await page.evaluate(({ identity }) => {
    const form = document.querySelector('form input[name="releaseKey"]')?.closest("form");
    if (!(form instanceof HTMLFormElement)) throw new Error("Create form not found for replay");
    const payload = JSON.stringify(Array.from(new FormData(form).entries())
      .filter(([key]) => !key.startsWith("$ACTION_") && key !== "idempotencyKey" && key !== "correlationId" && key !== "confirmed")
      .map(([key, value]) => [key, typeof value === "string" ? value : value.name])
      .sort(([leftKey, leftValue], [rightKey, rightValue]) => leftKey.localeCompare(rightKey) || leftValue.localeCompare(rightValue)));
    sessionStorage.setItem("matricia:catalogue-command:v1:CREATE_RELEASE", JSON.stringify({ schemaVersion: 1, action: "CREATE_RELEASE", payload, ...identity, createdAt: Date.now() }));
  }, { identity: originalIdentity });
  await page.reload({ waitUntil: "networkidle" });
  await expect.poll(() => page.evaluate(() => {
    const value = sessionStorage.getItem("matricia:catalogue-command:v1:CREATE_RELEASE");
    return value ? (JSON.parse(value) as { idempotencyKey?: string }).idempotencyKey : null;
  })).toBe(originalIdentity.idempotencyKey);
  await createCard.getByLabel("Clé de release").fill(fixture.adminReleaseKey);
  await createCard.getByLabel("Empreinte SHA-256 du bundle").fill(fixture.adminSourceHash);
  await createCard.getByLabel("Approbation centrale requise").selectOption("no");
  await createCard.getByLabel("Je confirme créer une release DRAFT pour cette bibliothèque.").check();
  await createCard.locator('input[name="expectedLibraryRowVersion"]').evaluate((input, value) => { (input as HTMLInputElement).value = value; }, originalLibraryRowVersion);
  await createCard.getByRole("button", { name: "Créer la release" }).click();
  await expect(createStatus).toContainText(releaseId!);
  await expect.poll(() => page.evaluate(() => sessionStorage.getItem("matricia:catalogue-command:v1:CREATE_RELEASE"))).toBeNull();

  const addCard = cardForHeading(page, "2. Ajouter un élément approuvé");
  for (const [index, item] of fixture.adminItems.entries()) {
    await addCard.getByLabel("Identifiant de release").fill(releaseId!);
    await addCard.getByLabel("Type d’objet").selectOption(item.objectType);
    await addCard.getByLabel("Identifiant de l’objet").fill(item.objectId);
    await addCard.getByLabel("Identifiant de la version APPROVED").fill(item.versionId);
    await addCard.getByLabel("Empreinte SHA-256 du contenu").fill(item.contentHash);
    await addCard.getByLabel("Ordre").fill(String(index + 1));
    await addCard.getByLabel("Row version attendu").fill(String(index + 1));
    await addCard.getByLabel("Je confirme l’identité, la version et l’empreinte de cet élément.").check();
    await addCard.getByRole("button", { name: "Ajouter l’élément" }).click();
    await expect(addCard.getByRole("status")).toContainText(`Nouvelle row version: ${index + 2}`);
  }

  const submitCard = cardForHeading(page, "3. Soumettre la release");
  await submitCard.getByLabel("Identifiant de release").fill(releaseId!);
  await submitCard.getByLabel("Row version attendu").fill("8");
  await submitCard.getByLabel("Je confirme que l’arbre est complet et que les traductions arabes sont approuvées.").check();
  await submitCard.getByRole("button", { name: "Soumettre pour validation" }).click();
  await expect(submitCard.getByRole("status")).toContainText("Approuvée (APPROVED)");
  await expect(submitCard.locator('bdi[dir="ltr"]', { hasText: "APPROVED" })).toBeVisible();
  await expectAccessibleAt360(page);

  await page.goto(`/ar/administration/catalogue?library=${fixture.libraryId}&service=${fixture.serviceId}`);
  await expect(page.locator("html")).toHaveAttribute("lang", "ar");
  await expect(page.locator("html")).toHaveAttribute("dir", "rtl");
  await expect(page.getByRole("heading", { level: 1, name: "إدارة إصدارات الدليل" })).toBeVisible();
  await expect(page.getByText(/منشور/u).first()).toBeVisible();
  await expect(page.getByLabel("المكتبة", { exact: true })).toHaveAttribute("dir", "ltr");
  await expect(page.getByLabel("الخدمة المستهدفة", { exact: true })).toHaveAttribute("dir", "ltr");
  expect(await page.getByLabel("المكتبة", { exact: true }).locator('option:not([value=""])').evaluateAll((options) => options.every((option) => option.getAttribute("dir") === "ltr"))).toBe(true);
  expect(await page.getByLabel("الخدمة المستهدفة", { exact: true }).locator('option:not([value=""])').evaluateAll((options) => options.every((option) => option.getAttribute("dir") === "ltr"))).toBe(true);
  await expectAccessibleAt360(page);

  await page.goto("/fr/administration/catalogue");
  const librarySelect = page.getByLabel("Bibliothèque", { exact: true });
  const deniedLibraryId = await librarySelect.locator("option").evaluateAll((options, allowed) => options.map((option) => (option as HTMLOptionElement).value).find((value) => value && value !== allowed), fixture.libraryId);
  expect(deniedLibraryId).toBeTruthy();
  await librarySelect.selectOption(deniedLibraryId!);
  await page.getByRole("button", { name: "Ouvrir le contexte" }).click();
  const deniedServiceId = await page.getByLabel("Service ciblé", { exact: true }).locator("option").evaluateAll((options) => options.map((option) => (option as HTMLOptionElement).value).find(Boolean));
  expect(deniedServiceId).toBeTruthy();
  await page.getByLabel("Service ciblé", { exact: true }).selectOption(deniedServiceId!);
  await page.getByRole("button", { name: "Ouvrir le contexte" }).click();
  const deniedCreate = cardForHeading(page, "1. Créer le brouillon");
  await deniedCreate.getByLabel("Clé de release").fill(`P06.DENY.${fixture.adminReleaseKey.split(".").at(-1)}`);
  await deniedCreate.getByLabel("Empreinte SHA-256 du bundle").fill(fixture.adminSourceHash);
  await deniedCreate.getByLabel("Approbation centrale requise").selectOption("no");
  await deniedCreate.getByLabel("Je confirme créer une release DRAFT pour cette bibliothèque.").check();
  await deniedCreate.getByRole("button", { name: "Créer la release" }).click();
  await expect(deniedCreate.getByRole("alert")).toContainText("Vous ne disposez pas des permissions catalogue requises.");
});
