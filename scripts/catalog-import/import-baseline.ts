import { readFile } from 'node:fs/promises';
import { resolve, basename } from 'node:path';
import { randomUUID } from 'node:crypto';
import postgres, { type Sql } from 'postgres';
import { canonicalJson, sha256File, sha256Text } from './canonical.ts';
import { chunks, csvRecords, jsonLines } from './streaming.ts';

type JsonObject = Record<string, unknown>;
type StagedRow = { line_number: number; business_key: string; payload: JsonObject };
const root = resolve(import.meta.dirname, '..', '..');
const sourceRoot = resolve(root, 'catalogue', 'Matricia_Catalogue_Metier_V1');
const sourceNames = ['catalog_manifest.json','libraries.csv','categories.csv','subcategories.csv','services.csv','service_subcategory_links.csv','questions_rfq.csv','questions_diagnostic.csv','questions_provider_qualification.csv','questions_all.jsonl'] as const;
const globalCounts = { libraries: 10, categories: 40, subcategories: 80, services: 200, service_subcategory_links: 212, rfq_questions: 5000, diagnostic_questions: 700, provider_questions: 300, total_questions: 6000 };

function parseEnv(source: string): Record<string, string> {
  return Object.fromEntries(source.split(/\r?\n/).flatMap((line) => { const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/); return match ? [[match[1]!, match[2]!.replace(/^(['"])(.*)\1$/, '$2')]] : []; }));
}
function parseArgs(values: string[]) {
  const result = { libraries: ['IT'], dryRun: true, all: false, validateOnly: false, verify: false };
  for (let index = 0; index < values.length; index += 1) {
    const arg = values[index];
    if (arg === '--all') { result.all = true; result.libraries = []; }
    else if (arg === '--library') { const library = values[++index]; if (!library) throw new Error('LIBRARY_ARGUMENT_REQUIRED'); result.libraries = [library.toUpperCase()]; }
    else if (arg === '--commit') result.dryRun = false;
    else if (arg === '--dry-run') result.dryRun = true;
    else if (arg === '--validate-only') result.validateOnly = true;
    else if (arg === '--verify') result.verify = true;
    else throw new Error(`UNKNOWN_ARGUMENT:${arg}`);
  }
  return result;
}
function bool(value: unknown): boolean { if (value === true || value === 'True' || value === 'true') return true; if (value === false || value === 'False' || value === 'false') return false; throw new Error(`INVALID_BOOLEAN:${String(value)}`); }
function integer(value: unknown): number { const parsed = Number(value); if (!Number.isSafeInteger(parsed)) throw new Error(`INVALID_INTEGER:${String(value)}`); return parsed; }
function requiredText(value: unknown, field: string): string { if (typeof value !== 'string' || !value.length) throw new Error(`REQUIRED_TEXT:${field}`); return value; }
function embedded(value: unknown, expected: 'array'|'object'): unknown {
  const parsed = typeof value === 'string' ? JSON.parse(value || (expected === 'array' ? '[]' : '{}')) : value;
  if ((expected === 'array' && !Array.isArray(parsed)) || (expected === 'object' && (!parsed || Array.isArray(parsed) || typeof parsed !== 'object'))) throw new Error(`INVALID_EMBEDDED_JSON:${expected}`);
  return parsed;
}
function normalizeCatalog(entity: string, raw: Record<string, string>): JsonObject {
  const value: JsonObject = { ...raw };
  for (const key of ['order','version']) if (key in value) value[key] = integer(value[key]);
  for (const key of ['franchisee_can_edit','franchisee_can_create','central_approval_for_sensitive_changes','volume_eligible','recurring_eligible','credit_eligible']) if (key in value) value[key] = bool(value[key]);
  for (const key of ['subcategories_json','secondary_subcategory_codes_json','focus_terms','central_approval_flags']) if (key in value) value[key] = embedded(value[key], 'array');
  if (entity === 'SERVICE' && value.category_code !== value.subcategory_code) throw new Error(`SERVICE_SUBCATEGORY_ALIAS_MISMATCH:${value.code}`);
  return value;
}
function normalizeQuestion(raw: JsonObject): JsonObject {
  const sourceOptions = embedded(raw.options_json, 'array');
  const value: JsonObject = { ...raw, order: integer(raw.order), version: integer(raw.version), weight: integer(raw.weight), max_score: integer(raw.max_score), required: bool(raw.required), required_for_quote: bool(raw.required_for_quote), modifiable_by_franchisee: bool(raw.modifiable_by_franchisee), requires_central_approval: bool(raw.requires_central_approval), options: raw.answer_type === 'YES_NO' ? [] : sourceOptions, validation_schema: embedded(raw.validation_json, 'object'), condition: embedded(raw.condition_json, 'object') };
  delete value.options_json; delete value.validation_json; delete value.condition_json;
  return value;
}
async function countRecords(name: typeof sourceNames[number]): Promise<number> {
  const path = resolve(sourceRoot, name); let count = 0;
  if (name.endsWith('.csv')) for await (const _ of csvRecords(path)) count += 1;
  else if (name.endsWith('.jsonl')) for await (const _ of jsonLines(path)) count += 1;
  else count = 1;
  return count;
}
async function sourceManifest() {
  const result = [];
  for (const name of sourceNames) { const info = await sha256File(resolve(sourceRoot, name)); result.push({ path: `catalogue/Matricia_Catalogue_Metier_V1/${name}`, sha256: info.sha256, byte_size: info.byteSize, data_rows: await countRecords(name), generator_version: '1.0.0' }); }
  return result;
}
async function loadSlice(libraryCode: string) {
  const definitions = [
    ['libraries.csv','LIBRARY',(row: Record<string,string>) => requiredText(row.code,'code')],['categories.csv','CATEGORY',(row: Record<string,string>) => requiredText(row.code,'code')],
    ['subcategories.csv','SUBCATEGORY',(row: Record<string,string>) => requiredText(row.code,'code')],['services.csv','SERVICE',(row: Record<string,string>) => requiredText(row.code,'code')],
    ['service_subcategory_links.csv','SERVICE_SUBCATEGORY_LINK',(row: Record<string,string>) => `${requiredText(row.service_code,'service_code')}:${requiredText(row.subcategory_code,'subcategory_code')}`],
  ] as const;
  const entities = new Map<string,{ source: string; rows: StagedRow[] }>();
  for (const [name, entity, key] of definitions) {
    const rows: StagedRow[] = [];
    for await (const item of csvRecords(resolve(sourceRoot, name))) { const rowLibrary = item.value.library_code ?? item.value.code; if (rowLibrary === libraryCode) rows.push({ line_number: item.lineNumber, business_key: key(item.value), payload: normalizeCatalog(entity, item.value) }); }
    entities.set(entity, { source: `catalogue/Matricia_Catalogue_Metier_V1/${name}`, rows });
  }
  const questions: StagedRow[] = [];
  for await (const item of jsonLines(resolve(sourceRoot, 'questions_all.jsonl'))) if (item.value.library_code === libraryCode) questions.push({ line_number: item.lineNumber, business_key: String(item.value.question_id), payload: normalizeQuestion(item.value) });
  entities.set('QUESTION', { source: 'catalogue/Matricia_Catalogue_Metier_V1/questions_all.jsonl', rows: questions });
  const phases = Object.fromEntries(['RFQ','DIAGNOSTIC','PROVIDER_QUALIFICATION'].map((phase) => [phase, questions.filter((row) => row.payload.phase === phase).length])) as Record<'RFQ'|'DIAGNOSTIC'|'PROVIDER_QUALIFICATION',number>;
  return { entities, expected: { libraries: entities.get('LIBRARY')!.rows.length, categories: entities.get('CATEGORY')!.rows.length, subcategories: entities.get('SUBCATEGORY')!.rows.length, services: entities.get('SERVICE')!.rows.length, service_subcategory_links: entities.get('SERVICE_SUBCATEGORY_LINK')!.rows.length, rfq_questions: phases.RFQ, diagnostic_questions: phases.DIAGNOSTIC, provider_questions: phases.PROVIDER_QUALIFICATION, total_questions: questions.length } };
}
async function configuredDatabase() {
  const env = { ...parseEnv(await readFile(resolve(root, '.env.local'), 'utf8')), ...process.env };
  const metadata = JSON.parse(await readFile(resolve(root, 'supabase', 'project-metadata.json'), 'utf8')) as { environment: string; project_ref: string; region: string };
  if (env.APP_ENV !== 'development' || metadata.environment !== 'development') throw new Error('CATALOG_IMPORT_DEVELOPMENT_ONLY');
  const publicEndpoint = env.NEXT_PUBLIC_SUPABASE_URL; const databaseEndpoint = env.SUPABASE_DB_POOLER_URL || env.DIRECT_URL;
  if (!publicEndpoint || !databaseEndpoint) throw new Error('SUPABASE_DEVELOPMENT_CONFIGURATION_REQUIRED');
  const publicUrl = new URL(publicEndpoint); if (publicUrl.hostname !== `${metadata.project_ref}.supabase.co`) throw new Error('SUPABASE_PROJECT_MISMATCH');
  const url = new URL(databaseEndpoint); const direct = `db.${metadata.project_ref}.supabase.co`; const pooler = `aws-0-${metadata.region}.pooler.supabase.com`;
  if (url.hostname === direct && url.username === 'postgres') { url.hostname = pooler; url.port = '5432'; url.username = `postgres.${metadata.project_ref}`; }
  else if (url.hostname !== pooler || url.username !== `postgres.${metadata.project_ref}`) throw new Error('DATABASE_TARGET_MISMATCH');
  url.searchParams.set('sslmode','require'); return { sql: postgres(url.toString(), { max: 1, prepare: false }), metadata };
}
async function ensureDevelopmentPrincipal(sql: Sql, projectRef: string) {
  const rows = await sql`select private.catalog_baseline_uuid('catalog-import-development-actor',${projectRef}) actor_id,private.catalog_baseline_uuid('catalog-import-development-org',${projectRef}) organization_id`;
  const identity = rows[0]; if (!identity) throw new Error('DEVELOPMENT_PRINCIPAL_IDS_MISSING');
  const { actor_id: actorId, organization_id: organizationId } = identity;
  const principalEmail = `catalog-import-${projectRef}@example.invalid`;
  await sql`insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values(${actorId}::uuid,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',${principalEmail},'',now(),'{}','{}',now(),now()) on conflict(id) do nothing`;
  await sql`insert into public.organizations(id,legal_name,display_name,status,created_by) values(${organizationId}::uuid,'Matricia Baseline Development','Matricia Baseline Development','ACTIVE',${actorId}::uuid) on conflict(id) do nothing`;
  const verified = await sql`select exists(select 1 from auth.users where id=${actorId}::uuid and aud='authenticated' and role='authenticated' and email=${principalEmail}) actor_ok,exists(select 1 from public.organizations where id=${organizationId}::uuid and legal_name='Matricia Baseline Development' and display_name='Matricia Baseline Development' and status='ACTIVE' and created_by=${actorId}::uuid) organization_ok`;
  if (!verified[0]?.actor_ok || !verified[0]?.organization_ok) throw new Error('DEVELOPMENT_PRINCIPAL_IDENTITY_MISMATCH');
  await sql`insert into public.platform_user_roles(user_id,role_code,granted_by,revoked_at) values(${actorId}::uuid,'MATRICIA_ADMIN',${actorId}::uuid,null) on conflict(user_id,role_code) do update set granted_by=excluded.granted_by,granted_at=clock_timestamp(),revoked_at=null`;
  const roles = await sql`select count(*)::integer active_count,bool_and(role_code='MATRICIA_ADMIN' and granted_by=${actorId}::uuid) exact from public.platform_user_roles where user_id=${actorId}::uuid and revoked_at is null`;
  if (roles[0]?.active_count !== 1 || roles[0]?.exact !== true) throw new Error('DEVELOPMENT_PRINCIPAL_ROLE_MISMATCH');
  return { actorId, organizationId };
}
async function neutralizeDevelopmentPrincipal(sql: Sql, actorId: string) {
  await sql.unsafe('reset role');
  await sql`update public.platform_user_roles set revoked_at=clock_timestamp() where user_id=${actorId}::uuid and role_code='MATRICIA_ADMIN' and granted_by=${actorId}::uuid and revoked_at is null`;
  const active = await sql`select exists(select 1 from public.platform_user_roles where user_id=${actorId}::uuid and revoked_at is null) active`;
  if (active[0]?.active) throw new Error('DEVELOPMENT_PRINCIPAL_NOT_NEUTRALIZED');
}
async function authenticate(sql: Sql, actorId: string) { await sql.unsafe("set local role authenticated;set local lock_timeout='10s';set local statement_timeout='120s'"); await sql`select set_config('request.jwt.claim.sub',${actorId},true),set_config('request.jwt.claims',${JSON.stringify({ sub: actorId, role: 'authenticated', aal: 'aal2' })},true)`; }
async function importSlice(sql: Sql, projectRef: string, actorId: string, organizationId: string, manifest: JsonObject, sources: Awaited<ReturnType<typeof sourceManifest>>, bundleHash: string, libraryCode: string, dryRun: boolean) {
  const slice = await loadSlice(libraryCode); const expectedByLibrary = (manifest.by_library as JsonObject)[libraryCode] as JsonObject;
  const expected = { libraries: 1, categories: Number(expectedByLibrary.categories), subcategories: Number(expectedByLibrary.subcategories), services: Number(expectedByLibrary.services), service_subcategory_links: slice.expected.service_subcategory_links, rfq_questions: Number(expectedByLibrary.rfq_questions), diagnostic_questions: Number(expectedByLibrary.diagnostic_questions), provider_questions: Number(expectedByLibrary.provider_questions), total_questions: Number(expectedByLibrary.rfq_questions)+Number(expectedByLibrary.diagnostic_questions)+Number(expectedByLibrary.provider_questions) };
  if (canonicalJson(slice.expected) !== canonicalJson(expected)) throw new Error(`SLICE_COUNT_MISMATCH:${libraryCode}`);
  await sql.unsafe('begin');
  try {
    const principal = await ensureDevelopmentPrincipal(sql, projectRef);
    if (principal.actorId !== actorId || principal.organizationId !== organizationId) throw new Error('DEVELOPMENT_PRINCIPAL_CHANGED');
    await authenticate(sql, actorId);
    const baselineKey = `MATRICIA_GOLD_MASTER_BASELINE_V1:${libraryCode}`; const suffix = `${libraryCode}-${bundleHash.slice(0,16)}`; const correlationId = randomUUID();
    const begun = await sql`select public.begin_catalog_import(${baselineKey},${bundleHash},${sql.json(manifest as never)},${libraryCode},${organizationId}::uuid,${sql.json(expected as never)},${sql.json(sources as never)},${`baseline-begin-${suffix}`},${correlationId}::uuid) result`;
    const begunResult = begun[0]?.result as JsonObject|undefined; const batchId = begunResult?.batch_id;
    if (typeof batchId !== 'string') throw new Error('CATALOG_IMPORT_BEGIN_RESPONSE_INVALID');
    for (const [entity, group] of slice.entities) for (const chunk of chunks(group.rows, 100)) {
      const first = chunk[0]; if (!first) throw new Error('CATALOG_IMPORT_EMPTY_CHUNK');
      const chunkHash = sha256Text(canonicalJson(chunk)); const key = `baseline-stage-${libraryCode}-${entity.toLowerCase()}-${first.line_number}-${chunkHash.slice(0,16)}`;
      try {
        await sql`select public.stage_catalog_import_rows(${batchId}::uuid,${group.source},${entity},${sql.json(chunk as never)},${key},${correlationId}::uuid)`;
      } catch (error) {
        throw new Error(`CATALOG_IMPORT_STAGE_FAILED:${libraryCode}:${entity}:${first.line_number}:${error instanceof Error ? error.message : 'UNKNOWN'}`,{ cause:error });
      }
    }
    let report = (await sql`select public.get_catalog_import_report(${batchId}::uuid) result`)[0]?.result as JsonObject|undefined;
    if (!report) throw new Error('CATALOG_IMPORT_REPORT_MISSING');
    const validateVersion = integer(report.row_version);
    const validated = (await sql`select public.validate_catalog_import(${batchId}::uuid,${validateVersion},${`baseline-validate-${suffix}`},${correlationId}::uuid) result`)[0]?.result as JsonObject|undefined;
    if (!validated) throw new Error('CATALOG_IMPORT_VALIDATE_RESPONSE_MISSING');
    if (validated.outcome !== 'CATALOG_IMPORT_VALIDATED') {
      report = (await sql`select public.get_catalog_import_report(${batchId}::uuid) result`)[0]?.result as JsonObject|undefined;
      const summary = ((report?.errors as JsonObject[]|undefined) ?? []).reduce<Record<string,number>>((counts,error) => {
        const key = `${String(error.error_code)}:${String(error.field_name ?? '')}`;
        counts[key] = (counts[key] ?? 0) + 1;
        return counts;
      },{});
      throw new Error(`CATALOG_IMPORT_INVALID:${libraryCode}:${validated.error_count}:${canonicalJson(summary)}`);
    }
    report = (await sql`select public.get_catalog_import_report(${batchId}::uuid) result`)[0]?.result as JsonObject|undefined;
    if (!report) throw new Error('CATALOG_IMPORT_REPORT_MISSING');
    const commitVersion = integer(report.row_version);
    const committedResult = (await sql`select public.commit_catalog_import(${batchId}::uuid,${commitVersion},${`baseline-commit-${suffix}`},${correlationId}::uuid) result`)[0]?.result as JsonObject|undefined;
    if (!committedResult) throw new Error('CATALOG_IMPORT_COMMIT_RESPONSE_MISSING');
    if (committedResult.outcome !== 'CATALOG_IMPORT_COMMITTED' || committedResult.published !== false || committedResult.translation_status !== 'PENDING') throw new Error(`CATALOG_IMPORT_COMMIT_INVALID:${libraryCode}`);
    if (dryRun) await sql.unsafe('rollback');
    else { await neutralizeDevelopmentPrincipal(sql, actorId); await sql.unsafe('commit'); }
    console.log(`${dryRun ? 'DRY_RUN' : 'COMMITTED'} library=${libraryCode} counts=${canonicalJson(expected)} release=${committedResult.candidate_release_id}`);
  } catch (error) { try { await sql.unsafe('rollback'); } catch {} throw error; }
}

const args = parseArgs(process.argv.slice(2));
const manifest = JSON.parse(await readFile(resolve(sourceRoot, 'catalog_manifest.json'), 'utf8')) as JsonObject;
if (canonicalJson(manifest.counts) !== canonicalJson(globalCounts)) throw new Error('GLOBAL_MANIFEST_COUNTS_INVALID');
const sources = await sourceManifest();
const actualGlobal = Object.fromEntries([['libraries.csv','libraries'],['categories.csv','categories'],['subcategories.csv','subcategories'],['services.csv','services'],['service_subcategory_links.csv','service_subcategory_links'],['questions_rfq.csv','rfq_questions'],['questions_diagnostic.csv','diagnostic_questions'],['questions_provider_qualification.csv','provider_questions'],['questions_all.jsonl','total_questions']].map(([file,key]) => [key,sources.find((item) => basename(item.path) === file)!.data_rows]));
if (canonicalJson(actualGlobal) !== canonicalJson(globalCounts)) throw new Error('GLOBAL_SOURCE_COUNTS_INVALID');
const canonicalSources = sources.map(({ path, sha256, byte_size, data_rows }) => ({ path, sha256, byte_size, data_rows })).sort((a,b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0);
const bundleHash = sha256Text(canonicalJson({ manifest, sources: canonicalSources }));
const selected = args.all ? Object.keys(manifest.by_library as JsonObject).sort() : args.libraries;
if (args.validateOnly) {
  for (const libraryCode of selected) {
    const slice = await loadSlice(libraryCode); const expected = (manifest.by_library as JsonObject)[libraryCode] as JsonObject;
    const total = Number(expected.rfq_questions)+Number(expected.diagnostic_questions)+Number(expected.provider_questions);
    if (slice.expected.libraries!==1 || slice.expected.categories!==Number(expected.categories) || slice.expected.subcategories!==Number(expected.subcategories) || slice.expected.services!==Number(expected.services) || slice.expected.rfq_questions!==Number(expected.rfq_questions) || slice.expected.diagnostic_questions!==Number(expected.diagnostic_questions) || slice.expected.provider_questions!==Number(expected.provider_questions) || slice.expected.total_questions!==total || slice.expected.service_subcategory_links<slice.expected.services) throw new Error(`SLICE_COUNT_MISMATCH:${libraryCode}`);
    console.log(`VALID library=${libraryCode} counts=${canonicalJson(slice.expected)}`);
  }
  console.log(`VALID baseline bundle=${bundleHash} libraries=${selected.length}`);
} else {
  const { sql, metadata } = await configuredDatabase();
  try {
    if (args.verify) {
      const rows = await sql`with batches as (select * from public.catalog_import_batches where baseline_key like 'MATRICIA_GOLD_MASTER_BASELINE_V1:%' and status='IMPORTED') select
        (select count(*)::integer from batches) batches,
        (select count(distinct library_code)::integer from batches) batch_libraries,
        (select count(*)::integer from public.catalog_libraries l where l.id in(select library_id from batches)) libraries,
        (select count(*)::integer from public.catalog_categories c where c.library_id in(select library_id from batches)) categories,
        (select count(*)::integer from public.catalog_subcategories s where s.library_id in(select library_id from batches)) subcategories,
        (select count(*)::integer from public.catalog_services s where s.library_id in(select library_id from batches)) services,
        (select count(*)::integer from public.catalog_service_subcategory_links l where l.library_id in(select library_id from batches)) service_subcategory_links,
        (select count(*)::integer from public.question_bank_questions q where q.library_id in(select library_id from batches)) questions,
        (select count(*)::integer from public.questionnaires q where q.library_id in(select library_id from batches)) questionnaires,
        (select count(*)::integer from public.catalog_releases r where r.id in(select candidate_release_id from batches)) candidate_releases,
        (select count(*)::integer from public.catalog_import_rows r where r.batch_id in(select id from batches)) staged_rows,
        (select coalesce(bool_and(v.status='DRAFT' and v.translation_review_status='PENDING'),false) from public.question_versions v where v.source_import_batch_id in(select id from batches)) questions_draft_pending,
        (select coalesce(bool_and(r.status='DRAFT'),false) from public.catalog_releases r where r.id in(select candidate_release_id from batches)) releases_draft`;
      const actual = rows[0];
      const expected = { batches:10,batch_libraries:10,libraries:10,categories:40,subcategories:80,services:200,service_subcategory_links:212,questions:6000,questionnaires:220,candidate_releases:10,staged_rows:6542,questions_draft_pending:true,releases_draft:true };
      if (!actual || Object.entries(expected).some(([key,value]) => actual[key] !== value)) throw new Error(`CATALOG_BASELINE_VERIFY_FAILED:${canonicalJson(actual ?? {})}`);
      console.log(`VERIFIED baseline=${canonicalJson(actual)}`);
    } else {
      const principalRows = await sql`select private.catalog_baseline_uuid('catalog-import-development-actor',${metadata.project_ref}) actor_id,private.catalog_baseline_uuid('catalog-import-development-org',${metadata.project_ref}) organization_id`;
      const principal = principalRows[0]; if (!principal) throw new Error('DEVELOPMENT_PRINCIPAL_IDS_MISSING');
      await neutralizeDevelopmentPrincipal(sql, principal.actor_id);
      for (const libraryCode of selected) await importSlice(sql, metadata.project_ref, principal.actor_id, principal.organization_id, manifest, sources, bundleHash, libraryCode, args.dryRun);
    }
  } finally { await sql.end({ timeout: 2 }); }
}
