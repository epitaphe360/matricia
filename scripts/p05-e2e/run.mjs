import { spawn } from "node:child_process";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { loadSafeConfiguration } from "./environment.mjs";
import { provision } from "./provision.mjs";
import { buildChildEnvironment, validateFreshManifest } from "./security.mjs";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const root = resolve(scriptDirectory, "..", "..");
const authDirectory = resolve(scriptDirectory, ".auth");
const playwrightMarkerPath = resolve(root, "artifacts", "test-results", "playwright", ".last-run.json");
const evidencePath = resolve(root, "docs", "evidence", "p05", "authenticated-e2e-last-run.json");
const EXPECTED_P05_TESTS = 28;

export function validatePlaywrightReport(report) {
  const stats = report?.stats;
  if (!stats || stats.expected !== EXPECTED_P05_TESTS
      || stats.unexpected !== 0 || stats.flaky !== 0 || stats.skipped !== 0) {
    throw new Error(`P05 Playwright JSON report must contain exactly ${EXPECTED_P05_TESTS} expected tests with zero skipped, flaky, or unexpected results`);
  }
  return stats.expected;
}

export function combineRunAndCleanupErrors(runError, cleanupError) {
  if (!runError) return cleanupError;
  if (!cleanupError) return runError;
  return new AggregateError(
    [runError, cleanupError],
    "P05 authenticated E2E execution and remote fixture cleanup both failed",
    { cause: runError },
  );
}

export async function removeLocalArtifacts(paths, remove = rm) {
  const failures = [];
  for (const path of paths) {
    try { await remove(path, { recursive: true, force: true }); }
    catch (error) { failures.push(new Error("P05 E2E local artifact cleanup failed", { cause: error })); }
  }
  if (failures.length > 0) throw new AggregateError(failures, "P05 E2E local artifact cleanup did not complete");
}

async function run() {
  let fixture;
  let runError;
  let sanitizedEvidence;
  try {
    fixture = await provision();
    const config = await loadSafeConfiguration(root);
    await validateFreshManifest(fixture.manifest, config);
    const resultPath = resolve(authDirectory, "playwright-result.json");
    const environment = buildChildEnvironment(process.env, {
      E2E_BASE_URL: config.baseUrl,
      E2E_P05_MANIFEST: fixture.manifestPath,
      E2E_CLIENT_STORAGE_STATE: fixture.manifest.states.clientA.path,
      E2E_CLIENT_B_STORAGE_STATE: fixture.manifest.states.clientB.path,
      E2E_COMPLIANCE_STORAGE_STATE: fixture.manifest.states.centralAal2.path,
      E2E_COMPLIANCE_AAL1_STORAGE_STATE: fixture.manifest.states.centralAal1.path,
      E2E_NO_ROLE_STORAGE_STATE: fixture.manifest.states.noRole.path,
      PLAYWRIGHT_JSON_OUTPUT_FILE: resultPath,
    });
    const child = spawn(process.execPath, [resolve(root, "node_modules", "@playwright", "test", "cli.js"),
      "test", "tests/e2e/p05-client-compliance.spec.ts", "--reporter=json"], {
      cwd: root, env: environment, stdio: ["ignore", "inherit", "inherit"], shell: false,
    });
    const exitCode = await new Promise((resolveExit, reject) => {
      child.once("error", reject);
      child.once("exit", (code, signal) => signal ? reject(new Error("Playwright was interrupted")) : resolveExit(code ?? 1));
    });
    if (exitCode !== 0) throw new Error("Authenticated P05 Playwright suite failed");
    const report = JSON.parse(await readFile(resultPath, "utf8"));
    const passed = validatePlaywrightReport(report);
    sanitizedEvidence = {
      schemaVersion: 1,
      completedAt: new Date().toISOString(),
      environment: config.environment,
      projectRef: config.projectRef,
      result: { expected: passed, skipped: 0, flaky: 0, unexpected: 0 },
      projects: ["chromium-mobile-360", "chromium-desktop"],
      locales: ["fr", "ar"],
      viewports: ["360x800", "desktop"],
      cleanup: "VERIFIED",
    };
    console.log(`PASS P05 authenticated E2E suite (${passed} tests, zero skipped)`);
  } catch (error) {
    runError = error;
  } finally {
    if (fixture) {
      try {
        await fixture.cleanup();
        if (fixture.resources.retainedEvidence <= 0) throw new Error("Immutable fixture evidence was not retained");
        console.log("PASS P05 remote fixture neutralized; immutable evidence retained");
      } catch (error) {
        runError = combineRunAndCleanupErrors(runError, error);
      }
    }
    try { await removeLocalArtifacts([authDirectory, playwrightMarkerPath]); }
    catch (error) { runError = combineRunAndCleanupErrors(runError, error); }
  }
  if (runError) throw runError;
  await mkdir(dirname(evidencePath), { recursive: true });
  await writeFile(evidencePath, `${JSON.stringify(sanitizedEvidence, null, 2)}\n`, { encoding: "utf8" });
  console.log("PASS P05 sanitized E2E evidence persisted after verified cleanup");
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { await run(); }
  catch { console.error("FAIL P05 authenticated E2E execution failed; no credential or remote detail was printed"); process.exitCode = 1; }
}
