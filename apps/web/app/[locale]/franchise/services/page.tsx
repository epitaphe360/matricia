import { randomUUID } from "node:crypto";
import { notFound } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { libraryCopy } from "@/modules/franchise/data/library/copy";
import { FranchiseServicesWorkbench } from "@/modules/franchise/screens/library/library-workbenches";
import { requireFranchiseLibrary } from "@/modules/franchise/screens/library/page-helper";
import { FranchiseSecurityPanel } from "@/modules/franchise/screens/library/library-chrome";
import { FranchiseAppShell } from "@/modules/franchise/ui/franchise-app-shell";

export default async function FranchiseServicesPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string; serviceId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const { space, result } = await requireFranchiseLibrary({ locale, organizationId: query.organizationId });
  const c = libraryCopy(locale);
  return (
    <FranchiseAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="services" title={c.servicesTitle} lead={c.servicesLead} kicker={c.scope} mandateName={result.status === "success" ? result.workspace.mandate.libraryName : null} actions={result.status === "success" ? <FranchiseSecurityPanel locale={locale} /> : null}>
      {result.status === "error" ? (
        <Alert variant="destructive"><AlertTitle>{c.unavailable}</AlertTitle><AlertDescription>{result.reason === "NO_MANDATE" ? c.noMandate : c.scopeHelp}</AlertDescription></Alert>
      ) : (
        <FranchiseServicesWorkbench
          locale={locale}
          query={space.selectedQuery}
          workspace={result.workspace}
          selectedId={query.serviceId ?? null}
          createMode={false}
          organizationId={space.selectedOrganizationId}
          commandIdentity={{ idempotencyKey: randomUUID(), correlationId: randomUUID() }}
        />
      )}
    </FranchiseAppShell>
  );
}
