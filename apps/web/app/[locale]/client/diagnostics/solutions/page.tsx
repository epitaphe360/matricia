import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { isLocale } from "@/lib/i18n/locale";
import { formatExactDecimal, formatMinorExact, formatScoreBps, formatSolutionDate, narrativeText } from "@/lib/solution-insights/model";
import { createServerSolutionInsightsRepository } from "@/lib/solution-insights/server-repository";
import { SolutionDecisionAccess } from "./decision-access";
import { messages } from "./messages";
export default async function SolutionsPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const m = messages(locale);
  const result = await (await createServerSolutionInsightsRepository()).list();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  if (result.status === "error" && result.reason === "FORBIDDEN") return <main className="min-h-dvh bg-muted/40 px-4 py-8 sm:px-6"><section role="alert" className="mx-auto max-w-3xl rounded-2xl border bg-card p-6"><h1 className="text-2xl font-semibold">{m.forbidden}</h1></section></main>;
  if (result.status === "error") throw new Error("SOLUTION_INSIGHTS_UNAVAILABLE");

  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6"><div className="mx-auto max-w-6xl space-y-8">
    <header><h1 className="text-3xl font-semibold">{m.title}</h1><p className="mt-2 max-w-3xl text-muted-foreground">{m.intro}</p></header>
    <section className="space-y-5" aria-label={m.title}>
      {result.value.sets.length === 0 ? <p className="rounded-xl border bg-card p-5">{m.empty}</p> : result.value.sets.map((set) => <Card key={set.id}><CardHeader><div className="flex flex-wrap items-center justify-between gap-2"><CardTitle>{m.rationale}</CardTitle><Badge>v{set.version}</Badge></div><p>{locale === "ar" ? set.rationaleAr : set.rationaleFr}</p></CardHeader><CardContent className="grid gap-4 lg:grid-cols-3">
        {set.options.map((option) => <article key={option.id} className="min-w-0 rounded-xl border p-4"><h2 className="text-lg font-semibold">{m.levels[option.level]}</h2><dl className="mt-3 space-y-2"><div><dt className="font-medium">{m.expected}</dt><dd dir="ltr">{formatScoreBps(option.expectedScoreBps, locale)}</dd></div><div><dt className="font-medium">{m.amount}</dt><dd dir="ltr">{option.estimatedAmountMinor && option.currency ? formatMinorExact(option.estimatedAmountMinor, option.currency, locale) : m.unavailable}</dd></div></dl>
          {option.benefits.length > 0 ? <section className="mt-4"><h3 className="font-medium">{m.benefits}</h3><ul className="mt-2 list-disc space-y-1 ps-5">{option.benefits.map((item, index) => <li key={index}>{narrativeText(item, locale)}</li>)}</ul></section> : null}
          {option.tradeoffs.length > 0 ? <section className="mt-4"><h3 className="font-medium">{m.tradeoffs}</h3><ul className="mt-2 list-disc space-y-1 ps-5">{option.tradeoffs.map((item, index) => <li key={index}>{narrativeText(item, locale)}</li>)}</ul></section> : null}
          {Object.keys(option.explanation).length > 0 ? <section className="mt-4"><h3 className="font-medium">{m.explanation}</h3><dl className="mt-2 space-y-2">{Object.entries(option.explanation).map(([key, value]) => <div key={key} className="min-w-0"><dt className="break-words text-sm text-muted-foreground">{key}</dt><dd className="break-words">{narrativeText(value, locale)}</dd></div>)}</dl></section> : null}
          <SolutionDecisionAccess canDecide={set.canDecide} locale={locale} solutionSetId={set.id} level={option.level} idempotencyKey={randomUUID()} messages={m} />
        </article>)}
      </CardContent></Card>)}
    </section>
    <section aria-labelledby="benchmarks"><h2 id="benchmarks" className="text-2xl font-semibold">{m.benchmarks}</h2>{result.value.benchmarks.length === 0 ? <p className="mt-3 rounded-xl border bg-card p-5">{m.noBenchmarks}</p> : <div className="mt-3 grid gap-3 sm:grid-cols-2">{result.value.benchmarks.map((item) => <Card key={item.id}><CardContent className="space-y-1 pt-6"><h3 className="break-words font-semibold">{item.metricCode}</h3><p className="break-words">{item.segmentKey}</p><p>{m.period}: <time dateTime={item.periodStart}>{formatSolutionDate(item.periodStart, locale)}</time> – <time dateTime={item.periodEnd}>{formatSolutionDate(item.periodEnd, locale)}</time></p><p>{m.group}: {item.groupSizeBand}</p><p>{m.mean}: <span dir="ltr">{formatExactDecimal(item.roundedMean, locale)}</span></p><p>{m.published}: <time dateTime={item.publishedAt}>{formatSolutionDate(item.publishedAt, locale)}</time></p></CardContent></Card>)}</div>}</section>
  </div></main>;
}
