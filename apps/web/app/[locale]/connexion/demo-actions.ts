"use server";

import { redirect } from "next/navigation";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseAdminClient } from "@/modules/shared/lib/supabase/admin";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { demoPersonaEmail, isPublicDemoAccessEnabled } from "./demo-policy";
import type { DemoPersona } from "./demo-personas";

const personaConfig = {
  client: { destination: "tableau-de-bord" },
  provider: { destination: "tableau-de-bord" },
  franchise: { destination: "franchise/accueil" },
  admin: { destination: "administration/command-center" },
} as const satisfies Record<DemoPersona, { destination: string }>;

function parsePersona(value: FormDataEntryValue | null): DemoPersona | null {
  return value === "client" || value === "provider" || value === "franchise" || value === "admin" ? value : null;
}

export async function connectDemoPersona(formData: FormData): Promise<void> {
  const localeInput = formData.get("locale");
  const locale = typeof localeInput === "string" && isLocale(localeInput) ? localeInput : "fr";
  const persona = parsePersona(formData.get("persona"));
  if (!persona || !isPublicDemoAccessEnabled()) redirect(`/${locale}/connexion?demo=disabled`);

  const email = demoPersonaEmail(persona);
  const admin = getSupabaseAdminClient();
  const { data, error } = await admin.auth.admin.generateLink({ type: "magiclink", email });
  const tokenHash = data?.properties?.hashed_token;
  if (error || !tokenHash) redirect(`/${locale}/connexion?demo=unavailable`);

  const supabase = await getSupabaseServerClient();
  const { error: sessionError } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type: "magiclink" });
  if (sessionError) redirect(`/${locale}/connexion?demo=unavailable`);
  redirect(`/${locale}/${personaConfig[persona].destination}`);
}
