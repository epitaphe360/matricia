import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { copyFile, mkdir, rm } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { loadSafeConfiguration } from "../../../scripts/p05-e2e/environment.mjs";
import { provision } from "../../../scripts/p05-e2e/provision.mjs";
import { buildChildEnvironment, secureLocalPaths, sha256File, validateFreshManifest } from "../../../scripts/p05-e2e/security.mjs";

const root=resolve(dirname(fileURLToPath(import.meta.url)),"..","..","..");
const runToken=randomUUID(),output=resolve(root,"artifacts","test-results",`p23-action-center-${runToken}`);
const authDirectory=resolve(root,"artifacts","test-results",`.p23-action-center-auth-${runToken}`);
const created={workItems:[],actions:[]};
let fixture,failure;

async function provisionActionCenter() {
  const database=fixture.resources.database,[clientA,,central,noRole]=fixture.resources.userIds,[organizationA]=fixture.resources.organizationIds;
  if(!clientA||!central||!noRole||!organizationA)throw new Error("P23 fixture identities are incomplete");
  const queues=await database`select id,queue_key from public.admin_queue_versions where status='ACTIVE' and queue_key in('RISK_FLAGS','EXCEPTIONS')`;
  const queueByKey=new Map(queues.map(row=>[row.queue_key,row.id]));
  if(!queueByKey.get("RISK_FLAGS")||!queueByKey.get("EXCEPTIONS"))throw new Error("P23 active admin queues are unavailable");
  const riskId=randomUUID(),exceptionId=randomUUID(),actionId=randomUUID(),notificationId=randomUUID(),deliveryId=randomUUID();
  await database.begin(async transaction=>{
    await transaction`insert into public.admin_work_items(id,queue_version_id,organization_id,source_kind,resource_type,resource_id,title_fr,title_ar,priority,due_at,redacted_context,created_by)
      values
      (${riskId}::uuid,${queueByKey.get("RISK_FLAGS")}::uuid,${organizationA}::uuid,'RISK_FLAG','organization',${organizationA},'Signal de risque P23 à réviser','إشارة مخاطر P23 للمراجعة','CRITICAL',clock_timestamp()+interval '30 minutes','{"fixture":"P23","automatic_sanction":false}'::jsonb,${central}::uuid),
      (${exceptionId}::uuid,${queueByKey.get("EXCEPTIONS")}::uuid,${organizationA}::uuid,'EXCEPTION','organization',${organizationA},'Exception P23 à décider','استثناء P23 لاتخاذ قرار','HIGH',clock_timestamp()+interval '1 hour','{"fixture":"P23","human_review":true}'::jsonb,${central}::uuid)`;
    created.workItems.push(riskId,exceptionId);
    await transaction`insert into public.admin_operational_action_requests(id,organization_id,action_type,target_environment,resource_type,resource_id,request_payload_hash,redacted_summary,reason,approvals_required,status,requested_by)
      values(${actionId}::uuid,${organizationA}::uuid,'SUSPEND_ENTITY','STAGING','organization',${organizationA},repeat('a',64),'{"fixture":"P23","execution":"not_authorized"}'::jsonb,'Contrôle P23 soumis à double approbation humaine',2,'PENDING_APPROVAL',${noRole}::uuid)`;
    created.actions.push(actionId);
    await transaction`insert into public.notification_instances(id,recipient_user_id,organization_id,template_version_id,category_code,event_type,locale,subject,body,cta_path,priority,mandatory,deduplication_key,source_aggregate_type,source_aggregate_id,variables_snapshot,correlation_id)
      select ${notificationId}::uuid,${clientA}::uuid,${organizationA}::uuid,id,'SECURITY_CRITICAL',event_type,'fr-MA','Alerte P23 obligatoire','Contrôle de sécurité P23 nécessitant votre attention.','/fr/notifications','CRITICAL',true,${`p23-${runToken}`},'p23_action_center',${organizationA},'{"fixture":"P23"}'::jsonb,${randomUUID()}::uuid
      from public.notification_template_versions where template_code='SYSTEM_ALERT' and locale='fr-MA' and status='ACTIVE'`;
    await transaction`insert into public.notification_deliveries(id,notification_id,channel,delivery_mode,status,next_attempt_at)
      values(${deliveryId}::uuid,${notificationId}::uuid,'IN_APP','IMMEDIATE','PENDING',clock_timestamp())`;
  });
  return {organizationA:fixture.manifest.fixtures.organizationA.name,organizationB:fixture.manifest.fixtures.organizationB.name};
}

async function neutralizeActionCenter() {
  const database=fixture?.resources.database;
  if(!database)return;
  if(created.actions.length)await database`update public.admin_operational_action_requests set status='CANCELLED',row_version=row_version+1 where id=any(${created.actions}::uuid[]) and status='PENDING_APPROVAL'`;
  if(created.workItems.length)await database`update public.admin_work_items set status='DISMISSED',resolution_code='E2E_NEUTRALIZED',resolution_reason='Fixture P23 neutralisée après preuve',resolution_evidence='{"fixture":"P23","neutralized":true}'::jsonb,row_version=row_version+1,updated_at=clock_timestamp() where id=any(${created.workItems}::uuid[]) and status in('OPEN','CLAIMED','WAITING_INFORMATION')`;
  const remaining=await database`select
    (select count(*)::integer from public.admin_work_items where id=any(${created.workItems}::uuid[]) and status in('OPEN','CLAIMED','WAITING_INFORMATION')) as work,
    (select count(*)::integer from public.admin_operational_action_requests where id=any(${created.actions}::uuid[]) and status='PENDING_APPROVAL') as actions`;
  if(remaining[0]?.work!==0||remaining[0]?.actions!==0)throw new Error("P23 remote Action Center fixture remains active");
}

try {
  fixture=await provision();
  const config=await loadSafeConfiguration(root);
  await validateFreshManifest(fixture.manifest,config);
  const labels=await provisionActionCenter();
  await mkdir(authDirectory,{recursive:false,mode:0o700});
  await secureLocalPaths(authDirectory,[]);
  const clientState=resolve(authDirectory,"client.json"),adminState=resolve(authDirectory,"admin.json");
  await copyFile(fixture.manifest.states.clientA.path,clientState);
  await copyFile(fixture.manifest.states.centralAal2.path,adminState);
  await secureLocalPaths(authDirectory,[clientState,adminState]);
  if(await sha256File(clientState)!==fixture.manifest.states.clientA.sha256||await sha256File(adminState)!==fixture.manifest.states.centralAal2.sha256)throw new Error("P23 copied authentication state integrity failed");
  const environment=buildChildEnvironment(process.env,{
    E2E_BASE_URL:config.baseUrl,E2E_CLIENT_STORAGE_STATE:clientState,E2E_ADMIN_STORAGE_STATE:adminState,
    E2E_ORGANIZATION_NAME:labels.organizationA,E2E_FOREIGN_ORGANIZATION_NAME:labels.organizationB,
  });
  const child=spawn(process.execPath,[resolve(root,"node_modules","@playwright","test","cli.js"),"test","tests/e2e/p22-universal-actions.spec.ts","--workers=1","--reporter=line","--output",output],{cwd:root,env:environment,stdio:["ignore","inherit","inherit"],shell:false});
  const code=await new Promise((resolveExit,reject)=>{child.once("error",reject);child.once("exit",(value,signal)=>signal?reject(new Error("P23 Playwright run was interrupted")):resolveExit(value??1));});
  if(code!==0)throw new Error("P23 Action Center Playwright suite failed");
  console.log("PASS P23 Action Center E2E suite");
} catch(error){failure=error;}
finally {
  if(fixture){
    try{await neutralizeActionCenter();}catch(error){failure=failure?new AggregateError([failure,error],"P23 run and Action Center neutralization failed"):error;}
    try{await fixture.cleanup();if(fixture.resources.retainedEvidence<=0)throw new Error("Immutable fixture evidence was not retained");console.log("PASS P23 remote fixture neutralized");}catch(error){failure=failure?new AggregateError([failure,error],"P23 run and fixture cleanup failed"):error;}
    try{const fixtureAuth=resolve(dirname(fixture.manifestPath)),expected=resolve(root,"scripts","p05-e2e",".auth");if(fixtureAuth!==expected)throw new Error("Refusing to remove an unverified fixture auth directory");await rm(fixtureAuth,{recursive:true,force:true});}catch(error){failure=failure?new AggregateError([failure,error],"P23 local fixture auth cleanup failed"):error;}
  }
  try{await rm(output,{recursive:true,force:true});}catch(error){failure??=error;}
  try{await rm(authDirectory,{recursive:true,force:true});}catch(error){failure??=error;}
}
if(failure){console.error("FAIL P23 Action Center E2E execution failed; no credential or remote detail was printed");process.exitCode=1;}
