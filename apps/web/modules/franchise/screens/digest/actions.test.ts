import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ getUser: vi.fn(), rpc: vi.fn(), revalidatePath: vi.fn() }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidatePath }));
vi.mock("@/modules/shared/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, rpc: mocks.rpc }) }));
vi.mock("@/modules/shared/lib/i18n/locale", () => ({ isLocale: (value: string) => value === "fr" || value === "ar" }));
vi.mock("@/modules/franchise/data/digest/model", async () => await import("@/modules/franchise/data/digest/model"));

import { configureDigest, type FranchiseDigestActionState } from "./actions";

const userId = "11111111-1111-4111-8111-111111111111", franchiseId = "22222222-2222-4222-8222-222222222222", key = "33333333-3333-4333-8333-333333333333", idle: FranchiseDigestActionState = { status: "idle" };
function form() { const value = new FormData(); Object.entries({ uiLocale: "fr", franchiseId, recipientUserId: userId, enabled: "on", frequency: "WEEKDAYS", localSendTime: "08:30", timeZone: "Africa/Casablanca", notificationLocale: "fr-MA", changeReason: "Mise à jour quotidienne", idempotencyKey: key }).forEach(([name, content]) => value.set(name, content)); return value; }

beforeEach(() => { mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id: userId } } }); mocks.rpc.mockReset().mockResolvedValue({ data: { outcome: "FRANCHISE_DAILY_DIGEST_CONFIGURED" }, error: null }); mocks.revalidatePath.mockReset(); });
describe("franchise digest action", () => {
  it("uses only the versioned canonical configuration RPC", async () => { await configureDigest(idle, form()); expect(mocks.rpc).toHaveBeenCalledTimes(1); expect(mocks.rpc).toHaveBeenCalledWith("configure_franchise_daily_digest", { p_franchise_id: franchiseId, p_recipient_user_id: userId, p_enabled: true, p_frequency: "WEEKDAYS", p_local_send_time: "08:30", p_time_zone: "Africa/Casablanca", p_locale: "fr-MA", p_change_reason: "Mise à jour quotidienne", p_idempotency_key: key }); expect(mocks.revalidatePath).toHaveBeenCalledWith("/fr/franchise/digest"); });
  it("rejects attempts to configure another recipient before RPC", async () => { const value = form(); value.set("recipientUserId", franchiseId); expect(await configureDigest(idle, value)).toEqual({ status: "error", reason: "FORBIDDEN" }); expect(mocks.rpc).not.toHaveBeenCalled(); });
  it("rejects malformed inputs before RPC", async () => { const value = form(); value.set("localSendTime", "28:90"); expect(await configureDigest(idle, value)).toEqual({ status: "error", reason: "VALIDATION" }); expect(mocks.rpc).not.toHaveBeenCalled(); });
  it("maps SQL scope denial without leaking backend details", async () => { mocks.rpc.mockResolvedValue({ data: null, error: { code: "42501", message: "FRANCHISE_DIGEST_CONFIG_ACTOR_SCOPE_DENIED" } }); expect(await configureDigest(idle, form())).toEqual({ status: "error", reason: "FORBIDDEN" }); });
});
