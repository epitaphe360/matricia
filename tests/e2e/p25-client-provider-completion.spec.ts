import { existsSync } from "node:fs";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Browser, type Page } from "@playwright/test";

type Locale = "fr" | "ar";
const clientSurfaces = [
  { route: "client/diagnostics", heading: { fr: "Diagnostics et opportunités", ar: "التشخيصات والفرص" } },
  { route: "client/demandes", heading: { fr: "Demandes et devis", ar: "الطلبات والعروض" } },
  { route: "client/missions", heading: { fr: "Contrats et missions", ar: "العقود والمهام" } },
  { route: "messagerie", heading: { fr: "Messagerie sécurisée", ar: "المراسلة الآمنة" } },
] as const;
const providerSurfaces = [
  { route: "sous-traitant/qualification", heading: { fr: "Qualification et capacité", ar: "التأهيل والقدرة" } },
  { route: "sous-traitant/devis", heading: { fr: "Invitations et devis", ar: "الدعوات وعروض الأسعار" } },
  { route: "sous-traitant/missions", heading: { fr: "Missions et livrables", ar: "المهام والتسليمات" } },
  { route: "sous-traitant/reputation", heading: { fr: "Réputation et feedback", ar: "السمعة والملاحظات" } },
  { route: "messagerie", heading: { fr: "Messagerie sécurisée", ar: "المراسلة الآمنة" } },
] as const;

async function session(browser: Browser, storageState: string, locale: Locale, mobile: boolean) {
  const context = await browser.newContext({ baseURL: process.env.E2E_BASE_URL ?? "http://localhost:5173", storageState, locale: locale === "ar" ? "ar-MA" : "fr-MA", timezoneId: "Africa/Casablanca", viewport: mobile ? { width: 360, height: 800 } : { width: 1280, height: 900 } });
  return { context, page: await context.newPage() };
}

async function verifySurface(page: Page, locale: Locale, route: string, heading: string) {
  await page.goto(`/${locale}/${route}`);
  await expect(page).toHaveURL(new RegExp(`/${locale}/${route}/?$`));
  await expect(page.getByRole("heading", { level: 1, name: heading })).toBeVisible();
  await expect(page.locator("html")).toHaveAttribute("dir", locale === "ar" ? "rtl" : "ltr");
  const width = await page.evaluate(() => ({ viewport: document.documentElement.clientWidth, content: document.documentElement.scrollWidth }));
  expect(width.content).toBeLessThanOrEqual(width.viewport);
  const audit = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"]).analyze();
  expect(audit.violations).toEqual([]);
}

for (const locale of ["fr", "ar"] as const) {
  test(`${locale.toUpperCase()} client diagnostics to acceptance surfaces are complete`, async ({ browser }, testInfo) => {
    const state = process.env.E2E_CLIENT_STORAGE_STATE;
    test.skip(!state || !existsSync(state), "E2E_CLIENT_STORAGE_STATE must reference an authenticated client state");
    const { context, page } = await session(browser, state!, locale, testInfo.project.name.includes("mobile"));
    try { for (const surface of clientSurfaces) await verifySurface(page, locale, surface.route, surface.heading[locale]); }
    finally { await context.close(); }
  });

  test(`${locale.toUpperCase()} provider qualification to delivery surfaces are complete`, async ({ browser }, testInfo) => {
    const state = process.env.E2E_PROVIDER_STORAGE_STATE;
    test.skip(!state || !existsSync(state), "E2E_PROVIDER_STORAGE_STATE must reference an authenticated provider state");
    const { context, page } = await session(browser, state!, locale, testInfo.project.name.includes("mobile"));
    try { for (const surface of providerSurfaces) await verifySurface(page, locale, surface.route, surface.heading[locale]); }
    finally { await context.close(); }
  });
}

test("provider upload is scanned before client accepts the delivery and milestone", async ({ browser,request }) => {
  const providerState=process.env.E2E_PROVIDER_STORAGE_STATE,clientState=process.env.E2E_CLIENT_STORAGE_STATE;
  const cronSecret=process.env.E2E_CRON_SECRET,workflows=JSON.parse(process.env.E2E_P25_WORKFLOWS??"[]") as Array<{missionId:string}>;
  test.skip(!providerState||!clientState||!cronSecret||workflows.length!==2||!existsSync(providerState)||!existsSync(clientState),"authenticated P25 mutation fixture is required");
  const provider=await session(browser,providerState!,"fr",false);
  try{
    await provider.page.goto("/fr/sous-traitant/missions");
    const submit=provider.page.getByRole("button",{name:"Soumettre le jalon au client"}).first();
    await expect(submit,"the deterministic E2E tenant must contain a provider-owned pending milestone").toBeVisible();
    await submit.click();
    await expect(provider.page.getByRole("status").filter({hasText:"Opération enregistrée et auditée"})).toBeVisible();
    await provider.page.getByText("Soumettre une nouvelle version",{exact:true}).first().click();
    const deliveryForm=provider.page.getByRole("button",{name:"Soumettre le livrable"}).first().locator("xpath=ancestor::form");
    await deliveryForm.getByLabel("Description du livrable").fill("Livrable P25 signé et prêt pour contrôle");
    await deliveryForm.getByLabel(/Fichier de preuve/).setInputFiles({name:"preuve-p25.pdf",mimeType:"application/pdf",buffer:Buffer.from("%PDF-1.7\nP25 deterministic proof\n")});
    await deliveryForm.getByLabel("Note de preuve").fill("Preuve déterministe P25");
    await deliveryForm.getByRole("button",{name:"Soumettre le livrable"}).click();
    await expect(deliveryForm.getByRole("status")).toContainText("Opération enregistrée et auditée");
  }finally{await provider.context.close()}
  const client=await session(browser,clientState!,"fr",false);
  try{
    await client.page.goto("/fr/client/missions");
    await expect(client.page.getByText(/scan fiable CLEAN/).first()).toContainText("PENDING");
    const scan=await request.post("/api/workers/delivery-proof-scans?limit=10",{headers:{authorization:`Bearer ${cronSecret}`}});expect(scan.status()).toBe(200);expect(await scan.json()).toEqual(expect.objectContaining({completed:expect.any(Number)}));
    await client.page.reload();
    const acceptance=client.page.getByRole("button",{name:"Décider le livrable"}).first().locator("xpath=ancestor::form");
    await acceptance.getByLabel("Commentaire").fill("Preuve propre et critères conformes");
    await acceptance.getByRole("button",{name:"Décider le livrable"}).click();
    await expect(acceptance.getByRole("status")).toContainText("Opération enregistrée");
    await expect(client.page.getByRole("heading",{name:"Jalons en attente de décision"})).toBeVisible();
    const form=client.page.getByRole("button",{name:"Accepter le jalon"}).first().locator("xpath=ancestor::form");
    await form.getByLabel("Motif de la décision").fill("Jalon vérifié et accepté par le parcours E2E");
    await form.getByRole("button",{name:"Accepter le jalon"}).click();
    await expect(form.getByRole("status")).toContainText("Opération enregistrée");
  }finally{await client.context.close()}
  const foreignState=process.env.E2E_CLIENT_B_STORAGE_STATE;
  if(!foreignState||!existsSync(foreignState))throw new Error("foreign tenant state is required");
  const foreign=await session(browser,foreignState,"fr",false);
  try{await foreign.page.goto("/fr/client/missions");for(const workflow of workflows)await expect(foreign.page.locator("body")).not.toContainText(workflow.missionId)}finally{await foreign.context.close()}
});
