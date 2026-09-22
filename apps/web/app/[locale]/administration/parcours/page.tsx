import { notFound, redirect } from "next/navigation";
import { resolveAdminSpace } from "@/modules/admin/data/spaces/context";
import { adminCopy } from "@/modules/admin/data/spaces/copy";
import { AdminHubBoard } from "@/modules/admin/screens/spaces/boards";
import { AdminAppShell, AdminCrumb } from "@/modules/admin/ui/admin-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function AdminParcoursHubPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveAdminSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const c = adminCopy(locale);
  const alternate = locale === "fr" ? "ar" : "fr";

  return (
    <AdminAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      active="parcours"
      alternateHref={`/${alternate}/administration/parcours${space.selectedQuery}`}
      crumb={
        <AdminCrumb
          locale={locale}
          query={space.selectedQuery}
          items={[
            { href: `/${locale}/administration/command-center${space.selectedQuery}`, label: c.crumbAdmin },
            { label: c.navParcours },
          ]}
        />
      }
      title={c.parcours}
      lead={c.hubParcoursLead}
      kicker={c.kicker}
    >
      <AdminHubBoard locale={locale} query={space.selectedQuery} groupId="parcours" />
    </AdminAppShell>
  );
}
