"use server";

import { createHash } from "node:crypto";
import { headers } from "next/headers";
import { z } from "zod";
import { getSupabaseAdminClient } from "@/lib/supabase/admin";

const inputSchema = z.object({
  locale: z.enum(["fr", "ar"]),
  category: z.enum(["CLIENT", "PROVIDER", "FRANCHISE", "OTHER"]),
  replyEmail: z.string().trim().email().max(254).transform((value) => value.toLowerCase()),
  message: z.string().trim().min(20).max(4000),
  website: z.string().max(0),
});

export type ContactActionState = { status: "idle" } | { status: "success"; reference: string } | { status: "error"; reason: "VALIDATION" | "RATE_LIMITED" | "UNAVAILABLE" };

function requesterHash(headerStore: Headers) {
  const raw = headerStore.get("cf-connecting-ip") ?? headerStore.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  return createHash("sha256").update(raw.slice(0, 128)).digest("hex");
}

export async function submitContactRequest(_: ContactActionState, formData: FormData): Promise<ContactActionState> {
  const parsed = inputSchema.safeParse({
    locale: formData.get("locale"),
    category: formData.get("category"),
    replyEmail: formData.get("replyEmail"),
    message: formData.get("message"),
    website: formData.get("website") ?? "",
  });
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };
  const headerStore = await headers();
  const result = await getSupabaseAdminClient().rpc("submit_public_contact_request", {
    p_category: parsed.data.category,
    p_reply_email: parsed.data.replyEmail,
    p_message: parsed.data.message,
    p_locale: parsed.data.locale,
    p_source_path: `/${parsed.data.locale}/contact`,
    p_ip_hash: requesterHash(headerStore),
  });
  if (result.error) return { status: "error", reason: result.error.message.includes("RATE_LIMITED") ? "RATE_LIMITED" : "UNAVAILABLE" };
  const reference = typeof result.data === "string" ? result.data.slice(0, 8).toUpperCase() : "";
  return reference ? { status: "success", reference } : { status: "error", reason: "UNAVAILABLE" };
}
