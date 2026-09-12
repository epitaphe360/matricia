import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ analyze: vi.fn(), compareAnomalies: vi.fn(), decide: vi.fn(), revalidatePath: vi.fn() }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidatePath }));
vi.mock("@/lib/assisted-intelligence/server-repository", () => ({ createServerAssistedIntelligenceRepository: async () => ({ analyze: mocks.analyze, compareAnomalies: mocks.compareAnomalies, decide: mocks.decide }) }));
vi.mock("@/lib/assisted-intelligence/model", async () => await import("../../../../../lib/assisted-intelligence/model"));
vi.mock("@/lib/assisted-intelligence/contracts", async () => await import("../../../../../lib/assisted-intelligence/contracts"));
vi.mock("@/lib/i18n/locale", async () => await import("../../../../../lib/i18n/locale"));
import { compareAnomalies, decideSuggestion, idleAssistanceAction, runAnalysis } from "./actions";

const id = (n: number) => `${String(n).padStart(8, "0")}-0000-4000-8000-000000000000`;
function form(values: Record<string, string>) { const data = new FormData(); for (const [key, value] of Object.entries(values)) data.set(key, value); return data; }

describe("assistance actions", () => {
  beforeEach(() => { vi.clearAllMocks(); });

  it("rejette les candidats non UUID avant le serveur", async () => {
    const result = await runAnalysis(idleAssistanceAction, form({ locale: "fr", organizationId: id(1), context: "NEED_TEXT", inputText: "Besoin valide", serviceVersionIds: "pas-un-uuid", questionVersionIds: "", knownDataKeys: "", modelVersionId: id(2), profileReassessmentId: "", idempotencyKey: id(3) }));
    expect(result).toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.analyze).not.toHaveBeenCalled();
  });

  it("transmet seulement les UUID d’anomalies ciblés", async () => {
    mocks.compareAnomalies.mockResolvedValue({ status: "success", value: { suggestionCount: 1 } });
    const result = await compareAnomalies(idleAssistanceAction, form({ locale: "ar", organizationId: id(1), anomalyIds: `${id(2)}\n${id(3)}`, modelVersionId: id(4), idempotencyKey: id(5) }));
    expect(result).toEqual({ status: "success", suggestionCount: 1 });
    expect(mocks.compareAnomalies).toHaveBeenCalledWith(expect.objectContaining({ anomalyIds: [id(2), id(3)] }));
  });

  it("bloque une réponse serveur qui prétend exécuter une action métier", async () => {
    mocks.decide.mockResolvedValue({ status: "success", value: { businessActionExecuted: true } });
    const result = await decideSuggestion(idleAssistanceAction, form({ locale: "fr", suggestionId: id(1), decision: "ACCEPTED", rationale: "Validation humaine", idempotencyKey: id(2) }));
    expect(result).toEqual({ status: "error", reason: "FAILED" });
  });
});
