import { randomUUID } from "node:crypto";
import { redirect, notFound } from "next/navigation";
import { createServerAssistedIntelligenceRepository } from "@/lib/assisted-intelligence/server-repository";
import { isLocale } from "@/lib/i18n/locale";
import { AssistancePanel } from "./assistance-panel";
import { getAssistanceMessages } from "./messages";

export default async function AssistancePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = getAssistanceMessages(locale);
  const result = await (await createServerAssistedIntelligenceRepository()).dashboard();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  if (result.status === "error") {
    const forbidden = result.reason === "FORBIDDEN";
    return <main className="min-h-dvh bg-muted/40 px-4 py-8 sm:px-6" dir={locale === "ar" ? "rtl" : "ltr"}><section className="mx-auto max-w-3xl rounded-2xl border bg-card p-6 shadow-sm" role={forbidden ? undefined : "alert"}><h1 className="text-2xl font-semibold">{forbidden ? messages.forbiddenTitle : messages.errorTitle}</h1><p className="mt-3 leading-7 text-muted-foreground">{forbidden ? messages.forbidden : messages.error}</p></section></main>;
  }
  const decisionKeys = Object.fromEntries(result.value.suggestions.map((suggestion) => [suggestion.id, randomUUID()]));
  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6" dir={locale === "ar" ? "rtl" : "ltr"}><div className="mx-auto max-w-6xl space-y-6"><header><h1 className="text-3xl font-semibold tracking-tight">{messages.title}</h1><p className="mt-2 max-w-3xl leading-7 text-muted-foreground">{messages.intro}</p><p className="mt-4 rounded-xl border border-primary/20 bg-primary/5 p-4 text-sm font-medium text-primary">{messages.safety}</p>{result.value.model ? <p className="mt-3 text-sm text-muted-foreground">{messages.model}: <span dir="ltr" className="font-mono">v{result.value.model.version} · {result.value.model.algorithm}</span></p> : null}</header><AssistancePanel dashboard={result.value} locale={locale} messages={messages} keys={{ analysis: randomUUID(), similarity: randomUUID(), decisions: decisionKeys }}/></div></main>;
}
