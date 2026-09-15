import { beforeEach, describe, expect, it, vi } from "vitest";

const rpc = vi.hoisted(() => vi.fn());
vi.mock("next/headers", () => ({ headers: vi.fn(async () => new Headers({ "x-forwarded-for": "203.0.113.10" })) }));
vi.mock("@/lib/supabase/admin", () => ({ getSupabaseAdminClient: () => ({ rpc }) }));
import { submitContactRequest } from "./actions";

function form(overrides: Record<string, string> = {}) {
  const data = new FormData();
  const values = { locale: "fr", category: "CLIENT", replyEmail: "contact@example.com", message: "Une demande professionnelle suffisamment détaillée.", website: "", ...overrides };
  for (const [key, value] of Object.entries(values)) data.set(key, value);
  return data;
}

beforeEach(() => rpc.mockReset());

describe("public contact intake", () => {
  it("confirms only the persisted request and returns a short reference", async () => {
    rpc.mockResolvedValue({ data: "12345678-1234-4000-8000-123456789abc", error: null });
    await expect(submitContactRequest({ status: "idle" }, form())).resolves.toEqual({ status: "success", reference: "12345678" });
    expect(rpc).toHaveBeenCalledWith("submit_public_contact_request", expect.objectContaining({ p_reply_email: "contact@example.com", p_source_path: "/fr/contact" }));
  });

  it("rejects invalid input and the honeypot without calling the database", async () => {
    await expect(submitContactRequest({ status: "idle" }, form({ website: "bot.example" }))).resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(rpc).not.toHaveBeenCalled();
  });

  it("does not report a false success when persistence fails", async () => {
    rpc.mockResolvedValue({ data: null, error: { message: "CONTACT_SUBMISSION_RATE_LIMITED" } });
    await expect(submitContactRequest({ status: "idle" }, form())).resolves.toEqual({ status: "error", reason: "RATE_LIMITED" });
  });
});
