import type { BuilderDraft, BuilderWorkspace, CreatedQuestion, CreatedQuestionnaire, CreatedRule, QuestionnaireDraftInput, QuestionDraftInput, RuleDraftInput } from "./model";

export type BuilderError = "UNAUTHENTICATED" | "FORBIDDEN" | "INVALID_INPUT" | "INVALID_RESPONSE" | "UNAVAILABLE" | "MISSING_QUESTIONNAIRE_WRITE_RPC";
export type BuilderResult<T> = { status: "success"; value: T } | { status: "error"; reason: BuilderError };

export type ReleaseDraft = { id: string; rowVersion: number };
export type CommandIdentity = { idempotencyKey: string; correlationId: string };
export type ReleaseItemInput = {
  releaseId: string; objectType: "LIBRARY" | "CATEGORY" | "SUBCATEGORY" | "SERVICE" | "SERVICE_SUBCATEGORY_LINK";
  objectId: string; versionId: string; contentHash: string; sortOrder: number; expectedRowVersion: number;
} & CommandIdentity;

export interface CatalogBuilderRepository {
  loadWorkspace(libraryId: string | null): Promise<BuilderResult<BuilderWorkspace>>;
  persistQuestionnaireDraft(draft: BuilderDraft): Promise<BuilderResult<never>>;
  createQuestion(input: QuestionDraftInput): Promise<BuilderResult<CreatedQuestion>>;
  createRule(input: RuleDraftInput): Promise<BuilderResult<CreatedRule>>;
  createQuestionnaire(input: QuestionnaireDraftInput): Promise<BuilderResult<CreatedQuestionnaire>>;
  createRelease(input: { libraryId: string; releaseKey: string; sourceBundleHash: string; requiresCentralApproval: boolean; expectedLibraryRowVersion: number } & CommandIdentity): Promise<BuilderResult<ReleaseDraft>>;
  addReleaseItem(input: ReleaseItemInput): Promise<BuilderResult<{ rowVersion: number }>>;
  submitRelease(input: { releaseId: string; expectedRowVersion: number } & CommandIdentity): Promise<BuilderResult<{ releaseId: string; status: "APPROVED" | "IN_REVIEW"; snapshotHash: string }>>;
}
