"use server";

import { isLocale } from "@/lib/i18n/locale";
import type { RuleSimulation, RuleValidationReport } from "@/lib/rule-validation/model";
import { parseAnswerMap, uuidSchema } from "@/lib/rule-validation/model";
import { createServerRuleValidationRepository } from "@/lib/rule-validation/server-repository";

export type RuleValidationActionState =
  | { status: "idle" }
  | { status: "success"; operation: "VALIDATION"; report: RuleValidationReport }
  | { status: "success"; operation: "SIMULATION"; simulation: RuleSimulation }
  | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "FORBIDDEN" | "FAILED" };

const text = (form: FormData, key: string) => String(form.get(key) ?? "");

function actionFailure(reason: string): RuleValidationActionState {
  if (reason === "UNAUTHENTICATED") return { status: "error", reason: "UNAUTHENTICATED" };
  if (reason === "FORBIDDEN") return { status: "error", reason: "FORBIDDEN" };
  if (reason === "INVALID_INPUT") return { status: "error", reason: "VALIDATION" };
  return { status: "error", reason: "FAILED" };
}

function validContext(form: FormData): { locale: "fr" | "ar"; questionnaireVersionId: string } | null {
  const locale = text(form, "locale");
  const questionnaireVersionId = text(form, "questionnaireVersionId");
  return isLocale(locale) && uuidSchema.safeParse(questionnaireVersionId).success ? { locale, questionnaireVersionId } : null;
}

export async function validateRules(_: RuleValidationActionState, form: FormData): Promise<RuleValidationActionState> {
  const context = validContext(form);
  if (!context) return { status: "error", reason: "VALIDATION" };
  const repository = await createServerRuleValidationRepository();
  const result = await repository.validate(context.questionnaireVersionId);
  return result.status === "success" ? { status: "success", operation: "VALIDATION", report: result.value } : actionFailure(result.reason);
}

export async function simulateRules(_: RuleValidationActionState, form: FormData): Promise<RuleValidationActionState> {
  const context = validContext(form);
  if (!context) return { status: "error", reason: "VALIDATION" };
  const answers = parseAnswerMap(text(form, "answers"));
  const previousAnswers = parseAnswerMap(text(form, "previousAnswers"));
  if (!answers || !previousAnswers) return { status: "error", reason: "VALIDATION" };
  const repository = await createServerRuleValidationRepository();
  const result = await repository.simulate({ questionnaireVersionId: context.questionnaireVersionId, answers, previousAnswers });
  return result.status === "success" ? { status: "success", operation: "SIMULATION", simulation: result.value } : actionFailure(result.reason);
}
