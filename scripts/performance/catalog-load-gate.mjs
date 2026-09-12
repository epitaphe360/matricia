#!/usr/bin/env node

/**
 * Read-only catalogue load gate for verified development/staging Supabase targets.
 * The module is dependency-free so the exact same command can run in CI.
 */

const ALLOWED_ENVIRONMENTS = new Set(["development", "staging"]);
const DEFAULT_SIZES = [6_000, 50_000];
const SAFE_RESOURCE = /^[a-z][a-z0-9_]{0,62}$/;
const SAFE_COLUMN = /^[a-z][a-z0-9_]{0,62}$/;

export class ConfigurationError extends Error {
  constructor(message) {
    super(message);
    this.name = "ConfigurationError";
  }
}

export function parsePositiveInteger(value, name, { maximum = Number.MAX_SAFE_INTEGER } = {}) {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0 || parsed > maximum) {
    throw new ConfigurationError(`${name} must be a positive integer no greater than ${maximum}`);
  }
  return parsed;
}

export function extractProjectRef(url) {
  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    throw new ConfigurationError("SUPABASE_URL must be a valid HTTPS URL");
  }
  if (parsed.protocol !== "https:") {
    throw new ConfigurationError("SUPABASE_URL must use HTTPS");
  }
  const suffix = ".supabase.co";
  if (!parsed.hostname.endsWith(suffix)) {
    throw new ConfigurationError("SUPABASE_URL must be a hosted Supabase project URL");
  }
  const projectRef = parsed.hostname.slice(0, -suffix.length);
  if (!/^[a-z0-9]{8,40}$/.test(projectRef)) {
    throw new ConfigurationError("SUPABASE_URL does not contain a valid project reference");
  }
  return projectRef;
}

export function validateConfiguration(env) {
  const environment = String(env.MATRICIA_PERF_ENV ?? "").trim().toLowerCase();
  if (!ALLOWED_ENVIRONMENTS.has(environment)) {
    throw new ConfigurationError("MATRICIA_PERF_ENV must be development or staging; production is refused");
  }

  const url = String(env.SUPABASE_URL ?? "").trim();
  const projectRef = extractProjectRef(url);
  const expectedProjectRef = String(env.MATRICIA_PERF_EXPECTED_PROJECT_REF ?? "").trim();
  if (!expectedProjectRef || expectedProjectRef !== projectRef) {
    throw new ConfigurationError("Verified target mismatch: expected project reference must exactly match SUPABASE_URL");
  }

  const productionProjectRef = String(env.MATRICIA_PRODUCTION_PROJECT_REF ?? "").trim();
  if (productionProjectRef && productionProjectRef === projectRef) {
    throw new ConfigurationError("Production Supabase project is refused");
  }

  const apiKey = String(env.SUPABASE_ANON_KEY ?? "").trim();
  if (!apiKey) {
    throw new ConfigurationError("SUPABASE_ANON_KEY is required");
  }

  const resource = String(env.MATRICIA_PERF_RESOURCE ?? "catalog_questions_perf").trim();
  const keyColumn = String(env.MATRICIA_PERF_KEY_COLUMN ?? "id").trim();
  if (!SAFE_RESOURCE.test(resource)) throw new ConfigurationError("MATRICIA_PERF_RESOURCE is invalid");
  if (!SAFE_COLUMN.test(keyColumn)) throw new ConfigurationError("MATRICIA_PERF_KEY_COLUMN is invalid");

  const pageSize = parsePositiveInteger(env.MATRICIA_PERF_PAGE_SIZE ?? 500, "MATRICIA_PERF_PAGE_SIZE", { maximum: 1_000 });
  const timeoutMs = parsePositiveInteger(env.MATRICIA_PERF_TIMEOUT_MS ?? 15_000, "MATRICIA_PERF_TIMEOUT_MS", { maximum: 120_000 });
  const maxP95Ms = parsePositiveInteger(env.MATRICIA_PERF_MAX_P95_MS ?? 1_500, "MATRICIA_PERF_MAX_P95_MS", { maximum: 120_000 });
  const sizes = String(env.MATRICIA_PERF_SIZES ?? DEFAULT_SIZES.join(","))
    .split(",")
    .map((item) => parsePositiveInteger(item.trim(), "MATRICIA_PERF_SIZES", { maximum: 50_000 }));
  if (new Set(sizes).size !== sizes.length) throw new ConfigurationError("MATRICIA_PERF_SIZES contains duplicates");

  return { environment, url, projectRef, apiKey, resource, keyColumn, pageSize, timeoutMs, maxP95Ms, sizes };
}

function percentile(values, ratio) {
  if (values.length === 0) return 0;
  const ordered = [...values].sort((a, b) => a - b);
  return ordered[Math.min(ordered.length - 1, Math.ceil(ordered.length * ratio) - 1)];
}

function elapsedMs(startNs, nowNs) {
  return Number(nowNs - startNs) / 1_000_000;
}

function makeHeaders(apiKey) {
  return Object.freeze({ apikey: apiKey, Authorization: `Bearer ${apiKey}`, Accept: "application/json" });
}

export async function runScenario(config, targetRows, dependencies = {}) {
  const fetchImpl = dependencies.fetchImpl ?? globalThis.fetch;
  const now = dependencies.now ?? (() => process.hrtime.bigint());
  if (typeof fetchImpl !== "function") throw new ConfigurationError("A fetch implementation is required");

  const requestDurationsMs = [];
  const startedAt = now();
  let lastKey;
  let rowsRead = 0;
  let pages = 0;

  while (rowsRead < targetRows) {
    const limit = Math.min(config.pageSize, targetRows - rowsRead);
    const endpoint = new URL(`/rest/v1/${config.resource}`, config.url);
    endpoint.searchParams.set("select", config.keyColumn);
    endpoint.searchParams.set("order", `${config.keyColumn}.asc`);
    endpoint.searchParams.set("limit", String(limit));
    if (lastKey !== undefined) endpoint.searchParams.set(config.keyColumn, `gt.${lastKey}`);

    const requestStartedAt = now();
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), config.timeoutMs);
    let response;
    try {
      response = await fetchImpl(endpoint, {
        method: "GET",
        headers: makeHeaders(config.apiKey),
        signal: controller.signal,
        redirect: "error",
      });
    } finally {
      clearTimeout(timeout);
    }
    requestDurationsMs.push(elapsedMs(requestStartedAt, now()));
    if (!response.ok) throw new Error(`Catalogue read failed with HTTP ${response.status}`);

    const page = await response.json();
    if (!Array.isArray(page)) throw new Error("Catalogue response must be an array");
    if (page.length > limit) throw new Error("Catalogue response exceeded the requested bound");
    if (page.length === 0) break;

    for (const row of page) {
      if (!row || !(config.keyColumn in row)) throw new Error("Catalogue response omitted the keyset column");
    }
    const nextKey = page.at(-1)[config.keyColumn];
    if (lastKey !== undefined && String(nextKey) <= String(lastKey)) {
      throw new Error("Catalogue keyset did not advance");
    }
    lastKey = nextKey;
    rowsRead += page.length;
    pages += 1;
    if (page.length < limit) break;
  }

  const durationMs = elapsedMs(startedAt, now());
  const p95Ms = percentile(requestDurationsMs, 0.95);
  return {
    targetRows,
    rowsRead,
    pages,
    pageSize: config.pageSize,
    durationMs: Number(durationMs.toFixed(2)),
    requestP95Ms: Number(p95Ms.toFixed(2)),
    throughputRowsPerSecond: durationMs > 0 ? Number(((rowsRead * 1_000) / durationMs).toFixed(2)) : 0,
    complete: rowsRead === targetRows,
    passed: rowsRead === targetRows && p95Ms <= config.maxP95Ms,
  };
}

export async function runGate(config, dependencies = {}) {
  const scenarios = [];
  for (const size of config.sizes) scenarios.push(await runScenario(config, size, dependencies));
  return {
    schemaVersion: 1,
    gate: "catalog-keyset-read",
    environment: config.environment,
    targetVerified: true,
    readOnly: true,
    generatedAt: new Date().toISOString(),
    thresholds: { requestP95Ms: config.maxP95Ms },
    scenarios,
    passed: scenarios.every((scenario) => scenario.passed),
  };
}

function sanitizeError(error) {
  if (error instanceof ConfigurationError) return { type: error.name, message: error.message };
  return { type: "GateError", message: "Catalogue performance gate failed; inspect server logs without exposing credentials" };
}

async function main() {
  try {
    const config = validateConfiguration(process.env);
    const result = await runGate(config);
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    process.exitCode = result.passed ? 0 : 1;
  } catch (error) {
    process.stdout.write(`${JSON.stringify({ schemaVersion: 1, gate: "catalog-keyset-read", passed: false, error: sanitizeError(error) }, null, 2)}\n`);
    process.exitCode = 1;
  }
}

const invokedPath = process.argv[1] ? new URL(`file:///${process.argv[1].replaceAll("\\", "/")}`).href : "";
if (import.meta.url === invokedPath) await main();

