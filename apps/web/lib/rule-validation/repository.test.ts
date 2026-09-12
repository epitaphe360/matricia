import { beforeEach, describe, expect, it, vi } from "vitest";
import type { RuleValidationDependencies } from "./contracts";
import { createRuleValidationRepository } from "./repository";

const versionId = "11111111-1111-4111-8111-111111111111";
const questionId = "22222222-2222-4222-8222-222222222222";
const ruleId = "33333333-3333-4333-8333-333333333333";
const libraryId = "44444444-4444-4444-8444-444444444444";

function dependencies(): RuleValidationDependencies {
  return {
    access: vi.fn().mockResolvedValue("AUTHORIZED"),
    versions: vi.fn().mockResolvedValue({ data: [{ id: versionId, version: 2, status: "LOCAL_TEST", title_fr: "Diagnostic", title_ar: "تشخيص", audience: "CLIENT", engine_version: "engine-v1", policy_version: "policy-v1", library_id: libraryId, catalog_libraries: { code: "IT" } }], error: null }),
    questions: vi.fn().mockResolvedValue({ data: [{ questionnaire_version_id: versionId, sort_order: 1, required_override: null, question_versions: { id: questionId, label_fr: "Nombre de sites", label_ar: "عدد المواقع", answer_type: "INTEGER", data_key: "company.site_count", required_by_default: true } }], error: null }),
    rpc: vi.fn(),
  };
}

describe("rule validation repository", () => {
  let deps: RuleValidationDependencies;
  beforeEach(() => { deps = dependencies(); });

  it("charge seulement les questions de la version sélectionnée", async () => {
    const result = await createRuleValidationRepository(deps).loadWorkspace(versionId);
    expect(result.status).toBe("success");
    expect(deps.questions).toHaveBeenCalledWith(versionId);
    if (result.status === "success") expect(result.value.questions).toEqual([expect.objectContaining({ id: questionId, required: true })]);
  });

  it("refuse une version absente du lot RLS sans requête de questions", async () => {
    const result = await createRuleValidationRepository(deps).loadWorkspace(ruleId);
    expect(result).toEqual({ status: "error", reason: "INVALID_INPUT" });
    expect(deps.questions).not.toHaveBeenCalled();
  });

  it("appelle les RPC finales et rejette toute réponse non conforme", async () => {
    vi.mocked(deps.rpc).mockResolvedValueOnce({ data: { valid: true, questionnaire_version_id: versionId, engine_version: "engine-v1", policy_version: "policy-v1", question_count: 1, rule_count: 1, errors: [] }, error: null });
    await expect(createRuleValidationRepository(deps).validate(versionId)).resolves.toEqual({ status: "success", value: expect.objectContaining({ valid: true }) });
    expect(deps.rpc).toHaveBeenCalledWith("validate_questionnaire_rule_engine", { p_questionnaire_version_id: versionId });

    vi.mocked(deps.rpc).mockResolvedValueOnce({ data: { questionnaire_version_id: versionId, engine_version: "engine-v1", policy_version: "policy-v1", score_basis_points: 5000, triggered_actions: [], simulation: true, reproducibility_hash: "bad" }, error: null });
    await expect(createRuleValidationRepository(deps).simulate({ questionnaireVersionId: versionId, answers: {}, previousAnswers: {} })).resolves.toEqual({ status: "error", reason: "INVALID_RESPONSE" });
  });

  it("neutralise les erreurs serveur tout en distinguant l’interdiction", async () => {
    vi.mocked(deps.rpc).mockResolvedValue({ data: null, error: { code: "42501", message: "QUESTIONNAIRE_SCOPE_DENIED" } });
    await expect(createRuleValidationRepository(deps).validate(versionId)).resolves.toEqual({ status: "error", reason: "FORBIDDEN" });
  });

  it("interdit l’espace administration avant toute lecture sans rôle catalogue", async () => {
    vi.mocked(deps.access).mockResolvedValueOnce("FORBIDDEN");
    await expect(createRuleValidationRepository(deps).loadWorkspace(null)).resolves.toEqual({ status: "error", reason: "FORBIDDEN" });
    expect(deps.versions).not.toHaveBeenCalled();
  });
});
