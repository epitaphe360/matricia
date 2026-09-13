import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { buttonVariants } from "@/components/ui/button";
import { loadAdminProviders } from "@/lib/admin-providers/repository";
import { isLocale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { getAdminProviderMessages } from "./messages";
import { ProvidersPanel } from "./providers-panel";

export default async function AdminProvidersPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params; if (!isLocale(locale)) notFound(); const messages = getAdminProviderMessages(locale); const result = await loadAdminProviders(); if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`); const alternate = locale === "fr" ? "ar" : "fr";
  const keys: Record<string, string> = { statement: crypto.randomUUID(), invoice: crypto.randomUUID(), payment: crypto.randomUUID(), reconcile: crypto.randomUUID() };
  if (result.status === "success") { for (const provider of result.dashboard.providers) keys[`company:${provider.organizationId}`] = crypto.randomUUID(); for (const document of result.dashboard.documents) keys[`document:${document.id}`] = crypto.randomUUID(); for (const service of result.dashboard.services) keys[`qualification:${service.id}`] = crypto.randomUUID(); }
  return <main dir={locale === "ar" ? "rtl" : "ltr"} className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8"><div className="mx-auto max-w-7xl space-y-7"><nav aria-label={messages.navigation} className="flex flex-wrap items-center justify-between gap-3"><Link href={`/${locale}/administration/command-center`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.back}</Link><Link href={`/${alternate}/administration/providers`} hrefLang={alternate} className="min-h-11 rounded-md px-3 py-2 font-medium text-primary hover:underline">{messages.language}</Link></nav><header><p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">{messages.title}</h1><p className="mt-3 max-w-4xl leading-7 text-muted-foreground">{messages.description}</p></header>{result.status === "error" ? <Alert variant="destructive"><AlertTitle>{result.reason === "FORBIDDEN" ? messages.forbiddenPage : messages.loadError}</AlertTitle><AlertDescription><Link href={`/${locale}/administration/providers`} className={cn(buttonVariants({ variant: "outline" }), "mt-4 min-h-11")}>{messages.retry}</Link></AlertDescription></Alert> : <ProvidersPanel dashboard={result.dashboard} locale={locale} messages={messages} keys={keys} />}</div></main>;
}
