import { describe, expect, it } from "vitest";
import { parseAnswerMap, ruleSimulationSchema, ruleValidationSchema } from "./model";

const versionId = "11111111-1111-4111-8111-111111111111";
const ruleId = "22222222-2222-4222-8222-222222222222";

describe("rule validation contracts", () => {
  it("accepte un objet de réponses JSON borné et indexé par UUID", () => {
    expect(parseAnswerMap(JSON.stringify({ [versionId]: { kind: "DECIMAL", value: "12.50" } }))).toEqual({ [versionId]: { kind: "DECIMAL", value: "12.50" } });
    expect(parseAnswerMap("[]")).toBeNull();
    expect(parseAnswerMap('{"not-a-uuid":true}')).toBeNull();
  });

  it("refuse plus de 500 réponses avant tout appel serveur", () => {
    const answers = Object.fromEntries(Array.from({ length: 501 }, (_, index) => [`00000000-0000-4000-8000-${String(index).padStart(12, "0")}`, true]));
    expect(parseAnswerMap(JSON.stringify(answers))).toBeNull();
  });

  it("applique la limite de 256 Kio en octets UTF-8", () => {
    const oversized = JSON.stringify({ [versionId]: "é".repeat(131_073) });
    expect(oversized.length).toBeLessThan(262_144);
    expect(parseAnswerMap(oversized)).toBeNull();
  });

  it("valide strictement les preuves de validation et simulation", () => {
    expect(ruleValidationSchema.safeParse({ valid: false, questionnaire_version_id: versionId, engine_version: "engine-v1", policy_version: "policy-v1", question_count: 1, rule_count: 1, errors: [{ rule_version_id: ruleId, code: "RULE_DEAD_BRANCH" }] }).success).toBe(true);
    expect(ruleValidationSchema.safeParse({ valid: false, questionnaire_version_id: versionId, engine_version: "engine-v1", policy_version: "policy-v1", question_count: 1, rule_count: 1, errors: [{ rule_version_id: ruleId, code: "relation internal_table does not exist" }] }).success).toBe(false);
    expect(ruleSimulationSchema.safeParse({ questionnaire_version_id: versionId, engine_version: "engine-v1", policy_version: "policy-v1", score_basis_points: 7500, triggered_actions: [{ type: "SCORE", rule_version_id: ruleId, evaluation_order: 1, delta_basis_points: 7500 }], simulation: true, reproducibility_hash: "a".repeat(64) }).success).toBe(true);
    expect(ruleSimulationSchema.safeParse({ questionnaire_version_id: versionId, engine_version: "engine-v1", policy_version: "policy-v1", score_basis_points: 10001, triggered_actions: [], simulation: true, reproducibility_hash: "invalid-hash" }).success).toBe(false);
  });
});
