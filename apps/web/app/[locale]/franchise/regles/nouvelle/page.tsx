import { randomUUID } from "node:crypto";
import { notFound } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { libraryCopy } from "@/modules/franchise/data/library/copy";
import { FranchiseRulesWorkbench } from "@/modules/franchise/screens/library/library-workbenches";
import { requireFranchiseLibrary } from "@/modules/franchise/screens/library/page-helper";
import { FranchiseAppShell } from "@/modules/franchise/ui/franchise-app-shell";

export default async function FranchiseNewRulePage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const { space, result } = await requireFranchiseLibrary({ locale, organizationId: query.organizationId });
  const c = libraryCopy(locale);
  return (
    <FranchiseAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="rules" title={c.newRule} lead={c.rulesLead} kicker={c.scope} mandateName={result.status === "success" ? result.workspace.mandate.libraryName : null}>
      {result.status === "error" ? (
        <Alert variant="destructive"><AlertTitle>{c.unavailable}</AlertTitle><AlertDescription>{result.reason === "NO_MANDATE" ? c.noMandate : c.scopeHelp}</AlertDescription></Alert>
      ) : (
        <FranchiseRulesWorkbench locale={locale} query={space.selectedQuery} workspace={result.workspace} selectedId={null} createMode commandIdentity={{ idempotencyKey: randomUUID(), correlationId: randomUUID() }} />
      )}
    </FranchiseAppShell>
  );
}
