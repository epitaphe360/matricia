import { notFound, redirect } from "next/navigation";
import { loadProviderDashboard } from "@/modules/provider/data/qualification/repository";
import { resolveProviderSpace } from "@/modules/provider/data/spaces/context";
import { providerCopy } from "@/modules/provider/data/spaces/copy";
import { ProviderDocumentsBoard } from "@/modules/provider/screens/spaces/boards";
import { ProviderActions, ProviderAppShell } from "@/modules/provider/ui/provider-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function ProviderDocumentsPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string; q?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveProviderSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const result = await loadProviderDashboard();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const c = providerCopy(locale);
  return (
    <ProviderAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="documents" title={c.docsTitle} lead={c.docsLead} kicker={c.kicker} actions={<ProviderActions href={`/${locale}/sous-traitant/qualification${space.selectedQuery}#documents`} label={c.addPiece} />}>
      <ProviderDocumentsBoard locale={locale} query={space.selectedQuery} documents={result.status === "success" ? result.dashboard.documents : []} loadError={result.status === "error"} search={query.q ?? ""} />
    </ProviderAppShell>
  );
}
