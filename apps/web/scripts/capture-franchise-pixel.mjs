import { createRequire } from "node:module";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repoRoot = resolve(webRoot, "../..");
const require = createRequire(resolve(repoRoot, "package.json"));
const { chromium } = require("@playwright/test");
const base = process.env.E2E_BASE_URL ?? "http://127.0.0.1:5173";
const out = resolve(repoRoot, ".tmp/pixel-connected");

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1100 } });
await page.goto(`${base}/fr/connexion`, { waitUntil: "networkidle", timeout: 90_000 });
const form = page.locator("form").filter({ has: page.getByRole("button", { name: /^Franchisé$/i }) }).first();
await Promise.all([
  page.waitForURL(/franchise/, { timeout: 60_000 }).catch(() => null),
  form.getByRole("button", { name: /^Franchisé$/i }).click(),
]);
await page.waitForTimeout(2000);

const targets = [
  ["franchise/messages", "franchise-20-messages.png"],
  ["franchise/documents", "franchise-19-documents.png"],
  ["franchise/fournisseurs", "franchise-11-fournisseurs.png"],
  ["franchise/accueil", "franchise-00-accueil.png"],
];

for (const [route, name] of targets) {
  await page.goto(`${base}/fr/${route}`, { waitUntil: "domcontentloaded", timeout: 90_000 });
  await page.waitForTimeout(2500);
  await page.keyboard.press("Escape").catch(() => null);
  await page.evaluate(() => {
    document.querySelectorAll("nextjs-portal").forEach((node) => node.remove());
  }).catch(() => null);
  await page.waitForTimeout(400);
  const text = await page.locator("body").innerText();
  console.log(
    route,
    "turbopack=",
    /Turbopack|Runtime Error/.test(text),
    "hits=",
    /Messages et notifications|Documents et renouvellements|Réseau|Pilotez|Conversations/.test(text),
  );
  await page.screenshot({ path: resolve(out, name), fullPage: false });
}

await browser.close();
