import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { loadClientAmendments } from "@/modules/shared/lib/contracts-missions/amendments";
import { loadContractMissions } from "@/modules/shared/lib/contracts-missions/repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { AmendmentPanel } from "@/modules/client/screens/missions/amendment-panel";
import { getMissionMessages } from "@/modules/client/screens/missions/messages";
import { MilestoneDecisions } from "@/modules/client/screens/missions/milestone-decisions";
import { MissionPanel } from "@/modules/client/screens/missions/mission-panel";
import { SpaceActions } from "@/modules/client/screens/spaces/boards";
import { FollowBoard } from "@/modules/client/screens/spaces/follow-board";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";

export default async function ClientMissionFollowPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string; missionId: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const [{ locale, missionId }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale) || !missionId) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const messages = getMissionMessages(locale);
  const c = spaceCopy(locale);
  const [result, amendments] = await Promise.all([loadContractMissions(locale, query.organizationId), loadClientAmendments(query.organizationId)]);
  const dashboard = result.status === "success"
    ? { ...result.dashboard, missions: result.dashboard.missions.filter((item) => item.id === missionId) }
    : null;
  const mission = dashboard?.missions[0] ?? null;

  return (
    <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="missions" theme="follow" title={c.followTitle} lead={c.followLead} kicker={c.kicker} actions={<SpaceActions href={`/${locale}/besoin${space.selectedQuery}`} label={locale === "ar" ? "وصف حاجتي" : "Décrire mon besoin"} />}>
      <FollowBoard locale={locale} query={space.selectedQuery} organizationName={space.organizationName} mission={mission} />
      <details className="client-ops">
        <summary>{c.opsMissions}</summary>
        {result.status === "error" ? (
          <Alert><AlertTitle>{messages.noOrg}</AlertTitle><AlertDescription>{result.reason}</AlertDescription></Alert>
        ) : dashboard && dashboard.missions.length === 0 ? (
          <p role="status" className="client-card">{messages.empty}</p>
        ) : dashboard ? (
          <div className="space-y-6">
            <MissionPanel d={dashboard} locale={locale} m={messages} />
            <MilestoneDecisions dashboard={dashboard} locale={locale} messages={messages} />
            {amendments.status === "success" && amendments.value.organizationId === dashboard.organizationId ? (
              <AmendmentPanel d={amendments.value} locale={locale} keys={Object.fromEntries(amendments.value.items.flatMap((item) => [[`submit:${item.id}`, randomUUID()], [`sign:${item.id}`, randomUUID()]]))} />
            ) : null}
          </div>
        ) : null}
      </details>
    </ClientAppShell>
  );
}
