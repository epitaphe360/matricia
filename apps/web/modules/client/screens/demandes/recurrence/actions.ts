"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import type { RecurringFailure } from "@/modules/client/data/recurring/contracts";
import { createServerClientRecurringRepository } from "@/modules/client/data/recurring/server-repository";
import { cloneInput, createPlanInput, generateInput, recurringLocale, transitionPlanInput } from "@/modules/client/data/recurring/model";

export type RecurringActionReason = "VALIDATION" | Exclude<RecurringFailure, "INVALID_INPUT" | "INVALID_RESPONSE">;
export type RecurringActionState = { status: "idle" } | { status: "success"; operation: "CLONED" | "PLAN_CREATED" | "PLAN_TRANSITIONED" | "GENERATED"; requestId?: string; planId?: string; generatedCount?: number } | { status: "error"; reason: RecurringActionReason };
const localeInput = z.object({ locale: recurringLocale });
function value(form: FormData, key: string) { return form.get(key); }
function actionFailure(reason: RecurringFailure): RecurringActionReason { return reason === "INVALID_INPUT" || reason === "INVALID_RESPONSE" ? "UNAVAILABLE" : reason; }
function refresh(locale: "fr" | "ar") { revalidatePath(`/${locale}/client/demandes`); revalidatePath(`/${locale}/client/demandes/recurrence`); }

export async function cloneRequestAction(_: RecurringActionState, form: FormData): Promise<RecurringActionState> {
  const locale = localeInput.safeParse({ locale: value(form, "locale") });
  const parsed = cloneInput.safeParse({ sourceRequestId: value(form, "sourceRequestId"), desiredDate: value(form, "desiredDate"), reason: value(form, "reason"), idempotencyKey: value(form, "idempotencyKey"), correlationId: value(form, "correlationId") });
  if (!locale.success || !parsed.success) return { status: "error", reason: "VALIDATION" };
  const result = await (await createServerClientRecurringRepository()).clone({ ...parsed.data, desiredDate: parsed.data.desiredDate || null });
  if (result.status === "error") return { status: "error", reason: actionFailure(result.reason) };
  refresh(locale.data.locale); return { status: "success", operation: "CLONED", requestId: result.value.requestId };
}

export async function createPlanAction(_: RecurringActionState, form: FormData): Promise<RecurringActionState> {
  const locale = localeInput.safeParse({ locale: value(form, "locale") });
  const parsed = createPlanInput.safeParse({ templateRequestId: value(form, "templateRequestId"), cadence: value(form, "cadence"), startsOn: value(form, "startsOn"), endsOn: value(form, "endsOn"), reason: value(form, "reason"), idempotencyKey: value(form, "idempotencyKey"), correlationId: value(form, "correlationId") });
  if (!locale.success || !parsed.success) return { status: "error", reason: "VALIDATION" };
  const result = await (await createServerClientRecurringRepository()).createPlan({ ...parsed.data, endsOn: parsed.data.endsOn || null });
  if (result.status === "error") return { status: "error", reason: actionFailure(result.reason) };
  refresh(locale.data.locale); return { status: "success", operation: "PLAN_CREATED", planId: result.value.planId };
}

export async function transitionPlanAction(_: RecurringActionState, form: FormData): Promise<RecurringActionState> {
  const locale = localeInput.safeParse({ locale: value(form, "locale") });
  const parsed = transitionPlanInput.safeParse({ planId: value(form, "planId"), action: value(form, "action"), expectedRowVersion: value(form, "expectedRowVersion"), reason: value(form, "reason"), idempotencyKey: value(form, "idempotencyKey"), correlationId: value(form, "correlationId") });
  if (!locale.success || !parsed.success) return { status: "error", reason: "VALIDATION" };
  const result = await (await createServerClientRecurringRepository()).transition(parsed.data);
  if (result.status === "error") return { status: "error", reason: actionFailure(result.reason) };
  refresh(locale.data.locale); return { status: "success", operation: "PLAN_TRANSITIONED", planId: result.value.planId };
}

export async function generateOccurrencesAction(_: RecurringActionState, form: FormData): Promise<RecurringActionState> {
  const locale = localeInput.safeParse({ locale: value(form, "locale") });
  const parsed = generateInput.safeParse({ planId: value(form, "planId"), throughDate: value(form, "throughDate"), maxOccurrences: value(form, "maxOccurrences"), idempotencyKey: value(form, "idempotencyKey"), correlationId: value(form, "correlationId") });
  if (!locale.success || !parsed.success) return { status: "error", reason: "VALIDATION" };
  const result = await (await createServerClientRecurringRepository()).generate(parsed.data);
  if (result.status === "error") return { status: "error", reason: actionFailure(result.reason) };
  refresh(locale.data.locale); return { status: "success", operation: "GENERATED", planId: result.value.planId, generatedCount: result.value.generatedCount };
}
