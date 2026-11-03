import test from 'node:test';
import assert from 'node:assert/strict';
import { fixtureState, sourceCandidate } from './franchise-final-support.mjs';

test('Franchise browser tooling refuses a production invocation before reading a private state', async () => {
  const saved = process.env.APP_ENV;
  try { process.env.APP_ENV = 'production'; await assert.rejects(fixtureState(), /EXPLICIT_DEVELOPMENT_REQUIRED/); }
  finally { if (saved === undefined) delete process.env.APP_ENV; else process.env.APP_ENV = saved; }
});
test('Franchise browser tooling requires a coordinated invocation even in development', async () => {
  const saved = process.env.APP_ENV;
  try { process.env.APP_ENV = 'development'; await assert.rejects(fixtureState(), /COORDINATED_FRANCHISE_RECIPE_REQUIRED/); }
  finally { if (saved === undefined) delete process.env.APP_ENV; else process.env.APP_ENV = saved; }
});
test('Franchise browser tooling refuses an implicit or missing product candidate', async () => {
  await assert.rejects(sourceCandidate(), /EXPLICIT_INTEGRATED_CANDIDATE_SHA_REQUIRED/);
});
