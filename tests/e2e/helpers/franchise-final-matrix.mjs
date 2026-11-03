import { fixtureState, privateDirectory, actorSession, sourceCandidate } from './franchise-final-support.mjs';
import { readFile,writeFile,mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { chromium } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
const state=await fixtureState(),pin=await sourceCandidate(),dir=await privateDirectory(state),file=resolve(dir,'actors.private.json'),cohort=JSON.parse(await readFile(file));
const mandate=cohort.mandates.find(value=>value.label==='FIRST');
if(mandate?.activation?.mode!=='NON_CONTRACTUAL_DEMO')throw Error('NATIVE_EXPLICIT_TEST_MANDATE_ACTIVATION_REQUIRED');
const owner=cohort.actors.find(value=>value.label==='owner'),out=resolve('docs/franchise-completion/evidence/browser/final-matrix');await mkdir(out,{recursive:true});
const fullRoutes=['accueil','recherche','bibliotheque','services','services/nouveau','questionnaires','questionnaires/nouveau','regles','regles/nouvelle','validations','perimetre','fournisseurs','fournisseurs/inviter','clients/inviter','demandes','qualite','performance','relances','digest','marketing','documents','messages','gouvernance','finance'];
const smoke=process.argv.includes('--smoke');
const routes=smoke?['accueil','services','qualite','marketing','finance']:fullRoutes;
const widths=smoke?[390]:[375,390,768,1440],locales=['fr','ar'];
const proof={scope:'FRANCHISE_FR_AR_RESPONSIVE_NATIVE_MANDATE',candidate:pin.commit,appTree:pin.appTree,locales,widths,routes,mandateActivation:'NON_CONTRACTUAL_DEMO',hostedCertification:false,manualFullWcagCertification:false,axeRuleExclusions:[],status:'RUNNING',cases:[],pageErrors:[]};
const browser=await chromium.launch({headless:true,executablePath:'/usr/bin/chromium'});
const safe=value=>String(value).replace(/[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}/gu,'[REDACTED]').slice(0,1200);
try{
 for(const locale of locales)for(const width of widths){
  const native=await actorSession(state,owner,file,cohort),context=await browser.newContext({viewport:{width,height:960},hasTouch:true,serviceWorkers:'block'});await context.addCookies(native.cookies);const page=await context.newPage();
  page.on('pageerror',error=>proof.pageErrors.push({locale,width,error:safe(error)}));
  for(const path of routes){const item={locale,width,path,status:'RUNNING'},start=Date.now();try{
   const target=new URL(`http://127.0.0.1:${state.appPort}/${locale}/franchise/${path}`);target.searchParams.set('organizationId',owner.organizationId);target.searchParams.set('franchiseId',mandate.activation.franchiseId);
   const response=await page.goto(target.toString(),{waitUntil:'networkidle',timeout:90000});item.http=response.status();if(item.http!==200||new URL(page.url()).pathname.includes('/connexion'))throw Error('NATIVE_FRANCHISE_ROUTE_NOT_AUTHORIZED');
   item.lang=await page.locator('html').getAttribute('lang');item.dir=await page.locator('html').getAttribute('dir');if(item.lang!==locale||item.dir!==(locale==='ar'?'rtl':'ltr'))throw Error('FRANCHISE_DOCUMENT_LOCALE_MISMATCH');
   item.overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1);if(item.overflow)throw Error('FRANCHISE_HORIZONTAL_OVERFLOW');
   const failures=await page.locator('[data-workspace-failure]').evaluateAll(nodes=>nodes.map(node=>node.getAttribute('data-workspace-failure')));item.workspaceFailures=failures;if(failures.length)throw Error('FRANCHISE_WORKSPACE_READ_FAILURE:'+failures.join(','));
   const result=await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21aa']).analyze();item.axe={violations:result.violations.map(({id,impact,nodes})=>({id,impact,nodes:nodes.map(({target,failureSummary})=>({target,failureSummary}))})),incomplete:result.incomplete.map(({id,nodes})=>({id,targets:nodes.map(({target})=>target)}))};
   if(item.axe.violations.length)throw Error('FRANCHISE_ACCESSIBILITY_VIOLATION');
   if(width===390||path==='accueil'){await page.screenshot({path:resolve(out,`${locale}-${width}-${path.replaceAll('/','_')}.png`),fullPage:true});item.screenshot=`${locale}-${width}-${path.replaceAll('/','_')}.png`;}
   item.status='PASS';
  }catch(error){item.status='FAIL';item.failure=safe(error);process.exitCode=1;}finally{item.elapsedMs=Date.now()-start;proof.cases.push(item);await writeFile(resolve(out,'summary.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({locale,width,path,status:item.status,failure:item.failure}));}}
  await context.close();
 }
 proof.status=proof.cases.every(item=>item.status==='PASS')&&proof.pageErrors.length===0?'PASSED':'FAILED';
}catch(error){proof.status='FAILED';proof.failure=safe(error);process.exitCode=1;}finally{await browser.close();await writeFile(resolve(out,'summary.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({status:proof.status,cases:proof.cases.length,failures:proof.cases.filter(item=>item.status!=='PASS').length,pageErrors:proof.pageErrors.length}));}
