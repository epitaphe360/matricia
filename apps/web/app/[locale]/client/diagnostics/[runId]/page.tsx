import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Badge } from "@/modules/shared/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/modules/shared/ui/card";
import { formatExactScore } from "@/modules/shared/lib/diagnostics-opportunities/model";
import { createServerDiagnosticsRepository } from "@/modules/shared/lib/diagnostics-opportunities/server-repository";
import { loadDiagnosticsEvolution } from "@/modules/shared/lib/diagnostics-evolution/repository";
import { formatHundredths } from "@/modules/shared/lib/diagnostics-evolution/model";
import { createServerAssistedIntelligenceRepository } from "@/modules/shared/lib/assisted-intelligence/server-repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { DiagnosticSnapshot, FindingExplanation, OpportunityContext, SubscoreExplanation } from "@/modules/client/screens/diagnostics/diagnostic-snapshot";
import { messages } from "@/modules/client/screens/diagnostics/messages";
import { OpportunityActions } from "@/modules/client/screens/diagnostics/opportunity-actions";
import { AssistanceCue } from "@/modules/client/screens/diagnostics/assistance-cue";
import { clientHref, formatDimensionKey, labelSolutionLevel } from "@/modules/client/screens/diagnostics/journey";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";

export default async function Result({ params, searchParams }: { params: Promise<{ locale: string; runId: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const [{ locale, runId }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const [result, evolutionResult, assistanceResult] = await Promise.all([
    (await createServerDiagnosticsRepository()).detail(runId),
    loadDiagnosticsEvolution(),
    createServerAssistedIntelligenceRepository().then((repository) => repository.dashboard()),
  ]);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  if (result.status === "error" || !result.value) notFound();
  const detail = result.value;
  const m = messages(locale);
  const c = spaceCopy(locale);
  const solutionsHref = clientHref(`/${locale}/client/diagnostics/solutions`, space.selectedQuery);
  const assistanceHref = clientHref(`/${locale}/client/diagnostics/assistance`, space.selectedQuery);
  const series = evolutionResult.status === "success"
    ? evolutionResult.value.series.find((item) => item.points.some((point) => point.id === detail.id))
    : null;
  const point = series?.points.find((item) => item.id === detail.id) ?? null;
  const proposedCount = assistanceResult.status === "success" ? assistanceResult.value.suggestions.filter((item) => item.status === "PROPOSED").length : 0;
  const reassessmentCount = assistanceResult.status === "success" ? assistanceResult.value.reassessmentCandidates.length : 0;
  return (
    <ClientAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      active="needs"
      title={`${m.score} ${formatExactScore(detail.score)}/100`}
      lead={m.intro}
      kicker={c.kicker}
    >
      <main className="client-page space-y-6">
        <Card>
          <CardHeader>
            <div className="flex flex-wrap justify-between gap-3">
              <CardTitle>{m.score}: <span dir="ltr">{formatExactScore(detail.score)}/100</span></CardTitle>
              <Badge>{m.ratings[detail.rating]}</Badge>
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            <p>{new Date(detail.completedAt).toLocaleString(locale)}</p>
            {point ? (
              <p>
                {m.evolutionNow}: {point.deltaHundredths === null ? m.firstRun : <><span>{m.previousDelta}</span> <bdi dir="ltr">{formatHundredths(point.deltaHundredths)}</bdi></>}
              </p>
            ) : null}
            <Link href={clientHref(`/${locale}/client/diagnostics/evolution`, space.selectedQuery)} className="client-text-link">{locale === "ar" ? "تطور التشخيصات" : "Évolution des diagnostics"}</Link>
          </CardContent>
        </Card>
        <AssistanceCue locale={locale} href={assistanceHref} proposedCount={proposedCount} reassessmentCount={reassessmentCount} context="diagnostic" />
        <DiagnosticSnapshot detail={detail} locale={locale} m={m} />
        <section>
          <h2 className="mb-3 text-xl font-semibold">{m.subscores}</h2>
          <div className="grid gap-3 sm:grid-cols-2">
            {detail.subscores.map((item) => (
              <Card key={item.key}>
                <CardHeader><CardTitle>{formatDimensionKey(item.key)}</CardTitle></CardHeader>
                <CardContent><SubscoreExplanation subscore={item} m={m} /></CardContent>
              </Card>
            ))}
          </div>
        </section>
        <section>
          <h2 className="mb-3 text-xl font-semibold">{m.anomalies}</h2>
          {!detail.anomalies.length ? <p className="rounded-xl border bg-card p-4">{m.noFinding}</p> : detail.anomalies.map((item) => {
            const recs = detail.recommendations.filter((recommendation) => recommendation.anomalyId === item.id);
            return (
              <article key={item.id} className="mb-3 rounded-xl border bg-card p-4">
                <div className="flex flex-wrap justify-between gap-2">
                  <strong>{locale === "ar" ? item.titleAr : item.titleFr}</strong>
                  <span>{item.severity}{item.blocking ? ` · ${m.blocking}` : ""}</span>
                </div>
                <FindingExplanation anomaly={item} m={m} />
                <div className="mt-4 space-y-3">
                  <h3 className="font-medium">{m.recommendations}</h3>
                  {recs.length === 0 ? <p>{m.noRecommendation}</p> : recs.map((recommendation) => (
                    <div key={recommendation.id} className="rounded-lg border p-3">
                      <p><strong>{locale === "ar" ? recommendation.titleAr : recommendation.titleFr}</strong></p>
                      <p className="mt-2">{locale === "ar" ? recommendation.textAr : recommendation.textFr}</p>
                      <small>{m.priority}: {recommendation.priority} · {m.solutionLevel}: {labelSolutionLevel(locale, recommendation.solutionLevel)}</small>
                    </div>
                  ))}
                  <Link href={clientHref(`/${locale}/client/diagnostics/solutions`, space.selectedQuery, { anomalyId: item.id })} className="client-ghost-link">{m.compareSolutions}</Link>
                </div>
              </article>
            );
          })}
        </section>
        <p><Link href={solutionsHref} className="client-text-link">{m.openSolutions}</Link></p>
        <section>
          <h2 className="mb-3 text-xl font-semibold">{m.opportunities}</h2>
          {detail.opportunities.map((opportunity) => (
            <Card key={opportunity.id} className="mb-4">
              <CardHeader>
                <div className="flex justify-between gap-2">
                  <CardTitle>{m.priority} {opportunity.priority}</CardTitle>
                  <Badge>{m.statuses[opportunity.status]}</Badge>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                <OpportunityContext opportunity={opportunity} detail={detail} locale={locale} m={m} />
                <OpportunityActions locale={locale} runId={detail.id} o={opportunity} m={m} keys={Array.from({ length: 4 }, () => randomUUID())} />
              </CardContent>
            </Card>
          ))}
        </section>
      </main>
    </ClientAppShell>
  );
}
