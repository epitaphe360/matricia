import { notFound } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { libraryCopy } from "@/modules/franchise/data/library/copy";
import { MandateBanner } from "@/modules/franchise/screens/library/library-boards";
import { FranchiseMandateRail } from "@/modules/franchise/screens/library/library-chrome";
import { requireFranchiseLibrary } from "@/modules/franchise/screens/library/page-helper";
import { FranchiseAppShell } from "@/modules/franchise/ui/franchise-app-shell";

export default async function FranchiseLibraryPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string; q?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const { space, result } = await requireFranchiseLibrary({ locale, organizationId: query.organizationId });
  const c = libraryCopy(locale);
  const needle = (query.q ?? "").trim().toLowerCase();
  return (
    <FranchiseAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="library" title={c.libraryTitle} lead={c.libraryLead} kicker={c.scope} mandateName={result.status === "success" ? result.workspace.mandate.libraryName : null}>
      {result.status === "error" ? (
        <Alert variant="destructive"><AlertTitle>{c.unavailable}</AlertTitle><AlertDescription>{result.reason === "NO_MANDATE" ? c.noMandate : c.scopeHelp}</AlertDescription></Alert>
      ) : (
        <main className="client-page">
          <MandateBanner locale={locale} name={result.workspace.mandate.libraryName} />
          <section className="franchise-workbench">
            <article className="client-card">
              <header><h2>{result.workspace.mandate.libraryName}</h2></header>
              <p><bdi dir="ltr">{result.workspace.mandate.libraryCode}</bdi></p>
              <dl className="franchise-props">
                <div><small>{c.drafts}</small><span dir="ltr">{result.workspace.counts.drafts}</span></div>
                <div><small>{c.inReview}</small><span dir="ltr">{result.workspace.counts.inReview}</span></div>
                <div><small>{c.published}</small><span dir="ltr">{result.workspace.counts.published}</span></div>
              </dl>
            </article>
            <article className="client-card">
              <header><h2>{c.queue}</h2></header>
              <ul className="client-feed">
                {[...result.workspace.services, ...result.workspace.questionnaires, ...result.workspace.rules]
                  .filter((item) => !needle || item.title.toLowerCase().includes(needle) || item.code.toLowerCase().includes(needle))
                  .slice(0, 20)
                  .map((item) => (
                    <li key={`${item.kind}-${item.id}`}><span><strong>{item.title}</strong><small>{item.code}</small></span></li>
                  ))}
              </ul>
            </article>
            <FranchiseMandateRail locale={locale} name={result.workspace.mandate.libraryName} />
          </section>
        </main>
      )}
    </FranchiseAppShell>
  );
}
