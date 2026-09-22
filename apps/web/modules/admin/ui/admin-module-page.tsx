import { redirect } from "next/navigation";
import type { ReactNode } from "react";
import { resolveAdminSpace } from "@/modules/admin/data/spaces/context";
import type { AdminDirectoryGroup } from "@/modules/admin/data/spaces/directory";
import { AdminHubStrip } from "@/modules/admin/screens/spaces/boards";
import { AdminAppShell, type AdminNavKey } from "@/modules/admin/ui/admin-app-shell";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

export async function AdminModulePage({
  locale,
  active,
  path,
  title,
  lead,
  kicker,
  querySuffix,
  hubGroup,
  children,
}: {
  locale: Locale;
  active: AdminNavKey;
  path: string;
  title: string;
  lead?: string;
  kicker?: string;
  querySuffix?: string;
  hubGroup?: AdminDirectoryGroup["id"];
  children: ReactNode;
}) {
  const space = await resolveAdminSpace({ locale });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const alternate = locale === "fr" ? "ar" : "fr";
  const query = querySuffix
    ? (space.selectedQuery ? `${space.selectedQuery}&${querySuffix}` : `?${querySuffix}`)
    : space.selectedQuery;
  return (
    <AdminAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      active={active}
      alternateHref={`/${alternate}/administration/${path}${query}`}
      title={title}
      lead={lead}
      kicker={kicker}
    >
      {hubGroup ? (
        <div className="client-page admin-hub-wrap">
          <AdminHubStrip locale={locale} query={space.selectedQuery} groupId={hubGroup} />
        </div>
      ) : null}
      {children}
    </AdminAppShell>
  );
}
