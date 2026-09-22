import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { formatExactScore } from "@/modules/shared/lib/diagnostics-opportunities/model";
import { createServerDiagnosticsRepository } from "@/modules/shared/lib/diagnostics-opportunities/server-repository";
import { createServerQuestionnaireSessionsRepository } from "@/modules/shared/lib/questionnaire-sessions/server-repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { CompleteForm } from "@/modules/client/screens/diagnostics/complete-form";
import { DiagnosticTools } from "@/modules/client/screens/diagnostics/diagnostic-tools";
import { IndicativeIntakes } from "@/modules/client/screens/diagnostics/indicative-intakes";
import { MesDiagnosticsHub } from "@/modules/client/screens/diagnostics/mes-diagnostics-hub";
import { messages } from "@/modules/client/screens/diagnostics/messages";
import { diagnosticToolMessages } from "@/modules/client/screens/diagnostics/tool-messages";
import { formatDimensionKey } from "@/modules/client/screens/diagnostics/journey";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";

export default async function Diagnostics({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const repository = await createServerDiagnosticsRepository();
  const result = await repository.list();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const m = messages(locale);
  const c = spaceCopy(locale);
  if (result.status === "error") {
    return (
      <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} organizationName={space.organizationName} active="needs" title={m.title} lead={m.intro} kicker={c.kicker}>
        <main className="client-page"><p role="alert" className="client-card">{locale === "ar" ? "تعذر تحميل التشخيصات." : "Impossible de charger les diagnostics."}</p></main>
      </ClientAppShell>
    );
  }
  const client = await getSupabaseServerClient();
  const intakeResult = await client.from("public_diagnostic_intakes").select("id,organization_id,priorities,created_at").order("created_at", { ascending: false }).limit(100);
  const organizationIds = [...new Set([...result.value.sessions.map((session) => session.organizationId), ...(intakeResult.data ?? []).map((intake) => intake.organization_id)])];
  const organizationResult = organizationIds.length ? await client.from("organizations").select("id,display_name").in("id", organizationIds) : { data: [], error: null };
  if (organizationResult.error) {
    return (
      <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} organizationName={space.organizationName} active="needs" title={m.title} lead={m.intro} kicker={c.kicker}>
        <main className="client-page"><p role="alert" className="client-card">{locale === "ar" ? "تعذر تحميل المؤسسات المرتبطة بالتشخيص." : "Impossible de charger les organisations liées au diagnostic."}</p></main>
      </ClientAppShell>
    );
  }
  const names = new Map((organizationResult.data ?? []).map((organization) => [organization.id, organization.display_name]));
  const organizations = organizationIds.flatMap((id) => {
    const latestSession = result.value.sessions.find((session) => session.organizationId === id);
    const name = names.get(id);
    return latestSession && name ? [{ id, name, latestAt: latestSession.submittedAt }] : [];
  });
  const latest = result.value.runs.find((run) => run.status === "COMPLETED") ?? null;
  const detailResult = latest ? await repository.detail(latest.id) : { status: "success" as const, value: null };
  const detail = detailResult.status === "success" ? detailResult.value : null;
  const runHref = (id: string) => `/${locale}/client/diagnostics/${id}${space.selectedQuery}`;
  const questionnaireHref = `/${locale}/client/questionnaires${space.selectedQuery}`;
  const evolutionHref = `/${locale}/client/diagnostics/evolution${space.selectedQuery}`;
  const assistanceHref = `/${locale}/client/diagnostics/assistance${space.selectedQuery}`;
  const solutionsHref = `/${locale}/client/diagnostics/solutions${space.selectedQuery}`;
  const organizationId = space.selectedOrganizationId;
  const questionnaireResult = organizationId
    ? await createServerQuestionnaireSessionsRepository().then((repository) => repository.load(undefined, organizationId))
    : { status: "error" as const, reason: "FORBIDDEN" as const };
  const selectedSession = questionnaireResult.status === "success" ? questionnaireResult.value.selected : null;
  const dateFmt = new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium" });
  const hubCards = [
    ...(latest
      ? [{
          id: latest.id,
          title: locale === "fr" ? `Diagnostic ${dateFmt.format(new Date(latest.completedAt))}` : `تشخيص ${dateFmt.format(new Date(latest.completedAt))}`,
          href: runHref(latest.id),
          status: "completed" as const,
          meta: `${locale === "fr" ? "Score" : "النتيجة"} ${formatExactScore(latest.score)}/100 · ${m.ratings[latest.rating]}`,
          description: locale === "fr" ? "Analyse versionnée basée sur vos réponses confirmées." : "تحليل بإصدار مبني على إجاباتكم المؤكدة.",
          scores: (detail?.subscores ?? []).slice(0, 3).map((item, index) => ({
            label: formatDimensionKey(item.key),
            value: `${formatExactScore(item.score)}/100`,
            tone: (index === 0 ? "mint" : index === 1 ? "violet" : "coral") as "mint" | "violet" | "coral",
          })),
        }]
      : []),
    ...(selectedSession
      ? [{
          id: selectedSession.id,
          title: locale === "fr" ? "Diagnostic en cours" : "تشخيص جارٍ",
          href: `/${locale}/client/questionnaires?session=${selectedSession.id}${space.selectedOrganizationId ? `&organizationId=${space.selectedOrganizationId}` : ""}`,
          status: "in_progress" as const,
          meta: locale === "fr" ? "Brouillon enregistré" : "مسودة محفوظة",
          progressLabel: locale === "fr" ? "Reprendre le questionnaire" : "استئناف الاستبيان",
          progressPct: 65,
        }]
      : []),
  ];
  const history = result.value.runs.slice(0, 8).map((run) => ({
    id: run.id,
    title: `${dateFmt.format(new Date(run.completedAt))} · ${formatExactScore(run.score)}/100`,
    meta: m.ratings[run.rating],
    status: "completed" as const,
    href: runHref(run.id),
  }));
  const todos = [
    {
      id: "resume",
      title: locale === "fr" ? "Compléter une réponse manquante" : "إكمال إجابة ناقصة",
      description: locale === "fr" ? "Finalisez les points encore ouverts." : "أكملوا النقاط المفتوحة.",
      href: questionnaireHref,
      tone: "coral" as const,
    },
    {
      id: "reco",
      title: locale === "fr" ? "Consulter une recommandation" : "مراجعة توصية",
      description: locale === "fr" ? "Passez des constats aux actions." : "انتقلوا من الملاحظات إلى الإجراءات.",
      href: latest ? runHref(latest.id) : questionnaireHref,
      tone: "violet" as const,
    },
    {
      id: "need",
      title: locale === "fr" ? "Transformer une priorité en besoin" : "تحويل أولوية إلى احتياج",
      description: locale === "fr" ? "Préparez une demande structurée." : "أعدوا طلباً منظماً.",
      href: `/${locale}/client/diagnostics/besoin${space.selectedQuery}`,
      tone: "lavender" as const,
    },
  ];
  const resources = [
    { id: "evolution", title: locale === "fr" ? "Évolution" : "التطور", href: evolutionHref },
    { id: "solutions", title: locale === "fr" ? "Solutions recommandées" : "حلول موصى بها", href: solutionsHref },
    { id: "assist", title: locale === "fr" ? "Assistance humaine" : "مساعدة بشرية", href: assistanceHref },
  ];

  return (
    <ClientAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail} organizationName={space.organizationName}
      active="needs"
      kicker={c.kicker}
      actions={<Link href={questionnaireHref} className="client-cta">{c.startQuestionnaire}</Link>}
    >
      <MesDiagnosticsHub
        locale={locale}
        cards={hubCards.length ? hubCards : [{
          id: "start",
          title: locale === "fr" ? "Commencer un diagnostic" : "بدء تشخيص",
          href: questionnaireHref,
          status: "draft",
          meta: locale === "fr" ? "Aucun diagnostic encore" : "لا تشخيص بعد",
          description: locale === "fr" ? "Lancez le questionnaire versionné pour obtenir une analyse explicable." : "ابدؤوا الاستبيان ذا الإصدار للحصول على تحليل قابل للتفسير.",
        }]}
        history={history}
        todos={todos}
        resources={resources}
        assistanceHref={assistanceHref}
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
