import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import postgres from 'postgres';

function parseEnv(source) {
  return Object.fromEntries(source.split(/\r?\n/).flatMap((line) => {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (!match) return [];
    return [[match[1], match[2].replace(/^(['"])(.*)\1$/, '$2')]];
  }));
}

async function databaseUrl(root, env) {
  const configured = env.SUPABASE_DB_POOLER_URL || env.DIRECT_URL;
  if (!configured?.startsWith('postgres')) throw new Error('A PostgreSQL development URL is required');
  const metadata = JSON.parse(await readFile(resolve(root, 'supabase', 'project-metadata.json'), 'utf8'));
  if (metadata.environment === 'production') throw new Error('Production migration validation is forbidden');
  const expectedRef = new URL(env.NEXT_PUBLIC_SUPABASE_URL).hostname.split('.')[0];
  if (metadata.project_ref !== expectedRef) throw new Error('Supabase project reference mismatch');
  const url = new URL(configured);
  if (url.hostname.startsWith('db.') && url.hostname.endsWith('.supabase.co')) {
    if (!metadata.region) throw new Error('Supabase development region is required');
    url.hostname = `aws-0-${metadata.region}.pooler.supabase.com`;
    url.port = '5432';
    url.username = `postgres.${expectedRef}`;
    url.searchParams.set('sslmode', 'require');
  }
  return url.toString();
}

const root = process.cwd();
const files = process.argv.slice(2);
if (files.length === 0) throw new Error('Pass one or more migration paths in application order');
for (const file of files) {
  if (!/^supabase[\\/]migrations[\\/]\d+_[A-Za-z0-9_.-]+\.sql$/.test(file)) throw new Error(`Invalid migration path: ${file}`);
}
const migrationSources = [];
for (const file of files) {
  const source = await readFile(resolve(root, file), 'utf8');
  if (/^\s*(?:begin|commit|rollback)\s*;/im.test(source)) {
    throw new Error(`${file}: explicit transaction control is forbidden in transactional validation`);
  }
  migrationSources.push(source);
}
const env = parseEnv(await readFile(resolve(root, '.env.local'), 'utf8'));
const sql = postgres(await databaseUrl(root, env), { max: 1, prepare: false, connect_timeout: 20 });
const rollback = new Error('EXPECTED_VALIDATION_ROLLBACK');
try {
  await sql.begin(async (transaction) => {
    for (const source of migrationSources) await transaction.unsafe(source);
    throw rollback;
  });
} catch (error) {
  if (error !== rollback) throw error;
} finally {
  await sql.end();
}
console.log(`PASS transactional migration validation (${files.length} file${files.length === 1 ? '' : 's'})`);
