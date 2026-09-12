import { z } from "zod";
import type { AssistanceContext, SuggestionDecision } from "./contracts";

export const uuid = z.string().uuid();
export const contextSchema = z.enum([
  "CONTEXTUAL_ASSISTANT",
  "PROFILE_CHANGE",
  "NEED_TEXT",
  "QUESTIONNAIRE_QUALITY",
  "SIMILARITY_REVIEW",
]);
export const decisionSchema = z.enum(["ACCEPTED", "REJECTED"]);

const boundedUuidList = z.array(uuid).max(50);
const knownKey = z.string().trim().min(1).max(120).regex(/^[A-Za-z0-9_.-]+$/u);

export const analysisInputSchema = z
  .object({
    organizationId: uuid,
    context: contextSchema,
    inputText: z.string().trim().max(4000).nullable(),
    serviceVersionIds: boundedUuidList,
    questionVersionIds: boundedUuidList,
    knownDataKeys: z.array(knownKey).max(100),
    modelVersionId: uuid,
    profileReassessmentId: uuid.nullable(),
    idempotencyKey: uuid,
    correlationId: uuid,
  })
  .superRefine((value, issue) => {
    if (value.context === "NEED_TEXT" && (value.inputText?.length ?? 0) < 3) {
      issue.addIssue({ code: "custom", path: ["inputText"], message: "NEED_TEXT_REQUIRES_INPUT" });
    }
  });

export const similarityInputSchema = z.object({
  organizationId: uuid,
  anomalyIds: z.array(uuid).min(2).max(50),
  modelVersionId: uuid,
  idempotencyKey: uuid,
  correlationId: uuid,
});

export const decisionInputSchema = z.object({
  suggestionId: uuid,
  decision: decisionSchema,
  rationale: z.string().trim().min(3).max(1000),
  idempotencyKey: uuid,
  correlationId: uuid,
});

export function parseUuidLines(value: string): string[] | null {
  const entries = [...new Set(value.split(/[\s,;]+/u).map((item) => item.trim()).filter(Boolean))];
  return boundedUuidList.safeParse(entries).success ? entries : null;
}

export function parseKnownKeys(value: string): string[] | null {
  const entries = [...new Set(value.split(/[\s,;]+/u).map((item) => item.trim()).filter(Boolean))];
  const result = z.array(knownKey).max(100).safeParse(entries);
  return result.success ? result.data : null;
}

export function isAssistanceContext(value: string): value is AssistanceContext {
  return contextSchema.safeParse(value).success;
}

export function isSuggestionDecision(value: string): value is SuggestionDecision {
  return decisionSchema.safeParse(value).success;
}
