import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";

const PROVIDER_ROLES = new Set([
  "PROVIDER_OWNER",
  "PROVIDER_MANAGER",
  "PROVIDER_SALES",
  "PROVIDER_TECHNICIAN",
  "PROVIDER_VIEWER",
  "PROVIDER_ACCOUNTING",
]);
const CLIENT_ROLES = new Set([
  "CLIENT_OWNER",
  "CLIENT_ADMIN",
  "CLIENT_BUYER",
  "CLIENT_ACCOUNTING",
  "CLIENT_MEMBER",
  "CLIENT_VIEWER",
]);
const FRANCHISE_ROLES = new Set([
  "FRANCHISE_OWNER",
  "FRANCHISE_MANAGER",
  "FRANCHISE_EXPERT",
  "FRANCHISE_PROVIDER_MANAGER",
  "FRANCHISE_ACCOUNTING",
  "FRANCHISE_VIEWER",
]);

export type ConnectedWorkspaceShell = "client" | "provider" | "franchise";

export async function resolveWorkspaceShell(organizationId: string | null): Promise<ConnectedWorkspaceShell> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return "client";

  let membershipQuery = client
    .from("organization_memberships")
    .select("id")
    .eq("user_id", auth.user.id)
    .eq("status", "ACTIVE");
  if (organizationId) {
    membershipQuery = membershipQuery.eq("organization_id", organizationId);
  }
  const { data: memberships } = await membershipQuery.limit(1);
  const membershipId = memberships?.[0]?.id;
  if (!membershipId) return "client";

  const { data: roles } = await client
    .from("organization_member_roles")
    .select("role_code")
    .eq("membership_id", membershipId)
    .is("revoked_at", null)
    .limit(20);

  const roleCodes = new Set((roles ?? []).map((row) => String(row.role_code)));
  const isProvider = [...roleCodes].some((role) => PROVIDER_ROLES.has(role));
  const isClient = [...roleCodes].some((role) => CLIENT_ROLES.has(role));
  const isFranchise = [...roleCodes].some((role) => FRANCHISE_ROLES.has(role));
  if (isProvider && !isClient) return "provider";
  if (isFranchise && !isClient) return "franchise";
  return "client";
}
