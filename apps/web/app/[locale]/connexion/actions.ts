"use server";

import { headers } from "next/headers";
import { normalizeEmail } from "@/modules/shared/lib/auth/otp";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseAdminClient } from "@/modules/shared/lib/supabase/admin";

export type OtpRequestResult = { accepted: true } | { accepted: false; reason: "INVALID_EMAIL" };

function clientIp(headerStore: Headers): string | null {
  const candidate = headerStore.get("cf-connecting-ip") ?? headerStore.get("x-forwarded-for")?.split(",")[0]?.trim();
  if (!candidate || candidate.length > 45 || !/^[0-9a-f:.]+$/i.test(candidate)) return null;
  return candidate;
}

export async function requestOtp(emailInput: string, localeInput: string, _nextPathInput?: string, intentInput?: string): Promise<OtpRequestResult> {
  const email = normalizeEmail(emailInput);
  if (!email) return { accepted: false, reason: "INVALID_EMAIL" };
  const locale = isLocale(localeInput) ? localeInput : "fr";
  const isRegistration = intentInput === "registration";
  const admin = getSupabaseAdminClient();
  const headerStore = await headers();
  const { data, error } = await admin.rpc("reserve_otp_request", {
    p_identifier: email,
    p_client_ip: clientIp(headerStore),
  });

  const quota = Array.isArray(data) ? data[0] : data;
  if (!error && quota?.allowed === true) {
    // Omit emailRedirectTo: that option makes Auth send a Magic Link instead of the 6-digit OTP.
    await admin.auth.signInWithOtp({
      email,
      options: {
        shouldCreateUser: isRegistration,
        ...(isRegistration ? { data: { locale } } : {}),
      },
    });
  }

  // Même résultat pour compte absent, limite atteinte, indisponibilité et succès.
  return { accepted: true };
}
