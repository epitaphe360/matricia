import assert from "node:assert/strict";
import { mkdir, rm, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import test from "node:test";
import { buildChildEnvironment, secureLocalPaths, sha256File, validateFreshManifest, validateWindowsAclOutput } from "./security.mjs";

test("passes only explicitly allowed process keys and E2E additions", () => {
  const result = buildChildEnvironment({ PATH: "safe", SUPABASE_SERVICE_ROLE_KEY: "secret", RANDOM_KEY: "hidden" }, { E2E_BASE_URL: "http://localhost:5173" });
  assert.deepEqual(result, { PATH: "safe", E2E_BASE_URL: "http://localhost:5173" });
  assert.throws(() => buildChildEnvironment({}, { SUPABASE_SERVICE_ROLE_KEY: "forbidden" }), /Unsafe/);
});

test("accepts only a fresh manifest bound to exact state hashes", async () => {
  const directory = resolve(import.meta.dirname, ".auth-unit");
  await rm(directory, { recursive: true, force: true });
  await mkdir(directory);
  try {
    const states = {};
    for (const key of ["clientA", "clientB", "centralAal1", "centralAal2", "noRole"]) {
      const path = resolve(directory, `${key}.json`);
      await writeFile(path, "{}\n");
      states[key] = { path, sha256: await sha256File(path) };
    }
    const now = Date.now();
    const config = { environment: "development", projectRef: "abcdefghijklmnopqrst", baseUrl: "http://localhost:5173" };
    const manifest = { schemaVersion: 1, environment: config.environment, projectRef: config.projectRef, baseUrl: config.baseUrl, runId: "12345678", createdAt: new Date(now).toISOString(), expiresAt: new Date(now + 300_000).toISOString(), states };
    await assert.doesNotReject(() => validateFreshManifest(manifest, config, now));
    await assert.rejects(() => validateFreshManifest({ ...manifest, projectRef: "different" }, config, now), /mismatch/);
    await writeFile(states.clientA.path, "tampered\n");
    await assert.rejects(() => validateFreshManifest(manifest, config, now), /integrity/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("secures local paths with the real host ACL implementation", async () => {
  const directory = resolve(import.meta.dirname, ".auth-acl-unit");
  const file = resolve(directory, "state.json");
  await rm(directory, { recursive: true, force: true });
  await mkdir(directory);
  await writeFile(file, "{}\n");
  try {
    await assert.doesNotReject(() => secureLocalPaths(directory, [file]));
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("Windows ACL branch applies directory and file ACLs and fails closed", async () => {
  const calls = [];
  const owner = { name: "test-user", sid: "S-1-5-21-1" };
  await secureLocalPaths("auth", ["one", "two"], {
    platform: "win32",
    windowsIdentity: async () => owner,
    setWindowsAcl: async (...args) => { calls.push(args); },
  });
  assert.deepEqual(calls, [["auth", owner, true], ["one", owner, false], ["two", owner, false]]);
  await assert.rejects(() => secureLocalPaths("auth", [], {
    platform: "win32",
    windowsIdentity: async () => owner,
    setWindowsAcl: async () => { throw new Error("ACL verification failed"); },
  }), /ACL verification failed/);
});

test("Windows ACL parser rejects any additional explicit or inherited ACE", () => {
  const owner = { name: "DOMAIN\\owner", sid: "S-1-5-21-1" };
  const expected = "C:\\auth DOMAIN\\owner:(F)\r\n          NT AUTHORITY\\SYSTEM:(F)\r\nSuccessfully processed 1 files\r\n";
  assert.doesNotThrow(() => validateWindowsAclOutput(expected, owner));
  assert.throws(() => validateWindowsAclOutput(`${expected}          BUILTIN\\Users:(R)\r\n`, owner), /Windows ACL verification failed/);
  assert.throws(() => validateWindowsAclOutput("C:\\auth DOMAIN\\owner:(F)\r\n          NT AUTHORITY\\SYSTEM:(I)(F)\r\n", owner), /Windows ACL verification failed/);
  assert.throws(() => validateWindowsAclOutput("C:\\auth DOMAIN\\owner:(F)\r\n          BUILTIN\\Administrators:(M)\r\n", owner), /Windows ACL verification failed/);
  assert.throws(() => validateWindowsAclOutput("C:\\auth DOMAIN\\owner:(F)\r\n          DOMAIN\\attacker:(F)\r\n", owner), /Windows ACL verification failed/);
  assert.doesNotThrow(() => validateWindowsAclOutput("C:\\auth DOMAIN\\owner:(F)\r\n          AUTORITE NT\\Système:(F)\r\n", owner));
});

test("POSIX permission branch verifies exact modes and fails closed", async () => {
  const chmodCalls = [];
  const modes = new Map([["auth", 0o40700], ["state", 0o100600]]);
  await secureLocalPaths("auth", ["state"], {
    platform: "linux",
    chmod: async (...args) => { chmodCalls.push(args); },
    stat: async (path) => ({ mode: modes.get(path) }),
  });
  assert.deepEqual(chmodCalls, [["auth", 0o700], ["state", 0o600]]);
  await assert.rejects(() => secureLocalPaths("auth", ["state"], {
    platform: "linux",
    chmod: async () => {},
    stat: async (path) => ({ mode: path === "auth" ? 0o40755 : 0o100600 }),
  }), /POSIX permissions verification failed/);
});
