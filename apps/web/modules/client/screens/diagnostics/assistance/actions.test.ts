import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ analyze: vi.fn(), compareAnomalies: vi.fn(), decide: vi.fn(), revalidatePath: vi.fn(), getClient: vi.fn() }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidatePath }));
vi.mock("@/modules/shared/lib/assisted-intelligence/server-repository", () => ({ createServerAssistedIntelligenceRepository: async () => ({ analyze: mocks.analyze, compareAnomalies: mocks.compareAnomalies, decide: mocks.decide }) }));
vi.mock("@/modules/shared/lib/assisted-intelligence/model", async () => await import("@/modules/shared/lib/assisted-intelligence/model"));
vi.mock("@/modules/shared/lib/assisted-intelligence/contracts", async () => await import("@/modules/shared/lib/assisted-intelligence/contracts"));
vi.mock("@/modules/shared/lib/i18n/locale", async () => await import("@/modules/shared/lib/i18n/locale"));
vi.mock("@/modules/shared/lib/supabase/server", () => ({ getSupabaseServerClient: mocks.getClient }));
import { compareAnomalies, decideSuggestion, runAnalysis } from "./actions";
import { idleAssistanceAction } from "./action-state";

const id = (n: number) => `${String(n).padStart(8, "0")}-0000-4000-8000-000000000000`;
function form(values: Record<string, string>) { const data = new FormData(); for (const [key, value] of Object.entries(values)) data.set(key, value); return data; }

describe("assistance actions", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.getClient.mockResolvedValue({
      auth: { getUser: vi.fn().mockResolvedValue({ data: { user: { id: id(9) } } }) },
      from: vi.fn((table: string) => {
        const chain: Record<string, unknown> = {};
        for (const method of ["select", "eq", "is", "in", "limit"]) chain[method] = vi.fn(() => chain);
        chain.maybeSingle = vi.fn().mockResolvedValue({
          data: table === "assistance_suggestions" ? { organization_id: id(8) } : { id: id(7) },
          error: null,
        });
        return chain;
      }),
    });
  });

  it("rejette les candidats non UUID avant le serveur", async () => {
    const result = await runAnalysis(idleAssistanceAction, form({ locale: "fr", organizationId: id(1), context: "NEED_TEXT", inputText: "Besoin valide", serviceVersionIds: "pas-un-uuid", questionVersionIds: "", knownDataKeys: "", modelVersionId: id(2), profileReassessmentId: "", idempotencyKey: id(3) }));
    expect(result).toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.analyze).not.toHaveBeenCalled();
  });

  it("transmet seulement les UUID d’anomalies ciblés", async () => {
    mocks.compareAnomalies.mockResolvedValue({ status: "success", value: { suggestionCount: 1 } });
    const data = form({ locale: "ar", organizationId: id(1), modelVersionId: id(4), idempotencyKey: id(5) });
    data.append("anomalyIds", id(2));
    data.append("anomalyIds", id(3));
    const result = await compareAnomalies(idleAssistanceAction, data);
    expect(result).toEqual({ status: "success", suggestionCount: 1 });
    expect(mocks.compareAnomalies).toHaveBeenCalledWith(expect.objectContaining({ anomalyIds: [id(2), id(3)] }));
  });

  it("bloque une réponse serveur qui prétend exécuter une action métier", async () => {
    mocks.decide.mockResolvedValue({ status: "success", value: { businessActionExecuted: true } });
    const result = await decideSuggestion(idleAssistanceAction, form({ locale: "fr", suggestionId: id(1), decision: "ACCEPTED", rationale: "Validation humaine", idempotencyKey: id(2) }));
    expect(result).toEqual({ status: "error", reason: "FAILED" });
  });
});
