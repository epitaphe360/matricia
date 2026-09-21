import "server-only";
import { createClient } from "@supabase/supabase-js";
import { getServerEnvironment } from "@/modules/shared/lib/env";

export function getSupabaseAdminClient() {
  const environment = getServerEnvironment();
  return createClient(environment.NEXT_PUBLIC_SUPABASE_URL, environment.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
