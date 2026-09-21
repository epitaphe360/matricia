import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

export async function resolveProviderSpace(input: { locale: Locale; organizationId?: string }) {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "unauthenticated" as const };
  const selectedOrganizationId = input.organizationId ?? null;
  const selectedQuery = selectedOrganizationId ? `?organizationId=${encodeURIComponent(selectedOrganizationId)}` : "";
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
