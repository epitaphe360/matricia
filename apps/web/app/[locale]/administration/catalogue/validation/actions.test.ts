import { beforeEach, describe, expect, it, vi } from "vitest";
import type { RuleValidationActionState } from "./actions";

const mocks = vi.hoisted(() => ({ validate: vi.fn(), simulate: vi.fn() }));
vi.mock("@/lib/i18n/locale", () => ({ isLocale: (value: string) => value === "fr" || value === "ar" }));
vi.mock("@/lib/rule-validation/model", async () => await import("../../../../../lib/rule-validation/model"));
vi.mock("@/lib/rule-validation/server-repository", () => ({ createServerRuleValidationRepository: async () => ({ validate: mocks.validate, simulate: mocks.simulate }) }));

import { simulateRules, validateRules } from "./actions";

const idle: RuleValidationActionState = { status: "idle" };
const versionId = "11111111-1111-4111-8111-111111111111";
const questionId = "22222222-2222-4222-8222-222222222222";

function form() {
  const value = new FormData();
  value.set("locale", "fr");
  value.set("questionnaireVersionId", versionId);
  return value;
}

describe("rule validation server actions", () => {
  beforeEach(() => {
    mocks.validate.mockReset().mockResolvedValue({ status: "success", value: { valid: true, questionnaire_version_id: versionId, engine_version: "engine-v1", policy_version: "policy-v1", question_count: 1, rule_count: 0, errors: [] } });
    mocks.simulate.mockReset().mockResolvedValue({ status: "success", value: { questionnaire_version_id: versionId, engine_version: "engine-v1", policy_version: "policy-v1", score_basis_points: 0, triggered_actions: [], simulation: true, reproducibility_hash: "a".repeat(64) } });
  });

  it("transmet la version à la validation serveur", async () => {
    await expect(validateRules(idle, form())).resolves.toEqual({ status: "success", operation: "VALIDATION", report: expect.objectContaining({ valid: true }) });
    expect(mocks.validate).toHaveBeenCalledWith(versionId);
  });

  it("parse des réponses JSON bornées avant la simulation", async () => {
    const value = form();
    value.set("answers", JSON.stringify({ [questionId]: true }));
    value.set("previousAnswers", "{}");
    await simulateRules(idle, value);
    expect(mocks.simulate).toHaveBeenCalledWith({ questionnaireVersionId: versionId, answers: { [questionId]: true }, previousAnswers: {} });
  });

  it("refuse un tableau JSON sans appeler le moteur", async () => {
    const value = form();
    value.set("answers", "[]");
    value.set("previousAnswers", "{}");
    await expect(simulateRules(idle, value)).resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.simulate).not.toHaveBeenCalled();
  });

  it("traduit une interdiction serveur en état stable", async () => {
    mocks.validate.mockResolvedValueOnce({ status: "error", reason: "FORBIDDEN" });
    await expect(validateRules(idle, form())).resolves.toEqual({ status: "error", reason: "FORBIDDEN" });
  });
});
