import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { loadFranchiseDashboard } from "@/lib/franchise-governance/repository";
import { isLocale } from "@/lib/i18n/locale";
import { GovernancePanel } from "./governance-panel";
import { getFranchiseMessages } from "./messages";

export default async function FranchiseGovernancePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params; if (!isLocale(locale)) notFound(); const messages = getFranchiseMessages(locale), result = await loadFranchiseDashboard(); if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const keys: Record<string, string> = { invitation: randomUUID() }; if (result.status === "success") { result.dashboard.approvals.forEach((value) => { keys[`approval:${value.id}`] = randomUUID(); }); result.dashboard.books.forEach((value) => { keys[`fee:${value.id}`] = randomUUID(); keys[`close:${value.id}`] = randomUUID(); keys[`payout:${value.id}`] = randomUUID(); }); }
  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8" dir={locale === "ar" ? "rtl" : "ltr"}><div className="mx-auto max-w-7xl space-y-7"><header><p className="text-xs font-semibold uppercase tracking-[.18em] text-primary">{messages.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">{messages.title}</h1><p className="mt-3 max-w-3xl leading-7 text-muted-foreground">{messages.subtitle}</p></header>{result.status === "error" ? <Alert variant="destructive"><AlertTitle>{result.reason === "FORBIDDEN" ? messages.accessDenied : messages.queryFailed}</AlertTitle><AlertDescription>{result.reason}</AlertDescription></Alert> : <GovernancePanel dashboard={result.dashboard} locale={locale} m={messages} keys={keys}/>}</div></main>;
}
