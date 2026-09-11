import { createHash, createHmac, randomBytes, randomUUID, timingSafeEqual } from "node:crypto";
import { spawn } from "node:child_process";
import { createRequire } from "node:module";
import { access, lstat, mkdir, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import postgres from "postgres";
import { loadSafeConfiguration, resolveExpectedDatabaseUrl } from "../../../scripts/p05-e2e/environment.mjs";
import { neutralizeFixture, verifyFixtureNeutralized } from "../../../scripts/p05-e2e/privileged-fixture-adapter.mjs";
import { buildChildEnvironment, secureLocalPaths } from "../../../scripts/p05-e2e/security.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");
const requireFromWeb = createRequire(resolve(root, "apps", "web", "package.json"));
const { createClient } = requireFromWeb("@supabase/supabase-js");
const { createServerClient } = requireFromWeb("@supabase/ssr");
const artifactRoot = resolve(root, "artifacts", "test-results", "p06-catalog");
const runId = randomUUID();
const runDirectory = resolve(artifactRoot, runId);
const authDirectory = resolve(runDirectory, "auth");
const playwrightDirectory = resolve(runDirectory, "playwright");
const statePath = resolve(authDirectory, "client.json");
const manifestPath = resolve(runDirectory, "manifest.json");
const heartbeatPath = resolve(runDirectory, "heartbeat.json");
const journalDirectory = resolve(runDirectory, "journal");
const runToken = randomBytes(32).toString("base64url");
const runTokenHash = createHash("sha256").update(runToken).digest("hex");
const processStartedAt = new Date(Date.now() - process.uptime() * 1_000).toISOString();
const maximumRunAgeMs = 30 * 60_000;
const corruptRunTtlMs = 2 * maximumRunAgeMs;
const heartbeatFreshnessMs = 45_000;
const simulatedCrashCheckpoint = process.argv.find((argument) => argument.startsWith("--simulate-crash="))?.split("=")[1];
const runLifetimeMs = simulatedCrashCheckpoint ? 5_000 : maximumRunAgeMs;
let journalSequence = 0;

function assertRunPath(path) {
  const child = relative(artifactRoot, path);
  if (!child || child.startsWith("..") || resolve(artifactRoot, child) !== path) {
    throw new Error("P06 cleanup target escaped its run-specific artifact directory");
  }
}

function signatureFor(manifest, key) {
  return createHmac("sha256", key).update(JSON.stringify(manifest)).digest("hex");
}

async function writeAtomic(path, contents) {
  const temporary = `${path}.${randomUUID()}.tmp`;
  await writeFile(temporary, contents, { mode: 0o600, flag: "wx" });
  await rename(temporary, path);
}

async function appendJournal(operation, phase, identifiers) {
  journalSequence += 1;
  const payload = {
    schemaVersion: 1,
    environment: config.environment,
    projectRef: config.projectRef,
    runId,
    artifactDirectory: runDirectory,
    operation,
    phase,
    identifiers,
    recordedAt: new Date().toISOString(),
    expiresAt: new Date(runCreatedAt.getTime() + runLifetimeMs).toISOString(),
  };
  const path = resolve(journalDirectory, `${String(journalSequence).padStart(4, "0")}.json`);
  await writeAtomic(path, `${JSON.stringify({ ...payload, signature: signatureFor(payload, config.serviceRoleKey) })}\n`);
}

function crashIfRequested(checkpoint) {
  if (simulatedCrashCheckpoint === checkpoint) process.kill(process.pid, "SIGTERM");
}

function signaturesMatch(actual, expected) {
  if (!/^[0-9a-f]{64}$/u.test(actual ?? "") || !/^[0-9a-f]{64}$/u.test(expected)) return false;
  return timingSafeEqual(Buffer.from(actual, "hex"), Buffer.from(expected, "hex"));
}

function processIsActive(pid) {
  if (!Number.isSafeInteger(pid) || pid < 1) return false;
  try { process.kill(pid, 0); return true; }
  catch (error) { return error?.code === "EPERM"; }
}

async function readSignedDocument(path, key) {
  try {
    const document = JSON.parse(await readFile(path, "utf8"));
    const signature = document.signature;
    const payload = Object.fromEntries(Object.entries(document)
      .filter(([key]) => key !== "signature" && key !== "childSignature"));
    return signaturesMatch(signature, signatureFor(payload, key)) ? payload : null;
  } catch { return null; }
}

function belongsToEnvironment(payload, config, directory, runName) {
  return payload?.schemaVersion === 2 && payload.environment === config.environment
    && payload.projectRef === config.projectRef && payload.runId === runName
    && payload.artifactDirectory === directory;
}

async function hasFreshOwnerHeartbeat(directory, config, runName, manifest) {
  const heartbeat = await readSignedDocument(resolve(directory, "heartbeat.json"), config.serviceRoleKey);
  if (!belongsToEnvironment(heartbeat, config, directory, runName)) return false;
  const observedAt = Date.parse(heartbeat.observedAt);
  const startedAt = Date.parse(heartbeat.processStartedAt);
  const now = Date.now();
  return Number.isFinite(observedAt) && Number.isFinite(startedAt)
    && observedAt >= startedAt && observedAt <= now + 5_000 && now - observedAt <= heartbeatFreshnessMs
    && heartbeat.pid === manifest?.pid && heartbeat.processStartedAt === manifest?.processStartedAt
    && heartbeat.runTokenHash === manifest?.runTokenHash
    && heartbeat.runTokenHash === createHash("sha256").update(heartbeat.runToken ?? "").digest("hex")
    && processIsActive(heartbeat.pid);
}

async function recoverResourcesFromJournal(directory, config, runName) {
  const expectedEmail = `p06-e2e-${runName}@example.invalid`;
  const expectedOrganization = `Matricia P06 Catalogue ${runName}`;
  const expectedReleaseKey = `P06.E2E.${runName.replaceAll("-", "").slice(0, 8).toUpperCase()}`;
  const uuid = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/u;
  let entries;
  try { entries = await readdir(resolve(directory, "journal"), { withFileTypes: true }); }
  catch { return null; }
  const resources = {};
  let expiresAt;
  let validEntries = 0;
  for (const entry of entries.sort((left, right) => left.name.localeCompare(right.name))) {
    if (!entry.isFile() || !/^\d{4}\.json$/u.test(entry.name)) continue;
    const payload = await readSignedDocument(resolve(directory, "journal", entry.name), config.serviceRoleKey);
    const recorded = Date.parse(payload?.recordedAt);
    const expiry = Date.parse(payload?.expiresAt);
    if (payload?.schemaVersion !== 1 || payload.environment !== config.environment || payload.projectRef !== config.projectRef
        || payload.runId !== runName || payload.artifactDirectory !== directory || !Number.isFinite(recorded)
        || !Number.isFinite(expiry) || expiry <= recorded || expiry - recorded > maximumRunAgeMs) continue;
    validEntries += 1;
    expiresAt = expiresAt === undefined ? expiry : Math.min(expiresAt, expiry);
    const identifiers = payload.identifiers ?? {};
    if (identifiers.email === expectedEmail) resources.userEmail = identifiers.email;
    if (uuid.test(identifiers.userId ?? "")) resources.userId = identifiers.userId;
    if (identifiers.organizationLegalName === expectedOrganization) resources.organizationLegalName = identifiers.organizationLegalName;
    if (uuid.test(identifiers.organizationId ?? "")) resources.organizationId = identifiers.organizationId;
    if (uuid.test(identifiers.libraryId ?? "") && identifiers.releaseKey === expectedReleaseKey) {
      resources.catalog = { ...(resources.catalog ?? {}), library: identifiers.libraryId, releaseKey: identifiers.releaseKey };
    }
    if (uuid.test(identifiers.releaseId ?? "") && identifiers.releaseKey === expectedReleaseKey && resources.catalog) {
      resources.catalog.release = identifiers.releaseId;
    }
  }
  return validEntries > 0 && Number.isFinite(expiresAt) ? { fixtureResources: resources, expiresAt } : null;
}

async function neutralizeCatalogFixture(database, fixture, actorId = null) {
  if (!fixture?.library) return;
  await database.begin(async (transaction) => {
    await transaction`select pg_advisory_xact_lock(hashtextextended('catalog-library-cleanup:'||${fixture.library}::text,0))`;
    const library = await transaction`select steward_organization_id from public.catalog_libraries
      where id=${fixture.library}::uuid for update`;
    if (library.length === 0) return;
    await transaction`select id,status from public.catalog_releases where library_id=${fixture.library}::uuid for update`;
    await transaction`update public.catalog_releases set status='RETIRED',lease_token=null,leased_until=null,next_attempt_at=null,retired_at=clock_timestamp(),row_version=row_version+1
      where library_id=${fixture.library}::uuid and status='PUBLISHED'`;
    await transaction`update public.catalog_releases set status='ARCHIVED',lease_token=null,leased_until=null,next_attempt_at=null,published_at=null,retired_at=null,row_version=row_version+1
      where library_id=${fixture.library}::uuid and status in ('DRAFT','IN_REVIEW','APPROVED','SCHEDULED','PUBLISHING','FAILED','DEAD_LETTER')`;
    await transaction`update public.catalog_libraries set status='ARCHIVED',archived_at=coalesce(archived_at,clock_timestamp()),current_release_id=null,row_version=row_version+1,updated_at=clock_timestamp()
      where id=${fixture.library}::uuid and status<>'ARCHIVED'`;
    await transaction`update public.catalog_categories set status='ARCHIVED',archived_at=coalesce(archived_at,clock_timestamp()),row_version=row_version+1
      where library_id=${fixture.library}::uuid and status<>'ARCHIVED'`;
    await transaction`update public.catalog_subcategories set status='ARCHIVED',archived_at=coalesce(archived_at,clock_timestamp()),row_version=row_version+1
      where library_id=${fixture.library}::uuid and status<>'ARCHIVED'`;
    await transaction`update public.catalog_services set status='ARCHIVED',archived_at=coalesce(archived_at,clock_timestamp()),row_version=row_version+1
      where library_id=${fixture.library}::uuid and status<>'ARCHIVED'`;
    await transaction`update public.catalog_service_subcategory_links set status='ARCHIVED',row_version=row_version+1
      where library_id=${fixture.library}::uuid and status<>'ARCHIVED'`;
    await transaction`insert into private.catalog_acl_write_capabilities(backend_pid,transaction_id)
      values(pg_backend_pid(),txid_current()) on conflict do nothing`;
    await transaction`update public.catalog_library_mandates set status='REVOKED',valid_until=coalesce(valid_until,clock_timestamp()),row_version=row_version+1
      where library_id=${fixture.library}::uuid and status='ACTIVE'`;
    await transaction`delete from private.catalog_acl_write_capabilities
      where backend_pid=pg_backend_pid() and transaction_id=txid_current()`;
    const correlationId = randomUUID();
    await transaction`insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
      values(${library[0].steward_organization_id}::uuid,${actorId}::uuid,${actorId ? "USER" : "SYSTEM"},'catalog.fixture.e2e_neutralized','catalog_library',${fixture.library},${correlationId}::uuid,jsonb_build_object('release_id',${fixture.release ?? null}::uuid,'fixture','P06_E2E'),null,repeat('0',64))`;
    await transaction`insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)
      values(${library[0].steward_organization_id}::uuid,'catalog_library',${fixture.library},'CatalogE2EFixtureNeutralizedV1',${correlationId}::uuid,jsonb_build_object('release_id',${fixture.release ?? null}::uuid,'library_id',${fixture.library}::uuid))`;
  });
  const active = await database`select
    (select count(*) from public.catalog_libraries where id=${fixture.library}::uuid and status<>'ARCHIVED')
    +(select count(*) from public.catalog_releases where library_id=${fixture.library}::uuid
      and status in ('DRAFT','IN_REVIEW','APPROVED','SCHEDULED','PUBLISHING','FAILED','DEAD_LETTER','PUBLISHED')) as count`;
  if (Number(active[0]?.count) !== 0) throw new Error("P06 catalogue fixture remained active after neutralization");
}

async function neutralizeExpiredRemoteFixture(database, admin, manifest) {
  const fixture = manifest.fixtureResources ?? {};
  let resolvedUserId = fixture.userId;
  if (!resolvedUserId && fixture.userEmail) {
    const users = await database`select id from auth.users where email=${fixture.userEmail}
      and raw_app_meta_data->>'p06_e2e_fixture'='true' limit 1`;
    resolvedUserId = users[0]?.id;
  }
  let resolvedOrganizationId = fixture.organizationId;
  if (!resolvedOrganizationId && fixture.organizationLegalName && resolvedUserId) {
    const organizations = await database`select id from public.organizations
      where legal_name=${fixture.organizationLegalName} and created_by=${resolvedUserId}::uuid limit 1`;
    resolvedOrganizationId = organizations[0]?.id;
  }
  let catalog = fixture.catalog;
  if (catalog?.library && catalog.releaseKey) {
    const releases = await database`select id from public.catalog_releases
      where library_id=${catalog.library}::uuid and release_key=${catalog.releaseKey} limit 1`;
    if (releases[0]?.id) catalog = { ...catalog, release: releases[0].id };
  }
  if (catalog) await neutralizeCatalogFixture(database, catalog, resolvedUserId ?? null);
  if (resolvedOrganizationId || resolvedUserId) {
    const target = {
      organizationIds: resolvedOrganizationId ? [resolvedOrganizationId] : [],
      userIds: resolvedUserId ? [resolvedUserId] : [],
      storagePaths: [],
    };
    await neutralizeFixture(database, target);
    await verifyFixtureNeutralized(database, target);
  }
  if (resolvedUserId) {
    const disabled = await admin.auth.admin.updateUserById(resolvedUserId, {
      ban_duration: "876000h",
      app_metadata: { p06_e2e_fixture: true, p06_e2e_neutralized: true },
    });
    if (disabled.error && disabled.error.status !== 404) throw disabled.error;
  }
}

async function removeExpiredRuns(config, database, admin) {
  await mkdir(artifactRoot, { recursive: true });
  await secureLocalPaths(artifactRoot, []);
  const entries = await readdir(artifactRoot, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isDirectory() || entry.isSymbolicLink() || !/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/u.test(entry.name)) continue;
    const directory = resolve(artifactRoot, entry.name);
    assertRunPath(directory);
    const metadata = await lstat(directory);
    const payload = await readSignedDocument(resolve(directory, "manifest.json"), config.serviceRoleKey);
    if (payload && await hasFreshOwnerHeartbeat(directory, config, entry.name, payload)) continue;
    if (!belongsToEnvironment(payload, config, directory, entry.name)) {
      const recovered = await recoverResourcesFromJournal(directory, config, entry.name);
      if (recovered && recovered.expiresAt < Date.now()) {
        await neutralizeExpiredRemoteFixture(database, admin, recovered);
        await rm(directory, { recursive: true, force: true });
      } else if (!recovered && Date.now() - metadata.mtimeMs > corruptRunTtlMs) {
        // Without a valid manifest or signed journal, no remote mutation is authorized.
        await rm(directory, { recursive: true, force: true });
      }
      continue;
    }
    const createdAt = Date.parse(payload.createdAt);
    const expiresAt = Date.parse(payload.expiresAt);
    const validTimes = Number.isFinite(createdAt) && Number.isFinite(expiresAt)
      && expiresAt > createdAt && expiresAt - createdAt <= maximumRunAgeMs;
    if (!validTimes) {
      if (Date.now() - metadata.mtimeMs > corruptRunTtlMs) {
        await neutralizeExpiredRemoteFixture(database, admin, payload);
        await rm(directory, { recursive: true, force: true });
      }
      continue;
    }
    if (expiresAt >= Date.now()) continue;
    await neutralizeExpiredRemoteFixture(database, admin, payload);
    await rm(directory, { recursive: true, force: true });
  }
}

function cookieClient(config) {
  const cookies = new Map();
  const client = createServerClient(config.supabaseUrl, config.publishableKey, {
    cookies: { getAll: () => [...cookies.values()], setAll: (changes) => {
      for (const change of changes) {
        if (change.value === "" || change.options?.maxAge === 0) cookies.delete(change.name);
        else cookies.set(change.name, change);
      }
    } },
    auth: { autoRefreshToken: false, detectSessionInUrl: false, persistSession: true },
  });
  return { client, cookies };
}

function playwrightState(cookies, baseUrl) {
  const origin = new URL(baseUrl);
  return { cookies: [...cookies.values()].map(({ name, value, options = {} }) => ({
    name,
    value,
    domain: origin.hostname,
    path: options.path || "/",
    expires: typeof options.maxAge === "number" ? Math.floor(Date.now() / 1000) + options.maxAge : -1,
    httpOnly: options.httpOnly ?? false,
    secure: false,
    sameSite: options.sameSite === "strict" ? "Strict" : options.sameSite === "none" ? "None" : "Lax",
  })), origins: [] };
}

async function verifyCatalogEvidence(database, organizationId, releaseId, evidence) {
  for (const item of evidence) {
    const rows = await database`select
      (select count(*)::int from public.audit_events where organization_id=${organizationId}::uuid
        and correlation_id=${item.correlationId}::uuid and action=${item.action}
        and resource_id=${releaseId}::text and event_hash<>repeat('0',64)) audits,
      (select count(*)::int from public.event_outbox where organization_id=${organizationId}::uuid
        and correlation_id=${item.correlationId}::uuid and event_type=${item.eventType}
        and aggregate_id=${releaseId}::text) outbox_events`;
    if (rows[0]?.audits !== item.count || rows[0]?.outbox_events !== item.count) {
      throw new Error(`P06 catalogue evidence verification failed (${item.action})`);
    }
  }
  const claimed = await database`select
    (select count(*)::int from public.audit_events where organization_id=${organizationId}::uuid and resource_id=${releaseId}::text and action='catalog.release.claimed' and event_hash<>repeat('0',64)) audits,
    (select count(*)::int from public.event_outbox where organization_id=${organizationId}::uuid and aggregate_id=${releaseId}::text and event_type='CatalogReleaseClaimedV1') outbox_events`;
  if (claimed[0]?.audits !== 1 || claimed[0]?.outbox_events !== 1) throw new Error("P06 catalogue claim evidence verification failed");
}

async function createCatalogFixture(database, userClient, serviceClient, actorId, stewardId, onProgress) {
  const ids = Object.fromEntries([
    "library", "libraryVersion", "category", "categoryVersion", "subcategory", "subcategoryVersion",
    "serviceA", "serviceAVersion", "serviceB", "serviceBVersion", "linkA", "linkAVersion",
    "linkB", "linkBVersion", "adminLibraryVersion", "adminCategoryVersion", "adminSubcategoryVersion",
    "adminServiceAVersion", "adminServiceBVersion", "adminLinkAVersion", "adminLinkBVersion", "release",
  ].map((key) => [key, randomUUID()]));
  const suffix = runId.replaceAll("-", "").slice(0, 8).toUpperCase();
  const fixture = {
    ...ids,
    libraryCode: `A_P06_${suffix}`,
    librarySlug: `p06-${suffix.toLowerCase()}`,
    libraryNameFr: `Catalogue E2E ${suffix}`,
    libraryNameAr: `دليل اختبار ${suffix}`,
    firstCode: `P06_${suffix}_ALPHA`,
    secondCode: `P06_${suffix}_BETA`,
    releaseKey: `P06.E2E.${suffix}`,
  };
  const hash = (label) => createHash("sha256").update(`${runId}:${label}`).digest("hex");
  fixture.serviceAHash = hash("service-1");
  fixture.adminSourceHash = hash("admin-release-source");
  fixture.adminReleaseKey = `P06.ADMIN.${suffix}`;
  fixture.adminItems = [
    { objectType: "LIBRARY", objectId: fixture.library, versionId: fixture.adminLibraryVersion, contentHash: hash("admin-library") },
    { objectType: "CATEGORY", objectId: fixture.category, versionId: fixture.adminCategoryVersion, contentHash: hash("admin-category") },
    { objectType: "SUBCATEGORY", objectId: fixture.subcategory, versionId: fixture.adminSubcategoryVersion, contentHash: hash("admin-subcategory") },
    { objectType: "SERVICE", objectId: fixture.serviceA, versionId: fixture.adminServiceAVersion, contentHash: hash("admin-service-1") },
    { objectType: "SERVICE_SUBCATEGORY_LINK", objectId: fixture.linkA, versionId: fixture.adminLinkAVersion, contentHash: hash("admin-link-1") },
    { objectType: "SERVICE", objectId: fixture.serviceB, versionId: fixture.adminServiceBVersion, contentHash: hash("admin-service-2") },
    { objectType: "SERVICE_SUBCATEGORY_LINK", objectId: fixture.linkB, versionId: fixture.adminLinkBVersion, contentHash: hash("admin-link-2") },
  ];
  const items = [
    ["LIBRARY", fixture.library, fixture.libraryVersion, hash("library")],
    ["CATEGORY", fixture.category, fixture.categoryVersion, hash("category")],
    ["SUBCATEGORY", fixture.subcategory, fixture.subcategoryVersion, hash("subcategory")],
    ["SERVICE", fixture.serviceA, fixture.serviceAVersion, fixture.serviceAHash],
    ["SERVICE_SUBCATEGORY_LINK", fixture.linkA, fixture.linkAVersion, hash("link-1")],
    ["SERVICE", fixture.serviceB, fixture.serviceBVersion, hash("service-2")],
    ["SERVICE_SUBCATEGORY_LINK", fixture.linkB, fixture.linkBVersion, hash("link-2")],
  ];
  const evidence = [];
  await appendJournal("catalog.fixture.prepare", "INTENT", { libraryId: fixture.library, releaseKey: fixture.releaseKey });
  await onProgress(fixture, "CATALOG_PREPARE_INTENT");
  await database.begin(async (transaction) => {
    await transaction`update public.organizations set status='ACTIVE',updated_at=clock_timestamp(),row_version=row_version+1
      where id=${stewardId}::uuid and status='PENDING'`;
    await transaction`insert into public.catalog_libraries(id,code,slug,steward_organization_id,created_by)
      values(${fixture.library}::uuid,${fixture.libraryCode},${fixture.librarySlug},${stewardId}::uuid,${actorId}::uuid)`;
    await transaction`insert into public.catalog_library_versions(id,library_id,version,status,code,slug,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by)
      values(${fixture.libraryVersion}::uuid,${fixture.library}::uuid,1,'APPROVED',${fixture.libraryCode},${fixture.librarySlug},${fixture.libraryNameFr},${fixture.libraryNameAr},'Catalogue isolé pour le parcours E2E','دليل معزول لاختبار المسار','library',1,'Fixture E2E isolée',${hash("library")},'APPROVED',${actorId}::uuid,clock_timestamp(),${hash("library-ar-review")},1,${actorId}::uuid)`;
    await transaction`insert into public.catalog_categories(id,library_id,code,slug,status,created_by)
      values(${fixture.category}::uuid,${fixture.library}::uuid,'P06_CATEGORY','p06-category','DRAFT',${actorId}::uuid)`;
    await transaction`insert into public.catalog_category_versions(id,category_id,library_id,version,status,code,slug,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by)
      values(${fixture.categoryVersion}::uuid,${fixture.category}::uuid,${fixture.library}::uuid,1,'APPROVED','P06_CATEGORY','p06-category','Catégorie E2E','فئة الاختبار','Catégorie isolée','فئة معزولة',1,'Fixture E2E isolée',${hash("category")},'APPROVED',${actorId}::uuid,clock_timestamp(),${hash("category-ar-review")},1,${actorId}::uuid)`;
    await transaction`insert into public.catalog_subcategories(id,library_id,category_id,code,slug,status,created_by)
      values(${fixture.subcategory}::uuid,${fixture.library}::uuid,${fixture.category}::uuid,'P06_SUBCATEGORY','p06-subcategory','DRAFT',${actorId}::uuid)`;
    await transaction`insert into public.catalog_subcategory_versions(id,subcategory_id,library_id,version,status,category_id,code,slug,name_fr,name_ar,description_fr,description_ar,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by)
      values(${fixture.subcategoryVersion}::uuid,${fixture.subcategory}::uuid,${fixture.library}::uuid,1,'APPROVED',${fixture.category}::uuid,'P06_SUBCATEGORY','p06-subcategory','Sous-catégorie E2E','فئة فرعية للاختبار','Sous-catégorie isolée','فئة فرعية معزولة',1,'Fixture E2E isolée',${hash("subcategory")},'APPROVED',${actorId}::uuid,clock_timestamp(),${hash("subcategory-ar-review")},1,${actorId}::uuid)`;
    for (const [index, serviceId, versionId, code, slug, nameFr, nameAr] of [
      [1, fixture.serviceA, fixture.serviceAVersion, fixture.firstCode, "p06-alpha", "Audit Alpha E2E", "تدقيق ألفا"],
      [2, fixture.serviceB, fixture.serviceBVersion, fixture.secondCode, "p06-beta", "Conseil Bêta E2E", "استشارة بيتا"],
    ]) {
      await transaction`insert into public.catalog_services(id,library_id,primary_subcategory_id,code,slug,status,created_by)
        values(${serviceId}::uuid,${fixture.library}::uuid,${fixture.subcategory}::uuid,${code},${slug},'DRAFT',${actorId}::uuid)`;
      await transaction`insert into public.catalog_service_versions(id,service_id,library_id,version,status,primary_subcategory_id,code,slug,name_fr,name_ar,short_description_fr,short_description_ar,long_description_fr,long_description_ar,service_type,unit_label_fr,unit_label_ar,sort_order,change_reason,content_hash,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by)
        values(${versionId}::uuid,${serviceId}::uuid,${fixture.library}::uuid,1,'APPROVED',${fixture.subcategory}::uuid,${code},${slug},${nameFr},${nameAr},'Description courte E2E','وصف موجز للاختبار','Description longue du service E2E','وصف طويل لخدمة الاختبار','CONSULTING','mission','مهمة',${index},'Fixture E2E isolée',${hash(`service-${index}`)},'APPROVED',${actorId}::uuid,clock_timestamp(),${hash(`service-${index}-ar-review`)},1,${actorId}::uuid)`;
    }
    for (const [index, linkId, versionId, serviceId] of [
      [1, fixture.linkA, fixture.linkAVersion, fixture.serviceA],
      [2, fixture.linkB, fixture.linkBVersion, fixture.serviceB],
    ]) {
      await transaction`insert into public.catalog_service_subcategory_links(id,service_id,subcategory_id,library_id,link_type,status,created_by)
        values(${linkId}::uuid,${serviceId}::uuid,${fixture.subcategory}::uuid,${fixture.library}::uuid,'PRIMARY','DRAFT',${actorId}::uuid)`;
      await transaction`insert into public.catalog_service_subcategory_link_versions(id,link_id,library_id,version,status,service_id,subcategory_id,link_type,change_reason,content_hash,created_by)
        values(${versionId}::uuid,${linkId}::uuid,${fixture.library}::uuid,1,'APPROVED',${serviceId}::uuid,${fixture.subcategory}::uuid,'PRIMARY','Fixture E2E isolée',${hash(`link-${index}`)},${actorId}::uuid)`;
    }
    await transaction`insert into public.catalog_library_mandates(library_id,organization_id,status,valid_from,policy_version,created_by)
      values(${fixture.library}::uuid,${stewardId}::uuid,'ACTIVE',clock_timestamp()-interval '1 minute',1,${actorId}::uuid)`;
    await transaction`insert into public.organization_member_roles(membership_id,role_code,library_id,granted_by)
      select id,'FRANCHISE_OWNER',${fixture.library}::uuid,${actorId}::uuid from public.organization_memberships
      where organization_id=${stewardId}::uuid and user_id=${actorId}::uuid and status='ACTIVE'`;
  });
  crashIfRequested("CATALOG_IDENTITIES_MUTATED");
  await appendJournal("catalog.fixture.prepare", "RESULT", { libraryId: fixture.library, releaseKey: fixture.releaseKey });
  await onProgress(fixture, "CATALOG_DRAFT_PREPARED");
  await appendJournal("catalog.release.create", "INTENT", { libraryId: fixture.library, releaseKey: fixture.releaseKey });
  const createCorrelationId = randomUUID();
  const created = await userClient.rpc("create_catalog_release", {
    p_library_id: fixture.library,
    p_release_key: fixture.releaseKey,
    p_source_bundle_hash: hash("source"),
    p_requires_central_approval: false,
    p_expected_library_row_version: 1,
    p_idempotency_key: randomUUID(),
    p_correlation_id: createCorrelationId,
  });
  crashIfRequested("RELEASE_MUTATED");
  if (created.error || created.data?.outcome !== "CATALOG_RELEASE_CREATED") {
    throw new Error(`P06 fixture DRAFT release creation failed (${created.error?.code ?? "INVALID_OUTCOME"})`);
  }
  fixture.release = created.data.release_id;
  evidence.push({ correlationId: createCorrelationId, action: "catalog.release.created", eventType: "CatalogReleaseCreatedV1", count: 1 });
  await appendJournal("catalog.release.create", "RESULT", { libraryId: fixture.library, releaseId: fixture.release, releaseKey: fixture.releaseKey });
  await onProgress(fixture, "CATALOG_RELEASE_CREATED");
  let releaseRowVersion = 1;
  for (let index = 0; index < items.length; index += 1) {
    const [objectType, objectId, versionId, contentHash] = items[index];
    const correlationId = randomUUID();
    const added = await userClient.rpc("add_catalog_release_item", {
      p_release_id: fixture.release,
      p_object_type: objectType,
      p_object_id: objectId,
      p_version_id: versionId,
      p_content_hash: contentHash,
      p_sort_order: index + 1,
      p_expected_release_row_version: releaseRowVersion,
      p_idempotency_key: randomUUID(),
      p_correlation_id: correlationId,
    });
    if (added.error || added.data?.outcome !== "CATALOG_RELEASE_ITEM_ADDED") throw new Error("P06 fixture release item command failed");
    releaseRowVersion = added.data.release_row_version;
    evidence.push({ correlationId, action: "catalog.release.item.added", eventType: "CatalogReleaseItemAddedV1", count: 1 });
  }
  const submitCorrelationId = randomUUID();
  const submitted = await userClient.rpc("submit_catalog_release", {
    p_release_id: fixture.release,
    p_expected_row_version: releaseRowVersion,
    p_idempotency_key: randomUUID(),
    p_correlation_id: submitCorrelationId,
  });
  if (submitted.error || submitted.data?.outcome !== "CATALOG_RELEASE_SUBMITTED" || submitted.data.status !== "APPROVED") {
    throw new Error("P06 fixture release submission failed");
  }
  evidence.push({ correlationId: submitCorrelationId, action: "catalog.release.submitted", eventType: "CatalogChangeSubmittedV1", count: 1 });
  releaseRowVersion += 1;
  const scheduleCorrelationId = randomUUID();
  const scheduled = await userClient.rpc("schedule_catalog_release", {
    p_release_id: fixture.release,
    p_effective_from: new Date(Date.now() - 60_000).toISOString(),
    p_effective_until: null,
    p_audience: { kind: "PUBLIC" },
    p_expected_row_version: releaseRowVersion,
    p_idempotency_key: randomUUID(),
    p_correlation_id: scheduleCorrelationId,
  });
  if (scheduled.error || scheduled.data?.outcome !== "CATALOG_RELEASE_SCHEDULED") throw new Error("P06 fixture release scheduling failed");
  crashIfRequested("SCHEDULED_MUTATED");
  evidence.push({ correlationId: scheduleCorrelationId, action: "catalog.release.scheduled", eventType: "CatalogReleaseScheduledV1", count: 1 });
  const workerId = randomUUID();
  const claimed = await serviceClient.rpc("claim_catalog_release", {
    p_worker_id: workerId, p_release_id: fixture.release, p_lease_seconds: 300,
  });
  if (claimed.error || claimed.data?.outcome !== "CATALOG_RELEASE_CLAIMED") throw new Error("P06 fixture release claim failed");
  crashIfRequested("CLAIMED_MUTATED");
  const publishCorrelationId = randomUUID();
  const completed = await serviceClient.rpc("complete_catalog_release_publish", {
    p_release_id: fixture.release,
    p_lease_token: claimed.data.lease_token,
    p_expected_row_version: claimed.data.release_row_version,
    p_correlation_id: publishCorrelationId,
  });
  if (completed.error || completed.data?.outcome !== "CATALOG_RELEASE_PUBLISHED") throw new Error("P06 fixture release activation failed");
  crashIfRequested("CATALOG_MUTATED");
  evidence.push({ correlationId: publishCorrelationId, action: "catalog.release.published", eventType: "CatalogReleasePublishedV1", count: 1 });
  await verifyCatalogEvidence(database, stewardId, fixture.release, evidence);
  await database.begin(async (transaction) => {
    await transaction`insert into public.catalog_library_versions(id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,change_reason,content_hash,sensitive,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,code,slug)
      select ${fixture.adminLibraryVersion}::uuid,library_id,2,'APPROVED',name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,'Version E2E administration',${hash("admin-library")},sensitive,'APPROVED',${actorId}::uuid,clock_timestamp(),${hash("admin-library-ar")},1,${actorId}::uuid,code,slug
      from public.catalog_library_versions where id=${fixture.libraryVersion}::uuid`;
    await transaction`insert into public.catalog_category_versions(id,category_id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,visibility_rules,change_reason,content_hash,sensitive,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,code,slug)
      select ${fixture.adminCategoryVersion}::uuid,category_id,library_id,2,'APPROVED',name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,visibility_rules,'Version E2E administration',${hash("admin-category")},sensitive,'APPROVED',${actorId}::uuid,clock_timestamp(),${hash("admin-category-ar")},1,${actorId}::uuid,code,slug
      from public.catalog_category_versions where id=${fixture.categoryVersion}::uuid`;
    await transaction`insert into public.catalog_subcategory_versions(id,subcategory_id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,visibility_rules,change_reason,content_hash,sensitive,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,category_id,code,slug)
      select ${fixture.adminSubcategoryVersion}::uuid,subcategory_id,library_id,2,'APPROVED',name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,visibility_rules,'Version E2E administration',${hash("admin-subcategory")},sensitive,'APPROVED',${actorId}::uuid,clock_timestamp(),${hash("admin-subcategory-ar")},1,${actorId}::uuid,category_id,code,slug
      from public.catalog_subcategory_versions where id=${fixture.subcategoryVersion}::uuid`;
    for (const [sourceVersionId, targetVersionId, contentHash, reviewHash] of [
      [fixture.serviceAVersion, fixture.adminServiceAVersion, hash("admin-service-1"), hash("admin-service-1-ar")],
      [fixture.serviceBVersion, fixture.adminServiceBVersion, hash("admin-service-2"), hash("admin-service-2-ar")],
    ]) {
      await transaction`insert into public.catalog_service_versions(id,service_id,library_id,version,status,name_fr,name_ar,short_description_fr,short_description_ar,long_description_fr,long_description_ar,service_type,unit_label_fr,unit_label_ar,credit_eligible,volume_eligible,recurring_eligible,trial_eligible,rfq_required,fixed_fulfillment_allowed,base_currency,sort_order,fulfillment_config,visibility_rules,change_reason,content_hash,sensitive,translation_review_status,translation_reviewer_user_id,translation_reviewed_at,translation_review_proof_hash,translation_review_version,created_by,primary_subcategory_id,code,slug)
        select ${targetVersionId}::uuid,service_id,library_id,2,'APPROVED',name_fr,name_ar,short_description_fr,short_description_ar,long_description_fr,long_description_ar,service_type,unit_label_fr,unit_label_ar,credit_eligible,volume_eligible,recurring_eligible,trial_eligible,rfq_required,fixed_fulfillment_allowed,base_currency,sort_order,fulfillment_config,visibility_rules,'Version E2E administration',${contentHash},sensitive,'APPROVED',${actorId}::uuid,clock_timestamp(),${reviewHash},1,${actorId}::uuid,primary_subcategory_id,code,slug
        from public.catalog_service_versions where id=${sourceVersionId}::uuid`;
    }
    for (const [sourceVersionId, targetVersionId, contentHash] of [
      [fixture.linkAVersion, fixture.adminLinkAVersion, hash("admin-link-1")],
      [fixture.linkBVersion, fixture.adminLinkBVersion, hash("admin-link-2")],
    ]) {
      await transaction`insert into public.catalog_service_subcategory_link_versions(id,link_id,library_id,version,status,change_reason,content_hash,created_by)
        select ${targetVersionId}::uuid,link_id,library_id,2,'APPROVED','Version E2E administration',${contentHash},${actorId}::uuid
        from public.catalog_service_subcategory_link_versions where id=${sourceVersionId}::uuid`;
    }
  });
  await onProgress(fixture, "CATALOG_PUBLISHED");
  return fixture;
}

async function removeCatalogFixture(database, fixture) {
  await neutralizeCatalogFixture(database, fixture);
}

async function runPlaywright(environment) {
  const child = spawn(process.execPath, [
    resolve(root, "node_modules", "@playwright", "test", "cli.js"),
    "test",
    "tests/e2e/p06-catalog.spec.ts",
    "tests/e2e/p06-catalog-admin.spec.ts",
    "--reporter=line",
    "--output",
    playwrightDirectory,
  ], { cwd: root, env: environment, stdio: ["ignore", "inherit", "inherit"], shell: false });
  return await new Promise((resolveExit, reject) => {
    child.once("error", reject);
    child.once("exit", (code, signal) => signal
      ? reject(new Error("P06 Playwright was interrupted"))
      : resolveExit(code ?? 1));
  });
}

let admin;
let database;
let userId;
let organizationId;
let catalogFixture;
let runCreatedAt;
let failure;
let config;
let heartbeatTimer;
let heartbeatFailure;
let persistedResources = {};
let remoteCleanupSucceeded = true;

async function writeRunManifest(phase, extra = {}) {
  const payload = {
    schemaVersion: 2,
    environment: config.environment,
    projectRef: config.projectRef,
    runId,
    pid: process.pid,
    processStartedAt,
    runTokenHash,
    artifactDirectory: runDirectory,
    createdAt: runCreatedAt.toISOString(),
    expiresAt: new Date(runCreatedAt.getTime() + runLifetimeMs).toISOString(),
    phase,
    fixtureResources: persistedResources,
    ...extra,
  };
  await writeAtomic(manifestPath, `${JSON.stringify({ ...payload, signature: signatureFor(payload, config.serviceRoleKey) }, null, 2)}\n`);
  await secureLocalPaths(runDirectory, [manifestPath]);
}

async function writeHeartbeat() {
  const payload = {
    schemaVersion: 2,
    environment: config.environment,
    projectRef: config.projectRef,
    runId,
    pid: process.pid,
    processStartedAt,
    runToken,
    runTokenHash,
    artifactDirectory: runDirectory,
    observedAt: new Date().toISOString(),
  };
  await writeAtomic(heartbeatPath, `${JSON.stringify({ ...payload, signature: signatureFor(payload, config.serviceRoleKey) })}\n`);
}
try {
  config = await loadSafeConfiguration(root);
  admin = createClient(config.supabaseUrl, config.serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } });
  database = postgres(resolveExpectedDatabaseUrl(config), { max: 1, prepare: false, connect_timeout: 15 });
  await removeExpiredRuns(config, database, admin);
  if (process.argv.includes("--reap-only")) {
    await database.end();
    database = undefined;
    console.log("PASS P06 expired-run reaper");
    process.exit(0);
  }
  assertRunPath(runDirectory);
  await mkdir(runDirectory, { recursive: false });
  await secureLocalPaths(runDirectory, []);
  await mkdir(journalDirectory, { recursive: false });
  await secureLocalPaths(journalDirectory, []);
  runCreatedAt = new Date();
  await writeRunManifest("BOOTSTRAP");
  await writeHeartbeat();
  heartbeatTimer = setInterval(() => {
    void writeHeartbeat().catch((error) => { heartbeatFailure ??= error; });
  }, 10_000);
  heartbeatTimer.unref();
  await mkdir(authDirectory, { recursive: false });
  await secureLocalPaths(authDirectory, []);
  await mkdir(playwrightDirectory, { recursive: false });
  await secureLocalPaths(playwrightDirectory, []);

  const email = `p06-e2e-${runId}@example.invalid`;
  const password = `${randomBytes(24).toString("base64url")}aA7!`;
  persistedResources = { userEmail: email };
  await appendJournal("auth.user.create", "INTENT", { email });
  await writeRunManifest("IDENTITY_CREATE_INTENT");
  const created = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    app_metadata: { p06_e2e_fixture: true },
    user_metadata: { full_name: "P06 Catalogue E2E", preferred_locale: "fr-MA" },
  });
  crashIfRequested("USER_MUTATED");
  if (created.error || !created.data.user) throw new Error("Unable to create the isolated P06 identity");
  userId = created.data.user.id;
  await appendJournal("auth.user.create", "RESULT", { email, userId });
  persistedResources = { userId, userEmail: email };
  await writeRunManifest("IDENTITY_CREATED");

  const authenticated = cookieClient(config);
  const signedIn = await authenticated.client.auth.signInWithPassword({ email, password });
  if (signedIn.error || !signedIn.data.session) throw new Error("Unable to authenticate the isolated P06 identity");
  const organizationLegalName = `Matricia P06 Catalogue ${runId}`;
  const organizationDisplayName = `P06 Catalogue ${runId}`;
  const organizationIce = createHash("sha256").update(runId).digest("hex").slice(0, 16).toUpperCase();
  persistedResources = { userId, userEmail: email, organizationLegalName, organizationIce };
  await appendJournal("organization.create", "INTENT", { organizationLegalName, organizationIce, userId });
  await writeRunManifest("ORGANIZATION_CREATE_INTENT");
  const organization = await authenticated.client.rpc("create_or_request_organization", {
    p_legal_name: organizationLegalName,
    p_display_name: organizationDisplayName,
    p_ice: organizationIce,
    p_owner_role: "CLIENT_OWNER",
    p_idempotency_key: randomUUID(),
    p_correlation_id: randomUUID(),
  });
  crashIfRequested("ORGANIZATION_MUTATED");
  if (organization.error || organization.data?.outcome !== "ORGANIZATION_CREATED") {
    throw new Error("Unable to create the isolated P06 organization");
  }
  organizationId = organization.data.organization_id;
  await appendJournal("organization.create", "RESULT", { organizationId, organizationLegalName, organizationIce });
  persistedResources = { userId, userEmail: email, organizationId, organizationLegalName, organizationIce };
  await writeRunManifest("ORGANIZATION_CREATED");

  catalogFixture = await createCatalogFixture(
    database,
    authenticated.client,
    admin,
    userId,
    organizationId,
    async (fixture, phase) => {
      catalogFixture = fixture;
      persistedResources = {
        userId,
        userEmail: email,
        organizationId,
        organizationLegalName,
        organizationIce,
        catalog: { library: fixture.library, release: fixture.release, releaseKey: fixture.releaseKey },
      };
      await writeRunManifest(phase);
    },
  );

  const state = playwrightState(authenticated.cookies, config.baseUrl);
  await writeFile(statePath, `${JSON.stringify(state, null, 2)}\n`, { mode: 0o600 });
  const manifestPayload = {
    schemaVersion: 2,
    environment: config.environment,
    projectRef: config.projectRef,
    runId,
    pid: process.pid,
    processStartedAt,
    runTokenHash,
    artifactDirectory: runDirectory,
    createdAt: runCreatedAt.toISOString(),
    expiresAt: new Date(runCreatedAt.getTime() + maximumRunAgeMs).toISOString(),
    phase: "READY",
    fixtureResources: persistedResources,
    state: { path: statePath, sha256: createHash("sha256").update(await readFile(statePath)).digest("hex") },
    fixture: {
      libraryNameFr: catalogFixture.libraryNameFr,
      libraryNameAr: catalogFixture.libraryNameAr,
      firstCode: catalogFixture.firstCode,
      secondCode: catalogFixture.secondCode,
      libraryId: catalogFixture.library,
      serviceId: catalogFixture.serviceA,
      serviceVersionId: catalogFixture.serviceAVersion,
      serviceContentHash: catalogFixture.serviceAHash,
      adminItems: catalogFixture.adminItems,
      adminSourceHash: catalogFixture.adminSourceHash,
      adminReleaseKey: catalogFixture.adminReleaseKey,
    },
  };
  const childManifestKey = randomBytes(32).toString("base64url");
  const manifest = {
    ...manifestPayload,
    signature: signatureFor(manifestPayload, config.serviceRoleKey),
    childSignature: signatureFor(manifestPayload, childManifestKey),
  };
  await writeAtomic(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  await secureLocalPaths(authDirectory, [statePath]);
  await secureLocalPaths(runDirectory, [manifestPath]);

  const environment = buildChildEnvironment(process.env, {
    E2E_BASE_URL: config.baseUrl,
    E2E_P06_MANIFEST: manifestPath,
    E2E_P06_STORAGE_STATE: statePath,
    E2E_P06_ENVIRONMENT: config.environment,
    E2E_P06_PROJECT_REF: config.projectRef,
    E2E_P06_MANIFEST_KEY: childManifestKey,
    E2E_P06_FORCE_FAILURE: process.argv.includes("--force-failure") ? "1" : "0",
  });
  if (await runPlaywright(environment) !== 0) throw new Error("Authenticated P06 Playwright suite failed");
  console.log("PASS P06 authenticated catalogue E2E suite");
} catch (error) {
  if (/^(?:P06|Unable to|Authenticated P06)/u.test(error?.message ?? "")) {
    console.error(`P06_SAFE_FAILURE: ${error.message}`);
  }
  failure = error;
} finally {
  if (heartbeatTimer) clearInterval(heartbeatTimer);
  if (heartbeatFailure) failure = failure
    ? new AggregateError([failure, heartbeatFailure], "P06 run and heartbeat failed")
    : heartbeatFailure;
  if (database && catalogFixture) {
    try { await removeCatalogFixture(database, catalogFixture); }
    catch (error) {
      remoteCleanupSucceeded = false;
      failure = failure ? new AggregateError([failure, error], "P06 run and catalogue cleanup failed") : error;
    }
  }
  if (database && (organizationId || userId)) {
    try {
      const fixture = {
        organizationIds: organizationId ? [organizationId] : [],
        userIds: userId ? [userId] : [],
        storagePaths: [],
      };
      await neutralizeFixture(database, fixture);
      await verifyFixtureNeutralized(database, fixture);
    } catch (error) {
      remoteCleanupSucceeded = false;
      failure = failure ? new AggregateError([failure, error], "P06 run and database cleanup failed") : error;
    }
  }
  if (admin && userId) {
    try {
      const disabled = await admin.auth.admin.updateUserById(userId, {
        ban_duration: "876000h",
        app_metadata: { p06_e2e_fixture: true, p06_e2e_neutralized: true },
      });
      if (disabled.error) throw disabled.error;
    } catch (error) {
      remoteCleanupSucceeded = false;
      failure = failure ? new AggregateError([failure, error], "P06 run and identity cleanup failed") : error;
    }
  }
  if (database) {
    try { await database.end(); }
    catch (error) { failure = failure ? new AggregateError([failure, error], "P06 database close failed") : error; }
  }
  try {
    assertRunPath(runDirectory);
    if (remoteCleanupSucceeded) {
      await rm(runDirectory, { recursive: true, force: true });
      await access(runDirectory).then(
        () => { throw new Error("P06 run artifacts still exist after cleanup"); },
        (error) => { if (error?.code !== "ENOENT") throw error; },
      );
    }
  } catch (error) {
    failure = failure ? new AggregateError([failure, error], "P06 artifact cleanup failed") : error;
  }
}

if (failure) {
  console.error("FAIL P06 authenticated E2E execution failed; no credential or remote detail was printed");
  process.exitCode = 1;
}
