import { notFound, redirect } from "next/navigation";
import { connexionHref } from "@/modules/shared/lib/auth/connexion-href";
import { loadProviderQuotes } from "@/modules/provider/data/quotes/repository";
import { resolveProviderSpace } from "@/modules/provider/data/spaces/context";
import { providerCopy } from "@/modules/provider/data/spaces/copy";
import { consultationRowsFromInvitations, filterInvitationsByConsultTab, filterListRows, providerSearchQuery } from "@/modules/provider/data/spaces/list-rows";
import { ConsultationsBoard } from "@/modules/provider/screens/spaces/boards";
import { ProviderActions, ProviderAppShell } from "@/modules/provider/ui/provider-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function ProviderConsultationsPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string; q?: string; tab?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveProviderSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(connexionHref(locale, { next: `/${locale}/sous-traitant/consultations` }));
  const result = await loadProviderQuotes(query.organizationId);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(connexionHref(locale, { next: `/${locale}/sous-traitant/consultations` }));
  const c = providerCopy(locale);
  const boardQuery = providerSearchQuery(space.selectedQuery, { q: query.q, tab: query.tab });
  const rows = result.status === "success"
    ? filterListRows(consultationRowsFromInvitations(filterInvitationsByConsultTab(result.dashboard.invitations, query.tab), locale, space.selectedQuery), query.q ?? "")
    : [];
  return (
    <ProviderAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="consult" title={c.consultTitle} lead={c.consultLead} kicker={c.kicker} actions={<ProviderActions href={`/${locale}/sous-traitant/services${space.selectedQuery}`} label={c.seeCriteria} />}>
      <ConsultationsBoard locale={locale} query={boardQuery} rows={rows} tab={query.tab} empty={result.status === "error" ? (locale === "ar" ? "تعذر تحميل الاستشارات." : "Impossible de charger les consultations.") : undefined} />
    </ProviderAppShell>
  );
}
