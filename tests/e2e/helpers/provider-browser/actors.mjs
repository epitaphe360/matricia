import{requireDevelopment,loadOwnState,docker}from'./safety.mjs';
requireDevelopment();
import{readFile,writeFile,access}from'node:fs/promises';
import{resolve}from'node:path';
import{randomUUID,randomBytes}from'node:crypto';
import{createRequire}from'node:module';
import{totp}from'../../../../scripts/p05-e2e/totp.mjs';
import{requiredActors}from'./plan.mjs';
const state=await loadOwnState(),path=resolve(state.directory,'actors.private.json');
if(state.status!=='SERVICES_STARTED')throw Error('FRESH_COORDINATED_PROVIDER_SERVICES_REQUIRED');
let exists=false;try{await access(path);exists=true;}catch{}if(exists)throw Error('NATIVE_COHORT_ALREADY_STARTED_PRESERVE_EXISTING_IDENTITIES');
const{createClient}=createRequire(resolve('apps/web/package.json'))('@supabase/supabase-js'),origin=`http://127.0.0.1:${state.gatewayPort}`,config={auth:{persistSession:false,autoRefreshToken:false}},admin=createClient(origin,state.serviceKey,config),actors=[],clients=new Map();
async function call(client,name,args){const result=await client.rpc(name,args);if(result.error)throw Error(`NATIVE_PROVIDER_SETUP_${name}:${result.error.code}`);return result.data;}
async function persist(){await writeFile(path,JSON.stringify(actors),{mode:0o600});}
for(const label of requiredActors){
 const email=`provider-browser-${label}-${state.token}@example.invalid`,created=await admin.auth.admin.createUser({email,email_confirm:true,user_metadata:{locale:'fr'},app_metadata:{isolated_browser_fixture:state.token}});
 if(created.error||!created.data.user)throw Error('NATIVE_PROVIDER_TEST_USER_CREATE_FAILED');
 const link=await admin.auth.admin.generateLink({type:'magiclink',email});if(link.error||!link.data.properties?.hashed_token)throw Error('NATIVE_PROVIDER_TEST_OTP_LINK_FAILED');
 const client=createClient(origin,state.anonKey,config);if((await client.auth.verifyOtp({type:'magiclink',token_hash:link.data.properties.hashed_token})).error)throw Error('NATIVE_PROVIDER_TEST_OTP_VERIFY_FAILED');
 const factor=await client.auth.mfa.enroll({factorType:'totp',friendlyName:'Owned Provider browser TEST cohort'});if(factor.error||!factor.data.totp?.secret)throw Error('NATIVE_PROVIDER_TEST_TOTP_ENROLL_FAILED');
 let verified=false;for(const offset of[0,-30000,30000])if(!(await client.auth.mfa.challengeAndVerify({factorId:factor.data.id,code:totp(factor.data.totp.secret,Date.now()+offset)})).error){verified=true;break;}
 const user=await client.auth.getUser(),assurance=await client.auth.mfa.getAuthenticatorAssuranceLevel();if(!verified||user.data.user?.id!==created.data.user.id||assurance.data?.currentLevel!=='aal2')throw Error('GENUINE_PROVIDER_ACTOR_AAL2_IDENTITY_REQUIRED');
 const actor={label,userId:created.data.user.id,email,session:(await client.auth.getSession()).data.session,organizationId:null,roles:[]};
 if(['provider-owner','foreign-provider','client-owner'].includes(label)){
  const ice=String(BigInt('0x'+randomBytes(6).toString('hex'))).padStart(15,'0'),role=label==='client-owner'?'CLIENT_OWNER':'PROVIDER_OWNER';
  const organization=await call(client,'create_or_request_organization',{p_legal_name:`TEST ONLY ${label} ${state.token}`,p_display_name:`TEST ONLY ${label}`,p_ice:ice,p_owner_role:role,p_idempotency_key:randomUUID(),p_correlation_id:randomUUID()});
  if(!organization?.organization_id)throw Error('NATIVE_PROVIDER_ORGANIZATION_REQUIRED');actor.organizationId=organization.organization_id;actor.ice=ice;actor.roles=[role];
 }
 actors.push(actor);clients.set(label,client);await persist();console.log(JSON.stringify({status:'GENUINE_GOTRUE_OTP_TOTP_ACTOR_READY',label,userJwtFabricated:false}));
}
const owner=actors.find(a=>a.label==='provider-owner'),ownerClient=clients.get('provider-owner');
for(const[label,role]of[['provider-manager','PROVIDER_MANAGER'],['provider-accounting','PROVIDER_ACCOUNTING'],['technician-assigned','PROVIDER_TECHNICIAN'],['technician-unassigned','PROVIDER_TECHNICIAN'],['technician-viewer',['PROVIDER_TECHNICIAN','PROVIDER_VIEWER']],['provider-viewer','PROVIDER_VIEWER'],['provider-sales','PROVIDER_SALES']]){
 const actor=actors.find(a=>a.label===label),invitation=await call(ownerClient,'invite_organization_member',{p_organization_id:owner.organizationId,p_invited_user_id:actor.userId,p_role_codes:Array.isArray(role)?role:[role],p_expires_at:new Date(Date.now()+86400000).toISOString(),p_correlation_id:randomUUID()});
 await call(clients.get(label),'accept_organization_invitation',{p_invitation_id:invitation,p_correlation_id:randomUUID()});actor.organizationId=owner.organizationId;actor.roles=Array.isArray(role)?role:[role];await persist();
}
// Explicit TEST staff bootstrap only. Authentication, sessions, organization
// creation and Provider invitations above use their real native commands.
const staff=[['compliance-reviewer','COMPLIANCE_MANAGER'],['governance-author','SUPER_ADMIN'],['governance-reviewer','SUPER_ADMIN'],['finance-author','FINANCE_MANAGER'],['finance-reviewer','FINANCE_MANAGER']];
const uuid=/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/iu;
const values=staff.map(([label,role])=>{const actor=actors.find(a=>a.label===label);if(!uuid.test(actor.userId))throw Error('EXACT_NATIVE_TEST_STAFF_REQUIRED');actor.roles=[role];return `('${actor.userId}','${role}')`;});
docker(['exec','-i',state.database,'psql','-X','-U','supabase_admin','-d','postgres','-v','ON_ERROR_STOP=1'],{input:`begin;do $$begin if not exists(select 1 from private.admin_execution_environment_v1 where singleton and environment='DEVELOPMENT')then raise exception'TEST_DEVELOPMENT_REQUIRED';end if;end$$;insert into public.platform_user_roles(user_id,role_code)values${values.join(',')};commit;`});
await persist();state.status='ACTORS_READY';await writeFile(resolve(state.directory,'state.private.json'),JSON.stringify(state),{mode:0o600});
const boundary=JSON.parse(docker(['exec','-i',state.database,'psql','-X','-U','supabase_admin','-d','postgres','-Atq','-v','ON_ERROR_STOP=1'],{input:`select json_build_object('clientRoles',(select count(*)from public.organization_memberships m join public.organization_member_roles r on r.membership_id=m.id where m.organization_id='${owner.organizationId}'and r.revoked_at is null and r.role_code like 'CLIENT_%'),'clientTrials',(select count(*)from public.client_trials where organization_id='${owner.organizationId}'));`}));
if(boundary.clientRoles!==0||boundary.clientTrials!==0)throw Error('NO_PROVIDER_CLIENT_ROLE_OR_TRIAL_ALLOWED');
const proof={scope:'GENUINE_GOTRUE_PROVIDER_COHORT_WITH_NATIVE_ORGANIZATIONS_AND_INVITATIONS',status:'READY',userJwtFabricated:false,nativeEmailDeliveryCertified:false,staffRoleBootstrap:'EXPLICIT_TEST_ONLY_NOT_GOVERNED_STAFF_ONBOARDING_CERTIFICATION',actors:actors.map(({label,userId,organizationId,roles})=>({label,userId,organizationId,roles})),noProviderClientRoleOrTrialActivated:true,boundary};
await writeFile(resolve(state.directory,'cohort-proof.json'),JSON.stringify(proof,null,2));console.log(JSON.stringify({status:'NATIVE_PROVIDER_COHORT_READY',actors:actors.length,separateStaffActors:staff.length}));
