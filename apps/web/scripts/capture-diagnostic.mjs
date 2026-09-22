import { createRequire } from "node:module";
import { mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const requireFromRoot = createRequire(resolve(root, "package.json"));
const { chromium } = requireFromRoot("@playwright/test");

const outDir = resolve(root, ".tmp");
mkdirSync(outDir, { recursive: true });
const out = resolve(outDir, process.argv[2] || "diagnostic-live.png");
const url = process.argv[3] || "http://127.0.0.1:5173/fr/diagnostic";

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1672, height: 941 }, deviceScaleFactor: 1 });
await page.goto(url, { waitUntil: "networkidle", timeout: 90_000 });
await page.waitForTimeout(1200);
// Prefer first choice selected for mockup parity when available
const choice = page.locator("main button[role=radio]").nth(2);
if (await choice.count()) {
  try { await choice.click({ timeout: 2000 }); } catch { /* ignore */ }
}
await page.screenshot({ path: out, fullPage: false });
console.log("wrote", out);
await browser.close();
