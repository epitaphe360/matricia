import { notFound, redirect } from "next/navigation";
import { connexionHref } from "@/modules/shared/lib/auth/connexion-href";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { resolveAdminSpace } from "@/modules/admin/data/spaces/context";
import { adminCopy } from "@/modules/admin/data/spaces/copy";
import { loadAdminOrganizationFiche } from "@/modules/admin/data/supervision/repository";
import { EditOrganizationForm } from "@/modules/admin/screens/spaces/org-forms";
import { AdminAppShell, AdminCrumb } from "@/modules/admin/ui/admin-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function AdminEnterpriseEditPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string; organizationId: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const [{ locale, organizationId }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveAdminSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(connexionHref(locale, { next: `/${locale}/administration/entreprises/${organizationId}/modifier` }));
  const result = await loadAdminOrganizationFiche(organizationId);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(connexionHref(locale, { next: `/${locale}/administration/entreprises/${organizationId}/modifier` }));
  if (result.status === "error" && result.reason === "NOT_FOUND") notFound();
  const c = adminCopy(locale);
  const alternate = locale === "fr" ? "ar" : "fr";
  const org = result.status === "success" ? result.value.organization : null;

  return (
    <AdminAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      active="actors"
      actorCurrent="orgs"
      searchAction={`/${locale}/administration/entreprises`}
      searchPlaceholder={c.searchList}
      alternateHref={`/${alternate}/administration/entreprises/${organizationId}/modifier${space.selectedQuery}`}
      crumb={<AdminCrumb locale={locale} query={space.selectedQuery} organizationName={org?.display_name} current={c.edit} />}
      title={c.editOrg}
      lead={c.editLead}
    >
      {result.status === "error" || !org ? (
        <main className="client-page">
          <Alert variant="destructive">
            <AlertTitle>{result.status === "error" && result.reason === "FORBIDDEN" ? (locale === "ar" ? "رفض الوصول" : "Accès refusé") : (locale === "ar" ? "تعذر التحميل" : "Chargement indisponible")}</AlertTitle>
            <AlertDescription>{result.status === "error" ? result.reason : "UNAVAILABLE"}</AlertDescription>
          </Alert>
        </main>
      ) : (
        <main className="client-page">
          <EditOrganizationForm
            locale={locale}
            query={space.selectedQuery}
            organizationId={org.id}
            displayName={org.display_name}
            legalName={org.legal_name}
            status={org.status}
            country={org.country_code}
            updatedAt={org.updated_at}
          />
        </main>
      )}
    </AdminAppShell>
  );
}
