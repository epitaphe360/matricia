import { z } from "zod";

export const uuidSchema = z.string().uuid();
export const codeSchema = z.string().trim().regex(/^[A-Z][A-Z0-9_.-]{1,79}$/u);
export const catalogEntityStatusSchema = z.enum(["DRAFT", "IN_REVIEW", "APPROVED", "PUBLISHED", "RETIRED", "ARCHIVED"]);
export type CatalogEntityStatus = z.infer<typeof catalogEntityStatusSchema>;

const bilingualText = z.object({
  fr: z.string().trim().min(2).max(1_000),
  ar: z.string().trim().min(2).max(1_000),
}).strict();

export const answerTypeSchema = z.enum([
  "YES_NO", "SINGLE_CHOICE", "MULTIPLE_CHOICE", "SHORT_TEXT", "LONG_TEXT",
  "INTEGER", "DECIMAL", "PERCENTAGE", "MONEY", "DATE", "EMAIL", "PHONE", "FILE",
]);

export const builderQuestionSchema = z.object({
  key: z.string().trim().regex(/^[A-Z][A-Z0-9_.-]{1,119}$/u),
  label: bilingualText,
  answerType: answerTypeSchema,
  required: z.boolean(),
  options: z.array(z.object({ value: z.string().trim().min(1).max(120), label: bilingualText }).strict()).max(50),
}).strict().superRefine((question, context) => {
  const choice = question.answerType === "SINGLE_CHOICE" || question.answerType === "MULTIPLE_CHOICE";
  if (choice && question.options.length < 2) context.addIssue({ code: "custom", path: ["options"] });
  if (!choice && question.options.length > 0) context.addIssue({ code: "custom", path: ["options"] });
});

export const builderRuleSchema = z.object({
  key: z.string().trim().regex(/^[A-Z][A-Z0-9_.-]{1,119}$/u),
  condition: z.string().trim().min(2).max(2_000),
  outcome: bilingualText,
}).strict();

export const builderDraftSchema = z.object({
  libraryId: uuidSchema,
  serviceId: uuidSchema,
  code: codeSchema,
  version: z.number().int().positive(),
  title: bilingualText,
  description: bilingualText,
  questions: z.array(builderQuestionSchema).min(1).max(200),
  rules: z.array(builderRuleSchema).max(200),
}).strict().superRefine((draft, context) => {
  const questionKeys = draft.questions.map((question) => question.key);
  const ruleKeys = draft.rules.map((rule) => rule.key);
  if (new Set(questionKeys).size !== questionKeys.length) context.addIssue({ code: "custom", path: ["questions"] });
  if (new Set(ruleKeys).size !== ruleKeys.length) context.addIssue({ code: "custom", path: ["rules"] });
});

export type BuilderDraft = z.infer<typeof builderDraftSchema>;
export type BuilderLibrary = { id: string; code: string; status: CatalogEntityStatus; rowVersion: number; currentReleaseId: string | null };
export type BuilderService = { id: string; libraryId: string; code: string; slug: string; status: CatalogEntityStatus };
export type BuilderRelease = { id: string; libraryId: string; key: string; rowVersion: number };
export type BuilderApprovedServiceVersion = { id: string; serviceId: string; libraryId: string; version: number; nameFr: string; nameAr: string };
export type BuilderWorkspace = { libraries: BuilderLibrary[]; services: BuilderService[]; draftReleases: BuilderRelease[]; approvedServiceVersions: BuilderApprovedServiceVersion[]; questionnairePersistenceAvailable: false };

export const questionDraftInputSchema = z.object({
  libraryId: uuidSchema,
  serviceId: uuidSchema,
  questionKey: z.string().trim().regex(/^[A-Z][A-Z0-9_.-]{1,119}$/u),
  labelFr: z.string().trim().min(1).max(1_000),
  labelAr: z.string().trim().min(1).max(1_000),
  helpFr: z.string().trim().max(2_000),
  helpAr: z.string().trim().max(2_000),
  answerType: z.enum(["YES_NO", "SHORT_TEXT", "LONG_TEXT", "INTEGER", "DATE", "MONEY"]),
  dataKey: z.string().trim().regex(/^[A-Za-z][A-Za-z0-9_.-]{1,159}$/u),
  requiredByDefault: z.boolean(),
  requiredForQuote: z.boolean(),
  sensitivity: z.enum(["PUBLIC", "BUSINESS", "CONFIDENTIAL", "RESTRICTED"]),
  changeReason: z.string().trim().min(3).max(500),
  idempotencyKey: uuidSchema,
  correlationId: uuidSchema,
}).strict();
export type QuestionDraftInput = z.infer<typeof questionDraftInputSchema>;
export type CreatedQuestion = { questionId: string; versionId: string; identityRowVersion: number; versionRowVersion: number; contentHash: string };

export const ruleDraftInputSchema = z.object({
  libraryId: uuidSchema,
  ruleKey: z.string().trim().regex(/^[A-Z][A-Z0-9_.-]{1,119}$/u),
  questionKey: z.string().trim().regex(/^[A-Z][A-Z0-9_.-]{1,119}$/u),
  expectedBoolean: z.boolean(),
  actionType: z.enum(["BLOCK_PUBLICATION", "BLOCK_RFQ", "REQUIRE_QUESTION", "SHOW_QUESTION", "HIDE_QUESTION", "CREATE_ANOMALY", "CREATE_RISK", "CREATE_RECOMMENDATION", "REQUIRE_HUMAN_REVIEW"]),
  actionTarget: z.string().trim().regex(/^[A-Z][A-Z0-9_.:-]{1,127}$/u),
  priority: z.number().int().min(0).max(100_000),
  sensitive: z.boolean(),
  changeReason: z.string().trim().min(3).max(500),
  idempotencyKey: uuidSchema,
  correlationId: uuidSchema,
}).strict();
export type RuleDraftInput = z.infer<typeof ruleDraftInputSchema>;
export type CreatedRule = { ruleId: string; versionId: string; identityRowVersion: number; versionRowVersion: number; compiledHash: string };

export const questionnaireDraftInputSchema = z.object({
  libraryId: uuidSchema, catalogReleaseId: uuidSchema, code: z.string().trim().regex(/^[A-Z][A-Z0-9_-]{1,79}$/u),
  titleFr: z.string().trim().min(2).max(240), titleAr: z.string().trim().min(2).max(240),
  descriptionFr: z.string().trim().min(3).max(4_000), descriptionAr: z.string().trim().min(3).max(4_000),
  audience: z.enum(["CLIENT", "PROVIDER", "FRANCHISE", "INTERNAL"]),
  engineVersion: z.string().trim().regex(/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/u), policyVersion: z.string().trim().regex(/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/u),
  sensitive: z.boolean(), sectionKey: z.string().trim().regex(/^[A-Z][A-Z0-9_-]{1,79}$/u),
  sectionLabelFr: z.string().trim().min(1).max(240), sectionLabelAr: z.string().trim().min(1).max(240),
  sectionHelpFr: z.string().trim().max(2_000), sectionHelpAr: z.string().trim().max(2_000),
  changeReason: z.string().trim().min(3).max(500), idempotencyKey: uuidSchema, correlationId: uuidSchema,
}).strict();
export type QuestionnaireDraftInput = z.infer<typeof questionnaireDraftInputSchema>;
export type CreatedQuestionnaire = { questionnaireId: string; versionId: string; sectionId: string; identityRowVersion: number; versionRowVersion: number; snapshotHash: string };

export function parseBuilderDraft(value: unknown) {
  return builderDraftSchema.safeParse(value);
}
