import { redirect } from "next/navigation";
import { loadMyPlatformAccess } from "@/modules/shared/lib/account-security/platform-access";
import { PLATFORM_ADMIN_ROLES } from "@/modules/shared/lib/connected-space/workspace-landing";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

export async function resolveAdminSpace(input: { locale: Locale; organizationId?: string }) {
  const access = await loadMyPlatformAccess();
  if (access.status === "error" && access.reason === "UNAUTHENTICATED") return { status: "unauthenticated" as const };
  // The administration shell is never served to a non-administrator: send them
  // back to the dashboard, which routes each account to its own space.
  if (access.status !== "ok" || !PLATFORM_ADMIN_ROLES.some((role) => access.roles.has(role))) {
    redirect(`/${input.locale}/tableau-de-bord`);
  }
  const selectedOrganizationId = input.organizationId ?? null;
  const selectedQuery = selectedOrganizationId ? `?organizationId=${encodeURIComponent(selectedOrganizationId)}` : "";
  return {
    status: "success" as const,
    locale: input.locale,
    userEmail: access.email,
    selectedOrganizationId,
    selectedQuery,
  };
}
