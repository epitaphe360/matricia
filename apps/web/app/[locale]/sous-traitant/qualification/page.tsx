import { notFound, redirect } from "next/navigation";
import { Alert, AlertTitle } from "@/modules/shared/ui/alert";
import { resolveProviderSpace } from "@/modules/provider/data/spaces/context";
import { providerCopy } from "@/modules/provider/data/spaces/copy";
import { loadProviderDashboard } from "@/modules/provider/data/qualification/repository";
import { QualificationBoard } from "@/modules/provider/screens/spaces/boards";
import { getProviderMessages } from "@/modules/provider/screens/qualification/messages";
import { QualificationForms } from "@/modules/provider/screens/qualification/qualification-forms";
import { ProviderActions, ProviderAppShell } from "@/modules/provider/ui/provider-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function ProviderQualificationPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveProviderSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const messages = getProviderMessages(locale);
  const result = await loadProviderDashboard();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const c = providerCopy(locale);
  return (
    <ProviderAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="qualify" title={c.qualTitle} lead={c.qualLead} kicker={c.kicker} actions={<ProviderActions href="#qualification" label={c.completeFolder} />}>
      <QualificationBoard locale={locale} query={space.selectedQuery} dashboard={result.status === "success" ? result.dashboard : null} />
      <details id="qualification" className="client-ops">
        <summary>{c.opsQual}</summary>
        {result.status === "error" ? (
          <Alert data-error-reason={result.reason} variant={result.reason === "NO_PROVIDER_ORGANIZATION" ? "default" : "destructive"}>
            <AlertTitle>{result.reason === "NO_PROVIDER_ORGANIZATION" ? messages.noProvider : messages.loadError}</AlertTitle>
          </Alert>
        ) : (
          <QualificationForms dashboard={result.dashboard} locale={locale} messages={messages} keys={{ profile: crypto.randomUUID(), service: crypto.randomUUID(), capacity: crypto.randomUUID(), document: crypto.randomUUID() }} />
        )}
      </details>
    </ProviderAppShell>
  );
}
