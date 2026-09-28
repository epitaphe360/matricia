import { createRequire } from "node:module";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { writeFileSync } from "node:fs";

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repoRoot = resolve(webRoot, "../..");
const require = createRequire(resolve(repoRoot, "package.json"));
const { chromium } = require("@playwright/test");
const base = process.env.E2E_BASE_URL ?? "http://127.0.0.1:5173";

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
const logs = [];
page.on("console", (msg) => logs.push(`[${msg.type()}] ${msg.text()}`));
page.on("pageerror", (err) => logs.push(`[pageerror] ${err.message}`));
page.on("response", (res) => {
  if (res.status() >= 400) logs.push(`[http ${res.status()}] ${res.url()}`);
});

await page.goto(`${base}/fr/connexion`, { waitUntil: "networkidle", timeout: 90_000 });
const form = page.locator("form").filter({ has: page.getByRole("button", { name: /^Franchisé$/i }) }).first();
await Promise.all([
  page.waitForURL(/franchise/, { timeout: 60_000 }).catch((e) => logs.push(`redirect: ${e.message}`)),
  form.getByRole("button", { name: /^Franchisé$/i }).click(),
]);
await page.waitForTimeout(2000);
await page.goto(`${base}/fr/franchise/messages`, { waitUntil: "networkidle", timeout: 90_000 });
await page.waitForTimeout(2000);
const html = await page.content();
writeFileSync(resolve(repoRoot, ".tmp/pixel-connected/debug-messages.html"), html.slice(0, 50_000));
writeFileSync(resolve(repoRoot, ".tmp/pixel-connected/debug-console.txt"), logs.join("\n"));
console.log("url", page.url());
console.log("logs", logs.slice(-30).join("\n"));
console.log("has overlay", html.includes("Turbopack") || html.includes("Runtime Error"));
console.log("has conversations", html.includes("Conversations") || html.includes("Messages et notifications"));
await browser.close();
