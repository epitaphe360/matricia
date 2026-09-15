import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { buttonVariants } from "@/components/ui/button";
import { createServerClientRecurringRepository } from "@/lib/client-recurring/server-repository";
import { isLocale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { getClientRecurringMessages } from "./messages";
import { RecurringPanel } from "./recurring-panel";

export default async function ClientRecurringPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const { organizationId } = await searchParams;
  const messages = getClientRecurringMessages(locale), result = await (await createServerClientRecurringRepository()).load(organizationId);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const alternate = locale === "fr" ? "ar" : "fr";
  const today = new Date(), horizon = new Date(today); horizon.setUTCDate(horizon.getUTCDate() + 366);
  const identity = () => ({ idempotencyKey: randomUUID(), correlationId: randomUUID() });
  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8"><div className="mx-auto max-w-7xl space-y-7"><nav aria-label={messages.navigation} className="flex flex-wrap items-center justify-between gap-3"><Link href={`/${locale}/client/demandes`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.back}</Link><Link href={`/${alternate}/client/demandes/recurrence`} hrefLang={alternate} className="min-h-11 rounded-md px-3 py-2 font-medium text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">{messages.language}</Link></nav><header><p className="text-xs font-semibold uppercase tracking-[.18em] text-primary">{messages.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">{messages.title}</h1><p className="mt-3 max-w-3xl leading-7 text-muted-foreground">{messages.description}</p></header><Alert><AlertTitle>{messages.safetyTitle}</AlertTitle><AlertDescription>{messages.safety}</AlertDescription></Alert>{result.status === "error" ? <Alert variant="destructive"><AlertTitle>{result.reason === "FORBIDDEN" ? messages.forbidden : messages.loadError}</AlertTitle><AlertDescription><Link className="underline" href={`/${locale}/client/demandes/recurrence`}>{messages.retry}</Link></AlertDescription></Alert> : <RecurringPanel dashboard={result.value} locale={locale} messages={messages} today={today.toISOString().slice(0, 10)} horizon={horizon.toISOString().slice(0, 10)} identities={{ clone: identity(), create: identity(), plans: Object.fromEntries(result.value.plans.map((plan) => [plan.id, { transition: identity(), generate: identity() }])) }} />}</div></main>;
}
