import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = { getUser: vi.fn(), rpc: vi.fn() };
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
vi.mock("@/modules/shared/lib/supabase/server", () => ({
  getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, rpc: mocks.rpc }),
}));

import { requestClientRole } from "./actions";

const id = "11111111-1111-4111-8111-111111111111";

describe("requestClientRole", () => {
  beforeEach(() => {
    mocks.getUser.mockResolvedValue({ data: { user: { id } }, error: null });
    mocks.rpc.mockResolvedValue({ data: { outcome: "ROLE_REQUESTED" }, error: null });
  });

  it("demande CLIENT_OWNER sur le passeport existant", async () => {
    const form = new FormData();
    form.set("locale", "fr");
    form.set("organizationId", id);
    form.set("requestedRoleCode", "CLIENT_OWNER");
    form.set("idempotencyKey", id);
    await expect(requestClientRole({ status: "idle" }, form)).resolves.toEqual({ status: "success", outcome: "ROLE_REQUESTED" });
    expect(mocks.rpc).toHaveBeenCalledWith("request_additional_organization_role", expect.objectContaining({
      p_organization_id: id,
      p_requested_role_code: "CLIENT_OWNER",
    }));
  });

  it("refuse un rôle inventé", async () => {
    const form = new FormData();
    form.set("locale", "fr");
    form.set("organizationId", id);
    form.set("requestedRoleCode", "SUPER_ADMIN");
    form.set("idempotencyKey", id);
    await expect(requestClientRole({ status: "idle" }, form)).resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
});
