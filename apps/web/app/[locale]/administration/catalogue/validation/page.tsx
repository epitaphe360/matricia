import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { buttonVariants } from "@/components/ui/button";
import { isLocale } from "@/lib/i18n/locale";
import { createServerRuleValidationRepository } from "@/lib/rule-validation/server-repository";
import { cn } from "@/lib/utils";
import { getRuleValidationMessages } from "./messages";
import { RuleValidationPanel } from "./rule-validation-panel";

export const dynamic = "force-dynamic";

function queryValue(value: string | string[] | undefined): string | null { return typeof value === "string" && value.length > 0 ? value : null; }

export default async function RuleValidationPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const messages = getRuleValidationMessages(locale);
  const selectedVersionId = queryValue(query.questionnaire);
  const repository = await createServerRuleValidationRepository();
  const result = await repository.loadWorkspace(selectedVersionId);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const alternate = locale === "fr" ? "ar" : "fr";
  const alternateQuery = selectedVersionId ? `?questionnaire=${encodeURIComponent(selectedVersionId)}` : "";

  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8" dir={locale === "ar" ? "rtl" : "ltr"}><div className="mx-auto max-w-7xl space-y-7">
    <nav aria-label={messages.eyebrow} className="flex flex-wrap items-center justify-between gap-3"><Link href={`/${locale}/administration/catalogue`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.back}</Link><Link href={`/${alternate}/administration/catalogue/validation${alternateQuery}`} hrefLang={alternate} className="min-h-11 rounded-md px-3 py-2 font-medium text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">{messages.language}</Link></nav>
    <header><p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">{messages.title}</h1><p className="mt-3 max-w-3xl leading-7 text-muted-foreground">{messages.description}</p></header>
    {result.status === "error" ? <Alert variant="destructive"><AlertTitle>{result.reason === "FORBIDDEN" ? messages.forbiddenPage : messages.unavailable}</AlertTitle><AlertDescription><Link href={`/${locale}/administration/catalogue/validation`} className={cn(buttonVariants({ variant: "outline" }), "mt-3 min-h-11")}>{messages.retry}</Link></AlertDescription></Alert> : <RuleValidationPanel workspace={result.value} locale={locale} messages={messages}/>}
  </div></main>;
}
