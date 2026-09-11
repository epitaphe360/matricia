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
export type BuilderWorkspace = { libraries: BuilderLibrary[]; services: BuilderService[]; questionnairePersistenceAvailable: false };

export function parseBuilderDraft(value: unknown) {
  return builderDraftSchema.safeParse(value);
}
