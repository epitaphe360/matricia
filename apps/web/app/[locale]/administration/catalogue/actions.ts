"use server";
import { createHash } from "node:crypto";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { createServerCatalogBuilderRepository } from "../../../../lib/catalogue-builder/server-repository";
import { uuidSchema } from "../../../../lib/catalogue-builder/model";
import { isLocale } from "../../../../lib/i18n/locale";

export type BuilderActionState =
  | { status: "idle" }
  | { status: "success"; operation: "CREATED" | "ITEM_ADDED" | "SUBMITTED"; releaseId: string; rowVersion?: number; releaseStatus?: "APPROVED" | "IN_REVIEW" }
  | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "FORBIDDEN" | "UNAVAILABLE" };

export type QuestionActionState =
  | { status: "idle" }
  | { status: "success"; questionId: string; versionId: string }
  | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "FORBIDDEN" | "UNAVAILABLE" };

export type RuleActionState =
  | { status: "idle" }
  | { status: "success"; ruleId: string; versionId: string }
  | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "FORBIDDEN" | "UNAVAILABLE" };
export type QuestionnaireActionState =
  | { status: "idle" }
  | { status: "success"; questionnaireId: string; versionId: string; sectionId: string }
  | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "FORBIDDEN" | "UNAVAILABLE" };

const base = z.object({ locale: z.string().refine(isLocale), confirmed: z.literal("yes"), idempotencyKey: uuidSchema, correlationId: uuidSchema });
const createSchema = base.extend({
  libraryId: uuidSchema, releaseKey: z.string().trim().regex(/^[A-Z][A-Z0-9_.-]{2,119}$/u),
  sourceBundleHash: z.string().trim().regex(/^[0-9a-f]{64}$/u), expectedLibraryRowVersion: z.coerce.number().int().positive(),
  requiresCentralApproval: z.enum(["yes", "no"]),
}).strict();
const addSchema = base.extend({
  releaseId: uuidSchema, versionId: uuidSchema,
}).strict();
const submitSchema = base.extend({ releaseId: uuidSchema }).strict();
const questionSchema = base.extend({
  libraryId: uuidSchema, serviceId: uuidSchema,
  questionKey: z.string().trim().regex(/^[A-Z][A-Z0-9_.-]{1,119}$/u),
  labelFr: z.string().trim().min(1).max(1_000), labelAr: z.string().trim().min(1).max(1_000),
  helpFr: z.string().trim().max(2_000), helpAr: z.string().trim().max(2_000),
  answerType: z.enum(["YES_NO", "SHORT_TEXT", "LONG_TEXT", "INTEGER", "DATE", "MONEY"]),
  dataKey: z.string().trim().regex(/^[A-Za-z][A-Za-z0-9_.-]{1,159}$/u),
  requiredByDefault: z.enum(["yes", "no"]), requiredForQuote: z.enum(["yes", "no"]),
  sensitivity: z.enum(["PUBLIC", "BUSINESS", "CONFIDENTIAL", "RESTRICTED"]),
  changeReason: z.string().trim().min(3).max(500),
}).strict();
const ruleSchema = base.extend({
  libraryId: uuidSchema, ruleKey: z.string().trim().regex(/^[A-Z][A-Z0-9_.-]{1,119}$/u),
  questionKey: z.string().trim().regex(/^[A-Z][A-Z0-9_.-]{1,119}$/u), expectedBoolean: z.enum(["yes", "no"]),
  actionType: z.enum(["BLOCK_PUBLICATION", "BLOCK_RFQ", "REQUIRE_QUESTION", "SHOW_QUESTION", "HIDE_QUESTION", "CREATE_ANOMALY", "CREATE_RISK", "CREATE_RECOMMENDATION", "REQUIRE_HUMAN_REVIEW"]),
  actionTarget: z.string().trim().regex(/^[A-Z][A-Z0-9_.:-]{1,127}$/u), priority: z.coerce.number().int().min(0).max(100_000),
  sensitive: z.enum(["yes", "no"]), changeReason: z.string().trim().min(3).max(500),
}).strict();
const questionnaireSchema = base.extend({
  libraryId: uuidSchema, catalogReleaseId: uuidSchema, code: z.string().trim().regex(/^[A-Z][A-Z0-9_-]{1,79}$/u),
  titleFr: z.string().trim().min(2).max(240), titleAr: z.string().trim().min(2).max(240),
  descriptionFr: z.string().trim().min(3).max(4_000), descriptionAr: z.string().trim().min(3).max(4_000),
  audience: z.enum(["CLIENT", "PROVIDER", "FRANCHISE", "INTERNAL"]), engineVersion: z.string().trim().regex(/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/u),
  policyVersion: z.string().trim().regex(/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/u), sensitive: z.enum(["yes", "no"]),
  sectionKey: z.string().trim().regex(/^[A-Z][A-Z0-9_-]{1,79}$/u), sectionLabelFr: z.string().trim().min(1).max(240), sectionLabelAr: z.string().trim().min(1).max(240),
  sectionHelpFr: z.string().trim().max(2_000), sectionHelpAr: z.string().trim().max(2_000), changeReason: z.string().trim().min(3).max(500),
}).strict();

function errorReason(
  reason: string,
): Extract<BuilderActionState, { status: "error" }> {
  return { status: "error", reason: reason === "UNAUTHENTICATED" ? "UNAUTHENTICATED" : reason === "FORBIDDEN" ? "FORBIDDEN" : "UNAVAILABLE" };
}

function actionFields(formData: FormData): Record<string, FormDataEntryValue> {
  return Object.fromEntries(Array.from(formData.entries()).filter(([key]) => !key.startsWith("$ACTION_")));
}

export async function createReleaseAction(_state: BuilderActionState, formData: FormData): Promise<BuilderActionState> {
  const fields = actionFields(formData), sourceNote = z.string().trim().min(3).max(500).safeParse(fields.sourceNote);
  if (!sourceNote.success) return { status: "error", reason: "VALIDATION" };
  const sourceBundleHash = createHash("sha256").update(JSON.stringify({ libraryId: fields.libraryId, releaseKey: fields.releaseKey, sourceNote: sourceNote.data })).digest("hex");
  const commandFields = { ...fields };
  delete commandFields.sourceNote;
  const parsed = createSchema.safeParse({ ...commandFields, sourceBundleHash });
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };
  const repository = await createServerCatalogBuilderRepository();
  const result = await repository.createRelease({ ...parsed.data, requiresCentralApproval: parsed.data.requiresCentralApproval === "yes" });
  if (result.status === "error") return errorReason(result.reason);
  revalidatePath(`/${parsed.data.locale}/administration/catalogue`);
  return { status: "success", operation: "CREATED", releaseId: result.value.id, rowVersion: result.value.rowVersion };
}

export async function addReleaseItemAction(_state: BuilderActionState, formData: FormData): Promise<BuilderActionState> {
  const parsed = addSchema.safeParse(actionFields(formData));
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };
  const repository = await createServerCatalogBuilderRepository();
  const resolved = await repository.resolveApprovedServiceItem(parsed.data.releaseId, parsed.data.versionId);
  if (resolved.status === "error") return errorReason(resolved.reason);
  const result = await repository.addReleaseItem({ ...resolved.value, idempotencyKey: parsed.data.idempotencyKey, correlationId: parsed.data.correlationId });
  if (result.status === "error") return errorReason(result.reason);
  revalidatePath(`/${parsed.data.locale}/administration/catalogue`);
  return { status: "success", operation: "ITEM_ADDED", releaseId: parsed.data.releaseId, rowVersion: result.value.rowVersion };
}

export async function submitReleaseAction(_state: BuilderActionState, formData: FormData): Promise<BuilderActionState> {
  const parsed = submitSchema.safeParse(actionFields(formData));
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };
  const repository = await createServerCatalogBuilderRepository();
  const resolved = await repository.resolveDraftRelease(parsed.data.releaseId);
  if (resolved.status === "error") return errorReason(resolved.reason);
  const result = await repository.submitRelease({ releaseId: resolved.value.releaseId, expectedRowVersion: resolved.value.rowVersion, idempotencyKey: parsed.data.idempotencyKey, correlationId: parsed.data.correlationId });
  if (result.status === "error") return errorReason(result.reason);
  revalidatePath(`/${parsed.data.locale}/administration/catalogue`);
  return { status: "success", operation: "SUBMITTED", releaseId: result.value.releaseId, releaseStatus: result.value.status };
}

export async function createQuestionAction(_state: QuestionActionState, formData: FormData): Promise<QuestionActionState> {
  const parsed = questionSchema.safeParse(actionFields(formData));
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };
  const repository = await createServerCatalogBuilderRepository();
  const { locale } = parsed.data;
  const result = await repository.createQuestion({
    libraryId: parsed.data.libraryId,
    serviceId: parsed.data.serviceId,
    questionKey: parsed.data.questionKey,
    labelFr: parsed.data.labelFr,
    labelAr: parsed.data.labelAr,
    helpFr: parsed.data.helpFr,
    helpAr: parsed.data.helpAr,
    answerType: parsed.data.answerType,
    dataKey: parsed.data.dataKey,
    requiredByDefault: parsed.data.requiredByDefault === "yes",
    requiredForQuote: parsed.data.requiredForQuote === "yes",
    sensitivity: parsed.data.sensitivity,
    changeReason: parsed.data.changeReason,
    idempotencyKey: parsed.data.idempotencyKey,
    correlationId: parsed.data.correlationId,
  });
  if (result.status === "error") return errorReason(result.reason);
  revalidatePath(`/${locale}/administration/catalogue`);
  return { status: "success", questionId: result.value.questionId, versionId: result.value.versionId };
}

export async function createRuleAction(_state: RuleActionState, formData: FormData): Promise<RuleActionState> {
  const parsed = ruleSchema.safeParse(actionFields(formData));
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };
  const result = await (await createServerCatalogBuilderRepository()).createRule({
    libraryId: parsed.data.libraryId, ruleKey: parsed.data.ruleKey, questionKey: parsed.data.questionKey,
    expectedBoolean: parsed.data.expectedBoolean === "yes", actionType: parsed.data.actionType, actionTarget: parsed.data.actionTarget,
    priority: parsed.data.priority, sensitive: parsed.data.sensitive === "yes", changeReason: parsed.data.changeReason,
    idempotencyKey: parsed.data.idempotencyKey, correlationId: parsed.data.correlationId,
  });
  if (result.status === "error") return errorReason(result.reason);
  revalidatePath(`/${parsed.data.locale}/administration/catalogue`);
  return { status: "success", ruleId: result.value.ruleId, versionId: result.value.versionId };
}

export async function createQuestionnaireAction(_state: QuestionnaireActionState, formData: FormData): Promise<QuestionnaireActionState> {
  const parsed = questionnaireSchema.safeParse(actionFields(formData));
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };
  const result = await (await createServerCatalogBuilderRepository()).createQuestionnaire({
    libraryId: parsed.data.libraryId, catalogReleaseId: parsed.data.catalogReleaseId, code: parsed.data.code,
    titleFr: parsed.data.titleFr, titleAr: parsed.data.titleAr, descriptionFr: parsed.data.descriptionFr, descriptionAr: parsed.data.descriptionAr,
    audience: parsed.data.audience, engineVersion: parsed.data.engineVersion, policyVersion: parsed.data.policyVersion, sensitive: parsed.data.sensitive === "yes",
    sectionKey: parsed.data.sectionKey, sectionLabelFr: parsed.data.sectionLabelFr, sectionLabelAr: parsed.data.sectionLabelAr,
    sectionHelpFr: parsed.data.sectionHelpFr, sectionHelpAr: parsed.data.sectionHelpAr, changeReason: parsed.data.changeReason,
    idempotencyKey: parsed.data.idempotencyKey, correlationId: parsed.data.correlationId,
  });
  if (result.status === "error") return errorReason(result.reason);
  revalidatePath(`/${parsed.data.locale}/administration/catalogue`);
  return { status: "success", questionnaireId: result.value.questionnaireId, versionId: result.value.versionId, sectionId: result.value.sectionId };
}
