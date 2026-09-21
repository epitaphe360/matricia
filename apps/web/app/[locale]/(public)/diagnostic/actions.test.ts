import { beforeEach, describe, expect, it, vi } from "vitest";

const { rpc, revalidatePath } = vi.hoisted(() => ({ rpc: vi.fn(), revalidatePath: vi.fn() }));
vi.mock("@/modules/shared/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ rpc }) }));
vi.mock("next/cache", () => ({ revalidatePath }));
import { savePublicDiagnosticIntake } from "./actions";

const organizationId = "00000000-0000-4000-8000-000000000001";
const intakeId = "00000000-0000-4000-8000-000000000002";
const answers = {
  goals: ["grow_sales"], sector: "commerce", team_size: "small",
  priority_tracking: "partial", sales_tracking: "manual", backup_restore: "recent",
  decision_trace: "systematic", next_action: "Mieux suivre les demandes commerciales.",
};

function form(overrides: Record<string, string> = {}) {
  const data = new FormData();
  Object.entries({ locale: "fr", organizationId, answers: JSON.stringify(answers), ...overrides }).forEach(([key, value]) => data.set(key, value));
  return data;
}

describe("savePublicDiagnosticIntake", () => {
  beforeEach(() => { rpc.mockReset(); revalidatePath.mockReset(); });

  it("rejects untrusted answers before calling the database", async () => {
    const result = await savePublicDiagnosticIntake({ status: "idle" }, form({ answers: JSON.stringify({ ...answers, sector: "invalid" }) }));
    expect(result).toEqual({ status: "error", reason: "VALIDATION" });
    expect(rpc).not.toHaveBeenCalled();
  });

  it("delegates authorization and authoritative recomputation to the idempotent RPC", async () => {
    rpc.mockResolvedValue({ data: { outcome: "PUBLIC_DIAGNOSTIC_INTAKE_SAVED", intake_id: intakeId, status: "INDICATIVE" }, error: null });
    await expect(savePublicDiagnosticIntake({ status: "idle" }, form())).resolves.toEqual({ status: "success", intakeId });
    expect(rpc).toHaveBeenCalledWith("save_public_diagnostic_intake", expect.objectContaining({
      p_organization_id: organizationId, p_answers: answers, p_locale: "fr",
      p_idempotency_key: expect.stringMatching(/^[a-f0-9]{64}$/), p_correlation_id: expect.any(String),
    }));
    expect(revalidatePath).toHaveBeenCalledWith("/fr/client/diagnostics");
  });
});
