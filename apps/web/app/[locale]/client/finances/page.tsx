import { notFound, redirect } from "next/navigation";
import { isDocumentExpired } from "@/modules/client/data/documents/expiry";
import { loadClientDocumentVault } from "@/modules/client/data/documents/server-repository";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { FinancesBoard } from "@/modules/client/screens/spaces/boards";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { resolveClientOrganizationContext } from "@/modules/shared/client-organization-context";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function ClientFinancesPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const result = await loadClientDocumentVault(query.organizationId);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const c = spaceCopy(locale);
  const context = result.status === "success"
    ? resolveClientOrganizationContext(result.value.organizations.map((organization) => ({ organization_id: organization.id })), query.organizationId)
    : null;
  const selectedId = context?.status === "success" ? context.membership.organization_id : null;
  const documents = result.status === "success" && selectedId
    ? result.value.documents.filter((document) => document.organizationId === selectedId)
    : [];
  const bindings = result.status === "success" && selectedId
    ? result.value.bindings.filter((binding) => binding.organizationId === selectedId)
    : [];
  const targets = result.status === "success" && selectedId
    ? result.value.targets.filter((target) => target.organizationId === selectedId)
    : [];
  const financialTypes = /facture|invoice|avoir|credit|paiement|payment|abonnement|subscription|tax|tva|fiscal/i;
  const rows = documents
    .filter((document) => financialTypes.test(`${document.type} ${document.fileName}`))
    .map((document) => {
      const binding = bindings.find((item) => item.documentId === document.id && !item.revokedAt);
      const target = binding ? targets.find((item) => item.id === binding.targetId) : null;
      const expired = isDocumentExpired(document.expiresOn);
      return {
        id: document.id,
        title: document.fileName,
        folder: target?.label ?? document.type,
        status: expired ? (locale === "ar" ? "للمراجعة" : "À examiner") : (locale === "ar" ? "متاح" : "Disponible"),
        next: expired ? (locale === "ar" ? "مراجعة المستند" : "Vérifier le document") : (locale === "ar" ? "فتح المستند" : "Ouvrir le document"),
        href: `/${locale}/client/documents${space.selectedQuery}`,
        tone: expired ? "peach" as const : "mint" as const,
      };
    });
  return (
    <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} organizationName={space.organizationName} active="finance" title={c.finTitle} lead={c.finLead} kicker={c.kicker}>
      <FinancesBoard locale={locale} query={space.selectedQuery} organizationName={space.organizationName} rows={rows} />
    </ClientAppShell>
  );
}
