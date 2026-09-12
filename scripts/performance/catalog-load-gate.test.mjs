import assert from "node:assert/strict";
import test from "node:test";

import {
  ConfigurationError,
  extractProjectRef,
  runGate,
  runScenario,
  validateConfiguration,
} from "./catalog-load-gate.mjs";

const PROJECT_REF = "abcdefghijklmnopqrst";

function validEnvironment(overrides = {}) {
  return {
    MATRICIA_PERF_ENV: "staging",
    SUPABASE_URL: `https://${PROJECT_REF}.supabase.co`,
    MATRICIA_PERF_EXPECTED_PROJECT_REF: PROJECT_REF,
    SUPABASE_ANON_KEY: "test-only-key",
    MATRICIA_PERF_RESOURCE: "catalog_questions_perf",
    MATRICIA_PERF_SIZES: "4",
    MATRICIA_PERF_PAGE_SIZE: "2",
    ...overrides,
  };
}

function response(body, status = 200) {
  return { ok: status >= 200 && status < 300, status, json: async () => body };
}

test("extractProjectRef accepts only hosted HTTPS Supabase targets", () => {
  assert.equal(extractProjectRef(`https://${PROJECT_REF}.supabase.co`), PROJECT_REF);
  assert.throws(() => extractProjectRef("http://example.test"), ConfigurationError);
});

test("configuration refuses production and requires exact target verification", () => {
  assert.throws(() => validateConfiguration(validEnvironment({ MATRICIA_PERF_ENV: "production" })), /production is refused/);
  assert.throws(() => validateConfiguration(validEnvironment({ MATRICIA_PERF_EXPECTED_PROJECT_REF: "differentprojectref" })), /target mismatch/i);
  assert.throws(() => validateConfiguration(validEnvironment({ MATRICIA_PRODUCTION_PROJECT_REF: PROJECT_REF })), /Production Supabase project is refused/);
});

test("configuration bounds page size and scenario sizes", () => {
  assert.throws(() => validateConfiguration(validEnvironment({ MATRICIA_PERF_PAGE_SIZE: "1001" })), /no greater than 1000/);
  assert.throws(() => validateConfiguration(validEnvironment({ MATRICIA_PERF_SIZES: "50001" })), /no greater than 50000/);
});

test("scenario uses bounded keyset GET requests and emits metrics only", async () => {
  const config = validateConfiguration(validEnvironment());
  const seen = [];
  const pages = [[{ id: "a" }, { id: "b" }], [{ id: "c" }, { id: "d" }]];
  let tick = 0n;
  const result = await runScenario(config, 4, {
    now: () => (tick += 1_000_000n),
    fetchImpl: async (url, options) => {
      seen.push({ url: String(url), options });
      return response(pages.shift());
    },
  });

  assert.equal(result.passed, true);
  assert.equal(result.rowsRead, 4);
  assert.equal(seen.length, 2);
  assert.equal(seen[0].options.method, "GET");
  assert.match(seen[0].url, /select=id/);
  assert.match(seen[0].url, /limit=2/);
  const firstQuery = new URL(seen[0].url).searchParams;
  assert.equal(firstQuery.get("select"), "id");
  assert.doesNotMatch(firstQuery.get("select"), /question|label|content/);
  assert.match(seen[1].url, /id=gt.b/);
  assert.equal(JSON.stringify(result).includes("test-only-key"), false);
  assert.equal(JSON.stringify(result).includes("abcdefghijklmnopqrst"), false);
});

test("scenario fails closed when the keyset does not advance", async () => {
  const config = validateConfiguration(validEnvironment());
  const pages = [[{ id: "b" }, { id: "c" }], [{ id: "a" }, { id: "a" }]];
  await assert.rejects(
    runScenario(config, 4, { fetchImpl: async () => response(pages.shift()) }),
    /keyset did not advance/,
  );
});

test("gate is failed when the target row count is unavailable", async () => {
  const config = validateConfiguration(validEnvironment());
  const result = await runGate(config, { fetchImpl: async () => response([]) });
  assert.equal(result.readOnly, true);
  assert.equal(result.targetVerified, true);
  assert.equal(result.passed, false);
  assert.equal(result.scenarios[0].complete, false);
});
