"use server";

import { headers } from "next/headers";
import { normalizeEmail } from "@/lib/auth/otp";
import { isLocale, type Locale } from "@/lib/i18n/locale";
import { getServerEnvironment } from "@/lib/env";
import { getSupabaseAdminClient } from "@/lib/supabase/admin";

export type OtpRequestResult = { accepted: true } | { accepted: false; reason: "INVALID_EMAIL" };

function clientIp(headerStore: Headers): string | null {
  const candidate = headerStore.get("cf-connecting-ip") ?? headerStore.get("x-forwarded-for")?.split(",")[0]?.trim();
  if (!candidate || candidate.length > 45 || !/^[0-9a-f:.]+$/i.test(candidate)) return null;
  return candidate;
}

function safeNextPath(value: string | undefined, locale: Locale): string {
  if (!value || !value.startsWith("/" + locale + "/") || value.startsWith("//") || value.includes("\\") || value.length > 1000) return "/" + locale + "/tableau-de-bord";
  return value;
}

export async function requestOtp(emailInput: string, localeInput: string, nextPathInput?: string): Promise<OtpRequestResult> {
  const email = normalizeEmail(emailInput);
  if (!email) return { accepted: false, reason: "INVALID_EMAIL" };
  const locale: Locale = isLocale(localeInput) ? localeInput : "fr";
  const nextPath = safeNextPath(nextPathInput, locale);
  const environment = getServerEnvironment();
  const admin = getSupabaseAdminClient();
  const headerStore = await headers();
  const { data, error } = await admin.rpc("reserve_otp_request", {
    p_identifier: email,
    p_client_ip: clientIp(headerStore),
  });

  const quota = Array.isArray(data) ? data[0] : data;
  if (!error && quota?.allowed === true) {
    await admin.auth.signInWithOtp({
      email,
      options: {
        shouldCreateUser: false,
        emailRedirectTo: environment.NEXT_PUBLIC_APP_URL + "/" + locale + "/auth/callback?next=" + encodeURIComponent(nextPath),
      },
    });
  }

  // Même résultat pour compte absent, limite atteinte, indisponibilité et succès.
  return { accepted: true };
}
