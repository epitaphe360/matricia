import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { formatExactScore } from "@/modules/shared/lib/diagnostics-opportunities/model";
import { createServerDiagnosticsRepository } from "@/modules/shared/lib/diagnostics-opportunities/server-repository";
import { loadDiagnosticsEvolution } from "@/modules/shared/lib/diagnostics-evolution/repository";
import { createServerAssistedIntelligenceRepository } from "@/modules/shared/lib/assisted-intelligence/server-repository";
import { createServerQuestionnaireSessionsRepository } from "@/modules/shared/lib/questionnaire-sessions/server-repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { CompleteForm } from "@/modules/client/screens/diagnostics/complete-form";
import { DiagnosticTools } from "@/modules/client/screens/diagnostics/diagnostic-tools";
import { IndicativeIntakes } from "@/modules/client/screens/diagnostics/indicative-intakes";
import { messages } from "@/modules/client/screens/diagnostics/messages";
import { diagnosticToolMessages } from "@/modules/client/screens/diagnostics/tool-messages";
import { formatDimensionKey, latestEvolutionHighlights, opportunityRequestHref } from "@/modules/client/screens/diagnostics/journey";
import { DiagnosticsBoard } from "@/modules/client/screens/spaces/boards";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";

export default async function Diagnostics({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const repository = await createServerDiagnosticsRepository();
  const result = await repository.list();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  if (result.status === "error") throw new Error("DIAGNOSTICS_UNAVAILABLE");
  const client = await getSupabaseServerClient();
  const intakeResult = await client.from("public_diagnostic_intakes").select("id,organization_id,priorities,created_at").order("created_at", { ascending: false }).limit(100);
  const organizationIds = [...new Set([...result.value.sessions.map((session) => session.organizationId), ...(intakeResult.data ?? []).map((intake) => intake.organization_id)])];
  const organizationResult = organizationIds.length ? await client.from("organizations").select("id,display_name").in("id", organizationIds) : { data: [], error: null };
  if (organizationResult.error) throw new Error("DIAGNOSTIC_ORGANIZATIONS_UNAVAILABLE");
  const names = new Map((organizationResult.data ?? []).map((organization) => [organization.id, organization.display_name]));
  const organizations = organizationIds.flatMap((id) => {
    const latestSession = result.value.sessions.find((session) => session.organizationId === id);
    const name = names.get(id);
    return latestSession && name ? [{ id, name, latestAt: latestSession.submittedAt }] : [];
  });
  const m = messages(locale);
  const c = spaceCopy(locale);
  const latest = result.value.runs.find((run) => run.status === "COMPLETED") ?? null;
  const detailResult = latest ? await repository.detail(latest.id) : { status: "success" as const, value: null };
  const detail = detailResult.status === "success" ? detailResult.value : null;
  const runHref = (id: string) => `/${locale}/client/diagnostics/${id}${space.selectedQuery}`;
  const questionnaireHref = `/${locale}/client/questionnaires${space.selectedQuery}`;
  const evolutionHref = `/${locale}/client/diagnostics/evolution${space.selectedQuery}`;
  const assistanceHref = `/${locale}/client/diagnostics/assistance${space.selectedQuery}`;
  const solutionsHref = `/${locale}/client/diagnostics/solutions${space.selectedQuery}`;
  const organizationId = space.selectedOrganizationId;
  const [evolutionResult, assistanceResult, questionnaireResult] = await Promise.all([
    loadDiagnosticsEvolution(),
    createServerAssistedIntelligenceRepository().then((repository) => repository.dashboard()),
    organizationId
      ? createServerQuestionnaireSessionsRepository().then((repository) => repository.load(undefined, organizationId))
      : Promise.resolve({ status: "error" as const, reason: "FORBIDDEN" as const }),
  ]);
  const latestRunHref = latest ? runHref(latest.id) : questionnaireHref;
  const findings = (detail?.anomalies ?? []).slice(0, 8).map((anomaly) => {
    const recommendation = detail?.recommendations.find((item) => item.anomalyId === anomaly.id);
    return {
      id: anomaly.id,
      title: locale === "ar" ? anomaly.titleAr : anomaly.titleFr,
      severity: anomaly.severity,
      blocking: anomaly.blocking,
      action: recommendation ? (locale === "ar" ? recommendation.titleAr : recommendation.titleFr) : m.recommendations,
      why: m.whyOpportunity,
      href: latestRunHref,
    };
  });
  const opportunities = (detail?.opportunities ?? []).filter((item) => item.status !== "CLOSED").slice(0, 8).map((item) => ({
    id: item.id,
    title: locale === "ar" ? (item.serviceNameAr ?? `${m.priority} ${item.priority}`) : (item.serviceNameFr ?? `${m.priority} ${item.priority}`),
    status: m.statuses[item.status],
    href: item.status === "RFQ_READY"
      ? opportunityRequestHref(locale, item.id, space.selectedQuery)
      : latestRunHref,
  }));
  const runs = result.value.runs.slice(0, 8).map((run) => ({
    id: run.id,
    title: `${new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium" }).format(new Date(run.completedAt))} · ${formatExactScore(run.score)}/100`,
    href: runHref(run.id),
  }));
  const selectedSession = questionnaireResult.status === "success" ? questionnaireResult.value.selected : null;

  return (
    <ClientAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      active="needs"
      title={c.diagTitle}
      lead={c.diagLead}
      kicker={c.kicker}
      actions={<Link href={questionnaireHref} className="client-cta">{c.startQuestionnaire}</Link>}
    >
      <DiagnosticsBoard
        locale={locale}
        questionnaireHref={questionnaireHref}
        evolutionHref={evolutionHref}
        score={latest ? formatExactScore(latest.score) : null}
        ratingLabel={latest ? m.ratings[latest.rating] : null}
        libraryScores={(detail?.subscores ?? []).map((item) => ({ key: formatDimensionKey(item.key), score: formatExactScore(item.score) }))}
        findings={findings}
        opportunities={opportunities}
        runs={runs}
        hasSubmittedAssessment={organizations.length > 0}
        organizationName={space.organizationName}
        continuity={{
          evolution: evolutionResult.status === "success" ? latestEvolutionHighlights(evolutionResult.value, locale, space.selectedQuery) : [],
          expiredAnswerCount: selectedSession?.expiredAnswerCount ?? 0,
          expiringAnswerCount: selectedSession?.expiringAnswerCount ?? 0,
          questionnaireHref: selectedSession
            ? `/${locale}/client/questionnaires?session=${selectedSession.id}${space.selectedOrganizationId ? `&organizationId=${space.selectedOrganizationId}` : ""}`
            : questionnaireHref,
          proposedCount: assistanceResult.status === "success" ? assistanceResult.value.suggestions.filter((item) => item.status === "PROPOSED").length : 0,
          reassessmentCount: assistanceResult.status === "success" ? assistanceResult.value.reassessmentCandidates.length : 0,
          assistanceHref,
          solutionsHref,
        }}
      />
      <details id="analyse" className="client-ops" open={organizations.length > 0 && !latest}>
        <summary>{c.computeAnalysis}</summary>
        <CompleteForm locale={locale} organizations={organizations} questionnaireHref={questionnaireHref} m={m} keyValue={randomUUID()} />
        <DiagnosticTools locale={locale} m={diagnosticToolMessages[locale]} />
      </details>
      <IndicativeIntakes
        locale={locale}
        failed={Boolean(intakeResult.error)}
        rows={(intakeResult.data ?? []).map((intake) => ({
          id: intake.id,
          organizationId: intake.organization_id,
          organizationName: names.get(intake.organization_id) ?? (locale === "fr" ? "Organisation" : "المؤسسة"),
          priorities: intake.priorities,
          createdAt: intake.created_at,
        }))}
      />
    </ClientAppShell>
  );
}
