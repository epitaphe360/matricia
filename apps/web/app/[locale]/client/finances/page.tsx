import { notFound, redirect } from "next/navigation";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { FinancesBoard } from "@/modules/client/screens/spaces/boards";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function ClientFinancesPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const c = spaceCopy(locale);
  return (
    <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="finance" title={c.finTitle} lead={c.finLead} kicker={c.kicker}>
      <FinancesBoard locale={locale} query={space.selectedQuery} organizationName={space.organizationName} />
    </ClientAppShell>
  );
}
