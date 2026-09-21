import { notFound } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { libraryCopy } from "@/modules/franchise/data/library/copy";
import { FranchiseValidationsWorkbench } from "@/modules/franchise/screens/library/validations-workbench";
import { franchiseMandateName, requireFranchiseLibrary } from "@/modules/franchise/screens/library/page-helper";
import { FranchiseAppShell } from "@/modules/franchise/ui/franchise-app-shell";

export default async function FranchiseValidationsPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const { space, result } = await requireFranchiseLibrary({ locale, organizationId: query.organizationId });
  const c = libraryCopy(locale);
  const mandateName = franchiseMandateName(result);
  return (
    <FranchiseAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="validations" title={c.validationsTitle} lead={c.validationsLead} kicker={c.scope} mandateName={mandateName}>
      {result.status === "error" ? (
        <Alert variant="destructive"><AlertTitle>{c.unavailable}</AlertTitle><AlertDescription>{result.reason === "NO_MANDATE" ? c.noMandate : c.scopeHelp}</AlertDescription></Alert>
      ) : (
        <FranchiseValidationsWorkbench locale={locale} query={space.selectedQuery} workspace={result.workspace} />
      )}
    </FranchiseAppShell>
  );
}
