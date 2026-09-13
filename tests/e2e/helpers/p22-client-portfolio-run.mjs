import { spawn } from "node:child_process";
import { rm } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { loadSafeConfiguration } from "../../../scripts/p05-e2e/environment.mjs";
import { provision } from "../../../scripts/p05-e2e/provision.mjs";
import { buildChildEnvironment, validateFreshManifest } from "../../../scripts/p05-e2e/security.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");
const output = resolve(root, "artifacts", "test-results", "p22-client-portfolio");
let fixture; let failure;
try {
  fixture = await provision();
  const config = await loadSafeConfiguration(root);
  await validateFreshManifest(fixture.manifest, config);
  const env = buildChildEnvironment(process.env, { E2E_BASE_URL: config.baseUrl, E2E_CLIENT_STORAGE_STATE: fixture.manifest.states.clientA.path, E2E_FOREIGN_ORGANIZATION_NAME: fixture.manifest.fixtures.organizationB.name });
  const child = spawn(process.execPath, [resolve(root, "node_modules", "@playwright", "test", "cli.js"), "test", "tests/e2e/p22-client-portfolio.spec.ts", "--workers=1", "--reporter=line", "--output", output], { cwd: root, env, stdio: ["ignore", "inherit", "inherit"], shell: false });
  const code = await new Promise((resolveExit, reject) => { child.once("error", reject); child.once("exit", (value, signal) => signal ? reject(new Error("P22 Playwright run was interrupted")) : resolveExit(value ?? 1)); });
  if (code !== 0) throw new Error("P22 Client portfolio Playwright suite failed");
  console.log("PASS P22 Client portfolio E2E suite");
} catch (error) { failure = error; }
finally {
  if (fixture) try { await fixture.cleanup(); if (fixture.resources.retainedEvidence <= 0) throw new Error("Immutable fixture evidence was not retained"); console.log("PASS P22 remote fixture neutralized"); } catch (error) { failure = failure ? new AggregateError([failure, error], "P22 run and cleanup failed") : error; }
  try { await rm(output, { recursive: true, force: true }); } catch (error) { failure ??= error; }
}
if (failure) { console.error("FAIL P22 authenticated E2E execution failed; no credential or remote detail was printed"); process.exitCode = 1; }
