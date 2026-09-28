"use server";

import { redirect } from "next/navigation";
import { isLocale, type Locale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";

function safeReturnPath(value: FormDataEntryValue | null, locale: Locale): string {
  if (typeof value !== "string") return `/${locale}/tableau-de-bord`;
  const allowed = value.startsWith(`/${locale}/`) && !value.startsWith("//") && !value.includes("\\") && !value.includes("://");
  return allowed ? value : `/${locale}/tableau-de-bord`;
}

export async function signOutOfWorkspace(formData: FormData) {
  const value = formData.get("locale");
  const locale = typeof value === "string" && isLocale(value) ? value : "fr";
  const returnTo = safeReturnPath(formData.get("returnTo"), locale);
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.auth.signOut();
  if (error) {
    const separator = returnTo.includes("?") ? "&" : "?";
    redirect(`${returnTo}${separator}signout=failed`);
  }
  redirect(`/${locale}/connexion`);
}
