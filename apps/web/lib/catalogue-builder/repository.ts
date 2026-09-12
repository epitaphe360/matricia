import { z } from "zod";
import type { BuilderResult, CatalogBuilderRepository, ReleaseDraft, ReleaseItemInput } from "./contracts";
import { builderDraftSchema, catalogEntityStatusSchema, questionDraftInputSchema, type BuilderDraft, type BuilderWorkspace, uuidSchema } from "./model";

const libraryRow = z.object({ id: uuidSchema, code: z.string().min(2).max(80), status: catalogEntityStatusSchema, row_version: z.number().int().positive(), current_release_id: uuidSchema.nullable() }).strict();
const serviceRow = z.object({ id: uuidSchema, library_id: uuidSchema, code: z.string().min(2).max(80), slug: z.string().min(1).max(80), status: catalogEntityStatusSchema }).strict();
const createdRelease = z.object({ outcome: z.literal("CATALOG_RELEASE_CREATED"), release_id: uuidSchema, status: z.literal("DRAFT"), library_row_version: z.number().int().positive() }).strict();
const addedItem = z.object({ outcome: z.literal("CATALOG_RELEASE_ITEM_ADDED"), release_id: uuidSchema, release_row_version: z.number().int().positive() }).strict();
const submittedRelease = z.object({ outcome: z.literal("CATALOG_RELEASE_SUBMITTED"), release_id: uuidSchema, status: z.enum(["APPROVED", "IN_REVIEW"]), snapshot_hash: z.string().regex(/^[0-9a-f]{64}$/u) }).strict();
const createdQuestion = z.object({
  outcome: z.literal("CATALOG_QUESTION_CREATED"), question_id: uuidSchema, library_id: uuidSchema, version_id: uuidSchema,
  identity_row_version: z.number().int().positive(), version_row_version: z.number().int().positive(),
  content_hash: z.string().regex(/^[0-9a-f]{64}$/u), command_id: uuidSchema,
}).strict();

type QueryResponse = { data: unknown; error: { code?: string } | null };
export type BuilderRepositoryDependencies = {
  authenticated(): Promise<boolean>;
  libraries(): Promise<QueryResponse>;
  library(libraryId: string): Promise<QueryResponse>;
  services(libraryId: string): Promise<QueryResponse>;
  rpc(name: string, input: Record<string, unknown>): Promise<QueryResponse>;
};

function failure(error: { code?: string } | null): BuilderResult<never> {
  return { status: "error", reason: error?.code === "42501" ? "FORBIDDEN" : "UNAVAILABLE" };
}

export function createCatalogBuilderRepository(dependencies: BuilderRepositoryDependencies): CatalogBuilderRepository {
  return {
    async loadWorkspace(libraryId) {
      if (!await dependencies.authenticated()) return { status: "error", reason: "UNAUTHENTICATED" };
      const librariesResponse = await dependencies.libraries();
      if (librariesResponse.error) return failure(librariesResponse.error);
      const parsedLibraries = z.array(libraryRow).max(10).safeParse(librariesResponse.data);
      if (!parsedLibraries.success) return { status: "error", reason: "INVALID_RESPONSE" };
      let libraries = parsedLibraries.data;
      let services: BuilderWorkspace["services"] = [];
      if (libraryId) {
        if (!uuidSchema.safeParse(libraryId).success) return { status: "error", reason: "INVALID_INPUT" };
        if (!libraries.some((library) => library.id === libraryId)) {
          const selectedResponse = await dependencies.library(libraryId);
          if (selectedResponse.error) return failure(selectedResponse.error);
          const selected = z.array(libraryRow).max(1).safeParse(selectedResponse.data);
          if (!selected.success) return { status: "error", reason: "INVALID_RESPONSE" };
          if (selected.data.length !== 1 || selected.data[0].id !== libraryId) return { status: "error", reason: "INVALID_INPUT" };
          libraries = [selected.data[0], ...libraries.slice(0, 9)];
        }
        const servicesResponse = await dependencies.services(libraryId);
        if (servicesResponse.error) return failure(servicesResponse.error);
        const parsed = z.array(serviceRow).max(200).safeParse(servicesResponse.data);
        if (!parsed.success || parsed.data.some((service) => service.library_id !== libraryId)) return { status: "error", reason: "INVALID_RESPONSE" };
        services = parsed.data.map((service) => ({ id: service.id, libraryId: service.library_id, code: service.code, slug: service.slug, status: service.status }));
      }
      return { status: "success", value: {
        libraries: libraries.map((library) => ({ id: library.id, code: library.code, status: library.status, rowVersion: library.row_version, currentReleaseId: library.current_release_id })),
        services,
        questionnairePersistenceAvailable: false,
      } };
    },
    async persistQuestionnaireDraft(draft: BuilderDraft) {
      if (!builderDraftSchema.safeParse(draft).success) return { status: "error", reason: "INVALID_INPUT" };
      return { status: "error", reason: "MISSING_QUESTIONNAIRE_WRITE_RPC" };
    },
    async createQuestion(input) {
      const parsedInput = questionDraftInputSchema.safeParse(input);
      if (!parsedInput.success) return { status: "error", reason: "INVALID_INPUT" };
      if (!await dependencies.authenticated()) return { status: "error", reason: "UNAUTHENTICATED" };
      const value = parsedInput.data;
      const response = await dependencies.rpc("create_catalog_question", {
        p_library_id: value.libraryId,
        p_question_key: value.questionKey,
        p_scope: "SERVICE",
        p_payload: {
          label_fr: value.labelFr, label_ar: value.labelAr,
          ...(value.helpFr ? { help_fr: value.helpFr } : {}), ...(value.helpAr ? { help_ar: value.helpAr } : {}),
          answer_type: value.answerType, data_key: value.dataKey,
          required_by_default: value.requiredByDefault, required_for_quote: value.requiredForQuote, required_for_publication: false,
          options: [], validation_schema: value.answerType === "INTEGER" ? { precision: 18, scale: 0, rounding: "HALF_EVEN" } : {},
          sensitivity: value.sensitivity, nullable: !value.requiredByDefault, weight: 0, maximum_score: 0,
          source_service_id: value.serviceId,
        },
        p_change_reason: value.changeReason, p_idempotency_key: value.idempotencyKey, p_correlation_id: value.correlationId,
      });
      if (response.error) return failure(response.error);
      const parsed = createdQuestion.safeParse(response.data);
      return parsed.success && parsed.data.library_id === value.libraryId
        ? { status: "success", value: { questionId: parsed.data.question_id, versionId: parsed.data.version_id, identityRowVersion: parsed.data.identity_row_version, versionRowVersion: parsed.data.version_row_version, contentHash: parsed.data.content_hash } }
        : { status: "error", reason: "INVALID_RESPONSE" };
    },
    async createRelease(input): Promise<BuilderResult<ReleaseDraft>> {
      if (!await dependencies.authenticated()) return { status: "error", reason: "UNAUTHENTICATED" };
      if (!uuidSchema.safeParse(input.libraryId).success || !/^[A-Z][A-Z0-9_.-]{2,119}$/u.test(input.releaseKey)
          || !/^[0-9a-f]{64}$/u.test(input.sourceBundleHash) || !Number.isSafeInteger(input.expectedLibraryRowVersion) || input.expectedLibraryRowVersion < 1
          || !uuidSchema.safeParse(input.idempotencyKey).success || !uuidSchema.safeParse(input.correlationId).success) {
        return { status: "error", reason: "INVALID_INPUT" };
      }
      const response = await dependencies.rpc("create_catalog_release", {
        p_library_id: input.libraryId, p_release_key: input.releaseKey, p_source_bundle_hash: input.sourceBundleHash,
        p_requires_central_approval: input.requiresCentralApproval, p_expected_library_row_version: input.expectedLibraryRowVersion,
        p_idempotency_key: input.idempotencyKey, p_correlation_id: input.correlationId,
      });
      if (response.error) return failure(response.error);
      const parsed = createdRelease.safeParse(response.data);
      return parsed.success ? { status: "success", value: { id: parsed.data.release_id, rowVersion: 1 } } : { status: "error", reason: "INVALID_RESPONSE" };
    },
    async addReleaseItem(input: ReleaseItemInput) {
      if (!await dependencies.authenticated()) return { status: "error", reason: "UNAUTHENTICATED" };
      if (!uuidSchema.safeParse(input.releaseId).success || !uuidSchema.safeParse(input.objectId).success || !uuidSchema.safeParse(input.versionId).success
          || !["LIBRARY", "CATEGORY", "SUBCATEGORY", "SERVICE", "SERVICE_SUBCATEGORY_LINK"].includes(input.objectType)
          || !/^[0-9a-f]{64}$/u.test(input.contentHash) || !Number.isSafeInteger(input.sortOrder) || input.sortOrder < 1
          || !Number.isSafeInteger(input.expectedRowVersion) || input.expectedRowVersion < 1
          || !uuidSchema.safeParse(input.idempotencyKey).success || !uuidSchema.safeParse(input.correlationId).success) return { status: "error", reason: "INVALID_INPUT" };
      const response = await dependencies.rpc("add_catalog_release_item", {
        p_release_id: input.releaseId, p_object_type: input.objectType, p_object_id: input.objectId, p_version_id: input.versionId,
        p_content_hash: input.contentHash, p_sort_order: input.sortOrder, p_expected_release_row_version: input.expectedRowVersion,
        p_idempotency_key: input.idempotencyKey, p_correlation_id: input.correlationId,
      });
      if (response.error) return failure(response.error);
      const parsed = addedItem.safeParse(response.data);
      return parsed.success && parsed.data.release_id === input.releaseId
        ? { status: "success", value: { rowVersion: parsed.data.release_row_version } }
        : { status: "error", reason: "INVALID_RESPONSE" };
    },
    async submitRelease(input) {
      if (!await dependencies.authenticated()) return { status: "error", reason: "UNAUTHENTICATED" };
      if (!uuidSchema.safeParse(input.releaseId).success || !Number.isSafeInteger(input.expectedRowVersion) || input.expectedRowVersion < 1
          || !uuidSchema.safeParse(input.idempotencyKey).success || !uuidSchema.safeParse(input.correlationId).success) return { status: "error", reason: "INVALID_INPUT" };
      const response = await dependencies.rpc("submit_catalog_release", {
        p_release_id: input.releaseId, p_expected_row_version: input.expectedRowVersion,
        p_idempotency_key: input.idempotencyKey, p_correlation_id: input.correlationId,
      });
      if (response.error) return failure(response.error);
      const parsed = submittedRelease.safeParse(response.data);
      return parsed.success && parsed.data.release_id === input.releaseId
        ? { status: "success", value: { releaseId: parsed.data.release_id, status: parsed.data.status, snapshotHash: parsed.data.snapshot_hash } }
        : { status: "error", reason: "INVALID_RESPONSE" };
    },
  };
}
