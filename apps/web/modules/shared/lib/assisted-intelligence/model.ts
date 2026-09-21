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

export function parseUuidValues(values: FormDataEntryValue[]): string[] | null {
  const entries = [...new Set(values.map(String).map((item) => item.trim()).filter(Boolean))];
  return boundedUuidList.safeParse(entries).success ? entries : null;
}

export function parseKnownKeys(value: string): string[] | null {
  const entries = [...new Set(value.split(/[\s,;]+/u).map((item) => item.trim()).filter(Boolean))];
  const result = z.array(knownKey).max(100).safeParse(entries);
  return result.success ? result.data : null;
}

const piiPatterns: ReadonlyArray<[RegExp, string]> = [
  [/(ICE\s*[#:=\-]*)(\d[\d -]{13,20}\d)/giu, "$1[ICE]"],
  [/((?:IF|IDENTIFIANT\s+FISCAL)\s*[#:=\-]*)(\d[\d -]{4,12}\d)/giu, "$1[IF]"],
  [/(CNSS\s*[#:=\-]*)(\d[\d -]{4,15}\d)/giu, "$1[CNSS]"],
  [/([\p{L}\d._%+-]+)@([\p{L}\d.-]+\.[\p{L}]{2,})/giu, "[EMAIL]"],
  [/[+]?\d[\d ()-]{7,}\d/gu, "[PHONE]"],
  [/((?:NOM|NAME|CONTACT|REPRÉSENTANT|REPRÉSENTANTE|RESPONSABLE|الاسم)\s*[#:=\-]+)[\p{L}][\p{L}' -]{1,100}/giu, "$1[NAME]"],
  [/((?:ADRESSE|ADDRESS|العنوان)\s*[#:=\-]+)[^;\r\n]{3,180}/giu, "$1[ADDRESS]"],
];

/** Client-side privacy barrier; the database repeats and authoritatively enforces minimisation. */
export function minimizeAssistanceInput(value: string | null): string | null {
  if (value === null) return null;
  let minimized = value.trim().slice(0, 1000);
  for (const [pattern, replacement] of piiPatterns) minimized = minimized.replace(pattern, replacement);
  return minimized || null;
}

export function isAssistanceContext(value: string): value is AssistanceContext {
  return contextSchema.safeParse(value).success;
}

export function isSuggestionDecision(value: string): value is SuggestionDecision {
  return decisionSchema.safeParse(value).success;
}
