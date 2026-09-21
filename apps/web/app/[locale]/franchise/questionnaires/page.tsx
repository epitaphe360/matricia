import { randomUUID } from "node:crypto";
import { notFound } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { libraryCopy } from "@/modules/franchise/data/library/copy";
import { FranchiseQuestionnairesWorkbench } from "@/modules/franchise/screens/library/library-workbenches";
import { requireFranchiseLibrary } from "@/modules/franchise/screens/library/page-helper";
import { FranchiseSecurityPanel } from "@/modules/franchise/screens/library/library-chrome";
import { FranchiseAppShell } from "@/modules/franchise/ui/franchise-app-shell";

export default async function FranchiseQuestionnairesPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string; q?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const { space, result } = await requireFranchiseLibrary({ locale, organizationId: query.organizationId });
  const c = libraryCopy(locale);
  return (
    <FranchiseAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="questionnaires" title={c.questionnairesTitle} lead={c.questionnairesLead} kicker={c.scope} mandateName={result.status === "success" ? result.workspace.mandate.libraryName : null} actions={result.status === "success" ? <FranchiseSecurityPanel locale={locale} /> : null}>
      {result.status === "error" ? (
        <Alert variant="destructive"><AlertTitle>{c.unavailable}</AlertTitle><AlertDescription>{result.reason === "NO_MANDATE" ? c.noMandate : c.scopeHelp}</AlertDescription></Alert>
      ) : (
        <FranchiseQuestionnairesWorkbench
          locale={locale}
          query={space.selectedQuery}
          workspace={result.workspace}
          selectedId={null}
          createMode={false}
          search={query.q ?? ""}
          commandIdentity={{ idempotencyKey: randomUUID(), correlationId: randomUUID() }}
        />
      )}
    </FranchiseAppShell>
  );
}
