import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { buttonVariants } from "@/components/ui/button";
import { isLocale } from "@/lib/i18n/locale";
import { loadAdminCommandCenter } from "@/lib/admin-command-center/repository";
import { cn } from "@/lib/utils";
import { CommandCenterPanel } from "./command-center-panel";
import { getCommandCenterMessages } from "./messages";

export default async function AdminCommandCenterPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const m = getCommandCenterMessages(locale), result = await loadAdminCommandCenter();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const alternate = locale === "fr" ? "ar" : "fr";
  const keyCount = result.status === "success" ? result.dashboard.workItems.length * 2 + result.dashboard.actions.length + 1 : 1;
  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8"><div className="mx-auto max-w-7xl space-y-7">
    <nav aria-label={m.navigation} className="flex flex-wrap items-center justify-between gap-3"><Link href={`/${locale}/tableau-de-bord`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{m.back}</Link><Link href={`/${locale}/administration/approbations-finance`} className={cn(buttonVariants({variant:"outline"}),"min-h-11")}>{locale==="ar"?"الموافقات والعمولات":"Approbations et commissions"}</Link><Link href={`/${alternate}/administration/command-center`} hrefLang={alternate} className="min-h-11 rounded-md px-3 py-2 font-medium text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">{m.language}</Link></nav>
    <header><p className="text-xs font-semibold uppercase tracking-[.18em] text-primary">{m.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">{m.title}</h1><p className="mt-3 font-medium text-foreground">{m.today}</p><p className="mt-2 max-w-3xl leading-7 text-muted-foreground">{m.description}</p></header>
    {result.status === "error" ? <Alert variant="destructive"><AlertTitle>{result.reason === "FORBIDDEN" ? m.forbiddenPage : m.loadError}</AlertTitle><AlertDescription>{result.reason}</AlertDescription></Alert> : <CommandCenterPanel dashboard={result.dashboard} locale={locale} m={m} currentTime={new Date().toISOString()} keys={Array.from({ length: keyCount }, () => crypto.randomUUID())} />}
  </div></main>;
}
