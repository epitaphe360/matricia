import { spawn } from "node:child_process";
import { rm } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { loadSafeConfiguration } from "../../../scripts/p05-e2e/environment.mjs";
import { provision } from "../../../scripts/p05-e2e/provision.mjs";
import { buildChildEnvironment, validateFreshManifest } from "../../../scripts/p05-e2e/security.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");
const output = resolve(root, "artifacts", "test-results", "p21-questionnaire-diagnostics");
let fixture;
let failure;

try {
  fixture = await provision();
  const config = await loadSafeConfiguration(root);
  await validateFreshManifest(fixture.manifest, config);
  const environment = buildChildEnvironment(process.env, {
    E2E_BASE_URL: config.baseUrl,
    E2E_CLIENT_STORAGE_STATE: fixture.manifest.states.clientA.path,
    E2E_FOREIGN_ORGANIZATION_NAME: fixture.manifest.fixtures.organizationB.name,
  });
  const child = spawn(process.execPath, [
    resolve(root, "node_modules", "@playwright", "test", "cli.js"),
    "test",
    "tests/e2e/p21-questionnaires-diagnostics.spec.ts",
    "--workers=1",
    "--reporter=line",
    "--output",
    output,
  ], { cwd: root, env: environment, stdio: ["ignore", "inherit", "inherit"], shell: false });
  const exitCode = await new Promise((resolveExit, reject) => {
    child.once("error", reject);
    child.once("exit", (code, signal) => signal ? reject(new Error("P21 Playwright run was interrupted")) : resolveExit(code ?? 1));
  });
  if (exitCode !== 0) throw new Error("P21 questionnaire/diagnostics Playwright suite failed");
  console.log("PASS P21 questionnaire/diagnostics E2E suite");
} catch (error) {
  failure = error;
} finally {
  if (fixture) {
    try {
      await fixture.cleanup();
      if (fixture.resources.retainedEvidence <= 0) throw new Error("Immutable fixture evidence was not retained");
      console.log("PASS P21 remote fixture neutralized");
    } catch (error) {
      failure = failure ? new AggregateError([failure, error], "P21 run and cleanup failed") : error;
    }
  }
  try { await rm(output, { recursive: true, force: true }); }
  catch (error) { failure ??= error; }
}

if (failure) {
  console.error("FAIL P21 authenticated E2E execution failed; no credential or remote detail was printed");
  process.exitCode = 1;
}
