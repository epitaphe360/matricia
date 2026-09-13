import { existsSync } from "node:fs";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";

const actors=[
  {name:"client",state:"E2E_CLIENT_STORAGE_STATE"},
  {name:"admin",state:"E2E_ADMIN_STORAGE_STATE"},
]as const;
type Locale="fr"|"ar";

async function expectAccessibleReflow(page:Page,locale:Locale){
  await expect(page.locator("html")).toHaveAttribute("lang",locale);
  await expect(page.locator("html")).toHaveAttribute("dir",locale==="ar"?"rtl":"ltr");
  const size=await page.evaluate(()=>({viewport:document.documentElement.clientWidth,content:document.documentElement.scrollWidth}));
  expect(size.content).toBeLessThanOrEqual(size.viewport);
  const audit=await new AxeBuilder({page}).withTags(["wcag2a","wcag2aa","wcag21a","wcag21aa"]).analyze();
  expect(audit.violations.map(({id,impact,nodes})=>({id,impact,targets:nodes.flatMap(node=>node.target)}))).toEqual([]);
}

async function expectKeyboardFocus(page:Page){
  await page.locator("body").focus();
  for(let index=0;index<40;index+=1){await page.keyboard.press("Tab");if(await page.locator(":focus").count()){await expect(page.locator(":focus")).toBeVisible();return;}}
  throw new Error("No visible control received keyboard focus");
}

for(const actor of actors){
  for(const locale of ["fr","ar"]as const){
    test(`${actor.name} universal actions ${locale.toUpperCase()} is accessible and RTL-safe`,async({browser},testInfo)=>{
      const statePath=process.env[actor.state],organization=process.env.E2E_ORGANIZATION_NAME,foreignOrganization=process.env.E2E_FOREIGN_ORGANIZATION_NAME;
      test.skip(!statePath||!existsSync(statePath),`${actor.state} must reference a generated authenticated Playwright state`);
      const viewport=testInfo.project.name.includes("mobile")?{width:360,height:800}:{width:1280,height:900};
      const context=await browser.newContext({baseURL:process.env.E2E_BASE_URL??"http://localhost:5173",storageState:statePath!,viewport,locale:locale==="ar"?"ar-MA":"fr-MA",timezoneId:"Africa/Casablanca"});
      const page=await context.newPage();
      try{
        await page.goto(`/${locale}/actions`);
        await expect(page).toHaveURL(new RegExp(`/${locale}/actions/?$`));
        await expect(page.getByRole("heading",{level:1,name:locale==="ar"?"الإجراءات المطلوبة":"Actions requises"})).toBeVisible();
        await expect(page.getByRole("note")).toContainText(locale==="ar"?"لا تطبق أي عقوبة تلقائياً":"aucune sanction n’est appliquée automatiquement");
        if(actor.name==="client"){
          if(organization)await expect(page.locator("body")).toContainText(organization);
          if(foreignOrganization)await expect(page.locator("body")).not.toContainText(foreignOrganization);
          await expect(page.getByText("Alerte P23 obligatoire")).toBeVisible();
          await expect(page.getByText(locale==="ar"?"إلزامي":"Obligatoire").first()).toBeVisible();
        }else{
          await expect(page.getByText(locale==="ar"?"إشارة مخاطر":"Signal de risque").first()).toBeVisible();
          await expect(page.getByText(locale==="ar"?"استثناء":"Exception").first()).toBeVisible();
          await expect(page.getByText(locale==="ar"?"موافقة":"Approbation").first()).toBeVisible();
          await expect(page.getByText(locale==="ar"?"يتطلب قراراً بشرياً":"Décision humaine requise").first()).toBeVisible();
          await expect(page.getByText(locale==="ar"?"إشارة مخاطر P23 للمراجعة":"Signal de risque P23 à réviser")).toBeVisible();
          await expect(page.getByText(locale==="ar"?"استثناء P23 لاتخاذ قرار":"Exception P23 à décider")).toBeVisible();
          await expect(page.getByText("Contrôle P23 soumis à double approbation humaine")).toBeVisible();
        }
        await expectKeyboardFocus(page);
        await expectAccessibleReflow(page,locale);

        if(actor.name==="client"){
          await page.goto(`/${locale}/notifications`);
          await expect(page.getByRole("heading",{level:1,name:locale==="ar"?"مركز الإشعارات":"Centre de notifications"})).toBeVisible();
          await expect(page.getByText(locale==="ar"?"تحمي هذه الفئة معلومة حرجة، لذلك لا يمكن تعطيلها أو تأجيلها.":"Cette catégorie protège une information critique : elle ne peut être ni désactivée ni différée.").first()).toBeVisible();
          await expect(page.getByText("Alerte P23 obligatoire")).toBeVisible();
          if(organization)await expect(page.locator("body")).toContainText(organization);
          if(foreignOrganization)await expect(page.locator("body")).not.toContainText(foreignOrganization);
          await expectKeyboardFocus(page);
          await expectAccessibleReflow(page,locale);
        }
      }finally{await context.close();}
    });
  }
}
