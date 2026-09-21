import Link from "next/link";
import { Download, Plus } from "lucide-react";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { resolveAdminSpace } from "@/modules/admin/data/spaces/context";
import { adminCopy } from "@/modules/admin/data/spaces/copy";
import { demoAdminOrgRows } from "@/modules/admin/data/spaces/demo-overlay";
import { mapAdminOrgRows, mapAdminTreatQueue, demoAdminTreatQueue } from "@/modules/admin/data/spaces/view-model";
import { loadAdminCommandCenter } from "@/modules/admin/data/command-center/repository";
import { loadAdminSupervisionDashboard } from "@/modules/admin/data/supervision/repository";
import { OrganizationsBoard } from "@/modules/admin/screens/spaces/boards";
import { AdminAppShell, AdminCrumb } from "@/modules/admin/ui/admin-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function AdminEntreprisesPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string; q?: string; archives?: string }>;
}) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveAdminSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const [result, command] = await Promise.all([loadAdminSupervisionDashboard(100), loadAdminCommandCenter()]);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const c = adminCopy(locale);
  const alternate = locale === "fr" ? "ar" : "fr";
  const liveRows = result.status === "success" ? mapAdminOrgRows(result.value.organizations, locale) : [];
  const rows = liveRows.length > 0 ? liveRows : demoAdminOrgRows(locale);
  const treatFromData = result.status === "success"
    ? mapAdminTreatQueue({
        locale,
        query: space.selectedQuery,
        organizations: result.value.organizations,
        requests: result.value.requests,
        workItems: command.status === "success" ? command.dashboard.workItems : [],
      })
    : mapAdminTreatQueue({
        locale,
        query: space.selectedQuery,
        organizations: [],
        requests: [],
        workItems: command.status === "success" ? command.dashboard.workItems : [],
      });
  const treat = treatFromData.length > 0 ? treatFromData : demoAdminTreatQueue(locale, space.selectedQuery);

  return (
    <AdminAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      active="actors"
      actorCurrent="orgs"
      searchAction={`/${locale}/administration/entreprises`}
      searchPlaceholder={c.searchOrgs}
      alternateHref={`/${alternate}/administration/entreprises${space.selectedQuery}`}
      crumb={<AdminCrumb locale={locale} query={space.selectedQuery} />}
      title={c.orgs}
      lead={c.orgsLead}
      actions={
        <>
          <Link href={`/${locale}/administration/entreprises/export${space.selectedQuery}`} className="admin-dir-action" data-tone="white"><Download className="size-4" aria-hidden />{c.export}</Link>
          <Link href={`/${locale}/administration/entreprises/nouvelle${space.selectedQuery}`} className="admin-primary-cta"><Plus className="size-4" aria-hidden />{c.createOrg}</Link>
        </>
      }
    >
      {result.status === "error" && result.reason !== "FORBIDDEN" ? (
        <main className="client-page">
          <Alert variant="destructive">
            <AlertTitle>{locale === "ar" ? "تعذر التحميل" : "Chargement indisponible"}</AlertTitle>
            <AlertDescription>{result.reason}</AlertDescription>
          </Alert>
        </main>
      ) : (
        <OrganizationsBoard locale={locale} query={space.selectedQuery} rows={rows} treat={treat} search={query.q} archives={query.archives === "1"} />
      )}
    </AdminAppShell>
  );
}
