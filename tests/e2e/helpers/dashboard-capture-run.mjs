import { mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

/**
 * Captures des quatre tableaux de bord démo (client, prestataire, franchisé,
 * admin) en FR à 360 px et desktop pour revue visuelle de la structure.
 */
const root = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");
const requireFromRoot = createRequire(resolve(root, "package.json"));
const { chromium } = requireFromRoot("@playwright/test");

const baseURL = process.env.E2E_BASE_URL ?? "http://localhost:5173";
if (!["localhost", "127.0.0.1", "::1"].includes(new URL(baseURL).hostname)) {
  throw new Error("restricted to a local server");
}

const output = resolve(root, "artifacts", "test-results", "dashboard-review");
const personas = [
  { key: "client", destination: "tableau-de-bord", name: "client" },
  { key: "provider", destination: "tableau-de-bord", name: "provider" },
  { key: "franchise", destination: "franchise/accueil", name: "franchise" },
  { key: "admin", destination: "administration/command-center", name: "admin" },
];

const browser = await chromium.launch();
try {
  await mkdir(output, { recursive: true });
  for (const persona of personas) {
    for (const mobile of [true, false]) {
      const context = await browser.newContext({
        baseURL,
        locale: "fr-MA",
        timezoneId: "Africa/Casablanca",
        viewport: mobile ? { width: 360, height: 800 } : { width: 1440, height: 900 },
      });
      const page = await context.newPage();
      await page.goto("/fr/connexion", { waitUntil: "domcontentloaded" });
      await page.locator(`form:has(input[name="persona"][value="${persona.key}"]) button[type="submit"]`).click();
      await page.waitForURL(new RegExp(`/fr/${persona.destination}`), { timeout: 60_000 });
      await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => undefined);
      await page.screenshot({ path: resolve(output, `${persona.name}${mobile ? "-360" : "-desktop"}.png`), fullPage: true });
      await context.close();
      console.log(`captured ${persona.name} ${mobile ? "360" : "desktop"}`);
    }
  }
  console.log(`PASS captures in ${output}`);
} finally {
  await browser.close();
}
