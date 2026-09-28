import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ getUser: vi.fn(), rpc: vi.fn(), maybeSingle: vi.fn() }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
vi.mock("@/modules/shared/lib/i18n/locale", () => ({ isLocale: (v: string) => v === "fr" || v === "ar" }));
vi.mock("@/modules/shared/lib/supabase/server", () => ({
  getSupabaseServerClient: async () => ({
    auth: { getUser: mocks.getUser },
    rpc: mocks.rpc,
    from: () => ({ select: () => ({ eq: () => ({ maybeSingle: mocks.maybeSingle }) }) }),
  }),
}));

import { requestActionFromCenter } from "./actions";

const user = "11111111-1111-4111-8111-111111111111";
const work = "22222222-2222-4222-8222-222222222222";
const org = "33333333-3333-4333-8333-333333333333";
const forged = "44444444-4444-4444-8444-444444444444";

function form(entries: Record<string, string>) {
  const f = new FormData();
  f.set("locale", "fr");
  f.set("idempotencyKey", user);
  f.set("workItemId", work);
  f.set("actionType", "MANUAL_EXCEPTION");
  f.set("targetEnvironment", "STAGING");
  f.set("reason", "Exception contrôlée sur le dossier");
  for (const [key, value] of Object.entries(entries)) f.set(key, value);
  return f;
}

beforeEach(() => {
  mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id: user } } });
  mocks.rpc.mockReset().mockResolvedValue({ data: { outcome: "ADMIN_OPERATION_RECORDED" }, error: null });
  mocks.maybeSingle.mockReset().mockResolvedValue({ data: { id: work, organization_id: org, resource_type: "SERVICE_REQUEST", resource_id: "R-1", assigned_to: user }, error: null });
});

describe("requestActionFromCenter", () => {
  it("déduit l’organisation, la ressource et l’empreinte du dossier, pas du navigateur", async () => {
    const result = await requestActionFromCenter({ status: "idle" }, form({ organizationId: forged, resourceId: "FORGED", requestPayloadHash: "0".repeat(64) }));
    expect(result).toEqual({ status: "success", outcome: "ADMIN_OPERATION_RECORDED" });
    const args = mocks.rpc.mock.calls[0]![1] as Record<string, unknown>;
    expect(args.p_organization_id).toBe(org);
    expect(args.p_resource_type).toBe("SERVICE_REQUEST");
    expect(args.p_resource_id).toBe("R-1");
    expect(args.p_request_payload_hash).toMatch(/^[0-9a-f]{64}$/);
    expect(args.p_request_payload_hash).not.toBe("0".repeat(64));
    expect(args.p_production_authorization_reference).toBeNull();
  });

  it("refuse un dossier invisible pour l’utilisateur", async () => {
    mocks.maybeSingle.mockResolvedValue({ data: null, error: null });
    expect(await requestActionFromCenter({ status: "idle" }, form({}))).toEqual({ status: "error", reason: "FORBIDDEN" });
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("accorde l’accès support au responsable du dossier pour une durée bornée", async () => {
    const before = Date.now();
    await requestActionFromCenter({ status: "idle" }, form({ actionType: "GRANT_SUPPORT_ACCESS", supportAccessMode: "READ_ONLY", supportMinutes: "30" }));
    const args = mocks.rpc.mock.calls[0]![1] as Record<string, unknown>;
    expect(args.p_support_user_id).toBe(user);
    const expires = Date.parse(String(args.p_support_expires_at));
    expect(expires - before).toBeGreaterThanOrEqual(29 * 60000);
    expect(expires - before).toBeLessThanOrEqual(31 * 60000);
  });

  it("refuse l’accès support sans responsable ou avec une durée hors liste", async () => {
    mocks.maybeSingle.mockResolvedValue({ data: { id: work, organization_id: org, resource_type: "CASE", resource_id: "C-1", assigned_to: null }, error: null });
    expect(await requestActionFromCenter({ status: "idle" }, form({ actionType: "GRANT_SUPPORT_ACCESS", supportAccessMode: "READ_ONLY", supportMinutes: "30" }))).toEqual({ status: "error", reason: "VALIDATION" });
    expect(await requestActionFromCenter({ status: "idle" }, form({ actionType: "GRANT_SUPPORT_ACCESS", supportAccessMode: "READ_ONLY", supportMinutes: "600" }))).toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
});
