import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { createServerDiagnosticsRepository } from "@/modules/shared/lib/diagnostics-opportunities/server-repository";
import { createServerAssistedIntelligenceRepository } from "@/modules/shared/lib/assisted-intelligence/server-repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { AnalyseDetailleeView } from "@/modules/client/screens/diagnostics/analyse-detaillee-view";
import { AssistanceCue } from "@/modules/client/screens/diagnostics/assistance-cue";
import { messages } from "@/modules/client/screens/diagnostics/messages";
import { clientHref } from "@/modules/client/screens/diagnostics/journey";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";

export default async function Result({ params, searchParams }: { params: Promise<{ locale: string; runId: string }>; searchParams: Promise<{ organizationId?: string; anomalyId?: string }> }) {
  const [{ locale, runId }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const [result, assistanceResult] = await Promise.all([
    (await createServerDiagnosticsRepository()).detail(runId),
    createServerAssistedIntelligenceRepository().then((repository) => repository.dashboard()),
  ]);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  if (result.status === "error" || !result.value) notFound();
  const detail = result.value;
  const m = messages(locale);
  const c = spaceCopy(locale);
  const solutionsHref = clientHref(`/${locale}/client/diagnostics/solutions`, space.selectedQuery);
  const assistanceHref = clientHref(`/${locale}/client/diagnostics/assistance`, space.selectedQuery);
  const evolutionHref = clientHref(`/${locale}/client/diagnostics/evolution`, space.selectedQuery);
  const listHref = clientHref(`/${locale}/client/diagnostics`, space.selectedQuery);
  const proposedCount = assistanceResult.status === "success" ? assistanceResult.value.suggestions.filter((item) => item.status === "PROPOSED").length : 0;
  const reassessmentCount = assistanceResult.status === "success" ? assistanceResult.value.reassessmentCandidates.length : 0;

  return (
    <ClientAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      organizationName={space.organizationName}
      active="needs"
      kicker={c.kicker}
    >
      <main className="client-page">
        <AssistanceCue locale={locale} href={assistanceHref} proposedCount={proposedCount} reassessmentCount={reassessmentCount} context="diagnostic" />
        <AnalyseDetailleeView
          detail={detail}
          locale={locale}
          m={m}
          solutionsHref={solutionsHref}
          assistanceHref={assistanceHref}
          evolutionHref={evolutionHref}
          listHref={listHref}
          anomalyId={query.anomalyId}
          decisionKeys={Array.from({ length: 4 }, () => randomUUID())}
        />
      </main>
    </ClientAppShell>
  );
}
