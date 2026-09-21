import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { franchiseCopy } from "@/modules/franchise/data/spaces/copy";
import { loadFranchiseFollowups } from "@/modules/franchise/data/followups/repository";
import { buildFranchiseSpaceBoard } from "@/modules/franchise/data/spaces/live";
import { FollowupsBoard } from "@/modules/franchise/screens/spaces/boards";
import { FollowupPanel } from "@/modules/franchise/screens/relances/panel";
import { getFollowupMessages } from "@/modules/franchise/screens/relances/messages";
import { franchiseMandateName, requireFranchiseLibrary } from "@/modules/franchise/screens/library/page-helper";
import { FranchiseAppShell } from "@/modules/franchise/ui/franchise-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function FranchiseFollowupsPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const { space, result: library } = await requireFranchiseLibrary({ locale, organizationId: query.organizationId });
  const m = getFollowupMessages(locale);
  const r = await loadFranchiseFollowups();
  if (r.status === "error" && r.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const c = franchiseCopy(locale);
  const mandateName = franchiseMandateName(library);
  return (
    <FranchiseAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="followups" title={c.folTitle} lead={c.folLead} kicker={c.kicker} mandateName={mandateName}>
      <FollowupsBoard locale={locale} query={space.selectedQuery} mandateName={mandateName} board={r.status === "success" ? buildFranchiseSpaceBoard({ locale, query: space.selectedQuery, libraryName: mandateName, followups: r.dashboard }) : undefined} />
      <details id="relances" className="client-ops" open>
        <summary>{c.opsFollow}</summary>
        {r.status === "error" ? (
          <Alert variant="destructive">
            <AlertTitle>{r.reason === "FORBIDDEN" ? m.accessDenied : m.loadFailed}</AlertTitle>
            <AlertDescription>{r.reason}</AlertDescription>
          </Alert>
        ) : (
          <FollowupPanel dashboard={r.dashboard} locale={locale} m={m} keyValue={randomUUID()} />
        )}
      </details>
    </FranchiseAppShell>
  );
}
