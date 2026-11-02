import { requireDevelopment, loadOwnState } from './safety.mjs';
requireDevelopment();
import { createRequire } from 'node:module';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
const root = process.cwd(), require = createRequire(resolve(root, 'apps/web/package.json')), { createClient } = require('@supabase/supabase-js'), { createServerClient } = require('@supabase/ssr'), { chromium } = createRequire(resolve(root, 'package.json'))('@playwright/test');
const s = await loadOwnState(), actors = JSON.parse(await readFile(resolve(s.directory, 'actors.private.json'), 'utf8'));
const owner = actors.find(a => a.label === 'owner'), foreign = actors.find(a => a.label === 'foreign'), origin = `http://127.0.0.1:${s.appPort}`, api = `http://127.0.0.1:${s.gatewayPort}`;
const cookies = new Map(), ssr = createServerClient(api, s.anonKey, { cookies: { getAll: () => [...cookies.values()], setAll: items => items.forEach(item => cookies.set(item.name, item)) } });
if ((await ssr.auth.setSession(owner.session)).error)
    throw new Error('NATIVE_SSR_SESSION_FAILED');
const client = createClient(api, s.anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
await client.auth.setSession(owner.session);
const proof = { scope: 'OWNED_ISOLATED_CLIENT_NATIVE_AUTH_BROWSER', nativeOnboardingCertified: false, physicalScanningCertified: false, status: 'RUNNING', candidate: execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(), sourceArchiveSha256: s.baselineArchiveSha256, actorBootstrap: 'SYNTHETIC_LOCAL_SQL_ROLE_FIXTURE_NOT_GOVERNED_ONBOARDING_PROOF', nativeAuth: { otp: true, totpAal2: true, userJwtFabrication: false }, pages: [], security: [], businessWorkflowCertified: false, externalProvidersCertified: false, pageErrors: [], menus: [], publicSession: [] };
const directory = resolve(s.directory, process.argv.includes('--probe') ? 'browser-probe' : 'browser');
await mkdir(directory, { recursive: true });
const browser = await chromium.launch({ executablePath: '/usr/bin/chromium' });
const check = (value, code) => { if (!value)
    throw new Error(code); };
try {
    const assurance = await client.auth.mfa.getAuthenticatorAssuranceLevel();
    check(!assurance.error && assurance.data?.currentLevel === 'aal2', 'NATIVE_TEST_AAL2_REQUIRED');
    proof.nativeAuth.verifiedCurrentLevel = assurance.data.currentLevel;
    const admin = await client.rpc('list_admin_supervision_page_v1', { p_limit: 25, p_offset: 0 });
    proof.security.push({ case: 'client-cannot-admin-rpc', denied: admin.error?.code === '42501' });
    check(admin.error?.code === '42501', 'CLIENT_ADMIN_RPC_NOT_DENIED');
    const org = await client.from('organizations').select('id').eq('id', foreign.organizationId);
    proof.security.push({ case: 'client-cannot-read-foreign-organization', denied: !org.error && org.data.length === 0 });
    check(!org.error && org.data.length === 0, 'FOREIGN_ORGANIZATION_VISIBLE');
    const paths = process.argv.includes('--probe') ? ['client/portefeuille', 'client/recompenses'] : ['client/diagnostics', 'client/questionnaires', 'client/actions', 'client/portefeuille', 'client/credits', 'client/recompenses', 'client/demandes', 'client/documents', 'notifications'];
    for (const locale of ['fr', 'ar'])
        for (const width of (process.argv.includes('--probe') ? [375, 1440] : [360, 375, 390, 768, 1440])) {
            const context = await browser.newContext({ viewport: { width, height: 960 }, hasTouch: width < 768, serviceWorkers: 'block' });
            await context.addCookies([...cookies.values()].map(c => ({ name: c.name, value: c.value, url: origin, httpOnly: false, secure: false, sameSite: 'Lax' })));
            await context.route('**/*', async (route) => { const h = route.request().headers(); if (h['next-router-prefetch'] !== undefined || /prefetch/.test(h.purpose ?? ''))
                return route.abort(); return route.continue(); });
            const page = await context.newPage();
            page.on('pageerror', error => proof.pageErrors.push({ locale, width, message: error.message.slice(0, 500) }));
            for (const path of paths) {
                const route = `/${locale}/${path}?organizationId=${owner.organizationId}`;
                const response = await page.goto(origin + route, { waitUntil: 'networkidle', timeout: 90000 });
                await page.locator('h1').first().waitFor({ timeout: 30000 });
                const alerts = await page.getByRole('alert').allTextContents();
                const record = { locale, width, path, http: response?.status(), redirectedToLogin: page.url().includes('/connexion'), selectedOrganizationRetained: new URL(page.url()).searchParams.get('organizationId') === owner.organizationId, rtl: await page.locator('html').getAttribute('dir') === 'rtl', horizontalOverflow: await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 1), alerts };
                proof.pages.push(record);
                console.log(JSON.stringify({ locale, width, path, http: record.http, overflow: record.horizontalOverflow, alerts: alerts.length }));
                await page.screenshot({ path: resolve(directory, `${locale}-${width}-${path.replaceAll('/', '-')}.png`), fullPage: true, caret: 'initial' });
                check(record.http === 200 && !record.redirectedToLogin, 'CLIENT_NATIVE_PAGE_FAILED');
                check(!record.horizontalOverflow, 'CLIENT_HORIZONTAL_OVERFLOW');
                check(record.rtl === (locale === 'ar'), 'CLIENT_LOCALE_DIRECTION_INCORRECT');
                check(record.selectedOrganizationRetained, 'CLIENT_ORGANIZATION_CONTEXT_LOST');
            }
            if (!process.argv.includes('--probe')) {
                await page.goto(`${origin}/${locale}/client/diagnostics?organizationId=${owner.organizationId}`, { waitUntil: 'networkidle', timeout: 90000 });
                const menu = page.locator('details.client-account').first(), summary = menu.locator('summary');
                await summary.focus();
                await page.keyboard.press('Enter');
                check(await menu.evaluate(element => element.open), 'ACCOUNT_MENU_KEYBOARD_OPEN_FAILED');
                const account = menu.locator('a').first();
                await account.scrollIntoViewIfNeeded();
                const exposed = await account.evaluate(element => { const r = element.getBoundingClientRect(), hit = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2); return !!hit && (element === hit || element.contains(hit)); });
                check(exposed, 'ACCOUNT_MENU_OCCLUDED');
                const href = await account.getAttribute('href');
                check(href?.includes('organizationId=' + owner.organizationId), 'ACCOUNT_MENU_LOST_ORGANIZATION');
                await page.screenshot({ path: resolve(directory, `${locale}-${width}-account-menu.png`), fullPage: true, caret: 'initial' });
                await summary.focus();
                await page.keyboard.press('Enter');
                check(!(await menu.evaluate(element => element.open)), 'ACCOUNT_MENU_KEYBOARD_CLOSE_FAILED');
                proof.menus.push({ locale, width, keyboardOpenClose: true, accountLinkExposed: true, organizationRetained: true });
                await page.goto(`${origin}/${locale}`, { waitUntil: 'networkidle', timeout: 90000 });
                const space = page.getByRole('link', { name: locale === 'fr' ? 'Mon espace · Client' : 'مساحتي · عميل', exact: true }).first();
                check(await space.count() > 0, 'PUBLIC_SESSION_SPACE_MISSING');
                const spaceHref = await space.getAttribute('href');
                check(spaceHref?.includes('/' + locale + '/'), 'PUBLIC_SESSION_SPACE_INVALID');
                proof.publicSession.push({ locale, width, signedInClientSpacePresent: true, href: spaceHref });
            }
            for (const path of [`/${locale}/administration/entreprises`, `/${locale}/client/actions?organizationId=${foreign.organizationId}`]) {
                const response = await page.goto(origin + path, { waitUntil: 'networkidle', timeout: 90000 });
                const destination = new URL(page.url()).pathname;
                const denied = [403, 404].includes(response?.status()) || (path.includes('/administration/') && !destination.includes('/administration/') && !destination.includes('/connexion'));
                proof.security.push({ case: path.includes('/administration/') ? 'client-cannot-admin-page' : 'client-cannot-select-foreign-org', locale, width, denied, http: response?.status(), destination });
                check(denied, 'CLIENT_ROUTE_SCOPE_NOT_DENIED');
            }
            await context.close();
        }
    check(!proof.pageErrors.some(error => /hydration|didn't match/iu.test(error.message)), 'HYDRATION_REGRESSION');
    proof.navigationAndGeometryPassed = true;
    proof.functionalReadinessPassed = !proof.pages.some(page => page.alerts.some(text => /impossible de charger|QUERY_FAILED|تعذر تحميل/iu.test(text)));
    proof.status = proof.functionalReadinessPassed ? 'PASSED' : 'FAILED';
    if (!proof.functionalReadinessPassed) {
        proof.failure = 'CLIENT_MODULE_LOADING_ERRORS';
        process.exitCode = 1;
    }
}
catch (e) {
    proof.status = 'FAILED';
    proof.failure = e.message;
    process.exitCode = 1;
    console.log(JSON.stringify({ failure: e.message }));
}
finally {
    await browser.close();
    await writeFile(resolve(directory, 'summary.json'), JSON.stringify(proof, null, 2) + '\n');
    console.log(JSON.stringify({ status: proof.status, pages: proof.pages.length, security: proof.security.length, evidence: resolve(directory, 'summary.json') }));
}
