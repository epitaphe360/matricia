"use server";

import { redirect } from "next/navigation";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";

export type DemoPersona = "client" | "provider" | "franchise" | "admin";

const personaConfig = {
  client: { envPrefix: "MATRICIA_DEMO_CLIENT", destination: "tableau-de-bord" },
  provider: { envPrefix: "MATRICIA_DEMO_PROVIDER", destination: "tableau-de-bord" },
  franchise: { envPrefix: "MATRICIA_DEMO_FRANCHISE", destination: "franchise/accueil" },
  admin: { envPrefix: "MATRICIA_DEMO_ADMIN", destination: "administration/command-center" },
} as const satisfies Record<DemoPersona, { envPrefix: string; destination: string }>;

function isDemoAccessEnabled(): boolean {
  return process.env.MATRICIA_DEMO_ACCESS_ENABLED === "true" && process.env.APP_ENV !== "production";
}

function parsePersona(value: FormDataEntryValue | null): DemoPersona | null {
  return value === "client" || value === "provider" || value === "franchise" || value === "admin" ? value : null;
}

export async function connectDemoPersona(formData: FormData): Promise<void> {
  const localeInput = formData.get("locale");
  const locale = typeof localeInput === "string" && isLocale(localeInput) ? localeInput : "fr";
  const persona = parsePersona(formData.get("persona"));
  if (!persona || !isDemoAccessEnabled()) redirect(`/${locale}/connexion?demo=disabled`);

  const config = personaConfig[persona];
  const email = process.env[`${config.envPrefix}_EMAIL`]?.trim();
  const password = process.env[`${config.envPrefix}_PASSWORD`];
  if (!email || !password) redirect(`/${locale}/connexion?demo=unavailable`);

  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) redirect(`/${locale}/connexion?demo=unavailable`);
  redirect(`/${locale}/${config.destination}`);
}
