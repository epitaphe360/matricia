import { notFound, redirect } from "next/navigation";
import { createServerClientRfqRepository } from "@/modules/client/data/rfq/server-repository";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { getClientRfqMessages } from "@/modules/client/screens/demandes/messages";
import { RequestsBoard, SpaceActions, SpaceFilters } from "@/modules/client/screens/spaces/boards";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function RequestsPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const result = await (await createServerClientRfqRepository()).list();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const messages = getClientRfqMessages(locale);
  const c = spaceCopy(locale);
  const selected = space.selectedOrganizationId;
  const rows = result.status === "success"
    ? result.value.requests.filter((request) => !selected || request.organizationId === selected).map((request) => ({
      id: request.id,
      title: request.description,
      status: messages.statuses[request.status],
      last: new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium" }).format(new Date(request.createdAt)),
      next: request.quoteCount > 0 ? c.compareCta : c.open,
      href: `/${locale}/client/demandes/${request.id}${space.selectedQuery}`,
      tone: (request.quoteCount > 0 ? "mint" : request.status === "DRAFT" ? "violet" : "sky") as "violet" | "sky" | "mint" | "peach",
    }))
    : [];
  const compareHref = rows[0] ? rows[0].href : `/${locale}/client/demandes${space.selectedQuery}`;
  return (
    <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="requests" title={c.reqTitle} lead={c.reqLead} kicker={c.kicker} actions={<><SpaceActions href={`/${locale}/besoin${space.selectedQuery}`} label={c.newNeed} /><SpaceActions href={`/${locale}/client/demandes/recurrence${space.selectedQuery}`} label={c.cloneRequest} variant="soft" /><SpaceFilters href="#filtres" label={c.filters} /></>}>
      <RequestsBoard locale={locale} query={space.selectedQuery} compareHref={compareHref} rows={rows} organizationName={space.organizationName} />
    </ClientAppShell>
  );
}
