import { existsSync } from "node:fs";
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

test.describe("P24 Marketing completion",()=>{
  for(const locale of ["fr","ar"] as const){
    test(`${locale.toUpperCase()} authenticated Marketing is responsive, localized and accessible`,async({browser},testInfo)=>{
      const state=process.env.E2E_ADMIN_STORAGE_STATE;
      test.skip(!state||!existsSync(state),"E2E_ADMIN_STORAGE_STATE must reference a generated authenticated admin state");
      const context=await browser.newContext({baseURL:process.env.E2E_BASE_URL??"http://localhost:5173",storageState:state!,locale:locale==="ar"?"ar-MA":"fr-MA",timezoneId:"Africa/Casablanca",viewport:testInfo.project.name.includes("mobile")?{width:360,height:800}:{width:1280,height:900}});
      const page=await context.newPage();
      try{
        await page.goto(`/${locale}/administration/marketing-autopilot`);
        await expect(page).toHaveURL(new RegExp(`/${locale}/administration/marketing-autopilot/?$`));
        await expect(page.locator("html")).toHaveAttribute("dir",locale==="ar"?"rtl":"ltr");
        await expect(page.getByRole("heading",{level:1,name:locale==="ar"?"التسويق الآلي":"Marketing Autopilot"})).toBeVisible();
        await expect(page.getByText(locale==="ar"?"القوالب التجارية":"Templates commerciaux",{exact:true})).toBeVisible();
        await expect(page.getByText(locale==="ar"?"المحتويات المولدة":"Contenus générés",{exact:true})).toBeVisible();
        await expect(page.getByRole("heading",{name:locale==="ar"?"تفويضات وأمان النشر":"Autorisations et sécurité sociale"})).toBeVisible();
        await expect(page.getByRole("button",{name:locale==="ar"?"إصدار نسخة":"Versionner"})).toBeVisible();
        await expect(page.getByRole("button",{name:locale==="ar"?"تطبيق":"Appliquer"})).toBeVisible();
        const dimensions=await page.evaluate(()=>({viewport:document.documentElement.clientWidth,content:document.documentElement.scrollWidth}));
        expect(dimensions.content).toBeLessThanOrEqual(dimensions.viewport);
        await page.keyboard.press("Tab");await expect(page.locator(":focus")).toBeVisible();
        const audit=await new AxeBuilder({page}).withTags(["wcag2a","wcag2aa","wcag21a","wcag21aa"]).analyze();
        expect(audit.violations.map(({id,impact,nodes})=>({id,impact,targets:nodes.flatMap(node=>node.target)}))).toEqual([]);
      }finally{await context.close()}
    });
  }

  test("local authenticated fixture proves generation to publication to attribution chain",async({request})=>{
    const secret=process.env.E2E_CRON_SECRET,fixtureText=process.env.E2E_MARKETING_CHAIN_FIXTURE;
    test.skip(!secret||!fixtureText,"E2E_CRON_SECRET and E2E_MARKETING_CHAIN_FIXTURE are required for the local chain");
    let fixture:{content:Record<string,unknown>;attribution:Record<string,unknown>};
    try{fixture=JSON.parse(fixtureText!)}catch{throw new Error("E2E_MARKETING_CHAIN_FIXTURE must be valid JSON")}
    const headers={authorization:`Bearer ${secret}`};
    const generated=await request.post("/api/workers/marketing-content",{headers,data:fixture.content});
    expect(generated.status()).toBe(200);expect(await generated.json()).toMatchObject({outcome:"MARKETING_CONTENT_BATCH_GENERATED",count:3});
    const publication=await request.post("/api/workers/marketing-publications?limit=3",{headers});
    expect(publication.status()).toBe(200);const publicationResult=await publication.json()as{processed:number;skipped:number;published?:number;sandboxed?:number};expect(publicationResult.processed).toBeGreaterThan(0);expect(publicationResult.skipped).toBe(0);expect((publicationResult.published??0)+(publicationResult.sandboxed??0)).toBeGreaterThan(0);
    const attribution=await request.post("/api/workers/marketing-attribution",{headers,data:fixture.attribution});
    expect(attribution.status()).toBe(200);expect(await attribution.json()).toMatchObject({outcome:"MARKETING_ATTRIBUTION_INGESTED",attributed_campaign_id:fixture.attribution.p_campaign_id});
  });

  test("anonymous access remains denied in FR and AR",async({page})=>{
    for(const locale of ["fr","ar"] as const){await page.goto(`/${locale}/administration/marketing-autopilot`);await expect(page).toHaveURL(new RegExp(`/${locale}/connexion/?$`));await expect(page.locator("html")).toHaveAttribute("dir",locale==="ar"?"rtl":"ltr")}
  });
});
