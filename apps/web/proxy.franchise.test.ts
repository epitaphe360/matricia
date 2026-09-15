import { NextRequest } from "next/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const getUser = vi.hoisted(() => vi.fn());
vi.mock("@supabase/ssr", () => ({
  createServerClient: () => ({ auth: { getUser } }),
}));
vi.mock("@/lib/env", () => ({
  getPublicEnvironment: () => ({
    NEXT_PUBLIC_SUPABASE_URL: "https://supabase.example.invalid",
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "public-test-key",
  }),
}));
vi.mock("@/lib/i18n/locale", () => ({
  normalizeLocale: (value: string) => value === "ar" ? "ar" : "fr",
}));

import { refreshSupabaseSession } from "./lib/supabase/proxy";

function request(pathname: string) {
  return new NextRequest(new URL(pathname, "https://matricia.example.invalid"));
}

beforeEach(() => getUser.mockReset());

describe("proxy franchise routing", () => {
  it.each(["/fr/diagnostic", "/ar/besoin", "/fr/fournisseur", "/ar/abonnements"])("laisse le parcours public %s accessible sans session", async (pathname) => {
    getUser.mockResolvedValue({ data: { user: null } });
    const response = await refreshSupabaseSession(request(pathname));
    expect(response.status).toBe(200);
    expect(response.headers.get("location")).toBeNull();
    expect(getUser).not.toHaveBeenCalled();
  });

  it("laisse la page franchise publique accessible sans session", async () => {
    getUser.mockResolvedValue({ data: { user: null } });
    const response = await refreshSupabaseSession(request("/fr/franchise"));
    expect(response.status).toBe(200);
    expect(response.headers.get("location")).toBeNull();
  });

  it("redirige le digest franchise privé sans session", async () => {
    getUser.mockResolvedValue({ data: { user: null } });
    const response = await refreshSupabaseSession(request("/ar/franchise/digest"));
    expect(response.status).toBe(307);
    expect(response.headers.get("location")).toBe("https://matricia.example.invalid/ar/connexion");
  });

  it("laisse passer une route franchise authentifiée et fixe la locale", async () => {
    getUser.mockResolvedValue({ data: { user: { id: "authenticated-user" } } });
    const response = await refreshSupabaseSession(request("/ar/franchise/digest"));
    expect(response.status).toBe(200);
    expect(response.cookies.get("matricia_locale")?.value).toBe("ar");
  });

});
