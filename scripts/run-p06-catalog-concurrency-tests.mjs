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
async function withTimeout(promise, milliseconds, label) {
  let timeout;
  try {
    return await Promise.race([
      promise,
      new Promise((_, reject) => { timeout = setTimeout(() => reject(new Error(`${label} timed out`)), milliseconds); }),
    ]);
  } finally { clearTimeout(timeout); }
}
const pendingOperations = new Set();
function trackOperation(promise) {
  pendingOperations.add(promise);
  promise.finally(() => pendingOperations.delete(promise)).catch(() => {});
  return promise;
}
async function settleOperations(promises, label) {
  const tracked = promises.map(trackOperation);
  return withTimeout(Promise.allSettled(tracked), 15_000, `${label} settlement`);
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
const id = Object.fromEntries(['user','reviewer','org','member','library','libraryVersion','category','categoryVersion','subcategory','subcategoryVersion','service','serviceVersion','link','linkVersion','release','reclaimRelease','reclaimLibraryVersion','reclaimCategoryVersion','reclaimSubcategoryVersion','reclaimServiceVersion','reclaimLinkVersion','worker','workerB'].map((key) => [key, randomUUID()]));
const hash = Object.fromEntries(['library','category','subcategory','service','link'].map((key, index) => [key, String.fromCharCode(97 + index).repeat(64)]));
const reclaimHash = Object.fromEntries(['library','category','subcategory','service','link'].map((key, index) => [key, String(5 + index).repeat(64)]));
const primaryReleaseKey = `CC.${id.release.replaceAll('-', '').slice(0, 20).toUpperCase()}`;
const primarySourceHash = 'f'.repeat(64);
const primaryCreateKey = `p06-create-${randomUUID()}`;
const primaryItemKeys = Array.from({ length: 5 }, () => `p06-item-${randomUUID()}`);
const primaryAttestKeys = Array.from({ length: 4 }, () => `p06-attest-${randomUUID()}`);
const primarySubmitKey = `p06-submit-${randomUUID()}`;
const primaryScheduleKeys = Array.from({ length: 2 }, () => `p06-schedule-${randomUUID()}`);
const primaryEffectiveFrom = new Date(Date.now() - 1_000).toISOString();

async function asActor(transaction, actorId) {
  await transaction.unsafe('set local role authenticated');
  await transaction.unsafe("set local lock_timeout='5s'; set local statement_timeout='10s'");
  await transaction`select set_config('request.jwt.claim.sub',${actorId},true)`;
  await transaction`select set_config('request.jwt.claims',${JSON.stringify({ sub: actorId, role: 'authenticated', aal: 'aal2' })},true)`;
}
async function asOwner(transaction) { await asActor(transaction, id.user); }
async function asReviewer(transaction) { await asActor(transaction, id.reviewer); }
async function asService(transaction) {
  await transaction.unsafe('set local role service_role');
  await transaction.unsafe("set local lock_timeout='5s'; set local statement_timeout='10s'");
  await transaction`select set_config('request.jwt.claim.role','service_role',true)`;
  await transaction`select set_config('request.jwt.claims','{"role":"service_role"}',true)`;
}

async function neutralizeRunFixtures(database) {
  await database.begin(async (transaction) => {
    await transaction`update public.catalog_releases set status='RETIRED',retired_at=clock_timestamp(),row_version=row_version+1
      where id in (${id.release}::uuid,${id.reclaimRelease}::uuid) and status='PUBLISHED'`;
    await transaction`update public.catalog_releases set status='CANCELLED',lease_token=null,leased_until=null,next_attempt_at=null,row_version=row_version+1
      where id in (${id.release}::uuid,${id.reclaimRelease}::uuid)
        and status in ('DRAFT','IN_REVIEW','APPROVED','SCHEDULED','PUBLISHING','FAILED')`;
    await transaction`update public.organization_member_roles role set revoked_at=coalesce(role.revoked_at,clock_timestamp())
      where role.membership_id=${id.member}::uuid and role.revoked_at is null`;
    await transaction`update public.organization_memberships set status='REVOKED',updated_at=clock_timestamp(),row_version=row_version+1
      where id=${id.member}::uuid and organization_id=${id.org}::uuid and user_id=${id.user}::uuid and status<>'REVOKED'`;
    await transaction`update public.platform_user_roles set revoked_at=coalesce(revoked_at,clock_timestamp())
      where user_id=${id.reviewer}::uuid and role_code='MATRICIA_ADMIN' and revoked_at is null`;
    await transaction`update public.organizations set status='ARCHIVED',updated_at=clock_timestamp(),row_version=row_version+1
      where id=${id.org}::uuid and created_by=${id.user}::uuid and status<>'ARCHIVED'`;
  });
}

let failure;
try {
  await admin.begin(async (tx) => {
    await tx`insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
      (${id.user}::uuid,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',${`p06-${id.user}@example.invalid`},'',now(),'{}','{}',now(),now()),
      (${id.reviewer}::uuid,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',${`p06-reviewer-${id.reviewer}@example.invalid`},'',now(),'{}','{}',now(),now())`;
    await tx`insert into public.organizations(id,legal_name,display_name,status,created_by) values(${id.org}::uuid,'P06 Concurrency Evidence','P06 Concurrency','ACTIVE',${id.user}::uuid)`;
    await tx`insert into public.organization_memberships(id,organization_id,user_id,status,activated_at) values(${id.member}::uuid,${id.org}::uuid,${id.user}::uuid,'ACTIVE',now())`;
    await tx`insert into public.catalog_libraries(id,code,slug,steward_organization_id,created_by) values(${id.library}::uuid,${`CC_${id.library.replaceAll('-', '').slice(0, 12).toUpperCase()}`},${`cc-${id.library}`},${id.org}::uuid,${id.user}::uuid)`;
    await tx`insert into public.organization_member_roles(membership_id,role_code,library_id) values(${id.member}::uuid,'FRANCHISE_OWNER',${id.library}::uuid)`;
    await tx`insert into public.platform_user_roles(user_id,role_code,granted_by) values(${id.reviewer}::uuid,'MATRICIA_ADMIN',${id.user}::uuid)`;
    await tx`insert into public.catalog_library_mandates(library_id,organization_id,status,valid_from,policy_version,created_by) values(${id.library}::uuid,${id.org}::uuid,'ACTIVE',now()-interval '1 day',1,${id.user}::uuid)`;
    await tx`insert into public.catalog_library_versions(id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,change_reason,content_hash,created_by) values(${id.libraryVersion}::uuid,${id.library}::uuid,1,'APPROVED','Bibliothèque concurrence','مكتبة التزامن','Preuve de concurrence','دليل التزامن','concurrency',1,'Fixture de concurrence',${hash.library},${id.user}::uuid)`;
    await tx`insert into public.catalog_categories(id,library_id,code,slug,created_by) values(${id.category}::uuid,${id.library}::uuid,'CONCURRENCY_CATEGORY','concurrency-category',${id.user}::uuid)`;
    await tx`insert into public.catalog_category_versions(id,category_id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,created_by) values(${id.categoryVersion}::uuid,${id.category}::uuid,${id.library}::uuid,1,'APPROVED','Catégorie concurrence','فئة التزامن','Preuve catégorie','دليل الفئة',1,'Fixture de concurrence',${hash.category},${id.user}::uuid)`;
    await tx`insert into public.catalog_subcategories(id,library_id,category_id,code,slug,created_by) values(${id.subcategory}::uuid,${id.library}::uuid,${id.category}::uuid,'CONCURRENCY_SUBCATEGORY','concurrency-subcategory',${id.user}::uuid)`;
    await tx`insert into public.catalog_subcategory_versions(id,subcategory_id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,created_by) values(${id.subcategoryVersion}::uuid,${id.subcategory}::uuid,${id.library}::uuid,1,'APPROVED','Sous-catégorie concurrence','فئة فرعية للتزامن','Preuve sous-catégorie','دليل الفئة الفرعية',1,'Fixture de concurrence',${hash.subcategory},${id.user}::uuid)`;
    await tx`insert into public.catalog_services(id,library_id,primary_subcategory_id,code,slug,created_by) values(${id.service}::uuid,${id.library}::uuid,${id.subcategory}::uuid,${`SVC_${id.service.replaceAll('-', '').slice(0, 12).toUpperCase()}`},${`svc-${id.service}`},${id.user}::uuid)`;
    await tx`insert into public.catalog_service_versions(id,service_id,library_id,version,status,name_fr,name_ar,short_description_fr,short_description_ar,long_description_fr,long_description_ar,service_type,unit_label_fr,unit_label_ar,sort_order,change_reason,content_hash,created_by) values(${id.serviceVersion}::uuid,${id.service}::uuid,${id.library}::uuid,1,'APPROVED','Service concurrence','خدمة التزامن','Preuve courte','دليل قصير','Preuve longue de concurrence','دليل طويل للتزامن','PROFESSIONAL','unité','وحدة',1,'Fixture de concurrence',${hash.service},${id.user}::uuid)`;
    await tx`insert into public.catalog_service_subcategory_links(id,service_id,subcategory_id,library_id,link_type,created_by) values(${id.link}::uuid,${id.service}::uuid,${id.subcategory}::uuid,${id.library}::uuid,'PRIMARY',${id.user}::uuid)`;
    await tx`insert into public.catalog_service_subcategory_link_versions(id,link_id,library_id,version,status,change_reason,content_hash,created_by) values(${id.linkVersion}::uuid,${id.link}::uuid,${id.library}::uuid,1,'APPROVED','Fixture de concurrence',${hash.link},${id.user}::uuid)`;
    await asReviewer(tx);
    const attestations = [
      ['LIBRARY',id.libraryVersion,'1'.repeat(64)],['CATEGORY',id.categoryVersion,'2'.repeat(64)],
      ['SUBCATEGORY',id.subcategoryVersion,'3'.repeat(64)],['SERVICE',id.serviceVersion,'4'.repeat(64)],
    ];
    const attestationResponses = [];
    for (let index = 0; index < attestations.length; index += 1) {
      const [type, versionId, proof] = attestations[index];
      const attested = await tx`select public.attest_catalog_ar_translation(${type},${versionId}::uuid,${proof},1,${primaryAttestKeys[index]}) as result`;
      if (attested[0]?.result?.outcome !== 'CATALOG_AR_TRANSLATION_ATTESTED' || attested[0].result.row_version !== 2) throw new Error(`translation attestation failed for ${type}`);
      attestationResponses.push(attested[0].result);
    }
    const attestationReplay = await tx`select public.attest_catalog_ar_translation('LIBRARY',${id.libraryVersion}::uuid,${'1'.repeat(64)},1,${primaryAttestKeys[0]}) as result`;
    if (JSON.stringify(attestationReplay[0]?.result) !== JSON.stringify(attestationResponses[0])) throw new Error('translation attestation replay changed the durable result');
    await asOwner(tx);
    const created = await tx`select public.create_catalog_release(${id.library}::uuid,${primaryReleaseKey},${primarySourceHash},false,1,${primaryCreateKey}) as result`;
    id.release = created[0].result.release_id;
    const items = [['LIBRARY',id.library,id.libraryVersion,hash.library],['CATEGORY',id.category,id.categoryVersion,hash.category],['SUBCATEGORY',id.subcategory,id.subcategoryVersion,hash.subcategory],['SERVICE',id.service,id.serviceVersion,hash.service],['SERVICE_SUBCATEGORY_LINK',id.link,id.linkVersion,hash.link]];
    const itemResponses = [];
    for (let index = 0; index < items.length; index += 1) {
      const [type, objectId, versionId, contentHash] = items[index];
      const added = await tx`select public.add_catalog_release_item(${id.release}::uuid,${type},${objectId}::uuid,${versionId}::uuid,${contentHash},${index + 1},${index + 1},${primaryItemKeys[index]}) as result`;
      itemResponses.push(added[0].result);
    }
    const createReplay = await tx`select public.create_catalog_release(${id.library}::uuid,${primaryReleaseKey},${primarySourceHash},false,1,${primaryCreateKey}) as result`;
    const itemReplay = await tx`select public.add_catalog_release_item(${id.release}::uuid,'LIBRARY',${id.library}::uuid,${id.libraryVersion}::uuid,${hash.library},1,1,${primaryItemKeys[0]}) as result`;
    if (createReplay[0]?.result?.release_id !== id.release || itemReplay[0]?.result?.release_id !== id.release
        || itemReplay[0].result.release_row_version !== itemResponses[0].release_row_version) throw new Error('catalogue create/item idempotent replay changed the durable result');
    const submitted = await tx`select public.submit_catalog_release(${id.release}::uuid,6,${primarySubmitKey}) as result`;
    if (submitted[0]?.result?.status !== 'APPROVED') throw new Error('catalogue concurrency fixture did not reach APPROVED through submit command');
    const submitReplay = await tx`select public.submit_catalog_release(${id.release}::uuid,6,${primarySubmitKey}) as result`;
    if (JSON.stringify(submitReplay[0]?.result) !== JSON.stringify(submitted[0].result)) throw new Error('catalogue submit replay changed the durable result');
  });

  for (const [label, invoke] of [
    ['release create', (tx) => tx`select public.create_catalog_release(${id.library}::uuid,${primaryReleaseKey},${'e'.repeat(64)},false,1,${primaryCreateKey})`],
    ['release item', (tx) => tx`select public.add_catalog_release_item(${id.release}::uuid,'LIBRARY',${id.library}::uuid,${id.libraryVersion}::uuid,${hash.library},99,1,${primaryItemKeys[0]})`],
    ['translation attestation', async (tx) => { await asReviewer(tx); return tx`select public.attest_catalog_ar_translation('LIBRARY',${id.libraryVersion}::uuid,${'9'.repeat(64)},1,${primaryAttestKeys[0]})`; }],
    ['release submit', (tx) => tx`select public.submit_catalog_release(${id.release}::uuid,5,${primarySubmitKey})`],
  ]) {
    let mismatchRejected = false;
    try { await workerA.begin(async (tx) => { await asOwner(tx); return invoke(tx); }); }
    catch (error) { mismatchRejected = error.message.includes('IDEMPOTENCY_PAYLOAD_MISMATCH'); }
    if (!mismatchRejected) throw new Error(`${label} idempotency payload mismatch was not rejected`);
  }

  const scheduleA = workerA.begin(async (tx) => { await asOwner(tx); return tx`select public.schedule_catalog_release(${id.release}::uuid,${primaryEffectiveFrom}::timestamptz,null,'{"kind":"PUBLIC"}'::jsonb,7,${primaryScheduleKeys[0]}) as result`; });
  const scheduleB = workerB.begin(async (tx) => { await asOwner(tx); return tx`select public.schedule_catalog_release(${id.release}::uuid,${primaryEffectiveFrom}::timestamptz,null,'{"kind":"PUBLIC"}'::jsonb,7,${primaryScheduleKeys[1]}) as result`; });
  const scheduleResults = await settleOperations([scheduleA, scheduleB], 'concurrent schedule');
  if (scheduleResults.filter((result) => result.status === 'fulfilled').length !== 1 || !scheduleResults.some((result) => result.status === 'rejected' && result.reason.message.includes('STALE_CATALOG_VERSION'))) throw new Error('concurrent schedules did not yield one success and one stale rejection');
  const scheduleWinner = scheduleResults.findIndex((result) => result.status === 'fulfilled');
  const schedulePayload = scheduleResults[scheduleWinner].value[0]?.result;
  const scheduleReplay = await workerA.begin(async (tx) => { await asOwner(tx); return tx`select public.schedule_catalog_release(${id.release}::uuid,${primaryEffectiveFrom}::timestamptz,null,'{"kind":"PUBLIC"}'::jsonb,7,${primaryScheduleKeys[scheduleWinner]}) as result`; });
  if (JSON.stringify(scheduleReplay[0]?.result) !== JSON.stringify(schedulePayload)) throw new Error('catalogue schedule replay changed the durable result');
  let scheduleMismatchRejected = false;
  try {
    await workerA.begin(async (tx) => { await asOwner(tx); return tx`select public.schedule_catalog_release(${id.release}::uuid,${primaryEffectiveFrom}::timestamptz,null,${{ kind: 'ORGANIZATIONS', organization_ids: [id.org] }}::jsonb,7,${primaryScheduleKeys[scheduleWinner]})`; });
  } catch (error) { scheduleMismatchRejected = error.message.includes('IDEMPOTENCY_PAYLOAD_MISMATCH'); }
  if (!scheduleMismatchRejected) throw new Error('release schedule idempotency payload mismatch was not rejected');
  console.log('PASS p06_schedule_stale_concurrency (2 connections)');

  const claimSettled = await settleOperations([
    workerA.begin(async (tx) => { await asService(tx); return tx`select public.claim_catalog_release(${id.worker}::uuid,${id.release}::uuid,300) as result`; }),
    workerB.begin(async (tx) => { await asService(tx); return tx`select public.claim_catalog_release(${randomUUID()}::uuid,${id.release}::uuid,300) as result`; }),
  ], 'concurrent claim');
  const claimFailures = claimSettled.filter((result) => result.status === 'rejected').map((result) => result.reason);
  if (claimFailures.length) throw new AggregateError(claimFailures, 'concurrent catalogue claims failed');
  const claimResults = claimSettled.map((result) => result.value);
  const claimPayloads = claimResults.map((rows) => rows[0].result);
  if (claimPayloads.filter((value) => value.outcome === 'CATALOG_RELEASE_CLAIMED').length !== 1 || claimPayloads.filter((value) => value.outcome === 'NO_CATALOG_RELEASE_DUE').length !== 1) throw new Error('concurrent workers did not yield exactly one lease');
  const lease = claimPayloads.find((value) => value.outcome === 'CATALOG_RELEASE_CLAIMED');
  console.log('PASS p06_claim_single_lease_concurrency (2 connections)');
  const firstReady = deferred(); const releaseFirst = deferred();
  const publishA = trackOperation(workerA.begin(async (tx) => {
    try {
      await asService(tx);
      const result = await tx`select public.complete_catalog_release_publish(${id.release}::uuid,${lease.lease_token}::uuid,${lease.release_row_version}) as result`;
      firstReady.resolve();
      await releaseFirst.promise;
      return result;
    } catch (error) { firstReady.reject(error); throw error; }
  }));
  let publishB; let handshakeFailure;
  try {
    await withTimeout(firstReady.promise, 12_000, 'first catalogue publication readiness');
    publishB = trackOperation(workerB.begin(async (tx) => { await asService(tx); return tx`select public.complete_catalog_release_publish(${id.release}::uuid,${lease.lease_token}::uuid,${lease.release_row_version}) as result`; }));
    await assertBlocked(publishB, 'catalog publication serialization');
  } catch (error) { handshakeFailure = error; }
  finally { releaseFirst.resolve(); }
  const publishSettled = await withTimeout(Promise.allSettled([publishA, publishB].filter(Boolean)), 15_000, 'catalog publication settlement');
  const publishFailures = publishSettled.filter((result) => result.status === 'rejected').map((result) => result.reason);
  if (handshakeFailure) throw handshakeFailure;
  if (publishFailures.length) throw new AggregateError(publishFailures, 'concurrent catalogue publications failed');
  const publishPayloads = publishSettled.map((result) => result.value[0]?.result);
  if (publishPayloads.some((payload) => payload?.outcome !== 'CATALOG_RELEASE_PUBLISHED' || payload.release_id !== id.release)
      || publishPayloads[0].snapshot_hash !== publishPayloads[1].snapshot_hash) throw new Error('concurrent publish replay returned inconsistent payloads');
  const evidence = await admin`select status,publish_attempts,
    (select count(*)::integer from public.audit_events where action='catalog.release.published' and resource_id=${id.release}) as publish_audits,
    (select count(*)::integer from public.event_outbox where aggregate_id=${id.release} and event_type='CatalogReleasePublishedV1') as publish_events
    from public.catalog_releases where id=${id.release}::uuid`;
  if (evidence[0].status !== 'PUBLISHED' || evidence[0].publish_attempts !== 1
      || evidence[0].publish_audits !== 1 || evidence[0].publish_events !== 1) throw new Error('publication retry was not idempotent or duplicated evidence');
  console.log('PASS p06_publish_lease_concurrency (2 connections)');

  const reclaimReleaseKey = `RC.${id.reclaimRelease.replaceAll('-', '').slice(0, 20).toUpperCase()}`;
  await admin.begin(async (tx) => {
    await tx`insert into public.catalog_library_versions(id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,change_reason,content_hash,created_by) values(${id.reclaimLibraryVersion}::uuid,${id.library}::uuid,2,'APPROVED','Bibliothèque concurrence v2','مكتبة التزامن ٢','Preuve de concurrence v2','دليل التزامن ٢','concurrency',1,'Fixture reclaim',${reclaimHash.library},${id.user}::uuid)`;
    await tx`insert into public.catalog_category_versions(id,category_id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,created_by) values(${id.reclaimCategoryVersion}::uuid,${id.category}::uuid,${id.library}::uuid,2,'APPROVED','Catégorie concurrence v2','فئة التزامن ٢','Preuve catégorie v2','دليل الفئة ٢',1,'Fixture reclaim',${reclaimHash.category},${id.user}::uuid)`;
    await tx`insert into public.catalog_subcategory_versions(id,subcategory_id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,created_by) values(${id.reclaimSubcategoryVersion}::uuid,${id.subcategory}::uuid,${id.library}::uuid,2,'APPROVED','Sous-catégorie concurrence v2','فئة فرعية للتزامن ٢','Preuve sous-catégorie v2','دليل الفئة الفرعية ٢',1,'Fixture reclaim',${reclaimHash.subcategory},${id.user}::uuid)`;
    await tx`insert into public.catalog_service_versions(id,service_id,library_id,version,status,name_fr,name_ar,short_description_fr,short_description_ar,long_description_fr,long_description_ar,service_type,unit_label_fr,unit_label_ar,sort_order,change_reason,content_hash,created_by) values(${id.reclaimServiceVersion}::uuid,${id.service}::uuid,${id.library}::uuid,2,'APPROVED','Service concurrence v2','خدمة التزامن ٢','Preuve courte v2','دليل قصير ٢','Preuve longue de concurrence v2','دليل طويل للتزامن ٢','PROFESSIONAL','unité','وحدة',1,'Fixture reclaim',${reclaimHash.service},${id.user}::uuid)`;
    await tx`insert into public.catalog_service_subcategory_link_versions(id,link_id,library_id,version,status,change_reason,content_hash,created_by) values(${id.reclaimLinkVersion}::uuid,${id.link}::uuid,${id.library}::uuid,2,'APPROVED','Fixture reclaim',${reclaimHash.link},${id.user}::uuid)`;
    await asReviewer(tx);
    for (const [type, versionId, proof] of [
      ['LIBRARY',id.reclaimLibraryVersion,'5'.repeat(64)],['CATEGORY',id.reclaimCategoryVersion,'6'.repeat(64)],
      ['SUBCATEGORY',id.reclaimSubcategoryVersion,'7'.repeat(64)],['SERVICE',id.reclaimServiceVersion,'8'.repeat(64)],
    ]) {
      const attested = await tx`select public.attest_catalog_ar_translation(${type},${versionId}::uuid,${proof},1,${`p06-reclaim-attest-${type.toLowerCase()}-${randomUUID()}`}) as result`;
      if (attested[0]?.result?.outcome !== 'CATALOG_AR_TRANSLATION_ATTESTED') throw new Error(`reclaim translation attestation failed for ${type}`);
    }
  });
  const libraryState = await admin`select row_version from public.catalog_libraries where id=${id.library}::uuid`;
  const reclaimCreated = await workerA.begin(async (tx) => {
    await asOwner(tx);
    return tx`select public.create_catalog_release(${id.library}::uuid,${reclaimReleaseKey},${'9'.repeat(64)},false,${libraryState[0].row_version},${`p06-reclaim-create-${randomUUID()}`}) as result`;
  });
  id.reclaimRelease = reclaimCreated[0].result.release_id;
  const reclaimItems = [
    ['LIBRARY',id.library,id.reclaimLibraryVersion,reclaimHash.library],['CATEGORY',id.category,id.reclaimCategoryVersion,reclaimHash.category],
    ['SUBCATEGORY',id.subcategory,id.reclaimSubcategoryVersion,reclaimHash.subcategory],['SERVICE',id.service,id.reclaimServiceVersion,reclaimHash.service],
    ['SERVICE_SUBCATEGORY_LINK',id.link,id.reclaimLinkVersion,reclaimHash.link],
  ];
  for (let index = 0; index < reclaimItems.length; index += 1) {
    const [type, objectId, versionId, contentHash] = reclaimItems[index];
    const added = await workerA.begin(async (tx) => {
      await asOwner(tx);
      return tx`select public.add_catalog_release_item(${id.reclaimRelease}::uuid,${type},${objectId}::uuid,${versionId}::uuid,${contentHash},${index + 1},${index + 1},${`p06-reclaim-item-${index}-${randomUUID()}`}) as result`;
    });
    if (added[0]?.result?.release_row_version !== index + 2) throw new Error(`reclaim release item ${index + 1} did not advance its version`);
  }
  const reclaimSubmitted = await workerA.begin(async (tx) => {
    await asOwner(tx);
    return tx`select public.submit_catalog_release(${id.reclaimRelease}::uuid,6,${`p06-reclaim-submit-${randomUUID()}`}) as result`;
  });
  if (reclaimSubmitted[0]?.result?.status !== 'APPROVED') throw new Error('reclaim fixture did not reach APPROVED through submit command');
  await workerA.begin(async (tx) => {
    await asOwner(tx);
    return tx`select public.schedule_catalog_release(${id.reclaimRelease}::uuid,statement_timestamp()-interval '1 minute',null,'{"kind":"PUBLIC"}'::jsonb,7,${`p06-reclaim-schedule-${randomUUID()}`})`;
  });
  const originalClaimRows = await workerA.begin(async (tx) => { await asService(tx); return tx`select public.claim_catalog_release(${id.worker}::uuid,${id.reclaimRelease}::uuid,1) as result`; });
  const originalLease = originalClaimRows[0].result;
  await new Promise((resolveWait) => setTimeout(resolveWait, 1100));
  const reclaimSettled = await settleOperations([
    workerA.begin(async (tx) => { await asService(tx); return tx`select public.claim_catalog_release(${id.worker}::uuid,${id.reclaimRelease}::uuid,30) as result`; }),
    workerB.begin(async (tx) => { await asService(tx); return tx`select public.claim_catalog_release(${id.workerB}::uuid,${id.reclaimRelease}::uuid,30) as result`; }),
  ], 'concurrent reclaim');
  const reclaimFailures = reclaimSettled.filter((result) => result.status === 'rejected').map((result) => result.reason);
  if (reclaimFailures.length) throw new AggregateError(reclaimFailures, 'concurrent catalogue reclaims failed');
  const reclaimResults = reclaimSettled.map((result) => result.value);
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
  await neutralizeRunFixtures(admin);
  const residual = await admin`select
    (select count(*)::integer from public.organizations where id=${id.org}::uuid and created_by=${id.user}::uuid and status<>'ARCHIVED') as active_organizations,
    (select count(*)::integer from public.organization_memberships where id=${id.member}::uuid and organization_id=${id.org}::uuid and user_id=${id.user}::uuid and status<>'REVOKED') as active_memberships,
    (select count(*)::integer from public.organization_member_roles where membership_id=${id.member}::uuid and revoked_at is null) as active_organization_roles,
    (select count(*)::integer from public.platform_user_roles where user_id=${id.reviewer}::uuid and role_code='MATRICIA_ADMIN' and revoked_at is null) as active_reviewer_roles,
    (select count(*)::integer from public.catalog_releases where id in (${id.release}::uuid,${id.reclaimRelease}::uuid)
      and status not in ('CANCELLED','RETIRED','DEAD_LETTER','ARCHIVED')) as active_releases`;
  if (Object.values(residual[0]).some((value) => value !== 0)) throw new Error('P06 concurrency fixture neutralization verification failed');
  console.log(`INFO retained immutable archived P06 evidence fixture organization=${id.org}`);
} catch (error) {
  failure = error;
} finally {
  try {
    await withTimeout(Promise.allSettled([...pendingOperations]), 15_000, 'pending catalogue operation drain');
  } catch (error) {
    failure = failure ? new AggregateError([failure, error], 'P06 concurrency run and operation drain failed') : error;
  }
  try { await neutralizeRunFixtures(admin); }
  catch (error) { failure = failure ? new AggregateError([failure, error], 'P06 concurrency run and cleanup failed') : error; }
  const closeResults = await Promise.allSettled([workerA.end(), workerB.end(), admin.end({ timeout: 2 })]);
  const closeErrors = closeResults.filter((result) => result.status === 'rejected').map((result) => result.reason);
  if (closeErrors.length) failure = failure ? new AggregateError([failure, ...closeErrors], 'P06 concurrency run and connection cleanup failed') : new AggregateError(closeErrors, 'P06 connection cleanup failed');
}
if (failure) throw failure;
