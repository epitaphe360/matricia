import { createHash, randomBytes } from "node:crypto";
import { createRequire } from "node:module";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import postgres from "postgres";
import { parseEnv, resolveExpectedDatabaseUrl } from "./p05-e2e/environment.mjs";

const root = resolve(import.meta.dirname, "..");
const requireFromWeb = createRequire(resolve(root, "apps", "web", "package.json"));
const { createClient } = requireFromWeb("@supabase/supabase-js");
const id = (seed) => { const chars=createHash("sha256").update(seed).digest("hex").slice(0,32).split("");chars[12]="4";chars[16]=((Number.parseInt(chars[16],16)&3)|8).toString(16);return `${chars.slice(0,8).join("")}-${chars.slice(8,12).join("")}-${chars.slice(12,16).join("")}-${chars.slice(16,20).join("")}-${chars.slice(20).join("")}`; };
const digest = (value) => createHash("sha256").update(value).digest("hex");
const required = (value, name) => { if(typeof value!=="string"||!value.trim())throw new Error(`${name} is required`);return value.trim(); };
const secret = () => `${randomBytes(24).toString("base64url")}aA7!`;

async function saveLocalEnvironment(source, values) {
  let result=source;
  for(const [key,value] of Object.entries(values)){
    const line=`${key}=${value}`;
    const pattern=new RegExp(`^${key}=.*$`,"m");
    result=pattern.test(result)?result.replace(pattern,line):`${result.trimEnd()}\n${line}\n`;
  }
  await writeFile(resolve(root,".env.local"),result,{encoding:"utf8",mode:0o600});
}

async function upsertUser(admin,database,userId,email,password,label,persona){
  const rows=await database`select id from auth.users where lower(email)=lower(${email}) limit 1`;
  const attributes={email,password,email_confirm:true,user_metadata:{full_name:label,preferred_locale:"fr-MA"},app_metadata:{matricia_demo:true,demo_persona:persona}};
  if(rows.length){const {data,error}=await admin.auth.admin.updateUserById(rows[0].id,attributes);if(error)throw new Error("Demo identity update failed");return data.user;}
  const {data,error}=await admin.auth.admin.createUser({id:userId,...attributes});if(error)throw new Error("Demo identity creation failed");return data.user;
}

const DOMAIN_LIBRARY_CODES = ["ACC", "BTP", "COM", "HR", "INS", "IT", "LEGAL", "LOG", "QHSE", "SALES"];

async function archiveConcurrencyFixtures(database) {
  const fixtures = await database`
    select l.id
    from public.catalog_libraries l
    left join public.catalog_library_versions lv on lv.id = l.current_published_version_id
    where l.status <> 'ARCHIVED'
      and (
        l.code ~ '^CC_'
        or coalesce(lv.icon_key, '') = 'concurrency'
        or coalesce(lv.name_fr, '') ilike '%concurrence%'
      )
  `;
  for (const fixture of fixtures) {
    await database.begin(async (tx) => {
      await tx`update public.catalog_releases set status='ARCHIVED',lease_token=null,leased_until=null,next_attempt_at=null,published_at=null,retired_at=null,row_version=row_version+1
        where library_id=${fixture.id}::uuid
          and status in ('DRAFT','IN_REVIEW','APPROVED','SCHEDULED','PUBLISHING','FAILED','DEAD_LETTER','PUBLISHED','RETIRED')`;
      await tx`update public.catalog_libraries set status='ARCHIVED',archived_at=coalesce(archived_at,clock_timestamp()),current_release_id=null,current_published_version_id=null,row_version=row_version+1,updated_at=clock_timestamp()
        where id=${fixture.id}::uuid and status<>'ARCHIVED'`;
      await tx`update public.catalog_categories set status='ARCHIVED',archived_at=coalesce(archived_at,clock_timestamp()),row_version=row_version+1
        where library_id=${fixture.id}::uuid and status<>'ARCHIVED'`;
      await tx`update public.catalog_subcategories set status='ARCHIVED',archived_at=coalesce(archived_at,clock_timestamp()),row_version=row_version+1
        where library_id=${fixture.id}::uuid and status<>'ARCHIVED'`;
      await tx`update public.catalog_services set status='ARCHIVED',archived_at=coalesce(archived_at,clock_timestamp()),row_version=row_version+1
        where library_id=${fixture.id}::uuid and status<>'ARCHIVED'`;
      await tx`update public.catalog_service_subcategory_links set status='ARCHIVED',row_version=row_version+1
        where library_id=${fixture.id}::uuid and status<>'ARCHIVED'`;
      await tx`insert into private.catalog_acl_write_capabilities(backend_pid,transaction_id)
        values(pg_backend_pid(),txid_current()) on conflict do nothing`;
      await tx`update public.catalog_library_mandates set status='REVOKED',valid_until=coalesce(valid_until,clock_timestamp()),row_version=row_version+1
        where library_id=${fixture.id}::uuid and status='ACTIVE'`;
      await tx`delete from private.catalog_acl_write_capabilities
        where backend_pid=pg_backend_pid() and transaction_id=txid_current()`;
    });
  }
  return fixtures.length;
}

async function main(){
  const envPath=resolve(root,".env.local");
  const [source,metadataSource]=await Promise.all([readFile(envPath,"utf8"),readFile(resolve(root,"supabase","project-metadata.json"),"utf8")]);
  const env={...parseEnv(source),...process.env};const metadata=JSON.parse(metadataSource);
  if(!new Set(["development","staging"]).has(metadata.environment)||env.APP_ENV!==metadata.environment)throw new Error("Demo provisioning is restricted to development/staging");
  const projectRef=required(metadata.project_ref,"SUPABASE_PROJECT_REF");const url=required(env.NEXT_PUBLIC_SUPABASE_URL,"NEXT_PUBLIC_SUPABASE_URL");
  if(new URL(url).hostname!==`${projectRef}.supabase.co`)throw new Error("Supabase project mismatch");
  const database=postgres(resolveExpectedDatabaseUrl({databaseUrl:required(env.SUPABASE_DB_POOLER_URL||env.DIRECT_URL,"DIRECT_URL"),projectRef,region:required(metadata.region,"SUPABASE_REGION")}),{max:1,prepare:false,connect_timeout:15});
  const admin=createClient(url,required(env.SUPABASE_SERVICE_ROLE_KEY,"SUPABASE_SERVICE_ROLE_KEY"),{auth:{autoRefreshToken:false,persistSession:false}});
  const credentials={
    MATRICIA_DEMO_ACCESS_ENABLED:"true",
    MATRICIA_DEMO_CLIENT_EMAIL:env.MATRICIA_DEMO_CLIENT_EMAIL||"demo.client@matricia.test",
    MATRICIA_DEMO_CLIENT_PASSWORD:env.MATRICIA_DEMO_CLIENT_PASSWORD||secret(),
    MATRICIA_DEMO_PROVIDER_EMAIL:env.MATRICIA_DEMO_PROVIDER_EMAIL||"demo.prestataire@matricia.test",
    MATRICIA_DEMO_PROVIDER_PASSWORD:env.MATRICIA_DEMO_PROVIDER_PASSWORD||secret(),
    MATRICIA_DEMO_ADMIN_EMAIL:env.MATRICIA_DEMO_ADMIN_EMAIL||"demo.admin@matricia.test",
    MATRICIA_DEMO_ADMIN_PASSWORD:env.MATRICIA_DEMO_ADMIN_PASSWORD||secret(),
  };
  const client=await upsertUser(admin,database,id(`${projectRef}:demo:client-user`),credentials.MATRICIA_DEMO_CLIENT_EMAIL,credentials.MATRICIA_DEMO_CLIENT_PASSWORD,"Client Démo Matricia","client");
  const provider=await upsertUser(admin,database,id(`${projectRef}:demo:provider-user`),credentials.MATRICIA_DEMO_PROVIDER_EMAIL,credentials.MATRICIA_DEMO_PROVIDER_PASSWORD,"Prestataire Démo Matricia","provider");
  const adminUser=await upsertUser(admin,database,id(`${projectRef}:demo:admin-user`),credentials.MATRICIA_DEMO_ADMIN_EMAIL,credentials.MATRICIA_DEMO_ADMIN_PASSWORD,"Admin Démo Matricia","admin");
  await database`insert into public.platform_user_roles(user_id,role_code,granted_by,revoked_at)
    values(${adminUser.id}::uuid,'MATRICIA_ADMIN',${adminUser.id}::uuid,null)
    on conflict(user_id,role_code) do update set granted_by=excluded.granted_by,revoked_at=null`;
  try{
    const archivedFixtures = await archiveConcurrencyFixtures(database);
    const libraries=await database`
      select l.id,l.code,
        coalesce(pv.name_fr, dv.name_fr) as name_fr,
        coalesce(pv.name_ar, dv.name_ar) as name_ar,
        (select s.id from public.catalog_services s
          where s.library_id=l.id and s.status not in ('ARCHIVED','RETIRED')
          order by case when s.status='PUBLISHED' then 0 else 1 end, s.code
          limit 1) as service_id
      from public.catalog_libraries l
      left join public.catalog_library_versions pv on pv.id=l.current_published_version_id
      left join public.catalog_library_versions dv on dv.id=l.current_draft_version_id
      where l.code in ${database(DOMAIN_LIBRARY_CODES)}
        and l.status not in ('RETIRED','ARCHIVED')
      order by l.code`;
    if(libraries.length!==10||libraries.some(row=>!row.service_id||!row.name_fr)){
      throw new Error("Ten domain libraries (ACC/BTP/COM/HR/INS/IT/LEGAL/LOG/QHSE/SALES) with at least one service are required");
    }
    const keepOrgIds=[];
    for(const library of libraries){
      const clientOrg=id(`${projectRef}:demo:${library.code}:client-org`),providerOrg=id(`${projectRef}:demo:${library.code}:provider-org`);
      keepOrgIds.push(clientOrg, providerOrg);
      const clientMembership=id(`${clientOrg}:membership`),providerMembership=id(`${providerOrg}:membership`),providerService=id(`${providerOrg}:${library.service_id}:service`),request=id(`${clientOrg}:${library.service_id}:request`),requestVersion=id(`${request}:version:1`);
      await database.begin(async tx=>{
        await tx`insert into public.organizations(id,legal_name,display_name,status,created_by) values(${clientOrg}::uuid,${`Client Démo ${library.name_fr}`},${`Client · ${library.name_fr}`},'ACTIVE',${client.id}::uuid) on conflict(id) do update set display_name=excluded.display_name,legal_name=excluded.legal_name,status='ACTIVE'`;
        await tx`insert into public.organizations(id,legal_name,display_name,status,created_by) values(${providerOrg}::uuid,${`Prestataire Démo ${library.name_fr}`},${`Prestataire · ${library.name_fr}`},'ACTIVE',${provider.id}::uuid) on conflict(id) do update set display_name=excluded.display_name,legal_name=excluded.legal_name,status='ACTIVE'`;
        await tx`insert into public.organization_memberships(id,organization_id,user_id,status,activated_at) values(${clientMembership}::uuid,${clientOrg}::uuid,${client.id}::uuid,'ACTIVE',clock_timestamp()) on conflict(id) do update set status='ACTIVE',activated_at=coalesce(public.organization_memberships.activated_at,clock_timestamp())`;
        await tx`insert into public.organization_memberships(id,organization_id,user_id,status,activated_at) values(${providerMembership}::uuid,${providerOrg}::uuid,${provider.id}::uuid,'ACTIVE',clock_timestamp()) on conflict(id) do update set status='ACTIVE',activated_at=coalesce(public.organization_memberships.activated_at,clock_timestamp())`;
        await tx`insert into public.organization_member_roles(membership_id,role_code,library_id,granted_by,revoked_at) values(${clientMembership}::uuid,'CLIENT_OWNER',${library.id}::uuid,${client.id}::uuid,null) on conflict(membership_id,role_code) do update set library_id=excluded.library_id,revoked_at=null`;
        await tx`insert into public.organization_member_roles(membership_id,role_code,library_id,granted_by,revoked_at) values(${providerMembership}::uuid,'PROVIDER_OWNER',${library.id}::uuid,${provider.id}::uuid,null) on conflict(membership_id,role_code) do update set library_id=excluded.library_id,revoked_at=null`;
        await tx`insert into public.provider_profiles(provider_organization_id,activity_summary,team_size,years_experience,created_by) values(${providerOrg}::uuid,${`Prestataire de démonstration pour ${library.name_fr}.`},5,4,${provider.id}::uuid) on conflict(provider_organization_id) do update set activity_summary=excluded.activity_summary`;
        await tx`insert into public.provider_services(id,provider_organization_id,service_id,request_status,requested_by) values(${providerService}::uuid,${providerOrg}::uuid,${library.service_id}::uuid,'DRAFT',${provider.id}::uuid) on conflict(provider_organization_id,service_id) do nothing`;
        await tx`insert into public.service_requests(id,client_organization_id,library_id,service_id,status,created_by) values(${request}::uuid,${clientOrg}::uuid,${library.id}::uuid,${library.service_id}::uuid,'DRAFT',${client.id}::uuid) on conflict(id) do nothing`;
        await tx`insert into public.service_request_versions(id,request_id,client_organization_id,library_id,version_number,description,urgency,currency_code,required_quote_data,required_fields_complete,catalog_snapshot_hash,questionnaire_snapshot_hash,change_reason,content_hash,created_by) values(${requestVersion}::uuid,${request}::uuid,${clientOrg}::uuid,${library.id}::uuid,1,${`Demande de démonstration pour ${library.name_fr}.`},'NORMAL','MAD','{}'::jsonb,false,${digest(`${library.id}:catalog`)},${digest(`${library.id}:questionnaire`)},'Initialisation démonstration',${digest(`${request}:v1`)},${client.id}::uuid) on conflict(request_id,version_number) do nothing`;
        await tx`update public.service_requests set current_version_id=${requestVersion}::uuid where id=${request}::uuid and current_version_id is null`;
      });
    }
    await database`
      update public.organization_memberships m
      set status='REVOKED', updated_at=clock_timestamp(), row_version=m.row_version+1
      from public.organizations o
      where m.organization_id=o.id
        and m.user_id in (${client.id}::uuid, ${provider.id}::uuid)
        and m.status='ACTIVE'
        and o.id not in ${database(keepOrgIds)}`;
    await database`
      update public.organizations o
      set status='ARCHIVED', updated_at=clock_timestamp(), row_version=o.row_version+1
      where o.created_by in (${client.id}::uuid, ${provider.id}::uuid)
        and o.status<>'ARCHIVED'
        and o.id not in ${database(keepOrgIds)}
        and (
          o.display_name ilike 'Client · %'
          or o.display_name ilike 'Prestataire · %'
          or o.display_name ilike '%concurrence%'
          or o.display_name ilike '%p06%'
        )`;
    await saveLocalEnvironment(source,credentials);
    console.log(`PASS demo Client, Provider and Admin personas provisioned across ${libraries.length} domain libraries (archived ${archivedFixtures} concurrency fixtures); credentials stored only in ignored .env.local`);
  }finally{await database.end({timeout:2});}
}

try{await main();}catch(error){console.error(`FAIL ${error instanceof Error?error.message:"demo provisioning failed"}; no credential was printed`);process.exitCode=1;}
