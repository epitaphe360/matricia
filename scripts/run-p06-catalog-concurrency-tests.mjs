import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import postgres from 'postgres';

function parseEnv(source) {
  return Object.fromEntries(source.split(/\r?\n/).flatMap((line) => {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    return match ? [[match[1], match[2].replace(/^(['"])(.*)\1$/, '$2')]] : [];
  }));
}
function deferred() {
  let resolvePromise; let rejectPromise;
  const promise = new Promise((resolveValue, rejectValue) => { resolvePromise = resolveValue; rejectPromise = rejectValue; });
  return { promise, resolve: resolvePromise, reject: rejectPromise };
}
async function assertBlocked(promise, label) {
  let settled = false; promise.finally(() => { settled = true; }).catch(() => {});
  await new Promise((resolveWait) => setTimeout(resolveWait, 300));
  if (settled) throw new Error(`${label} did not overlap the first transaction`);
}
async function resolveDatabaseUrl(env, metadata) {
  const configured = env.SUPABASE_DB_POOLER_URL || env.DIRECT_URL;
  if (!configured?.startsWith('postgres')) throw new Error('A PostgreSQL DIRECT_URL is required');
  const url = new URL(configured);
  const directHost = `db.${metadata.project_ref}.supabase.co`;
  const poolerHost = `aws-0-${metadata.region}.pooler.supabase.com`;
  if (url.hostname === directHost && url.username === 'postgres') {
    url.hostname = poolerHost; url.port = '5432'; url.username = `postgres.${metadata.project_ref}`; url.searchParams.set('sslmode', 'require');
    return url.toString();
  }
  if (url.hostname === poolerHost && url.username === `postgres.${metadata.project_ref}`) {
    url.searchParams.set('sslmode', 'require');
    return url.toString();
  }
  throw new Error('Database target is not the configured Supabase development project');
}

const root = resolve(import.meta.dirname, '..');
const fileEnv = parseEnv(await readFile(resolve(root, '.env.local'), 'utf8'));
const env = { ...fileEnv, ...process.env };
const metadata = JSON.parse(await readFile(resolve(root, 'supabase', 'project-metadata.json'), 'utf8'));
if (env.APP_ENV !== 'development' || metadata.environment !== 'development') throw new Error('P06 concurrency tests are development-only');
const publicUrl = new URL(env.NEXT_PUBLIC_SUPABASE_URL);
if (publicUrl.hostname !== `${metadata.project_ref}.supabase.co`) throw new Error('Supabase project mismatch');
const url = await resolveDatabaseUrl(env, metadata);
const admin = postgres(url, { max: 1, prepare: false, connect_timeout: 15 });
const workerA = postgres(url, { max: 1, prepare: false, connect_timeout: 15 });
const workerB = postgres(url, { max: 1, prepare: false, connect_timeout: 15 });
const id = Object.fromEntries(['user','org','member','library','libraryVersion','category','categoryVersion','subcategory','subcategoryVersion','service','serviceVersion','link','linkVersion','release','reclaimRelease','worker','workerB'].map((key) => [key, randomUUID()]));
const hash = Object.fromEntries(['library','category','subcategory','service','link'].map((key, index) => [key, String.fromCharCode(97 + index).repeat(64)]));

async function asOwner(transaction) {
  await transaction.unsafe('set local role authenticated');
  await transaction`select set_config('request.jwt.claim.sub',${id.user},true)`;
  await transaction`select set_config('request.jwt.claims',${JSON.stringify({ sub: id.user, role: 'authenticated', aal: 'aal2' })},true)`;
}
async function asService(transaction) {
  await transaction.unsafe('set local role service_role');
  await transaction`select set_config('request.jwt.claim.role','service_role',true)`;
  await transaction`select set_config('request.jwt.claims','{"role":"service_role"}',true)`;
}

async function neutralizePartialFixtures(database) {
  await database.begin(async (transaction) => {
    const organizations = await transaction`select organization.id
      from public.organizations organization
      join auth.users fixture_user on fixture_user.id=organization.created_by
      where organization.display_name='P06 Concurrency'
        and fixture_user.email like 'p06-%@example.invalid'
        and organization.status<>'ARCHIVED'
      for update`;
    const organizationIds = organizations.map((row) => row.id);
    if (organizationIds.length === 0) return;
    await transaction`update public.catalog_releases release set status='CANCELLED',lease_token=null,leased_until=null,next_attempt_at=null,row_version=release.row_version+1
      from public.catalog_libraries library where release.library_id=library.id and library.steward_organization_id=any(${organizationIds}::uuid[])
        and release.status in ('DRAFT','IN_REVIEW','APPROVED','SCHEDULED','PUBLISHING','FAILED')`;
    await transaction`update public.organization_member_roles role set revoked_at=coalesce(role.revoked_at,clock_timestamp())
      from public.organization_memberships membership where role.membership_id=membership.id and membership.organization_id=any(${organizationIds}::uuid[])`;
    await transaction`update public.organization_memberships set status='REVOKED',updated_at=clock_timestamp(),row_version=row_version+1
      where organization_id=any(${organizationIds}::uuid[]) and status<>'REVOKED'`;
    await transaction`update public.organizations set status='ARCHIVED',updated_at=clock_timestamp(),row_version=row_version+1
      where id=any(${organizationIds}::uuid[]) and status<>'ARCHIVED'`;
  });
}

try {
  await neutralizePartialFixtures(admin);
  await admin.begin(async (tx) => {
    await tx`insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values(${id.user}::uuid,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',${`p06-${id.user}@example.invalid`},'',now(),'{}','{}',now(),now())`;
    await tx`insert into public.organizations(id,legal_name,display_name,status,created_by) values(${id.org}::uuid,'P06 Concurrency Evidence','P06 Concurrency','ACTIVE',${id.user}::uuid)`;
    await tx`insert into public.organization_memberships(id,organization_id,user_id,status,activated_at) values(${id.member}::uuid,${id.org}::uuid,${id.user}::uuid,'ACTIVE',now())`;
    await tx`insert into public.catalog_libraries(id,code,slug,steward_organization_id,created_by) values(${id.library}::uuid,${`CC_${id.library.replaceAll('-', '').slice(0, 12).toUpperCase()}`},${`cc-${id.library}`},${id.org}::uuid,${id.user}::uuid)`;
    await tx`insert into public.organization_member_roles(membership_id,role_code,library_id) values(${id.member}::uuid,'FRANCHISE_OWNER',${id.library}::uuid)`;
    await tx`insert into public.catalog_library_mandates(library_id,organization_id,status,valid_from,policy_version,created_by) values(${id.library}::uuid,${id.org}::uuid,'ACTIVE',now()-interval '1 day',1,${id.user}::uuid)`;
    await tx`insert into public.catalog_library_versions(id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by) values(${id.libraryVersion}::uuid,${id.library}::uuid,1,'APPROVED','Bibliothèque concurrence','مكتبة التزامن','Preuve de concurrence','دليل التزامن','concurrency',1,'Fixture de concurrence',${hash.library},'APPROVED',${id.user}::uuid,clock_timestamp(),${'1'.repeat(64)},1,${id.user}::uuid)`;
    await tx`insert into public.catalog_categories(id,library_id,code,slug,created_by) values(${id.category}::uuid,${id.library}::uuid,'CONCURRENCY_CATEGORY','concurrency-category',${id.user}::uuid)`;
    await tx`insert into public.catalog_category_versions(id,category_id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by) values(${id.categoryVersion}::uuid,${id.category}::uuid,${id.library}::uuid,1,'APPROVED','Catégorie concurrence','فئة التزامن','Preuve catégorie','دليل الفئة',1,'Fixture de concurrence',${hash.category},'APPROVED',${id.user}::uuid,clock_timestamp(),${'2'.repeat(64)},1,${id.user}::uuid)`;
    await tx`insert into public.catalog_subcategories(id,library_id,category_id,code,slug,created_by) values(${id.subcategory}::uuid,${id.library}::uuid,${id.category}::uuid,'CONCURRENCY_SUBCATEGORY','concurrency-subcategory',${id.user}::uuid)`;
    await tx`insert into public.catalog_subcategory_versions(id,subcategory_id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by) values(${id.subcategoryVersion}::uuid,${id.subcategory}::uuid,${id.library}::uuid,1,'APPROVED','Sous-catégorie concurrence','فئة فرعية للتزامن','Preuve sous-catégorie','دليل الفئة الفرعية',1,'Fixture de concurrence',${hash.subcategory},'APPROVED',${id.user}::uuid,clock_timestamp(),${'3'.repeat(64)},1,${id.user}::uuid)`;
    await tx`insert into public.catalog_services(id,library_id,primary_subcategory_id,code,slug,created_by) values(${id.service}::uuid,${id.library}::uuid,${id.subcategory}::uuid,${`SVC_${id.service.replaceAll('-', '').slice(0, 12).toUpperCase()}`},${`svc-${id.service}`},${id.user}::uuid)`;
    await tx`insert into public.catalog_service_versions(id,service_id,library_id,version,status,name_fr,name_ar,short_description_fr,short_description_ar,long_description_fr,long_description_ar,service_type,unit_label_fr,unit_label_ar,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by) values(${id.serviceVersion}::uuid,${id.service}::uuid,${id.library}::uuid,1,'APPROVED','Service concurrence','خدمة التزامن','Preuve courte','دليل قصير','Preuve longue de concurrence','دليل طويل للتزامن','PROFESSIONAL','unité','وحدة',1,'Fixture de concurrence',${hash.service},'APPROVED',${id.user}::uuid,clock_timestamp(),${'4'.repeat(64)},1,${id.user}::uuid)`;
    await tx`insert into public.catalog_service_subcategory_links(id,service_id,subcategory_id,library_id,link_type,created_by) values(${id.link}::uuid,${id.service}::uuid,${id.subcategory}::uuid,${id.library}::uuid,'PRIMARY',${id.user}::uuid)`;
    await tx`insert into public.catalog_service_subcategory_link_versions(id,link_id,library_id,version,status,change_reason,content_hash,created_by) values(${id.linkVersion}::uuid,${id.link}::uuid,${id.library}::uuid,1,'APPROVED','Fixture de concurrence',${hash.link},${id.user}::uuid)`;
    await tx`insert into public.catalog_releases(id,library_id,release_key,status,source_bundle_hash,snapshot_hash,created_by,approved_by,approved_at) values(${id.release}::uuid,${id.library}::uuid,${`CC.${id.release.replaceAll('-', '').slice(0, 20).toUpperCase()}`},'APPROVED',${'f'.repeat(64)},${'0'.repeat(64)},${id.user}::uuid,${id.user}::uuid,now())`;
    for (const [type, objectId, versionId, contentHash, order] of [['LIBRARY',id.library,id.libraryVersion,hash.library,1],['CATEGORY',id.category,id.categoryVersion,hash.category,2],['SUBCATEGORY',id.subcategory,id.subcategoryVersion,hash.subcategory,3],['SERVICE',id.service,id.serviceVersion,hash.service,4],['SERVICE_SUBCATEGORY_LINK',id.link,id.linkVersion,hash.link,5]]) {
      await tx`insert into public.catalog_release_items(release_id,library_id,object_type,object_id,version_id,content_hash,sort_order) values(${id.release}::uuid,${id.library}::uuid,${type},${objectId}::uuid,${versionId}::uuid,${contentHash},${order})`;
    }
    await tx`update public.catalog_releases r set snapshot_hash=(select encode(extensions.digest(convert_to(string_agg(object_type||':'||object_id::text||':'||version_id::text||':'||content_hash||':'||sort_order::text,',' order by sort_order,object_type,object_id),'UTF8'),'sha256'),'hex') from public.catalog_release_items where release_id=r.id) where r.id=${id.release}::uuid`;
  });

  const scheduleA = workerA.begin(async (tx) => { await asOwner(tx); return tx`select public.schedule_catalog_release(${id.release}::uuid,statement_timestamp()-interval '1 second',null,'{"kind":"PUBLIC"}'::jsonb,1,${`p06-schedule-${randomUUID()}`})`; });
  const scheduleB = workerB.begin(async (tx) => { await asOwner(tx); return tx`select public.schedule_catalog_release(${id.release}::uuid,statement_timestamp()-interval '1 second',null,'{"kind":"PUBLIC"}'::jsonb,1,${`p06-schedule-${randomUUID()}`})`; });
  const scheduleResults = await Promise.allSettled([scheduleA, scheduleB]);
  if (scheduleResults.filter((result) => result.status === 'fulfilled').length !== 1 || !scheduleResults.some((result) => result.status === 'rejected' && result.reason.message.includes('STALE_CATALOG_VERSION'))) throw new Error('concurrent schedules did not yield one success and one stale rejection');
  console.log('PASS p06_schedule_stale_concurrency (2 connections)');

  const claimResults = await Promise.all([
    workerA.begin(async (tx) => { await asService(tx); return tx`select public.claim_catalog_release(${id.worker}::uuid,${id.release}::uuid,300) as result`; }),
    workerB.begin(async (tx) => { await asService(tx); return tx`select public.claim_catalog_release(${randomUUID()}::uuid,${id.release}::uuid,300) as result`; }),
  ]);
  const claimPayloads = claimResults.map((rows) => rows[0].result);
  if (claimPayloads.filter((value) => value.outcome === 'CATALOG_RELEASE_CLAIMED').length !== 1 || claimPayloads.filter((value) => value.outcome === 'NO_CATALOG_RELEASE_DUE').length !== 1) throw new Error('concurrent workers did not yield exactly one lease');
  const lease = claimPayloads.find((value) => value.outcome === 'CATALOG_RELEASE_CLAIMED');
  console.log('PASS p06_claim_single_lease_concurrency (2 connections)');
  const firstReady = deferred(); const releaseFirst = deferred();
  const publishA = workerA.begin(async (tx) => { await asService(tx); const result = await tx`select public.complete_catalog_release_publish(${id.release}::uuid,${lease.lease_token}::uuid,${lease.release_row_version})`; firstReady.resolve(); await releaseFirst.promise; return result; });
  await firstReady.promise;
  const publishB = workerB.begin(async (tx) => { await asService(tx); return tx`select public.complete_catalog_release_publish(${id.release}::uuid,${lease.lease_token}::uuid,${lease.release_row_version})`; });
  try { await assertBlocked(publishB, 'catalog publication serialization'); } finally { releaseFirst.resolve(); }
  await Promise.all([publishA, publishB]);
  const evidence = await admin`select status,publish_attempts from public.catalog_releases where id=${id.release}::uuid`;
  if (evidence[0].status !== 'PUBLISHED' || evidence[0].publish_attempts !== 1) throw new Error('publication retry was not idempotent');
  console.log('PASS p06_publish_lease_concurrency (2 connections)');

  await admin`insert into public.catalog_releases(id,library_id,release_key,status,source_bundle_hash,snapshot_hash,audience,effective_from,created_by) values(${id.reclaimRelease}::uuid,${id.library}::uuid,${`RC.${id.reclaimRelease.replaceAll('-', '').slice(0, 20).toUpperCase()}`},'SCHEDULED',${'9'.repeat(64)},${'9'.repeat(64)},'{"kind":"PUBLIC"}',clock_timestamp()-interval '1 minute',${id.user}::uuid)`;
  const originalClaimRows = await workerA.begin(async (tx) => { await asService(tx); return tx`select public.claim_catalog_release(${id.worker}::uuid,${id.reclaimRelease}::uuid,1) as result`; });
  const originalLease = originalClaimRows[0].result;
  await new Promise((resolveWait) => setTimeout(resolveWait, 1100));
  const reclaimResults = await Promise.all([
    workerA.begin(async (tx) => { await asService(tx); return tx`select public.claim_catalog_release(${id.worker}::uuid,${id.reclaimRelease}::uuid,30) as result`; }),
    workerB.begin(async (tx) => { await asService(tx); return tx`select public.claim_catalog_release(${id.workerB}::uuid,${id.reclaimRelease}::uuid,30) as result`; }),
  ]);
  const reclaimPayloads = reclaimResults.map((rows) => rows[0].result);
  if (reclaimPayloads.filter((value) => value.outcome === 'CATALOG_RELEASE_CLAIMED').length !== 1 || reclaimPayloads.filter((value) => value.outcome === 'NO_CATALOG_RELEASE_DUE').length !== 1) throw new Error('expired lease reclaim did not yield exactly one new owner');
  const reclaimedLease = reclaimPayloads.find((value) => value.outcome === 'CATALOG_RELEASE_CLAIMED');
  let staleTokenRejected = false;
  try {
    await workerA.begin(async (tx) => { await asService(tx); return tx`select public.fail_catalog_release_publish(${id.reclaimRelease}::uuid,${originalLease.lease_token}::uuid,'STALE_WORKER',3)`; });
  } catch (error) { staleTokenRejected = error.message.includes('INVALID_CATALOG_LEASE'); }
  if (!staleTokenRejected) throw new Error('expired pre-reclaim token was not rejected');
  console.log('PASS p06_expired_lease_reclaim_concurrency (2 connections)');
  await workerB.begin(async (tx) => { await asService(tx); return tx`select public.fail_catalog_release_publish(${id.reclaimRelease}::uuid,${reclaimedLease.lease_token}::uuid,'RECLAIM_EVIDENCE',${reclaimedLease.release_row_version})`; });
  await new Promise((resolveWait) => setTimeout(resolveWait, 2100));
  const terminalClaimRows = await workerA.begin(async (tx) => { await asService(tx); return tx`select public.claim_catalog_release(${id.worker}::uuid,${id.reclaimRelease}::uuid,30) as result`; });
  const terminalLease = terminalClaimRows[0].result;
  await workerA.begin(async (tx) => { await asService(tx); return tx`select public.fail_catalog_release_publish(${id.reclaimRelease}::uuid,${terminalLease.lease_token}::uuid,'RECLAIM_TERMINAL',${terminalLease.release_row_version})`; });
  await neutralizePartialFixtures(admin);
  const residual = await admin`select
    (select count(*)::integer from public.organizations organization join auth.users fixture_user on fixture_user.id=organization.created_by
      where organization.display_name='P06 Concurrency' and fixture_user.email like 'p06-%@example.invalid' and organization.status<>'ARCHIVED') as active_organizations,
    (select count(*)::integer from public.organization_memberships membership join public.organizations organization on organization.id=membership.organization_id
      join auth.users fixture_user on fixture_user.id=organization.created_by where organization.display_name='P06 Concurrency'
        and fixture_user.email like 'p06-%@example.invalid' and membership.status<>'REVOKED') as active_memberships,
    (select count(*)::integer from public.catalog_releases release join public.catalog_libraries library on library.id=release.library_id
      join public.organizations organization on organization.id=library.steward_organization_id join auth.users fixture_user on fixture_user.id=organization.created_by
      where organization.display_name='P06 Concurrency' and fixture_user.email like 'p06-%@example.invalid'
        and release.status in ('DRAFT','IN_REVIEW','APPROVED','SCHEDULED','PUBLISHING','FAILED')) as unfinished_releases`;
  if (Object.values(residual[0]).some((value) => value !== 0)) throw new Error('P06 concurrency fixture neutralization verification failed');
  console.log(`INFO retained immutable archived P06 evidence fixture organization=${id.org}`);
} finally {
  await Promise.allSettled([workerA.end(), workerB.end()]);
  await admin.end({ timeout: 2 });
}
