"use client";

import { createClient } from "@supabase/supabase-js";
import { getPublicEnvironment } from "@/lib/env";

let browserClient: ReturnType<typeof createClient> | undefined;

export function getSupabaseBrowserClient() {
  if (browserClient) return browserClient;
  const environment = getPublicEnvironment();
  browserClient = createClient(environment.NEXT_PUBLIC_SUPABASE_URL, environment.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
  });
  return browserClient;
}
