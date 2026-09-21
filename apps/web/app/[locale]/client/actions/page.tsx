import { notFound, redirect } from "next/navigation";
import { loadUserActionCenterWithinBudget } from "@/modules/shared/lib/action-center/repository";
import { filterDashboardActions } from "@/modules/shared/lib/action-center/dashboard-summary";
import { filterClientFacingActions } from "@/modules/client/data/home/view-model";
import { clientDashboardCopy } from "@/modules/client/data/home/copy";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { RequiredActionsBoard } from "@/modules/client/screens/spaces/required-actions-board";
import { ClientApprovalsPanel } from "@/modules/client/screens/approbations/approval-panel";
import { getApprovalMessages } from "@/modules/client/screens/approbations/messages";
import { loadClientApprovals } from "@/modules/client/screens/approbations/load";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function ClientActionsPage({
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
  const now = new Date().toISOString();
  const [result, approvals] = await Promise.all([
    loadUserActionCenterWithinBudget(locale, now, space.selectedOrganizationId),
    loadClientApprovals(space.selectedOrganizationId),
  ]);
  const scoped = result.status === "success"
    ? filterClientFacingActions(filterDashboardActions(result.value.items, space.selectedOrganizationId), false)
    : [];
  const c = clientDashboardCopy[locale];
  const kicker = spaceCopy(locale).kicker;
  return (
    <ClientAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      active="actions"
      title={c.actionsTitle}
      lead={c.actionsLead}
      kicker={kicker}
    >
      <RequiredActionsBoard
        locale={locale}
        items={scoped}
        organizationQuery={space.selectedQuery}
        error={result.status === "error"}
      />
      <ClientApprovalsPanel locale={locale} items={approvals} messages={getApprovalMessages(locale)} />
    </ClientAppShell>
  );
}
