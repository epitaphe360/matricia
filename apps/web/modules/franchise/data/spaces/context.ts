import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

export async function resolveFranchiseSpace(input: { locale: Locale; organizationId?: string;franchiseId?:string }) {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "unauthenticated" as const };
  const selectedOrganizationId = input.organizationId ?? null;
  const params=new URLSearchParams();if(selectedOrganizationId)params.set("organizationId",selectedOrganizationId);if(input.franchiseId)params.set("franchiseId",input.franchiseId);
  const selectedQuery=params.size?`?${params}`:"";
  const organizationName = selectedOrganizationId
    ? (await client.from("organizations").select("display_name").eq("id", selectedOrganizationId).limit(1)).data?.[0]?.display_name ?? null
    : null;
  return {
    status: "success" as const,
    locale: input.locale,
    userEmail: auth.user.email ?? null,
    selectedOrganizationId,
    selectedQuery,
    organizationName,
  };
}
