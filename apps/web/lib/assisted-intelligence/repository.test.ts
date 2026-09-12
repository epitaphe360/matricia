import { describe, expect, it, vi } from "vitest";
import { createAssistedIntelligenceRepository, type AssistanceSource } from "./repository";

const id = (n: number) => `${String(n).padStart(8, "0")}-0000-4000-8000-000000000000`;
const ok = (data: unknown) => ({ data, error: null });

function source(overrides: Partial<AssistanceSource> = {}): AssistanceSource {
  return {
    async userId() { return id(1); },
    async memberships() { return ok([{ id: id(2), organization_id: id(3) }]); },
    async roles() { return ok([{ membership_id: id(2), role_code: "CLIENT_ADMIN", revoked_at: null }]); },
    async organizations() { return ok([{ id: id(3), display_name: "Atlas" }]); },
    async models() { return ok([{ id: id(4), version: 1, algorithm: "TOKEN_OVERLAP_V1" }]); },
    async requests() { return ok([]); },
    async suggestions() { return ok([]); },
    async decisions() { return ok([]); },
    async rpc() { return ok({}); },
    ...overrides,
  };
}

describe("assisted intelligence repository", () => {
  it("sépare les droits d’analyse et de décision", async () => {
    const buyer = source({ async roles() { return ok([{ membership_id: id(2), role_code: "CLIENT_BUYER", revoked_at: null }]); } });
    const result = await createAssistedIntelligenceRepository(buyer).dashboard();
    expect(result).toMatchObject({ status: "success", value: { organizations: [{ canAnalyze: true, canDecide: false }] } });
  });

  it("branche l’analyse sur le contrat RPC final et valide sa sortie", async () => {
    const rpc = vi.fn(async () => ok({ outcome: "ASSISTANCE_PROPOSED", request_id: id(8), suggestion_count: 2, model_version_id: id(4), human_confirmation_required: true }));
    const repository = createAssistedIntelligenceRepository(source({ rpc }));
    const result = await repository.analyze({ organizationId: id(3), context: "NEED_TEXT", inputText: "Sauvegarde distante", serviceVersionIds: [id(5)], questionVersionIds: [], knownDataKeys: [], modelVersionId: id(4), profileReassessmentId: null, idempotencyKey: id(6), correlationId: id(7) });
    expect(result).toMatchObject({ status: "success", value: { suggestionCount: 2, humanConfirmationRequired: true } });
    expect(rpc).toHaveBeenCalledWith("run_assisted_analysis", expect.objectContaining({ p_candidate_service_version_ids: [id(5)], p_context_type: "NEED_TEXT" }));
  });

  it("prouve qu’une décision ne déclenche aucune action métier", async () => {
    const rpc = vi.fn(async () => ok({ outcome: "ASSISTANCE_SUGGESTION_ACCEPTED", suggestion_id: id(5), decision_id: id(6), business_action_executed: false }));
    const result = await createAssistedIntelligenceRepository(source({ rpc })).decide({ suggestionId: id(5), decision: "ACCEPTED", rationale: "Confirmé par le client", idempotencyKey: id(7), correlationId: id(8) });
    expect(result).toMatchObject({ status: "success", value: { businessActionExecuted: false } });
  });

  it("stabilise les erreurs d’autorisation serveur", async () => {
    const result = await createAssistedIntelligenceRepository(source({ async rpc() { return { data: null, error: { code: "42501" } }; } })).compareAnomalies({ organizationId: id(3), anomalyIds: [id(4), id(5)], modelVersionId: id(6), idempotencyKey: id(7), correlationId: id(8) });
    expect(result).toEqual({ status: "error", reason: "FORBIDDEN" });
  });
});
