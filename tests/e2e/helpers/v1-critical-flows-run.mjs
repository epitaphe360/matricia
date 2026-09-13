import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { copyFile, mkdir, rm, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { loadSafeConfiguration } from "../../../scripts/p05-e2e/environment.mjs";
import { provision } from "../../../scripts/p05-e2e/provision.mjs";
import { buildChildEnvironment, secureLocalPaths, sha256File, validateFreshManifest } from "../../../scripts/p05-e2e/security.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");
const runToken = randomUUID();
const output = resolve(root, "artifacts", "test-results", `v1-critical-flows-${runToken}`);
const authSnapshotDirectory = resolve(root, "artifacts", "test-results", `.v1-critical-auth-${runToken}`);
let fixture;
let failure;

try {
  fixture = await provision();
  const config = await loadSafeConfiguration(root);
  await validateFreshManifest(fixture.manifest, config);
  await mkdir(authSnapshotDirectory, { recursive: false, mode: 0o700 });
  await secureLocalPaths(authSnapshotDirectory, []);
  const states = {};
  for (const [key, state] of Object.entries(fixture.manifest.states)) {
    const path = resolve(authSnapshotDirectory, `${key}.json`);
    await copyFile(state.path, path);
    await secureLocalPaths(authSnapshotDirectory, [path]);
    states[key] = { path, sha256: await sha256File(path) };
  }
  const manifestPath = resolve(authSnapshotDirectory, "manifest.json");
  const manifest = { ...fixture.manifest, states };
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, { mode: 0o600 });
  await secureLocalPaths(authSnapshotDirectory, [manifestPath]);
  await validateFreshManifest(manifest, config);
  const environment = buildChildEnvironment(process.env, {
    E2E_BASE_URL: config.baseUrl,
    E2E_P05_MANIFEST: manifestPath,
    E2E_CLIENT_STORAGE_STATE: manifest.states.clientA.path,
    E2E_ADMIN_STORAGE_STATE: manifest.states.centralAal2.path,
    E2E_CLIENT_B_STORAGE_STATE: manifest.states.clientB.path,
    E2E_COMPLIANCE_STORAGE_STATE: manifest.states.centralAal2.path,
    E2E_COMPLIANCE_AAL1_STORAGE_STATE: manifest.states.centralAal1.path,
    E2E_NO_ROLE_STORAGE_STATE: manifest.states.noRole.path,
  });
  const child = spawn(process.execPath, [
    resolve(root, "node_modules", "@playwright", "test", "cli.js"),
    "test",
    "tests/e2e/v1-critical-flows.spec.ts",
    "tests/e2e/p20-admin-diagnostics-authenticated.spec.ts",
    "--workers=1",
    "--reporter=line",
    "--output",
    output,
  ], { cwd: root, env: environment, stdio: ["ignore", "inherit", "inherit"], shell: false });
  const exitCode = await new Promise((resolveExit, reject) => {
    child.once("error", reject);
    child.once("exit", (code, signal) => signal
      ? reject(new Error("V1 critical-flow Playwright run was interrupted"))
      : resolveExit(code ?? 1));
  });
  if (exitCode !== 0) throw new Error("V1 critical-flow Playwright suite failed");
  console.log("PASS V1 critical-flow E2E suite");
} catch (error) {
  failure = error;
} finally {
  if (fixture) {
    try {
      await fixture.cleanup();
      if (fixture.resources.retainedEvidence <= 0) throw new Error("Immutable fixture evidence was not retained");
      console.log("PASS V1 critical-flow remote fixture neutralized");
    } catch (error) {
      failure = failure
        ? new AggregateError([failure, error], "V1 critical-flow run and cleanup failed")
        : error;
    }
    try {
      const fixtureAuthDirectory = resolve(dirname(fixture.manifestPath));
      const expectedFixtureAuthDirectory = resolve(root, "scripts", "p05-e2e", ".auth");
      if (fixtureAuthDirectory !== expectedFixtureAuthDirectory) throw new Error("Refusing to remove an unverified P05 auth directory");
      await rm(fixtureAuthDirectory, { recursive: true, force: true });
    } catch (error) {
      failure = failure
        ? new AggregateError([failure, error], "V1 critical-flow run and local auth cleanup failed")
        : error;
    }
  }
  try { await rm(output, { recursive: true, force: true }); }
  catch (error) { failure ??= error; }
  try { await rm(authSnapshotDirectory, { recursive: true, force: true }); }
  catch (error) { failure ??= error; }
}

if (failure) {
  console.error("FAIL V1 critical-flow E2E execution failed; no credential or remote detail was printed");
  process.exitCode = 1;
}
