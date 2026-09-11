import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
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
  else if (typeof value === 'string') {
    for (const rawLine of value.split(/\r?\n/)) {
      const line = rawLine.trim();
      if (/^(?:not )?ok\b|^1\.\.\d+\b|^Bail out!/i.test(line)) target.push(line);
    }
  }
  return target;
}

function validateTap(file, lines) {
  const bailOut = lines.find((line) => /^Bail out!/i.test(line));
  if (bailOut) throw new Error(`${file}: ${bailOut}`);

  const plans = lines.filter((line) => /^1\.\.\d+\b/.test(line));
  if (plans.length !== 1) throw new Error(`${file}: expected exactly one TAP plan, received ${plans.length}`);

  const planned = Number.parseInt(plans[0].match(/^1\.\.(\d+)/)?.[1] ?? '', 10);
  const assertionLines = lines.filter((line) => /^(?:not )?ok\b/.test(line));
  if (!Number.isSafeInteger(planned) || planned < 1) throw new Error(`${file}: invalid TAP plan ${plans[0]}`);
  if (assertionLines.length !== planned) {
    throw new Error(`${file}: TAP plan requires ${planned} assertions, received ${assertionLines.length}`);
  }

  const numbered = assertionLines.map((line) => Number.parseInt(line.match(/^(?:not )?ok\s+(\d+)\b/)?.[1] ?? '', 10));
  if (numbered.some((number, index) => number !== index + 1)) {
    throw new Error(`${file}: TAP assertion numbers are missing, duplicated, or out of order`);
  }

  const failures = assertionLines.filter((line) => line.startsWith('not ok'));
  if (failures.length) throw new Error(`${file}: ${failures.join(' | ')}`);
  return planned;
}

async function verifyOutboxConcurrency(databaseUrl, admin) {
  const existing = await admin`
    select count(*)::integer as count
    from public.event_outbox
    where published_at is null
      and dead_lettered_at is null
      and available_at <= clock_timestamp()
      and (locked_at is null or locked_at < clock_timestamp()-interval '5 minutes')
  `;
  if (existing[0].count !== 0) {
    throw new Error('outbox concurrency test requires an isolated development/staging queue');
  }

  const correlationId = randomUUID();
  const firstWorkerId = randomUUID();
  const secondWorkerId = randomUUID();
  const inserted = await admin`
    insert into public.event_outbox (
      aggregate_type,aggregate_id,event_type,correlation_id,payload,available_at
    ) values (
      'security_test',${correlationId},'OutboxConcurrencyTestV1',
      ${correlationId}::uuid,jsonb_build_object('test',true),clock_timestamp()
    )
    returning id
  `;
  const eventId = inserted[0].id;
  const workerA = postgres(databaseUrl, { max: 1, prepare: false, connect_timeout: 15, idle_timeout: 0 });
  const workerB = postgres(databaseUrl, { max: 1, prepare: false, connect_timeout: 15, idle_timeout: 0 });
  let releaseFirst;
  let announceFirst;
  let rejectFirst;
  const holdFirst = new Promise((resolveHold) => { releaseFirst = resolveHold; });
  const firstClaimed = new Promise((resolveClaim, rejectClaim) => {
    announceFirst = resolveClaim;
    rejectFirst = rejectClaim;
  });

  try {
    const firstTransaction = workerA.begin(async (transaction) => {
      try {
        await transaction.unsafe('set local role service_role');
        const claimed = await transaction`
          select id from public.claim_outbox_events(${firstWorkerId}::uuid,1)
        `;
        announceFirst(claimed);
        await holdFirst;
        return claimed;
      } catch (error) {
        rejectFirst(error);
        throw error;
      }
    });

    const firstRows = await firstClaimed;
    let secondRows;
    try {
      secondRows = await workerB.begin(async (transaction) => {
        await transaction.unsafe('set local role service_role');
        return transaction`
          select id from public.claim_outbox_events(${secondWorkerId}::uuid,1)
        `;
      });
    } finally {
      releaseFirst();
    }
    await firstTransaction;

    if (firstRows.length !== 1 || String(firstRows[0].id) !== String(eventId)) {
      throw new Error('first Outbox worker did not claim the isolated test event');
    }
    if (secondRows.some((row) => String(row.id) === String(eventId))) {
      throw new Error('second Outbox worker double-claimed a row locked by the first transaction');
    }
  } finally {
    releaseFirst?.();
    await Promise.allSettled([
      workerA.end(),
      workerB.end(),
    ]);
    await admin.begin(async (transaction) => {
      await transaction.unsafe('lock table public.event_outbox in access exclusive mode');
      await transaction.unsafe('alter table public.event_outbox disable trigger event_outbox_no_delete');
      await transaction`
        delete from public.event_outbox
        where id=${eventId}
          and aggregate_type='security_test'
          and event_type='OutboxConcurrencyTestV1'
      `;
      await transaction.unsafe('alter table public.event_outbox enable trigger event_outbox_no_delete');
    });
  }
}

const root = resolve(import.meta.dirname, '..');
let fileEnv = {};
try {
  fileEnv = parseEnv(await readFile(resolve(root, '.env.local'), 'utf8'));
} catch (error) {
  if (error?.code !== 'ENOENT') throw error;
}
const env = { ...fileEnv, ...process.env };
if (!['development', 'staging'].includes(env.APP_ENV)) throw new Error('DB tests are restricted to development/staging');

const databaseUrl = await resolveDatabaseUrl(env, root);
const sql = postgres(databaseUrl, { max: 1, prepare: false, connect_timeout: 15, idle_timeout: 0 });
const testDirectory = resolve(root, 'supabase', 'tests');
const files = (await readdir(testDirectory)).filter((file) => file.endsWith('.test.sql')).sort();
let assertions = 0;

try {
  for (const file of files) {
    const source = await readFile(resolve(testDirectory, file), 'utf8');
    const result = await sql.unsafe(source, [], { simple: true });
    const lines = tapLines(result);
    assertions += validateTap(file, lines);
    console.log(`PASS ${file}`);
  }
  await verifyOutboxConcurrency(databaseUrl, sql);
  console.log('PASS outbox_concurrency (2 connections)');
  console.log(`DB tests passed: ${files.length} files, ${assertions} assertions, 1 concurrency scenario`);
} finally {
  await sql.end({ timeout: 2 });
}
