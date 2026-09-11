"use server";

import { redirect } from "next/navigation";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { isLocale } from "@/lib/i18n/locale";

export async function signOut(formData: FormData) {
  const value = formData.get("locale");
  const locale = typeof value === "string" && isLocale(value) ? value : "fr";
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.auth.signOut();
  if (error) redirect(`/${locale}/tableau-de-bord?signout=failed`);
  redirect(`/${locale}/connexion`);
}
