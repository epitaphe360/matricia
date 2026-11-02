import { notFound } from "next/navigation";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

/** Account security is available before an organization or a workspace role exists. */
export async function resolveConnectedSpace(input: { locale: Locale; organizationId?: string }) {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "unauthenticated" as const };
  const result = await client.from("organization_memberships").select("organization_id").eq("user_id", auth.user.id).eq("status", "ACTIVE").order("organization_id");
  if (result.error) throw new Error("WORKSPACE_CONTEXT_UNAVAILABLE");
  const organizationIds = [...new Set((result.data ?? []).map(row => row.organization_id))];
  if (input.organizationId && !organizationIds.includes(input.organizationId)) notFound();
  const selectedOrganizationId = input.organizationId ?? organizationIds[0] ?? null;
  const organization = selectedOrganizationId ? await client.from("organizations").select("display_name").eq("id",selectedOrganizationId).maybeSingle() : null;
  if (organization?.error) throw new Error("WORKSPACE_CONTEXT_UNAVAILABLE");
  return { status: "success" as const, selectedOrganizationId, selectedQuery: selectedOrganizationId ? `?organizationId=${encodeURIComponent(selectedOrganizationId)}` : "", organizationName: organization?.data?.display_name ?? null, userEmail: auth.user.email ?? null };
}
