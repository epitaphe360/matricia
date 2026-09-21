import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ rpc: vi.fn(), from: vi.fn() }));
vi.mock("@/modules/shared/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ auth: { getUser: async () => ({ data: { user: { id: "11111111-1111-4111-8111-111111111111" } } }) }, rpc: mocks.rpc, from: mocks.from }) }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));

import { evaluateBadge, publishChecklist } from "./actions";

const idle = { status: "idle" } as const;
const key = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const chain = (data: unknown) => { const value = { select: vi.fn(), eq: vi.fn(), maybeSingle: vi.fn(async () => ({ data, error: null })) }; value.select.mockReturnValue(value); value.eq.mockReturnValue(value); return value; };

describe("authoritative incentives actions", () => {
  beforeEach(() => { mocks.rpc.mockReset().mockResolvedValue({ data: { outcome: "OK" }, error: null }); mocks.from.mockReset(); });

  it("derives provider and service from the selected reputation snapshot", async () => {
    mocks.from.mockReturnValue(chain({ provider_organization_id: "22222222-2222-4222-8222-222222222222", service_id: "33333333-3333-4333-8333-333333333333" }));
    const form = new FormData(); form.set("locale", "fr"); form.set("idempotencyKey", key); form.set("policyId", "44444444-4444-4444-8444-444444444444"); form.set("reputationId", "55555555-5555-4555-8555-555555555555");
    await expect(evaluateBadge(idle, form)).resolves.toEqual({ status: "success" });
    expect(mocks.rpc).toHaveBeenCalledWith("evaluate_provider_badge", expect.objectContaining({ p_provider_organization_id: "22222222-2222-4222-8222-222222222222", p_service_id: "33333333-3333-4333-8333-333333333333", p_reputation_snapshot_id: "55555555-5555-4555-8555-555555555555" }));
  });

  it("derives the audit organization from the service library steward", async () => {
    mocks.from.mockReturnValue(chain({ catalog_services: { catalog_libraries: { steward_organization_id: "66666666-6666-4666-8666-666666666666" } } }));
    const form = new FormData(); form.set("locale", "ar"); form.set("idempotencyKey", key); form.set("serviceVersionId", "77777777-7777-4777-8777-777777777777"); form.set("reason", "Publication autoritative"); form.set("items", JSON.stringify([{ key: "VERIFY", label_fr: "Vérifier", label_ar: "تحقق", instructions_fr: "Comparer la preuve.", instructions_ar: "قارن الدليل.", proof_required: true, proof_types: ["DOCUMENT"] }]));
    await expect(publishChecklist(idle, form)).resolves.toEqual({ status: "success" });
    expect(mocks.rpc).toHaveBeenCalledWith("publish_service_checklist_template", expect.objectContaining({ p_audit_organization_id: "66666666-6666-4666-8666-666666666666", p_service_version_id: "77777777-7777-4777-8777-777777777777" }));
  });
});
