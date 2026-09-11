import assert from "node:assert/strict";
import test from "node:test";
import { combineRunAndCleanupErrors, removeLocalArtifacts, validatePlaywrightReport } from "./run.mjs";
import { cleanupFailedProvision, cleanupRemote, combineProvisionAndCleanupErrors } from "./provision.mjs";

test("accepts only the complete 28-test Playwright contract with zero skips", () => {
  assert.equal(validatePlaywrightReport({ stats: { expected: 28, unexpected: 0, flaky: 0, skipped: 0 } }), 28);
  assert.throws(() => validatePlaywrightReport({ stats: { expected: 24, unexpected: 0, flaky: 0, skipped: 0 } }), /exactly 28/);
  assert.throws(() => validatePlaywrightReport({ stats: { expected: 27, unexpected: 0, flaky: 0, skipped: 1 } }), /exactly 28/);
  assert.throws(() => validatePlaywrightReport({ stats: { expected: 28, unexpected: 1, flaky: 0, skipped: 0 } }), /exactly 28/);
});

test("preserves both provisioning and cleanup failures", () => {
  const provisionError = new Error("provision failed");
  const cleanupError = new Error("cleanup failed");
  const combined = combineProvisionAndCleanupErrors("fixture setup", provisionError, cleanupError);
  assert.ok(combined instanceof AggregateError);
  assert.deepEqual(combined.errors, [provisionError, cleanupError]);
  assert.equal(combined.cause, provisionError);
});

test("preserves both Playwright and cleanup failures", () => {
  const runError = new Error("Playwright failed");
  const cleanupError = new Error("cleanup failed");
  const combined = combineRunAndCleanupErrors(runError, cleanupError);
  assert.ok(combined instanceof AggregateError);
  assert.deepEqual(combined.errors, [runError, cleanupError]);
  assert.equal(combined.cause, runError);
});

test("cleanup attempts every stage, closes the database, and retains every failure", async () => {
  const calls = [];
  let factorListCalls = 0;
  const resources = { storagePaths: ["object"], userIds: ["user"], retainedEvidence: 0, admin: {}, database: {} };
  const dependencies = {
    removeStorage: async () => { calls.push("storage"); throw new Error("storage"); },
    neutralizeFixture: async () => { calls.push("neutralize"); throw new Error("neutralize"); },
    listFactors: async () => {
      factorListCalls += 1; calls.push(factorListCalls === 1 ? "mfa-list" : "mfa-verify");
      if (factorListCalls === 1) return { error: null, data: { factors: [{ id: "factor" }] } };
      throw new Error("mfa-verify");
    },
    deleteFactor: async () => { calls.push("mfa-delete"); throw new Error("mfa-delete"); },
    disableUser: async () => { calls.push("user-disable"); throw new Error("user-disable"); },
    getUser: async () => { calls.push("user-verify"); throw new Error("user-verify"); },
    verifyNeutralized: async () => { calls.push("database-verify"); throw new Error("database-verify"); },
    closeDatabase: async () => { calls.push("database-close"); throw new Error("database-close"); },
  };
  await assert.rejects(() => cleanupRemote(resources, dependencies), (error) => {
    assert.ok(error instanceof AggregateError);
    assert.equal(error.errors.length, 8);
    return true;
  });
  assert.deepEqual(calls, ["storage", "neutralize", "mfa-list", "mfa-delete", "user-disable", "mfa-verify", "user-verify", "database-verify", "database-close"]);
});

test("cleanup continues after an initial MFA listing failure", async () => {
  const calls = [];
  let factorListCalls = 0;
  const resources = { storagePaths: [], userIds: ["user"], retainedEvidence: 0, admin: {}, database: {} };
  await assert.rejects(() => cleanupRemote(resources, {
    neutralizeFixture: async () => { calls.push("neutralize"); return { retainedEvidence: 1 }; },
    listFactors: async () => {
      factorListCalls += 1; calls.push(factorListCalls === 1 ? "mfa-list" : "mfa-verify");
      if (factorListCalls === 1) throw new Error("mfa-list");
      return { error: null, data: { factors: [] } };
    },
    deleteFactor: async () => { calls.push("unexpected-delete"); },
    disableUser: async () => { calls.push("user-disable"); return { error: null }; },
    getUser: async () => { calls.push("user-verify"); return { error: null, data: { user: { banned_until: "2999-01-01T00:00:00Z" } } }; },
    verifyNeutralized: async () => { calls.push("database-verify"); },
    closeDatabase: async () => { calls.push("database-close"); },
  }), AggregateError);
  assert.deepEqual(calls, ["neutralize", "mfa-list", "user-disable", "mfa-verify", "user-verify", "database-verify", "database-close"]);
  assert.equal(resources.retainedEvidence, 1);
});

test("provision failure still neutralizes remote resources when local auth removal is locked", async () => {
  const calls = [];
  const provisionError = new Error("provision failed");
  const failure = await cleanupFailedProvision("local states", provisionError, {}, {
    removeAuthDirectory: async () => { calls.push("local-remove"); throw new Error("locked"); },
    cleanupResources: async () => { calls.push("remote-cleanup"); },
  });
  assert.ok(failure instanceof AggregateError);
  assert.deepEqual(calls, ["local-remove", "remote-cleanup"]);
  assert.equal(failure.errors[0], provisionError);
  assert.match(failure.errors[1].message, /local-auth-remove/);
});

test("local artifact cleanup attempts every path and retains every failure", async () => {
  const calls = [];
  await assert.rejects(() => removeLocalArtifacts(["auth", "marker"], async (path) => {
    calls.push(path);
    throw new Error(`locked:${path}`);
  }), (error) => {
    assert.ok(error instanceof AggregateError);
    assert.equal(error.errors.length, 2);
    return true;
  });
  assert.deepEqual(calls, ["auth", "marker"]);
});
