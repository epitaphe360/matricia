"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { createServerCatalogBuilderRepository } from "../../../../lib/catalogue-builder/server-repository";
import { uuidSchema } from "../../../../lib/catalogue-builder/model";
import { isLocale } from "../../../../lib/i18n/locale";

export type BuilderActionState =
  | { status: "idle" }
  | { status: "success"; operation: "CREATED" | "ITEM_ADDED" | "SUBMITTED"; releaseId: string; rowVersion?: number; releaseStatus?: "APPROVED" | "IN_REVIEW" }
  | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "FORBIDDEN" | "UNAVAILABLE" };

const base = z.object({ locale: z.string().refine(isLocale), confirmed: z.literal("yes"), idempotencyKey: uuidSchema, correlationId: uuidSchema });
const createSchema = base.extend({
  libraryId: uuidSchema, releaseKey: z.string().trim().regex(/^[A-Z][A-Z0-9_.-]{2,119}$/u),
  sourceBundleHash: z.string().trim().regex(/^[0-9a-f]{64}$/u), expectedLibraryRowVersion: z.coerce.number().int().positive(),
  requiresCentralApproval: z.enum(["yes", "no"]),
}).strict();
const addSchema = base.extend({
  releaseId: uuidSchema, objectType: z.enum(["LIBRARY", "CATEGORY", "SUBCATEGORY", "SERVICE", "SERVICE_SUBCATEGORY_LINK"]),
  objectId: uuidSchema, versionId: uuidSchema, contentHash: z.string().trim().regex(/^[0-9a-f]{64}$/u),
  sortOrder: z.coerce.number().int().positive(), expectedRowVersion: z.coerce.number().int().positive(),
}).strict();
const submitSchema = base.extend({ releaseId: uuidSchema, expectedRowVersion: z.coerce.number().int().positive() }).strict();

function errorReason(reason: string): BuilderActionState {
  return { status: "error", reason: reason === "UNAUTHENTICATED" ? "UNAUTHENTICATED" : reason === "FORBIDDEN" ? "FORBIDDEN" : "UNAVAILABLE" };
}

function actionFields(formData: FormData): Record<string, FormDataEntryValue> {
  return Object.fromEntries(Array.from(formData.entries()).filter(([key]) => !key.startsWith("$ACTION_")));
}

export async function createReleaseAction(_state: BuilderActionState, formData: FormData): Promise<BuilderActionState> {
  const parsed = createSchema.safeParse(actionFields(formData));
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
  const result = await repository.addReleaseItem(parsed.data);
  if (result.status === "error") return errorReason(result.reason);
  revalidatePath(`/${parsed.data.locale}/administration/catalogue`);
  return { status: "success", operation: "ITEM_ADDED", releaseId: parsed.data.releaseId, rowVersion: result.value.rowVersion };
}

export async function submitReleaseAction(_state: BuilderActionState, formData: FormData): Promise<BuilderActionState> {
  const parsed = submitSchema.safeParse(actionFields(formData));
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };
  const repository = await createServerCatalogBuilderRepository();
  const result = await repository.submitRelease(parsed.data);
  if (result.status === "error") return errorReason(result.reason);
  revalidatePath(`/${parsed.data.locale}/administration/catalogue`);
  return { status: "success", operation: "SUBMITTED", releaseId: result.value.releaseId, releaseStatus: result.value.status };
}
