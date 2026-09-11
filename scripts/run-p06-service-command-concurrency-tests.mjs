import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import postgres from 'postgres';

function parseEnv(source) {
  return Object.fromEntries(source.split(/\r?\n/).flatMap((line) => {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    return match ? [[match[1], match[2].replace(/^(['"])(.*)\1$/, '$2')]] : [];
  }));
}

function deferred() {
  let resolvePromise;
  let rejectPromise;
  const promise = new Promise((resolveValue, rejectValue) => {
    resolvePromise = resolveValue;
    rejectPromise = rejectValue;
  });
  return { promise, resolve: resolvePromise, reject: rejectPromise };
}

async function resolveDatabaseUrl(root, env) {
  const metadata = JSON.parse(await readFile(resolve(root, 'supabase/project-metadata.json'), 'utf8'));
  if (!['development', 'staging'].includes(env.APP_ENV)
    || !['development', 'staging'].includes(metadata.environment)) {
    throw new Error('Service command concurrency tests are restricted to development/staging');
  }
  if (!/^[a-z0-9]{20}$/.test(metadata.project_ref)
    || !/^[a-z0-9-]+$/.test(metadata.region)) throw new Error('Invalid Supabase project metadata');
  const publicUrl = new URL(env.NEXT_PUBLIC_SUPABASE_URL);
  const publicProjectRef = publicUrl.hostname.match(/^([a-z0-9]{20})\.supabase\.co$/)?.[1];
  if (publicUrl.protocol !== 'https:' || publicProjectRef !== metadata.project_ref) {
    throw new Error('Supabase public URL does not match development/staging project metadata');
  }
  const configured = env.SUPABASE_DB_POOLER_URL || env.DIRECT_URL;
  if (!configured?.startsWith('postgres')) throw new Error('A PostgreSQL development/staging URL is required');
  const url = new URL(configured);
  const directHost = `db.${metadata.project_ref}.supabase.co`;
  const poolerHost = `aws-0-${metadata.region}.pooler.supabase.com`;
  if (url.hostname === directHost) {
    if (decodeURIComponent(url.username) !== 'postgres') throw new Error('Direct database user does not match project metadata');
    url.hostname = poolerHost;
    url.port = '5432';
    url.username = `postgres.${metadata.project_ref}`;
  } else if (url.hostname === poolerHost) {
    if (decodeURIComponent(url.username) !== `postgres.${metadata.project_ref}` || url.port !== '5432') {
      throw new Error('Pooler database URL does not match project metadata');
    }
  } else throw new Error('Database host does not match the configured Supabase development/staging project');
  url.searchParams.set('sslmode', 'require');
  return url.toString();
}

async function setActor(transaction, actorId) {
  await transaction.unsafe('set local role authenticated');
  await transaction`select set_config('request.jwt.claims',${JSON.stringify({ sub: actorId, role: 'authenticated', aal: 'aal2' })},true)`;
}

async function expectBlocked(promise, label) {
  let settled = false;
  promise.finally(() => { settled = true; }).catch(() => {});
  await new Promise((resolveWait) => setTimeout(resolveWait, 250));
  if (settled) throw new Error(`${label} did not overlap the first open transaction`);
}

const root = resolve(import.meta.dirname, '..');
const fileEnv = parseEnv(await readFile(resolve(root, '.env.local'), 'utf8'));
const env = { ...fileEnv, ...process.env };
const databaseUrl = await resolveDatabaseUrl(root, env);
const admin = postgres(databaseUrl, { max: 1, prepare: false, connect_timeout: 15, idle_timeout: 0 });
const workerA = postgres(databaseUrl, { max: 1, prepare: false, connect_timeout: 15, idle_timeout: 0 });
const workerB = postgres(databaseUrl, { max: 1, prepare: false, connect_timeout: 15, idle_timeout: 0 });
const runId = randomUUID();
const compactId = runId.replaceAll('-', '').toUpperCase();
const code = `P06_RACE_${compactId}`;
const slug = `p06-race-${runId}`;
const impactKey = `p06-impact-${runId}`;
const archiveKey = `p06-archive-${runId}`;
const releaseId = randomUUID();
const releaseKey = `P06.RACE.${compactId}`;
const actorId = randomUUID();
const organizationId = randomUUID();
let libraryId;
let libraryVersionId;
let mandateId;
let categoryId;
let categoryVersionId;
let subcategoryId;
let subcategoryVersionId;
let service;
let primaryError;

async function retainArchivedEvidence() {
  if (service?.service_id) {
    const releases = await admin`select status from public.catalog_releases where id=${releaseId}::uuid`;
    if (releases[0]?.status === 'PUBLISHED') {
      await admin`update public.catalog_releases set status='RETIRED',retired_at=clock_timestamp(),row_version=row_version+1 where id=${releaseId}::uuid and status='PUBLISHED'`;
    } else if (['DRAFT', 'SCHEDULED', 'PUBLISHING', 'APPROVED', 'IN_REVIEW'].includes(releases[0]?.status)) {
      await admin`update public.catalog_releases set status='ARCHIVED',row_version=row_version+1 where id=${releaseId}::uuid and status=${releases[0].status}`;
    }
    const candidates = await admin`
      select s.status,s.row_version identity_row_version,v.id version_id,v.row_version version_row_version
      from public.catalog_services s join public.catalog_service_versions v on v.id=coalesce(s.current_draft_version_id,s.current_published_version_id)
      where s.id=${service.service_id}::uuid
    `;
    const candidate = candidates[0];
    if (candidate && candidate.status !== 'ARCHIVED') {
      await workerA.begin(async (transaction) => {
        await setActor(transaction, actorId);
        await transaction`select public.archive_catalog_service(${service.service_id}::uuid,${candidate.version_id}::uuid,${candidate.identity_row_version},${candidate.version_row_version},'Archivage de nettoyage après test de concurrence',${`p06-cleanup-${runId}`},${randomUUID()}::uuid)`;
      });
    }
  }
  if (libraryId) {
    await admin.begin(async (transaction) => {
      if (mandateId) {
        await transaction`insert into private.catalog_acl_write_capabilities(backend_pid,transaction_id) values(pg_backend_pid(),txid_current()) on conflict do nothing`;
        await transaction`update public.catalog_library_mandates set status='REVOKED',valid_until=coalesce(valid_until,clock_timestamp()),row_version=row_version+1 where id=${mandateId}::uuid and status='ACTIVE'`;
        await transaction`delete from private.catalog_acl_write_capabilities where backend_pid=pg_backend_pid() and transaction_id=txid_current()`;
      }
      if (subcategoryVersionId) await transaction`update public.catalog_subcategory_versions set status='ARCHIVED',row_version=row_version+1 where id=${subcategoryVersionId}::uuid and status='DRAFT'`;
      if (subcategoryId) await transaction`update public.catalog_subcategories set status='ARCHIVED',archived_at=coalesce(archived_at,clock_timestamp()),row_version=row_version+1 where id=${subcategoryId}::uuid and status<>'ARCHIVED'`;
      if (categoryVersionId) await transaction`update public.catalog_category_versions set status='ARCHIVED',row_version=row_version+1 where id=${categoryVersionId}::uuid and status='DRAFT'`;
      if (categoryId) await transaction`update public.catalog_categories set status='ARCHIVED',archived_at=coalesce(archived_at,clock_timestamp()),row_version=row_version+1 where id=${categoryId}::uuid and status<>'ARCHIVED'`;
      if (libraryVersionId) await transaction`update public.catalog_library_versions set status='ARCHIVED',row_version=row_version+1 where id=${libraryVersionId}::uuid and status='DRAFT'`;
      await transaction`update public.catalog_libraries set status='ARCHIVED',archived_at=coalesce(archived_at,clock_timestamp()),row_version=row_version+1 where id=${libraryId}::uuid and status<>'ARCHIVED'`;
    });
  }
  await admin`update public.platform_user_roles set revoked_at=coalesce(revoked_at,clock_timestamp()) where user_id=${actorId}::uuid and revoked_at is null`;
  await admin`update public.organizations set status='ARCHIVED',updated_at=clock_timestamp(),row_version=row_version+1 where id=${organizationId}::uuid and status<>'ARCHIVED'`;
  await admin`update auth.users set banned_until='2099-01-01T00:00:00Z',raw_app_meta_data=coalesce(raw_app_meta_data,'{}'::jsonb)||'{"p06_service_neutralized":true}'::jsonb where id=${actorId}::uuid`;
  const neutralized = await admin`
    select
      (select status='ARCHIVED' from public.organizations where id=${organizationId}::uuid) organization_archived,
      (select bool_and(revoked_at is not null) from public.platform_user_roles where user_id=${actorId}::uuid) roles_revoked,
      (select banned_until>clock_timestamp() from auth.users where id=${actorId}::uuid) actor_banned,
      (${libraryId ?? null}::uuid is null or exists(select 1 from public.catalog_libraries where id=${libraryId ?? null}::uuid and status='ARCHIVED')) library_archived,
      (${categoryId ?? null}::uuid is null or exists(select 1 from public.catalog_categories where id=${categoryId ?? null}::uuid and status='ARCHIVED')) category_archived,
      (${subcategoryId ?? null}::uuid is null or exists(select 1 from public.catalog_subcategories where id=${subcategoryId ?? null}::uuid and status='ARCHIVED')) subcategory_archived,
      (${service?.service_id ?? null}::uuid is null or exists(select 1 from public.catalog_services where id=${service?.service_id ?? null}::uuid and status='ARCHIVED')) service_archived,
      (select count(*) from public.audit_events where organization_id=${organizationId}::uuid)>0 audit_retained,
      (select count(*) from public.event_outbox where organization_id=${organizationId}::uuid)>0 outbox_retained
  `;
  if (!neutralized[0] || Object.values(neutralized[0]).some((value) => value !== true)) {
    throw new Error('Generated development fixtures were not fully neutralized with evidence retained');
  }
}

try {
  await admin.begin(async (transaction) => {
    await transaction`insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values(${actorId}::uuid,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',${`p06-service-${runId}@example.invalid`},'',now(),'{}','{}',now(),now())`;
    await transaction`insert into public.organizations(id,legal_name,display_name,status,created_by) values(${organizationId}::uuid,${`P06 Service Race ${runId}`},${`P06 Service ${runId}`},'ACTIVE',${actorId}::uuid)`;
    await transaction`insert into public.platform_user_roles(user_id,role_code,granted_by) values(${actorId}::uuid,'MATRICIA_ADMIN',${actorId}::uuid)`;
  });
  await workerA.begin(async (transaction) => {
    await setActor(transaction, actorId);
    const library = (await transaction`select public.create_catalog_library(${organizationId}::uuid,${`P06SRV_${compactId.slice(0,12)}`},${`p06srv-${runId}`},'Bibliothèque service test','مكتبة اختبار الخدمة','Hiérarchie isolée pour test','تسلسل معزول للاختبار','test-catalog',2147483000,false,'Création fixture concurrence',${`p06-library-${runId}`},${randomUUID()}::uuid) response`)[0].response;
    libraryId = library.library_id; libraryVersionId = library.version_id;
    const category = (await transaction`select public.create_catalog_category(${libraryId}::uuid,${`P06CAT_${compactId.slice(0,12)}`},${`p06cat-${runId}`},'Catégorie service test','فئة اختبار الخدمة','Catégorie isolée pour test','فئة معزولة للاختبار','test-category',2147483000,'{}'::jsonb,false,'Création fixture catégorie',${`p06-category-${runId}`},${randomUUID()}::uuid) response`)[0].response;
    categoryId = category.category_id; categoryVersionId = category.version_id;
    const subcategory = (await transaction`select public.create_catalog_subcategory(${categoryId}::uuid,${`P06SUB_${compactId.slice(0,12)}`},${`p06sub-${runId}`},'Sous-catégorie service test','فئة فرعية لاختبار الخدمة','Sous-catégorie isolée pour test','فئة فرعية معزولة للاختبار','test-subcategory',2147483000,'{}'::jsonb,false,'Création fixture sous-catégorie',${`p06-subcategory-${runId}`},${randomUUID()}::uuid) response`)[0].response;
    subcategoryId = subcategory.subcategory_id; subcategoryVersionId = subcategory.version_id;
  });
  mandateId = (await admin`select id from public.catalog_library_mandates where library_id=${libraryId}::uuid and organization_id=${organizationId}::uuid and status='ACTIVE'`)[0]?.id;
  if (!mandateId) throw new Error('Isolated catalog mandate fixture was not created');

  service = await workerA.begin(async (transaction) => {
    await setActor(transaction, actorId);
    const rows = await transaction`
      select public.create_catalog_service(
        ${libraryId}::uuid,${subcategoryId}::uuid,${code},${slug},
        'Service test concurrence','خدمة اختبار التزامن','Test de concurrence','اختبار التزامن',
        'Service de preuve pour sérialisation des commandes','خدمة إثبات لتسلسل الأوامر',
        'ADVISORY','test','اختبار',false,false,false,false,true,false,'MAD',2147483000,
        '{"schema_version":1}'::jsonb,'{"schema_version":1}'::jsonb,false,
        'Preuve de concurrence automatisée',${`p06-create-${runId}`},${randomUUID()}::uuid
      ) as response
    `;
    return rows[0].response;
  });

  const firstReady = deferred();
  const releaseFirst = deferred();
  const firstImpact = workerA.begin(async (transaction) => {
    try {
      await setActor(transaction, actorId);
      const rows = await transaction`
        select public.simulate_catalog_service_impact(${service.service_id}::uuid,5,${impactKey},${randomUUID()}::uuid) response
      `;
      firstReady.resolve(rows[0].response);
      await releaseFirst.promise;
      return rows[0].response;
    } catch (error) { firstReady.reject(error); throw error; }
  });
  const firstResponse = await firstReady.promise;
  const secondImpact = workerB.begin(async (transaction) => {
    await setActor(transaction, actorId);
    const rows = await transaction`
      select public.simulate_catalog_service_impact(${service.service_id}::uuid,5,${impactKey},${randomUUID()}::uuid) response
    `;
    return rows[0].response;
  });
  try { await expectBlocked(secondImpact, 'service command idempotency replay'); }
  finally { releaseFirst.resolve(); }
  const [committedFirst, replayedSecond] = await Promise.all([firstImpact, secondImpact]);
  if (JSON.stringify(firstResponse) !== JSON.stringify(committedFirst)
    || JSON.stringify(firstResponse) !== JSON.stringify(replayedSecond)) {
    throw new Error('Concurrent idempotency replay returned a different response');
  }
  const idempotencyEvidence = await admin`
    select
      (select count(*)::integer from public.catalog_command_keys where actor_user_id=${actorId}::uuid and operation_scope='catalog.service.impact' and key=${impactKey}) commands,
      (select count(*)::integer from public.audit_events where actor_user_id=${actorId}::uuid and action='catalog.service.impact_simulated' and resource_id=${service.service_id}) audits,
      (select count(*)::integer from public.event_outbox where causation_id=${firstResponse.command_id}::uuid) outbox
  `;
  if (idempotencyEvidence[0].commands !== 1 || idempotencyEvidence[0].audits !== 1 || idempotencyEvidence[0].outbox !== 0) {
    throw new Error('Concurrent idempotency replay duplicated effects or emitted a simulation event');
  }
  console.log('PASS service_command_idempotency_concurrency (2 connections)');

  await admin`
    insert into public.catalog_releases(id,library_id,release_key,status,source_bundle_hash,snapshot_hash,created_by,effective_from)
    values(${releaseId}::uuid,${libraryId}::uuid,${releaseKey},'DRAFT',repeat('a',64),repeat('b',64),${actorId}::uuid,statement_timestamp()+interval '1 day')
  `;
  await admin`
    insert into public.catalog_release_items(release_id,library_id,object_type,object_id,version_id,content_hash,sort_order)
    values(${releaseId}::uuid,${libraryId}::uuid,'SERVICE',${service.service_id}::uuid,${service.version_id}::uuid,${service.content_hash},2147483000)
  `;

  const archiveReady = deferred();
  const releaseArchive = deferred();
  const archive = workerA.begin(async (transaction) => {
    try {
      await setActor(transaction, actorId);
      const rows = await transaction`
        select public.archive_catalog_service(
          ${service.service_id}::uuid,${service.version_id}::uuid,1,1,
          'Archivage de preuve concurrente',${archiveKey},${randomUUID()}::uuid
        ) response
      `;
      archiveReady.resolve(rows[0].response);
      await releaseArchive.promise;
      return rows[0].response;
    } catch (error) { archiveReady.reject(error); throw error; }
  });
  await archiveReady.promise;
  const producer = workerB.begin((transaction) => transaction`
    update public.catalog_releases set status='PUBLISHED',published_at=clock_timestamp(),row_version=row_version+1
    where id=${releaseId}::uuid
  `);
  try { await expectBlocked(producer, 'archive versus dependency producer'); }
  finally { releaseArchive.resolve(); }
  await archive;
  let producerRejected = false;
  try { await producer; }
  catch (error) {
    producerRejected = error?.code === '55000' && error?.message === 'CATALOG_SERVICE_DEPENDENCY_REJECTED';
    if (!producerRejected) throw error;
  }
  if (!producerRejected) throw new Error('Dependency producer activated after concurrent archive');
  const raceEvidence = await admin`
    select s.status service_status,r.status release_status,
      (select count(*)::integer from public.event_outbox where event_type='CatalogServiceArchivedV1' and aggregate_id=${service.service_id}) archive_events
    from public.catalog_services s cross join public.catalog_releases r
    where s.id=${service.service_id}::uuid and r.id=${releaseId}::uuid
  `;
  if (raceEvidence[0]?.service_status !== 'ARCHIVED'
    || raceEvidence[0]?.release_status !== 'DRAFT' || raceEvidence[0]?.archive_events !== 1) {
    throw new Error('Archive/dependency race produced an invalid durable state');
  }
  await admin`update public.catalog_releases set status='ARCHIVED',row_version=row_version+1 where id=${releaseId}::uuid and status='DRAFT'`;
  console.log('PASS service_archive_dependency_concurrency (2 connections)');
  console.log('Evidence retained: generated service and release are archived; audit/outbox/command proofs were not deleted');
} catch (error) {
  primaryError = error;
  throw error;
} finally {
  try {
    await retainArchivedEvidence();
  } catch (cleanupError) {
    if (!primaryError) throw cleanupError;
    console.error(`Evidence cleanup transition failed: ${cleanupError?.message || 'unknown error'}`);
  }
  await Promise.allSettled([workerA.end(), workerB.end(), admin.end()]);
}
