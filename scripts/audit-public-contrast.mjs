import AxeBuilder from "@axe-core/playwright";
import { chromium } from "@playwright/test";

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
const page = await context.newPage();
for (const route of ["/fr/a-propos", "/fr/franchise", "/fr/contact", "/ar/a-propos", "/ar/franchise", "/ar/contact"]) {
  await page.goto(`http://localhost:5173${route}`);
  const result = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa"]).analyze();
  process.stdout.write(`${route} ${JSON.stringify(result.violations.map(item => ({ id: item.id, nodes: item.nodes.map(node => ({ target: node.target, summary: node.failureSummary })) })))}\n`);
}
await browser.close();
