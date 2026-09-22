import { notFound, redirect } from "next/navigation";
import { connexionHref } from "@/modules/shared/lib/auth/connexion-href";
import { z } from "zod";
import { resolveAdminSpace } from "@/modules/admin/data/spaces/context";
import { actorCopy } from "@/modules/admin/data/spaces/actors-copy";
import { loadAdminActorUser } from "@/modules/admin/data/spaces/actors-repository";
import { EditUserRolesForm } from "@/modules/admin/screens/spaces/actor-forms";
import { AdminAppShell, AdminCrumb } from "@/modules/admin/ui/admin-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function AdminUserRolesPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string; userId: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const [{ locale, userId }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale) || !z.string().uuid().safeParse(userId).success) notFound();
  const space = await resolveAdminSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(connexionHref(locale, { next: `/${locale}/administration/utilisateurs/${userId}/roles` }));
  const result = await loadAdminActorUser(userId);
  const row = result.rows[0];
  if (!row) notFound();
  const a = actorCopy(locale);
  const alternate = locale === "ar" ? "fr" : "ar";

  return (
    <AdminAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      active="actors"
      actorCurrent="users"
      searchAction={`/${locale}/administration/utilisateurs`}
      searchPlaceholder={a.searchUsers}
      alternateHref={`/${alternate}/administration/utilisateurs/${userId}/roles${space.selectedQuery}`}
      crumb={<AdminCrumb locale={locale} query={space.selectedQuery} items={[{ href: `/${locale}/administration/entreprises${space.selectedQuery}`, label: locale === "ar" ? "الفاعلون" : "Acteurs" }, { href: `/${locale}/administration/utilisateurs${space.selectedQuery}`, label: a.usersTitle }, { href: `/${locale}/administration/utilisateurs/${userId}${space.selectedQuery}`, label: row.organizationName }, { label: a.editRoles }]} />}
      title={a.editRoles}
      lead={a.editRolesLead}
      kicker={locale === "ar" ? "وصول مضبوط لنظام أكثر أماناً" : "Des accès maîtrisés pour un écosystème plus sûr"}
    >
      <main className="client-page">
        <EditUserRolesForm
          locale={locale}
          query={space.selectedQuery}
          userId={userId}
          organizationId={row.organizationId}
          organizationName={row.organizationName}
          currentRole={row.roles[0] ?? "CLIENT_MEMBER"}
        />
      </main>
    </AdminAppShell>
  );
}
