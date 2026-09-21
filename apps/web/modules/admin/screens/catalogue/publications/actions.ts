"use server";

import { revalidatePath } from "next/cache";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { rollbackCatalogRelease } from "@/modules/shared/lib/catalogue-publications/repository";

export type RollbackActionState = { status: "idle" } | { status: "success"; releaseId: string } | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "FORBIDDEN" | "AAL2_REQUIRED" | "CONFLICT" | "FAILED" };
const text = (form: FormData, key: string) => String(form.get(key) ?? "");

export async function rollbackReleaseAction(_: RollbackActionState, form: FormData): Promise<RollbackActionState> {
  const locale = text(form, "locale");
  if (!isLocale(locale) || text(form, "confirmed") !== "yes") return { status: "error", reason: "VALIDATION" };
  const result = await rollbackCatalogRelease({
    libraryId: text(form, "libraryId"), targetReleaseId: text(form, "targetReleaseId"), releaseKey: text(form, "releaseKey").toUpperCase(),
    expectedLibraryRowVersion: text(form, "expectedLibraryRowVersion"), idempotencyKey: text(form, "idempotencyKey"), correlationId: text(form, "correlationId"),
  });
  if (result.status === "error") return { status: "error", reason: result.reason === "INVALID_INPUT" || result.reason === "INVALID_RESPONSE" ? "VALIDATION" : result.reason === "UNAVAILABLE" ? "FAILED" : result.reason };
  revalidatePath(`/${locale}/administration/catalogue/publications`);
  return { status: "success", releaseId: result.value.releaseId };
}
