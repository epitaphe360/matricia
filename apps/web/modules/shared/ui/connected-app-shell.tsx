import { redirect } from "next/navigation";
import type { ReactNode } from "react";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { ClientAppShell, type ClientNavKey } from "@/modules/client/ui/client-app-shell";
import { FranchiseAppShell, type FranchiseNavKey } from "@/modules/franchise/ui/franchise-app-shell";
import { ProviderAppShell, type ProviderNavKey } from "@/modules/provider/ui/provider-app-shell";
import { resolveWorkspaceShell } from "@/modules/shared/lib/connected-space/workspace-shell";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

export async function ConnectedAppShell({
  locale,
  organizationId,
  title,
  lead,
  kicker,
  actions,
  clientActive,
  providerActive,
  franchiseActive,
  children,
}: {
  locale: Locale;
  organizationId?: string;
  title: string;
  lead?: string;
  kicker?: string;
  actions?: ReactNode;
  clientActive?: ClientNavKey;
  providerActive: ProviderNavKey;
  franchiseActive: FranchiseNavKey;
  children: ReactNode;
}): Promise<ReactNode> {
  const space = await resolveClientSpace({ locale, organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const kind = await resolveWorkspaceShell(space.selectedOrganizationId);
  const shared = {
    locale,
    selectedQuery: space.selectedQuery,
    selectedOrganizationId: space.selectedOrganizationId,
    userEmail: space.userEmail,
    title,
    lead,
    kicker: kicker ?? space.organizationName ?? undefined,
    actions,
    children,
  };
  if (kind === "provider") {
    return <ProviderAppShell {...shared} active={providerActive} />;
  }
  if (kind === "franchise") {
    return <FranchiseAppShell {...shared} active={franchiseActive} />;
  }
  return <ClientAppShell {...shared} organizationName={space.organizationName} active={clientActive} />;
}
