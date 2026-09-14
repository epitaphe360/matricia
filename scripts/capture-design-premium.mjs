import { mkdir } from "node:fs/promises";
import { chromium } from "@playwright/test";

const output = "docs/design-premium/screenshots/after";
const baseURL = process.argv[2] ?? process.env.E2E_BASE_URL ?? "http://localhost:5173";
const shots = [
  ["home-fr-1440.png", "/fr", 1440, 1000],
  ["home-fr-768.png", "/fr", 768, 1024],
  ["home-fr-390.png", "/fr", 390, 844],
  ["home-ar-360.png", "/ar", 360, 800],
  ["diagnostic-fr-1440.png", "/fr/diagnostic", 1440, 1000],
  ["diagnostic-ar-390.png", "/ar/diagnostic", 390, 844],
  ["besoin-fr-390.png", "/fr/besoin", 390, 844],
  ["fournisseur-fr-1440.png", "/fr/fournisseur", 1440, 1000],
  ["connexion-ar-390.png", "/ar/connexion", 390, 844],
];

await mkdir(output, { recursive: true });
const browser = await chromium.launch({ headless: true });
for (const [filename, route, width, height] of shots) {
  const context = await browser.newContext({ viewport: { width, height }, locale: route.startsWith("/ar") ? "ar-MA" : "fr-MA" });
  const page = await context.newPage();
  await page.goto(baseURL + route, { waitUntil: "networkidle" });
  await page.locator("h1").waitFor({ state: "visible" });
  await page.screenshot({ path: `${output}/${filename}`, fullPage: true });
  await context.close();
}
await browser.close();
