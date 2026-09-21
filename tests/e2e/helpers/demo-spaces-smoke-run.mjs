import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

/**
 * Smoke runtime des quatre espaces connectés via les personas démo réels.
 * Connexion par les boutons démo de /connexion puis visite des routes clés
 * de chaque rôle à 360 px (FR) : statut < 500, h1 visible, pas de débordement
 * horizontal, pas d'erreur navigateur. Prérequis : serveur local et personas
 * démo provisionnés (scripts/provision-demo-library-personas.mjs et
 * scripts/provision-demo-franchise-persona.mjs).
 */
const root = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");
const requireFromRoot = createRequire(resolve(root, "package.json"));
const { chromium } = requireFromRoot("@playwright/test");

const baseURL = process.env.E2E_BASE_URL ?? "http://localhost:5173";
const host = new URL(baseURL).hostname;
if (!["localhost", "127.0.0.1", "::1"].includes(host)) {
  throw new Error("Le smoke démo est restreint à un serveur local");
}

const personas = [
  {
    key: "client",
    destination: "tableau-de-bord",
    routes: ["tableau-de-bord", "client/diagnostics", "client/demandes", "client/missions", "client/finances"],
  },
  {
    key: "provider",
    destination: "tableau-de-bord",
    routes: ["tableau-de-bord", "sous-traitant/qualification", "sous-traitant/devis", "sous-traitant/missions"],
  },
  {
    key: "franchise",
    destination: "franchise/accueil",
    routes: ["franchise/accueil", "franchise/gouvernance", "franchise/performance", "franchise/relances", "franchise/digest"],
  },
  {
    key: "admin",
    destination: "administration/command-center",
    routes: ["administration/command-center", "administration/parcours", "administration/entreprises", "administration/finance", "administration/operations"],
  },
];

const failures = [];
const browser = await chromium.launch();

try {
  for (const persona of personas) {
    const context = await browser.newContext({
      baseURL,
      locale: "fr-MA",
      timezoneId: "Africa/Casablanca",
      viewport: { width: 360, height: 800 },
    });
    const page = await context.newPage();
    const pageErrors = [];
    page.on("pageerror", (error) => pageErrors.push(`${persona.key}: ${error.message}`));
    try {
      await page.goto("/fr/connexion", { waitUntil: "domcontentloaded" });
      await page.locator(`form:has(input[name="persona"][value="${persona.key}"]) button[type="submit"]`).click();
      await page.waitForURL(new RegExp(`/fr/${persona.destination}`), { timeout: 60_000 });
      for (const route of persona.routes) {
        const response = await page.goto(`/fr/${route}`, { waitUntil: "domcontentloaded" });
        await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => undefined);
        const status = response ? response.status() : 0;
        const h1Count = await page.locator("h1").count();
        const dimensions = await page.evaluate(() => ({
          viewport: document.documentElement.clientWidth,
          content: document.documentElement.scrollWidth,
        }));
        const bodyText = (await page.locator("body").innerText()).trim();
        const problems = [];
        if (status >= 500 || status === 0) problems.push(`status=${status}`);
        if (h1Count === 0) problems.push("h1 absent");
        if (dimensions.content > dimensions.viewport) problems.push("débordement horizontal");
        if (/Application error|Internal Server Error/u.test(bodyText) || bodyText.length < 20) problems.push("page en erreur ou vide");
        if (problems.length > 0) failures.push(`${persona.key} /fr/${route}: ${problems.join(", ")}`);
        console.log(`${problems.length === 0 ? "OK" : "FAIL"} ${persona.key} /fr/${route} status=${status} h1=${h1Count}`);
      }
    } catch (error) {
      failures.push(`${persona.key}: ${error instanceof Error ? error.message.split("\n")[0] : "échec de connexion"}`);
    } finally {
      if (pageErrors.length > 0) failures.push(...pageErrors.map((message) => `erreur navigateur ${message}`));
      await context.close();
    }
  }
  if (failures.length > 0) {
    console.error(`FAIL smoke démo:\n${failures.join("\n")}`);
    process.exitCode = 1;
  } else {
    console.log("PASS smoke démo : 4 espaces connectés, 18 routes saines à 360 px");
  }
} finally {
  await browser.close();
}
