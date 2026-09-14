import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

for (const locale of ['fr', 'ar'] as const) {
  test(`public experience ${locale}: studio, catalogue, detail, mobile and accessibility`, async ({ page }, testInfo) => {
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto(`/${locale}`);
    await expect(page.getByRole('heading', { level: 1 })).toContainText(locale === 'fr' ? 'Votre projet' : 'مشروعكم');
    await page.locator('.mx-motion-control').click();
    await expect(page.locator('.mx-experience')).toHaveAttribute('data-motion', 'paused');
    const scenario = page.locator('.mx-scenarios button').nth(1);
    await scenario.click();
    await expect(scenario).toHaveAttribute('aria-pressed', 'true');
    await expect(page.locator('.mx-board-services a')).toHaveCount(4);
    await expect(page.locator('.mx-board-client h3')).toHaveText(locale === 'fr' ? 'Je développe ma marque' : 'أطور علامتي');
    const width = await page.evaluate(() => ({ viewport: innerWidth, content: document.documentElement.scrollWidth }));
    expect(width.content).toBeLessThanOrEqual(width.viewport);
    const audit = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
    expect(audit.violations.map(v => ({ id: v.id, targets: v.nodes.map(n => n.target) }))).toEqual([]);
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.screenshot({ path: testInfo.outputPath(`home-${locale}.png`), fullPage: true });
    await page.locator('.mx-board-services a').first().click();
    await expect(page).toHaveURL(/library=COM/);
    await expect(page.locator('.mx-result-card')).toHaveCount(20);
    await page.locator('.mx-result-card a').first().click();
    await expect(page.locator('.mx-detail h1')).toBeVisible();
    await expect(page.locator('.mx-detail .mx-button')).toHaveAttribute('href', `/${locale}/connexion`);
    await page.goto(`/${locale}/services?q=zzzz-no-result`);
    await expect(page.locator('.mx-result-card')).toHaveCount(0);
    await page.goto(`/${locale}/services?q=cybersecurite`);
    expect(await page.locator('.mx-result-card').count()).toBeGreaterThan(0);
  });
}
