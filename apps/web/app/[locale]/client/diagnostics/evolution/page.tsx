import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { buttonVariants } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { formatHundredths } from "@/lib/diagnostics-evolution/model";
import { loadDiagnosticsEvolution } from "@/lib/diagnostics-evolution/repository";
import { isLocale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { getEvolutionMessages } from "./messages";

export const dynamic = "force-dynamic";

export default async function DiagnosticsEvolutionPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const result = await loadDiagnosticsEvolution();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const messages = getEvolutionMessages(locale);
  const alternate = locale === "fr" ? "ar" : "fr";
  return <main dir={locale === "ar" ? "rtl" : "ltr"} className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8"><div className="mx-auto max-w-6xl space-y-7"><nav aria-label={messages.nav} className="flex flex-wrap items-center justify-between gap-3"><Link href={`/${locale}/client/diagnostics`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.back}</Link><Link href={`/${alternate}/client/diagnostics/evolution`} hrefLang={alternate} className="min-h-11 rounded-md px-3 py-2 font-medium text-primary">{messages.language}</Link></nav><header><p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">{messages.title}</h1><p className="mt-3 max-w-3xl leading-7 text-muted-foreground">{messages.intro}</p></header>{result.status === "error" ? <Alert variant="destructive"><AlertTitle>{result.reason === "FORBIDDEN" ? messages.forbidden : messages.unavailable}</AlertTitle><AlertDescription><Link href={`/${locale}/client/diagnostics/evolution`} className={cn(buttonVariants({ variant: "outline" }), "mt-3 min-h-11")}>{messages.retry}</Link></AlertDescription></Alert> : <>{result.value.truncated ? <p role="status" className="rounded-lg border bg-card p-4 text-sm">{messages.truncated}</p> : null}{result.value.series.length === 0 ? <p className="rounded-xl border bg-card p-5">{messages.empty}</p> : result.value.series.map((series) => <section key={series.libraryId} aria-labelledby={`library-${series.libraryId}`} className="space-y-3"><h2 id={`library-${series.libraryId}`} className="text-xl font-semibold"><bdi dir="ltr">{series.libraryCode}</bdi> · {messages.timeline}</h2><div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">{series.points.map((point) => <Card key={point.id}><CardHeader><div className="flex flex-wrap items-start justify-between gap-2"><CardTitle><span dir="ltr">{formatHundredths(point.scoreHundredths)}/100</span></CardTitle><Badge>{messages.ratings[point.rating]}</Badge></div></CardHeader><CardContent className="space-y-3"><div className="h-2 overflow-hidden rounded-full bg-muted" role="img" aria-label={`${messages.score} ${formatHundredths(point.scoreHundredths)} / 100`}><div className="h-full rounded-full bg-primary" style={{ width: `${Math.trunc(point.scoreHundredths / 100)}%` }}/></div><dl className="grid gap-2 text-sm"><div className="flex justify-between gap-3"><dt>{messages.delta}</dt><dd dir="ltr" className="font-semibold">{point.deltaHundredths === null ? messages.first : formatHundredths(point.deltaHundredths)}</dd></div><div className="flex justify-between gap-3"><dt>{messages.open}</dt><dd><bdi dir="ltr">{point.openAnomalies}</bdi>{point.criticalAnomalies ? ` · ${point.criticalAnomalies} ${messages.critical}` : ""}</dd></div><div className="flex justify-between gap-3"><dt>{point.status === "COMPLETED" ? messages.current : messages.superseded}</dt><dd><time dateTime={point.completedAt}>{new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium" }).format(new Date(point.completedAt))}</time></dd></div></dl><Link href={`/${locale}/client/diagnostics/${point.id}`} className="inline-flex min-h-11 items-center font-medium text-primary underline underline-offset-4">{messages.details}</Link></CardContent></Card>)}</div></section>)}</>}</div></main>;
}
