import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  getUser: vi.fn(),
  getClaims: vi.fn(),
  rpc: vi.fn(),
  revalidatePath: vi.fn(),
}));

vi.mock("@/modules/shared/lib/supabase/server", () => ({
  getSupabaseServerClient: async () => ({
    auth: { getUser: mocks.getUser, getClaims: mocks.getClaims },
    rpc: mocks.rpc,
  }),
}));
vi.mock("@/modules/shared/lib/i18n/locale", () => ({
  isLocale: (value: string) => value === "fr" || value === "ar",
}));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidatePath }));
vi.mock("node:crypto", () => ({ randomUUID: () => "33333333-3333-4333-8333-333333333333" }));

import { listMySessions, revokeMySession, type RevokeSessionState } from "./actions";

const currentSessionId = "11111111-1111-4111-8111-111111111111";
const otherSessionId = "22222222-2222-4222-8222-222222222222";
const idle: RevokeSessionState = { status: "idle" };

function revokeForm(overrides: Record<string, string> = {}) {
  const form = new FormData();
  const values = { sessionId: otherSessionId, locale: "fr", confirmed: "yes", ...overrides };
  for (const [key, value] of Object.entries(values)) form.set(key, value);
  return form;
}

describe("session server actions", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.getUser.mockResolvedValue({ data: { user: { id: "user-1" } }, error: null });
    mocks.getClaims.mockResolvedValue({ data: { claims: { session_id: currentSessionId } }, error: null });
  });

  it("refuse la lecture sans authentification avant le RPC", async () => {
    mocks.getUser.mockResolvedValue({ data: { user: null }, error: null });
    await expect(listMySessions()).resolves.toEqual({ status: "error", reason: "UNAUTHENTICATED" });
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("refuse un jeton authentifié sans identifiant de session vérifié", async () => {
    mocks.getClaims.mockResolvedValue({ data: { claims: {} }, error: null });
    await expect(listMySessions()).resolves.toEqual({ status: "error", reason: "UNAUTHENTICATED" });
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("retourne un contrat borné sans adresse IP", async () => {
    mocks.rpc.mockResolvedValue({ data: [{
      id: currentSessionId,
      created_at: "2026-09-11T10:00:00Z",
      updated_at: "2026-09-11T11:00:00Z",
      refreshed_at: null,
      user_agent: `Agent\u0000 ${"x".repeat(300)}`,
      ip: "203.0.113.42",
      not_after: null,
    }], error: null });
    const result = await listMySessions();
    expect(result.status).toBe("success");
    if (result.status !== "success") throw new Error("unexpected result");
    expect(result.sessions[0]).toMatchObject({ id: currentSessionId, isCurrent: true });
    expect(result.sessions[0]?.userAgent?.length).toBeLessThanOrEqual(160);
    expect(JSON.stringify(result)).not.toContain("203.0.113.42");
    expect(JSON.stringify(result)).not.toContain('"ip"');
  });

  it("rejette une réponse RPC inattendue", async () => {
    mocks.rpc.mockResolvedValue({ data: [{ id: "invalid" }], error: null });
    await expect(listMySessions()).resolves.toEqual({ status: "error", reason: "UNAVAILABLE" });
  });

  it("valide UUID et confirmation avant tout accès serveur", async () => {
    await expect(revokeMySession(idle, revokeForm({ sessionId: "invalid", confirmed: "no" }))).resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.getUser).not.toHaveBeenCalled();
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("protège la session courante contre une révocation accidentelle", async () => {
    await expect(revokeMySession(idle, revokeForm({ sessionId: currentSessionId }))).resolves.toEqual({ status: "error", reason: "CURRENT_SESSION" });
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("révoque une autre session avec corrélation puis rafraîchit la route", async () => {
    mocks.rpc.mockResolvedValue({ data: true, error: null });
    await expect(revokeMySession(idle, revokeForm({ locale: "ar" }))).resolves.toEqual({ status: "success" });
    expect(mocks.rpc).toHaveBeenCalledWith("revoke_my_session", {
      p_session_id: otherSessionId,
      p_correlation_id: "33333333-3333-4333-8333-333333333333",
    });
    expect(mocks.revalidatePath).toHaveBeenCalledWith("/ar/securite/sessions");
  });

  it("ne révèle pas si la session ciblée existait", async () => {
    mocks.rpc.mockResolvedValue({ data: false, error: null });
    const result = await revokeMySession(idle, revokeForm());
    expect(result).toEqual({ status: "success" });
    expect(JSON.stringify(result)).not.toContain(otherSessionId);
  });
});
