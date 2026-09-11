import assert from "node:assert/strict";
import test from "node:test";
import { decodeBase32, totp } from "./totp.mjs";

test("matches the RFC 6238 SHA-1 vector", () => {
  assert.equal(totp("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", 59_000, 8), "94287082");
});

test("rejects malformed secrets", () => {
  assert.throws(() => decodeBase32("invalid!"), /Invalid TOTP/);
});
