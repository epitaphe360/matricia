import { randomUUID } from "node:crypto";
import type { ReactNode } from "react";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Badge } from "@/modules/shared/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/modules/shared/ui/card";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { SolutionDecisionAccess } from "@/modules/client/screens/diagnostics/solutions/decision-access";
import { messages } from "@/modules/client/screens/diagnostics/solutions/messages";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { formatExactDecimal, formatMinorExact, formatScoreBps, formatSolutionDate, narrativeText } from "@/modules/shared/lib/solution-insights/model";
import { createServerSolutionInsightsRepository } from "@/modules/shared/lib/solution-insights/server-repository";

export default async function SolutionsPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string; anomalyId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const m = messages(locale);
  const result = await (await createServerSolutionInsightsRepository()).list();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const shell = (title: string, lead: string, children: ReactNode) => (
    <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="needs" title={title} lead={lead} kicker={spaceCopy(locale).kicker}>{children}</ClientAppShell>
  );
  if (result.status === "error" && result.reason === "FORBIDDEN") {
    return shell(m.forbidden, m.forbidden, <main className="client-page" role="alert"><p>{m.forbidden}</p></main>);
  }
  if (result.status === "error") throw new Error("SOLUTION_INSIGHTS_UNAVAILABLE");
  const focused = query.anomalyId ? result.value.sets.filter((set) => set.anomalyId === query.anomalyId) : [];
  const orderedSets = focused.length ? [...focused, ...result.value.sets.filter((set) => set.anomalyId !== query.anomalyId)] : result.value.sets;
  const diagnosticHref = `/${locale}/client/diagnostics${space.selectedQuery}`;
  const bundleNeedHref = (title: string) => {
    const params = new URLSearchParams(space.selectedQuery.startsWith("?") ? space.selectedQuery.slice(1) : space.selectedQuery);
    params.set("q", title);
    return `/${locale}/besoin?${params.toString()}`;
  };

  return shell(m.title, m.intro, <main className="client-page space-y-8">
    <p><Link href={diagnosticHref} className="client-text-link">{m.backDiagnostic}</Link></p>
    {query.anomalyId && focused.length > 0 ? <p role="status" className="client-card">{m.focusedAnomaly}</p> : null}
    <section className="space-y-5" aria-label={m.title}>
      {orderedSets.length === 0 ? <p className="rounded-xl border bg-card p-5">{m.empty}</p> : orderedSets.map((set) => <Card key={set.id}><CardHeader><div className="flex flex-wrap items-center justify-between gap-2"><CardTitle>{m.rationale}</CardTitle><Badge>v{set.version}</Badge></div><p>{locale === "ar" ? set.rationaleAr : set.rationaleFr}</p></CardHeader><CardContent className="grid gap-4 lg:grid-cols-3">
        {set.options.map((option) => <article key={option.id} className="min-w-0 rounded-xl border p-4"><h2 className="text-lg font-semibold">{m.levels[option.level]}</h2><dl className="mt-3 space-y-2"><div><dt className="font-medium">{m.expected}</dt><dd dir="ltr">{formatScoreBps(option.expectedScoreBps, locale)}</dd></div><div><dt className="font-medium">{m.amount}</dt><dd dir="ltr">{option.estimatedAmountMinor && option.currency ? formatMinorExact(option.estimatedAmountMinor, option.currency, locale) : m.unavailable}</dd></div></dl>
          {option.benefits.length > 0 ? <section className="mt-4"><h3 className="font-medium">{m.benefits}</h3><ul className="mt-2 list-disc space-y-1 ps-5">{option.benefits.map((item, index) => <li key={index}>{narrativeText(item, locale)}</li>)}</ul></section> : null}
          {option.tradeoffs.length > 0 ? <section className="mt-4"><h3 className="font-medium">{m.tradeoffs}</h3><ul className="mt-2 list-disc space-y-1 ps-5">{option.tradeoffs.map((item, index) => <li key={index}>{narrativeText(item, locale)}</li>)}</ul></section> : null}
          {Object.keys(option.explanation).length > 0 ? <section className="mt-4"><h3 className="font-medium">{m.explanation}</h3><dl className="mt-2 space-y-2">{Object.entries(option.explanation).map(([key, value]) => <div key={key} className="min-w-0"><dt className="break-words text-sm text-muted-foreground">{key}</dt><dd className="break-words">{narrativeText(value, locale)}</dd></div>)}</dl></section> : null}
          <SolutionDecisionAccess canDecide={set.canDecide} locale={locale} solutionSetId={set.id} level={option.level} idempotencyKey={randomUUID()} messages={m} />
        </article>)}
      </CardContent></Card>)}
    </section>
    <section aria-labelledby="solution-bundles"><h2 id="solution-bundles" className="text-2xl font-semibold">{m.bundles}</h2>{result.value.bundles.length === 0 ? <p className="mt-3 rounded-xl border bg-card p-5">{m.noBundles}</p> : <div className="mt-3 grid gap-4 lg:grid-cols-2">{result.value.bundles.map((bundle) => <Card key={bundle.id}><CardHeader><div className="flex flex-wrap items-center justify-between gap-2"><CardTitle>{locale === "ar" ? bundle.titleAr : bundle.titleFr}</CardTitle><Badge>v{bundle.version}</Badge></div><p className="break-words">{locale === "ar" ? bundle.descriptionAr : bundle.descriptionFr}</p><p role="status" className="rounded-lg border border-primary/20 bg-primary/5 p-3 text-sm">{m.humanBundleDecision}</p></CardHeader><CardContent className="space-y-4"><dl className="grid gap-2 text-sm sm:grid-cols-2"><div><dt className="font-medium">{m.libraries}</dt><dd className="break-words" dir="ltr">{bundle.libraryCodes.join(" · ")}</dd></div><div><dt className="font-medium">{m.amount}</dt><dd dir="ltr">{formatMinorExact(bundle.totalAmountMinor, bundle.currency, locale)}</dd></div><div className="sm:col-span-2"><dt className="font-medium">{m.manifest}</dt><dd className="break-all font-mono text-xs" dir="ltr">{bundle.sourceManifestHash}</dd></div></dl><Link href={bundleNeedHref(locale === "ar" ? bundle.titleAr : bundle.titleFr)} className="client-ghost-link">{m.launchBundleNeed}</Link><details className="rounded-lg border p-3"><summary className="cursor-pointer font-medium focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">{m.bundleItems}</summary><ol className="mt-3 space-y-3">{bundle.items.map((item) => <li key={item.id} className="min-w-0 rounded-lg bg-muted/50 p-3"><p className="break-words font-medium">{item.dedupeKey}</p><p className="text-sm text-muted-foreground" dir="ltr">{item.fusionStrategy} · {formatMinorExact(item.amountMinor, bundle.currency, locale)}</p><details className="mt-2"><summary className="cursor-pointer text-sm font-medium">{m.bundleProvenance}</summary><pre className="mt-2 overflow-x-auto whitespace-pre-wrap break-words text-xs" dir="ltr">{JSON.stringify(item.provenance, null, 2)}</pre></details></li>)}</ol></details></CardContent></Card>)}</div>}</section>
    <section aria-labelledby="benchmarks"><h2 id="benchmarks" className="text-2xl font-semibold">{m.benchmarks}</h2>{result.value.benchmarks.length === 0 ? <p className="mt-3 rounded-xl border bg-card p-5">{m.noBenchmarks}</p> : <div className="mt-3 grid gap-3 sm:grid-cols-2">{result.value.benchmarks.map((item) => <Card key={item.id}><CardContent className="space-y-1 pt-6"><h3 className="break-words font-semibold">{item.metricCode}</h3><p className="break-words">{item.segmentKey}</p><p>{m.period}: <time dateTime={item.periodStart}>{formatSolutionDate(item.periodStart, locale)}</time> – <time dateTime={item.periodEnd}>{formatSolutionDate(item.periodEnd, locale)}</time></p><p>{m.group}: {item.groupSizeBand}</p><p>{m.mean}: <span dir="ltr">{formatExactDecimal(item.roundedMean, locale)}</span></p><p>{m.published}: <time dateTime={item.publishedAt}>{formatSolutionDate(item.publishedAt, locale)}</time></p></CardContent></Card>)}</div>}</section>
  </main>);
}
