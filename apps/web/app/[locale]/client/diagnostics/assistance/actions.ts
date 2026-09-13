"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { createServerAssistedIntelligenceRepository } from "@/lib/assisted-intelligence/server-repository";
import { contextSchema, decisionSchema, minimizeAssistanceInput, parseKnownKeys, parseUuidValues, uuid } from "@/lib/assisted-intelligence/model";
import type { AssistanceFailure } from "@/lib/assisted-intelligence/contracts";
import { isLocale } from "@/lib/i18n/locale";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import type { AssistanceActionState } from "./action-state";

function text(form: FormData, key: string): string {
  return String(form.get(key) ?? "").trim();
}

function actionFailure(reason: AssistanceFailure): AssistanceActionState {
  if (reason === "INVALID_INPUT") return { status: "error", reason: "VALIDATION" };
  if (reason === "UNAUTHENTICATED" || reason === "FORBIDDEN" || reason === "CONFLICT") return { status: "error", reason };
  return { status: "error", reason: "FAILED" };
}

function localePath(form: FormData): string | null {
  const locale = text(form, "locale");
  return isLocale(locale) ? `/${locale}/client/diagnostics/assistance` : null;
}

async function authorizeClientOrganization(organizationId: string, canDecide: boolean): Promise<AssistanceActionState | null> {
  const client = await getSupabaseServerClient();
  const { data } = await client.auth.getUser();
  if (!data.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const allowedRoles = canDecide ? ["CLIENT_OWNER", "CLIENT_ADMIN"] : ["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_BUYER"];
  const membership = await client.from("organization_memberships").select("id,organization_member_roles!inner(role_code,revoked_at)").eq("user_id", data.user.id).eq("organization_id", organizationId).eq("status", "ACTIVE").is("organization_member_roles.revoked_at", null).in("organization_member_roles.role_code", allowedRoles).limit(1).maybeSingle();
  return membership.error || !membership.data ? { status: "error", reason: "FORBIDDEN" } : null;
}

async function authorizeSuggestionDecision(suggestionId: string): Promise<AssistanceActionState | null> {
  const client = await getSupabaseServerClient();
  const suggestion = await client.from("assistance_suggestions").select("organization_id").eq("id", suggestionId).maybeSingle();
  if (suggestion.error || !suggestion.data) return { status: "error", reason: "FORBIDDEN" };
  return authorizeClientOrganization(String(suggestion.data.organization_id), true);
}

export async function runAnalysis(_: AssistanceActionState, form: FormData): Promise<AssistanceActionState> {
  const path = localePath(form);
  const serviceVersionIds = parseUuidValues(form.getAll("serviceVersionIds"));
  const questionVersionIds = parseUuidValues(form.getAll("questionVersionIds"));
  const knownDataKeys = parseKnownKeys(text(form, "knownDataKeys"));
  const parsed = zRun.safeParse({
    organizationId: text(form, "organizationId"),
    context: text(form, "context"),
    inputText: minimizeAssistanceInput(text(form, "inputText") || null),
    modelVersionId: text(form, "modelVersionId"),
    profileReassessmentId: text(form, "profileReassessmentId") || null,
    idempotencyKey: text(form, "idempotencyKey"),
  });
  if (!path || !serviceVersionIds || !questionVersionIds || !knownDataKeys || !parsed.success || (parsed.data.context === "NEED_TEXT" && (parsed.data.inputText?.length ?? 0) < 3)) return { status: "error", reason: "VALIDATION" };
  const authorization = await authorizeClientOrganization(parsed.data.organizationId, false);
  if (authorization) return authorization;
  const result = await (await createServerAssistedIntelligenceRepository()).analyze({ ...parsed.data, serviceVersionIds, questionVersionIds, knownDataKeys, correlationId: randomUUID() });
  if (result.status === "error") return actionFailure(result.reason);
  revalidatePath(path);
  return { status: "success", suggestionCount: result.value.suggestionCount };
}

export async function compareAnomalies(_: AssistanceActionState, form: FormData): Promise<AssistanceActionState> {
  const path = localePath(form);
  const anomalyIds = parseUuidValues(form.getAll("anomalyIds"));
  const parsed = zCompare.safeParse({ organizationId: text(form, "organizationId"), modelVersionId: text(form, "modelVersionId"), idempotencyKey: text(form, "idempotencyKey") });
  if (!path || !anomalyIds || anomalyIds.length < 2 || !parsed.success) return { status: "error", reason: "VALIDATION" };
  const authorization = await authorizeClientOrganization(parsed.data.organizationId, false);
  if (authorization) return authorization;
  const result = await (await createServerAssistedIntelligenceRepository()).compareAnomalies({ ...parsed.data, anomalyIds, correlationId: randomUUID() });
  if (result.status === "error") return actionFailure(result.reason);
  revalidatePath(path);
  return { status: "success", suggestionCount: result.value.suggestionCount };
}

export async function decideSuggestion(_: AssistanceActionState, form: FormData): Promise<AssistanceActionState> {
  const path = localePath(form);
  const parsed = zDecision.safeParse({ suggestionId: text(form, "suggestionId"), decision: text(form, "decision"), rationale: text(form, "rationale"), idempotencyKey: text(form, "idempotencyKey") });
  if (!path || !parsed.success) return { status: "error", reason: "VALIDATION" };
  const authorization = await authorizeSuggestionDecision(parsed.data.suggestionId);
  if (authorization) return authorization;
  const result = await (await createServerAssistedIntelligenceRepository()).decide({ ...parsed.data, correlationId: randomUUID() });
  if (result.status === "error") return actionFailure(result.reason);
  if (result.value.businessActionExecuted !== false) return { status: "error", reason: "FAILED" };
  revalidatePath(path);
  return { status: "success" };
}

const zRun = z.object({ organizationId: uuid, context: contextSchema, inputText: z.string().max(4000).nullable(), modelVersionId: uuid, profileReassessmentId: uuid.nullable(), idempotencyKey: uuid });
const zCompare = z.object({ organizationId: uuid, modelVersionId: uuid, idempotencyKey: uuid });
const zDecision = z.object({ suggestionId: uuid, decision: decisionSchema, rationale: z.string().trim().min(3).max(1000), idempotencyKey: uuid });
