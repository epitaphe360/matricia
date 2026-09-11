import { describe, expect, it } from "vitest";
import { canonicalCommandPayload, purgeConfirmedCommandIdentity, resolveCommandIdentity } from "./command-identity";

const first = { idempotencyKey: "11111111-1111-4111-8111-111111111111", correlationId: "22222222-2222-4222-8222-222222222222" };
const second = { idempotencyKey: "33333333-3333-4333-8333-333333333333", correlationId: "44444444-4444-4444-8444-444444444444" };

function memoryStorage() {
  const values = new Map<string, string>();
  return {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => { values.set(key, value); },
    removeItem: (key: string) => { values.delete(key); },
  };
}

describe("catalogue command identity persistence", () => {
  it("canonicalizes payload independently of field order and private command fields", () => {
    const left = new FormData(); left.set("releaseId", "release"); left.set("rowVersion", "2"); left.set("idempotencyKey", "private");
    const right = new FormData(); right.set("rowVersion", "2"); right.set("releaseId", "release"); right.set("confirmed", "yes");
    expect(canonicalCommandPayload(left)).toBe(canonicalCommandPayload(right));
  });
  it("reuses an identity only for the same bounded action payload", () => {
    const storage = memoryStorage();
    expect(resolveCommandIdentity(storage, "CREATE_RELEASE", "[[\"key\",\"A\"]]", first, 100)).toEqual(first);
    expect(resolveCommandIdentity(storage, "CREATE_RELEASE", "[[\"key\",\"A\"]]", second, 200)).toEqual(first);
    expect(resolveCommandIdentity(storage, "CREATE_RELEASE", "[[\"key\",\"B\"]]", second, 300)).toEqual(second);
  });
  it("rejects malformed, stale, future and cross-action entries", () => {
    const storage = memoryStorage();
    resolveCommandIdentity(storage, "CREATE_RELEASE", "[[\"key\",\"A\"]]", first, 100);
    expect(resolveCommandIdentity(storage, "ADD_RELEASE_ITEM", "[[\"key\",\"A\"]]", second, 200)).toEqual(second);
    expect(resolveCommandIdentity(storage, "CREATE_RELEASE", "[[\"key\",\"A\"]]", second, 24 * 60 * 60 * 1_000 + 101)).toEqual(second);
  });
  it("replaces malformed persisted data with a valid bounded entry", () => {
    const storage = memoryStorage();
    storage.setItem("matricia:catalogue-command:v1:CREATE_RELEASE", "{malformed");
    expect(resolveCommandIdentity(storage, "CREATE_RELEASE", "[[\"key\",\"A\"]]", first, 100)).toEqual(first);
    expect(resolveCommandIdentity(storage, "CREATE_RELEASE", "[[\"key\",\"A\"]]", second, 200)).toEqual(first);
  });
  it("purges only the exact confirmed identity", () => {
    const storage = memoryStorage();
    resolveCommandIdentity(storage, "SUBMIT_RELEASE", "[[\"release\",\"A\"]]", first, 100);
    purgeConfirmedCommandIdentity(storage, "SUBMIT_RELEASE", second.idempotencyKey);
    expect(resolveCommandIdentity(storage, "SUBMIT_RELEASE", "[[\"release\",\"A\"]]", second, 200)).toEqual(first);
    purgeConfirmedCommandIdentity(storage, "SUBMIT_RELEASE", first.idempotencyKey);
    expect(resolveCommandIdentity(storage, "SUBMIT_RELEASE", "[[\"release\",\"A\"]]", second, 300)).toEqual(second);
  });
});
