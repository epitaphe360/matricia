import { requireDevelopment, docker, loadOwnState } from './safety.mjs';
requireDevelopment();
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { validateSourceTarget } from './safety.mjs';
import { createHash } from 'node:crypto';
const s = await loadOwnState(), statePath = resolve(s.directory, 'state.private.json');
const target = JSON.parse(docker(['inspect', '--format', '{"labels":{{json .Config.Labels}},"networks":{{json .NetworkSettings.Networks}}}', s.database], { encoding: 'utf8' }));
if (target.labels['matricia.client-browser-test'] !== s.token || !target.networks[s.network])
    throw new Error('OWNED_TEST_TARGET_REQUIRED');
s.dbHost = target.networks[s.network].IPAddress;
s.dbPort = 5432;
const source = validateSourceTarget(JSON.parse(await readFile(resolve(process.argv[2] ?? ''), 'utf8')));
const sourceInspect = JSON.parse(docker(['inspect', '--format', '{"labels":{{json .Config.Labels}},"network":"{{.HostConfig.NetworkMode}}","ports":{{json .NetworkSettings.Ports}}}', source.name], { encoding: 'utf8' }));
if (sourceInspect.labels['matricia.isolated-replay'] !== source.token || sourceInspect.network !== 'none' || Object.values(sourceInspect.ports ?? {}).some(value => value?.length))
    throw new Error('SOURCE_ISOLATION_NOT_VERIFIED');
const archive = docker(['exec', source.name, 'pg_dump', '-U', 'supabase_admin', '-d', 'postgres', '-Fc']);
await writeFile(resolve(s.directory, 'baseline.private.dump'), archive, { mode: 0o600 });
s.baselineArchiveSha256 = createHash('sha256').update(archive).digest('hex');
try {
    docker(['exec', '-i', s.database, 'pg_restore', '-U', 'supabase_admin', '-d', 'postgres', '--clean', '--if-exists', '--exit-on-error'], { input: archive });
}
catch (e) {
    await writeFile(resolve(s.directory, 'restore.log'), String(e.stderr ?? ''), { mode: 0o600 });
    throw new Error('OWNED_TEST_RESTORE_FAILED');
}
// Fresh test runtime passwords, not source cluster credentials or user sessions.
docker(['exec', '-i', s.database, 'psql', '-X', '-U', 'supabase_admin', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'], { input: Buffer.from(`alter role supabase_auth_admin password '${s.dbSecret}';alter role supabase_storage_admin password '${s.dbSecret}';alter role authenticator password '${s.dbSecret}';alter role supabase_admin password '${s.dbSecret}';`) });
s.status = 'RESTORED';
await writeFile(statePath, JSON.stringify(s), { mode: 0o600 });
console.log(JSON.stringify({ status: s.status, archiveSha256: s.baselineArchiveSha256, database: s.database }));
