import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { loadAdminCommandCenter } from "@/modules/admin/data/command-center/repository";
import { resolveAdminSpace } from "@/modules/admin/data/spaces/context";
import { adminCopy } from "@/modules/admin/data/spaces/copy";
import { loadAdminSupervisionDashboard } from "@/modules/admin/data/supervision/repository";
import { CommandCenterPanel } from "@/modules/admin/screens/command-center/command-center-panel";
import { getCommandCenterMessages } from "@/modules/admin/screens/command-center/messages";
import { AdminDirectoryBoard } from "@/modules/admin/screens/spaces/boards";
import { AdminAppShell } from "@/modules/admin/ui/admin-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function AdminCommandCenterPage({
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
  const m = getCommandCenterMessages(locale);
  const c = adminCopy(locale);
  const [result, supervision] = await Promise.all([loadAdminCommandCenter(), loadAdminSupervisionDashboard(50)]);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const alternate = locale === "fr" ? "ar" : "fr";
  const keyCount = result.status === "success" ? result.dashboard.workItems.length * 2 + result.dashboard.actions.length + 1 : 1;
  const enrichment = supervision.status === "success" ? supervision.value.work_enrichment : {};

  return (
    <AdminAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      active="home"
      alternateHref={`/${alternate}/administration/command-center${space.selectedQuery}`}
      title={m.today}
      lead={c.homeLead}
      kicker={c.kicker}
    >
      {result.status === "error" ? (
        <Alert variant="destructive">
          <AlertTitle>{result.reason === "FORBIDDEN" ? m.forbiddenPage : result.reason === "MFA_REQUIRED" ? m.mfaRequired : m.loadError}</AlertTitle>
          <AlertDescription>{result.reason}</AlertDescription>
        </Alert>
      ) : (
        <CommandCenterPanel
          dashboard={result.dashboard}
          locale={locale}
          m={m}
          enrichment={enrichment}
          currentTime={new Date().toISOString()}
          keys={Array.from({ length: keyCount }, () => crypto.randomUUID())}
        />
      )}
      <details className="client-ops">
        <summary>{c.homeTitle}</summary>
        <AdminDirectoryBoard locale={locale} query={space.selectedQuery} />
      </details>
    </AdminAppShell>
  );
}
