import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import postgres from 'postgres';

const parseEnv = (source) => Object.fromEntries(source.split(/\r?\n/).flatMap((line) => {
  const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
  return match ? [[match[1], match[2].replace(/^(['"])(.*)\1$/, '$2')]] : [];
}));
function deferred() { let resolvePromise; let rejectPromise; const promise = new Promise((resolveValue, rejectValue) => { resolvePromise = resolveValue; rejectPromise = rejectValue; }); return { promise, resolve: resolvePromise, reject: rejectPromise }; }
async function timeout(promise, label) { let timer; try { return await Promise.race([promise, new Promise((_, reject) => { timer = setTimeout(() => reject(new Error(`${label} timed out`)), 15_000); })]); } finally { clearTimeout(timer); } }
async function blocked(promise, label) { let settled = false; promise.finally(() => { settled = true; }).catch(() => {}); await new Promise((resolveWait) => setTimeout(resolveWait, 300)); if (settled) throw new Error(`${label} did not overlap the permission-holding transaction`); }
async function databaseUrl(env, metadata) {
  const configured = env.SUPABASE_DB_POOLER_URL || env.DIRECT_URL;
  if (!configured?.startsWith('postgres')) throw new Error('A PostgreSQL DIRECT_URL is required');
  const url = new URL(configured); const direct = `db.${metadata.project_ref}.supabase.co`; const pooler = `aws-0-${metadata.region}.pooler.supabase.com`;
  if (url.hostname === direct && url.username === 'postgres') { url.hostname = pooler; url.port = '5432'; url.username = `postgres.${metadata.project_ref}`; }
  else if (url.hostname !== pooler || url.username !== `postgres.${metadata.project_ref}`) throw new Error('Database target is not the configured Supabase development project');
  if (url.port !== '5432') throw new Error('Supabase development pooler must use port 5432');
  url.searchParams.set('sslmode', 'require'); return url.toString();
}

const root = resolve(import.meta.dirname, '..');
const env = { ...parseEnv(await readFile(resolve(root, '.env.local'), 'utf8')), ...process.env };
const metadata = JSON.parse(await readFile(resolve(root, 'supabase/project-metadata.json'), 'utf8'));
if (env.APP_ENV !== 'development' || metadata.environment !== 'development') throw new Error('Hierarchy command concurrency tests are development-only');
if (!/^[a-z0-9]{20}$/.test(metadata.project_ref ?? '')) throw new Error('Invalid Supabase development project_ref');
if (!/^[a-z]{2}(?:-[a-z0-9]+)+-[1-9][0-9]*$/.test(metadata.region ?? '')) throw new Error('Invalid Supabase development region');
if (new URL(env.NEXT_PUBLIC_SUPABASE_URL).hostname !== `${metadata.project_ref}.supabase.co`) throw new Error('Supabase project mismatch');
const url = await databaseUrl(env, metadata);
const admin = postgres(url, { max: 1, prepare: false, connect_timeout: 15 });
const workerA = postgres(url, { max: 8, prepare: false, connect_timeout: 15 });
const workerB = postgres(url, { max: 1, prepare: false, connect_timeout: 15 });
const id = { actor: randomUUID(), reviewer: randomUUID(), organization: randomUUID(), membership: randomUUID(), library: undefined, libraryVersion: undefined, mandate: undefined, category: undefined, categoryVersion: undefined, subcategory: undefined, subcategoryVersion: undefined, change: undefined };
const key = Object.fromEntries(['libraryCreate','librarySave','categoryCreate','categorySave','subcategoryCreate','subcategorySave','submit','decide','revoke'].map((name) => [name, `p06-hierarchy-${name}-${randomUUID()}`]));
const correlation = Object.fromEntries(Object.keys(key).map((name) => [name, randomUUID()]));
const librarySuffix = id.organization.replaceAll('-', '').slice(0, 12).toUpperCase();

async function asActor(transaction, actorId) {
  await transaction.unsafe('set local role authenticated');
  await transaction.unsafe("set local lock_timeout='5s'; set local statement_timeout='10s'");
  await transaction`select set_config('request.jwt.claim.role','authenticated',true)`;
  await transaction`select set_config('request.jwt.claims',${JSON.stringify({ sub: actorId, role: 'authenticated', aal: 'aal2' })},true)`;
}
async function resetActor(transaction) { await transaction.unsafe('reset role'); }

async function libraryCreate(transaction) {
  const rows = await transaction`select public.create_catalog_library(${id.organization}::uuid,${`P06_${librarySuffix}`},${`p06-${librarySuffix.toLowerCase()}`} ,'Bibliothèque course','مكتبة السباق','Preuve de concurrence','دليل التزامن','race',1,false,'Création test',${key.libraryCreate},${correlation.libraryCreate}::uuid) response`;
  return rows[0].response;
}
async function librarySave(transaction) {
  const rows = await transaction`select public.save_catalog_library_draft(${id.library}::uuid,${id.libraryVersion}::uuid,'Bibliothèque sauvée','المكتبة المحفوظة','État sauvé','الحالة المحفوظة','race',2,false,'Sauvegarde test',1,1,${key.librarySave},${correlation.librarySave}::uuid) response`;
  return rows[0].response;
}
async function categoryCreate(transaction) {
  const rows = await transaction`select public.create_catalog_category(${id.library}::uuid,'P06_RACE_CAT','p06-race-cat','Catégorie course','فئة السباق','Description catégorie','وصف الفئة','category',1,'{}'::jsonb,false,'Création catégorie',${key.categoryCreate},${correlation.categoryCreate}::uuid) response`;
  return rows[0].response;
}
async function categorySave(transaction) {
  const rows = await transaction`select public.save_catalog_category_draft(${id.category}::uuid,${id.categoryVersion}::uuid,'Catégorie sauvée','الفئة المحفوظة','Description sauvée','الوصف المحفوظ','category',2,'{}'::jsonb,false,'Sauvegarde catégorie',1,1,${key.categorySave},${correlation.categorySave}::uuid) response`;
  return rows[0].response;
}
async function subcategoryCreate(transaction) {
  const rows = await transaction`select public.create_catalog_subcategory(${id.category}::uuid,'P06_RACE_SUB','p06-race-sub','Sous-catégorie course','فئة فرعية للسباق','Description sous-catégorie','وصف الفئة الفرعية','subcategory',1,'{}'::jsonb,true,'Création sous-catégorie',${key.subcategoryCreate},${correlation.subcategoryCreate}::uuid) response`;
  return rows[0].response;
}
async function subcategorySave(transaction) {
  const rows = await transaction`select public.save_catalog_subcategory_draft(${id.subcategory}::uuid,${id.subcategoryVersion}::uuid,'Sous-catégorie sauvée','الفئة الفرعية المحفوظة','Description sauvée','الوصف المحفوظ','subcategory',2,'{}'::jsonb,true,'Sauvegarde sous-catégorie',1,1,${key.subcategorySave},${correlation.subcategorySave}::uuid) response`;
  return rows[0].response;
}
async function submit(transaction) {
  const rows = await transaction`select public.submit_catalog_change('SUBCATEGORY',${id.subcategory}::uuid,${id.subcategoryVersion}::uuid,2,2,${key.submit},${correlation.submit}::uuid) response`;
  return rows[0].response;
}
async function decide(transaction) {
  const rows = await transaction`select public.decide_catalog_change(${id.change}::uuid,'APPROVE','Validation centrale',1,${key.decide},${correlation.decide}::uuid) response`;
  return rows[0].response;
}

async function neutralize() {
  await admin.begin(async (transaction) => {
    await resetActor(transaction);
    await transaction`update public.platform_user_roles set revoked_at=coalesce(revoked_at,clock_timestamp()) where user_id=${id.reviewer}::uuid and role_code='MATRICIA_ADMIN' and revoked_at is null`;
    await transaction`update public.organization_member_roles set revoked_at=coalesce(revoked_at,clock_timestamp()) where membership_id=${id.membership}::uuid and revoked_at is null`;
    await transaction`update public.organization_memberships set status='REVOKED',updated_at=clock_timestamp(),row_version=row_version+1 where id=${id.membership}::uuid and status<>'REVOKED'`;
    if (id.mandate) {
      await transaction`insert into private.catalog_acl_write_capabilities(backend_pid,transaction_id) values(pg_backend_pid(),txid_current()) on conflict do nothing`;
      await transaction`update public.catalog_library_mandates set status='REVOKED',valid_until=coalesce(valid_until,clock_timestamp()),row_version=row_version+1 where id=${id.mandate}::uuid and status='ACTIVE'`;
      await transaction`delete from private.catalog_acl_write_capabilities where backend_pid=pg_backend_pid() and transaction_id=txid_current()`;
    }
    await transaction`update public.organizations set status='ARCHIVED',updated_at=clock_timestamp(),row_version=row_version+1 where id=${id.organization}::uuid and status<>'ARCHIVED'`;
    await transaction`update auth.users set banned_until='2099-01-01T00:00:00Z',raw_app_meta_data=coalesce(raw_app_meta_data,'{}'::jsonb)||'{"p06_hierarchy_neutralized":true}'::jsonb where id in (${id.actor}::uuid,${id.reviewer}::uuid)`;
  });
}

let first; let mandateRevocation; let centralRevocation; let revokeFirstOperations = []; let releaseFirst; let releaseSecond; let releaseThird; let failure;
try {
  const migration = await admin`select version from supabase_migrations.schema_migrations where version='20260911004300'`;
  if (migration.length !== 1) throw new Error('Migration 20260911004300 must be applied before this two-connection test');
  await admin.begin(async (transaction) => {
    await transaction`insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
      (${id.actor}::uuid,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',${`p06-hierarchy-${id.actor}@example.invalid`},'',now(),'{}','{}',now(),now()),
      (${id.reviewer}::uuid,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',${`p06-hierarchy-review-${id.reviewer}@example.invalid`},'',now(),'{}','{}',now(),now())`;
    await transaction`insert into public.organizations(id,legal_name,display_name,status,created_by) values(${id.organization}::uuid,${`P06 Hierarchy Race ${id.organization}`},${`P06 Hierarchy ${id.organization}`},'ACTIVE',${id.actor}::uuid)`;
    await transaction`insert into public.platform_user_roles(user_id,role_code,granted_by) values(${id.reviewer}::uuid,'MATRICIA_ADMIN',${id.reviewer}::uuid)`;
    await asActor(transaction, id.reviewer);
    const created = await libraryCreate(transaction); id.library = created.library_id; id.libraryVersion = created.version_id;
    await resetActor(transaction);
    const mandates = await transaction`select id from public.catalog_library_mandates where library_id=${id.library}::uuid and organization_id=${id.organization}::uuid and status='ACTIVE'`; id.mandate = mandates[0].id;
    await transaction`insert into public.organization_memberships(id,organization_id,user_id,status,activated_at) values(${id.membership}::uuid,${id.organization}::uuid,${id.actor}::uuid,'ACTIVE',now())`;
    await transaction`insert into public.organization_member_roles(membership_id,role_code,library_id) values(${id.membership}::uuid,'FRANCHISE_OWNER',${id.library}::uuid)`;
  });

  const ready = deferred(); const release = deferred(); releaseFirst = release.resolve;
  first = workerA.begin(async (transaction) => {
    try {
      const observed = {};
      await asActor(transaction, id.reviewer); observed.libraryCreate = await libraryCreate(transaction);
      await asActor(transaction, id.actor); observed.librarySave = await librarySave(transaction);
      observed.categoryCreate = await categoryCreate(transaction); id.category = observed.categoryCreate.category_id; id.categoryVersion = observed.categoryCreate.version_id;
      observed.categorySave = await categorySave(transaction);
      observed.subcategoryCreate = await subcategoryCreate(transaction); id.subcategory = observed.subcategoryCreate.subcategory_id; id.subcategoryVersion = observed.subcategoryCreate.version_id;
      observed.subcategorySave = await subcategorySave(transaction); observed.submit = await submit(transaction); id.change = observed.submit.change_request_id;
      await asActor(transaction, id.reviewer); observed.decide = await decide(transaction);
      ready.resolve(observed); await release.promise; return observed;
    } catch (error) { ready.reject(error); throw error; }
  });
  const observed = await timeout(ready.promise, 'eight-command readiness');
  mandateRevocation = workerB.begin(async (transaction) => { await asActor(transaction, id.reviewer); const claims = await transaction`select auth.uid() actor,auth.jwt()->>'aal' aal`; if (claims[0]?.actor !== id.reviewer || claims[0]?.aal !== 'aal2') throw new Error('reviewer AAL2 claims were not installed'); const rows = await transaction`select public.revoke_catalog_library_mandate(${id.mandate}::uuid,1,'Révocation concurrente',${key.revoke},${correlation.revoke}::uuid) response`; return rows[0].response; }).catch((error) => {
    if (error?.code === '42501' && error?.message === 'CATALOG_MANDATE_REVOKE_DENIED') return { outcome: 'CATALOG_MANDATE_REVOKE_DENIED' };
    throw error;
  });
  await blocked(mandateRevocation, 'mandate revocation');
  centralRevocation = admin`update public.platform_user_roles set revoked_at=clock_timestamp() where user_id=${id.reviewer}::uuid and role_code='MATRICIA_ADMIN' and revoked_at is null returning user_id`;
  await blocked(centralRevocation, 'central role revocation');
  release.resolve();
  const settled = await timeout(Promise.allSettled([first, mandateRevocation, centralRevocation]), 'permission-first settlement');
  if (settled[0].status === 'rejected' || settled[2].status === 'rejected') throw new AggregateError([settled[0],settled[2]].filter((result) => result.status === 'rejected').map((result) => result.reason), 'permission-first command or central revocation failed');
  const mandateDeniedAfterCentralWin = settled[1].status === 'fulfilled' && settled[1].value?.outcome === 'CATALOG_MANDATE_REVOKE_DENIED';
  if (JSON.stringify(settled[0].value) !== JSON.stringify(observed) || settled[1].status === 'rejected' || !['CATALOG_MANDATE_REVOKED','CATALOG_MANDATE_REVOKE_DENIED'].includes(settled[1].value?.outcome) || settled[2].value.length !== 1) throw new Error('permission-first race produced unexpected results');

  await admin.begin(async (transaction) => {
    await transaction`update public.platform_user_roles set revoked_at=null where user_id=${id.reviewer}::uuid and role_code='MATRICIA_ADMIN'`;
    if (mandateDeniedAfterCentralWin) {
      await asActor(transaction,id.reviewer);
      await transaction`select public.revoke_catalog_library_mandate(${id.mandate}::uuid,1,'Révocation après course',${`p06-hierarchy-revoke-retry-${randomUUID()}`},${randomUUID()}::uuid)`;
      await resetActor(transaction);
    }
    id.mandate = randomUUID();
    await transaction`insert into private.catalog_acl_write_capabilities(backend_pid,transaction_id) values(pg_backend_pid(),txid_current())`;
    await transaction`insert into public.catalog_library_mandates(id,library_id,organization_id,status,valid_from,policy_version,created_by) values(${id.mandate}::uuid,${id.library}::uuid,${id.organization}::uuid,'ACTIVE',clock_timestamp(),1,${id.reviewer}::uuid)`;
    await transaction`delete from private.catalog_acl_write_capabilities where backend_pid=pg_backend_pid() and transaction_id=txid_current()`;
  });

  const mandateLocked = deferred(); const secondRelease = deferred(); releaseSecond = secondRelease.resolve;
  const revokeMandateFirst = workerB.begin(async (transaction) => {
    await asActor(transaction,id.reviewer);
    const rows = await transaction`select public.revoke_catalog_library_mandate(${id.mandate}::uuid,1,'Révocation avant commandes',${`p06-hierarchy-revoke-first-${randomUUID()}`},${randomUUID()}::uuid) response`;
    mandateLocked.resolve(); await secondRelease.promise; return rows[0].response;
  }).catch((error) => { mandateLocked.reject(error); throw error; });
  revokeFirstOperations = [revokeMandateFirst];
  await timeout(mandateLocked.promise,'mandate-first lock readiness');
  const mandateBlockedCommands = [
    ['library save',librarySave,id.actor,['CATALOG_SCOPE_DENIED']],
    ['category create',categoryCreate,id.actor,['CATALOG_SCOPE_DENIED']],
    ['category save',categorySave,id.actor,['CATALOG_SCOPE_DENIED']],
    ['subcategory create',subcategoryCreate,id.actor,['CATALOG_SCOPE_DENIED']],
    ['subcategory save',subcategorySave,id.actor,['CATALOG_SCOPE_DENIED']],
    ['submit',submit,id.actor,['CATALOG_SCOPE_DENIED']],
  ].map(([label,invoke,actorId,expected]) => ({ label, expected, promise: workerA.begin(async (transaction) => { await asActor(transaction,actorId); return invoke(transaction); }) }));
  revokeFirstOperations.push(...mandateBlockedCommands.map(({ promise }) => promise));
  await Promise.all(mandateBlockedCommands.map(({ label,promise }) => blocked(promise,`${label} mandate-first`)));
  secondRelease.resolve();
  const mandateFirstSettled = await timeout(Promise.allSettled(revokeFirstOperations),'mandate-first settlement');
  if (mandateFirstSettled[0].status !== 'fulfilled' || mandateFirstSettled[0].value?.outcome !== 'CATALOG_MANDATE_REVOKED') throw new Error('mandate-first revocation failed');
  mandateBlockedCommands.forEach(({ label,expected },index) => {
    const result = mandateFirstSettled[index+1];
    if (result.status !== 'rejected' || !expected.some((code) => result.reason?.message?.includes(code))) throw new Error(`${label} did not fail after the held revocation committed`);
  });
  revokeFirstOperations = [];

  const centralLocked = deferred(); const thirdRelease = deferred(); releaseThird = thirdRelease.resolve;
  const revokeCentralFirst = admin.begin(async (transaction) => {
    const rows = await transaction`update public.platform_user_roles set revoked_at=clock_timestamp() where user_id=${id.reviewer}::uuid and role_code='MATRICIA_ADMIN' and revoked_at is null returning user_id`;
    centralLocked.resolve(); await thirdRelease.promise; return rows;
  }).catch((error) => { centralLocked.reject(error); throw error; });
  revokeFirstOperations = [revokeCentralFirst];
  await timeout(centralLocked.promise,'central-first lock readiness');
  const centralBlockedCommands = [
    ['library create',libraryCreate,id.reviewer,['CENTRAL_MFA_REQUIRED']],
    ['decide',decide,id.reviewer,['CATALOG_APPROVAL_DENIED']],
  ].map(([label,invoke,actorId,expected]) => ({ label, expected, promise: workerA.begin(async (transaction) => { await asActor(transaction,actorId); return invoke(transaction); }) }));
  revokeFirstOperations.push(...centralBlockedCommands.map(({ promise }) => promise));
  await Promise.all(centralBlockedCommands.map(({ label,promise }) => blocked(promise,`${label} central-first`)));
  thirdRelease.resolve();
  const centralFirstSettled = await timeout(Promise.allSettled(revokeFirstOperations),'central-first settlement');
  if (centralFirstSettled[0].status !== 'fulfilled' || centralFirstSettled[0].value.length !== 1) throw new Error('central-first revocation failed');
  centralBlockedCommands.forEach(({ label,expected },index) => {
    const result = centralFirstSettled[index+1];
    if (result.status !== 'rejected' || !expected.some((code) => result.reason?.message?.includes(code))) throw new Error(`${label} did not fail after the held central revocation committed`);
  });
  revokeFirstOperations = [];

  const evidence = await admin`select
    (select count(*)::integer from public.catalog_command_keys where actor_user_id in (${id.actor}::uuid,${id.reviewer}::uuid) and key=any(${Object.values(key)}::text[])) commands,
    (select count(*)::integer from public.audit_events where organization_id=${id.organization}::uuid and action in ('catalog.library.created','catalog.library.draft_saved','catalog.category.created','catalog.category.draft_saved','catalog.subcategory.created','catalog.subcategory.draft_saved','catalog.change.submitted','catalog.change.approved')) audits,
    (select count(*)::integer from public.event_outbox where organization_id=${id.organization}::uuid and event_type in ('CatalogLibraryCreatedV1','CatalogLibraryDraftSavedV1','CatalogCategoryCreatedV1','CatalogCategoryDraftSavedV1','CatalogSubcategoryCreatedV1','CatalogSubcategoryDraftSavedV1','CatalogChangeSubmittedV1','CatalogChangeApprovedV1')) outbox`;
  if (![8,9].includes(evidence[0].commands) || evidence[0].audits !== 8 || evidence[0].outbox !== 8) throw new Error('eight-family race evidence is incomplete or duplicated');
  console.log('PASS p06_hierarchy_eight_family_permission_revocation (2 connections)');
} catch (error) { failure = error; }
finally {
  releaseFirst?.(); releaseSecond?.(); releaseThird?.();
  const operations = await timeout(Promise.allSettled([first,mandateRevocation,centralRevocation,...revokeFirstOperations].filter(Boolean)), 'final settlement').catch((error) => [{ status: 'rejected', reason: error }]);
  const lifecycle = operations.filter((result) => result.status === 'rejected' && result.reason !== failure).map((result) => result.reason);
  await Promise.allSettled([workerA.end({ timeout: 2 }),workerB.end({ timeout: 2 })]);
  try { if ((await admin`select 1 from auth.users where id=${id.actor}::uuid`).length) await neutralize(); } catch (error) { lifecycle.push(error); }
  await admin.end({ timeout: 2 });
  const errors = [failure,...lifecycle].filter(Boolean); if (errors.length === 1) throw errors[0]; if (errors.length > 1) throw new AggregateError(errors,'hierarchy race and lifecycle failed');
}
