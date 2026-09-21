"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { isLocale, type Locale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";

const uuidSchema = z.string().uuid();
const sessionRowSchema = z.object({
  id: z.string().uuid(),
  created_at: z.string(),
  updated_at: z.string(),
  refreshed_at: z.string().nullable(),
  user_agent: z.string().nullable(),
  not_after: z.string().nullable(),
}).passthrough();

export type SafeSession = {
  id: string;
  createdAt: string;
  lastSeenAt: string;
  expiresAt: string | null;
  userAgent: string | null;
  isCurrent: boolean;
};

export type SessionsQueryResult =
  | { status: "success"; sessions: SafeSession[] }
  | { status: "error"; reason: "UNAUTHENTICATED" | "UNAVAILABLE" };

export type RevokeSessionState =
  | { status: "idle" }
  | { status: "success" }
  | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "CURRENT_SESSION" | "UNAVAILABLE" };

function safeUserAgent(value: string | null): string | null {
  if (!value) return null;
  const sanitized = value.replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim();
  return sanitized ? sanitized.slice(0, 160) : null;
}

function claimSessionId(claims: unknown): string | null {
  if (!claims || typeof claims !== "object" || !("session_id" in claims)) return null;
  const parsed = uuidSchema.safeParse((claims as { session_id?: unknown }).session_id);
  return parsed.success ? parsed.data : null;
}

async function authenticatedContext() {
  const supabase = await getSupabaseServerClient();
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) return null;
  const { data: claimsData, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError || !claimsData?.claims) return null;
  const currentSessionId = claimSessionId(claimsData.claims);
  if (!currentSessionId) return null;
  return { supabase, currentSessionId };
}

export async function listMySessions(): Promise<SessionsQueryResult> {
  const context = await authenticatedContext();
  if (!context) return { status: "error", reason: "UNAUTHENTICATED" };

  const { data, error } = await context.supabase.rpc("list_my_sessions");
  if (error) return { status: "error", reason: "UNAVAILABLE" };
  const parsed = z.array(sessionRowSchema).safeParse(data);
  if (!parsed.success) return { status: "error", reason: "UNAVAILABLE" };

  return {
    status: "success",
    sessions: parsed.data.map((session) => ({
      id: session.id,
      createdAt: session.created_at,
      lastSeenAt: session.refreshed_at ?? session.updated_at,
      expiresAt: session.not_after,
      userAgent: safeUserAgent(session.user_agent),
      isCurrent: session.id === context.currentSessionId,
    })),
  };
}

export async function revokeMySession(
  _previousState: RevokeSessionState,
  formData: FormData,
): Promise<RevokeSessionState> {
  const sessionId = uuidSchema.safeParse(formData.get("sessionId"));
  const rawLocale = formData.get("locale");
  const locale: Locale = typeof rawLocale === "string" && isLocale(rawLocale) ? rawLocale : "fr";
  if (!sessionId.success || formData.get("confirmed") !== "yes") {
    return { status: "error", reason: "VALIDATION" };
  }

  const context = await authenticatedContext();
  if (!context) return { status: "error", reason: "UNAUTHENTICATED" };
  if (context.currentSessionId === sessionId.data) {
    return { status: "error", reason: "CURRENT_SESSION" };
  }

  const { error } = await context.supabase.rpc("revoke_my_session", {
    p_session_id: sessionId.data,
    p_correlation_id: randomUUID(),
  });
  if (error) return { status: "error", reason: "UNAVAILABLE" };

  revalidatePath(`/${locale}/securite/sessions`);
  return { status: "success" };
}
