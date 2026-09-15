import { beforeEach, describe, expect, it, vi } from "vitest";
const mocks = vi.hoisted(() => ({ getUser: vi.fn(), rpc: vi.fn() }));
vi.mock("@/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, rpc: mocks.rpc }) }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
import { cloneClauses } from "./actions";
const id = "11111111-1111-4111-8111-111111111111", source = "22222222-2222-4222-8222-222222222222";
beforeEach(() => { mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id } } }); mocks.rpc.mockReset().mockResolvedValue({ data: {}, error: null }); });
describe("clone actions", () => { it("dérive le type et l'identifiant depuis le choix contrôlé", async () => { const f = new FormData(); f.set("locale", "fr"); f.set("sourceSelection", `CONTRACT_VERSION|${source}`); f.set("organizationId", id); f.set("code", "CLAUSES_AUDIT"); f.set("reason", "Réutilisation validée"); f.set("key", id); await expect(cloneClauses({ status: "idle" }, f)).resolves.toEqual({ status: "success" }); expect(mocks.rpc).toHaveBeenCalledWith("clone_contract_clause_set", expect.objectContaining({ p_source_type: "CONTRACT_VERSION", p_source_id: source, p_audit_organization_id: id })); }); });
