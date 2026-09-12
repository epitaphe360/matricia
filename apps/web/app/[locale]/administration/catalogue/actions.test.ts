import { beforeEach, describe, expect, it, vi } from "vitest";

const repository = vi.hoisted(() => ({
  createQuestion: vi.fn(),
  createRule: vi.fn(),
  createQuestionnaire: vi.fn(),
  createRelease: vi.fn(),
  addReleaseItem: vi.fn(),
  submitRelease: vi.fn(),
}));
const revalidatePath = vi.hoisted(() => vi.fn());

vi.mock("../../../../lib/catalogue-builder/server-repository", () => ({
  createServerCatalogBuilderRepository: async () => repository,
}));
vi.mock("next/cache", () => ({ revalidatePath }));

import { addReleaseItemAction, createQuestionAction, createQuestionnaireAction, createReleaseAction, createRuleAction, submitReleaseAction } from "./actions";

const identity = {
  idempotencyKey: "11111111-1111-4111-8111-111111111111",
  correlationId: "22222222-2222-4222-8222-222222222222",
};
const libraryId = "33333333-3333-4333-8333-333333333333";
const releaseId = "44444444-4444-4444-8444-444444444444";
const objectId = "55555555-5555-4555-8555-555555555555";
const versionId = "66666666-6666-4666-8666-666666666666";

function form(values: Record<string, string>): FormData {
  const data = new FormData();
  for (const [key, value] of Object.entries(values)) data.set(key, value);
  return data;
}

function createForm(extra: Record<string, string> = {}) {
  return form({ locale: "fr", confirmed: "yes", ...identity, libraryId, releaseKey: "IT.E2E.V1", sourceBundleHash: "a".repeat(64), expectedLibraryRowVersion: "4", requiresCentralApproval: "no", ...extra });
}

beforeEach(() => {
  vi.clearAllMocks();
  repository.createRelease.mockResolvedValue({ status: "success", value: { id: releaseId, rowVersion: 1 } });
  repository.createQuestion.mockResolvedValue({ status: "success", value: { questionId: objectId, versionId, identityRowVersion: 1, versionRowVersion: 1, contentHash: "d".repeat(64) } });
  repository.createRule.mockResolvedValue({ status: "success", value: { ruleId: objectId, versionId, identityRowVersion: 1, versionRowVersion: 1, compiledHash: "e".repeat(64) } });
  repository.createQuestionnaire.mockResolvedValue({ status: "success", value: { questionnaireId: objectId, versionId, sectionId: releaseId, identityRowVersion: 1, versionRowVersion: 1, snapshotHash: "f".repeat(64) } });
  repository.addReleaseItem.mockResolvedValue({ status: "success", value: { rowVersion: 2 } });
  repository.submitRelease.mockResolvedValue({ status: "success", value: { releaseId, status: "APPROVED", snapshotHash: "b".repeat(64) } });
});

describe("catalogue questionnaire server action", () => {
  function questionnaireForm(extra: Record<string, string> = {}) { return form({ locale: "ar", confirmed: "yes", ...identity, libraryId, catalogReleaseId: releaseId, code: "SECURITY", titleFr: "Diagnostic sécurité", titleAr: "تشخيص الأمان", descriptionFr: "Questionnaire initial de sécurité", descriptionAr: "استبيان الأمان الأولي", audience: "CLIENT", engineVersion: "1.0.0", policyVersion: "P06-1", sensitive: "no", sectionKey: "GENERAL", sectionLabelFr: "Général", sectionLabelAr: "عام", sectionHelpFr: "", sectionHelpAr: "", changeReason: "Création questionnaire", ...extra }); }
  it("creates a bilingual governed questionnaire with strict normalized input", async () => {
    expect(await createQuestionnaireAction({ status: "idle" }, questionnaireForm())).toEqual({ status: "success", questionnaireId: objectId, versionId, sectionId: releaseId });
    expect(repository.createQuestionnaire).toHaveBeenCalledWith(expect.objectContaining({ libraryId, catalogReleaseId: releaseId, audience: "CLIENT", sensitive: false, ...identity }));
    expect(repository.createQuestionnaire.mock.calls[0]?.[0]).not.toHaveProperty("locale");
    expect(revalidatePath).toHaveBeenCalledWith("/ar/administration/catalogue");
  });
  it("rejects unknown questionnaire fields before persistence", async () => {
    expect(await createQuestionnaireAction({ status: "idle" }, questionnaireForm({ injected: "true" }))).toEqual({ status: "error", reason: "VALIDATION" });
    expect(repository.createQuestionnaire).not.toHaveBeenCalled();
  });
});

describe("catalogue rule server action", () => {
  function ruleForm(extra: Record<string, string> = {}) {
    return form({ locale: "fr", confirmed: "yes", ...identity, libraryId, ruleKey: "MFA_REQUIRED", questionKey: "HAS_MFA", expectedBoolean: "no", actionType: "CREATE_RISK", actionTarget: "MFA_MISSING", priority: "20", sensitive: "yes", changeReason: "Création de la règle MFA", ...extra });
  }
  it("creates a typed boolean rule without transport fields", async () => {
    const result = await createRuleAction({ status: "idle" }, ruleForm());
    expect(result).toEqual({ status: "success", ruleId: objectId, versionId });
    expect(repository.createRule).toHaveBeenCalledWith({ libraryId, ruleKey: "MFA_REQUIRED", questionKey: "HAS_MFA", expectedBoolean: false, actionType: "CREATE_RISK", actionTarget: "MFA_MISSING", priority: 20, sensitive: true, changeReason: "Création de la règle MFA", ...identity });
    expect(revalidatePath).toHaveBeenCalledWith("/fr/administration/catalogue");
  });
  it("rejects augmented rule input before persistence", async () => {
    expect(await createRuleAction({ status: "idle" }, ruleForm({ injected: "true" }))).toEqual({ status: "error", reason: "VALIDATION" });
    expect(repository.createRule).not.toHaveBeenCalled();
  });
});

describe("catalogue question server action", () => {
  function questionForm(extra: Record<string, string> = {}) {
    return form({
      locale: "ar", confirmed: "yes", ...identity, libraryId, serviceId: objectId, questionKey: "IT_SECURITY_MFA",
      labelFr: "Le MFA est-il activé ?", labelAr: "هل المصادقة متعددة العوامل مفعلة؟", helpFr: "", helpAr: "",
      answerType: "YES_NO", dataKey: "security.mfa.enabled", requiredByDefault: "yes", requiredForQuote: "no",
      sensitivity: "BUSINESS", changeReason: "Création du contrôle MFA", ...extra,
    });
  }

  it("creates a question with normalized booleans and exact command identity", async () => {
    const result = await createQuestionAction({ status: "idle" }, questionForm());
    expect(result).toEqual({ status: "success", questionId: objectId, versionId });
    expect(repository.createQuestion).toHaveBeenCalledWith(expect.objectContaining({
      libraryId, serviceId: objectId, requiredByDefault: true, requiredForQuote: false, ...identity,
    }));
    expect(repository.createQuestion.mock.calls[0]?.[0]).not.toHaveProperty("locale");
    expect(repository.createQuestion.mock.calls[0]?.[0]).not.toHaveProperty("confirmed");
    expect(revalidatePath).toHaveBeenCalledWith("/ar/administration/catalogue");
  });

  it("rejects an augmented question command before persistence", async () => {
    const result = await createQuestionAction({ status: "idle" }, questionForm({ injected: "true" }));
    expect(result).toEqual({ status: "error", reason: "VALIDATION" });
    expect(repository.createQuestion).not.toHaveBeenCalled();
  });
});

describe("catalogue release server actions", () => {
  it("rejects an unknown field before creating a repository", async () => {
    const result = await createReleaseAction({ status: "idle" }, createForm({ unexpected: "field" }));
    expect(result).toEqual({ status: "error", reason: "VALIDATION" });
    expect(repository.createRelease).not.toHaveBeenCalled();
  });

  it("ignores only the React transport field while retaining a strict DTO", async () => {
    const data = createForm(); data.set("$ACTION_REF_1", "transport");
    const result = await createReleaseAction({ status: "idle" }, data);
    expect(result.status).toBe("success");
    expect(repository.createRelease).toHaveBeenCalledOnce();
  });

  it("creates and safely replays with the exact browser command identity", async () => {
    const first = await createReleaseAction({ status: "idle" }, createForm());
    const replay = await createReleaseAction({ status: "idle" }, createForm());
    expect(first).toEqual({ status: "success", operation: "CREATED", releaseId, rowVersion: 1 });
    expect(replay).toEqual(first);
    expect(repository.createRelease).toHaveBeenNthCalledWith(1, expect.objectContaining(identity));
    expect(repository.createRelease).toHaveBeenNthCalledWith(2, expect.objectContaining(identity));
    expect(revalidatePath).toHaveBeenCalledWith("/fr/administration/catalogue");
  });

  it("adds an approved version through the typed action", async () => {
    const result = await addReleaseItemAction({ status: "idle" }, form({
      locale: "ar", confirmed: "yes", ...identity, releaseId, objectType: "SERVICE", objectId, versionId,
      contentHash: "c".repeat(64), sortOrder: "1", expectedRowVersion: "1",
    }));
    expect(result).toEqual({ status: "success", operation: "ITEM_ADDED", releaseId, rowVersion: 2 });
    expect(repository.addReleaseItem).toHaveBeenCalledWith(expect.objectContaining({ objectType: "SERVICE", sortOrder: 1, expectedRowVersion: 1, ...identity }));
  });

  it("submits and translates a permission denial to a stable error", async () => {
    repository.submitRelease.mockResolvedValue({ status: "error", reason: "FORBIDDEN" });
    const result = await submitReleaseAction({ status: "idle" }, form({ locale: "fr", confirmed: "yes", ...identity, releaseId, expectedRowVersion: "2" }));
    expect(result).toEqual({ status: "error", reason: "FORBIDDEN" });
  });
});
