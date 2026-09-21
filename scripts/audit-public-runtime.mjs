import { chromium } from "@playwright/test";

const base = new URL(process.argv[2] ?? "http://127.0.0.1:3000");
if (!/^https?:$/.test(base.protocol)) throw new Error("AUDIT_URL_PROTOCOL_INVALID");

const widths = [360, 390, 412, 768, 1024, 1440];
const routes = ["/fr", "/ar", "/fr/diagnostic", "/ar/diagnostic", "/fr/besoin", "/ar/besoin", "/fr/fournisseur", "/ar/fournisseur"];
const browser = await chromium.launch({ headless: true });
const findings = [];

for (const width of widths) {
  const context = await browser.newContext({ viewport: { width, height: width < 700 ? 844 : 900 }, reducedMotion: "reduce" });
  for (const route of routes) {
    const page = await context.newPage();
    const consoleErrors = [];
    page.on("console", (message) => { if (message.type() === "error") consoleErrors.push(message.text().slice(0, 180)); });
    const started = Date.now();
    const response = await page.goto(new URL(route, base).href, { waitUntil: "domcontentloaded", timeout: 30_000 });
    await page.waitForTimeout(150);
    const result = await page.evaluate(() => ({
      title: document.title,
      h1: document.querySelectorAll("h1").length,
      dir: document.documentElement.dir,
      overflow: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
      unnamedButtons: [...document.querySelectorAll("button")].filter((element) => !(element.textContent?.trim() || element.getAttribute("aria-label") || element.getAttribute("title"))).length,
      emptyLinks: [...document.querySelectorAll("a")].filter((element) => !element.getAttribute("href")?.trim()).length,
    }));
    const status = response?.status() ?? 0;
    if (status >= 400 || result.h1 !== 1 || !result.title || result.overflow || result.unnamedButtons || result.emptyLinks || consoleErrors.length) {
      findings.push({ route, width, status, ...result, consoleErrors });
    }
    findings.push({ route, width, status, elapsedMs: Date.now() - started, check: "timing" });
    await page.close();
  }
  await context.close();
}

await browser.close();
const timings = findings.filter((item) => item.check === "timing");
const defects = findings.filter((item) => item.check !== "timing");
const elapsed = timings.map((item) => item.elapsedMs);
console.log(JSON.stringify({
  baseOrigin: base.origin,
  pagesChecked: timings.length,
  widths,
  routes,
  timingMs: { min: Math.min(...elapsed), max: Math.max(...elapsed), average: Math.round(elapsed.reduce((sum, value) => sum + value, 0) / elapsed.length) },
  defectCount: defects.length,
  defects,
}, null, 2));
if (defects.length) process.exitCode = 1;
