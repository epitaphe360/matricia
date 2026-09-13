import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { buttonVariants } from "@/components/ui/button";
import { loadPublicationDashboard } from "@/lib/catalogue-publications/repository";
import { isLocale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { getPublicationMessages } from "./messages";
import { PublicationPanel } from "./publication-panel";

export const dynamic = "force-dynamic";

export default async function CataloguePublicationsPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const result = await loadPublicationDashboard();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const messages = getPublicationMessages(locale);
  const alternate = locale === "fr" ? "ar" : "fr";
  const commandIds = result.status === "success" ? Object.fromEntries(result.value.libraries.map((library) => [library.id, { idempotencyKey: randomUUID(), correlationId: randomUUID() }])) : {};
  return <main dir={locale === "ar" ? "rtl" : "ltr"} className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8"><div className="mx-auto max-w-7xl space-y-7"><nav aria-label={messages.nav} className="flex flex-wrap items-center justify-between gap-3"><Link href={`/${locale}/administration/catalogue`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.back}</Link><Link href={`/${alternate}/administration/catalogue/publications`} hrefLang={alternate} className="min-h-11 rounded-md px-3 py-2 font-medium text-primary">{messages.language}</Link></nav><header><p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">{messages.title}</h1><p className="mt-3 max-w-4xl leading-7 text-muted-foreground">{messages.description}</p></header>{result.status === "error" ? <Alert variant="destructive"><AlertTitle>{result.reason === "FORBIDDEN" ? messages.forbidden : messages.unavailable}</AlertTitle><AlertDescription><Link href={`/${locale}/administration/catalogue/publications`} className={cn(buttonVariants({ variant: "outline" }), "mt-3 min-h-11")}>{messages.retry}</Link></AlertDescription></Alert> : <PublicationPanel locale={locale} dashboard={result.value} messages={messages} commandIds={commandIds}/>}</div></main>;
}
