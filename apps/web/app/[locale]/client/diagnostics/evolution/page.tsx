import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { Badge } from "@/modules/shared/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/modules/shared/ui/card";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { getEvolutionMessages } from "@/modules/client/screens/diagnostics/evolution/messages";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { formatHundredths } from "@/modules/shared/lib/diagnostics-evolution/model";
import { loadDiagnosticsEvolution } from "@/modules/shared/lib/diagnostics-evolution/repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export const dynamic = "force-dynamic";

export default async function DiagnosticsEvolutionPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const result = await loadDiagnosticsEvolution();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const messages = getEvolutionMessages(locale);
  const c = spaceCopy(locale);

  return (
    <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="needs" title={messages.title} lead={messages.intro} kicker={c.kicker}>
      <main className="client-page">
        {result.status === "error" ? (
          <Alert variant="destructive">
            <AlertTitle>{result.reason === "FORBIDDEN" ? messages.forbidden : messages.unavailable}</AlertTitle>
            <AlertDescription>
              <Link href={`/${locale}/client/diagnostics/evolution${space.selectedQuery}`} className="client-ghost-link">{messages.retry}</Link>
            </AlertDescription>
          </Alert>
        ) : (
          <>
            {result.value.truncated ? <p role="status" className="client-card">{messages.truncated}</p> : null}
            {result.value.series.length === 0 ? (
              <p className="client-card">{messages.empty}</p>
            ) : (
              result.value.series.map((series) => (
                <section key={series.libraryId} aria-labelledby={`library-${series.libraryId}`} className="space-y-3">
                  <h2 id={`library-${series.libraryId}`} className="text-xl font-semibold">
                    <bdi dir="ltr">{series.libraryCode}</bdi> · {messages.timeline}
                  </h2>
                  <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
                    {series.points.map((point) => (
                      <Card key={point.id}>
                        <CardHeader>
                          <div className="flex flex-wrap items-start justify-between gap-2">
                            <CardTitle><span dir="ltr">{formatHundredths(point.scoreHundredths)}/100</span></CardTitle>
                            <Badge>{messages.ratings[point.rating]}</Badge>
                          </div>
                        </CardHeader>
                        <CardContent className="space-y-3">
                          <div className="h-2 overflow-hidden rounded-full bg-muted" role="img" aria-label={`${messages.score} ${formatHundredths(point.scoreHundredths)} / 100`}>
                            <div className="h-full rounded-full bg-primary" style={{ width: `${Math.trunc(point.scoreHundredths / 100)}%` }} />
                          </div>
                          <dl className="grid gap-2 text-sm">
                            <div className="flex justify-between gap-3"><dt>{messages.delta}</dt><dd dir="ltr" className="font-semibold">{point.deltaHundredths === null ? messages.first : formatHundredths(point.deltaHundredths)}</dd></div>
                            <div className="flex justify-between gap-3"><dt>{messages.open}</dt><dd><bdi dir="ltr">{point.openAnomalies}</bdi>{point.criticalAnomalies ? ` · ${point.criticalAnomalies} ${messages.critical}` : ""}</dd></div>
                            <div className="flex justify-between gap-3"><dt>{point.status === "COMPLETED" ? messages.current : messages.superseded}</dt><dd><time dateTime={point.completedAt}>{new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium" }).format(new Date(point.completedAt))}</time></dd></div>
                          </dl>
                          <Link href={`/${locale}/client/diagnostics/${point.id}${space.selectedQuery}`} className="client-text-link">{messages.details}</Link>
                        </CardContent>
                      </Card>
                    ))}
                  </div>
                </section>
              ))
            )}
          </>
        )}
      </main>
    </ClientAppShell>
  );
}
