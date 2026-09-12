import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { isLocale } from "@/lib/i18n/locale";
import { loadMoroccoTaxDashboard } from "@/lib/morocco-tax/repository";
import { getMoroccoTaxMessages } from "./messages";
import { TaxPanel } from "./tax-panel";

export default async function MoroccoTaxPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const m = getMoroccoTaxMessages(locale), result = await loadMoroccoTaxDashboard();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const keys: Record<string, string> = { proposal: randomUUID() };
  if (result.status === "success") result.dashboard.rules.forEach((rule) => { keys[rule.id] = randomUUID(); });
  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8" dir={locale === "ar" ? "rtl" : "ltr"}><div className="mx-auto max-w-7xl space-y-7"><header><p className="text-xs font-semibold uppercase tracking-[.18em] text-primary">{m.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">{m.title}</h1><p className="mt-3 max-w-3xl leading-7 text-muted-foreground">{m.subtitle}</p></header>{result.status === "error" ? <Alert variant="destructive"><AlertTitle>{m.unavailable}</AlertTitle><AlertDescription>{result.reason}</AlertDescription></Alert> : <TaxPanel dashboard={result.dashboard} locale={locale} m={m} keys={keys}/>}</div></main>;
}
