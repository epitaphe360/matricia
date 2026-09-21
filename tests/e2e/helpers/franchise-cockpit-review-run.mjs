import { mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

/**
 * Revue visuelle de l'espace franchisé aligné sur le cockpit SIP.
 * Connexion réelle via le bouton démo de /connexion (persona franchise),
 * captures FR/AR à 360 px et desktop, contrôle de débordement horizontal.
 * Prérequis : serveur local sur E2E_BASE_URL (défaut http://localhost:5173)
 * et persona démo franchise provisionné (scripts/provision-demo-franchise-persona.mjs).
 */
const root = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");
const requireFromRoot = createRequire(resolve(root, "package.json"));
const { chromium } = requireFromRoot("@playwright/test");

const baseURL = process.env.E2E_BASE_URL ?? "http://localhost:5173";
const host = new URL(baseURL).hostname;
if (!["localhost", "127.0.0.1", "::1"].includes(host)) {
  throw new Error("La revue visuelle franchise est restreinte à un serveur local");
}

const output = resolve(root, "artifacts", "test-results", "franchise-cockpit");
const modules = [
  { route: "franchise/accueil", name: "accueil" },
  { route: "franchise/gouvernance", name: "gouvernance" },
  { route: "franchise/performance", name: "performance" },
  { route: "franchise/relances", name: "relances" },
  { route: "franchise/digest", name: "digest" },
];

const results = [];
const browser = await chromium.launch();

async function newSession(locale, mobile) {
  const context = await browser.newContext({
    baseURL,
    locale: locale === "ar" ? "ar-MA" : "fr-MA",
    timezoneId: "Africa/Casablanca",
    viewport: mobile ? { width: 360, height: 800 } : { width: 1280, height: 900 },
  });
  return context;
}

async function loginAsFranchiseDemo(page, locale) {
  await page.goto(`/${locale}/connexion`, { waitUntil: "domcontentloaded" });
  const form = page.locator('form:has(input[name="persona"][value="franchise"])');
  await form.locator('button[type="submit"]').click();
  await page.waitForURL(new RegExp(`/${locale}/franchise/accueil`), { timeout: 60_000 });
}

async function capture(page, locale, route, name, mobile, errors) {
  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  const response = await page.goto(`/${locale}/${route}`, { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => undefined);
  const status = response ? response.status() : 0;
  const dimensions = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    content: document.documentElement.scrollWidth,
  }));
  const bodyText = (await page.locator("body").innerText()).trim();
  const overflow = dimensions.content > dimensions.viewport;
  const broken = status >= 500 || /Application error|Internal Server Error/u.test(bodyText) || bodyText.length < 20;
  const file = resolve(output, `${name}-${locale}${mobile ? "-360" : "-desktop"}.png`);
  await page.screenshot({ path: file, fullPage: true });
  results.push({ route, locale, mobile, status, overflow, broken, pageErrors });
  if (status >= 500 || overflow || broken || pageErrors.length > 0) errors.push({ route, locale, mobile, status, overflow, broken, pageErrors });
}

try {
  await mkdir(output, { recursive: true });
  const errors = [];
  for (const locale of ["fr", "ar"]) {
    for (const mobile of [true, false]) {
      const context = await newSession(locale, mobile);
      const page = await context.newPage();
      await loginAsFranchiseDemo(page, locale);
      for (const module of modules) {
        await capture(page, locale, module.route, module.name, mobile, errors);
      }
      await context.close();
    }
  }
  console.log(`captures: ${results.length} screenshots in ${output}`);
  for (const result of results) {
    console.log(`${result.broken || result.overflow || result.pageErrors.length ? "CHECK" : "OK"} ${result.locale} ${result.mobile ? "360px" : "desktop"} ${result.route} status=${result.status}`);
  }
  if (errors.length > 0) {
    console.error(`FAIL ${errors.length} page(s) avec anomalie (statut>=500, débordement horizontal ou erreur navigateur)`);
    process.exitCode = 1;
  } else {
    console.log("PASS revue visuelle franchise : 20 captures saines, aucun débordement horizontal, aucune erreur navigateur");
  }
} finally {
  await browser.close();
}
