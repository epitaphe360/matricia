import "server-only";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { officialRegionCodes, providerRegionsRowSchema } from "./regions";

/** Current intervention regions of the provider, read under RLS. `null` when they cannot be read. */
export async function loadProviderRegions(organizationId: string): Promise<string[] | null> {
  const client = await getSupabaseServerClient();
  const result = await client
    .from("provider_match_profiles")
    .select("region_codes")
    .eq("provider_organization_id", organizationId)
    .maybeSingle();
  if (result.error) return null;
  if (!result.data) return [];
  const parsed = providerRegionsRowSchema.safeParse(result.data);
  return parsed.success ? officialRegionCodes(parsed.data.region_codes) : null;
}
