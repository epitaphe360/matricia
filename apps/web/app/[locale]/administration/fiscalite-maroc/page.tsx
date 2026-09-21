import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { loadMoroccoTaxDashboard } from "@/modules/shared/lib/morocco-tax/repository";
import { getMoroccoTaxMessages } from "@/modules/admin/screens/fiscalite-maroc/messages";
import { TaxPanel } from "@/modules/admin/screens/fiscalite-maroc/tax-panel";
import { AdminModulePage } from "@/modules/admin/ui/admin-module-page";

export default async function MoroccoTaxPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const m = getMoroccoTaxMessages(locale);
  const result = await loadMoroccoTaxDashboard();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const keys: Record<string, string> = { proposal: randomUUID() };
  if (result.status === "success") result.dashboard.rules.forEach((rule) => { keys[rule.id] = randomUUID(); });
  return (
    <AdminModulePage locale={locale} active="catalog" path="fiscalite-maroc" title={m.title} lead={m.subtitle}>
      {result.status === "error" ? (
        <Alert variant="destructive"><AlertTitle>{m.unavailable}</AlertTitle><AlertDescription>{result.reason}</AlertDescription></Alert>
      ) : (
        <TaxPanel dashboard={result.dashboard} locale={locale} m={m} keys={keys} />
      )}
    </AdminModulePage>
  );
}
