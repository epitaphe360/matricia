import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import postgres from 'postgres';

function parseEnv(source) {
  return Object.fromEntries(source.split(/\r?\n/).flatMap((line) => {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (!match) return [];
    return [[match[1], match[2].replace(/^(['"])(.*)\1$/, '$2')]];
  }));
}

async function resolveDatabaseUrl(env, root) {
  const configured = env.SUPABASE_DB_POOLER_URL || env.DIRECT_URL;
  if (!configured?.startsWith('postgres')) throw new Error('A PostgreSQL DIRECT_URL is required');
  const direct = new URL(configured);
  if (!direct.hostname.startsWith('db.') || !direct.hostname.endsWith('.supabase.co')) return configured;

  const projectRef = new URL(env.NEXT_PUBLIC_SUPABASE_URL).hostname.split('.')[0];
  let region = env.SUPABASE_REGION;
  try {
    const metadata = JSON.parse(await readFile(resolve(root, 'supabase', 'project-metadata.json'), 'utf8'));
    if (metadata.project_ref === projectRef && metadata.environment !== 'production') region ||= metadata.region;
  } catch (error) {
    if (error?.code !== 'ENOENT') throw error;
  }
  if (!region && env.SUPABASE_ACCESS_TOKEN) {
    const response = await fetch(`https://api.supabase.com/v1/projects/${projectRef}`, {
      headers: { Authorization: `Bearer ${env.SUPABASE_ACCESS_TOKEN}` },
    });
    if (!response.ok) throw new Error(`Supabase project metadata failed (${response.status})`);
    region = (await response.json()).region;
  }
  if (!region) throw new Error('SUPABASE_REGION is required when the direct host is IPv6-only');

  direct.hostname = `aws-0-${region}.pooler.supabase.com`;
  direct.port = '5432';
  direct.username = `postgres.${projectRef}`;
  direct.searchParams.set('sslmode', 'require');
  return direct.toString();
}

function tapLines(value, target = []) {
  if (Array.isArray(value)) for (const item of value) tapLines(item, target);
  else if (value && typeof value === 'object') for (const item of Object.values(value)) tapLines(item, target);
  else if (typeof value === 'string' && /^(?:not )?ok\b|^1\.\./.test(value)) target.push(value);
  return target;
}

const root = resolve(import.meta.dirname, '..');
const fileEnv = parseEnv(await readFile(resolve(root, '.env.local'), 'utf8'));
const env = { ...fileEnv, ...process.env };
if (!['development', 'staging'].includes(env.APP_ENV)) throw new Error('DB tests are restricted to development/staging');

const databaseUrl = await resolveDatabaseUrl(env, root);
const sql = postgres(databaseUrl, { max: 1, prepare: false, connect_timeout: 15, idle_timeout: 2 });
const testDirectory = resolve(root, 'supabase', 'tests');
const files = (await readdir(testDirectory)).filter((file) => file.endsWith('.test.sql')).sort();
let assertions = 0;

try {
  for (const file of files) {
    const source = await readFile(resolve(testDirectory, file), 'utf8');
    const result = await sql.unsafe(source, [], { simple: true });
    const lines = tapLines(result);
    const failures = lines.filter((line) => line.startsWith('not ok'));
    assertions += lines.filter((line) => /^(?:not )?ok\b/.test(line)).length;
    if (failures.length) throw new Error(`${file}: ${failures.join(' | ')}`);
    console.log(`PASS ${file}`);
  }
  console.log(`DB tests passed: ${files.length} files, ${assertions} assertions`);
} finally {
  await sql.end({ timeout: 2 });
}
