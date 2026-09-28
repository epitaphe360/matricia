import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { connexionHref } from "@/modules/shared/lib/auth/connexion-href";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { franchiseCopy } from "@/modules/franchise/data/spaces/copy";
import { loadFranchiseDashboard } from "@/modules/franchise/data/governance/repository";
import { buildFranchiseSpaceBoard } from "@/modules/franchise/data/spaces/live";
import { GovernanceBoard } from "@/modules/franchise/screens/spaces/boards";
import { GovernancePanel } from "@/modules/franchise/screens/gouvernance/governance-panel";
import { getFranchiseMessages } from "@/modules/franchise/screens/gouvernance/messages";
import { franchiseMandateName, requireFranchiseLibrary } from "@/modules/franchise/screens/library/page-helper";
import { FranchiseActions, FranchiseAppShell } from "@/modules/franchise/ui/franchise-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function FranchiseGovernancePage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const { space, result: library } = await requireFranchiseLibrary({ locale, organizationId: query.organizationId });
  const messages = getFranchiseMessages(locale);
  const result = await loadFranchiseDashboard(locale);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(connexionHref(locale, { next: `/${locale}/franchise/gouvernance` }));
  const c = franchiseCopy(locale);
  const mandateName = franchiseMandateName(library);
  const keys: Record<string, string> = { invitation: randomUUID() };
  if (result.status === "success") {
    result.dashboard.approvals.forEach((value) => {
      keys[`approval:${value.id}`] = randomUUID();
    });
    result.dashboard.books.forEach((value) => {
      keys[`fee:${value.id}`] = randomUUID();
      keys[`close:${value.id}`] = randomUUID();
      keys[`payout:${value.id}`] = randomUUID();
    });
  }
  return (
    <FranchiseAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="governance" title={c.govTitle} lead={c.govLead} kicker={c.govKicker} mandateName={mandateName} actions={<FranchiseActions href="#gouvernance" label={c.prepare} />}>
      <GovernanceBoard locale={locale} query={space.selectedQuery} mandateName={mandateName} board={result.status === "success" ? buildFranchiseSpaceBoard({ locale, query: space.selectedQuery, libraryName: mandateName, governance: result.dashboard }) : undefined} />
      <details id="gouvernance" className="client-ops" open>
        <summary>{c.opsGov}</summary>
        {result.status === "error" ? (
          <Alert variant="destructive">
            <AlertTitle>{result.reason === "FORBIDDEN" ? messages.accessDenied : messages.queryFailed}</AlertTitle>
            <AlertDescription>{result.reason}</AlertDescription>
          </Alert>
        ) : (
          <GovernancePanel dashboard={result.dashboard} locale={locale} m={messages} keys={keys} />
        )}
      </details>
    </FranchiseAppShell>
  );
}
