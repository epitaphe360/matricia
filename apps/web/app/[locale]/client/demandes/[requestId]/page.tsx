import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Badge } from "@/modules/shared/ui/badge";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { formatMinorExact } from "@/modules/client/data/rfq/model";
import { createServerClientRfqRepository } from "@/modules/client/data/rfq/server-repository";
import { getClientRfqMessages } from "@/modules/client/screens/demandes/messages";
import { WorkflowActions } from "@/modules/client/screens/demandes/workflow-actions";
import { MatchingHistory } from "@/modules/client/screens/demandes/request-id/matching-history";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function RequestDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string; requestId: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const [{ locale, requestId }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const result = await (await createServerClientRfqRepository()).detail(requestId);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  if (result.status === "error" || !result.value) notFound();
  const q = result.value;
  const messages = getClientRfqMessages(locale);
  const c = spaceCopy(locale);
  const compareHref = q.rfqId
    ? `/${locale}/client/demandes/${q.id}/offres?rfq=${q.rfqId}${space.selectedOrganizationId ? `&organizationId=${space.selectedOrganizationId}` : ""}`
    : `/${locale}/client/demandes/${q.id}/offres${space.selectedQuery}`;

  return (
    <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="requests" title={messages.detailTitle} lead={q.description} kicker={c.kicker}>
      <main className="client-page">
        <article className="client-card">
          <header className="client-priority-head">
            <h2>{messages.detailTitle}</h2>
            <Badge>{messages.statuses[q.status]}</Badge>
          </header>
          <p className="whitespace-pre-wrap leading-7">{q.description}</p>
          <dl className="client-fact-grid">
            <div><small>{messages.budget}</small><span dir="ltr">{q.budgetMinor === null ? messages.unavailable : formatMinorExact(q.budgetMinor, q.currency, locale)}</span></div>
            <div><small>{messages.deadline}</small><span>{q.rfqDeadline ?? messages.unavailable}</span></div>
            <div><small>{messages.quotes}</small><span>{q.quoteCount}</span></div>
          </dl>
          {q.rfqId ? <Link href={compareHref} className="client-cta mt-4 inline-flex">{messages.comparison}</Link> : null}
        </article>
        <MatchingHistory locale={locale} runs={q.matchingHistory} />
        {q.canManage ? (
          <section className="client-card" aria-labelledby="workflow">
            <h2 id="workflow">{messages.workflow}</h2>
            <WorkflowActions locale={locale} requestId={q.id} rowVersion={q.rowVersion} status={q.status} matchingRunId={q.matchingRunId} messages={messages} keys={{ ready: randomUUID(), match: randomUUID(), open: randomUUID() }} />
          </section>
        ) : (
          <p role="status" className="client-card">{messages.readOnly}</p>
        )}
      </main>
    </ClientAppShell>
  );
}
