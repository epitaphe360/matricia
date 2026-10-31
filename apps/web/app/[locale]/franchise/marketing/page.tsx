import { notFound, redirect } from "next/navigation";
import { connexionHref } from "@/modules/shared/lib/auth/connexion-href";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { loadWorkspaceMarketingDashboard } from "@/modules/shared/lib/marketing-autopilot/repository";
import { loadMarketingDimensionLabels } from "@/modules/shared/lib/marketing-autopilot/dimension-labels";
import { loadMarketingBrandDefaults } from "@/modules/shared/lib/marketing-autopilot/brand-defaults";
import { marketingActionKeys } from "@/modules/admin/screens/marketing-autopilot/action-keys";
import { MarketingPanel } from "@/modules/admin/screens/marketing-autopilot/marketing-panel";
import { getMarketingMessages } from "@/modules/admin/screens/marketing-autopilot/messages";
import { franchiseCopy } from "@/modules/franchise/data/spaces/copy";
import { franchiseMandateName, requireFranchiseLibrary } from "@/modules/franchise/screens/library/page-helper";
import { FranchiseAppShell } from "@/modules/franchise/ui/franchise-app-shell";

export default async function FranchiseMarketingPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const { space, result: library } = await requireFranchiseLibrary({ locale, organizationId: query.organizationId });
  const m = getMarketingMessages(locale);
  const c = franchiseCopy(locale);
  const result = await loadWorkspaceMarketingDashboard(space.selectedOrganizationId);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(connexionHref(locale, { next: `/${locale}/franchise/marketing` }));
  const mandateName = franchiseMandateName(library);
  const brandDefaults = result.status === "success" && space.selectedOrganizationId ? await loadMarketingBrandDefaults(space.selectedOrganizationId, locale, mandateName ? [mandateName] : []) : null;
  const dimensionLabels = result.status === "success" ? await loadMarketingDimensionLabels(result.dashboard, locale) : {};
  return (
    <FranchiseAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="marketing" title={m.workspaceTitle} lead={m.workspaceLead} kicker={c.kicker} mandateName={mandateName}>
      {result.status === "error" ? (
        <Alert variant={result.reason === "NO_ORGANIZATION" ? "default" : "destructive"}>
          <AlertTitle>{result.reason === "NO_ORGANIZATION" ? m.noOrganization : result.reason === "FORBIDDEN" ? m.accessDenied : m.loadFailed}</AlertTitle>
          <AlertDescription>{result.reason === "NO_ORGANIZATION" ? m.noOrganization : m.safetyText}</AlertDescription>
        </Alert>
      ) : (
        <MarketingPanel workspace dashboard={result.dashboard} brandDefaults={brandDefaults} dimensionLabels={dimensionLabels} locale={locale} m={m} keys={marketingActionKeys(result.dashboard)} />
      )}
    </FranchiseAppShell>
  );
}
