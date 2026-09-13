import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { buttonVariants } from "@/components/ui/button";
import { createServerQuestionnaireSessionsRepository } from "@/lib/questionnaire-sessions/server-repository";
import { isLocale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { getQuestionnaireMessages } from "./messages";
import { QuestionnairePanel } from "./questionnaire-panel";

export default async function ClientQuestionnairesPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ session?: string }> }) {
  const { locale } = await params, { session } = await searchParams;
  if (!isLocale(locale)) notFound();
  const messages = getQuestionnaireMessages(locale), result = await (await createServerQuestionnaireSessionsRepository()).load(session);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const alternate = locale === "fr" ? "ar" : "fr";
  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8"><div className="mx-auto max-w-7xl space-y-7"><nav aria-label={messages.navigation} className="flex flex-wrap items-center justify-between gap-3"><Link href={`/${locale}/client/diagnostics`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.back}</Link><Link href={`/${alternate}/client/questionnaires${session ? `?session=${session}` : ""}`} hrefLang={alternate} className="min-h-11 rounded-md px-3 py-2 font-medium text-primary underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">{messages.language}</Link></nav><header><p className="text-xs font-semibold uppercase tracking-[.18em] text-primary">{messages.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">{messages.title}</h1><p className="mt-3 max-w-3xl leading-7 text-muted-foreground">{messages.description}</p></header><Alert><AlertTitle>{messages.privacyTitle}</AlertTitle><AlertDescription>{messages.privacy}</AlertDescription></Alert>{result.status === "error" ? <Alert variant="destructive"><AlertTitle>{result.reason === "FORBIDDEN" ? messages.forbidden : result.reason === "BOUNDS_EXCEEDED" ? messages.bounds : messages.loadError}</AlertTitle><AlertDescription><Link className="underline" href={`/${locale}/client/questionnaires`}>{messages.retry}</Link></AlertDescription></Alert> : <QuestionnairePanel locale={locale} dashboard={result.value} messages={messages} identities={{ start: { idempotencyKey: randomUUID(), correlationId: randomUUID() }, submit: { idempotencyKey: randomUUID(), correlationId: randomUUID() }, answers: Object.fromEntries((result.value.selected?.sections ?? []).flatMap((section) => section.questions.map((question) => [question.id, { idempotencyKey: randomUUID(), correlationId: randomUUID() }]))) }} />}</div></main>;
}
