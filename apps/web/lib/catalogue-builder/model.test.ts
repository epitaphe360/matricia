import { describe, expect, it } from "vitest";
import { parseBuilderDraft } from "./model";

const valid = {
  libraryId: "11111111-1111-4111-8111-111111111111",
  serviceId: "22222222-2222-4222-8222-222222222222",
  code: "Q_IT_AUDIT", version: 1,
  title: { fr: "Diagnostic IT", ar: "تشخيص تقني" },
  description: { fr: "Questionnaire de diagnostic", ar: "استبيان التشخيص" },
  questions: [{ key: "SECURITY_LEVEL", label: { fr: "Niveau de sécurité", ar: "مستوى الأمان" }, answerType: "YES_NO", required: true, options: [] }],
  rules: [{ key: "ESCALATE", condition: "SECURITY_LEVEL == false", outcome: { fr: "Revue requise", ar: "المراجعة مطلوبة" } }],
};

describe("parseBuilderDraft", () => {
  it("accepts a bounded bilingual versioned draft", () => expect(parseBuilderDraft(valid).success).toBe(true));
  it("rejects duplicate keys and incomplete Arabic", () => expect(parseBuilderDraft({ ...valid, questions: [valid.questions[0], { ...valid.questions[0], label: { fr: "Autre", ar: "" } }] }).success).toBe(false));
  it("requires bounded options only for choice questions", () => expect(parseBuilderDraft({ ...valid, questions: [{ ...valid.questions[0], answerType: "SINGLE_CHOICE", options: [] }] }).success).toBe(false));
});
