import { describe, expect, it, vi } from "vitest";
import { createQuestionnaireSessionsRepository, type QuestionnaireSessionSource } from "./repository";

const id = (n: number) => `${String(n).padStart(8, "0")}-0000-4000-8000-000000000000`;
const ok = (data: unknown) => ({ data, error: null });
function source(overrides: Partial<QuestionnaireSessionSource> = {}): QuestionnaireSessionSource {
  return {
    async user() { return id(1); }, async memberships() { return ok([{ id: id(2), organization_id: id(3) }]); }, async roles() { return ok([{ membership_id: id(2), role_code: "CLIENT_OWNER", revoked_at: null }]); }, async organizations() { return ok([{ id: id(3), display_name: "Atelier Atlas" }]); },
    async documents() { return ok([]); }, async publishedVersions() { return ok([{ id: id(4), version: 2, status: "PUBLISHED", audience: "CLIENT", title_fr: "Diagnostic", title_ar: "التشخيص", description_fr: "Diagnostic client", description_ar: "تشخيص العميل" }]); }, async sessions() { return ok([]); }, async versions() { return ok([]); }, async session() { return ok([]); }, async sections() { return ok([]); }, async questionLinks() { return ok([]); }, async questions() { return ok([]); }, async answers() { return ok([]); }, async revisions() { return ok([]); }, async rpc() { return ok({}); }, ...overrides,
  };
}
describe("questionnaire sessions repository", () => {
  it("fails closed without authentication or Client role", async () => {
    expect(await createQuestionnaireSessionsRepository(source({ user: async () => null })).load()).toEqual({ status: "error", reason: "UNAUTHENTICATED" });
    expect(await createQuestionnaireSessionsRepository(source({ roles: async () => ok([]) })).load()).toEqual({ status: "error", reason: "FORBIDDEN" });
  });
  it("loads only the bounded published dashboard", async () => {
    const result = await createQuestionnaireSessionsRepository(source()).load();
    expect(result).toEqual({ status: "success", value: { organizations: [{ id: id(3), name: "Atelier Atlas" }], documents: [], questionnaires: [expect.objectContaining({ id: id(4), version: 2 })], sessions: [], selected: null } });
  });
  it("uses exact autosave RPC payload and reports optimistic conflicts", async () => {
    const rpc = vi.fn(async () => ok({ outcome: "AUTOSAVE_CONFLICT", session_id: id(5), server_row_version: 3, conflicts: [] }));
    const result = await createQuestionnaireSessionsRepository(source({ rpc })).save({ sessionId: id(5), questionVersionId: id(6), expectedSessionRowVersion: 2, expectedAnswerRowVersion: 0, answerType: "DECIMAL", value: { kind: "DECIMAL", value: "1.25" }, idempotencyKey: "command-123", correlationId: id(7) });
    expect(result).toEqual({ status: "error", reason: "CONFLICT" });
    expect(rpc).toHaveBeenCalledWith("autosave_questionnaire_answers", expect.objectContaining({ p_answers: [{ question_version_id: id(6), value: { kind: "DECIMAL", value: "1.25" }, expected_answer_row_version: 0 }] }));
  });
  it("rejects RPC response extensions and accepts the final versioned start contract", async () => {
    const response = { outcome: "QUESTIONNAIRE_SESSION_STARTED", session_id: id(5), row_version: 1, questionnaire_version_id: id(4), session_snapshot_id: id(6), session_snapshot_hash: "a".repeat(64) };
    const accepted = await createQuestionnaireSessionsRepository(source({ rpc: async () => ok(response) })).start({ organizationId: id(3), questionnaireVersionId: id(4), locale: "fr", dueAt: null, idempotencyKey: "command-123", correlationId: id(7) });
    expect(accepted).toEqual({ status: "success", value: { sessionId: id(5), rowVersion: 1 } });
    const rejected = await createQuestionnaireSessionsRepository(source({ rpc: async () => ok({ ...response, internal: "must-not-pass" }) })).start({ organizationId: id(3), questionnaireVersionId: id(4), locale: "fr", dueAt: null, idempotencyKey: "command-456", correlationId: id(8) });
    expect(rejected).toEqual({ status: "error", reason: "INVALID_RESPONSE" });
  });
  it("resumes one immutable version and only its selected question subset", async () => {
    const sessions = [{ id: id(5), organization_id: id(3), actor_user_id: id(1), questionnaire_version_id: id(4), status: "IN_PROGRESS", locale: "fr-MA", updated_at: "2026-09-12T12:00:00Z", submitted_at: null, row_version: 2 }];
    const versions = [{ id: id(4), version: 2, status: "PUBLISHED", audience: "CLIENT", title_fr: "Diagnostic", title_ar: "التشخيص", description_fr: "Diagnostic client", description_ar: "تشخيص العميل" }];
    const questions = vi.fn(async () => ok([{ id: id(7), label_fr: "Budget", label_ar: "الميزانية", help_fr: null, help_ar: null, why_we_ask_fr: null, why_we_ask_ar: null, answer_type: "MONEY", required_by_default: true, options: [], validation_schema: {}, structured_schema: null, nullable: false }]));
    const result = await createQuestionnaireSessionsRepository(source({ async sessions() { return ok(sessions); }, async versions() { return ok(versions); }, async session() { return ok(sessions); }, async sections() { return ok([{ id: id(6), label_fr: "Contexte", label_ar: "السياق", help_fr: null, help_ar: null, sort_order: 1 }]); }, async questionLinks() { return ok([{ section_id: id(6), question_version_id: id(7), sort_order: 1, required_override: null }]); }, questions, async answers() { return ok([{ id: id(8), question_version_id: id(7), current_revision_id: id(9), row_version: 1 }]); }, async revisions() { return ok([{ id: id(9), value: { kind: "MONEY", amountMinor: "12500", currency: "MAD" } }]); } })).load(id(5));
    expect(result.status).toBe("success");
    if (result.status === "success") expect(result.value.selected).toEqual(expect.objectContaining({ id: id(5), answeredCount: 1, questionCount: 1 }));
    expect(questions).toHaveBeenCalledWith([id(7)]);
  });
  it("fails closed before loading more than 100 questions", async () => {
    const session = { id: id(5), organization_id: id(3), actor_user_id: id(1), questionnaire_version_id: id(4), status: "IN_PROGRESS", locale: "fr-MA", updated_at: "2026-09-12T12:00:00Z", submitted_at: null, row_version: 2 };
    const questions = vi.fn(async () => ok([]));
    const result = await createQuestionnaireSessionsRepository(source({ async sessions() { return ok([session]); }, async versions() { return ok([{ id: id(4), version: 2, status: "PUBLISHED", audience: "CLIENT", title_fr: "Diagnostic", title_ar: "التشخيص", description_fr: "Diagnostic client", description_ar: "تشخيص العميل" }]); }, async session() { return ok([session]); }, async sections() { return ok([{ id: id(6), label_fr: "Contexte", label_ar: "السياق", help_fr: null, help_ar: null, sort_order: 1 }]); }, async questionLinks() { return ok(Array.from({ length: 101 }, (_, index) => ({ section_id: id(6), question_version_id: id(100 + index), sort_order: index + 1, required_override: null }))); }, questions })).load(id(5));
    expect(result).toEqual({ status: "error", reason: "BOUNDS_EXCEEDED" });
    expect(questions).not.toHaveBeenCalled();
  });
  it("never exposes a private document from another organization in a selected session", async () => {
    const session = { id: id(5), organization_id: id(3), actor_user_id: id(1), questionnaire_version_id: id(4), status: "IN_PROGRESS", locale: "fr-MA", updated_at: "2026-09-12T12:00:00Z", submitted_at: null, row_version: 2 };
    const document = (documentId: string, organizationId: string, name: string) => ({ id: documentId, organization_id: organizationId, original_file_name: name, document_type: "TAX_DOCUMENT", declared_mime_type: "application/pdf", status: "VERIFIED" });
    const result = await createQuestionnaireSessionsRepository(source({
      async sessions() { return ok([session]); },
      async versions() { return ok([{ id: id(4), version: 2, status: "PUBLISHED", audience: "CLIENT", title_fr: "Diagnostic", title_ar: "التشخيص", description_fr: "Diagnostic client", description_ar: "تشخيص العميل" }]); },
      async session() { return ok([session]); },
      async documents() { return ok([document(id(20), id(3), "own.pdf"), document(id(21), id(99), "foreign.pdf")]); },
    })).load(id(5));
    expect(result.status).toBe("success");
    if (result.status === "success") expect(result.value.documents).toEqual([expect.objectContaining({ id: id(20), organizationId: id(3), name: "own.pdf" })]);
  });
});
