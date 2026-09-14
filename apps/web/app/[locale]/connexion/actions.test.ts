import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  rpc: vi.fn(),
  signInWithOtp: vi.fn(),
}));

vi.mock("@/lib/supabase/admin", () => ({
  getSupabaseAdminClient: () => ({ rpc: mocks.rpc, auth: { signInWithOtp: mocks.signInWithOtp } }),
}));
vi.mock("@/lib/auth/otp", () => ({
  normalizeEmail: (value: string) => {
    const normalized = value.trim().toLowerCase();
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized) ? normalized : null;
  },
}));
vi.mock("@/lib/i18n/locale", () => ({
  isLocale: (value: string) => value === "fr" || value === "ar",
}));
vi.mock("@/lib/env", () => ({
  getServerEnvironment: () => ({ NEXT_PUBLIC_APP_URL: "https://app.example.test" }),
}));
vi.mock("next/headers", () => ({
  headers: async () => new Headers({ "x-forwarded-for": "203.0.113.7, 10.0.0.1" }),
}));

import { requestOtp } from "./actions";

describe("requestOtp", () => {
  beforeEach(() => {
    mocks.rpc.mockReset();
    mocks.signInWithOtp.mockReset();
  });

  it("rejette une adresse invalide sans interroger Supabase", async () => {
    await expect(requestOtp("incorrect", "fr")).resolves.toEqual({ accepted: false, reason: "INVALID_EMAIL" });
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("respecte le quota sans révéler la raison au navigateur", async () => {
    mocks.rpc.mockResolvedValue({ data: [{ allowed: false, retry_after_seconds: 60 }], error: null });
    await expect(requestOtp("personne@example.ma", "fr")).resolves.toEqual({ accepted: true });
    expect(mocks.signInWithOtp).not.toHaveBeenCalled();
  });

  it("interdit la création implicite et construit un callback localisé", async () => {
    mocks.rpc.mockResolvedValue({ data: [{ allowed: true, retry_after_seconds: 0 }], error: null });
    mocks.signInWithOtp.mockResolvedValue({ data: {}, error: null });
    await expect(requestOtp(" Personne@Example.ma ", "ar")).resolves.toEqual({ accepted: true });
    expect(mocks.rpc).toHaveBeenCalledWith("reserve_otp_request", {
      p_identifier: "personne@example.ma",
      p_client_ip: "203.0.113.7",
    });
    expect(mocks.signInWithOtp).toHaveBeenCalledWith({
      email: "personne@example.ma",
      options: {
        shouldCreateUser: false,
        emailRedirectTo: "https://app.example.test/ar/auth/callback?next=%2Far%2Ftableau-de-bord",
      },
    });
  });
});
