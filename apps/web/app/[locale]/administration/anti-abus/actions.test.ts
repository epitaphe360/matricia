import { createHash } from "node:crypto";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ getUser: vi.fn(), rpc: vi.fn() }));
vi.mock("@/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, rpc: mocks.rpc }) }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));

import { decideCase, type State } from "./actions";

const idle: State = { status: "idle" };
const caseId = "11111111-1111-4111-8111-111111111111";
const key = "22222222-2222-4222-8222-222222222222";

beforeEach(() => {
  mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id: "reviewer" } } });
  mocks.rpc.mockReset().mockResolvedValue({ data: null, error: null });
});

describe("anti-abuse actions", () => {
  it("construit une preuve canonique de la décision côté serveur", async () => {
    const form = new FormData();
    form.set("locale", "fr"); form.set("caseId", caseId); form.set("rowVersion", "3");
    form.set("decision", "BLOCKED"); form.set("reason", "Signaux confirmés par la revue humaine"); form.set("key", key);
    await expect(decideCase(idle, form)).resolves.toEqual({ status: "success" });
    const expected = createHash("sha256").update(JSON.stringify({ caseId, rowVersion: 3, decision: "BLOCKED", reason: "Signaux confirmés par la revue humaine" })).digest("hex");
    expect(mocks.rpc).toHaveBeenCalledWith("decide_abuse_case", expect.objectContaining({ p_case_id: caseId, p_expected_row_version: 3, p_evidence_hash: expected, p_idempotency_key: key }));
  });

  it("rejette une décision incomplète avant le RPC", async () => {
    const form = new FormData();
    form.set("locale", "fr"); form.set("caseId", caseId); form.set("rowVersion", "3"); form.set("decision", "BLOCKED"); form.set("reason", "court"); form.set("key", key);
    await expect(decideCase(idle, form)).resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
});
